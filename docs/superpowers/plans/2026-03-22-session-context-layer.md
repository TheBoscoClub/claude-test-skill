# Session Context Layer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a session context layer (curated context file, ring buffer, compaction recovery gate) to Claude Code's hook infrastructure so reasoning chains survive auto-compaction and session crashes.

**Architecture:** Four new mechanisms wired into existing bash hooks: (1) SessionStart creates a context file + ring buffer, (2) PostToolUse keeps the ring buffer current and detects compaction flags, (3) PreCompact writes a compaction flag, (4) UserPromptSubmit detects the same flag as a fallback. Recovery is structurally enforced via `additionalContext` injection, not behavioral rules.

**Tech Stack:** Bash (hooks), Markdown (context file, rules, commands), JSONL (ring buffer)

---

## File Structure

| File | Action | Responsibility |
|------|--------|---------------|
| `~/.claude/templates/gitignore-claude` | Modify | Add `.claude-session-context.md` and `.claude-session-ring.jsonl` |
| `~/.claude/hooks/session-start.sh` | Modify | Create context file with frontmatter + empty ring buffer on session start; detect crashed sessions |
| `~/.claude/hooks/context-monitor.sh` | Modify | Update ring buffer on every PostToolUse; detect compaction flag and inject `additionalContext` |
| `~/.claude/hooks/pre-compact.sh` | Modify | Write compaction flag file before compaction |
| `~/.claude/hooks/prompt-dispatcher.sh` | Modify | Detect compaction flag on UserPromptSubmit (belt-and-suspenders fallback) |
| `~/.claude/commands/close.md` | Modify | Clean up context file + ring buffer during `/close` |
| `~/.claude/rules/session-workflow.md` | Modify | Document session context file, ring buffer, checkpoint obligations, recovery flow |
| `~/.claude/CLAUDE.md` | Modify | Add session context file to line 3 |

---

### Task 1: Gitignore Template — Add Context Layer Files

**Files:**
- Modify: `~/.claude/templates/gitignore-claude:148-155`

These entries must exist before any other task creates the files, so projects don't accidentally track ephemeral session data.

- [ ] **Step 1: Add gitignore entries after the existing wallet card block**

In `~/.claude/templates/gitignore-claude`, after line 154 (`.claude-task-state.md`), add:

```gitignore
# Session context — curated conversation memory for compaction/crash recovery
.claude-session-context.md
# Ring buffer — 128KB trailing I/O window for ground-truth recovery
.claude-session-ring.jsonl
```

- [ ] **Step 2: Add entries to this project's `.gitignore`**

In `/hddRaid1/ClaudeCodeProjects/claude-test-skill/.gitignore`, add the same two entries. Also check any other active projects that have `.gitignore` files and add the entries there too. Existing projects won't pick up template changes automatically.

Run: `grep -rn 'claude-task-state' /hddRaid1/ClaudeCodeProjects/*/.gitignore 2>/dev/null` to find all project gitignore files that track Claude workflow files, then add the two new entries to each.

- [ ] **Step 3: Verify the entries are in the right location**

Run: `grep -n 'session-context\|session-ring' ~/.claude/templates/gitignore-claude`

Expected: Two lines showing both new entries, positioned after the wallet card block.

- [ ] **Step 4: Commit**

```bash
git add ~/.claude/templates/gitignore-claude
git commit -m "chore: add session context file and ring buffer to gitignore template"
```

---

### Task 2: SessionStart Hook — Create Context File and Ring Buffer

**Files:**
- Modify: `~/.claude/hooks/session-start.sh:1-186`

This is the structural guarantee — every session gets a context file and ring buffer, created by code, not by behavioral rules.

- [ ] **Step 1: Add the `create_session_context` function**

After the `snapshot_claude_md` function call (line 48), before the "Last session exit" section (line 50), add:

