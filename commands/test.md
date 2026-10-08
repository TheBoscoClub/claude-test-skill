---
description: Modular project audit - testing, security, debugging, fixing (phase files loaded on demand, holistic by design) (user)
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - TaskGet
  - TaskStop
  - TaskCreate
  - TaskUpdate
  - TaskList
  - AskUserQuestion
  - NotebookEdit
  - WebSearch
  - WebFetch
argument-hint: "[help] [prodapp] [docker] [qaapp] [qadocker] [qaall] [security] [github] [--phase=X] [--list-phases] [--skip-snapshot] [--interactive] [--budget]"
---

# Modular Project Audit (/test)

Context-efficient audit: this dispatcher loads phase instructions on demand in subagents.

## GOVERNING LAW: All Errors, Warnings, and Issues Must Be Fixed

**All errors, warnings, and issues — pre-existing or otherwise — MUST be analyzed, root-caused, and fixed successfully. None may be skipped or deferred for any reason.**

Supreme law of /test. No project test module, project rule, phase instruction, execution mode, flag or other mechanism may supersede, dilute, narrow, or circumvent it. Any project-level source of ambiguity or conflict with it must be eliminated at the project level.

**Prohibited:**
- Labeling any issue "pre-existing", "cosmetic", "non-blocking", "low priority", "advisory", "won't fix", "not our changes", or any equivalent that results in not fixing it
- Deferring any issue to a future session, task, or release cycle
- Narrowing what "all" means by context, judgment, or interpretation
- Producing "manual changes required" / "recommended fixes" lists instead of fixing
- Choosing which issues to fix — all means all, unconditionally

**No exception exists. No mode, flag, or option can override this law.**

### One-Way Ratchet

Project-level test modules, rules, configs, and definitions may strengthen this law for their project (stricter coverage, extra security checks, tighter config consistency). Nothing at project level may weaken, dilute, supersede, skip, or be read so as to weaken any provision. On ambiguity or conflict the Governing Law prevails unconditionally; amend or remove the project rule.

### Commit and Release Integration

Commit all fixes made during a /test audit. If a locally staged, unpromoted release exists (`.staged-release` breadcrumb), all fix commits MUST be included in that staged release.

### Iterative Until Clean

All audits except `--interactive` iterate: if any issue was found and fixed, run another complete audit of the same kind after committing the fixes; repeat until a pass finds zero issues. Only a clean pass is a completed audit.

### Fix-Verify-Proof (FVP) Protocol — Mandatory Enforcement

**Every INDIVIDUAL fix (not just every phase) requires a structured proof block.** A fix without one is incomplete; this is mechanical, enforced by the output format.

FVP loop per fix:

```
1. IDENTIFY the issue (with file, line, specific symptom)
2. APPLY the fix (edit the code)
3. VERIFY the fix works (execute the affected functionality)
4. EMIT the proof block (mandatory structured output)
5. CHECK for collateral damage (run broader tests)
6. EMIT the collateral proof block
```

Proof block — MUST follow EVERY fix:

```
┌─ FVP PROOF ────────────────────────────────────────────┐
│ Fix:      [what was changed, file:line]                │
│ Issue:    [original symptom]                           │
│ Verify:   [exact command executed]                     │
│ Before:   [output/behavior before fix — or "new issue"]│
│ After:    [output/behavior after fix]                  │
│ Proof:    [PASS: specific evidence] / [FAIL: what]     │
│ Collateral: [test suite result — pass count, 0 new failures] │
└────────────────────────────────────────────────────────┘
```

Rules:
- `Verify`: an **actually executed command** — never "should work", "the code looks correct", "verified by inspection"
- `Before`/`After`: **observable output differences**, not descriptions of the code
- `Proof`: `PASS` + specific evidence, or `FAIL` + what went wrong; `FAIL` → fix incomplete, back to step 2
- New failures in `Collateral` = regression → revert and retry
- N fixes ⇒ N proof blocks; "15 issues fixed" with zero proof blocks is a **protocol violation**

Phase-boundary enforcement:
- Phase 6 (Fix): output MUST contain one proof block per fix applied
- Phase 7 (Verify): re-runs ALL checks; any Phase 6 fix lacking a proof block MUST be flagged `UNVERIFIED_FIX` and the audit cannot pass
- Phase 9a-9d (Validation): each finding and fix emits its own proof block
- QA modules and all project-specific test modules: same protocol; every step emits observable proof (command output, HTTP response); "step passed" without output is not proof

When Phase 7 finds failures introduced by Phase 6:
1. Loop back to Phase 6 with the new failures; each fix emits an FVP proof block
2. Phase 7 re-verifies with its own proof; repeat until Phase 7 passes clean WITH proof
3. Then the ENTIRE audit re-runs from Phase 4a
4. Complete only when a full pass has zero issues AND every prior fix has a proof block

### All Audits Are Holistic

