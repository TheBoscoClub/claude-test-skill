---
description: Modular project audit - testing, security, debugging, fixing (phase-based loading for context efficiency) (user)
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, Task
argument-hint: "[help] [prodapp] [docker] [security] [holistic] [--phase=X] [--list-phases] [--skip-snapshot] [--interactive]"
---

# Modular Project Audit (/test)

A context-efficient project audit that loads phase instructions on-demand using subagents.

## CRITICAL: Autonomous Resolution Directive

**The /test skill MUST fix and resolve ALL issues autonomously.**

This skill operates **entirely non-interactively** except in extremely rare cases requiring major architectural changes affecting the entire codebase, production application, AND Docker deployment simultaneously.

### Behavioral Requirements

1. **Fix ALL Issues**: Every issue found - regardless of priority, severity, or complexity - MUST be fixed. No "advisory" or "low priority" issues left for manual resolution.

2. **No Manual Lists**: Never return a list of "manual changes required" or "recommended fixes". If it can be identified, it can be fixed.

3. **Documentation is Code**: Documentation MUST remain synchronized with:
   - Current codebase state
   - VERSION file
   - Docker image versions
   - All obsolete references removed

4. **Autonomous Operation**: The only acceptable user prompts are:
   - SAFETY: Confirming destructive operations on production systems
   - ARCHITECTURE: Changes requiring complete rewrites of core systems
   - EXTERNAL: Issues requiring credentials or external service access

5. **Loop Until Clean**: Phase 10 (Fix) and Phase 12 (Verify) form a loop. If verification finds new issues introduced by fixes, fix those too. Continue until all tests pass and all issues are resolved.

---

## Quick Reference

```
/test                    # Full audit (autonomous - fixes everything)
/test prodapp            # Validate installed production app (Phase P)
/test docker             # Validate Docker image and registry (Phase D)
/test security           # Comprehensive security audit (Phase 5/SEC)
/test github             # Audit GitHub repository settings (Phase G)
/test holistic           # Full-stack cross-component analysis (Phase H)
/test --phase=V          # Force VM testing (Phase V)
/test --phase=A          # Run single phase
/test --phase=0-3        # Run phase range
/test --list-phases      # Show available phases
/test --interactive      # Enable interactive mode (prompts, manual items allowed)
/test --force-sandbox    # DANGEROUS: Skip VM requirement for vm-required projects
/test --phase=5 --interactive  # Combine with other options
/test help               # Show help
```

### Execution Modes

| Mode | Flag | Behavior |
|------|------|----------|
| **Autonomous** (default) | (none) | Fixes ALL issues, no prompts, loops until clean |
| **Interactive** | `--interactive` | May prompt user, may list "manual required" items |

**Autonomous mode** (default):
- Fixes every issue regardless of priority/severity
- No user prompts except for safety/architecture/external blocks
- Loops until all tests pass and all issues resolved
- Documentation automatically synchronized

**Interactive mode** (`--interactive`):
- May prompt for decisions (Phase P/D conditional execution)
- May output "manual required" or "recommendation" lists
- Single pass - does not loop until clean
- Useful for exploration or when human judgment needed

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
| **G** | **GitHub** | **Audit GitHub repository security and settings** |
| **H** | **Holistic** | **Full-stack cross-component analysis** |
| **V** | **VM Testing** | **Heavy isolation testing in libvirt/QEMU VM** |
| 4 | Cleanup | Deprecation, dead code |
| **5/SEC** | **Security** | **Comprehensive security (GitHub + Local + Installed)** |
| 6 | Dependencies | Package health |
| 7 | Quality | Linting, complexity |
| 8 | Coverage | Test coverage analysis |
| 9 | Debug | Failure analysis |
| 10 | Fix | Auto-fixing |
| 11 | Config | Configuration audit |
| 12 | Verify | Final verification |
| 13 | Docs | Documentation review |
| C | Cleanup | Restore environment |
| **ST** | **Self-Test** | **Validate test-skill framework (explicit only)** |

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
| **G** | **5** | **10 + Discovery** | **No (audits GitHub)** | **P, D (CONDITIONAL)** |
| **H** | **3** | **1** | **YES (fixes cross-component)** | **7, 5 (after Discovery)** |
| 12 | 6 | P (or 10 if P skipped) | No (re-tests) | None |
| **13** | **7** | **12** | **YES (fixes docs)** | **None (ALWAYS RUNS)** |
| **C** | **8** | **ALL** | **Cleans up** | **None (LAST)** |
| A | Special | 1 | Sandbox only | Tier 3 |
| **V** | **Special** | **1 (isolation-required)** | **VM only** | **None (CONDITIONAL)** |
| **ST** | **Special** | **None** | **No (read-only)** | **None (ISOLATED)** |

