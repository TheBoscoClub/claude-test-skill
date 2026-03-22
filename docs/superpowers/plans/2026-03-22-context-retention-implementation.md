# Context Retention Architecture Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the feedback-loop-prone session record system with a distributed wallet card + milestone-only architecture.

**Architecture:** Three independent recovery sources — wallet card (intent), git state (actual changes), session record (audit trail). Context monitor goes silent under pressure instead of louder. PreCompact hook points recovery at wallet card instead of session record.

**Tech Stack:** Bash hooks, Markdown rules files, Claude Code settings.json hook configuration

**Spec:** `docs/superpowers/specs/2026-03-22-context-retention-design.md`

---

### Task 1: Add Wallet Card to Gitignore Template

**Files:**
- Modify: `~/.claude/templates/gitignore-claude:148-155` (Claude Code workflow section)

This must happen first — before any wallet card files get created, the gitignore template must exclude them.

- [ ] **Step 1: Add `.claude-task-state.md` to the gitignore template**

In `~/.claude/templates/gitignore-claude`, after the `.claude-recovery-plan.md` line (line 151), add:

```
# Wallet card — ephemeral task state for context recovery
.claude-task-state.md
```

- [ ] **Step 2: Verify the entry is in the right section**

Run: `grep -n 'task-state' ~/.claude/templates/gitignore-claude`
Expected: Line ~152 showing `.claude-task-state.md`

- [ ] **Step 3: Add to current project's .gitignore too**

Existing projects won't pick up the template change. Add `.claude-task-state.md` to the current project's `.gitignore`:

```bash
echo -e "\n# Wallet card — ephemeral task state for context recovery\n.claude-task-state.md" >> /hddRaid1/ClaudeCodeProjects/claude-test-skill/.gitignore
```

Other projects will get it added on first use or via a bulk sweep.

- [ ] **Step 4: No git commit for this task**

The gitignore template lives at `~/.claude/templates/` which is outside any project repo. The project `.gitignore` change will be committed with the final commit in Task 10.

---

### Task 2: Rewrite Context Monitor Hook

**Files:**
- Rewrite: `~/.claude/hooks/context-monitor.sh` (117 lines → ~80 lines)

The current hook fires on every PostToolUse, writes to the session record at CRITICAL with no cooldown, and injects `additionalContext` creating a feedback loop. The new hook observes transcript size with graduated thresholds (3/5/7 MB), goes silent at Critical, and never writes to the session record.

- [ ] **Step 1: Back up the current hook**

```bash
cp ~/.claude/hooks/context-monitor.sh ~/.claude/hooks/context-monitor.sh.bak-$(date +%Y%m%d)
```

- [ ] **Step 2: Write the new context-monitor.sh**

Replace the entire file with:

```bash
#!/bin/bash
# context-monitor.sh — Graduated transcript size observer
#
# Runs on PostToolUse. Measures transcript JSONL file size.
# Graduated response: observe → note → wallet-card-update → silent.
# NEVER writes to session record. NEVER injects additionalContext.
# At Critical level, goes silent and trusts PreCompact hook.
#
# Thresholds calibrated from ~/.claude/cache/context-monitor/compaction-sizes.log
# Compaction fires at 1.4–12 MB transcript, median ~6–7 MB.

set -euo pipefail

input=$(cat)
cwd=$(echo "$input" | jq -r '.cwd // empty')
transcript_path=$(echo "$input" | jq -r '.transcript_path // empty')
session_id=$(echo "$input" | jq -r '.session_id // "unknown"')

# --- Configuration ---
# Transcript file size thresholds in bytes (calibrated from real compaction data)
ELEVATED_THRESHOLD=3145728    # 3 MB — one-time stderr note
HIGH_THRESHOLD=5242880        # 5 MB — update wallet card git-state once
CRITICAL_THRESHOLD=7340032    # 7 MB — silent, trust PreCompact

# State tracking (per session)
state_dir="$HOME/.claude/cache/context-monitor"
mkdir -p "$state_dir"
elevated_flag="$state_dir/${session_id}.elevated"
high_flag="$state_dir/${session_id}.high"

# --- Guards ---
[[ -z "$transcript_path" || ! -f "$transcript_path" ]] && exit 0

file_size=$(stat -c%s "$transcript_path" 2>/dev/null || echo 0)

# Below Elevated — do nothing
[[ "$file_size" -lt "$ELEVATED_THRESHOLD" ]] && exit 0

# --- Critical: Silent ---
# Trust PreCompact hook. No writes, no injection, no output.
[[ "$file_size" -ge "$CRITICAL_THRESHOLD" ]] && exit 0

# --- High: Update wallet card git-state fields (once) ---
if [[ "$file_size" -ge "$HIGH_THRESHOLD" ]]; then
    # Only fire once per session
    [[ -f "$high_flag" ]] && exit 0
    touch "$high_flag"

    # Resolve wallet card path
    wallet_card=""
    if [[ -n "$cwd" ]] && git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        wallet_card="$cwd/.claude-task-state.md"
    elif [[ -n "$cwd" && "$cwd" == /hddRaid1/ClaudeCodeProjects/* ]]; then
        wallet_card="$cwd/.claude-task-state.md"
    else
        wallet_card="$HOME/.claude/task-state.md"
    fi

    # Capture git state into wallet card frontmatter + git fields only
    # Does NOT populate semantic fields (Current Work, Next Step) — Claude's job
    if [[ -n "$cwd" ]] && git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        branch=$(git -C "$cwd" branch --show-current 2>/dev/null || echo "unknown")
        dirty_files=$(git -C "$cwd" status --short 2>/dev/null | head -10)
        dirty_count=$(git -C "$cwd" status --short 2>/dev/null | wc -l)
        recent=$(git -C "$cwd" log --oneline -5 2>/dev/null)

        cat > "$wallet_card" << WALLETEOF
---
updated: $(date -Iseconds)
session: $session_id
branch: $branch
---
# Task State

## Current Work
Unknown — check git log.

## Files Modified
$(echo "$dirty_files" | sed 's/^../- /')

## Uncommitted Changes
$dirty_count files

## Current Decision
Unknown — context monitor auto-populated git state only.

## Next Step
Unknown — check git log.
WALLETEOF
    fi

    file_mb=$(( file_size / 1048576 ))
    echo "Context at ~${file_mb}MB — wallet card git-state updated." >&2
    exit 0
fi

# --- Elevated: One-time stderr note (once) ---
if [[ "$file_size" -ge "$ELEVATED_THRESHOLD" ]]; then
    [[ -f "$elevated_flag" ]] && exit 0
    touch "$elevated_flag"

    file_mb=$(( file_size / 1048576 ))
    echo "Context at ~${file_mb}MB (~50%)." >&2
    exit 0
fi
```

- [ ] **Step 3: Make executable and verify syntax**

```bash
chmod +x ~/.claude/hooks/context-monitor.sh
bash -n ~/.claude/hooks/context-monitor.sh
```

Expected: No output (valid syntax)

- [ ] **Step 4: Verify eliminated behaviors**

```bash
# Must NOT contain additionalContext
grep -c 'additionalContext' ~/.claude/hooks/context-monitor.sh
# Expected: 0

# Must NOT write to session record
grep -c 'session_file' ~/.claude/hooks/context-monitor.sh
# Expected: 0

# Must NOT contain flock
grep -c 'flock' ~/.claude/hooks/context-monitor.sh
# Expected: 0
```

- [ ] **Step 5: No git commit**

`context-monitor.sh` lives at `~/.claude/hooks/` — outside any git repo. The backup at `.bak-YYYYMMDD` serves as the rollback point.

---

### Task 3: Update PreCompact Hook

