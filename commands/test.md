---
description: Modular project audit - testing, security, debugging, fixing (phase-based loading for context efficiency) (user)
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, Task
argument-hint: "[help] [prodapp] [docker] [--phase=X] [--list-phases] [--skip-snapshot]"
---

# Modular Project Audit (/test)

A context-efficient project audit that loads phase instructions on-demand using subagents.

## Quick Reference

```
/test                    # Full audit (runs all phases)
/test prodapp            # Validate installed production app (Phase P)
/test docker             # Validate Docker image and registry (Phase D)
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
| **A** | **App Test** | **Deployable application testing (sandbox)** |
| **P** | **Production** | **Validate installed production app** |
| **D** | **Docker** | **Validate Docker image and registry package** |
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

### Quick Dependency Reference

| Phase | Tier | Depends On | Modifies Files? | Can Parallel With |
|-------|------|------------|-----------------|-------------------|
| S | 0 | None | No (creates snapshot) | M, 0 |
| M | 0 | None | Creates sandbox | S, 0 |
| 0 | 0 | None | No | S, M |
| **1** | **1** | **S,M,0** | **No** | **None (GATE)** |
| 2 | 2 | 1 | No (runs tests) | 2a |
| 2a | 2 | 1 | No | 2 |
| 3-9,11 | 3 | 1,2 | No (read-only) | Each other |
| **10** | **4** | **ALL Tier 3** | **YES** | **None (BLOCKING)** |
| **P** | **5** | **10 + Discovery** | **No (validates live)** | **None (CONDITIONAL)** |
| **D** | **5** | **10 + Discovery** | **No (validates registry)** | **P (CONDITIONAL)** |
| 12 | 6 | P (or 10 if P skipped) | No (re-tests) | None |
| **13** | **7** | **ALL phases pass** | **No (docs)** | **None (SUCCESS GATE)** |
| **C** | **8** | **ALL** | **Cleans up** | **None (LAST)** |
| A | Special | 1 | Sandbox only | Tier 3 |

**Legend:**
- Bolded phases are **execution gates** - they block until complete
- Phase P is **conditional** - may be skipped based on Discovery results
- Phase D is **conditional** - may be skipped if no Docker/registry detected
- Phase 13 is a **success gate** - only runs if ALL prior phases passed

### Phase P Conditional Execution

Phase P (Production Validation) execution depends on Discovery (Phase 1) results:

| Discovery: Installable App | Discovery: Production Status | Phase P Action |
|---------------------------|------------------------------|----------------|
| `none` | N/A | **SKIP** - No app to validate |
| Any | `installed` | **RUN** - Validate production |
| Any | `installed-not-running` | **RUN** - Check why not running |
| Any | `not-installed` | **PROMPT** - Ask user to skip or run |

When Phase P is skipped, Phase 12 (Verify) proceeds directly after Phase 10 (Fix).

### Phase D Conditional Execution

Phase D (Docker Validation) execution depends on Discovery (Phase 1) results:

| Discovery: Dockerfile | Discovery: Registry Package | Phase D Action |
|-----------------------|----------------------------|----------------|
| `none` | N/A | **SKIP** - No Docker to validate |
| exists | `not-found` | **PROMPT** - Image exists but not in registry |
| exists | `found` | **RUN** - Validate image and registry package |
| exists | `version-mismatch` | **RUN** - Flag version sync issue |

When Phase D is skipped, Phase 12 (Verify) proceeds after Phase P (or 10 if P also skipped).

## Phase Dependencies & Execution Order

**CRITICAL**: Phases have dependencies that MUST be respected. Running phases in parallel
when they have unmet dependencies will cause incorrect results, race conditions, or
invalidated rollback points.

### Dependency Rules

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         PHASE DEPENDENCY GRAPH                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  TIER 0: SAFETY GATES (Complete before ANY other phases)                   │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ S (Snapshot) ─┬─> Must complete BEFORE any file modifications       │   │
│  │ M (Mocking)  ─┤   Can run in PARALLEL with each other              │   │
│  │ 0 (PreFlight)─┘   └──> GATE 1: Safety Ready                        │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                              │                                              │
│                              ▼                                              │
│  TIER 1: DISCOVERY (Everything depends on this completing)                 │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ 1 (Discovery) ──────────> GATE 2: Project Known                     │   │
│  │   - Project type, test framework, file locations                    │   │
│  │   - Detects: Installable app? Production installed?                 │   │
│  │   - Sets Phase P recommendation: SKIP / RUN / PROMPT                │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                              │                                              │
│                              ▼                                              │
│  TIER 2: TEST EXECUTION (Sequential - tests must complete first)           │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ 2 (Execute)  ─┬─> Run tests                                         │   │
│  │ 2a (Runtime) ─┘   Can run in PARALLEL                               │   │
│  │                   └──> GATE 3: Tests Complete                       │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                              │                                              │
│                              ▼                                              │
│  TIER 3: READ-ONLY ANALYSIS (Can parallelize - no file modifications)      │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ These phases ONLY READ files - safe to run in parallel:             │   │
│  │ [3, 4, 5, 6, 7, 8, 9, 11]  ← Note: 13 moved to Tier 7               │   │
│  │                                                                      │   │
│  │ ⚠️  Phase 8 (Coverage) needs test results from Phase 2              │   │
│  │ ⚠️  Phase 9 (Debug) needs failure data from Phase 2                 │   │
│  │                   └──> GATE 4: Analysis Complete                    │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                              │                                              │
│                              ▼                                              │
│  TIER 4: MODIFICATIONS (STRICTLY SEQUENTIAL - Never parallel!)             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ 10 (Fix) ────> MODIFIES FILES                                       │   │
│  │   ⛔ ALL analysis phases MUST complete before this starts           │   │
│  │   ⛔ NO other phases can run while this is running                  │   │
│  │                   └──> GATE 5: Fixes Applied                        │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                              │                                              │
│                              ▼                                              │
│  TIER 5: PRODUCTION & DOCKER VALIDATION (Conditional based on Discovery)  │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ P (Production) ──> Validates live installed app                     │   │
│  │   📋 CONDITIONAL execution based on Discovery:                      │   │
│  │      - No installable app → SKIP                                    │   │
│  │      - App installed → RUN                                          │   │
│  │      - App exists but not installed → PROMPT user                   │   │
│  │                                                                      │   │
│  │ D (Docker) ──> Validates Docker image and registry package          │   │
│  │   📋 CONDITIONAL execution based on Discovery:                      │   │
│  │      - No Dockerfile → SKIP                                         │   │
│  │      - Dockerfile + registry package → RUN                          │   │
│  │      - Dockerfile but no registry → PROMPT user                     │   │
│  │                   └──> GATE 6: Production/Docker Validated          │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                              │                                              │
│                              ▼                                              │
│  TIER 6: VERIFICATION (After modifications and production check)           │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ 12 (Verify) ──> Re-run tests after fixes                            │   │
│  │                   └──> GATE 7: Verified                             │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                              │                                              │
│                              ▼                                              │
│  TIER 7: DOCUMENTATION (Only if ALL prior phases PASSED)                   │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ 13 (Docs) ──> Documentation review/update                           │   │
│  │   ⛔ SUCCESS GATE: Only runs if ALL phases 0-12,P passed            │   │
│  │   ⛔ If any prior phase FAILED, skip Phase 13                       │   │
│  │                   └──> GATE 8: Docs Complete                        │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                              │                                              │
│                              ▼                                              │
│  TIER 8: CLEANUP (ALWAYS LAST)                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ C (Restore) ──> MUST be last phase, never parallel                  │   │
│  │   Always runs regardless of prior failures (cleanup is mandatory)   │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  SPECIAL PHASE (Independent track):                                         │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ A (App Test) ─> Depends on 1, sandbox testing independent of main   │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Parallel Execution Rules

| Tier | Phases | Parallel? | Gate Condition |
|------|--------|-----------|----------------|
| 0 | S, M, 0 | ✅ Yes | All three complete |
| 1 | 1 | ❌ No (single) | Discovery complete (+ P decision made) |
| 2 | 2, 2a | ✅ Yes | Tests complete |
| 3 | 3,4,5,6,7,8,9,11 | ✅ Yes | All analysis complete |
| 4 | 10 | ❌ No | Fixes complete |
| 5 | P, D | ❌ No (conditional) | Production/Docker validated OR skipped |
| 6 | 12 | ❌ No | Verification complete |
| 7 | 13 | ❌ No (success gate) | Docs complete - ONLY if all prior passed |
| 8 | C | ❌ No (always last) | Cleanup complete (always runs) |

### Execution Algorithm

```
function executeAudit(requestedPhases):
    # Build execution plan respecting dependencies
    executionPlan = []
    allPhasesSucceeded = true
    phasePRecommendation = null  # Set by Discovery

    # TIER 0: Safety (parallel)
    tier0 = intersection(requestedPhases, [S, M, 0])
    if tier0:
        executionPlan.append({phases: tier0, parallel: true, gate: "SAFETY"})

    # TIER 1: Discovery (sequential - BLOCKER)
    # Discovery ALSO determines Phase P recommendation
    if 1 in requestedPhases:
        executionPlan.append({phases: [1], parallel: false, gate: "DISCOVERY"})
        # After Discovery completes, extract:
        #   - phasePRecommendation: "SKIP" | "RUN" | "PROMPT"
        #   - installableApp: type of app (or "none")
        #   - productionStatus: installation status

    # TIER 2: Test Execution (parallel within tier)
    tier2 = intersection(requestedPhases, [2, 2a])
    if tier2:
        executionPlan.append({phases: tier2, parallel: true, gate: "TESTS"})

    # TIER 3: Analysis (parallel - all read-only, EXCLUDES 13)
    tier3 = intersection(requestedPhases, [3,4,5,6,7,8,9,11])
    if tier3:
        executionPlan.append({phases: tier3, parallel: true, gate: "ANALYSIS"})

    # TIER 4: Modifications (NEVER parallel)
    if 10 in requestedPhases:
        executionPlan.append({phases: [10], parallel: false, gate: "FIXES"})

    # TIER 5: Production & Docker Validation (CONDITIONAL)
    tier5Phases = []
    if P in requestedPhases:
        tier5Phases.append({phase: P, condition: "phasePRecommendation"})
    if D in requestedPhases:
        tier5Phases.append({phase: D, condition: "phaseDRecommendation"})
    if tier5Phases:
        executionPlan.append({
            phases: tier5Phases,
            parallel: false,  # Run P then D sequentially
            gate: "PRODUCTION_DOCKER",
            conditional: true
        })

    # TIER 6: Verification
    if 12 in requestedPhases:
        executionPlan.append({phases: [12], parallel: false, gate: "VERIFY"})

    # TIER 7: Documentation (SUCCESS GATE - only if all prior passed)
    if 13 in requestedPhases:
        executionPlan.append({
            phases: [13],
            parallel: false,
            gate: "DOCS",
            successGate: true  # Only runs if allPhasesSucceeded
        })

    # TIER 8: Cleanup (always last, always runs)
    if C in requestedPhases:
        executionPlan.append({phases: [C], parallel: false, gate: "CLEANUP", alwaysRun: true})

    # Execute plan tier by tier
    for tier in executionPlan:
        # Handle conditional execution (Phase P and D)
        if tier.conditional:
            for phaseInfo in tier.phases:
                if phaseInfo.phase == P:
                    if phasePRecommendation == "SKIP":
                        log("Phase P skipped: No installable app detected")
                        continue
                    elif phasePRecommendation == "PROMPT":
                        userChoice = askUser("Installable app exists but not installed. Run Phase P?")
                        if userChoice == "skip":
                            continue
                elif phaseInfo.phase == D:
                    if phaseDRecommendation == "SKIP":
                        log("Phase D skipped: No Dockerfile detected")
                        continue
                    elif phaseDRecommendation == "PROMPT":
                        userChoice = askUser("Dockerfile exists but no registry package found. Run Phase D?")
                        if userChoice == "skip":
                            continue

        # Handle success gate (Phase 13)
        if tier.successGate and not allPhasesSucceeded:
            log("Phase 13 skipped: Prior phases had failures")
            continue

        # Execute the tier
        if tier.parallel:
            results = parallelExecute(tier.phases)  # Use Task tool in parallel
        else:
            results = sequentialExecute(tier.phases)

        # Check gate - track failures
        if any(result.status == FAIL for result in results):
            allPhasesSucceeded = false
            if tier.gate in ["SAFETY", "DISCOVERY"]:
                abort("Critical gate failed: " + tier.gate)
            else:
                warn("Gate " + tier.gate + " had failures")

        waitForGate(tier.gate)  # Ensure tier completes before next
