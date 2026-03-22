---
description: Modular project audit - testing, security, debugging, fixing (phase-based loading for context efficiency) (user)
model: opus
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - TaskGet
  - TaskOutput
  - TaskStop
  - TaskCreate
  - TaskUpdate
  - TaskList
  - AskUserQuestion
  - NotebookEdit
  - WebSearch
  - WebFetch
argument-hint: "[help] [prodapp] [docker] [qaapp] [qadocker] [qaall] [security] [github] [holistic] [--phase=X] [--list-phases] [--skip-snapshot] [--interactive]"
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

6. **Production Data Isolation**: No test VM, QA VM, or test/QA Docker container may have LIVE ACCESS (mounts) to production storage. NFS, CIFS, virtiofs, virtio-9p mounts and Docker `-v` bind-mounts to host production paths are forbidden. Copying production data *into* a test/QA environment is allowed — once on the VM's own disk, it's fully isolated. Test VM libraries should be ≤275GB. This boundary is enforced across all phases (A, D, V, VM-lifecycle).

---

## Quick Reference

```
/test                    # Full audit (autonomous - fixes everything)
/test prodapp            # Validate installed production app (Phase P)
/test docker             # Validate Docker image and registry (Phase D)
/test qaapp              # QA VM: regression test native app (auto-upgrade + DB sync)
/test qadocker           # QA VM: regression test Docker container (auto-upgrade + DB sync)
/test qaall              # QA VM: regression test both native and Docker sequentially
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
| 0 | Pre-Flight | Environment validation, config audit, sandbox setup |
| 1 | Discovery | Find testable components |
| 2 | Execute & Analyze | Run tests, coverage, reporting, failure analysis |
| 2a | Runtime | Service health checks |
| **A** | **App Test** | **Deployable application testing (sandbox)** |
| **P** | **Production** | **Validate installed production app** |
| **D** | **Docker** | **Validate Docker image and registry package** |
| **G** | **GitHub** | **Audit GitHub repository security and settings** |
| **H** | **Holistic** | **Full-stack cross-component analysis** |
| **I** | **Infrastructure** | **Infrastructure & runtime issue detection** |
| **V** | **VM Testing** | **Heavy isolation testing in libvirt/QEMU VM** |
| **VM** | **VM Lifecycle** | **VM snapshot create/revert/delete management** |
| **5/SEC** | **Security** | **Comprehensive security (GitHub + Local + Installed)** |
| 6 | Dependencies | Package health |
| 7 | Quality | Linting, complexity, formatting, dead code detection |
| 10 | Fix | Auto-fixing |
| 12 | Verify | Final verification |
| 13 | Docs | Documentation review |
| C | Cleanup | Restore environment |
| **ST** | **Self-Test** | **Validate test-skill framework (explicit only)** |

### Quick Dependency Reference

| Phase | Tier | Depends On | Modifies Files? | Can Parallel With |
|-------|------|------------|-----------------|-------------------|
| S | 0 | None | No (creates snapshot) | 0 |
| 0 | 1 | S | No | None (GATE with 1) |
| **1** | **1** | **S,0** | **No** | **None (GATE)** |
| 2 | 2 | 1 | No (runs tests + analysis) | 2a |
| 2a | 2 | 1 | No | 2 |
| 5,6,7,H,I | 3 | 1,2 | No (read-only) | Each other |
| **10** | **4** | **ALL Tier 3** | **YES** | **None (BLOCKING)** |
| 12 | 5 | 10 | No (re-tests) | None |
| **13** | **6** | **12** | **YES (fixes docs)** | **None (ALWAYS RUNS)** |
| **A** | **7** | **1** | **Sandbox only** | **P, D** |
| **P** | **7** | **10 + Discovery** | **No (validates live)** | **None (CONDITIONAL)** |
| **D** | **7** | **10 + Discovery** | **No (validates registry)** | **P (CONDITIONAL)** |
| **G** | **7** | **10 + Discovery** | **No (audits GitHub)** | **P, D (CONDITIONAL)** |
| **H** | **3** | **1** | **No (read-only analysis)** | **7, 5, I (after Discovery)** |
| **I** | **3** | **1** | **No (read-only)** | **H, 7, 5 (after Discovery)** |
| **V** | **8** | **1 (isolation-required)** | **VM only** | **None (CONDITIONAL)** |
| **VM** | **8** | **V** | **VM snapshots** | **None** |
| **C** | **last** | **ALL** | **Cleans up** | **None (LAST)** |
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

When Phase P is skipped, Phase D proceeds (or Phase G if D also skipped).

### Phase D Conditional Execution

Phase D (Docker Validation) execution depends on Discovery (Phase 1) results:

| Discovery: Dockerfile | Discovery: Registry Package | Phase D Action |
|-----------------------|----------------------------|----------------|
| `none` | N/A | **SKIP** - No Docker to validate |
| exists | `not-found` | **SKIP** - No registry package to validate |
| exists | `found` | **RUN** - Validate image and registry package |
| exists | `version-mismatch` | **RUN** - Flag and FIX version sync issue |

When Phase D is skipped, Phase G proceeds (or Tier 8 if G also skipped).

### Phase G Conditional Execution

Phase G (GitHub Audit) execution depends on Discovery (Phase 1) results:

| Discovery: GitHub Remote | Discovery: gh CLI Auth | Phase G Action |
|--------------------------|------------------------|----------------|
| `none` | N/A | **SKIP** - No GitHub remote to audit |
| exists | `not-authenticated` | **SKIP** - Cannot audit without gh CLI auth |
| exists | `authenticated` | **RUN** - Full GitHub repository audit |

When Phase G is skipped, Tier 8 (VM) proceeds (or Cleanup if VM also skipped).

### Phase V (VM Testing) Conditional Execution

Phase V execution depends on **both** Discovery (Phase 1) isolation analysis AND Pre-Flight (Phase 0) VM availability, **plus staged release detection**:

| Discovery: Isolation Level | Staged Release | Pre-Flight: VM Available | Phase V Action |
|---------------------------|----------------|-------------------------|----------------|
| `sandbox` | `none` | Any | **SKIP** - Sandbox (Phase 0) sufficient |
| `sandbox` | `valid` | `true` | **RUN** - Staged release lifecycle test |
| `sandbox` | `valid` | `false` | **WARN** - Cannot test staged release without VM |
| `sandbox-warn` | Any | Any | **SKIP** - Sandbox with monitoring (unless staged) |
| `vm-recommended` | Any | `false` | **WARN + SKIP** - Proceed with sandbox (caution) |
| `vm-recommended` | Any | `true` | **RUN** - Use VM for safer testing |
| `vm-required` | Any | `false` | **⛔ ABORT** - Cannot safely test this project |
| `vm-required` | Any | `true` | **RUN** - VM isolation mandatory |

**Two independent triggers for Phase V:**
1. **Isolation Level** — project contains dangerous patterns requiring VM isolation
2. **Staged Release** — `.staged-release` breadcrumb exists and is valid

Either trigger independently activates Phase V when a VM is available.

**Isolation Level Detection** (performed by Discovery):
- Scans project for dangerous patterns: PAM configs, kernel params, systemd services, bootloader, etc.
- Calculates `DANGER_SCORE` based on weighted pattern matches
- Outputs `ISOLATION_LEVEL`: `sandbox`, `sandbox-warn`, `vm-recommended`, or `vm-required`

**Staged Release Detection** (performed by Discovery):
- Checks for `.staged-release` breadcrumb file written by `/git-release --local`
- Validates tag exists and points to correct commit
- Detects Docker staging images matching project name and version
- Outputs `Staged Release`: `valid`, `invalid`, or `none`

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

### Sandbox vs Phase V Selection

The dispatcher automatically selects the appropriate isolation:

| Isolation Level | Sandbox (Phase 0) | Phase V (VM) |
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
│  TIER 0: SAFETY SNAPSHOT (Complete before ANY file modifications)           │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ S (Snapshot) ──> Must complete BEFORE any file modifications        │   │
│  │                   └──> GATE 0: Snapshot Ready                       │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                              │                                              │
│                              ▼                                              │
│  TIER 1: PREFLIGHT & DISCOVERY (Everything depends on these completing)    │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ 0 (PreFlight) ──> Config validation, sandbox setup, env checks      │   │
│  │ 1 (Discovery) ──> Project type, tests, isolation level              │   │
│  │   - Detects: Installable app? Production installed?                 │   │
│  │   - Sets Phase P recommendation: SKIP / RUN / PROMPT                │   │
│  │                   └──> GATE 1: Project Known                        │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                              │                                              │
│                              ▼                                              │
│  TIER 2: TEST EXECUTION & ANALYSIS (tests + coverage + reporting)          │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ 2 (Execute & Analyze) ─┬─> Run tests, coverage, reporting, debug   │   │
│  │ 2a (Runtime)           ─┘   Can run in PARALLEL                     │   │
│  │                   └──> GATE 2: Tests Complete                       │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                              │                                              │
│                              ▼                                              │
│  TIER 3: READ-ONLY ANALYSIS (Can parallelize - no file modifications)      │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ These phases ONLY READ files - safe to run in parallel:             │   │
│  │ [5, 6, 7, H, I]  ← Note: 13 moved to Tier 6                        │   │
│  │                   └──> GATE 3: Analysis Complete                    │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                              │                                              │
│                              ▼                                              │
│  TIER 4: MODIFICATIONS (STRICTLY SEQUENTIAL - Never parallel!)             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ 10 (Fix) ────> MODIFIES FILES                                       │   │
│  │   ⛔ ALL analysis phases MUST complete before this starts           │   │
│  │   ⛔ NO other phases can run while this is running                  │   │
│  │                   └──> GATE 4: Fixes Applied                        │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                              │                                              │
│                              ▼                                              │
│  TIER 5: VERIFICATION (After modifications)                                │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ 12 (Verify) ──> Re-run tests after fixes                            │   │
│  │                   └──> GATE 5: Verified                             │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                              │                                              │
│                              ▼                                              │
│  TIER 6: DOCUMENTATION (Only if ALL prior phases PASSED)                   │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ 13 (Docs) ──> Documentation review/update                           │   │
│  │   ⛔ SUCCESS GATE: Only runs if ALL phases 0-12 passed              │   │
│  │   ⛔ If any prior phase FAILED, skip Phase 13                       │   │
│  │                   └──> GATE 6: Docs Complete                        │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                              │                                              │
│                              ▼                                              │
│  TIER 7: APP, PRODUCTION & DOCKER VALIDATION (Conditional)                 │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ A (App Test) ──> Sandbox installation & deployment testing          │   │
│  │                                                                      │   │
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
│  │                   └──> GATE 7: App/Production/Docker/GitHub Done    │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                              │                                              │
│                              ▼                                              │
│  TIER 8: VM TESTING (Conditional on isolation level or staged release)      │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ V (VM Testing) ──> Heavy isolation in libvirt/QEMU VM               │   │
│  │ VM (VM Lifecycle) ──> Snapshot create/revert/delete management      │   │
│  │                   └──> GATE 8: VM Complete                          │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                              │                                              │
│                              ▼                                              │
│  CLEANUP (ALWAYS LAST)                                                      │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ C (Restore) ──> MUST be last phase, never parallel                  │   │
│  │   Always runs regardless of prior failures (cleanup is mandatory)   │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  SPECIAL PHASES (Independent tracks):                                        │
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
| 0 | S | ❌ No (single) | Snapshot complete |
| 1 | 0, 1 | ❌ No (sequential) | Preflight + Discovery complete (+ P decision made) |
| 2 | 2, 2a | ✅ Yes | Tests complete |
| 3 | 5,6,7,H,I | ✅ Yes | All analysis complete |
| 4 | 10 | ❌ No | Fixes complete |
| 5 | 12 | ❌ No | Verification complete |
| 6 | 13 | ❌ No (success gate) | Docs complete - ONLY if all prior passed |
| 7 | A, P, D, G | ❌ No (conditional) | App/Production/Docker/GitHub validated OR skipped |
| 8 | V, VM | ❌ No (conditional) | VM testing complete OR skipped |
| last | C | ❌ No (always last) | Cleanup complete (always runs) |

### Execution Algorithm

```
function executeAudit(requestedPhases):
    # Build execution plan respecting dependencies
    executionPlan = []
    allPhasesSucceeded = true
    phasePRecommendation = null  # Set by Discovery

    # TIER 0: Snapshot
    if S in requestedPhases:
        executionPlan.append({phases: [S], parallel: false, gate: "SNAPSHOT"})

    # TIER 1: Preflight + Discovery (sequential - BLOCKER)
    # Preflight now includes config validation and sandbox setup
    # Discovery ALSO determines Phase P recommendation AND isolation level
    tier1 = intersection(requestedPhases, [0, 1])
    if tier1:
        executionPlan.append({phases: tier1, parallel: false, gate: "DISCOVERY"})
        # After Discovery completes, extract:
        #   - phasePRecommendation: "SKIP" | "RUN" | "PROMPT"
        #   - installableApp: type of app (or "none")
        #   - productionStatus: installation status
        #   - isolationLevel: "sandbox" | "sandbox-warn" | "vm-recommended" | "vm-required"
        #   - dangerScore: numeric score from pattern detection
        #   - stagedRelease: "valid" | "invalid" | "none"
        #   - stagedVersion: version string (or empty)

    # TIER 2: Test Execution (parallel within tier)
    tier2 = intersection(requestedPhases, [2, 2a])
    if tier2:
        executionPlan.append({phases: tier2, parallel: true, gate: "TESTS"})

    # TIER 3: Analysis (parallel - all read-only, EXCLUDES 13)
    tier3 = intersection(requestedPhases, [5,6,7,H,I])
    if tier3:
        executionPlan.append({phases: tier3, parallel: true, gate: "ANALYSIS"})

    # TIER 4: Modifications (NEVER parallel)
    if 10 in requestedPhases:
        executionPlan.append({phases: [10], parallel: false, gate: "FIXES"})

    # TIER 5: Verification
    if 12 in requestedPhases:
        executionPlan.append({phases: [12], parallel: false, gate: "VERIFY"})

    # TIER 6: Documentation (SUCCESS GATE - only if all prior passed)
    if 13 in requestedPhases:
        executionPlan.append({
            phases: [13],
            parallel: false,
            gate: "DOCS",
            successGate: true  # Only runs if allPhasesSucceeded
        })

    # TIER 7: App, Production, Docker & GitHub Validation (CONDITIONAL)
    tier7Phases = []
    if A in requestedPhases:
        tier7Phases.append({phase: A, condition: "always"})
    if P in requestedPhases:
        tier7Phases.append({phase: P, condition: "phasePRecommendation"})
    if D in requestedPhases:
        tier7Phases.append({phase: D, condition: "phaseDRecommendation"})
    if G in requestedPhases:
        tier7Phases.append({phase: G, condition: "phaseGRecommendation"})
    if tier7Phases:
        executionPlan.append({
            phases: tier7Phases,
            parallel: false,  # Run A then P then D then G sequentially
            gate: "APP_PRODUCTION_DOCKER_GITHUB",
            conditional: true
        })

    # TIER 8: VM Testing (CONDITIONAL on isolation level or staged release)
    tier8Phases = intersection(requestedPhases, [V, VM])
    if tier8Phases:
        executionPlan.append({
            phases: tier8Phases,
            parallel: false,
            gate: "VM",
            conditional: true
        })

    # CLEANUP: Always last, always runs
    if C in requestedPhases:
        executionPlan.append({phases: [C], parallel: false, gate: "CLEANUP", alwaysRun: true})

    # Execute plan tier by tier
    for tier in executionPlan:
        # Handle conditional execution (Phases A, P, D, G)
        if tier.conditional:
            for phaseInfo in tier.phases:
                if phaseInfo.phase == A:
                    # App testing always runs if requested
                    pass
                elif phaseInfo.phase == P:
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
                log("VM isolation REQUIRED - starting test VM...")
                # Trigger VM startup from phase-VM-lifecycle.md
                start_test_vm()  # Creates .test-vm-state for cleanup
                useVM = true
            elif isolationLevel == "vm-recommended" and vmAvailable:
                log("VM isolation recommended and available - starting test VM...")
                # Trigger VM startup from phase-VM-lifecycle.md
                start_test_vm()  # Creates .test-vm-state for cleanup
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

            # STAGED RELEASE GATE (additional Phase V trigger)
            # A valid staged release triggers Phase V regardless of isolation level
            if stagedRelease == "valid" and not useVM:
                log("Staged release v{stagedVersion} detected — Phase V will deploy and verify")
                if vmAvailable:
                    start_test_vm()
                    useVM = true
                    stagedReleaseTrigger = true
                else:
                    warn("Staged release detected but no VM available")
                    warn("Cannot run lifecycle tests without VM")
                    # Not a hard abort — staged release testing is valuable but not safety-critical

            # Note: VM shutdown is handled by Phase C cleanup (reads .test-vm-state)

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