```bash
# ── Create session context file and ring buffer ──────────────────────────────
create_session_context() {
    local project_dir=""
    if [[ -f "$HOME/.claude/.current_project" ]]; then
        project_dir=$(cat "$HOME/.claude/.current_project")
    elif [[ "$PWD" == /hddRaid1/ClaudeCodeProjects/* ]]; then
        project_dir="$PWD"
    fi

    # Skip if not in a project directory
    [[ -z "$project_dir" || ! -d "$project_dir" ]] && return 0

    local context_file="$project_dir/.claude-session-context.md"
    local ring_file="$project_dir/.claude-session-ring.jsonl"
    local session_id="${CLAUDE_SESSION_ID:-unknown}"
    # $PPID = Claude Code process (hook's parent). $$ = this bash subprocess (ephemeral, useless).
    # Claude Code's parent (terminal/shell) is one level up.
    local claude_pid=$PPID
    local claude_ppid
    claude_ppid=$(ps -o ppid= -p "$PPID" 2>/dev/null | tr -d ' ')
    local current_tty
    current_tty=$(tty 2>/dev/null || echo "unknown")
    local branch
    branch=$(git -C "$project_dir" branch --show-current 2>/dev/null || echo "unknown")

    # Detect crashed sessions
    if [[ -f "$context_file" ]]; then
        local old_session
        old_session=$(grep '^session:' "$context_file" | head -1 | awk '{print $2}')
        local old_state
        old_state=$(grep '^session:' "$context_file" | head -1)

        if [[ "$old_session" == "$session_id" ]]; then
            # Same session — resuming after compaction, preserve file
            log "Session context: same session ($session_id), preserving"
            return 0
        elif echo "$old_state" | grep -q "closed"; then
            # Previous session ended cleanly — overwrite
            log "Session context: previous session closed cleanly, creating fresh"
        else
            # Previous session died — preserve as recovery source
            local old_pid
            old_pid=$(grep '^pid:' "$context_file" | head -1 | awk '{print $2}')
            if [[ -n "$old_pid" ]] && kill -0 "$old_pid" 2>/dev/null; then
                log "Session context: previous session PID $old_pid still alive — preserving"
                return 0
            fi
            log "Session context: CRASHED SESSION DETECTED (session=$old_session, pid=$old_pid) — preserving for recovery"
            # Don't overwrite — Claude will read this on first interaction
            return 0
        fi
    fi

    # Create fresh context file with frontmatter
    cat > "$context_file" << CTXEOF
---
updated: $(date -Iseconds)
session: $session_id
branch: $branch
ppid: ${claude_ppid:-0}
pid: $claude_pid
cpids: []
tty: $current_tty
active_work: ""
---

## Active Context

### Approach & Reasoning


### Key Decisions


### Plan Progress


### User Preferences (this session)

CTXEOF

    log "Session context: created ($context_file)"

    # Create empty ring buffer
    : > "$ring_file"
    log "Ring buffer: created ($ring_file)"
}
create_session_context
```

- [ ] **Step 2: Verify the hook still runs without errors**

Run: `echo '{}' | bash ~/.claude/hooks/session-start.sh 2>/dev/null; echo "exit code: $?"`

Expected: Exit code 0. The function will skip (no `CLAUDE_SESSION_ID` set in test) but should not error.

- [ ] **Step 3: Test context file creation with a mock session ID**

Run:
```bash
cd /tmp && mkdir -p test-session-hook && cd test-session-hook && git init
CLAUDE_SESSION_ID=test123 PWD=/tmp/test-session-hook bash -c '
    source <(grep -A100 "create_session_context()" ~/.claude/hooks/session-start.sh | head -70)
    # Manually set the project_dir since .current_project won't match /tmp
'
# Cleanup
rm -rf /tmp/test-session-hook
```

This is a sanity check — the real test is starting a new Claude Code session and verifying the file appears.

- [ ] **Step 4: Commit**

```bash
git add ~/.claude/hooks/session-start.sh
git commit -m "feat: session-start creates context file and ring buffer with process identity"
```

---

### Task 3: Ring Buffer — PostToolUse Update in Context Monitor