```

### Why This Matters

**Without dependency enforcement:**
```
❌ Phase 10 (Fix) runs parallel with Phase 5 (Security)
   → Security finds vulnerability in line 45
   → Fix modifies line 45 at the same time
   → Race condition: Report shows stale findings

❌ Phase S (Snapshot) runs parallel with Phase 10 (Fix)
   → Snapshot captures mid-modification state
   → Rollback would restore corrupted state

❌ Phase 9 (Debug) runs before Phase 2 (Execute)
   → No test failures exist yet to debug
   → Phase 9 reports "no issues" incorrectly
```

**With dependency enforcement:**
```
✅ S, M, 0 complete → snapshot is clean baseline
✅ 1 completes → all phases know project type
✅ 2, 2a complete → test results available
✅ 3-9, 11, 13 run parallel (read-only) → safe
✅ 10 runs alone → no race conditions
✅ 12 verifies → confirms fixes work
✅ C runs last → clean exit
```

---

## Execution Strategy

This skill uses **phase subagents** to minimize context consumption:

1. **Dispatcher** (this file) - parses args, enforces dependencies
2. **Phase Files** - `~/.claude/skills/test-phases/phase-*.md`
3. **Subagents** - Load phase files on-demand via Task tool
4. **Gates** - Tier completion checkpoints before next tier

Each phase runs in its own subagent context, then returns a summary.
**Phases within a tier may run in parallel. Tiers run sequentially.**

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

**Phase A (App Testing)** - Sandbox Installation:
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

**Phase P (Production Validation)** - Live System:
```
Read ~/.claude/skills/test-phases/phase-P-production.md for full instructions.
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