❌ Phase 7 (Quality) runs before Phase 2 (Execute)
   → No test results available for dead code analysis
   → Phase 7 reports incomplete findings
```

**With dependency enforcement:**
```
✅ S completes → snapshot is clean baseline
✅ 0, 1 complete → config validated, project type known
✅ 2, 2a complete → test results + coverage + failure analysis available
✅ 5, 6, 7, H, I run parallel (read-only) → safe
✅ 10 runs alone → no race conditions
✅ 12 verifies → confirms fixes work
✅ C runs last → clean exit
```

---

## Execution Strategy

This skill uses **phase subagents** to minimize context consumption:

1. **Dispatcher** (this file) - parses args, enforces dependencies
2. **Phase Files** - `~/.claude/skills/test-phases/phase-*.md`
3. **Subagents** - Load phase files on-demand via Task tool with model selection
4. **Gates** - Tier completion checkpoints before next tier
5. **Task tracking** - Use TaskCreate/TaskUpdate for phase progress visibility

Each phase runs in its own subagent context, then returns a summary.
**Phases within a tier may run in parallel. Tiers run sequentially.**

### Subagent Model Selection

When spawning Task subagents for phases, specify the `model` parameter based on phase complexity:

| Model | Phases | Rationale |
|-------|--------|-----------|
| **opus** | 1, 5, 7, 10, A, P, D, G, H, ST | Complex analysis, multi-step fixes, security audit, cross-component reasoning |
| **sonnet** | 0, 2, 2a, 6, 12, 13, I, V, VM | Moderate complexity: test execution, dependency checks, verification |
| **haiku** | S, C | Lightweight: snapshots, cleanup |

**Example Task call with model:**
```
Task(subagent_type="general-purpose", model="opus", prompt="Read phase file and execute...")
Task(subagent_type="general-purpose", model="haiku", prompt="Read phase file and execute...")
```

### Task Progress Tracking

Use TaskCreate at the start of the audit to create a task for each phase being run.
Update task status as phases execute:
- `pending` → `in_progress` when a phase subagent is spawned
- `in_progress` → `completed` when the phase returns successfully
- Use `addBlockedBy` to express tier dependencies between tasks

This gives the user real-time visibility into audit progress.

---

## Phase Execution

When running phases, spawn a Task subagent for each phase:

```
For each requested phase:
  1. Read the phase file from ~/.claude/skills/test-phases/phase-{X}.md
  2. If file exists, execute the phase instructions via Task tool with appropriate model
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
    SNAPSHOT="$PROJECT_DIR/.snapshots/audit-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$PROJECT_DIR/.snapshots"
    sudo btrfs subvolume snapshot -r "$PROJECT_DIR" "$SNAPSHOT"