**Files:**
- Modify: `~/.claude/hooks/context-monitor.sh:1-105`

The ring buffer update runs on **every** PostToolUse call, regardless of transcript size thresholds. It's a single `tail -c` — near-zero cost.

- [ ] **Step 1: Update the file header comment**

Lines 5-7 of `context-monitor.sh` currently say:
```
# Graduated response: observe → note → wallet-card-update → silent.
# NEVER writes to session record. NEVER injects additionalContext.
# At Critical level, goes silent and trusts PreCompact hook.
```

Replace with:
```
# Graduated response: observe → note → wallet-card-update → silent.
# NEVER writes to session record.
# Injects additionalContext ONLY on compaction flag detection (one-shot recovery).
# Also updates ring buffer on every call (near-zero cost).
# At Critical level, goes silent and trusts PreCompact hook.
```

- [ ] **Step 2: Add ring buffer update at the top of the hook, after guards**

After line 32 (`[[ -z "$transcript_path" || ! -f "$transcript_path" ]] && exit 0`), and before the `file_size` check (line 34), add:

```bash
# --- Ring buffer: always update (near-zero cost) ---
# Trailing 128 KB of raw transcript — ground-truth recovery source
ring_dir=""
if [[ -n "$cwd" && "$cwd" == /hddRaid1/ClaudeCodeProjects/* ]]; then
    ring_dir="$cwd"
elif [[ -f "$HOME/.claude/.current_project" ]]; then
    ring_dir=$(cat "$HOME/.claude/.current_project")
fi
if [[ -n "$ring_dir" && -d "$ring_dir" ]]; then
    tail -c 131072 "$transcript_path" > "$ring_dir/.claude-session-ring.jsonl" 2>/dev/null
fi
```

- [ ] **Step 3: Verify the hook still exits cleanly below threshold**

Run: `echo '{"cwd":"/tmp","transcript_path":"/dev/null","session_id":"test"}' | bash ~/.claude/hooks/context-monitor.sh; echo "exit: $?"`

Expected: Exit code 0.

- [ ] **Step 4: Commit**

```bash
git add ~/.claude/hooks/context-monitor.sh
git commit -m "feat: ring buffer — update 128KB trailing window on every PostToolUse"
```

---

### Task 4: PreCompact Hook — Write Compaction Flag

**Files:**
- Modify: `~/.claude/hooks/pre-compact.sh:1-145`

Simple addition: write a flag file that PostToolUse and UserPromptSubmit will check after compaction.

- [ ] **Step 1: Add flag file write and safety-net context file after the calibration logging block**

After line 25 (the `fi` closing the calibration log block), add:

```bash
# --- Write compaction flag for post-compaction recovery injection ---
# PostToolUse (context-monitor.sh) and UserPromptSubmit (prompt-dispatcher.sh)
# will check for this flag and inject additionalContext recovery instructions.
flag_dir="$HOME/.claude/cache"
mkdir -p "$flag_dir"
touch "$flag_dir/compaction-pending-${session_id}"

# --- Safety net: create minimal context file if SessionStart didn't ---
# This ensures the recovery injection has something to point to.
if [[ -n "$cwd" && -d "$cwd" && ! -f "$cwd/.claude-session-context.md" ]]; then
    cat > "$cwd/.claude-session-context.md" << CTXEOF
---
updated: $(date -Iseconds)
session: $session_id
branch: ${git_branch:-unknown}
ppid: 0
pid: 0
cpids: []
tty: unknown
active_work: "unknown — created by PreCompact safety net"
---

## Active Context

(No checkpoints were written before compaction. Check ring buffer and git state.)
CTXEOF
fi
```

- [ ] **Step 2: Verify the hook writes the flag**

Run:
```bash
echo '{"cwd":"/tmp","transcript_path":"/dev/null","trigger":"auto","session_id":"test-flag"}' | bash ~/.claude/hooks/pre-compact.sh 2>/dev/null
ls -la ~/.claude/cache/compaction-pending-test-flag
rm -f ~/.claude/cache/compaction-pending-test-flag
```