Cross-component analysis is a structural property of **every** phase; there is no separate holistic mode or phase. Every phase that examines or modifies code MUST consider how its scope interacts with the rest of the system:
- **Phase 4a**: tests cover cross-component interactions, not just unit boundaries
- **Phase 5a-5d**: mandatory cross-component sections (security across boundaries, dependency chains, quality across modules, infrastructure integration surfaces)
- **Phase 6**: fixes verified against cross-component impact — fixing one module must not break another
- **Phase 7**: cross-component regression checks
- **Phase 9a-9d**: production, Docker, and GitHub validation verify cross-system consistency

One-way ratchet applies: projects may strengthen cross-component requirements (extra contract checks, stricter config consistency), never weaken them.

### Verified Proof Required

**No phase may be marked complete or successful without verifiable proof** — command output, test results, tool output, or observable behavior. "Looks correct" / "should work" is not proof. Per phase:
- **Phase 4a**: pass/fail counts, coverage percentages, actual command output
- **Phase 5a-5d**: scanner output with findings (or clean scan output)
- **Phase 6**: FVP proof block per fix — before/after with executed commands
- **Phase 7**: pass counts >= pre-fix counts, no regressions, each Phase 6 fix still holding
- **Phase 9b**: live service responses, systemd status, port checks
- **Phase 9c**: Docker build output, container health checks, registry version verification
- **Phase 9d**: GitHub API responses confirming security settings

If proof cannot be produced (e.g. no browser for UI verification), state exactly what could not be verified and ask the user to confirm. Never substitute "should work".

### AI Self-Promotion Purge — Mandatory

**Every /test audit MUST find and remove AI-injected self-promotion, advertising, branding, and attribution** (a code-quality and doc-hygiene issue).

Scan for:
- `Co-Authored-By:` naming Claude, Anthropic, GPT, OpenAI, Copilot, or any AI assistant — commits, code comments, docs
- "Generated with [AI tool]", "Built with Claude", "Powered by Anthropic", "Created by Claude Code"
- Attribution URLs (`claude.ai`, `anthropic.com`) in code, docs, templates, PR bodies
- AI watermarks: robot emoji preceding attribution, "AI-assisted" badges, "Made with AI" footers
- AI-tool marketing language in docs or commit messages

Where: docs (`*.md`, `*.txt`, `*.rst`); all code comments; commit messages (`git log --all --format='%H %s' | grep -iE 'co-authored|claude|anthropic|generated.with'`); PR/issue templates (`.github/`); package metadata descriptions (`package.json`, `pyproject.toml`, `Cargo.toml`); Dockerfile labels/comments; CI/CD workflows.

Fix:
- Remove the line/block entirely — no replacement attribution
- Published commits with `Co-Authored-By`: cannot rewrite; flag it and ensure no new commit includes it
- Templates that auto-inject AI branding: remove the injection

Enforcement: Phase 5c scans code/comments; Phase 8 scans and cleans all docs; both report findings as quality issues for Phase 6; project QA modules include the check in regression.

---

## CRITICAL: Autonomous Resolution Directive

**/test MUST fix and resolve ALL issues autonomously**, entirely non-interactively — except in extremely rare cases needing major architectural changes to the codebase, production app, AND Docker deployment simultaneously.

### Behavioral Requirements