fi
```

**Phase 0 (Pre-Flight)** — now includes config validation and sandbox setup:
- Check dependencies: `pip check` / `npm ls` / `go mod verify`
- Verify env vars exist
- Test service connectivity
- Check file permissions
- Validate configuration files
- Set up safe sandbox environment

**Phase 1 (Discovery)**:
- Identify project type (Python/Node/Go/Rust/etc.)
- Find test files
- Locate config files

**Phase 2 (Execute Tests & Analyze)** — now includes coverage, reporting, and failure analysis:
- Run: `pytest` / `npm test` / `go test` / `cargo test`
- Check actual output, not just exit codes
- Run coverage tool and enforce 85% minimum (configurable)
- Summarize test results and analyze failures

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
2. If `help` or `--list-phases`: display the canonical help block below **verbatim** and exit. Do not summarize or rephrase — output the block exactly as written:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  /test — Modular Project Audit                                              │
│  Autonomous, context-efficient project testing with 21 phases in 9 tiers    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  USAGE                                                                      │
│  ─────                                                                      │
│  /test                           Full audit (autonomous — fixes everything) │
│  /test --phase=0-2               Quick check (safety + discovery + tests)   │
│  /test --phase=X                 Run single phase (e.g., --phase=5)         │
│  /test --phase=X,Y,Z             Run multiple phases                        │
│  /test --interactive             Enable prompts and manual items            │
│  /test --skip-snapshot           Skip BTRFS snapshot (Phase S)              │
│  /test --force-sandbox           DANGEROUS: bypass VM requirement           │
│  /test --no-mcp-enable           Skip auto-enabling MCP servers             │
│  /test help                      This help                                  │
│  /test --list-phases             Show all 21 phases                         │
│                                                                             │
│  SHORTCUTS                                                                  │
│  ─────────                                                                  │
│  /test security                  Comprehensive security audit (Phase 5)     │
│  /test prodapp                   Validate installed production app (Phase P)│
│  /test docker                    Validate Docker image & registry (Phase D) │
│  /test qaapp                     QA native app regression (upgrade+DB sync) │
│  /test qadocker                  QA Docker regression (upgrade+DB sync)     │
│  /test qaall                     QA native+Docker combined regression       │
│  /test github                    Audit GitHub repo security (Phase G)       │
│  /test holistic                  Full-stack cross-component analysis (H)    │
│                                                                             │
│  ALL PHASES                                                                 │
│  ──────────                                                                 │
│  Tier 0 — Safety Snapshot                                                   │
│    S   Snapshot         BTRFS read-only safety snapshot                     │
│                                                                             │
│  Tier 1 — Preflight & Discovery (gate)                                      │
│    0   Pre-Flight       Config validation, sandbox setup, env checks        │
│    1   Discovery         Detect project type, tests, isolation level        │
│                                                                             │
│  Tier 2 — Test Execution & Analysis (parallel)                              │
│    2   Execute&Analyze   Run tests, coverage, reporting, failure analysis   │
│    2a  Runtime           Service health checks & connectivity               │
│                                                                             │
│  Tier 3 — Read-Only Analysis (parallel)                                     │
│    5   Security          8-tool security suite (SAST + deps + secrets)      │
│    6   Dependencies      Package health & outdated checks                   │
│    7   Quality           Linting, complexity, formatting, dead code detect  │
│    H   Holistic          Full-stack cross-component analysis                │
│    I   Infrastructure    Infrastructure & runtime issue detection           │
│                                                                             │
│  Tier 4 — Modifications (blocking)                                          │
│   10   Fix               Auto-fix ALL issues found in Tier 3                │
│                                                                             │
│  Tier 5 — Verification                                                      │
│   12   Verify            Re-run tests; loop to Tier 4 if failures           │
│                                                                             │
│  Tier 6 — Documentation                                                     │
│   13   Docs              Sync docs with codebase (always runs)              │
│                                                                             │
│  Tier 7 — App, Production & Docker Validation (conditional)                 │
│    A   App Test          Sandbox installation & deployment testing           │
│    P   Production        Validate installed production app                  │
│    D   Docker            Validate Docker image & registry package           │
│    G   GitHub            Audit repo security: Dependabot, CodeQL, etc.      │
│                                                                             │
│  Tier 8 — VM Testing (conditional)                                          │
│    V   VM Testing        Heavy isolation in libvirt/QEMU VM                 │
│   VM   VM Lifecycle      VM snapshot create/revert/delete management        │
│                                                                             │
│  Cleanup (always last)                                                      │
│    C   Cleanup           Restore environment, remove temp files             │
│                                                                             │
│  SPECIAL PHASES (independent tracks)                                        │
│  ─────────────────────────────────────                                      │
│   ST   Self-Test         Validate the test-skill framework itself           │
│                                                                             │
│  NOTES                                                                      │
│  ─────                                                                      │
│  • Autonomous mode (default): fixes ALL issues, no prompts, loops           │
│  • Interactive mode (--interactive): single pass, may prompt                │
│  • Phase P/D/G: auto-skipped when not applicable (no prompts)               │
│  • Phase V: auto-triggered when isolation level is vm-required              │
│  • Phase ST: NEVER runs in normal /test — explicit --phase=ST only          │
│  • Phase 13: ALWAYS runs — docs must stay in sync with code                 │
│  • Tier dependencies enforced: phases never run before prerequisites        │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

3. **Handle shortcuts:**
   - `prodapp` → `--phase=P` (production validation)
   - `docker` → `--phase=D` (Docker validation)
   - `qaapp` → load project QA app module (test-*-qa-app.md from project root)
   - `qadocker` → load project QA docker module (test-*-qa-docker.md from project root)
   - `qaall` → load project QA all module (test-*-qa-all.md from project root)
   - `security` → `--phase=5` (comprehensive security audit)
   - `github` → `--phase=G` (GitHub repository audit)
   - `holistic` → `--phase=H` (full-stack cross-component analysis)
   - `--phase=SEC` → `--phase=5` (alias for security phase)
4. **Build execution plan from requested phases**

### QA Module Loading (Project-Specific)

When the argument is `qaapp`, `qadocker`, or `qaall`:

1. **Map shortcut to file suffix:**
   - `qaapp` → `app`
   - `qadocker` → `docker`
   - `qaall` → `all`

2. **Find module file in project root:**
   ```bash
   SUFFIX={app|docker|all}  # based on shortcut
   MODULE_FILE=$(ls ${PROJECT_DIR}/test-*-qa-${SUFFIX}.md 2>/dev/null | head -1)
   ```

3. **Validate module exists:**
   - If no file found:
     ```
     ERROR: No QA ${SUFFIX} module found in project root.
     Expected: test-*-qa-${SUFFIX}.md
     Create a project-specific QA test module to use this shortcut.
     ```
     **ABORT** — do not fall back to any built-in phase.

4. **Read vm-test-manifest.json QA config:**
   ```bash
   QA_CONFIG=$(python3 -c "import json; print(json.dumps(json.load(open('${PROJECT_DIR}/vm-test-manifest.json')).get('qa_vm', {})))" 2>/dev/null)
   ```
   If no `qa_vm` section found, WARN but continue (module may have inline config).

5. **Execute as standalone subagent:**
   - Read the module file contents
   - Spawn a single Task subagent with `model: opus`
   - Pass the module contents as the subagent's instructions
   - Include context: `PROJECT_DIR`, QA VM config from manifest, SSH config
   - **QA modules are STANDALONE** — no tier system, no S/M/0/1 prerequisites
   - The module handles its own VM connectivity, version checks, upgrades, DB sync
   - **No other phases run** — qaapp/qadocker/qaall are self-contained

6. **Report results:**
   - Collect subagent output
   - Display QA test summary
   - Return overall PASS/FAIL status

**Key difference from built-in phases:** QA shortcuts bypass the entire tier/gate execution system. They are project-specific, standalone operations that load their own instructions.

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
   TIER 0: Snapshot [S] - Run SEQUENTIALLY (single Task)
   ──────────────────────────────────────────────────────────────────
   Wait for completion → GATE 0: Snapshot Ready
   If --skip-snapshot: exclude S

   TIER 1: Preflight & Discovery [0, 1] - Run SEQUENTIALLY
   ──────────────────────────────────────────────────────────────────
   Phase 0 includes config validation and sandbox setup
   Wait for completion → GATE 1: Project Known
   ⛔ ABORT if this fails - nothing else can proceed
   📋 Extract Phase P recommendation from output:
      - Installable App: [type or "none"]
      - Production Status: [installed|not-installed|installed-not-running]
      - Phase P Recommendation: [SKIP|RUN|PROMPT]
   📋 Extract staged release status from output:
      - Staged Release: [valid|invalid|none]
      - Staged Version: [X.Y.Z or empty]
      - If "valid": Phase V will be triggered for lifecycle testing
   📋 Extract custom pytest options from output:
      - Parse `Pytest Custom Option: --flag | help text | resource-type` lines
      - Resource types: vm, hardware, other
      - **ALWAYS prompt for vm/hardware flags** (even in autonomous mode):
        These require physical resources or human action that can't be automated.
        Use AskUserQuestion (multiSelect: true) with only the vm/hardware flags.
        This is the sole autonomous-mode exception for pytest flag prompting.
      - If user selects --hardware, show reminder:
        "Hardware tests require manual action (e.g., touch your security key
        when it flashes, or approve on your passkey device). Stay attentive
        during Phase 2."
      - For `other` flags: only prompt in --interactive mode, skip in autonomous
      - If no resource flags and autonomous: Set PYTEST_EXTRA_FLAGS=""
      - Pass PYTEST_EXTRA_FLAGS as context to Phase 2 subagent

   TIER 2: Test Execution & Analysis [2, 2a] - Run in PARALLEL
   ──────────────────────────────────────────────────────────────────
   Phase 2 now includes coverage, reporting, and failure analysis
   📋 Pass PYTEST_EXTRA_FLAGS to Phase 2 subagent context:
      "Set PYTEST_EXTRA_FLAGS to: [flags from Discovery]"
      (empty string if no flags selected)
   Wait for all to complete → GATE 2: Tests Complete

   TIER 3: Analysis [5,6,7,H,I] - Run in PARALLEL
   ──────────────────────────────────────────────────────────────────
   All are READ-ONLY, safe to parallelize
   Phase 7 now includes dead code detection
   ⚠️ Phase 13 is NOT in this tier (moved to Tier 6)
   Wait for all to complete → GATE 3: Analysis Complete

   TIER 4: Modifications [10] - Run ALONE (no parallel)
   ──────────────────────────────────────────────────────────────────
   ⛔ Must wait for ALL Tier 3 to complete
   ⛔ No other phases can run during this
   Wait for completion → GATE 4: Fixes Applied

   TIER 5: Verification [12] - Run SEQUENTIALLY
   ──────────────────────────────────────────────────────────────────
   Wait for completion → GATE 5: Verified
   If tests fail, loop back to TIER 4 (Fix) until clean

   TIER 6: Documentation [13] - ALWAYS RUNS
   ──────────────────────────────────────────────────────────────────
   ✅ ALWAYS runs - documentation must stay current
   ✅ Fixes ALL doc issues: versions, paths, obsolete content
   Wait for completion → GATE 6: Docs Complete

   TIER 7: App, Production, Docker & GitHub Validation [A, P, D, G] - CONDITIONAL
   ──────────────────────────────────────────────────────────────────
   **Phase A** - App Testing:
     - Sandbox installation & deployment testing
     - Runs if project has deployable app components

   **Phase P** - Check Phase P Recommendation from Discovery:
     - SKIP: Log "No installable app or not installed" and proceed to Phase D
     - RUN: Execute Phase P, fix any issues found
     (No prompts - fully autonomous)

   **Phase D** - Check Phase D Recommendation from Discovery:
     - SKIP: Log "No Dockerfile or registry package" and proceed to Phase G
     - RUN: Execute Phase D, fix any version sync issues
     (No prompts - fully autonomous)

   **Phase G** - Check Phase G Recommendation from Discovery:
     - SKIP: Log "No GitHub remote or gh not authenticated" and proceed to Tier 8
     - RUN: Execute Phase G, audit and fix GitHub security settings
     (No prompts - fully autonomous)
   Wait for completion (or skip) → GATE 7: App/Production/Docker/GitHub Done

   TIER 8: VM Testing [V, VM] - CONDITIONAL
   ──────────────────────────────────────────────────────────────────
   Conditional on isolation level or staged release detection
   V: Heavy isolation testing in VM
   VM: VM lifecycle snapshot management
   Wait for completion (or skip) → GATE 8: VM Complete

   CLEANUP: [C] - Run LAST (never parallel, always runs)
   ──────────────────────────────────────────────────────────────────
   Always runs regardless of prior failures (cleanup is mandatory)
   ```

