# Design Principles & Future Improvements

Detail, incidents and reasoning per section: `.claude/docs/rules-reference/design.md` (same headings).

## Design Principles

1. **Project-Agnostic**: NO references to specific projects
2. **Context-Efficient**: phases load on demand via subagents
3. **Autonomous by Default**: fixes all issues without prompting (unless `--interactive`)

## Verification in /test Phases

Applications of the global Proof Principle / `[SI-GATE]` (`~/.claude/rules/verification.md`). After ANY fix applied by /test:

- Phase 6 (Fix): MUST verify the fix works
- Phase 9b (Production): MUST run wrapper scripts, not just check they exist
- Phase 7 (Verify): MUST execute actual tests, not just check test files exist

## Project-Specific Test Modules

**Status**: partially implemented (QA modules). Shortcuts `qaapp`, `qadocker`, `qaall`; dispatcher (`commands/test.md`: shortcut routing + module loading) globs the project root for `test-*-qa-{app,docker,all}.md`:

Module names: `test-$project-qa-{app,docker,all}.md` (`all` runs app then docker).

- QA shortcuts are **standalone** — bypass the phase dependency system entirely
- Each module loads as a self-contained subagent instruction file (judgement tier: `JUDGEMENT_MODEL`)
- Modules handle their own VM connectivity, version checks, upgrades, DB sync, regression
- The `test-*-qa-*.md` glob supports future QA module types beyond app/docker/all
