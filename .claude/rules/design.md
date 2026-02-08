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

## Future: Project-Specific Test Modules

**Status**: Design phase

**Architecture**:
```
Project Root (any project using /test)
├── .test-skill.md              # Untracked index file (gitignored)
├── test-$project-00.md         # Project-specific test module 00
└── test-$project-99.md         # Up to 100 modules (00-99)
```

**Key Design Decisions Needed**:
1. **Trigger**: When do project-specific tests run? (New phase? Before/after existing? User flag?)
2. **Timing**: Which tier? Independent track like Phase A? Dependencies?
3. **Discovery**: How does `.test-skill.md` index the modules?
4. **Execution**: Each as a subagent? Sequential or parallel?

**Files to modify when implementing**: `commands/test.md`, `skills/test-phases/`

**Naming Convention**: Index: `.test-skill.md`, Modules: `test-$project-XY.md` (XY = 00-99)
