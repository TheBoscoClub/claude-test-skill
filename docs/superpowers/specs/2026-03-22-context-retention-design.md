# Context Retention Architecture — Brain-Inspired Redesign

**Date**: 2026-03-22
**Status**: Approved for implementation
**Scope**: `~/.claude/` hooks, rules, commands, and memory files

## Problem

Claude Code has no built-in context management or retention system. When auto-compaction fires or the process crashes, Claude loses its working state. The user built a local safety net (session records, context-monitor hook, PreCompact hook, session-workflow rules) that evolved over months of incident-driven iteration.

The safety net swung too far: the context-monitor hook fires on every tool call, writes to the session record with no cooldown at CRITICAL level, and injects `additionalContext` that creates a feedback loop — Claude writes to the session record, which triggers the hook, which tells Claude to write again. The session record becomes a 5,000+ line file dominated by duplicate monitor entries, consuming the very context it was trying to protect.

### Community Context

This is not a unique problem. Issue [#17428](https://github.com/anthropics/claude-code/issues/17428) (104 reactions, 39 comments, assigned to Anthropic engineer `rboyce-ant` but no response in 70+ days) is the community focal point. At least 16 independent tools/scripts have been built by users to work around the same gap. Anthropic has not acknowledged, committed to, or shipped any solution.

Key community tools referenced in this design:
- **Cozempic** (Ruya-AI): session bloat pruning before compaction
- **Mnemon** (mnemon-dev): SQLite graph memory with lifecycle hooks
- **yurukusa's graduated thresholds**: 40/25/20/15% warnings with mission.md pattern
- **murias002's multi-layer recovery**: PreCompact + SessionStart + CLAUDE.md markers

## Design Principle: Brain Analogy

A person at risk of stroke doesn't write a journal entry every 15 seconds. The brain protects itself through:

| Brain Mechanism | System Equivalent |
|---|---|
| Distributed memory (hippocampus, cortex, cerebellum) | Multiple independent recovery sources, not one monolithic file |
| Consolidation during idle, not under pressure | Update at milestones, not on timers or under context pressure |
| Small emergency card (name, meds, contacts) | Wallet card: ~20 lines of structured recovery state |
| Redundancy across regions | Wallet card + git state + session record = three independent sources |
| Prioritize what to protect (motor skills survive strokes) | Protect: current task, files touched, next step. Drop: PIDs, timestamps, duplicate entries |
| Goes quiet under extreme pressure (not louder) | Context monitor goes silent at CRITICAL, trusts PreCompact |

## Architecture

### Component 1: Wallet Card (`$PROJECT/.claude-task-state.md`)

The primary recovery target. Small, structured, machine-readable. Updated at milestones only.

**Format:**
```markdown
---
updated: 2026-03-22T14:52:00
session: 7c83b07e
branch: main
---
# Task State

## Current Work
[1-2 sentences describing active task]

## Files Modified
- [file paths touched this session]

## Uncommitted Changes
[count] files ([brief list])

## Current Decision
[active decision or blocker, if any]

## Next Step
[what to do after compaction/crash recovery]
```

**Rules:**
- Maximum 30 lines (including frontmatter and headers). Longer = wrong.
- **Creation**: Claude creates the wallet card as part of session initialization, immediately after the session record. If the project already has a wallet card from a previous session, Claude overwrites it with fresh state.
- Updated by Claude at milestones: task completion, commit, error, decision point, phase boundary.
- YAML frontmatter for metadata (timestamp, session ID, branch).
- `.gitignore`'d — add `.claude-task-state.md` to both `~/.claude/templates/gitignore-claude` (global template) and each project's `.gitignore`. Ephemeral working state, not project content.
- PreCompact hook points recovery at THIS file, not the session record.
- "Files Modified" and "Uncommitted Changes" capture intent. `git diff` provides the actual diff.
- For no-project sessions: `~/.claude/task-state.md` (same format).
- **Only the master session updates the wallet card.** Subagents write to the session record only. The wallet card is a fixed-structure file (not append-only), so concurrent subagent writes would clobber each other.
- **If no wallet card exists at PreCompact time** (e.g., crash before first milestone), the PreCompact hook creates a minimal wallet card from git state only (branch, uncommitted files, recent commits). Semantic fields (Current Work, Next Step) are left as "Unknown — check git log."

### Component 2: Context Monitor (`~/.claude/hooks/context-monitor.sh`)

Observes transcript size. Graduated response. Goes silent under extreme pressure.

**Thresholds** (calibrated from `compaction-sizes.log` — compaction fires at 1.4–12 MB transcript file size, median ~6–7 MB).

All thresholds are measured on raw transcript JSONL file size via `stat -c%s`, the same mechanism the current hook uses. The current thresholds (600 KB / 800 KB) were set before calibration data existed and are 5-10x too low — they trigger panic mode at ~10% of actual compaction distance. The new thresholds are intentionally higher, based on observed compaction behavior:

| Level | Transcript File Size | Action |
|---|---|---|
| Normal | < 3 MB | Nothing |
| Elevated | 3–5 MB | One-time stderr note: "Context at ~50%." No file writes. Cooldown: never repeats. |
| High | 5–7 MB | Updates wallet card git-state fields once (branch, uncommitted files, recent commits). Does NOT populate semantic fields (Current Work, Next Step) — those are Claude's responsibility. Does NOT write to session record. Cooldown: never repeats. |
| Critical | > 7 MB | **Silent.** No writes, no injection, no additionalContext. Trusts PreCompact hook. |

**Eliminated behaviors:**
- `additionalContext` injection at any level (feedback loop source)
- Session record writes at any level (bloat source)
- No-cooldown CRITICAL mode (spam source)

**Retained behaviors:**
- Transcript size measurement via `stat`
- Cooldown state tracking per session
- Compaction calibration logging (append to `~/.claude/cache/context-monitor/compaction-sizes.log`)

### Component 3: PreCompact Hook (`~/.claude/hooks/pre-compact.sh`)

Fires once when compaction is imminent. Captures git state and injects recovery instructions.

**Changes from current:**
- Recovery target changes from session record to wallet card
- `systemMessage` updated: tells Claude to read `$PROJECT/.claude-task-state.md`, then check `git diff` and `git log`
- Still writes a one-time snapshot to session record (audit trail, not recovery)
- Still logs transcript size to calibration file
- **If no wallet card exists**, creates a minimal one from git state before injecting the systemMessage

**Wallet card path resolution** (same logic for context-monitor and pre-compact hooks):
1. If `$cwd` is a git repo: `$cwd/.claude-task-state.md`
2. Else if `$cwd` is under `/hddRaid1/ClaudeCodeProjects/`: `$cwd/.claude-task-state.md` (catches projects before `git init`)
3. Else: `~/.claude/task-state.md`

**Updated systemMessage:**
```
CONTEXT COMPACTION JUST OCCURRED. Read your task state file at: {wallet_card_path}
Then run: git diff --stat && git log --oneline -5
These three sources (task state + git diff + git log) reconstruct your working context.
Do not ask the user what you were doing — the answer is in those sources.
If the task state file does not exist or has only git state, rely on git diff and git log.
Resume work unless the user's last message indicates otherwise.
```

### Component 4: Session Workflow Rules (`~/.claude/rules/session-workflow.md`)

Complete rewrite. 148 lines → ~30 lines.

**New content:**
```markdown
# Session Workflow

## Session Record
- Create SESSION_RECORD_YYYY-MM-DD.md on session start (or append to existing). Initial entry: session start timestamp, branch, project name.
- Write to it at MILESTONES: task completion, commits, errors, decisions, phase boundaries.
- This is an audit trail, not a recovery mechanism. Write-only during session.
- Subagents append a summary when they complete (not continuously).

## Recovery: Wallet Card
- Maintain $PROJECT/.claude-task-state.md (~20 lines max).
- Update at the same milestones as the session record.
- Contains: current work, files modified, uncommitted changes, current decision, next step.
- This is the PRIMARY recovery target after compaction or crash.
- After compaction: read the wallet card, then check git diff and git log.
  Those three sources reconstruct full working state.

## What NOT to Do
- Do not update the session record on a timer or after every tool call.
- Do not write context monitor entries to the session record.
- Do not include PIDs, process trees, or VM IPs in the session record.
- Do not echo "Session record update: [HH:MM:SS]" — there are no constant updates.

## Session Lifecycle
- SessionStart hook: displays project table, sets up session.
- SessionEnd hook: creates exit timestamp.
- PreCompact hook: captures git state, injects systemMessage pointing to wallet card.
- Context monitor hook: observes transcript size, updates wallet card once at High level.
```

### Component 5: Cleanup — Contaminated Files

| File | Action | Detail |
|---|---|---|
| `~/.claude/hooks/context-monitor.sh` | **Rewrite** | Graduated observe-only model per Component 2 |
| `~/.claude/hooks/pre-compact.sh` | **Update** | Point recovery at wallet card per Component 3 |
| `~/.claude/rules/session-workflow.md` | **Rewrite** | Per Component 4 |
| `~/.claude/CLAUDE.md` | **Update** | Line 5: change "create/update SESSION_RECORD with PIDs, then maintain every ~3 minutes" → "create SESSION_RECORD and wallet card at session start." Remove PID tracking language. |
| `~/.claude/commands/close.md` | **Update** | Simplify session record finalization: remove flock coordination (no longer needed — milestone-only writes eliminate concurrent write races). Add wallet card cleanup: write `## Current Work\nSession closed normally.\n## Next Step\nNo pending work.` to wallet card before finalizing. |
| `~/.claude/customization-manifest.md` | **Update** | Add entries for `context-monitor.sh` (graduated observe-only transcript monitor) and `pre-compact.sh` (compaction recovery hook pointing to wallet card). Update session-workflow.md entry to reflect milestone-only audit trail role. |
| `~/.claude/projects/-hddRaid1-ClaudeCodeProjects-Audiobook-Manager/memory/feedback_session_record_frequency.md` | **Delete** | Contains "update after every tool call round" — exact opposite of new design |
| Audiobook-Manager memory: `MEMORY.md` lines 36-37 | **Update** | Remove "ALWAYS update SESSION_RECORD before calling ExitPlanMode" and "Session record update cadence: every tool call round" — contradicts milestone-only design |
| Audiobook-Manager memory: `feedback_btrfs_snapshots.md` | **Check** | Remove "Log the snapshot in the session record" if present — reinforces old write-everything pattern |
| `~/.claude/plans/mutable-churning-allen.md` | **Check** | Update if it references old session workflow |
| `~/.claude/plans/calm-hopping-thunder.md` | **Check** | Contains `fcntl.flock` reference — verify it's unrelated Python flock, not bash session record flock |

### Files NOT Changed

- `~/.claude/hooks/session-start.sh` — Fine as-is. Projects table, CLAUDE.md snapshot, version check.
- `~/.claude/hooks/session-end.sh` — Fine as-is. Lightweight exit timestamps.
- `~/.claude/hooks/prompt-dispatcher.sh` — Unrelated to context retention.
- `/test` skill dispatcher and phase files — Separate concern. Session record references in subagent prompts can be updated in a follow-up.

## Recovery Scenarios

### After Auto-Compaction
1. PreCompact hook fires, captures git state, writes audit entry to session record
2. Compaction occurs
3. PreCompact's `systemMessage` injected into post-compaction context
4. Claude reads wallet card → knows current task, files, next step
5. Claude runs `git diff --stat` and `git log --oneline -5` → knows actual changes
6. Claude resumes work

### After Crash (No Hook Fires)
1. New session starts
2. Claude checks for wallet card in project directory
3. Wallet card shows last milestone state (may be minutes old, not seconds — that's OK)
4. `git diff` and `git log` show everything that happened since
5. Claude can reconstruct from those two sources
6. Session record exists as additional audit trail if needed

### After `/close`
1. Close skill updates wallet card with "session closed" state
2. Session record gets closing summary (simplified)
3. Next session sees clean wallet card, knows previous session ended normally

### After Crash (No Wallet Card Exists)
1. New session starts
2. Claude checks for wallet card — not found
3. Claude falls back to `git diff --stat` and `git log --oneline -10`
4. Session record from previous session exists as additional context
5. Claude reconstructs from git state + session record
6. Claude creates a fresh wallet card as part of normal session initialization

## Migration

### Existing Bloated Session Records
No migration needed. Existing `SESSION_RECORD_*.md` files are left as-is — they're `.gitignore`'d and will naturally age out. New sessions create new records under the new rules. The old records serve as historical audit trail if ever needed.

### Rollback Plan
If the new system proves inadequate:
1. `git revert` the implementation commits to restore old hook/rules files
2. Delete any `.claude-task-state.md` wallet cards from project directories
3. The old session-workflow.md and context-monitor.sh are recoverable from git history
4. No data loss risk — the new system only removes write volume, never removes recovery capability

## Success Criteria

1. Session records are < 200 lines for a normal session (not 5,000+)
2. No context monitor entries appear in session records
3. No feedback loops — context monitor never triggers Claude to write, which triggers the monitor
4. Recovery after compaction takes < 30 seconds (read wallet card + git state)
5. Context monitor is invisible during normal operation (< 3 MB transcript)
6. The word "flock" does not appear in session-workflow.md