6. **For each tier, spawn Task subagent(s) with model selection:**
   - **Parallel tier**: Multiple Task tool calls in SINGLE message
   - **Sequential tier**: Single Task tool call, wait for result
   - Each subagent reads `~/.claude/skills/test-phases/phase-{X}-{name}.md`
   - Each returns summary with Status, Issue count, Key findings
   - **Model selection per phase** (use `model` parameter on Task tool):
     - `opus`: Phases 1, 5, 7, 10, A, P, D, G, H, ST
     - `sonnet`: Phases 0, 2, 2a, 6, 12, 13, I, V, VM
     - `haiku`: Phases S, C
   - Use `run_in_background: true` for long-running phases where appropriate

7. **Gate validation between tiers:**
   - Collect all results from current tier
   - Check for failures
   - SAFETY/DISCOVERY failures → abort audit
   - Other failures → warn and continue

8. **Generate final report after all tiers complete**

### Special Phase Handling

**Phase A (App Testing):**
- Position: Tier 7 (after Docs, alongside Production/Docker/GitHub)
- Depends on: Tier 1 (Discovery) completing
- Runs in sandbox - separate from production validation

**Phase P (Production) - Autonomous:**
- Position: Tier 7 (after Docs, before VM)
- Conditional execution based on Discovery results
- Two possible outcomes (no prompts):
  1. **SKIP**: No installable app or not installed → proceed to Phase D
  2. **RUN**: Production app is installed → validate and fix issues

