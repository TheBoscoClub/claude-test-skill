# test-skill — Claude Code Instructions

## Core Rules (details in .claude/rules/)

1. **VERIFY FIXES** — /test phases must execute affected functionality after fixes, not just edit code. See `rules/design.md`.
2. **VM TESTING** — Phase V uses `test-vm-cachyos` with mandatory snapshot lifecycle. See `rules/vm-testing.md`.
3. **PROJECT-AGNOSTIC** — the skill contains NO references to specific projects. See `rules/design.md`.

## Project Overview

The `/test` skill plugin for Claude Code — modular, context-efficient project audit. Location: `/hddRaid1/ClaudeCodeProjects/claude-test-skill/`

**Symlinks**:
- `~/.claude/commands/test.md` -> `commands/test.md`
- `~/.claude/skills/test-phases/` -> `skills/test-phases/`

## Rules Files

- `rules/vm-testing.md` — Phase V config, VM management, snapshot workflow
- `rules/design.md` — design principles, verification requirements, future improvements
