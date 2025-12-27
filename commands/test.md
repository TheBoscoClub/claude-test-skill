---
description: Modular project audit - testing, security, debugging, fixing (phase-based loading for context efficiency) (user)
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, Task
argument-hint: "[help] [--phase=X] [--list-phases] [--skip-snapshot]"
---

# Modular Project Audit (/test)

A context-efficient project audit that loads phase instructions on-demand using subagents.

## Quick Reference

```
/test                    # Full audit (runs all phases)
/test --phase=A          # Run single phase
/test --phase=0-3        # Run phase range
/test --list-phases      # Show available phases
/test help               # Show help
```

## Available Phases

| Phase | Name | Description |
|-------|------|-------------|
| S | Snapshot | BTRFS safety snapshot |
| M | Mocking | Safe sandbox environment |
| 0 | Pre-Flight | Environment validation |
| 1 | Discovery | Find testable components |
| 2 | Execute | Run tests |
| 2a | Runtime | Service health checks |
| 3 | Report | Test results |
| **A** | **App Test** | **Deployable application testing** |
| 4 | Cleanup | Deprecation, dead code |
| 5 | Security | Vulnerability scan |
| 6 | Dependencies | Package health |
| 7 | Quality | Linting, complexity |
| 8 | Coverage | Test coverage analysis |
| 9 | Debug | Failure analysis |
| 10 | Fix | Auto-fixing |
| 11 | Config | Configuration audit |
| 12 | Verify | Final verification |
| 13 | Docs | Documentation review |
| C | Cleanup | Restore environment |

## Execution Strategy

This skill uses **phase subagents** to minimize context consumption:

1. **Dispatcher** (this file) - ~200 lines, parses args
2. **Phase Files** - `~/.claude/skills/test-phases/phase-*.md`
3. **Subagents** - Load phase files on-demand via Task tool

Each phase runs in its own subagent context, then returns a summary.

---

## Phase Execution

When running phases, spawn a Task subagent for each phase:

```
For each requested phase:
  1. Read the phase file from ~/.claude/skills/test-phases/phase-{X}.md
  2. If file exists, execute the phase instructions
  3. If no file, use inline fallback instructions below
  4. Collect results and continue to next phase
```

### Inline Fallback Instructions

If phase files don't exist, use these minimal instructions:

**Phase S (Snapshot)**:
```bash
# Check if BTRFS and create read-only snapshot
PROJECT_DIR="$(pwd)"
if df -T "$PROJECT_DIR" | grep -q btrfs; then
    SNAPSHOT="/snapshots/audit/audit-$(date +%Y%m%d-%H%M%S)-$(basename $PROJECT_DIR)"
    sudo btrfs subvolume snapshot -r "$PROJECT_DIR" "$SNAPSHOT"
fi
```

**Phase 0 (Pre-Flight)**:
- Check dependencies: `pip check` / `npm ls` / `go mod verify`
- Verify env vars exist
- Test service connectivity
- Check file permissions

**Phase 1 (Discovery)**:
- Identify project type (Python/Node/Go/Rust/etc.)
- Find test files
- Locate config files

**Phase 2 (Execute Tests)**:
- Run: `pytest` / `npm test` / `go test` / `cargo test`
- Check actual output, not just exit codes

**Phase A (App Testing)** - NEW:
```
Read ~/.claude/skills/test-phases/phase-A-app-testing.md for full instructions.
Key steps:
1. Detect deployable app (install.sh, setup.py, package.json bin, etc.)
2. Create sandbox installation
3. Test install/upgrade/migration scripts
4. Test functionality, performance, race conditions
5. Record issues to app-test-issues.log
6. Repeat until clean
```

**Phase 5 (Security)**:
- `pip-audit` / `npm audit` / `cargo audit`
- Grep for hardcoded secrets
- Check CVEs

**Phase 8 (Coverage)**:
- Run coverage tool
- Enforce 85% minimum (configurable)

---

## Output Format

Each phase returns a summary block:

```
═══════════════════════════════════════════════════════════════════
  PHASE X: [NAME]
═══════════════════════════════════════════════════════════════════

[Phase output]

Status: ✅ PASS / ⚠️ ISSUES / ❌ FAIL
Issues: [count]
```

---

## Final Summary

After all phases complete:

```markdown
# Audit Summary

| Phase | Status | Issues |
|-------|--------|--------|
| S | ✅ | 0 |
| 0 | ✅ | 0 |
| A | ⚠️ | 3 |
| ... | ... | ... |

Total Issues: X
Auto-Fixed: Y
Manual Required: Z

Output Log: audit-YYYYMMDD-HHMMSS.log
```

---

## How to Add New Phases

1. Create file: `~/.claude/skills/test-phases/phase-X-name.md`
2. Follow the structure of existing phase files
3. Add phase to the Available Phases table above
4. The dispatcher will automatically load it

---

## Context Efficiency Notes

**Why modular?**
- Old skill: 3,600 lines loaded every time
- New approach: ~200 line dispatcher + phase files loaded on-demand
- Only active phases consume context

**Subagent strategy:**
- Each phase runs in its own Task subagent
- Subagent reads the phase file, executes, returns summary
- Main context only sees summaries, not full instructions

---

## Dispatcher Logic

When `/test` is invoked:

1. Parse arguments
2. If `help` or `--list-phases`: show help and exit
3. Determine which phases to run
4. For each phase:
   - Check if `~/.claude/skills/test-phases/phase-{X}.md` exists
   - Spawn Task subagent with prompt:
     ```
     Run Phase {X} of the project audit.
     Project: {PROJECT_DIR}

     Read the phase instructions from:
     ~/.claude/skills/test-phases/phase-{X}-{name}.md

     Execute the phase and return a summary with:
     - Status (PASS/ISSUES/FAIL)
     - Issue count
     - Key findings
     ```
5. Collect all summaries
6. Generate final report

---

## Recommended Execution

For full audit:
```
/test
```

For quick check:
```
/test --phase=0-3
```

For app deployment testing only:
```
/test --phase=A
```

For security-focused audit:
```
/test --phase=5,6
```