**Phase D (Docker) - Autonomous:**
- Position: Tier 7 (after Phase P, before Phase G)
- Conditional execution based on Discovery results
- Two possible outcomes (no prompts):
  1. **SKIP**: No Dockerfile or registry package → proceed to Phase G
  2. **RUN**: Dockerfile + registry package found → validate and fix version sync

**Phase G (GitHub) - Autonomous:**
- Position: Tier 7 (after Phase D, before VM)
- Conditional execution based on Discovery results
- Two possible outcomes (no prompts):
  1. **SKIP**: No GitHub remote or gh CLI not authenticated → proceed to Tier 6
  2. **RUN**: GitHub remote + gh authenticated → full security audit
- Audits: Dependabot, CodeQL workflows, secret scanning, branch protection
- Auto-enables missing security features when possible

**Phase 13 (Docs) - ALWAYS Runs:**
- Position: Tier 6 (after Verify, before App/Production/Docker)
- ALWAYS runs regardless of prior phase status
- Fixes ALL documentation issues: version refs, obsolete paths, outdated content
- Documentation MUST match current codebase state
- Rationale: Docs should always be current, even if codebase has issues to track

**Phase C (Cleanup) - Always Runs:**
- Always executes regardless of prior failures
- Cleanup is mandatory for environment hygiene

