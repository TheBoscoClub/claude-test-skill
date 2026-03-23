# Session Context Layer — Conversation Memory That Survives

**Date**: 2026-03-22
**Status**: Draft — pending review
**Scope**: `~/.claude/` hooks, rules, commands; per-project ephemeral files
**Builds on**: Context Retention Architecture spec (2026-03-22)

## Problem

The context retention redesign (wallet card + milestone-only session records + graduated context monitor) solved the bloat and feedback loop problems, but left a critical gap: **cumulative reasoning chains built over the course of a session are lost when compaction fires or the session dies.**

The wallet card captures *what* Claude is doing and *what's next*. Git captures *what changed*. But neither captures *why* — the chain of small, incremental decisions made during hours of discussion that shape the ultimate solution. These are the hardest losses to recover from because:

- They're cumulative and interconnected — each decision builds on previous ones
- The user often can't reconstruct them alone — some were Claude's own discoveries during code exploration
- Loss is frequently **silent** — Claude continues confidently in a wrong direction without knowing what it's forgotten
- The user doesn't realize context was lost until output diverges, requiring work to be undone

### User-reported loss severity (worst to least-bad)

1. **Decisions made together** (conversation context) — earlier decisions, preferences, constraints discussed and agreed upon
2. **Progress in multi-step plans** — where in a 10-step plan, what's done vs. pending
3. **Approach/reasoning** — why approach A was chosen over B, what was explored and ruled out
4. **Current task** (least-bad) — already well-covered by the wallet card

### Recovery patterns observed

