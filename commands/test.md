---
description: Modular project audit - testing, security, debugging, fixing (phase-based loading for context efficiency, holistic by design) (user)
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
argument-hint: "[help] [prodapp] [docker] [qaapp] [qadocker] [qaall] [security] [github] [--phase=X] [--list-phases] [--skip-snapshot] [--interactive]"
---

# Modular Project Audit (/test)

A context-efficient project audit that loads phase instructions on-demand using subagents.

## GOVERNING LAW: All Errors, Warnings, and Issues Must Be Fixed

**All errors, warnings, and issues — pre-existing or otherwise — MUST be analyzed, root-caused, and fixed successfully. None may be skipped or deferred for any reason.**

This is the supreme governing law of /test. It cannot be superseded, diluted, narrowed, or circumvented by any project-specific test module, project-specific test rule, phase instruction, execution mode, or any other mechanism. If any project-level rule, test configuration, or phase instruction creates ambiguity, conflict, or confusion with this law, the source of that conflict must be identified and eliminated at the project level. This law is always the sole authority.

**Prohibited actions under this law:**
- Labeling any issue as "pre-existing", "cosmetic", "non-blocking", "low priority", "advisory", "won't fix", "not our changes", or any equivalent classification that results in not fixing it
- Deferring any issue to a "future" session, task, or release cycle
- Narrowing the scope of what "all" means based on context, judgment, or interpretation
- Producing lists of "manual changes required" or "recommended fixes" instead of fixing them
- Exercising discretion about which issues to fix — all means all, unconditionally

**No exception exists. No mode, flag, or option can override this law.**

### One-Way Ratchet

Project-specific test modules, rules, configurations, and definitions may strengthen the Governing Law's requirements for their respective project (e.g., stricter coverage thresholds, additional security checks, tighter config consistency). However, nothing at the project level may weaken, dilute, supersede, skip, or be interpreted in a way whose outcome would weaken any provision of this law. If a project-level rule creates ambiguity or appears to conflict with the Governing Law, the Governing Law prevails unconditionally — the project-level rule must be amended or removed.

### Commit and Release Integration

All fixes applied during a /test audit MUST be committed. If a locally staged, unpromoted release exists (`.staged-release` breadcrumb), all fix commits MUST be included in that staged release.

### Iterative Until Clean

All /test audits (except `--interactive`) are iterative. If any issues were detected and fixed during a /test audit, another complete audit of the same kind MUST be run after the fixes are committed. This cycle repeats until the audit completes with zero issues found. A single pass that finds and fixes issues is not a completed audit — only a clean pass is.

### Fix-Verify-Proof (FVP) Protocol — Mandatory Enforcement

**Every individual fix — not just every phase, every INDIVIDUAL FIX — requires a structured proof block.** A fix without a proof block is an incomplete fix. This is not a guideline; it is a mechanical requirement enforced by the output format.

**The FVP loop for every fix:**

```
1. IDENTIFY the issue (with file, line, specific symptom)
2. APPLY the fix (edit the code)
3. VERIFY the fix works (execute the affected functionality)
4. EMIT the proof block (mandatory structured output)
5. CHECK for collateral damage (run broader tests)
6. EMIT the collateral proof block
```

**Mandatory proof block format — must appear after EVERY fix:**

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

**Rules:**
- The `Verify` field must contain an **actually executed command** — not "should work", not "the code looks correct", not "verified by inspection"
- The `Before` and `After` fields must contain **observable output differences** — not descriptions of what the code does
- The `Proof` field must be `PASS` with specific evidence or `FAIL` with what went wrong
- If `Proof` is `FAIL`, the fix is not complete — loop back to step 2
- If `Collateral` shows any new failures, the fix introduced a regression — revert and try again
- A phase that applies N fixes must emit N proof blocks. A phase summary with "15 issues fixed" but zero proof blocks is a **protocol violation**

**Enforcement at phase boundaries:**
- Phase 6 (Fix): Every fix emits an FVP proof block. The phase output MUST contain one proof block per fix applied
- Phase 7 (Verify): Re-runs ALL checks. If any fix lacks a proof block from Phase 6, Phase 7 MUST flag it as `UNVERIFIED_FIX` and the audit cannot pass
- Phase 9a-9d (Validation): Each finding and fix emits its own proof block
- QA modules: Every regression test step emits proof (command output, HTTP response, etc.)

**Iterative re-testing after fixes:**
When Phase 7 finds failures introduced by Phase 6 fixes:
1. Loop back to Phase 6 with the new failures
2. Phase 6 fixes them, emitting FVP proof blocks for each
3. Phase 7 re-verifies, emitting its own verification proof
4. This loop repeats until Phase 7 produces a clean pass WITH proof
5. After the fix-verify loop converges, the ENTIRE audit re-runs from Phase 4a
6. Only a full audit pass with zero issues AND proof blocks for every prior fix constitutes completion

**Project-specific test modules** (QA app, QA docker, etc.) are subject to the same FVP Protocol. Every test step must produce observable proof. "Step passed" without command output is not proof.

### All Audits Are Holistic

Cross-component analysis is a structural property of **every** /test phase, not just analysis phases. Every phase that examines or modifies code MUST consider how its scope interacts with the rest of the system. There is no separate "holistic" mode or phase — holistic analysis is integral to all testing throughout the entire audit.