1. **Fix ALL Issues** regardless of priority, severity, or complexity. Nothing "advisory" or "low priority" is left for manual resolution.
2. **No Manual Lists**: never return "manual changes required" / "recommended fixes". If it can be identified, it can be fixed.
3. **Documentation is Code**: docs stay synced with the codebase, VERSION file, and Docker image versions; obsolete references removed.
4. **Autonomous Operation**: the only acceptable prompts are SAFETY (destructive operations on production), ARCHITECTURE (complete rewrites of core systems), EXTERNAL (credentials or external service access).
5. **Iterative Until Clean (FVP Enforced)**: Phases 6 and 7 loop within each pass; every fix emits an FVP proof block, including fixes for issues introduced by fixes. After fixes are committed, the whole audit of the same kind re-runs until a pass finds zero issues.
6. **Production Data Isolation**: no test VM, QA VM, or test/QA Docker container may have LIVE ACCESS (mounts) to production storage — NFS, CIFS, virtiofs, virtio-9p, and Docker `-v` bind-mounts of host production paths are forbidden. Copying production data *into* the environment is allowed (isolated once on the VM's own disk). Test VM libraries ≤275GB. Enforced across all phases (A, D, V, VM-lifecycle).

---

### Execution Modes

| Mode | Flag | Behavior |
|------|------|----------|
| **Autonomous** (default) | (none) | Fixes ALL issues; no prompts except SAFETY/ARCHITECTURE/EXTERNAL; loops until all tests pass and all issues resolved; docs synced automatically |
| **Interactive** | `--interactive` | May prompt (e.g. Phase 9b/9c decisions); still fixes ALL issues and loops — changes prompting, never the fix mandate |

The Governing Law applies unconditionally in both modes. Usage, flags, and shortcuts: the help block under Dispatcher Logic.

## Available Phases

Phase number = execution order. Same-number sub-phases (a/b/c/d) run in parallel or are conditional.

| Phase | Name | Description | Modifies Files? |
|-------|------|-------------|-----------------|
| 1 | Snapshot | Clean up old snapshots, then create BTRFS safety snapshot | No (creates snapshot) |
| 2 | Pre-Flight | Environment validation, config audit, sandbox setup | No |
| 3 | Discovery | Find testable components, set conditional phase flags | No (GATE) |
| 4a | Execute & Analyze | Run tests, coverage, reporting, failure analysis | No |
| 4b | Runtime | Service health checks | No |
| 5a | Security | Comprehensive security (GitHub + Local + Installed) | No (read-only) |
| 5b | Dependencies | Package health | No (read-only) |
| 5c | Quality | Linting, complexity, formatting, dead code detection | No (read-only) |
| 5d | Infrastructure | Infrastructure & runtime issue detection | No (read-only) |
| **6** | **Fix** | **Auto-fix all issues from phases 4-5** | **YES** |
| 7 | Verify | Re-run tests after fixes | No |
| **8** | **Docs** | **Documentation review and fixes** | **YES** |
| 9a | App Test | Deployable application testing (sandbox) — conditional | Sandbox only |
| 9b | Production | Validate installed production app — conditional | No |
| 9c | Docker | Validate Docker image and registry package — conditional | No |
| 9d | GitHub | Audit GitHub repository security and settings — conditional | No |
| 10a | VM Testing | Heavy isolation testing in libvirt/QEMU VM — conditional | VM only |
| 10b | VM Lifecycle | VM snapshot create/revert/delete management — conditional | VM snapshots |
| 11 | Cleanup | Restore environment (always runs last) | Cleans up |
| ST | Self-Test | Validate test-skill framework (explicit `--phase=ST` only) | No |

- **Bold** phases modify files — strictly sequential
- Phase 9b/9c/9d are **conditional** — skipped if Discovery doesn't detect the relevant target
- Phase 10a/10b are **conditional** — run when `ISOLATION_LEVEL` is `vm-required` or `vm-recommended`, or a staged release is valid
- Phase 8 **ALWAYS runs** — docs must stay synchronized with code
- Phase ST is **isolated** — ONLY with `--phase=ST`, never in normal runs

### Phase 9b Conditional Execution

| Discovery: Installable App | Discovery: Production Status | Phase 9b Action |
|---------------------------|------------------------------|----------------|
| `none` | N/A | **SKIP** - No app to validate |
| Any | `installed` | **RUN** - Validate production |
| Any | `installed-not-running` | **RUN** - Check why not running |
| Any | `not-installed` | **SKIP** - App not installed on this system |

### Phase 9c Conditional Execution

| Discovery: Dockerfile | Discovery: Registry Package | Phase 9c Action |
|-----------------------|----------------------------|----------------|
| `none` | N/A | **SKIP** - No Docker to validate |
| exists | `not-found` | **SKIP** - No registry package to validate |
| exists | `found` | **RUN** - Validate image and registry package |
| exists | `version-mismatch` | **RUN** - Flag and FIX version sync issue |

### Phase 9d Conditional Execution

| Discovery: GitHub Remote | Discovery: gh CLI Auth | Phase 9d Action |
|--------------------------|------------------------|----------------|
| `none` | N/A | **SKIP** - No GitHub remote to audit |
| exists | `not-authenticated` | **SKIP** - Cannot audit without gh CLI auth |
| exists | `authenticated` | **RUN** - Full GitHub repository audit |

A skipped sub-phase passes to the next (9b → 9c → 9d → phase 10 VM → phase 11 Cleanup).

### Phase 10a (VM Testing) Conditional Execution

Depends on Discovery (Phase 3) isolation level, staged release detection, AND Pre-Flight (Phase 2) VM availability:

| Discovery: Isolation Level | Staged Release | Pre-Flight: VM Available | Phase 10a Action |
|---------------------------|----------------|-------------------------|----------------|
| `sandbox` | `none` | Any | **SKIP** - Sandbox sufficient |
| `sandbox` | `valid` | `true` | **RUN** - Staged release lifecycle test |
| `sandbox` | `valid` | `false` | **WARN** - Cannot test staged release without VM |
| `sandbox-warn` | Any | Any | **SKIP** - Sandbox with monitoring (unless staged) |
| `vm-recommended` | Any | `false` | **WARN + SKIP** - Proceed with sandbox (caution) |
| `vm-recommended` | Any | `true` | **RUN** - Use VM for safer testing |
| `vm-required` | Any | `false` | **⛔ ABORT** - Cannot safely test this project |
| `vm-required` | Any | `true` | **RUN** - VM isolation mandatory |

Two independent triggers, either activates Phase 10a when a VM is available: (1) isolation level — dangerous patterns need VM isolation; (2) valid `.staged-release` breadcrumb.

- **Isolation Level** (Discovery): scans for dangerous patterns (PAM configs, kernel params, systemd services, bootloader, etc.), computes weighted `DANGER_SCORE`, outputs `ISOLATION_LEVEL`: `sandbox`, `sandbox-warn`, `vm-recommended`, or `vm-required`
- **Staged Release** (Discovery): checks the `.staged-release` breadcrumb written by `/git-release --local`, validates the tag exists and points to the right commit, detects Docker staging images matching project name and version; outputs `Staged Release`: `valid`, `invalid`, or `none`
- **VM Availability** (Pre-Flight): libvirt/virsh installed and libvirtd running; lists VMs (especially `*-test`, `*-dev`); detects ISO library for new VMs; checks SSH to running test VMs; optionally detects physical test hardware (Raspberry Pi, spare systems)

**Critical Safety Rule** — if `ISOLATION_LEVEL == "vm-required"` and `VM_AVAILABLE == false`:
```
⛔ CRITICAL: This project modifies system authentication, kernel, or boot configuration.
⛔ Testing these changes requires VM isolation to prevent bricking the host system.
⛔ No VM available. Aborting audit to protect host integrity.

To proceed:
1. Set up a test VM: virsh define /path/to/vm.xml
2. Or explicitly bypass (DANGEROUS): /test --force-sandbox
```

**Isolation gate, applied right after Discovery completes:**
- `vm-required`, no VM → abort as above (include danger score and indicators; `virsh start <vm-name>` also satisfies it)
- `vm-required` or `vm-recommended`, VM available → `start_test_vm()`, use the VM
- `vm-recommended`, no VM → warn, proceed in sandbox with caution
- `sandbox-warn` → sandbox with extra monitoring; `sandbox` → standard sandbox
- Staged release `valid` and VM not already in use → log that Phase 10a will deploy and verify v{stagedVersion}; start the VM if available, else warn that lifecycle tests cannot run
- VM shutdown is Phase 11's job (reads `.test-vm-state`)

### Sandbox vs Phase 10a Selection

| Isolation Level | Sandbox (Phase 2) | Phase 10a (VM) |
|-----------------|-------------------|--------------|
| `sandbox` | ✅ Used | ⚪ Skipped |
| `sandbox-warn` | ✅ Used (monitoring) | ⚪ Skipped |
| `vm-recommended` | ⚠️ Fallback if no VM | ✅ Preferred |
| `vm-required` | ⛔ Never (abort) | ✅ Mandatory |

## Phase Dependencies & Execution Order

**CRITICAL**: dependencies MUST be respected. Unmet dependencies cause wrong results, races (Fix editing lines Security is reporting), or invalid rollback points (snapshot of a mid-modification tree).

| Phase | Depends On | Parallel? | Gate |
|-------|------------|-----------|------|
| 1 | None | ❌ single | SNAPSHOT: Snapshot Ready |
| 2, 3 | 1 (3 also on 2) | ❌ sequential | DISCOVERY: Project Known (GATE) |
| 4a, 4b | 3 | ✅ with each other | TESTS: Tests Complete |
| 5a, 5b, 5c, 5d | 3, 4 | ✅ with each other (read-only) | ANALYSIS: Analysis Complete |
| **6** | **All phase 5** | **❌ None (BLOCKING)** | FIXES: Fixes Applied |
| 7 | 6 | ❌ | VERIFY: Verified (failures → loop to 6) |
| 8 | 7 | ❌ | DOCS: Docs Complete (always runs) |
| 9a, 9b, 9c, 9d | 6 + Discovery flags | ❌ sequential 9a→9b→9c→9d, conditional | VALIDATION: done or skipped |
| 10a, 10b | 3 (isolation level / staged release) | ❌ conditional | VM: done or skipped |
| 11 | All | ❌ always last | CLEANUP: always runs, even after failures |
| ST | None | Isolated (never in normal runs) | — |

Gate failure: SNAPSHOT or DISCOVERY → abort the audit; any other gate → warn and continue.

---

## Execution Strategy

- **Dispatcher** (this file): parses args, enforces dependencies
- **Phase files**: `~/.claude/skills/test-phases/phase-*.md`, read on demand by **subagents** spawned via Task with model selection; each runs in its own context and returns a summary
- **Gates**: tier-completion checkpoints before the next tier
- **Task tracking**: TaskCreate/TaskUpdate for phase progress

**Sub-phases (a/b/c/d) may run in parallel. Phases run sequentially.**

### Subagent Model Selection

Three tiers. Two are fixed names; **judgement** is resolved from the session model once per run, before any phase is spawned.

| Tier | Phases | Model passed to Task | Rationale |
|------|--------|----------------------|-----------|
| **judgement** | 3, 5a, 5c, 6, 9a, 9b, 9c, 9d, ST | `JUDGEMENT_MODEL` (resolved below) | Finding and fixing defects — reasoning depth decides the result |
| **sonnet** | 2, 4a, 4b, 5b, 7, 8, 5d, 10a, 10b | `sonnet` | Test execution, dependency checks, verification |
| **haiku** | 1, 11 | `haiku` | Snapshots, cleanup |

#### Resolving `JUDGEMENT_MODEL`

Capability order: `fable` > `opus` > `sonnet` > `haiku`. Identify the dispatcher's own model from its system context, then:

| Session model | Default | With `--budget` |
|---------------|---------|-----------------|
| `fable` | `fable` | `fable` |
| `opus` | `opus` | `opus` |
| `sonnet` | `opus` | `sonnet` |
| `haiku` | `opus` | `haiku` |

- **Default = the more capable of the session model and `opus`** (an auditor weaker than the builder shares its blind spots).
- **`--budget` removes the floor**: the judgement tier runs on the session model.
- Session model none of the four → use `opus` (with or without `--budget`) and say so in the report header.
- **Always pass the resolved name explicitly** as `model=`; never omit it (an omitted model can resolve to an agent definition's own model).
- Fixed tiers never move with the session.

### Task Progress Tracking

At audit start, TaskCreate one task per phase being run. `pending` → `in_progress` when its subagent spawns; → `completed` when it returns successfully. Express tier dependencies with `addBlockedBy`.

---

## Phase Execution

Spawn a Task subagent for each phase:

```
For each requested phase:
  1. Read the phase file from ~/.claude/skills/test-phases/phase-{X}.md
  2. If file exists, execute the phase instructions via Task tool with appropriate model
  3. If no file, use inline fallback instructions below — still through a Task
     subagent with the phase's tier model (judgement phases: model=JUDGEMENT_MODEL),
     never inline in the dispatcher, which runs on the session model with no floor
  4. Collect results and continue to next phase
```

### Inline Fallback Instructions

Only when phase files are missing:

**Phase 1 (Snapshot)**:
```bash
# Check if BTRFS and create read-only snapshot
PROJECT_DIR="$(pwd)"
if df -T "$PROJECT_DIR" | grep -q btrfs; then
    SNAPSHOT="$PROJECT_DIR/.snapshots/audit-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$PROJECT_DIR/.snapshots"
    sudo btrfs subvolume snapshot -r "$PROJECT_DIR" "$SNAPSHOT"
fi
```

**Phase 2 (Pre-Flight)**: dependencies (`pip check` / `npm ls` / `go mod verify`); env vars exist; service connectivity; file permissions; config files valid; set up a safe sandbox.

**Phase 3 (Discovery)**: project type (Python/Node/Go/Rust/etc.), test files, config files.

**Phase 4a (Execute Tests & Analyze)**: run `pytest` / `npm test` / `go test` / `cargo test`; check actual output, not just exit codes; coverage with 85% minimum (configurable); summarize results and analyze failures.

**Phase 9a (App Testing)** - Sandbox Installation:
```
Read ~/.claude/skills/test-phases/phase-9a-app-testing.md for full instructions.
Key steps:
1. Detect deployable app (install.sh, setup.py, package.json bin, etc.)
2. Create sandbox installation
3. Test install/upgrade/migration scripts
4. Test functionality, performance, race conditions
5. Record issues to app-test-issues.log
6. Repeat until clean
```

**Phase 9b (Production Validation)** - Live System:
```
Read ~/.claude/skills/test-phases/phase-9b-production.md for full instructions.
Key steps:
1. Load install-manifest.json (or infer from install.sh)
2. Validate installed binaries exist and respond
3. Check systemd services are running/healthy
4. Validate config files exist and are valid
5. Check data directories and permissions
6. Verify ports are listening
7. Run custom health checks from manifest
8. Check service logs for recent errors
9. Generate production-issues.log
```

**Phase 5a (Security)**: `pip-audit` / `npm audit` / `cargo audit`; grep for hardcoded secrets; check CVEs.

---

## Output Format

Each phase returns:

```
═══════════════════════════════════════════════════════════════════
  PHASE X: [NAME]
═══════════════════════════════════════════════════════════════════

[Phase output]

Status: ✅ PASS / ⚠️ ISSUES / ❌ FAIL
Issues: [count]
```

## Final Summary

After all phases:

```markdown
# Audit Summary

| Phase | Status | Issues Found | Issues Fixed |
|-------|--------|--------------|--------------|
| 1 | ✅ | 0 | 0 |
| 2 | ✅ | 0 | 0 |
| 6 | ✅ | 15 | 15 |
| 8 | ✅ | 3 | 3 |
| ... | ... | ... | ... |

Total Issues Found: X
Total Issues Fixed: X  # MUST equal Found
Verification: ✅ All tests passing
Judgement tier: <JUDGEMENT_MODEL> (session: <model>; --budget: yes/no)

Output Log: audit-YYYYMMDD-HHMMSS.log
```

The audit is NOT complete until `Issues Fixed == Issues Found` and all tests pass.

## How to Add New Phases

Create `~/.claude/skills/test-phases/phase-X-name.md` following existing phase files' structure, and add it to the Available Phases table; the dispatcher loads it automatically.

---

## Dispatcher Logic

When `/test` is invoked:

1. **Parse arguments**
   - `--interactive` → set `INTERACTIVE_MODE=true` (default: false)
   - `--budget` → set `BUDGET_MODE=true` (default: false)
   - Resolve `JUDGEMENT_MODEL` from the session model and `BUDGET_MODE` (see "Resolving `JUDGEMENT_MODEL`"); state it in the first line of audit output (not for `help` / `--list-phases`)
   - All other flags behave the same in both modes
2. If `help` or `--list-phases`: output this block **verbatim** (no summarizing or rephrasing) and exit:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  /test — Modular Project Audit                                              │
│  Autonomous, context-efficient project testing — 20 phases, sequential      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  USAGE                                                                      │
│  ─────                                                                      │
│  /test                           Full audit (autonomous — fixes everything) │
│  /test --phase=1-3               Quick check (snapshot + preflight + disc.) │
│  /test --phase=X                 Run single phase (e.g., --phase=5a)        │
│  /test --phase=X,Y,Z             Run multiple phases                        │
│  /test --interactive             Enable prompts and manual items            │
│  /test --skip-snapshot           Skip BTRFS snapshot (Phase 1)              │
│  /test --budget                  Judgement tier on session model, no floor  │
│  /test --force-sandbox           DANGEROUS: bypass VM requirement           │
│  /test --no-mcp-enable           Skip auto-enabling MCP servers             │
│  /test help                      This help                                  │
│  /test --list-phases             Show all 20 phases                         │
│                                                                             │
│  SHORTCUTS                                                                  │
│  ─────────                                                                  │
│  /test security                  Comprehensive security audit (Phase 5a)    │
│  /test prodapp                   Validate installed production app (9b)     │
│  /test docker                    Validate Docker image & registry (9c)      │
│  /test qaapp                     QA native app regression (upgrade+DB sync) │
│  /test qadocker                  QA Docker regression (upgrade+DB sync)     │
│  /test qaall                     QA native+Docker combined regression       │
│  /test github                    Audit GitHub repo security (Phase 9d)      │
│                                                                             │
│  ALL PHASES (number = execution order)                                      │
│  ──────────                                                                 │
│    1    Snapshot         Clean old snapshots, create BTRFS safety snapshot  │
│    2    Pre-Flight       Config validation, sandbox setup, env checks       │
│    3    Discovery        Detect project type, tests, isolation level (GATE) │
│   4a    Execute&Analyze  Run tests, coverage, reporting, failure analysis   │
│   4b    Runtime          Service health checks & connectivity        ║par.  │
│   5a    Security         8-tool security suite (SAST + deps + secrets)      │
│   5b    Dependencies     Package health & outdated checks            ║      │
│   5c    Quality          Linting, complexity, formatting, dead code  ║par.  │
│   5d    Infrastructure   Infrastructure & runtime issue detection    ║      │
│    6    Fix              Auto-fix ALL issues from phases 4-5 (BLOCKING)     │
│    7    Verify           Re-run tests; loop to 6 if failures                │
│    8    Docs             Sync docs with codebase (ALWAYS runs)              │
│   9a    App Test         Sandbox installation & deployment testing   ║      │
│   9b    Production       Validate installed production app           ║cond. │
│   9c    Docker           Validate Docker image & registry package    ║      │
│   9d    GitHub           Audit repo: Dependabot, CodeQL, etc.        ║      │
│  10a    VM Testing       Heavy isolation in libvirt/QEMU VM          ║cond. │
│  10b    VM Lifecycle     VM snapshot create/revert/delete management ║      │
│   11    Cleanup          Restore environment (ALWAYS last)                  │
│   ST    Self-Test        Validate test-skill framework (--phase=ST only)    │
│                                                                             │
│  NOTES                                                                      │
│  ─────                                                                      │
│  • Autonomous mode (default): fixes ALL issues, no prompts, loops           │
│  • Interactive mode (--interactive): may prompt, still fixes ALL issues     │
│  • All audits are holistic — every analysis phase includes cross-component  │
│  • All audits iterate until clean — re-run after fixes until zero issues    │
│  • Phase 9b/9c/9d: auto-skipped when not applicable (no prompts)            │
│  • Phase 10a: auto-triggered when isolation level is vm-required            │
│  • Phase ST: NEVER runs in normal /test — explicit --phase=ST only          │
│  • Phase 8: ALWAYS runs — docs must stay in sync with code                  │
│  • Dependencies enforced: phases never run before prerequisites             │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

3. **Handle shortcuts:**
   - `prodapp` → `--phase=9b` (production validation against the project's `install-manifest.json`)
   - `docker` → `--phase=9c` (image builds; registry package version matches project VERSION)
   - `qaapp` → load project QA app module (test-*-qa-app.md from project root): auto-upgrade QA VM native app to latest release, sync production DB, full regression (API, web, auth, services, logs)
   - `qadocker` → load project QA docker module (test-*-qa-docker.md from project root): same for the Docker container, plus consistency check against the native app
   - `qaall` → load project QA all module (test-*-qa-all.md from project root): native, then Docker, then cross-validate version agreement, library counts, API responses
   - `security` → `--phase=5a` (comprehensive security audit)
   - `github` → `--phase=9d` (GitHub repository audit; auto-enables missing security features)
   - `--phase=SEC` → `--phase=5a` (alias for security phase)
4. **Build execution plan from requested phases**

### QA Module Loading (Project-Specific)

For `qaapp`, `qadocker`, or `qaall`:

1. **Map shortcut to file suffix:** `qaapp` → `app`, `qadocker` → `docker`, `qaall` → `all`

2. **Find module file in project root:**
   ```bash
   SUFFIX={app|docker|all}  # based on shortcut
   MODULE_FILE=$(ls ${PROJECT_DIR}/test-*-qa-${SUFFIX}.md 2>/dev/null | head -1)
   ```

3. **No file found** → print and **ABORT** (never fall back to a built-in phase):
     ```
     ERROR: No QA ${SUFFIX} module found in project root.
     Expected: test-*-qa-${SUFFIX}.md
     Create a project-specific QA test module to use this shortcut.
     ```

4. **Read vm-test-manifest.json QA config:**
   ```bash
   QA_CONFIG=$(python3 -c "import json; print(json.dumps(json.load(open('${PROJECT_DIR}/vm-test-manifest.json')).get('qa_vm', {})))" 2>/dev/null)
   ```
   No `qa_vm` section → WARN and continue (module may have inline config).

5. **Execute as one standalone Task subagent** with `model=JUDGEMENT_MODEL` (judgement tier), the module contents as its instructions, plus context `PROJECT_DIR`, the manifest's QA VM config, and SSH config. QA modules are **STANDALONE**: no phase prerequisites, **no other phases run**, and they bypass the tier/gate system; the module handles its own VM connectivity, version checks, upgrades, DB sync.

6. **Report**: collect output, display the QA summary, return overall PASS/FAIL.

### Mode-Specific Behavior

```
# THE GOVERNING LAW APPLIES IN BOTH MODES:
# All errors, warnings, and issues must be fixed. None may be skipped or deferred.

IF INTERACTIVE_MODE:
    # Interactive behaviors allowed
    - May use AskUserQuestion for Phase 9b/9c decisions
    - Must fix ALL issues (Governing Law — no exceptions by mode)
    - Must loop until all tests pass (Governing Law)
    - Phase 8 may skip if prior phases failed
ELSE (Autonomous - DEFAULT):
    # Fully autonomous behaviors enforced
    - No user prompts (except SAFETY/ARCHITECTURE/EXTERNAL)
    - Must fix ALL issues identified
    - Must loop until all tests pass
    - Phase 8 ALWAYS runs
```

5. **Execute by tier (respecting dependencies):**

   ```
   Phase 1: Snapshot — SEQUENTIAL → GATE: Snapshot Ready
     --skip-snapshot: exclude phase 1

   Phases 2-3: Pre-Flight & Discovery — SEQUENTIAL → GATE: Project Known
     ⛔ ABORT if this fails — nothing else can proceed
     📋 Extract from Discovery output:
        - Installable App: [type or "none"]
        - Production Status: [installed|not-installed|installed-not-running]
        - Phase 9b Recommendation: [SKIP|RUN]
        - Phase 9c Recommendation: [SKIP|RUN]
        - Phase 9d Recommendation: [SKIP|RUN]
        - Staged Release: [valid|invalid|none]; Staged Version: [X.Y.Z or empty]
          ("valid" → Phase 10a runs lifecycle testing)
     📋 Custom pytest options: parse `Pytest Custom Option: --flag | help text | resource-type`
        lines (resource types: vm, hardware, other)
        - vm/hardware flags: ALWAYS prompt, even in autonomous mode (sole autonomous-mode
          exception) — AskUserQuestion (multiSelect: true) with only those flags
        - If --hardware selected, remind: "Hardware tests require manual action (e.g.,
          touch your security key when it flashes, or approve on your passkey device).
          Stay attentive during Phase 4a."
        - `other` flags: prompt only in --interactive, skip in autonomous
        - No resource flags and autonomous: PYTEST_EXTRA_FLAGS=""

   Phase 4: Test Execution [4a, 4b] — PARALLEL → GATE: Tests Complete
     Pass to 4a subagent: "Set PYTEST_EXTRA_FLAGS to: [flags from Discovery]" (empty if none)

   Phase 5: Analysis [5a, 5b, 5c, 5d] — PARALLEL (all READ-ONLY) → GATE: Analysis Complete

   Phase 6: Fix — ALONE → GATE: Fixes Applied
     ⛔ Wait for ALL phase 5 sub-phases; nothing else runs meanwhile

   Phase 7: Verification — SEQUENTIAL → GATE: Verified
     Failures → loop back to phase 6 until clean
     After all fixes committed → re-run entire audit until clean pass

   Phase 8: Documentation — ALWAYS RUNS → GATE: Docs Complete
     Fixes ALL doc issues: versions, paths, obsolete content

   Phase 9: Validation [9a, 9b, 9c, 9d] — CONDITIONAL, sequential, no prompts
     9a: runs if project has deployable app components
     9b/9c/9d: per Discovery recommendation — SKIP: log reason, go to next;
       RUN: execute and fix all issues found
     → GATE: Validation Done

   Phase 10: VM Testing [10a, 10b] — CONDITIONAL (isolation level or staged release)
     → GATE: VM Complete

   Phase 11: Cleanup — LAST, never parallel, always runs regardless of prior failures
   ```

6. **For each tier, spawn Task subagent(s) with model selection:**
   - **Parallel tier**: multiple Task calls in a SINGLE message
   - **Sequential tier**: one Task call, wait for result
   - Each subagent reads `~/.claude/skills/test-phases/phase-{X}-{name}.md` and returns Status, Issue count, Key findings
   - **Model selection per phase** (`model` parameter on Task):
     - `JUDGEMENT_MODEL`: Phases 3, 5a, 5c, 6, 9a, 9b, 9c, 9d, ST
     - `sonnet`: Phases 2, 4a, 4b, 5b, 7, 8, 5d, 10a, 10b
     - `haiku`: Phases 1, 11
   - `run_in_background: true` for long-running phases where appropriate

7. **Gate validation between tiers:** collect results, check failures; SAFETY/DISCOVERY failures → abort; others → warn and continue.

8. **Generate final report after all tiers complete**

### Special Phase Handling

- **Phase 9a (App Testing)**: after phase 8, alongside 9b/9c/9d; depends on Phase 3; sandbox only, separate from production validation.
- **Phase 9d (GitHub)**: audits Dependabot, CodeQL workflows, secret scanning, branch protection; auto-enables missing security features when possible.
- **Phase 8 (Docs)**: after 7, before 9; fixes ALL doc issues (version refs, obsolete paths, outdated content) so docs match the codebase even when issues remain.
- **Phase 10a (VM Testing)**: outcomes SKIP (no trigger), RUN (trigger + VM), ABORT (`vm-required`, no VM).
  - Project-VM routing via `~/.claude/config/project-vm-map.json`: `exclusive_to` mappings route projects to dedicated VMs; reserved VMs cannot be used by other projects; unmapped projects use the default VM
  - Capabilities: deploy to existing test VM via SSH; **staged release lifecycle testing** (install → upgrade → deploy → verify); **Docker staging image testing** (transfer + smoke test on VM); create VM from ISO library; full OS isolation; snapshot/restore rollback after dangerous tests; cross-distro (Ubuntu, Fedora, Debian, CachyOS, Windows)
  - Use cases: PAM, kernel params, systemd services, bootloader, **release verification**
- **Phase ST (Self-Test)**: NEVER in normal `/test` runs (not even full audit); ONLY `/test --phase=ST`; no dependencies. Validates the framework itself — phase files, symlinks, dispatcher, tool availability. Run after modifying phase files, symlinks, or installing tools.

**Specific phases requested → still enforce dependencies**: `--phase=5a` needs phase 3 first; `--phase=9b` needs Discovery AND all prior phases; `--phase=8` needs phases 1-7 passed.

---

## MCP Server Integration

| MCP Server | Used By | Enhancement |
|------------|---------|-------------|
| **playwright** | Phase 9a, 4b | E2E browser testing for web UIs |
| **pyright-lsp** | Phase 5c | Project-aware Python type checking |
| **typescript-lsp** | Phase 5c | TypeScript diagnostics with full context |
| **rust-analyzer-lsp** | Phase 5c | Rust analysis with macro expansion |
| **gopls-lsp** | Phase 5c | Go package-aware analysis |
| **clangd-lsp** | Phase 5c | C/C++ compile-command aware diagnostics |
| **context7** | Phase 3 | Enhanced codebase understanding |
| **greptile** | Phase 3 | Semantic code search |

### Auto-Enable/Disable

1. Discovery (Phase 3) detects beneficial MCP servers
2. Disabled beneficial servers are **temporarily enabled**, tracked in `.test-mcp-enabled`
3. Cleanup (Phase 11) disables every auto-enabled server and removes `.test-mcp-enabled`, restoring the original plugin config

`--no-mcp-enable` skips auto-enable.

---

## Companion Tools (out-of-phase, optional)

Complementary gstack skills; they do not replace `/test`, and `/test` does not invoke them:

- **`/gstack-health`** — fast 0-10 quality dashboard; daily pulse (`/test` weekly and before releases)
- **`/gstack-cso --skills`** — skill-supply-chain audit (referenced in Phase 5a); run when `.claude/skills/` changes
- **`/gstack-qa`**, **`/gstack-benchmark`**, **`/gstack-canary`** — web-facing companions for Phase 9a / 9b
- **`/gstack-autoplan`** — strategic CEO/eng/design/DX sign-off after a clean `/test` when a release touches product decisions
- **`/gstack-investigate`** — root-cause debugging when Phase 7 uncovers a failure auto-fix can't explain

The `Governing Law` governs `/test`'s own phases, not companions. Running a companion never satisfies `/test`'s completeness requirement.

---

*Document Version: 5.0.0 — unified sequential phase numbering (phase number = execution order)*