**Phase V (VM Testing) - Conditional on Isolation Level OR Staged Release:**
- Position: Tier 8 - VM isolation when sandbox is insufficient
- Conditional execution based on Discovery `ISOLATION_LEVEL` output OR staged release detection
- Two independent triggers (either activates Phase V):
  1. **Isolation Level**: `vm-required` or `vm-recommended` with VM available
  2. **Staged Release**: `.staged-release` exists and is valid
- Possible outcomes:
  1. **SKIP**: No trigger active (sandbox isolation, no staged release)
  2. **RUN**: Either trigger active AND VM available
  3. **ABORT**: `ISOLATION_LEVEL` is `vm-required` AND no VM available
- Project-VM routing via `~/.claude/config/project-vm-map.json`:
  - Projects with dedicated VMs are routed automatically based on `exclusive_to` mappings
  - Exclusivity enforced — reserved VMs cannot be used by other projects
  - Default VM used for projects without explicit mapping
- Capabilities:
  - Deploy project to existing test VM via SSH
  - **Staged release lifecycle testing**: install → upgrade → deploy → verify
  - **Docker staging image testing**: transfer and smoke test on VM
  - Create new VM from ISO library if needed
  - Run tests in full OS isolation
  - Snapshot/restore for rollback after dangerous tests
  - Cross-distro testing (Ubuntu, Fedora, Debian, CachyOS, Windows)
- Use cases: PAM modifications, kernel params, systemd services, bootloader changes, **release verification**

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
- Example: `/test --phase=13` requires ALL phases 0-12 to have passed

---

## Recommended Execution

For full audit:
```
/test
```

For quick check:
```
/test --phase=0-2
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

For QA native app regression:
```
/test qaapp
```
Auto-upgrades the QA VM native app to the latest release, syncs the production database, and runs full regression (API, web, auth, services, logs).

For QA Docker regression:
```
/test qadocker
```
Same as qaapp but for the Docker container. Includes consistency check comparing Docker against native app.

For complete QA regression (both):
```
/test qaall
```
Runs native regression first, then Docker regression, then cross-validates version agreement, library counts, and API responses.

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

*Document Version: 4.0.0 — Phase consolidation (27→21), project-agnostic refactor, bloat reduction*