**Legend:**
- Bolded phases are **execution gates** - they block until complete
- Phase P is **conditional** - may be skipped based on Discovery results (no prompts)
- Phase D is **conditional** - may be skipped if no Docker/registry detected (no prompts)
- Phase G is **conditional** - may be skipped if no GitHub remote detected (no prompts)
- Phase V is **conditional** - runs when `ISOLATION_LEVEL` is `vm-required` or `vm-recommended`
- Phase 13 **ALWAYS runs** - documentation must stay synchronized with code
- Phase ST is **isolated** - ONLY runs when explicitly called with `--phase=ST` (never in normal runs)

### Phase P Conditional Execution

Phase P (Production Validation) execution depends on Discovery (Phase 1) results:

| Discovery: Installable App | Discovery: Production Status | Phase P Action |
|---------------------------|------------------------------|----------------|
| `none` | N/A | **SKIP** - No app to validate |
| Any | `installed` | **RUN** - Validate production |
| Any | `installed-not-running` | **RUN** - Check why not running |
| Any | `not-installed` | **SKIP** - App not installed on this system |

When Phase P is skipped, Phase 12 (Verify) proceeds directly after Phase 10 (Fix).

### Phase D Conditional Execution

Phase D (Docker Validation) execution depends on Discovery (Phase 1) results:

| Discovery: Dockerfile | Discovery: Registry Package | Phase D Action |
|-----------------------|----------------------------|----------------|
| `none` | N/A | **SKIP** - No Docker to validate |
| exists | `not-found` | **SKIP** - No registry package to validate |
| exists | `found` | **RUN** - Validate image and registry package |
| exists | `version-mismatch` | **RUN** - Flag and FIX version sync issue |

When Phase D is skipped, Phase 12 (Verify) proceeds after Phase P (or 10 if P also skipped).

### Phase G Conditional Execution

Phase G (GitHub Audit) execution depends on Discovery (Phase 1) results:

| Discovery: GitHub Remote | Discovery: gh CLI Auth | Phase G Action |
|--------------------------|------------------------|----------------|
| `none` | N/A | **SKIP** - No GitHub remote to audit |
| exists | `not-authenticated` | **SKIP** - Cannot audit without gh CLI auth |
| exists | `authenticated` | **RUN** - Full GitHub repository audit |

When Phase G is skipped, Phase 12 (Verify) proceeds after Phase D (or P if D skipped, or 10 if both skipped).

### Phase V (VM Testing) Conditional Execution

Phase V execution depends on **both** Discovery (Phase 1) isolation analysis AND Pre-Flight (Phase 0) VM availability:

| Discovery: Isolation Level | Pre-Flight: VM Available | Phase V Action |
|---------------------------|-------------------------|----------------|
| `sandbox` | Any | **SKIP** - Sandbox (Phase M) sufficient |
| `sandbox-warn` | Any | **SKIP** - Sandbox with monitoring |
| `vm-recommended` | `false` | **WARN + SKIP** - Proceed with sandbox (caution) |
| `vm-recommended` | `true` | **RUN** - Use VM for safer testing |
| `vm-required` | `false` | **⛔ ABORT** - Cannot safely test this project |
| `vm-required` | `true` | **RUN** - VM isolation mandatory |