**Applies to ALL phases, not just analysis:**
- **Phase 4a (Execute)**: Tests must cover cross-component interactions, not just unit boundaries
- **Phase 5a-5d (Analysis)**: Each includes mandatory cross-component sections (security across boundaries, dependency chains, quality across modules, infrastructure integration surfaces)
- **Phase 6 (Fix)**: Fixes must be verified against cross-component impacts — fixing one module must not break another
- **Phase 7 (Verify)**: Re-verification must include cross-component regression checks
- **Phase 9a-9d (Validation)**: Production, Docker, and GitHub validation must verify cross-system consistency

**One-way ratchet:** Project-specific test modules, rules, configurations, and definitions may strengthen cross-component requirements for their respective project (e.g., require additional contract checks, stricter config consistency), but nothing at the project level may weaken, dilute, supersede, skip, or be interpreted in a way whose outcome would weaken the global law. The Governing Law is always the sole and final authority.

### Verified Proof Required

**No phase may be marked complete or successful without verified, verifiable proof.** "The code looks correct" and "it should work" are not proof. Every phase completion must include a proof artifact — command output, test results, tool output, or observable behavior — that demonstrates the claimed outcome actually occurred.

**Phase-specific proof requirements:**
- **Phase 4a**: Test pass/fail counts, coverage percentages, actual command output
- **Phase 5a-5d**: Scanner output with specific findings (or clean scan output proving no findings)
- **Phase 6**: FVP proof block per fix (see FVP Protocol above) — before/after with executed commands
- **Phase 7**: Test output showing pass counts >= pre-fix counts, no regressions, proof of each Phase 6 fix still holding
- **Phase 9b**: Live service responses, systemd status output, port check results
- **Phase 9c**: Docker build output, container health check results, registry version verification
- **Phase 9d**: GitHub API responses confirming security settings

**If proof cannot be produced** (e.g., no browser available for UI verification), the phase MUST explicitly state what could not be verified and ask the user to confirm. Never substitute "should work" for proof.

### AI Self-Promotion Purge — Mandatory

**All /test audits MUST scan for and remove AI-generated self-promotion, advertising, branding, and attribution injected by language models.** This is a code quality issue and a documentation hygiene issue.

**What to scan for and remove:**
- `Co-Authored-By:` lines referencing Claude, Anthropic, GPT, OpenAI, Copilot, or any AI assistant — in commits, code comments, and documentation
- "Generated with [AI tool]", "Built with Claude", "Powered by Anthropic", "Created by Claude Code" — in README, CHANGELOG, docs, code comments, PR descriptions
- Anthropic URLs injected as attribution (`claude.ai`, `anthropic.com`) — in code, docs, templates, PR bodies
- AI watermarking patterns: emojis used as AI branding (robot emoji preceding attribution), "AI-assisted" badges, "Made with AI" footers
- Marketing language for AI tools embedded in project documentation or commit messages

**Where to scan:**
- All documentation files (`*.md`, `*.txt`, `*.rst`)
- All code comments (inline and block)
- Git commit messages: `git log --all --format='%H %s' | grep -iE 'co-authored|claude|anthropic|generated.with'`
- PR and issue templates (`.github/`)
- Package metadata (`package.json` description, `pyproject.toml` description, `Cargo.toml` description)
- Dockerfile labels and comments
- CI/CD workflow files

**How to fix:**
- Remove the self-promotion line/block entirely — do not replace with alternative attribution
- For commits with `Co-Authored-By` in their message: cannot rewrite published history, but flag for awareness and ensure no new commits include it
- For template files that auto-inject AI branding: remove the injection template

**Enforcement:**
- Phase 5c (Quality): Scans code and comments for AI self-promotion patterns
- Phase 8 (Docs): Scans all documentation for AI branding and removes it
- Both phases: Report findings as quality issues subject to Phase 6 fix
- Project-specific QA modules: Include AI self-promotion check in regression testing

---

## CRITICAL: Autonomous Resolution Directive

**The /test skill MUST fix and resolve ALL issues autonomously.**

This skill operates **entirely non-interactively** except in extremely rare cases requiring major architectural changes affecting the entire codebase, production application, AND Docker deployment simultaneously.

### Behavioral Requirements

1. **Fix ALL Issues**: Every issue found — regardless of priority, severity, or complexity — MUST be fixed. No "advisory" or "low priority" issues left for manual resolution.

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

5. **Iterative Until Clean (FVP Enforced)**: Phase 6 (Fix) and Phase 7 (Verify) form a loop within each audit pass. Every individual fix MUST emit an FVP proof block (see FVP Protocol). If verification finds new issues introduced by fixes, fix those too — each with its own proof block. After all fixes are committed, the entire audit of the same kind re-runs from the beginning. This continues until a complete audit pass finds zero issues. A single pass that finds and fixes issues is not a completed audit.

6. **Production Data Isolation**: No test VM, QA VM, or test/QA Docker container may have LIVE ACCESS (mounts) to production storage. NFS, CIFS, virtiofs, virtio-9p mounts and Docker `-v` bind-mounts to host production paths are forbidden. Copying production data *into* a test/QA environment is allowed — once on the VM's own disk, it's fully isolated. Test VM libraries should be ≤275GB. This boundary is enforced across all phases (A, D, V, VM-lifecycle).