Expected: Flag file exists, then is cleaned up.

- [ ] **Step 3: Commit**

```bash
git add ~/.claude/hooks/pre-compact.sh
git commit -m "feat: pre-compact writes compaction flag for post-compaction recovery injection"
```

---

### Task 5: Compaction Detection — PostToolUse Injection in Context Monitor

**Files:**
- Modify: `~/.claude/hooks/context-monitor.sh` (after the ring buffer addition from Task 3)

This is the primary compaction recovery path. When the flag is found, inject `additionalContext` with recovery instructions and delete the flag.

**Dependency:** This task MUST be implemented after Task 3 in the same file. The `$ring_dir` variable used below is defined in Task 3's ring buffer block. Both blocks live in `context-monitor.sh` in sequence.

- [ ] **Step 1: Add compaction flag detection after the ring buffer block, before the `file_size` line**

After the ring buffer block (added in Task 3) and before `file_size=$(stat -c%s ...)`, add:

```bash
# --- Compaction flag detection: inject recovery instructions ---
# PreCompact writes a flag; we check it on every PostToolUse.
# First hook to fire (PostToolUse or UserPromptSubmit) handles recovery.
compaction_flag="$HOME/.claude/cache/compaction-pending-${session_id}"
if [[ -f "$compaction_flag" ]]; then
    rm -f "$compaction_flag"

    # Build recovery file paths
    ctx_file=""
    wallet_file=""
    ring_file=""
    if [[ -n "$ring_dir" && -d "$ring_dir" ]]; then
        ctx_file="$ring_dir/.claude-session-context.md"
        wallet_file="$ring_dir/.claude-task-state.md"
        ring_file="$ring_dir/.claude-session-ring.jsonl"
    fi

    # Inject additionalContext for post-compaction recovery
    cat <<RECOVERY_JSON
{
  "additionalContext": "COMPACTION JUST OCCURRED. Before doing anything else:\n1. Read ${ctx_file} (your curated reasoning chain — decisions, approach, preferences)\n2. Read ${wallet_file} (task skeleton — current work, files, next step)\n3. Read ${ring_file} (raw recent conversation — filter for user/assistant messages, skip tool results)\n4. Run: git diff --stat && git log --oneline -5\n5. Output a recovery checkpoint (⟡ Recovery checkpoint) confirming what you recovered.\n   Wait for user confirmation before proceeding.\nDo not ask the user what you were doing. Do not proceed until the user confirms."
}
RECOVERY_JSON
    exit 0
fi
```

- [ ] **Step 2: Verify flag detection and JSON output**

Run:
```bash
# Create a fake flag
touch ~/.claude/cache/compaction-pending-test-detect
echo '{"cwd":"/hddRaid1/ClaudeCodeProjects/claude-test-skill","transcript_path":"/dev/null","session_id":"test-detect"}' \
    | bash ~/.claude/hooks/context-monitor.sh 2>/dev/null
# Flag should be consumed
ls ~/.claude/cache/compaction-pending-test-detect 2>&1
```

Expected: First command outputs valid JSON with `additionalContext` key. Second command shows "No such file" (flag was consumed).

- [ ] **Step 3: Verify JSON is valid**

Run:
```bash
touch ~/.claude/cache/compaction-pending-test-json
echo '{"cwd":"/hddRaid1/ClaudeCodeProjects/claude-test-skill","transcript_path":"/dev/null","session_id":"test-json"}' \
    | bash ~/.claude/hooks/context-monitor.sh 2>/dev/null | jq .
rm -f ~/.claude/cache/compaction-pending-test-json
```

Expected: `jq` parses the output successfully — valid JSON with `additionalContext` field.

- [ ] **Step 4: Commit**

```bash
git add ~/.claude/hooks/context-monitor.sh
git commit -m "feat: PostToolUse compaction detection — inject additionalContext for recovery"
```

---