**Files:**
- Modify: `~/.claude/hooks/pre-compact.sh` (lines 73-110)

Changes: (1) resolve wallet card path, (2) create minimal wallet card from git state if none exists, (3) update systemMessage to point at wallet card instead of session record.

- [ ] **Step 1: Back up the current hook**

```bash
cp ~/.claude/hooks/pre-compact.sh ~/.claude/hooks/pre-compact.sh.bak-$(date +%Y%m%d)
```

- [ ] **Step 2: Add wallet card path resolution after git capture (after line 64)**

After the git state capture block (lines 56-64), add wallet card resolution and creation:

```bash
# --- Resolve wallet card path ---
wallet_card=""
if [[ -n "$cwd" ]] && git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    wallet_card="$cwd/.claude-task-state.md"
elif [[ -n "$cwd" && "$cwd" == /hddRaid1/ClaudeCodeProjects/* ]]; then
    wallet_card="$cwd/.claude-task-state.md"
else
    wallet_card="$HOME/.claude/task-state.md"
fi

# --- Create minimal wallet card from git state if none exists ---
if [[ ! -f "$wallet_card" ]]; then
    dirty_count=$(echo "$git_status" | wc -l)
    [[ -z "$git_status" ]] && dirty_count=0
    cat > "$wallet_card" << WALLETEOF
---
updated: $(date -Iseconds)
session: $session_id
branch: ${git_branch:-unknown}
---
# Task State

## Current Work
Unknown — check git log.

## Files Modified
$(echo "$git_status" | head -10 | sed 's/^../- /')

## Uncommitted Changes
$dirty_count files

## Current Decision
Unknown — PreCompact auto-populated git state only.

## Next Step
Unknown — check git log.
WALLETEOF
fi
```

- [ ] **Step 3: Replace the systemMessage (lines 106-110)**

Replace the existing `cat <<EOJSON` block at the end of the file with:

```bash
# Output systemMessage pointing to wallet card for post-compaction recovery.
cat <<EOJSON
{
  "systemMessage": "CONTEXT COMPACTION JUST OCCURRED. Read your task state file at: ${wallet_card}\nThen run: git diff --stat && git log --oneline -5\nThese three sources (task state + git diff + git log) reconstruct your working context.\nDo not ask the user what you were doing — the answer is in those sources.\nIf the task state file does not exist or has only git state, rely on git diff and git log.\nResume work unless the user's last message indicates otherwise."
}
EOJSON
```

- [ ] **Step 4: Verify syntax and key behaviors**

```bash
bash -n ~/.claude/hooks/pre-compact.sh
# Expected: No output (valid syntax)

grep -c 'wallet_card' ~/.claude/hooks/pre-compact.sh
# Expected: ≥5 (path resolution + creation + systemMessage)

grep -c 'task-state' ~/.claude/hooks/pre-compact.sh
# Expected: ≥2 (wallet card path references)
```

- [ ] **Step 5: No git commit**

`pre-compact.sh` lives at `~/.claude/hooks/` — outside any git repo. The backup at `.bak-YYYYMMDD` serves as the rollback point.

---

### Task 4: Rewrite Session Workflow Rules

**Files:**
- Rewrite: `~/.claude/rules/session-workflow.md` (148 lines → ~60 lines)

The current file mandates 15-second update cycles, PID tracking, flock coordination, and "after EVERY tool call round" cadence. The new version keeps useful parts (project transitions, lifecycle, MCP limitations) and replaces the panic-driven update model with milestone-only.

- [ ] **Step 1: Back up the current file**

```bash
cp ~/.claude/rules/session-workflow.md ~/.claude/rules/session-workflow.md.bak-$(date +%Y%m%d)
```

- [ ] **Step 2: Write the new session-workflow.md**

Replace the entire file with:

```markdown
# Session Workflow & Records

## Session Record

- Create `SESSION_RECORD_YYYY-MM-DD.md` on session start (or append to existing). Initial entry: session start timestamp, branch, project name.
- Write to it at **milestones**: task completion, commits, errors, decisions, phase boundaries.
- This is an **audit trail**, not a recovery mechanism. Write-only during session.
- Subagents append a summary when they complete (not continuously).

## Recovery: Wallet Card

- Maintain `$PROJECT/.claude-task-state.md` (~30 lines max).
- Update at the same milestones as the session record.
- Contains: current work, files modified, uncommitted changes, current decision, next step.
- This is the **PRIMARY recovery target** after compaction or crash.
- After compaction: read the wallet card, then check `git diff` and `git log`. Those three sources reconstruct full working state.
- Only the master session updates the wallet card. Subagents write to the session record only.

## What NOT to Do

- Do not update the session record on a timer or after every tool call.
- Do not write context monitor entries to the session record.
- Do not include PIDs, process trees, or VM IPs in the session record.
- Do not echo "Session record update: [HH:MM:SS]" — there are no constant updates.
- Do not use flock for session record writes — milestone-only cadence eliminates concurrent write races.

## Session Lifecycle

- **SessionStart** hook: displays project table, sets up session.
- **SessionEnd** hook: creates exit timestamp.
- **PreCompact** hook: captures git state, injects systemMessage pointing to wallet card.
- **Context monitor** hook: observes transcript size, updates wallet card once at High level (~5 MB).

## Where Session Records Go

- **In a project**: `PROJECT_ROOT/SESSION_RECORD_YYYY-MM-DD.md`
- **No project**: `~/.claude/session-records/SESSION_RECORD_YYYY-MM-DD.md`

## No-Project → Project Transitions

1. **"open ProjectA"**: Log switch in no-project record, start project-level record.
2. **Returning to general work**: Log switch back in no-project record.
3. **"open ProjectB"** (switching): Close ProjectA's record, log switch, start ProjectB's.
4. The no-project record is the anchor — it stitches the full session across project hops.

## "open [project]"

Immediately `cd` to `/hddRaid1/ClaudeCodeProjects/[ProjectName]/` AND update `~/.claude/.current_project`. The hook cannot change cwd (subprocess limitation), so Claude must do it explicitly.

## STAY IN PROJECT

Once inside a project directory, never change cwd unless explicitly asked or opening a different project.

## MCP Plugin Limitations

MCP servers connect at startup and cannot be hot-swapped mid-session.
- **"open \<project\>" in-session**: Updates settings for NEXT session. Suggest `ccp <project>` if MCPs matter.
- **cd-ing between projects**: Has no MCP management. Always use "open \<project\>".
- **`ccp` launcher**: Toggles MCPs BEFORE launching Claude.

## Claude.ai Skill Upload

- File must have YAML frontmatter with `name` and `description` fields
- Name: lowercase letters, numbers, hyphens only. Cannot contain "claude" — use "cc".

## Test-Skill Project

The `/test` skill lives in `/hddRaid1/ClaudeCodeProjects/claude-test-skill/` with symlinks to `~/.claude/`:
- `~/.claude/commands/test.md` -> project's `commands/test.md`
- `~/.claude/skills/test-phases/` -> project's `skills/test-phases/` (directory symlink)
- When adding NEW command files, create corresponding symlink.
```

- [ ] **Step 3: Verify key behaviors are eliminated**

```bash
# Must NOT contain "every tool call"
grep -ci 'every tool call' ~/.claude/rules/session-workflow.md
# Expected: 0

# Must NOT contain "15 second"
grep -ci '15 second' ~/.claude/rules/session-workflow.md
# Expected: 0

# Must NOT contain "flock"
grep -ci 'flock' ~/.claude/rules/session-workflow.md
# Expected: 0

# Must NOT contain PID tracking
grep -ci 'PID.*PPID\|CPID\|process info' ~/.claude/rules/session-workflow.md
# Expected: 0

# MUST contain wallet card
grep -ci 'wallet card' ~/.claude/rules/session-workflow.md
# Expected: ≥3
```