---

## Quick Reference

```
/test                    # Full audit (autonomous - fixes everything)
/test prodapp            # Validate installed production app (Phase 9b)
/test docker             # Validate Docker image and registry (Phase 9c)
/test qaapp              # QA VM: regression test native app (auto-upgrade + DB sync)
/test qadocker           # QA VM: regression test Docker container (auto-upgrade + DB sync)
/test qaall              # QA VM: regression test both native and Docker sequentially
/test security           # Comprehensive security audit (Phase 5a/SEC)
/test github             # Audit GitHub repository settings (Phase 9d)
/test --phase=10a        # Force VM testing (Phase 10a)
/test --phase=9a         # Run single phase
/test --phase=1-3        # Run phase range
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
| **Interactive** | `--interactive` | May prompt user for decisions, still fixes ALL issues |

**Autonomous mode** (default):
- Fixes every issue regardless of priority/severity
- No user prompts except for safety/architecture/external blocks
- Loops until all tests pass and all issues resolved
- Documentation automatically synchronized

**Interactive mode** (`--interactive`):
- May prompt for decisions (Phase 9b/9c conditional execution)
- Still fixes ALL issues — interactive mode changes prompting behavior, not the fix mandate
- Loops until all tests pass and all issues resolved
- The Governing Law applies unconditionally in both modes

## Available Phases

The phase number IS the execution order. Same-number sub-phases (a/b/c/d) run in parallel or are conditional.

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

### Quick Reference

| Phase | Depends On | Parallel With |
|-------|------------|---------------|
| 1 | None | — |
| 2 | 1 | — |
| 3 | 1, 2 | — (GATE) |
| 4a, 4b | 3 | Each other |
| 5a, 5b, 5c, 5d | 3, 4 | Each other |
| **6** | **All phase 5** | **None (BLOCKING)** |
| 7 | 6 | — |
| 8 | 7 (only if all prior passed) | — |
| 9a, 9b, 9c, 9d | 6 + Discovery flags | Conditional |
| 10a, 10b | 3 (isolation-required) | Conditional |
| 11 | All | Always last |
| ST | None | Isolated (never in normal runs) |

**Legend:**
- **Bold** phases modify files — they run strictly sequentially
- Phase 9b/9c/9d are **conditional** — skipped if Discovery doesn't detect the relevant target
- Phase 10a/10b are **conditional** — run when `ISOLATION_LEVEL` is `vm-required` or `vm-recommended`
- Phase 8 **ALWAYS runs** - documentation must stay synchronized with code
- Phase ST is **isolated** - ONLY runs when explicitly called with `--phase=ST` (never in normal runs)

### Phase 9b Conditional Execution

Phase 9b (Production Validation) execution depends on Discovery (Phase 3) results:

| Discovery: Installable App | Discovery: Production Status | Phase 9b Action |
|---------------------------|------------------------------|----------------|
| `none` | N/A | **SKIP** - No app to validate |
| Any | `installed` | **RUN** - Validate production |
| Any | `installed-not-running` | **RUN** - Check why not running |
| Any | `not-installed` | **SKIP** - App not installed on this system |

When Phase 9b is skipped, Phase 9c proceeds (or 9d if 9c also skipped).

### Phase 9c Conditional Execution

Phase 9c (Docker Validation) execution depends on Discovery (Phase 3) results:

| Discovery: Dockerfile | Discovery: Registry Package | Phase 9c Action |
|-----------------------|----------------------------|----------------|
| `none` | N/A | **SKIP** - No Docker to validate |
| exists | `not-found` | **SKIP** - No registry package to validate |
| exists | `found` | **RUN** - Validate image and registry package |
| exists | `version-mismatch` | **RUN** - Flag and FIX version sync issue |

When Phase 9c is skipped, Phase 9d proceeds (or phase 10 if 9d also skipped).

### Phase 9d Conditional Execution

Phase 9d (GitHub Audit) execution depends on Discovery (Phase 3) results:

| Discovery: GitHub Remote | Discovery: gh CLI Auth | Phase 9d Action |
|--------------------------|------------------------|----------------|
| `none` | N/A | **SKIP** - No GitHub remote to audit |
| exists | `not-authenticated` | **SKIP** - Cannot audit without gh CLI auth |
| exists | `authenticated` | **RUN** - Full GitHub repository audit |

When Phase 9d is skipped, phase 10 (VM) proceeds (or phase 11 Cleanup if VM also skipped).

### Phase 10a (VM Testing) Conditional Execution

Phase 10a execution depends on **both** Discovery (Phase 3) isolation analysis AND Pre-Flight (Phase 2) VM availability, **plus staged release detection**:

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

**Two independent triggers for Phase 10a:**
1. **Isolation Level** — project contains dangerous patterns requiring VM isolation
2. **Staged Release** — `.staged-release` breadcrumb exists and is valid

Either trigger independently activates Phase 10a when a VM is available.

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

### Sandbox vs Phase 10a Selection

The dispatcher automatically selects the appropriate isolation:

| Isolation Level | Sandbox (Phase 2) | Phase 10a (VM) |
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
│  Phase number = execution order. Sub-phases (a/b/c/d) = parallel/cond.     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  1: SNAPSHOT (Complete before ANY file modifications)                       │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ 1 (Snapshot) ──> Clean old snapshots, create safety snapshot        │   │
│  │                   └──> GATE: Snapshot Ready                         │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                              │                                              │
│                              ▼                                              │
│  2-3: PREFLIGHT & DISCOVERY (Everything depends on these completing)       │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ 2 (Pre-Flight) ──> Config validation, sandbox setup, env checks     │   │
│  │ 3 (Discovery) ──> Project type, tests, isolation level              │   │
│  │   - Detects: Installable app? Production installed? Docker? GitHub? │   │
│  │   - Sets conditional phase flags: 9b/9c/9d SKIP/RUN                │   │
│  │                   └──> GATE: Project Known                          │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                              │                                              │
│                              ▼                                              │
│  4: TEST EXECUTION (parallel sub-phases)                                   │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ 4a (Execute & Analyze) ─┬─> Run tests, coverage, failure analysis  │   │
│  │ 4b (Runtime)            ─┘   Can run in PARALLEL                    │   │
│  │                   └──> GATE: Tests Complete                         │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                              │                                              │
│                              ▼                                              │
│  5: READ-ONLY ANALYSIS (parallel sub-phases, no file modifications)        │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ These phases ONLY READ files - safe to run in parallel:             │   │
│  │ 5a (Security), 5b (Dependencies), 5c (Quality), 5d (Infrastructure)│   │
│  │                   └──> GATE: Analysis Complete                      │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                              │                                              │
│                              ▼                                              │
│  6: FIX (STRICTLY SEQUENTIAL - Never parallel!)                            │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ 6 (Fix) ────> MODIFIES FILES                                        │   │
│  │   ⛔ ALL analysis phases (5a-5d) MUST complete before this starts   │   │
│  │   ⛔ NO other phases can run while this is running                  │   │
│  │                   └──> GATE: Fixes Applied                          │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                              │                                              │
│                              ▼                                              │
│  7: VERIFICATION (After modifications)                                     │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ 7 (Verify) ──> Re-run tests after fixes                             │   │
│  │   If failures → loop back to phase 6                                │   │
│  │                   └──> GATE: Verified                               │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                              │                                              │
│                              ▼                                              │
│  8: DOCUMENTATION (ALWAYS runs)                                            │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ 8 (Docs) ──> Documentation review/update — MODIFIES FILES           │   │
│  │   ✅ ALWAYS runs - docs must stay in sync with code                 │   │
│  │                   └──> GATE: Docs Complete                          │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                              │                                              │
│                              ▼                                              │
│  9: APP, PRODUCTION, DOCKER & GITHUB (Conditional sub-phases)              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ 9a (App Test) ──> Sandbox installation & deployment testing         │   │
│  │ 9b (Production) ──> Validates live installed app                    │   │
│  │ 9c (Docker) ──> Validates Docker image and registry package         │   │
│  │ 9d (GitHub) ──> Audits GitHub repository security and settings      │   │
│  │   📋 Each conditionally SKIP or RUN based on Discovery flags        │   │
│  │                   └──> GATE: Validation Done                        │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                              │                                              │
│                              ▼                                              │
│  10: VM TESTING (Conditional on isolation level or staged release)          │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ 10a (VM Testing) ──> Heavy isolation in libvirt/QEMU VM             │   │
│  │ 10b (VM Lifecycle) ──> Snapshot create/revert/delete management     │   │
│  │                   └──> GATE: VM Complete                            │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                              │                                              │
│                              ▼                                              │
│  11: CLEANUP (ALWAYS LAST)                                                  │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ 11 (Cleanup) ──> MUST be last phase, never parallel                 │   │
│  │   Always runs regardless of prior failures (cleanup is mandatory)   │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  SPECIAL (Independent — never in normal runs):                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ ST (Self-Test) ─> ISOLATED: validates test-skill framework itself   │   │
│  │   ⛔ ONLY runs when explicitly called: /test --phase=ST             │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Parallel Execution Rules

| Phase | Sub-phases | Parallel? | Gate Condition |
|-------|-----------|-----------|----------------|
| 1 | — | ❌ No (single) | Snapshot complete |
| 2, 3 | — | ❌ No (sequential) | Pre-Flight + Discovery complete |
| 4 | 4a, 4b | ✅ Yes | Tests complete |
| 5 | 5a, 5b, 5c, 5d | ✅ Yes | All analysis complete |
| 6 | — | ❌ No (blocking) | Fixes complete |
| 7 | — | ❌ No | Verification complete |
| 8 | — | ❌ No | Docs complete (always runs) |
| 9 | 9a, 9b, 9c, 9d | ❌ No (conditional) | Validation complete OR skipped |
| 10 | 10a, 10b | ❌ No (conditional) | VM testing complete OR skipped |
| 11 | — | ❌ No (always last) | Cleanup complete (always runs) |

### Execution Algorithm

```
function executeAudit(requestedPhases):
    # Build execution plan respecting dependencies
    executionPlan = []
    allPhasesSucceeded = true

    # Phase 1: Snapshot
    if 1 in requestedPhases:
        executionPlan.append({phases: [1], parallel: false, gate: "SNAPSHOT"})

    # Phases 2-3: Pre-Flight + Discovery (sequential - BLOCKER)
    # Pre-Flight includes config validation and sandbox setup
    # Discovery determines conditional flags AND isolation level
    setup = intersection(requestedPhases, [2, 3])
    if setup:
        executionPlan.append({phases: setup, parallel: false, gate: "DISCOVERY"})
        # After Discovery (phase 3) completes, extract:
        #   - phase9bRecommendation: "SKIP" | "RUN" (Production)
        #   - phase9cRecommendation: "SKIP" | "RUN" (Docker)
        #   - phase9dRecommendation: "SKIP" | "RUN" (GitHub)
        #   - isolationLevel: "sandbox" | "sandbox-warn" | "vm-recommended" | "vm-required"
        #   - dangerScore: numeric score from pattern detection
        #   - stagedRelease: "valid" | "invalid" | "none"
        #   - stagedVersion: version string (or empty)

    # Phase 4: Test Execution (parallel sub-phases)
    phase4 = intersection(requestedPhases, ["4a", "4b"])
    if phase4:
        executionPlan.append({phases: phase4, parallel: true, gate: "TESTS"})

    # Phase 5: Analysis (parallel sub-phases, all read-only)
    phase5 = intersection(requestedPhases, ["5a", "5b", "5c", "5d"])
    if phase5:
        executionPlan.append({phases: phase5, parallel: true, gate: "ANALYSIS"})

    # Phase 6: Fix (NEVER parallel)
    if 6 in requestedPhases:
        executionPlan.append({phases: [6], parallel: false, gate: "FIXES"})

    # Phase 7: Verification
    if 7 in requestedPhases:
        executionPlan.append({phases: [7], parallel: false, gate: "VERIFY"})

    # Phase 8: Documentation (ALWAYS runs)
    if 8 in requestedPhases:
        executionPlan.append({phases: [8], parallel: false, gate: "DOCS"})

    # Phase 9: App, Production, Docker & GitHub Validation (CONDITIONAL)
    phase9 = []
    if "9a" in requestedPhases:
        phase9.append({phase: "9a", condition: "always"})
    if "9b" in requestedPhases:
        phase9.append({phase: "9b", condition: "phase9bRecommendation"})
    if "9c" in requestedPhases:
        phase9.append({phase: "9c", condition: "phase9cRecommendation"})
    if "9d" in requestedPhases:
        phase9.append({phase: "9d", condition: "phase9dRecommendation"})
    if phase9:
        executionPlan.append({
            phases: phase9,
            parallel: false,  # Run 9a then 9b then 9c then 9d sequentially
            gate: "VALIDATION",
            conditional: true
        })

    # Phase 10: VM Testing (CONDITIONAL on isolation level or staged release)
    phase10 = intersection(requestedPhases, ["10a", "10b"])
    if phase10:
        executionPlan.append({
            phases: phase10,
            parallel: false,
            gate: "VM",
            conditional: true
        })

    # Phase 11: Cleanup (always last, always runs)
    if 11 in requestedPhases:
        executionPlan.append({phases: [11], parallel: false, gate: "CLEANUP", alwaysRun: true})

    # Execute plan sequentially
    for step in executionPlan:
        # Handle conditional execution (Phase 9 sub-phases)
        if step.conditional:
            for phaseInfo in step.phases:
                if phaseInfo.phase == "9a":
                    pass  # App testing always runs if requested
                elif phaseInfo.phase == "9b":
                    if phase9bRecommendation == "SKIP":
                        log("Phase 9b skipped: No installable app or not installed")
                        continue
                elif phaseInfo.phase == "9c":
                    if phase9cRecommendation == "SKIP":
                        log("Phase 9c skipped: No Dockerfile or registry package")
                        continue
                elif phaseInfo.phase == "9d":
                    if phase9dRecommendation == "SKIP":
                        log("Phase 9d skipped: No GitHub remote or gh not authenticated")
                        continue

        # Execute the step
        if step.parallel:
            results = parallelExecute(step.phases)  # Use Task tool in parallel
        else:
            results = sequentialExecute(step.phases)

        # Check gate - track failures
        if any(result.status == FAIL for result in results):
            allPhasesSucceeded = false
            if step.gate in ["SNAPSHOT", "DISCOVERY"]:
                abort("Critical gate failed: " + step.gate)
            else:
                warn("Gate " + step.gate + " had failures")

        # ISOLATION LEVEL GATE (after Discovery completes)
        if step.gate == "DISCOVERY":
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
                start_test_vm()
                useVM = true
            elif isolationLevel == "vm-recommended" and vmAvailable:
                log("VM isolation recommended and available - starting test VM...")
                start_test_vm()
                useVM = true
            elif isolationLevel == "vm-recommended" and not vmAvailable:
                warn("VM isolation recommended but not available")
                warn("Proceeding with sandbox - exercise caution")
                useVM = false
            elif isolationLevel == "sandbox-warn":
                log("Sandbox with extra monitoring")
                useVM = false
            else:  # sandbox
                log("Standard sandbox isolation sufficient")
                useVM = false

            # STAGED RELEASE GATE (additional Phase 10a trigger)
            if stagedRelease == "valid" and not useVM:
                log("Staged release v{stagedVersion} detected — Phase 10a will deploy and verify")
                if vmAvailable:
                    start_test_vm()
                    useVM = true
                else:
                    warn("Staged release detected but no VM available")
                    warn("Cannot run lifecycle tests without VM")

            # Note: VM shutdown is handled by Phase 11 cleanup (reads .test-vm-state)

        waitForGate(step.gate)