### Task 6: Compaction Detection — UserPromptSubmit Fallback in Prompt Dispatcher

**Files:**
- Modify: `~/.claude/hooks/prompt-dispatcher.sh:1-67`

Belt-and-suspenders: if compaction happens and Claude generates a text-only response (no tool call), PostToolUse never fires. UserPromptSubmit fires when the user types anything — even `.` + Enter.

- [ ] **Step 1: Add compaction flag detection before the `case` statement**

After line 14 (`log "Received prompt: '$prompt'"`), before the `case "$prompt" in` line (line 16), add:

```bash
# --- Compaction flag detection (belt-and-suspenders with PostToolUse) ---
# If compaction occurred and PostToolUse hasn't fired yet, this catches it.
session_id=$(echo "$input" | jq -r '.session_id // "unknown"')
compaction_flag="$HOME/.claude/cache/compaction-pending-${session_id}"
if [[ -f "$compaction_flag" ]]; then
    rm -f "$compaction_flag"
    log "Compaction flag detected — injecting recovery instructions"

    # Resolve project directory for file paths
    recovery_dir=""
    cwd=$(echo "$input" | jq -r '.cwd // empty')
    if [[ -n "$cwd" && "$cwd" == /hddRaid1/ClaudeCodeProjects/* ]]; then
        recovery_dir="$cwd"
    elif [[ -f "$HOME/.claude/.current_project" ]]; then
        recovery_dir=$(cat "$HOME/.claude/.current_project")
    fi

    ctx_file="${recovery_dir:+$recovery_dir/}.claude-session-context.md"
    wallet_file="${recovery_dir:+$recovery_dir/}.claude-task-state.md"
    ring_file="${recovery_dir:+$recovery_dir/}.claude-session-ring.jsonl"

    cat <<RECOVERY_JSON
{
  "additionalContext": "COMPACTION JUST OCCURRED. Before doing anything else:\n1. Read ${ctx_file} (your curated reasoning chain — decisions, approach, preferences)\n2. Read ${wallet_file} (task skeleton — current work, files, next step)\n3. Read ${ring_file} (raw recent conversation — filter for user/assistant messages, skip tool results)\n4. Run: git diff --stat && git log --oneline -5\n5. Output a recovery checkpoint (⟡ Recovery checkpoint) confirming what you recovered.\n   Wait for user confirmation before proceeding.\nDo not ask the user what you were doing. Do not proceed until the user confirms."
}
RECOVERY_JSON
    exit 0
fi
```

- [ ] **Step 2: Verify normal prompt dispatch still works**

Run:
```bash
echo '{"prompt":"hello","session_id":"test-normal","cwd":"/tmp"}' | bash ~/.claude/hooks/prompt-dispatcher.sh 2>/dev/null
echo "exit: $?"
```

Expected: Exit code 0, no output (falls through to `*` case, silent exit).

- [ ] **Step 3: Verify compaction flag detection**

Run:
```bash
touch ~/.claude/cache/compaction-pending-test-dispatch
echo '{"prompt":".","session_id":"test-dispatch","cwd":"/hddRaid1/ClaudeCodeProjects/claude-test-skill"}' \
    | bash ~/.claude/hooks/prompt-dispatcher.sh 2>/dev/null | jq .
ls ~/.claude/cache/compaction-pending-test-dispatch 2>&1
```

Expected: Valid JSON with `additionalContext`. Flag consumed (no such file).

- [ ] **Step 4: Commit**

```bash
git add ~/.claude/hooks/prompt-dispatcher.sh
git commit -m "feat: UserPromptSubmit compaction detection — belt-and-suspenders recovery fallback"
```

---

### Task 7: `/close` Command — Clean Up Context Layer Files

**Files:**
- Modify: `~/.claude/commands/close.md:166-224` (Step 6 section)

On clean session close, the context file should be marked closed (not deleted — allows crash detection to distinguish clean exit from crash) and the ring buffer deleted.