- [ ] **Step 4: No git commit**

`session-workflow.md` lives at `~/.claude/rules/` — outside any git repo. The backup at `.bak-YYYYMMDD` serves as the rollback point.

---

### Task 5: Update CLAUDE.md Line 5

**Files:**
- Modify: `~/.claude/CLAUDE.md:5` (one line change)

- [ ] **Step 1: Update the session records principle**

Change line 5 from:
```
3. **SESSION RECORDS** — The FIRST action on project open: create/update `SESSION_RECORD_YYYY-MM-DD.md` with PIDs, then maintain every ~3 minutes. Before any other work. See `rules/session-workflow.md`.
```

To:
```
3. **SESSION RECORDS** — On session start: create `SESSION_RECORD_YYYY-MM-DD.md` and wallet card (`.claude-task-state.md`). Update both at milestones. See `rules/session-workflow.md`.
```

- [ ] **Step 2: Verify**

```bash
grep 'SESSION RECORDS' ~/.claude/CLAUDE.md
# Expected: Shows "wallet card" and "milestones", NOT "PIDs" or "every ~3 minutes"
```

- [ ] **Step 3: No git commit**

`~/.claude/CLAUDE.md` is outside any git repo.

---

### Task 6: Update Close Command — Wallet Card Cleanup

**Files:**
- Modify: `~/.claude/commands/close.md` (Step 6, lines 166-217)

Two changes: (1) remove flock from session record finalization, (2) add wallet card cleanup before the closing entry.

- [ ] **Step 1: Replace Step 6 flock-based write with simple append**

In `~/.claude/commands/close.md`, replace the flock block (lines 189-201) with a direct append:

```bash
    # Write closing entry (no flock needed — milestone-only writes)
    {
        echo ""
        echo "### [$timestamp] SESSION CLOSED"
        echo "- Branch: \`$branch\`"
        echo "- Last commit: $last_commit"
        echo "- Uncommitted files at close: $uncommitted"
        echo "- Session closed via /close"
        echo ""
    } >> "$session_file"
```

- [ ] **Step 2: Add wallet card cleanup before the closing entry**

Insert AFTER `$PROJECT_DIR` is set (after line 172) but BEFORE the session record closing entry (before the `if [[ -f "$session_file" ]]` check at line 182):

```bash
# Update wallet card with closed state
wallet_card="$PROJECT_DIR/.claude-task-state.md"
if [[ -f "$wallet_card" ]]; then
    cat > "$wallet_card" << WALLETEOF
---
updated: $(date -Iseconds)
session: closed
branch: $(git -C "$PROJECT_DIR" branch --show-current 2>/dev/null || echo "unknown")
---
# Task State

## Current Work
Session closed normally.

## Next Step
No pending work.
WALLETEOF
    echo "✓ Wallet card: marked as closed"
fi
```

- [ ] **Step 3: Verify no flock remains**

```bash
grep -c 'flock' ~/.claude/commands/close.md
# Expected: 0
```

- [ ] **Step 4: No git commit**

`close.md` lives at `~/.claude/commands/` — outside any git repo.

---

### Task 7: Update Customization Manifest

**Files:**
- Modify: `~/.claude/customization-manifest.md` (lines 36-41, Hooks section)

- [ ] **Step 1: Add context-monitor and pre-compact entries to Hooks table**

After the `prompt-dispatcher.sh` row (line 41), add:

```markdown
| context-monitor.sh | `~/.claude/hooks/context-monitor.sh` | Graduated transcript size observer (3/5/7 MB). Updates wallet card at High, silent at Critical | CC adds built-in context pressure awareness |
| pre-compact.sh | `~/.claude/hooks/pre-compact.sh` | Captures git state before compaction, injects systemMessage pointing to wallet card | CC adds built-in pre/post-compaction state preservation |
```