```

### Why This Matters

**Without dependency enforcement:**
```
❌ Phase 6 (Fix) runs parallel with Phase 5a (Security)
   → Security finds vulnerability in line 45
   → Fix modifies line 45 at the same time
   → Race condition: Report shows stale findings

❌ Phase 1 (Snapshot) runs parallel with Phase 6 (Fix)
   → Snapshot captures mid-modification state
   → Rollback would restore corrupted state

❌ Phase 5c (Quality) runs before Phase 4a (Execute)
   → No test results available for dead code analysis
   → Phase 5c reports incomplete findings
```

**With dependency enforcement:**
```
✅ 1 completes → snapshot is clean baseline
✅ 2, 3 complete → config validated, project type known
✅ 4a, 4b complete → test results + coverage + failure analysis available
✅ 5a-5d run parallel (read-only) → safe
✅ 6 runs alone → no race conditions
✅ 7 verifies → confirms fixes work
✅ 11 runs last → clean exit
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
**Sub-phases (a/b/c/d) may run in parallel. Phases run sequentially.**

### Subagent Model Selection

When spawning Task subagents for phases, specify the `model` parameter based on phase complexity:

| Model | Phases | Rationale |
|-------|--------|-----------|
| **opus** | 3, 5a, 5c, 6, 9a, 9b, 9c, 9d, ST | Complex analysis, multi-step fixes, security audit, cross-component reasoning |
| **sonnet** | 2, 4a, 4b, 5b, 7, 8, 5d, 10a, 10b | Moderate complexity: test execution, dependency checks, verification |
| **haiku** | 1, 11 | Lightweight: snapshots, cleanup |

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