1. **Parse arguments**
2. If `help` or `--list-phases`: show help and exit
3. **Handle shortcuts:**
   - `prodapp` → `--phase=P` (production validation)
   - `docker` → `--phase=D` (Docker validation)
4. **Build execution plan from requested phases**

5. **Execute by tier (respecting dependencies):**

   ```
   TIER 0: Safety Gates [S, M, 0] - Run in PARALLEL (Task tools in single message)
   ──────────────────────────────────────────────────────────────────
   Wait for all to complete → GATE 1: Safety Ready
   If --skip-snapshot: exclude S

   TIER 1: Discovery [1] - Run SEQUENTIALLY (single Task)
   ──────────────────────────────────────────────────────────────────
   Wait for completion → GATE 2: Project Known
   ⛔ ABORT if this fails - nothing else can proceed
   📋 Extract Phase P recommendation from output:
      - Installable App: [type or "none"]
      - Production Status: [installed|not-installed|installed-not-running]
      - Phase P Recommendation: [SKIP|RUN|PROMPT]

   TIER 2: Test Execution [2, 2a] - Run in PARALLEL
   ──────────────────────────────────────────────────────────────────
   Wait for all to complete → GATE 3: Tests Complete

   TIER 3: Analysis [3,4,5,6,7,8,9,11] - Run in PARALLEL
   ──────────────────────────────────────────────────────────────────
   All are READ-ONLY, safe to parallelize
   ⚠️ Phase 13 is NOT in this tier (moved to Tier 7)
   Wait for all to complete → GATE 4: Analysis Complete

   TIER 4: Modifications [10] - Run ALONE (no parallel)
   ──────────────────────────────────────────────────────────────────
   ⛔ Must wait for ALL Tier 3 to complete
   ⛔ No other phases can run during this
   Wait for completion → GATE 5: Fixes Applied

   TIER 5: Production & Docker Validation [P, D] - CONDITIONAL
   ──────────────────────────────────────────────────────────────────
   **Phase P** - Check Phase P Recommendation from Discovery:
     - SKIP: Log "No installable app" and proceed to Phase D
     - RUN: Execute Phase P
     - PROMPT: Use AskUserQuestion tool:
         "Installable app detected but not installed on this system.
          Skip Phase P (production validation)?"
         Options: [Run anyway] [Skip]

   **Phase D** - Check Phase D Recommendation from Discovery:
     - SKIP: Log "No Dockerfile" and proceed to Tier 6
     - RUN: Execute Phase D
     - PROMPT: Use AskUserQuestion tool:
         "Dockerfile exists but no registry package found.
          Skip Phase D (Docker validation)?"
         Options: [Run anyway] [Skip]
   Wait for completion (or skip) → GATE 6: Production/Docker Validated

   TIER 6: Verification [12] - Run SEQUENTIALLY
   ──────────────────────────────────────────────────────────────────
   Wait for completion → GATE 7: Verified

   TIER 7: Documentation [13] - SUCCESS GATE
   ──────────────────────────────────────────────────────────────────
   ⛔ ONLY runs if ALL prior phases (0-12, P) PASSED
   ⛔ If any prior phase FAILED, skip with log message
   Wait for completion (or skip) → GATE 8: Docs Complete

   TIER 8: Cleanup [C] - Run LAST (never parallel, always runs)
   ──────────────────────────────────────────────────────────────────
   Always runs regardless of prior failures (cleanup is mandatory)
   ```