- [ ] **Step 1: Add context file and ring buffer cleanup to Step 6**

In `close.md`, in the Step 6 bash block (around line 171), after the wallet card update block (`echo "✓ Wallet card: marked as closed"`) and before the `today=$(date ...)` line, add:

```bash
# Clean up session context file — mark as closed (not delete)
context_file="$PROJECT_DIR/.claude-session-context.md"
if [[ -f "$context_file" ]]; then
    # Overwrite with closed-state frontmatter only
    cat > "$context_file" << CTXEOF
---
updated: $(date -Iseconds)
session: closed
branch: $(git -C "$PROJECT_DIR" branch --show-current 2>/dev/null || echo "unknown")
ppid: 0
pid: 0
cpids: []
tty: closed
active_work: ""
---
CTXEOF
    echo "✓ Session context: marked as closed"
fi

# Delete ring buffer — ephemeral, no value after clean close
rm -f "$PROJECT_DIR/.claude-session-ring.jsonl"
echo "✓ Ring buffer: deleted"
```

- [ ] **Step 2: Also clean up any stale compaction flags in Step 8**

In the Step 8 bash block (around line 338), after `rm -f ~/.claude/.current_project`, add:

```bash
# Clean up any stale compaction flags for this session
rm -f ~/.claude/cache/compaction-pending-* 2>/dev/null
```

- [ ] **Step 3: Verify the close command markdown is valid**

Run: `head -5 ~/.claude/commands/close.md`

Expected: YAML frontmatter header intact.

- [ ] **Step 4: Commit**

```bash
git add ~/.claude/commands/close.md
git commit -m "feat: /close cleans up session context file and ring buffer"
```

---

### Task 8: Rules and Documentation Updates

**Files:**
- Modify: `~/.claude/rules/session-workflow.md:1-72`
- Modify: `~/.claude/CLAUDE.md:3`

Update the rules file to document the new components and update CLAUDE.md's session record line.

- [ ] **Step 1: Update `session-workflow.md` — add Session Context File section**

After the "## Recovery: Wallet Card" section (after line 17), add:

```markdown
## Session Context File

- **`$PROJECT/.claude-session-context.md`** — curated conversation memory (decisions, reasoning, approach).
- Created by SessionStart hook (structurally guaranteed). Updated by Claude at visible context checkpoints.
- Carries only the **active reasoning chain** — completed work is purged, not consolidated.
- **On session start**: hook creates file with frontmatter (session ID, PIDs, TTY, branch).
- **Crashed session detection**: if file exists from a different session and is not marked `closed`, the previous session died — read it as recovery source.
- **`.gitignore`'d** — ephemeral working state, never tracked.

## Ring Buffer

- **`$PROJECT/.claude-session-ring.jsonl`** — 128 KB trailing window of raw session I/O.
- Updated on every PostToolUse call via `tail -c 131072` (near-zero cost).
- Survives every failure mode including hard crashes (already on disk).
- Post-compaction recovery: Claude filters for user/assistant messages, skips tool results.
- **`.gitignore`'d** — ephemeral session data.

## Visible Context Checkpoints

- Claude produces `⟡ Context checkpoint` blocks as visible conversation output.
- These serve dual purpose: real-time alignment AND recovery record.
- After producing a visible checkpoint, Claude persists it to the session context file.
- Triggered by: understanding shifts, decisions reached, transition points, user request.
- **First checkpoint obligation**: Claude MUST produce a checkpoint within its first substantive response of every session:
  - New session → confirm what the user wants to work on
  - Resumed session → recovery checkpoint confirming recovered state
  - Crashed session detected → recovery checkpoint + check if old PID/TTY alive

## Post-Compaction Recovery

- **Structurally enforced** — hooks gate recovery, not behavioral rules.
- PreCompact writes a flag file (`~/.claude/cache/compaction-pending-{session_id}`).
- PostToolUse or UserPromptSubmit (whichever fires first) detects the flag and injects `additionalContext`.
- Claude reads: session context file → wallet card → ring buffer → git state.
- Claude outputs a `⟡ Recovery checkpoint` and waits for user confirmation before proceeding.
```