**Phase 2 (Pre-Flight)** — includes config validation and sandbox setup:
- Check dependencies: `pip check` / `npm ls` / `go mod verify`
- Verify env vars exist
- Test service connectivity
- Check file permissions
- Validate configuration files
- Set up safe sandbox environment

**Phase 3 (Discovery)**:
- Identify project type (Python/Node/Go/Rust/etc.)
- Find test files
- Locate config files

**Phase 4a (Execute Tests & Analyze)** — includes coverage, reporting, and failure analysis:
- Run: `pytest` / `npm test` / `go test` / `cargo test`
- Check actual output, not just exit codes
- Run coverage tool and enforce 85% minimum (configurable)
- Summarize test results and analyze failures

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

**Phase 5a (Security)**:
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
| 1 | ✅ | 0 | 0 |
| 2 | ✅ | 0 | 0 |
| 6 | ✅ | 15 | 15 |
| 8 | ✅ | 3 | 3 |
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
│   4b    Runtime          Service health checks & connectivity       ║parallel│
│   5a    Security         8-tool security suite (SAST + deps + secrets)     │
│   5b    Dependencies     Package health & outdated checks            ║      │
│   5c    Quality          Linting, complexity, formatting, dead code  ║par.  │
│   5d    Infrastructure   Infrastructure & runtime issue detection    ║      │
│    6    Fix              Auto-fix ALL issues from phases 4-5 (BLOCKING)    │
│    7    Verify           Re-run tests; loop to 6 if failures               │
│    8    Docs             Sync docs with codebase (ALWAYS runs)             │
│   9a    App Test         Sandbox installation & deployment testing   ║      │
│   9b    Production       Validate installed production app           ║cond. │
│   9c    Docker           Validate Docker image & registry package    ║      │
│   9d    GitHub           Audit repo: Dependabot, CodeQL, etc.        ║      │
│  10a    VM Testing       Heavy isolation in libvirt/QEMU VM          ║cond. │
│  10b    VM Lifecycle     VM snapshot create/revert/delete management  ║      │
│   11    Cleanup          Restore environment (ALWAYS last)                  │
│   ST    Self-Test        Validate test-skill framework (--phase=ST only)   │
│                                                                             │
│  NOTES                                                                      │
│  ─────                                                                      │
│  • Autonomous mode (default): fixes ALL issues, no prompts, loops           │
│  • Interactive mode (--interactive): may prompt, still fixes ALL issues     │
│  • All audits are holistic — every analysis phase includes cross-component │
│  • All audits iterate until clean — re-run after fixes until zero issues   │
│  • Phase 9b/9c/9d: auto-skipped when not applicable (no prompts)            │
│  • Phase 10a: auto-triggered when isolation level is vm-required            │
│  • Phase ST: NEVER runs in normal /test — explicit --phase=ST only          │
│  • Phase 8: ALWAYS runs — docs must stay in sync with code                  │
│  • Dependencies enforced: phases never run before prerequisites             │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