6. **For each tier, spawn Task subagent(s):**
   - **Parallel tier**: Multiple Task tool calls in SINGLE message
   - **Sequential tier**: Single Task tool call, wait for result
   - Each subagent reads `~/.claude/skills/test-phases/phase-{X}-{name}.md`
   - Each returns summary with Status, Issue count, Key findings

7. **Gate validation between tiers:**
   - Collect all results from current tier
   - Check for failures
   - SAFETY/DISCOVERY failures → abort audit
   - Other failures → warn and continue

8. **Generate final report after all tiers complete**

### Special Phase Handling

**Phase A (App Testing):**
- Depends on: Tier 1 (Discovery) completing
- Independent of: Testing tiers (2, 3)
- Can run parallel with: Tier 3 analysis phases
- Runs in sandbox - separate from production validation

**Phase P (Production) - Now in Main Flow:**
- Position: Tier 5 (after Fixes, before Verify)
- Conditional execution based on Discovery results
- Three possible outcomes:
  1. **SKIP**: No installable app detected → proceed to Phase D
  2. **RUN**: Production app is installed → validate it
  3. **PROMPT**: App exists but not installed → ask user

**Phase D (Docker) - Now in Main Flow:**
- Position: Tier 5 (after Phase P, before Verify)
- Conditional execution based on Discovery results
- Three possible outcomes:
  1. **SKIP**: No Dockerfile detected → proceed to Tier 6
  2. **RUN**: Dockerfile + registry package found → validate sync
  3. **PROMPT**: Dockerfile exists but no registry package → ask user

**Phase 13 (Docs) - Success Gate:**
- Position: Tier 7 (after Verify, before Cleanup)
- Only runs if ALL prior phases passed
- If any phase failed, log skip message and proceed to Cleanup
- Rationale: Don't update docs for a broken codebase

**Phase C (Cleanup) - Always Runs:**
- Always executes regardless of prior failures
- Cleanup is mandatory for environment hygiene

**When user requests only specific phases:**
- Still enforce tier dependencies
- Example: `/test --phase=5` still requires 1 (Discovery) to run first
- Example: `/test --phase=P` requires Discovery AND all prior tiers
- Example: `/test --phase=13` requires ALL phases 0-12,P to have passed

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

For production validation (installed app):
```
/test prodapp
```
This validates the live production installation against the project's `install-manifest.json`.

For Docker validation (image and registry):
```
/test docker
```
This validates the Docker image builds correctly and the registry package version matches the project VERSION.
