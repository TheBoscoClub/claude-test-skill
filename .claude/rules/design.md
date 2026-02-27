# Design Principles & Future Improvements

## Design Principles

1. **Project-Agnostic**: The skill contains NO references to specific projects
2. **Context-Efficient**: Phases load on-demand via subagents
3. **Autonomous by Default**: Fixes all issues without prompting (unless `--interactive`)

## Verification in /test Phases

After ANY fix applied by /test:
- Phase 10 (Fix): After applying a fix, MUST verify the fix works
- Phase P (Production): MUST run wrapper scripts, not just check they exist
- Phase 12 (Verify): MUST execute actual tests, not just check test files exist

## Project-Specific Test Modules

**Status**: Partially implemented (QA modules)

**Implemented**: QA module discovery for `qaapp`, `qadocker`, `qaall` shortcuts.
Dispatcher looks for `test-*-qa-{app,docker,all}.md` in project root.
First project using this: Audiobook-Manager.

**Architecture**:
```
Project Root (any project using /test)
├── test-$project-qa-app.md     # QA native app regression module
├── test-$project-qa-docker.md  # QA Docker regression module
└── test-$project-qa-all.md     # QA orchestrator (runs both sequentially)
```

**Execution Model**:
- QA shortcuts are **standalone** — bypass the tier/gate system entirely
- Each module is loaded as a self-contained subagent instruction file (model=opus)
- Dispatcher discovers modules via glob: `test-*-qa-{app,docker,all}.md`
- Modules handle their own VM connectivity, version checks, upgrades, DB sync, regression

**Files modified**: `commands/test.md` (shortcut routing + QA module loading logic)

**Future expansion**: The `test-*-qa-*.md` glob pattern supports additional QA module types beyond app/docker/all.