3. **Handle shortcuts:**
   - `prodapp` → `--phase=9b` (production validation)
   - `docker` → `--phase=9c` (Docker validation)
   - `qaapp` → load project QA app module (test-*-qa-app.md from project root)
   - `qadocker` → load project QA docker module (test-*-qa-docker.md from project root)
   - `qaall` → load project QA all module (test-*-qa-all.md from project root)
   - `security` → `--phase=5a` (comprehensive security audit)
   - `github` → `--phase=9d` (GitHub repository audit)
   - `--phase=SEC` → `--phase=5a` (alias for security phase)
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
   - **QA modules are STANDALONE** — no phase prerequisites
   - The module handles its own VM connectivity, version checks, upgrades, DB sync
   - **No other phases run** — qaapp/qadocker/qaall are self-contained

6. **Report results:**
   - Collect subagent output
   - Display QA test summary
   - Return overall PASS/FAIL status

**Key difference from built-in phases:** QA shortcuts bypass the entire tier/gate execution system. They are project-specific, standalone operations that load their own instructions.

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
   Phase 1: Snapshot - Run SEQUENTIALLY
   ──────────────────────────────────────────────────────────────────
   Wait for completion → GATE: Snapshot Ready
   If --skip-snapshot: exclude phase 1

   Phases 2-3: Pre-Flight & Discovery - Run SEQUENTIALLY
   ──────────────────────────────────────────────────────────────────
   Phase 2 includes config validation and sandbox setup
   Wait for completion → GATE: Project Known
   ⛔ ABORT if this fails - nothing else can proceed
   📋 Extract conditional phase flags from output:
      - Installable App: [type or "none"]
      - Production Status: [installed|not-installed|installed-not-running]
      - Phase 9b Recommendation: [SKIP|RUN]
      - Phase 9c Recommendation: [SKIP|RUN]
      - Phase 9d Recommendation: [SKIP|RUN]
   📋 Extract staged release status from output:
      - Staged Release: [valid|invalid|none]
      - Staged Version: [X.Y.Z or empty]
      - If "valid": Phase 10a will be triggered for lifecycle testing
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
        during Phase 4a."
      - For `other` flags: only prompt in --interactive mode, skip in autonomous
      - If no resource flags and autonomous: Set PYTEST_EXTRA_FLAGS=""
      - Pass PYTEST_EXTRA_FLAGS as context to Phase 4a subagent

   Phase 4: Test Execution [4a, 4b] - Run in PARALLEL
   ──────────────────────────────────────────────────────────────────
   Phase 4a includes coverage, reporting, and failure analysis
   📋 Pass PYTEST_EXTRA_FLAGS to Phase 4a subagent context:
      "Set PYTEST_EXTRA_FLAGS to: [flags from Discovery]"
      (empty string if no flags selected)
   Wait for all to complete → GATE: Tests Complete

   Phase 5: Analysis [5a, 5b, 5c, 5d] - Run in PARALLEL
   ──────────────────────────────────────────────────────────────────
   All are READ-ONLY, safe to parallelize
   Phase 5c includes dead code detection
   Wait for all to complete → GATE: Analysis Complete

   Phase 6: Fix - Run ALONE (no parallel)
   ──────────────────────────────────────────────────────────────────
   ⛔ Must wait for ALL phase 5 sub-phases to complete
   ⛔ No other phases can run during this
   Wait for completion → GATE: Fixes Applied

   Phase 7: Verification - Run SEQUENTIALLY
   ──────────────────────────────────────────────────────────────────
   Wait for completion → GATE: Verified
   If tests fail, loop back to phase 6 (Fix) until clean
   After all fixes committed, re-run entire audit until clean pass

   Phase 8: Documentation - ALWAYS RUNS
   ──────────────────────────────────────────────────────────────────
   ✅ ALWAYS runs - documentation must stay current
   ✅ Fixes ALL doc issues: versions, paths, obsolete content
   Wait for completion → GATE: Docs Complete

   Phase 9: Validation [9a, 9b, 9c, 9d] - CONDITIONAL
   ──────────────────────────────────────────────────────────────────
   **Phase 9a** - App Testing:
     - Sandbox installation & deployment testing
     - Runs if project has deployable app components

   **Phase 9b** - Check Recommendation from Discovery:
     - SKIP: Log "No installable app or not installed" and proceed to 9c
     - RUN: Execute Phase 9b, fix any issues found
     (No prompts - fully autonomous)

   **Phase 9c** - Check Recommendation from Discovery:
     - SKIP: Log "No Dockerfile or registry package" and proceed to 9d
     - RUN: Execute Phase 9c, fix any version sync issues
     (No prompts - fully autonomous)

   **Phase 9d** - Check Recommendation from Discovery:
     - SKIP: Log "No GitHub remote or gh not authenticated" and proceed to phase 10
     - RUN: Execute Phase 9d, audit and fix GitHub security settings
     (No prompts - fully autonomous)
   Wait for completion (or skip) → GATE: Validation Done

   Phase 10: VM Testing [10a, 10b] - CONDITIONAL
   ──────────────────────────────────────────────────────────────────
   Conditional on isolation level or staged release detection
   10a: Heavy isolation testing in VM
   10b: VM lifecycle snapshot management
   Wait for completion (or skip) → GATE: VM Complete

   Phase 11: Cleanup - Run LAST (never parallel, always runs)
   ──────────────────────────────────────────────────────────────────
   Always runs regardless of prior failures (cleanup is mandatory)
   ```

6. **For each tier, spawn Task subagent(s) with model selection:**
   - **Parallel tier**: Multiple Task tool calls in SINGLE message
   - **Sequential tier**: Single Task tool call, wait for result
   - Each subagent reads `~/.claude/skills/test-phases/phase-{X}-{name}.md`
   - Each returns summary with Status, Issue count, Key findings
   - **Model selection per phase** (use `model` parameter on Task tool):
     - `opus`: Phases 3, 5a, 5c, 6, 9a, 9b, 9c, 9d, ST
     - `sonnet`: Phases 2, 4a, 4b, 5b, 7, 8, 5d, 10a, 10b
     - `haiku`: Phases 1, 11
   - Use `run_in_background: true` for long-running phases where appropriate

7. **Gate validation between tiers:**
   - Collect all results from current tier
   - Check for failures
   - SAFETY/DISCOVERY failures → abort audit
   - Other failures → warn and continue

8. **Generate final report after all tiers complete**

### Special Phase Handling

**Phase 9a (App Testing):**
- Runs after phase 8 (Docs), alongside 9b/9c/9d
- Depends on: Phase 3 (Discovery) completing
- Runs in sandbox - separate from production validation

**Phase 9b (Production) - Autonomous:**
- Conditional execution based on Discovery results
- Two possible outcomes (no prompts):
  1. **SKIP**: No installable app or not installed → proceed to 9c
  2. **RUN**: Production app is installed → validate and fix issues

**Phase 9c (Docker) - Autonomous:**
- Runs after 9b
- Conditional execution based on Discovery results
- Two possible outcomes (no prompts):
  1. **SKIP**: No Dockerfile or registry package → proceed to 9d
  2. **RUN**: Dockerfile + registry package found → validate and fix version sync

**Phase 9d (GitHub) - Autonomous:**
- Runs after 9c
- Conditional execution based on Discovery results
- Two possible outcomes (no prompts):
  1. **SKIP**: No GitHub remote or gh CLI not authenticated → proceed to phase 10
  2. **RUN**: GitHub remote + gh authenticated → full security audit
- Audits: Dependabot, CodeQL workflows, secret scanning, branch protection
- Auto-enables missing security features when possible

**Phase 8 (Docs) - ALWAYS Runs:**
- Runs after phase 7 (Verify), before phase 9 (Validation)
- ALWAYS runs regardless of prior phase status
- Fixes ALL documentation issues: version refs, obsolete paths, outdated content
- Documentation MUST match current codebase state
- Rationale: Docs should always be current, even if codebase has issues to track

**Phase 11 (Cleanup) - Always Runs:**
- Always executes regardless of prior failures
- Cleanup is mandatory for environment hygiene

**Phase 10a (VM Testing) - Conditional on Isolation Level OR Staged Release:**
- VM isolation when sandbox is insufficient
- Conditional execution based on Discovery `ISOLATION_LEVEL` output OR staged release detection
- Two independent triggers (either activates Phase 10a):
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
- ISOLATED — never part of normal phase execution
- NEVER included in normal `/test` runs (not even full audit)
- ONLY runs when explicitly called: `/test --phase=ST`
- No dependencies - runs completely standalone
- Purpose: Validates the test-skill framework itself (meta-testing)
- Checks: Phase file existence, symlinks, dispatcher, tool availability
- Use cases: After modifying phase files, updating symlinks, installing tools

**When user requests only specific phases:**
- Still enforce dependencies
- Example: `/test --phase=5a` still requires phase 3 (Discovery) to run first
- Example: `/test --phase=9b` requires Discovery AND all prior phases
- Example: `/test --phase=8` requires ALL phases 1-7 to have passed

---

## Recommended Execution

For full audit:
```
/test
```

For quick check:
```
/test --phase=1-3
```

For app deployment testing only:
```
/test --phase=9a
```

For comprehensive security audit (standalone):
```
/test security
# or: /test --phase=5a
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
| **playwright** | Phase 9a, 4b | E2E browser testing for web UIs |
| **pyright-lsp** | Phase 5c | Project-aware Python type checking |
| **typescript-lsp** | Phase 5c | TypeScript diagnostics with full context |
| **rust-analyzer-lsp** | Phase 5c | Rust analysis with macro expansion |
| **gopls-lsp** | Phase 5c | Go package-aware analysis |
| **clangd-lsp** | Phase 5c | C/C++ compile-command aware diagnostics |
| **context7** | Phase 3 | Enhanced codebase understanding |
| **greptile** | Phase 3 | Semantic code search |

### Auto-Enable/Disable

**`/test` automatically manages MCP servers:**

1. **Discovery (Phase 3)** detects which MCP servers would benefit the project
2. If a beneficial server is disabled, `/test` **temporarily enables it**
3. Enabled servers are tracked in `.test-mcp-enabled`
4. **Cleanup (Phase 11)** automatically disables any servers that were auto-enabled
5. Your original plugin configuration is restored

**Example flow:**
```
Phase 3 (Discovery):
  Project has: React frontend, Python backend
  Auto-enabling: playwright (for E2E), pyright-lsp (for type checking)
  Saved to: .test-mcp-enabled

Phase 9a (App Testing):
  Using playwright for E2E browser tests... ✅

Phase 5c (Quality):
  Using pyright-lsp for type checking... ✅

Phase 11 (Cleanup):
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

*Document Version: 5.0.0 — Unified sequential phase numbering (phase number = execution order), eliminated dual tier/phase system*