- [ ] **Step 2: Update the session-workflow entry in Custom Rules**

Change the session records row (line 17) to reflect milestone-only:

```markdown
| Session records | `rules/session-workflow.md` | Milestone-only audit trail + wallet card recovery. PreCompact hook + git state provide three-source recovery | CC makes sessions reliable + adds persistent decision logging |
```

- [ ] **Step 3: No git commit**

`customization-manifest.md` lives at `~/.claude/` — outside any git repo.

---

### Task 8: Delete Contaminated Memory Files

**Files:**
- Delete: `~/.claude/projects/-hddRaid1-ClaudeCodeProjects-Audiobook-Manager/memory/feedback_session_record_frequency.md`
- Modify: `~/.claude/projects/-hddRaid1-ClaudeCodeProjects-Audiobook-Manager/memory/MEMORY.md` (lines 36-37)

- [ ] **Step 1: Delete the feedback file**

```bash
rm ~/.claude/projects/-hddRaid1-ClaudeCodeProjects-Audiobook-Manager/memory/feedback_session_record_frequency.md
```

- [ ] **Step 2: Remove the MEMORY.md index entry for deleted file**

In the Audiobook-Manager `MEMORY.md`, find and remove the line referencing `feedback_session_record_frequency.md`.

- [ ] **Step 3: Update MEMORY.md lines 36-37 — remove old cadence rules**

Replace:
```markdown
- **ALWAYS update SESSION_RECORD before calling ExitPlanMode** — user requires this every time, no exceptions
- **Session record update cadence: every tool call round (~30-60s)** — NOT every 3 minutes. Crashes (GPU VRAM, OOM, power) kill without warning. 2026-02-25 incident lost all post-commit context because updates stopped after milestone.
```

With:
```markdown
- **Session records**: milestone-only audit trail. Wallet card (`.claude-task-state.md`) is the primary recovery target.
```

- [ ] **Step 4: Check feedback_btrfs_snapshots.md for session record language**

```bash
grep -n 'session record' ~/.claude/projects/-hddRaid1-ClaudeCodeProjects-Audiobook-Manager/memory/feedback_btrfs_snapshots.md
```

If it contains "Log the snapshot in the session record", remove that line.

- [ ] **Step 5: Verify deleted file is gone**

```bash
ls ~/.claude/projects/-hddRaid1-ClaudeCodeProjects-Audiobook-Manager/memory/feedback_session_record_frequency.md 2>&1
# Expected: "No such file or directory"
```

- [ ] **Step 6: Commit**

This is outside the test-skill repo, so no git commit here. The changes are to `~/.claude/` memory files.

---

### Task 9: Check Plan Files for Old References

**Files:**
- Check: `~/.claude/plans/mutable-churning-allen.md`
- Check: `~/.claude/plans/calm-hopping-thunder.md`

- [ ] **Step 1: Check mutable-churning-allen.md**

```bash
grep -ni 'session.record\|flock\|every tool call\|15 second\|session-workflow' ~/.claude/plans/mutable-churning-allen.md
```

If matches found referencing old session workflow patterns, update or add a note that the session workflow was redesigned per the context retention spec.

- [ ] **Step 2: Check calm-hopping-thunder.md**

```bash
grep -ni 'flock\|session.record.*cadence\|every tool call' ~/.claude/plans/calm-hopping-thunder.md
```

The `fcntl.flock` reference is expected to be Python-specific (unrelated to bash session record flock). Verify and leave alone if so.

- [ ] **Step 3: Commit any plan file updates**

Only if changes were made.

---

### Task 10: End-to-End Verification

- [ ] **Step 1: Verify all eliminated behaviors**