**Isolation Level Detection** (performed by Discovery):
- Scans project for dangerous patterns: PAM configs, kernel params, systemd services, bootloader, etc.
- Calculates `DANGER_SCORE` based on weighted pattern matches
- Outputs `ISOLATION_LEVEL`: `sandbox`, `sandbox-warn`, `vm-recommended`, or `vm-required`

**VM Availability Detection** (performed by Pre-Flight):
- Checks for libvirt/virsh installation and libvirtd service
- Lists existing VMs (especially test VMs matching `*-test`, `*-dev` patterns)
- Detects ISO library for creating new VMs if needed
- Checks SSH connectivity to running test VMs
- Optionally detects physical test hardware (Raspberry Pi, spare systems)

**Critical Safety Rule:**
If `ISOLATION_LEVEL == "vm-required"` and `VM_AVAILABLE == false`:
```
⛔ CRITICAL: This project modifies system authentication, kernel, or boot configuration.
⛔ Testing these changes requires VM isolation to prevent bricking the host system.
⛔ No VM available. Aborting audit to protect host integrity.

To proceed:
1. Set up a test VM: virsh define /path/to/vm.xml
2. Or explicitly bypass (DANGEROUS): /test --force-sandbox
```

### Phase M vs Phase V Selection

The dispatcher automatically selects the appropriate isolation:

| Isolation Level | Phase M (Sandbox) | Phase V (VM) |
|-----------------|-------------------|--------------|
| `sandbox` | ✅ Used | ⚪ Skipped |
| `sandbox-warn` | ✅ Used (monitoring) | ⚪ Skipped |
| `vm-recommended` | ⚠️ Fallback if no VM | ✅ Preferred |
| `vm-required` | ⛔ Never (abort) | ✅ Mandatory |

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
│  │                                                                      │   │
│  │ G (GitHub) ──> Audits GitHub repository security and settings       │   │
│  │   📋 CONDITIONAL execution based on Discovery:                      │   │
│  │      - No GitHub remote → SKIP                                      │   │
│  │      - GitHub + gh authenticated → RUN                              │   │
│  │      - GitHub but no gh auth → SKIP (cannot audit)                  │   │
│  │                   └──> GATE 6: Production/Docker/GitHub Validated   │   │
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
│  SPECIAL PHASES (Independent tracks):                                        │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ A (App Test) ─> Depends on 1, sandbox testing independent of main   │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ ST (Self-Test) ─> ISOLATED: validates test-skill framework itself   │   │
│  │   ⛔ NEVER included in normal /test runs                            │   │
│  │   ⛔ ONLY runs when explicitly called: /test --phase=ST             │   │
│  │   ✅ No dependencies - can run standalone                           │   │
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
| 5 | P, D, G | ❌ No (conditional) | Production/Docker/GitHub validated OR skipped |
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
    # Discovery ALSO determines Phase P recommendation AND isolation level
    if 1 in requestedPhases:
        executionPlan.append({phases: [1], parallel: false, gate: "DISCOVERY"})
        # After Discovery completes, extract:
        #   - phasePRecommendation: "SKIP" | "RUN" | "PROMPT"
        #   - installableApp: type of app (or "none")
        #   - productionStatus: installation status
        #   - isolationLevel: "sandbox" | "sandbox-warn" | "vm-recommended" | "vm-required"
        #   - dangerScore: numeric score from pattern detection

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

    # TIER 5: Production, Docker & GitHub Validation (CONDITIONAL)
    tier5Phases = []
    if P in requestedPhases:
        tier5Phases.append({phase: P, condition: "phasePRecommendation"})
    if D in requestedPhases:
        tier5Phases.append({phase: D, condition: "phaseDRecommendation"})
    if G in requestedPhases:
        tier5Phases.append({phase: G, condition: "phaseGRecommendation"})
    if tier5Phases:
        executionPlan.append({
            phases: tier5Phases,
            parallel: false,  # Run P then D then G sequentially
            gate: "PRODUCTION_DOCKER_GITHUB",
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
                        log("Phase P skipped: No installable app or not installed")
                        continue
                    elif phasePRecommendation == "PROMPT" and INTERACTIVE_MODE:
                        # Only prompt in interactive mode
                        userChoice = askUser("Run Phase P?")
                        if userChoice == "skip": continue
                    # Otherwise RUN (autonomous mode never prompts)
                elif phaseInfo.phase == D:
                    if phaseDRecommendation == "SKIP":
                        log("Phase D skipped: No Dockerfile or registry package")
                        continue
                    elif phaseDRecommendation == "PROMPT" and INTERACTIVE_MODE:
                        userChoice = askUser("Run Phase D?")
                        if userChoice == "skip": continue
                    # Otherwise RUN (autonomous mode never prompts)
                elif phaseInfo.phase == G:
                    if phaseGRecommendation == "SKIP":
                        log("Phase G skipped: No GitHub remote or gh not authenticated")
                        continue
                    # Phase G never prompts - either runs or skips

        # Handle Phase 13 based on mode
        if tier.phase == 13:
            if INTERACTIVE_MODE and not allPhasesSucceeded:
                log("Phase 13 skipped: Prior phases had failures (interactive mode)")
                continue
            # Autonomous mode: ALWAYS run Phase 13 to fix docs

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

        # ISOLATION LEVEL GATE (after Discovery completes)
        if tier.gate == "DISCOVERY":
            # Check isolation requirements vs VM availability
            if isolationLevel == "vm-required" and not vmAvailable:
                abort("""
⛔ CRITICAL: This project requires VM isolation.
⛔ Danger Score: {dangerScore}
⛔ Indicators: {dangerIndicators}
⛔ No VM available. Aborting to protect host system.

To proceed:
1. Set up a test VM: virsh start <vm-name>
2. Or bypass (DANGEROUS): /test --force-sandbox
""")
            elif isolationLevel == "vm-required" and vmAvailable:
                log("VM isolation REQUIRED - Phase V will execute")
                useVM = true
            elif isolationLevel == "vm-recommended" and vmAvailable:
                log("VM isolation recommended and available - using Phase V")
                useVM = true
            elif isolationLevel == "vm-recommended" and not vmAvailable:
                warn("VM isolation recommended but not available")
                warn("Proceeding with sandbox - exercise caution")
                useVM = false
            elif isolationLevel == "sandbox-warn":
                log("Sandbox with extra monitoring")
                useVM = false
                extraMonitoring = true
            else:  # sandbox
                log("Standard sandbox isolation sufficient")
                useVM = false

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

| Phase | Status | Issues Found | Issues Fixed |
|-------|--------|--------------|--------------|
| S | ✅ | 0 | 0 |
| 0 | ✅ | 0 | 0 |
| 10 | ✅ | 15 | 15 |
| 13 | ✅ | 3 | 3 |
| ... | ... | ... | ... |

Total Issues Found: X
Total Issues Fixed: X  # MUST equal Found
Verification: ✅ All tests passing

Output Log: audit-YYYYMMDD-HHMMSS.log
```

**Note**: The audit is NOT complete until `Issues Fixed == Issues Found` and all tests pass.

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
   - Check for `--interactive` flag → set `INTERACTIVE_MODE=true` (default: false)
   - All other flags work the same in both modes
2. If `help` or `--list-phases`: show help and exit
3. **Handle shortcuts:**
   - `prodapp` → `--phase=P` (production validation)
   - `docker` → `--phase=D` (Docker validation)
   - `security` → `--phase=5` (comprehensive security audit)
   - `github` → `--phase=G` (GitHub repository audit)
   - `holistic` → `--phase=H` (full-stack cross-component analysis)
   - `--phase=SEC` → `--phase=5` (alias for security phase)
4. **Build execution plan from requested phases**

### Mode-Specific Behavior

```
IF INTERACTIVE_MODE:
    # Interactive behaviors allowed
    - May use AskUserQuestion for Phase P/D decisions
    - May output "manual required" items
    - May output "recommendations"
    - Single pass execution (no fix→verify loop)
    - Phase 13 may skip if prior phases failed
ELSE (Autonomous - DEFAULT):
    # Fully autonomous behaviors enforced
    - No user prompts (except SAFETY/ARCHITECTURE/EXTERNAL)
    - Must fix ALL issues identified
    - Must loop until all tests pass
    - Phase 13 ALWAYS runs
    - No "manual required" or "recommendations" output
```

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

   TIER 5: Production, Docker & GitHub Validation [P, D, G] - CONDITIONAL
   ──────────────────────────────────────────────────────────────────
   **Phase P** - Check Phase P Recommendation from Discovery:
     - SKIP: Log "No installable app or not installed" and proceed to Phase D
     - RUN: Execute Phase P, fix any issues found
     (No prompts - fully autonomous)

   **Phase D** - Check Phase D Recommendation from Discovery:
     - SKIP: Log "No Dockerfile or registry package" and proceed to Phase G
     - RUN: Execute Phase D, fix any version sync issues
     (No prompts - fully autonomous)

   **Phase G** - Check Phase G Recommendation from Discovery:
     - SKIP: Log "No GitHub remote or gh not authenticated" and proceed to Tier 6
     - RUN: Execute Phase G, audit and fix GitHub security settings
     (No prompts - fully autonomous)
   Wait for completion (or skip) → GATE 6: Production/Docker/GitHub Validated

   TIER 6: Verification [12] - Run SEQUENTIALLY
   ──────────────────────────────────────────────────────────────────
   Wait for completion → GATE 7: Verified
   If tests fail, loop back to TIER 4 (Fix) until clean

   TIER 7: Documentation [13] - ALWAYS RUNS
   ──────────────────────────────────────────────────────────────────
   ✅ ALWAYS runs - documentation must stay current
   ✅ Fixes ALL doc issues: versions, paths, obsolete content
   Wait for completion → GATE 8: Docs Complete

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

**Phase P (Production) - Autonomous:**
- Position: Tier 5 (after Fixes, before Verify)
- Conditional execution based on Discovery results
- Two possible outcomes (no prompts):
  1. **SKIP**: No installable app or not installed → proceed to Phase D
  2. **RUN**: Production app is installed → validate and fix issues

**Phase D (Docker) - Autonomous:**
- Position: Tier 5 (after Phase P, before Phase G)
- Conditional execution based on Discovery results
- Two possible outcomes (no prompts):
  1. **SKIP**: No Dockerfile or registry package → proceed to Phase G
  2. **RUN**: Dockerfile + registry package found → validate and fix version sync

**Phase G (GitHub) - Autonomous:**
- Position: Tier 5 (after Phase D, before Verify)
- Conditional execution based on Discovery results
- Two possible outcomes (no prompts):
  1. **SKIP**: No GitHub remote or gh CLI not authenticated → proceed to Tier 6
  2. **RUN**: GitHub remote + gh authenticated → full security audit
- Audits: Dependabot, CodeQL workflows, secret scanning, branch protection
- Auto-enables missing security features when possible

**Phase 13 (Docs) - ALWAYS Runs:**
- Position: Tier 7 (after Verify, before Cleanup)
- ALWAYS runs regardless of prior phase status
- Fixes ALL documentation issues: version refs, obsolete paths, outdated content
- Documentation MUST match current codebase state
- Rationale: Docs should always be current, even if codebase has issues to track

**Phase C (Cleanup) - Always Runs:**
- Always executes regardless of prior failures
- Cleanup is mandatory for environment hygiene

**Phase V (VM Testing) - Conditional on Isolation Level:**
- Position: Special - replaces Phase M when VM isolation is needed
- Conditional execution based on Discovery `ISOLATION_LEVEL` output
- Three possible outcomes:
  1. **SKIP**: `ISOLATION_LEVEL` is `sandbox` or `sandbox-warn` → use Phase M instead
  2. **RUN**: `ISOLATION_LEVEL` is `vm-required` or `vm-recommended` AND VM available
  3. **ABORT**: `ISOLATION_LEVEL` is `vm-required` AND no VM available
- Capabilities:
  - Deploy project to existing test VM via SSH
  - Create new VM from ISO library if needed
  - Run tests in full OS isolation
  - Snapshot/restore for rollback after dangerous tests
  - Cross-distro testing (Ubuntu, Fedora, Debian, CachyOS, Windows)
- Use cases: PAM modifications, kernel params, systemd services, bootloader changes

**Phase ST (Self-Test) - Explicit Only:**
- Position: ISOLATED (never part of normal tier execution)
- NEVER included in normal `/test` runs (not even full audit)
- ONLY runs when explicitly called: `/test --phase=ST`
- No dependencies - runs completely standalone
- Purpose: Validates the test-skill framework itself (meta-testing)
- Checks: Phase file existence, symlinks, dispatcher, tool availability
- Use cases: After modifying phase files, updating symlinks, installing tools

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

For comprehensive security audit (standalone):
```
/test security
# or: /test --phase=5
# or: /test --phase=SEC
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

For GitHub repository audit:
```
/test github
```
This audits the project's GitHub repository for security settings (Dependabot, CodeQL, secret scanning, branch protection) and auto-enables missing security features.

For test-skill framework validation (meta-testing):
```
/test --phase=ST
```
This validates the test-skill framework itself - phase files, symlinks, dispatcher, and tool availability.
**Note:** Phase ST is NEVER included in normal `/test` runs. It only runs when explicitly called.

---

## MCP Server Integration

The `/test` skill can leverage MCP (Model Context Protocol) servers for enhanced testing when available:

| MCP Server | Used By | Enhancement |
|------------|---------|-------------|
| **playwright** | Phase A, 2a | E2E browser testing for web UIs |
| **pyright-lsp** | Phase 7 | Project-aware Python type checking |
| **typescript-lsp** | Phase 7 | TypeScript diagnostics with full context |
| **rust-analyzer-lsp** | Phase 7 | Rust analysis with macro expansion |
| **gopls-lsp** | Phase 7 | Go package-aware analysis |
| **clangd-lsp** | Phase 7 | C/C++ compile-command aware diagnostics |
| **context7** | Phase 1 | Enhanced codebase understanding |
| **greptile** | Phase 1 | Semantic code search |

### Auto-Enable/Disable

**`/test` automatically manages MCP servers:**

1. **Discovery (Phase 1)** detects which MCP servers would benefit the project
2. If a beneficial server is disabled, `/test` **temporarily enables it**
3. Enabled servers are tracked in `.test-mcp-enabled`
4. **Cleanup (Phase C)** automatically disables any servers that were auto-enabled
5. Your original plugin configuration is restored

**Example flow:**
```
Phase 1 (Discovery):
  Project has: React frontend, Python backend
  Auto-enabling: playwright (for E2E), pyright-lsp (for type checking)
  Saved to: .test-mcp-enabled

Phase A (App Testing):
  Using playwright for E2E browser tests... ✅

Phase 7 (Quality):
  Using pyright-lsp for type checking... ✅

Phase C (Cleanup):
  Disabling playwright (was auto-enabled) ✅
  Disabling pyright-lsp (was auto-enabled) ✅
  Removed .test-mcp-enabled ✅
```

**No manual intervention needed** - your settings are preserved automatically.

To skip auto-enable behavior, use:
```
/test --no-mcp-enable
```

---

*Document Version: 1.0.2.0*