- [ ] **Step 2: Update the Session Lifecycle section**

Replace lines 29-32 (the Session Lifecycle bullet list) with:

```markdown
## Session Lifecycle

- **SessionStart** hook: displays project table, creates session context file with process identity (PIDs, TTY), creates empty ring buffer, detects crashed sessions.
- **SessionEnd** hook: creates exit timestamp.
- **PreCompact** hook: captures git state, writes compaction flag, logs transcript size.
- **PostToolUse** hook (context monitor): updates ring buffer (always), detects compaction flag and injects `additionalContext` recovery instructions.
- **UserPromptSubmit** hook (prompt dispatcher): detects compaction flag (belt-and-suspenders fallback).
```

- [ ] **Step 3: Add wallet card pointer to session context file**

In `session-workflow.md`, in the "## Recovery: Wallet Card" section, after the bullet about "Only the master session updates the wallet card", add:

```markdown
- Wallet card gains one pointer line: `## Session Context` → `.claude-session-context.md` for the full reasoning chain.
```

- [ ] **Step 4: Update CLAUDE.md line 3**

Change line 3 from:
```
3. **SESSION RECORDS** — On session start: create `SESSION_RECORD_YYYY-MM-DD.md` and wallet card (`.claude-task-state.md`). Update both at milestones. See `rules/session-workflow.md`.
```
To:
```
3. **SESSION RECORDS** — On session start: create `SESSION_RECORD_YYYY-MM-DD.md`, wallet card (`.claude-task-state.md`), and session context file (`.claude-session-context.md`). Update at milestones and visible checkpoints. See `rules/session-workflow.md`.
```

- [ ] **Step 5: Commit**

```bash
git add ~/.claude/rules/session-workflow.md ~/.claude/CLAUDE.md
git commit -m "docs: update session workflow rules and CLAUDE.md for context layer"
```

---

### Task 9: Integration Verification

No new files — verify the full system works end-to-end.

- [ ] **Step 1: Verify SessionStart creates context file**

Start a new terminal, navigate to any project directory, and check:
```bash
ls -la /hddRaid1/ClaudeCodeProjects/claude-test-skill/.claude-session-context.md
ls -la /hddRaid1/ClaudeCodeProjects/claude-test-skill/.claude-session-ring.jsonl
```

Expected: Both files exist after starting a Claude Code session in that project.

- [ ] **Step 2: Verify ring buffer updates**

After using a few tool calls in a session:
```bash
wc -c /hddRaid1/ClaudeCodeProjects/claude-test-skill/.claude-session-ring.jsonl
```

Expected: Non-zero size, growing with each tool call, capped at 128 KB.

- [ ] **Step 3: Simulate compaction flag and verify injection**

```bash
# Create flag as if PreCompact fired
touch ~/.claude/cache/compaction-pending-$(cat /hddRaid1/ClaudeCodeProjects/claude-test-skill/.claude-session-context.md | grep '^session:' | awk '{print $2}')
# Next tool call or user prompt should trigger recovery injection
```

Expected: Claude outputs a recovery checkpoint on the next interaction.

- [ ] **Step 4: Verify `/close` cleanup**

Run `/close` and check:
```bash
cat /hddRaid1/ClaudeCodeProjects/claude-test-skill/.claude-session-context.md | head -5
ls /hddRaid1/ClaudeCodeProjects/claude-test-skill/.claude-session-ring.jsonl 2>&1
```

Expected: Context file shows `session: closed`. Ring buffer is gone.

- [ ] **Step 5: Verify gitignore template has both entries**

```bash
grep -c 'session-context\|session-ring' ~/.claude/templates/gitignore-claude
```

Expected: 2

- [ ] **Step 6: Final commit — mark implementation complete**

```bash
git add -A
git commit -m "feat: session context layer — complete implementation with ring buffer and compaction recovery"
```