```bash
# Context monitor: no additionalContext, no session record writes, no flock
echo "=== context-monitor.sh ==="
grep -c 'additionalContext' ~/.claude/hooks/context-monitor.sh  # Expected: 0
grep -c 'session_file' ~/.claude/hooks/context-monitor.sh       # Expected: 0
grep -c 'flock' ~/.claude/hooks/context-monitor.sh              # Expected: 0

# Session workflow: no timers, no PIDs, no flock
echo "=== session-workflow.md ==="
grep -ci 'every tool call' ~/.claude/rules/session-workflow.md   # Expected: 0
grep -ci '15 second' ~/.claude/rules/session-workflow.md         # Expected: 0
grep -ci 'flock' ~/.claude/rules/session-workflow.md             # Expected: 0

# Close: no flock
echo "=== close.md ==="
grep -c 'flock' ~/.claude/commands/close.md                      # Expected: 0

# CLAUDE.md: no PIDs, no timer
echo "=== CLAUDE.md ==="
grep 'SESSION RECORDS' ~/.claude/CLAUDE.md | grep -c 'PID'      # Expected: 0
grep 'SESSION RECORDS' ~/.claude/CLAUDE.md | grep -c 'minutes'  # Expected: 0
```

- [ ] **Step 2: Verify wallet card integration**

```bash
# PreCompact hook references wallet card
grep -c 'wallet_card\|task-state' ~/.claude/hooks/pre-compact.sh  # Expected: ≥5

# Context monitor references wallet card
grep -c 'wallet_card\|task-state' ~/.claude/hooks/context-monitor.sh  # Expected: ≥3

# Session workflow mentions wallet card
grep -ci 'wallet card' ~/.claude/rules/session-workflow.md  # Expected: ≥3

# Close command handles wallet card
grep -c 'wallet_card\|task-state' ~/.claude/commands/close.md  # Expected: ≥2
```

- [ ] **Step 3: Verify context-monitor.sh runs without errors on mock input**

```bash
echo '{"cwd":"/tmp","transcript_path":"/dev/null","session_id":"test123"}' | bash ~/.claude/hooks/context-monitor.sh
echo "Exit code: $?"
# Expected: Exit code: 0 (transcript is 0 bytes, below threshold, exits cleanly)
```

- [ ] **Step 4: Verify pre-compact.sh runs without errors on mock input**

```bash
tmpdir=$(mktemp -d)
echo '{"cwd":"'"$tmpdir"'","transcript_path":"/dev/null","session_id":"test123","trigger":"manual"}' | bash ~/.claude/hooks/pre-compact.sh 2>/dev/null
echo "Exit code: $?"
rm -rf "$tmpdir"
# Expected: Exit code: 0, outputs JSON with systemMessage containing wallet_card/task-state path
```

- [ ] **Step 5: Final commit**

```bash
git commit -m "chore: context retention architecture — implementation complete

Implements brain-inspired context retention redesign per spec
2026-03-22-context-retention-design.md. Replaces feedback-loop-prone
session record system with distributed wallet card + milestone-only
architecture."
```

---

## Success Criteria Checklist

After all tasks complete, verify against spec success criteria:

| # | Criterion | How to verify |
|---|-----------|---------------|
| 1 | Session records < 200 lines for normal session | Run a session, check line count |
| 2 | No context monitor entries in session records | `grep -c 'CONTEXT MONITOR' SESSION_RECORD_*.md` = 0 |
| 3 | No feedback loops | `grep -c 'additionalContext' ~/.claude/hooks/context-monitor.sh` = 0 |
| 4 | Recovery after compaction < 30s | Observe next compaction event |
| 5 | Context monitor invisible < 3 MB | Normal sessions produce no stderr from hook |
| 6 | "flock" not in session-workflow.md | `grep -c flock ~/.claude/rules/session-workflow.md` = 0 |

Criteria 1, 2, 4, 5 can only be fully verified in subsequent sessions. The implementation ensures they will pass by eliminating the root causes.