- **Typical**: User cannot fully reconstruct the chain (Claude's discoveries are lost), then Claude silently diverges
- **Occasional**: Claude goes off in a wrong direction post-compaction; user doesn't notice until output is wrong
- **Rare**: User re-explains key decisions and Claude recovers (only works for simple chains)

## Design Principles

1. **Write early, when it's cheap.** Context is most valuable when the transcript is small and writing costs nothing. By the time compaction is imminent, the context should already be externalized.
2. **Visible summaries serve two purposes.** They align Claude and the user in real time (catching misunderstandings before they compound) AND create the recovery record as a byproduct.
3. **Completed work gets purged, not compressed.** The context file carries only the active reasoning chain. Finished work lives in git. The file stays small naturally.
4. **The ring buffer captures reality.** A fixed-size trailing window of raw session I/O survives every failure mode and provides ground truth when curated sources are stale or missing.
5. **Recovery is structurally enforced, not behavioral.** Hooks gate Claude's post-compaction actions — recovery can't be forgotten or skipped.

## Architecture

### Component 1: Session Context File (`$PROJECT/.claude-session-context.md`)

Externalized conversation memory — the cumulative chain of decisions, reasoning, and understanding that shapes the current work. Maintained by Claude as **visible conversation output**, then persisted to disk.

**Format:**

```markdown
---
updated: 2026-03-22T19:30:00
session: 7c83b07e
branch: main
ppid: 48291
pid: 48295
cpids: [48301, 48305]
tty: /dev/pts/3
active_work: "Redesigning auth middleware — session token storage"
---

## Active Context

### Approach & Reasoning
- [Cumulative chain of decisions and why each was made]
- [What was explored and ruled out, and why]

### Key Decisions
- [Specific decisions reached during discussion]
- [Constraints the user stated]

### Plan Progress
- [x] Completed steps
- [ ] Current step ← CURRENT
- [ ] Pending steps

### User Preferences (this session)
- [Communication preferences, testing approach, etc.]
```

**Frontmatter fields:**

| Field | Source | Purpose |
|-------|--------|---------|
| `updated` | Claude (at each checkpoint) | Staleness detection |
| `session` | SessionStart hook | Session identity — detect crashed sessions |
| `branch` | SessionStart hook / Claude | Git branch context |
| `ppid` | SessionStart hook (`$PPID`) | Parent process ID — find orphaned sessions |
| `pid` | SessionStart hook (`$$`) | Claude Code process ID |
| `cpids` | Claude (updated when spawning subagents) | Child process IDs |
| `tty` | SessionStart hook (`tty` command) | Terminal — distinguish orphaned vs. active sessions |
| `active_work` | Claude (at each checkpoint) | One-line summary of current task |

**Lifecycle rules:**

- **Created**: By SessionStart hook (frontmatter with process identity) on every session launch — both `claude` CLI and `ccp` menu. This is code, not a behavioral rule.
- **Updated**: Claude writes a visible context checkpoint, then persists it to this file. Updates happen after meaningful exchanges, at transition points, or when either party triggers it.
- **Purged**: When a chunk of work is completed (committed, tested, done), its entries are removed. Only the active reasoning chain remains.
- **At session end (`/close`)**: File is cleared or deleted.
- **Crash recovery**: If a new session finds a context file from a different session ID, the previous session died — read it as recovery source, then check if old PID/TTY is still alive.

**Size**: Should naturally stay under ~60 lines because completed work gets pruned. Growth past that signals entries aren't being purged.

**`.gitignore`'d** — ephemeral working state.

### Component 2: Visible Context Checkpoints

Claude produces brief "here's where we are" summaries as **visible conversation output**. These serve dual purpose: real-time alignment check AND recovery record.

**Format:**

```
⟡ Context checkpoint ─────────────────────────
We're building [X]. Approach: [Y] because [Z]. Ruled out [W]
because [reason]. Current step: [step]. Key constraint from
user: [constraint].
───────────────────────────────────────────────
```

The `⟡` delimited block is the canonical format — visually distinct from normal conversation output so the user can spot checkpoints when scrolling back. If Claude Code ever supports colored terminal output in conversation, light green is the target color.

**Trigger conditions (any of these):**

| Trigger | Example |
|---------|---------|
| Claude's understanding shifts | User clarifies a constraint, Claude realizes a different approach is needed |
| Decision reached | "Let's go with approach B" — capture what was decided and why |
| Transition point | Finishing one task, starting the next |
| Exploration reveals something | Claude found something in the codebase that changes the plan |
| User asks | "What do you think I meant?" / "Checkpoint this" / "Where are we?" |
| Claude offers | After a complex exchange where misunderstanding risk is high |

**What a checkpoint is NOT:**

- Not a status update ("I just edited file X") — that's the session record
- Not a progress report ("3 of 7 tests passing") — that's test output
- Not a recap of the full conversation — just the active reasoning chain
- Not on a timer — driven by conversation dynamics

**After producing the visible checkpoint**, Claude writes/updates the session context file on disk. The visible output and the file stay in sync because Claude always shows the user what it's about to persist.

**If the user corrects the checkpoint** ("No, we decided X not Y"), Claude updates both its understanding and the file.

### Component 3: Ring Buffer (`$PROJECT/.claude-session-ring.jsonl`)

A fixed-size trailing window of raw session I/O. Always on disk, always current at the byte level. Survives every failure mode including hard system crashes.

**Mechanics:**

```bash
# In PostToolUse hook (context-monitor.sh):
ring_file="$PROJECT/.claude-session-ring.jsonl"
tail -c 131072 "$transcript_path" > "$ring_file"   # 128 KB
```

`tail -c` is a single seek + read on the transcript JSONL — near-zero cost per invocation.

**Size:** 128 KB default, configurable via variable in `context-monitor.sh`. Starting conservative — can be tuned upward based on real recovery experience. Value logged alongside compaction sizes in `compaction-sizes.log` for empirical tuning.

**Reading the ring buffer post-compaction:** Claude filters for user and assistant message entries only, skipping tool call results (which are the bulk of JSONL volume). 128 KB of raw JSONL yields approximately 20-40 KB of actual conversation content after filtering.

**Lifecycle:**

| Event | Ring buffer action |
|-------|-------------------|
| Session start | Created empty (or existing one from crashed session is recovery source) |
| Every tool call | Updated via `tail -c 131072` — always current |
| `/close` | Deleted alongside context file |
| Crash / kill | Stays on disk — recovery source for next session |
| `--continue` / `--resume` | Read as part of recovery if stale session detected |

**`.gitignore`'d** — ephemeral session data.

### Component 4: Compaction Detection and Recovery Gate

Post-compaction recovery is **structurally enforced** via hook-based gating, not dependent on behavioral rules that Claude might ignore.

**Mechanism: Flag-based compaction detection with belt-and-suspenders injection.**

```
Step 1: PreCompact fires (documented, supported hook)
  → Writes flag file: ~/.claude/cache/compaction-pending-{session_id}
  → Logs transcript size to calibration file
  → Writes audit entry to session record

Step 2: Compaction occurs

Step 3: Claude's first post-compaction action triggers a hook
  EITHER PostToolUse (if Claude uses a tool first)
  OR UserPromptSubmit (if user types first)
  → Hook checks for compaction-pending flag
  → If found: injects additionalContext with recovery instructions
  → Deletes flag (one-shot — no feedback loop possible)

Step 4: Claude reads recovery sources in order:
  1. Session context file (curated reasoning chain)
  2. Wallet card (task skeleton)
  3. Ring buffer (raw recent conversation, messages only)
  4. git diff --stat && git log --oneline -5 (actual changes)

Step 5: Claude outputs recovery checkpoint:
  ⟡ Recovery checkpoint ────────────────────────
  Recovered from compaction. [summary of active work,
  key decisions, current approach]. Correct?
  ───────────────────────────────────────────────

Step 6: User confirms or corrects
  → Claude updates context file if corrections needed
  → Work resumes
```

**The `additionalContext` injection (exact text):**

```
COMPACTION JUST OCCURRED. Before doing anything else:
1. Read .claude-session-context.md (your curated reasoning chain — decisions, approach, preferences)
2. Read .claude-task-state.md (task skeleton — current work, files, next step)
3. Read .claude-session-ring.jsonl (raw recent conversation — filter for user/assistant messages, skip tool results)
4. Run: git diff --stat && git log --oneline -5
5. Output a recovery checkpoint (⟡ Recovery checkpoint) confirming what you recovered.
   Wait for user confirmation before proceeding.
Do not ask the user what you were doing. Do not proceed until the user confirms.
```

**Why this is reliable:**

- PreCompact writes the flag — this is code, not a rule. It runs regardless of Claude's state.
- PostToolUse and UserPromptSubmit both check for the flag — whichever fires first handles recovery.
- The flag is consumed (deleted) after injection — no feedback loop, no repeated injection.
- The injection is `additionalContext`, which enters Claude's context window — not a display-only message.
- The recovery checkpoint requires user confirmation — catches silent divergence.

**Why PreCompact's `systemMessage` output is NOT used:**

PreCompact and PostCompact hook events cannot inject context into Claude's context window. Their `systemMessage` output is displayed to the user as a warning, not fed to Claude. The actual injection must happen via hooks that support `additionalContext`: PostToolUse or UserPromptSubmit.

### Component 5: Mandatory Session Initialization

The session context file is created at the start of every session, regardless of launch method. This is structurally guaranteed, not a behavioral rule.

**Enforcement layers:**

| Layer | Mechanism | Guarantee level |
|-------|-----------|----------------|
| SessionStart hook | Creates file with frontmatter (PIDs, TTY, session ID) | Code — always runs |
| Workflow rules | Instructs Claude that context file is mandatory | Behavioral — reinforcement |
| CLAUDE.md | Lists context file alongside session record and wallet card | Behavioral — reinforcement |
| PreCompact hook | Creates minimal context file if one doesn't exist at compaction time | Code — safety net |

**SessionStart hook additions:**

1. Create `$PROJECT/.claude-session-context.md` with frontmatter (session ID, PIDs, TTY, branch, empty `active_work`).
2. If a context file already exists:
   - Same session ID → resume (preserve it — recovery from compaction within same session)
   - Different session ID, `session: closed` → previous session ended cleanly, overwrite with fresh frontmatter
   - Different session ID, NOT closed → previous session died. Preserve as recovery source. Claude reads it on first interaction, then decides whether to continue that work or start fresh.
3. Create empty ring buffer file (`$PROJECT/.claude-session-ring.jsonl`).

**First checkpoint obligation:**

After session initialization, Claude must produce a visible context checkpoint within its first substantive response:
- **New session**: Confirms what the user wants to work on
- **Resumed session** (context file has content): Recovery checkpoint confirming what was recovered
- **Crashed session detected** (context file from different session, not closed): Recovery checkpoint from previous session's state + check if old PID/TTY is still alive

### Component 6: Integration with Existing Components

**Wallet Card** — gains one new line:

```markdown
## Session Context
→ .claude-session-context.md
```

Wallet card stays ~30 lines. Points to the context file for the full story.

**Context Monitor (`context-monitor.sh`)** — gains two additions:

1. Ring buffer update on every PostToolUse call (regardless of transcript size level)
2. Compaction flag detection: check for `compaction-pending-{session_id}`, inject `additionalContext` if found, delete flag

The existing graduated thresholds (Normal → Elevated → High → Critical) remain unchanged. The ring buffer update is independent of threshold level — it always runs because it's nearly free.

**PreCompact Hook (`pre-compact.sh`)** — gains one addition:

1. Write compaction flag file: `~/.claude/cache/compaction-pending-{session_id}`

Existing behavior (audit entry to session record, calibration logging, minimal wallet card creation) remains unchanged. The `systemMessage` JSON output is kept for user-facing display but is understood to NOT inject into Claude's context.

**UserPromptSubmit Hook (`prompt-dispatcher.sh`)** — gains one addition:

1. Compaction flag detection: same logic as context-monitor.sh — check for flag, inject `additionalContext`, delete flag. Belt-and-suspenders with PostToolUse.

**`/close` Command** — gains additions:

1. Delete `.claude-session-context.md` (or clear to frontmatter-only with `session: closed`)
2. Delete `.claude-session-ring.jsonl`

**Session Workflow Rules (`session-workflow.md`)** — updated to include:

- Session context file creation and checkpoint obligations
- Ring buffer existence (for awareness, not behavioral enforcement)
- Recovery flow description

**CLAUDE.md** — Line 5 updated to include session context file alongside session record and wallet card.

**Gitignore template (`~/.claude/templates/gitignore-claude`)** — add:

```
# Session context — conversation memory for context recovery
.claude-session-context.md
# Ring buffer — trailing I/O window for crash/compaction recovery
.claude-session-ring.jsonl
```

### Component 7: Purging and Active Chain Management

The session context file carries only the **active reasoning chain**. Completed work is purged — the result lives in git.

**Purge triggers:**

| Trigger | What gets purged | What remains |
|---------|-----------------|--------------|
| Commit | Entries for the committed work | Active chain for uncommitted/in-progress work |
| Task completion | Completed task's reasoning chain | Next task's emerging chain |
| User says "that's done" | Everything for the finished topic | Fresh slate |
| `/close` | Entire file | Nothing — next session is clean |

**Purging is accompanied by a visible checkpoint:**

```
⟡ Context checkpoint ─────────────────────────
Auth middleware done and committed (abc1234). Purging that context.
Starting fresh: next up is CSRF protection. No decisions made yet.
───────────────────────────────────────────────
```

**Multiple concurrent chains:** If implementation work and an unrelated debugging sidetrack are both active, each gets its own section under `## Active Context`. When one resolves, it's purged independently.

**Empty state:** File exists with frontmatter only. `active_work` field is empty. Claude's first context checkpoint populates it when real work begins.

## Recovery Scenarios (Complete)

### After Auto-Compaction

1. PreCompact fires → writes compaction flag + audit entry
2. Compaction occurs → context window compressed
3. Claude's first post-compaction action triggers PostToolUse or UserPromptSubmit
4. Hook sees compaction flag → injects `additionalContext` with recovery instructions → deletes flag
5. Claude reads: session context file → wallet card → ring buffer (messages only) → git state
6. Claude outputs recovery checkpoint → user confirms or corrects
7. Work resumes with validated context

### After Kill / Ctrl+C / Suspend

1. No hooks fire. Session dies.
2. Session context file is on disk (last checkpoint state)
3. Ring buffer is on disk (last tool call state — more current than context file)
4. Wallet card is on disk (last milestone state)
5. New session starts → SessionStart hook sees context file from different session, not closed
6. Claude reads previous session's recovery files, checks if old PID/TTY is still alive
7. If old process alive: "Previous session (PID X, pts/Y) still running. Resume or kill?"
8. If dead: recovery checkpoint from files → user confirms → work resumes

### After System Crash / Power Loss

Same as kill, with BTRFS copy-on-write protecting file integrity. Files may be slightly stale (last hook invocation, not last thought) but ring buffer covers the gap.

### After `/close`

1. Context file cleared, ring buffer deleted, wallet card set to "closed"
2. Next session: clean start, no recovery needed
3. SessionStart hook creates fresh context file, Claude checkpoints when work begins

### After Crash Before First Checkpoint

1. Context file exists (SessionStart hook created it) but has no Active Context section
2. Ring buffer may have some content if any tool calls were made
3. Wallet card may not exist yet (no milestones reached)
4. Recovery: Claude reads whatever exists, falls back to `git diff --stat` and `git log --oneline -10`
5. Creates first checkpoint from what it can determine

## Complete File Inventory

| File | Max Size | Updated by | Survives crash? | Purpose |
|------|----------|-----------|----------------|---------|
| `.claude-session-context.md` | ~60 lines | Claude (visible checkpoints) + SessionStart hook (frontmatter) | Yes | Curated reasoning chain — the thinking |
| `.claude-task-state.md` | ~30 lines | Claude (milestones) + hooks (git state) | Yes | Emergency skeleton — the what |
| `.claude-session-ring.jsonl` | 128 KB | PostToolUse hook (automated, every call) | Yes | Raw recent conversation — the reality |
| `SESSION_RECORD_*.md` | < 200 lines | Claude (milestones) | Yes | Audit trail — the history |
| Git state | N/A | Git | Yes | Ground truth — the actual changes |

## Files Modified by This Spec

| File | Action | Detail |
|------|--------|--------|
| `~/.claude/hooks/context-monitor.sh` | **Update** | Add ring buffer update + compaction flag detection with `additionalContext` injection |
| `~/.claude/hooks/pre-compact.sh` | **Update** | Add compaction flag file write. Keep existing `systemMessage` for user display. |
| `~/.claude/hooks/session-start.sh` | **Update** | Add session context file creation with frontmatter (PIDs, TTY). Add ring buffer creation. Detect crashed sessions. |
| `~/.claude/hooks/prompt-dispatcher.sh` | **Update** | Add compaction flag detection with `additionalContext` injection (belt-and-suspenders with PostToolUse) |
| `~/.claude/rules/session-workflow.md` | **Update** | Add session context file and ring buffer to session lifecycle. Add checkpoint obligations. |
| `~/.claude/CLAUDE.md` | **Update** | Line 5: add session context file alongside session record and wallet card |
| `~/.claude/commands/close.md` | **Update** | Add context file and ring buffer cleanup |
| `~/.claude/templates/gitignore-claude` | **Update** | Add `.claude-session-context.md` and `.claude-session-ring.jsonl` |
| Per-project `.gitignore` files | **Update** | Add same entries |

### Files NOT Changed

- `~/.claude/hooks/session-end.sh` — Lightweight exit timestamps, no changes needed
- Wallet card format — Only addition is one pointer line to context file
- Context monitor thresholds — Graduated response unchanged (Normal/Elevated/High/Critical)
- Session record role — Still milestone-only audit trail

## Success Criteria

1. Session context file is created on every session start (structurally guaranteed by SessionStart hook)
2. Visible context checkpoints appear in conversation at natural transition points
3. Ring buffer is always within one tool call of current (128 KB trailing window)
4. After compaction, Claude reads recovery sources automatically (enforced by flag + `additionalContext` injection)
5. Post-compaction recovery checkpoint is shown to user for confirmation before Claude proceeds
6. Completed work is purged from context file — file stays under ~60 lines during normal operation
7. After kill/crash, next session detects the orphaned state and offers recovery
8. No feedback loops — compaction flag is consumed (deleted) after single injection
9. Ring buffer size and recovery quality logged for empirical tuning
