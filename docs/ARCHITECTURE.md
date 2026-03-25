# Test-Skill Architecture

> Version: 4.1.0

This document describes the architecture of the claude-test-skill plugin for Claude Code, a modular 20-phase autonomous project audit system.

---

## Overview

The test-skill follows a **dispatcher + subagent** architecture that achieves ~93% context reduction compared to a monolithic approach. Instead of loading all 20 phases into context, only the dispatcher (~1,000 lines) is loaded, and individual phases are invoked on-demand via Task tool subagents with per-phase model selection.

```
┌─────────────────────────────────────────────────────────────────────┐
│                      TEST-SKILL ARCHITECTURE                        │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌─────────────┐  spawn (opus)  ┌──────────────────────────────┐   │
│  │ Dispatcher  │────────────────► Task Subagent (Phase 5)      │   │
│  │ test.md     │                │ Model: opus                   │   │
│  │ (~1000 ln)  │◄───────────────│ Reads: phase-5-security.md    │   │
│  │ model: opus │    summary     │ Reports: TaskUpdate            │   │
│  └─────────────┘                └──────────────────────────────┘   │
│        │                                                            │
│        │ spawn (parallel, model varies per phase)                   │
│        ▼                                                            │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  [Phase 5]   [Phase 6]   [Phase 7]   [Phase I]              │  │
│  │   opus       sonnet      opus        sonnet                  │  │
│  │  Running in parallel — each in its own subagent context      │  │
│  └──────────────────────────────────────────────────────────────┘  │
│        │                                                            │
│        ▼                                                            │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  TaskCreate / TaskUpdate / TaskList                           │  │
│  │  Real-time progress tracking with dependency chains           │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Directory Structure

```
claude-test-skill/
├── commands/
│   └── test.md                 # Main dispatcher (~1,000 lines)
│
├── skills/
│   └── test-phases/            # 20 phase files
│       │
│       │  ── TIER 0: Safety Gates ──
│       ├── phase-S-snapshot.md       # BTRFS safety snapshot          [haiku]
│       ├── phase-0-preflight.md      # Environment + config validation [sonnet]
│       │
│       │  ── TIER 1: Discovery ──
│       ├── phase-1-discovery.md      # Project detection (GATE)       [opus]
│       │
│       │  ── TIER 2: Testing ──
│       ├── phase-2-execute.md        # Run tests + analysis + coverage [sonnet]
│       ├── phase-2a-runtime.md       # Service health                 [sonnet]
│       │
│       │  ── TIER 3: Analysis (Read-Only) ──
│       ├── phase-5-security.md       # Comprehensive security         [opus]
│       ├── phase-6-dependencies.md   # Package health                 [sonnet]
│       ├── phase-7-quality.md        # Linting, complexity, cleanup   [opus]
│       ├── phase-I-infrastructure.md # Infrastructure issues          [sonnet]
│       │
│       │  ── TIER 4: Modifications ──
│       ├── phase-10-fix.md           # Auto-fixing (BLOCKING)         [opus]
│       │
│       │  ── TIER 5: Validation (Conditional) ──
│       ├── phase-A-app-testing.md    # Sandbox app testing            [opus]
│       ├── phase-P-production.md     # Production validation          [opus]
│       ├── phase-D-docker.md         # Docker/registry validation     [opus]
│       ├── phase-G-github.md         # GitHub security audit          [opus]
│       │
│       │  ── TIER 6: Verification ──
│       ├── phase-12-verify.md        # Re-run tests                   [sonnet]
│       │
│       │  ── TIER 7: Documentation ──
│       ├── phase-13-docs.md          # Doc synchronization            [sonnet]
│       │
│       │  ── TIER 8: Cleanup ──
│       ├── phase-C-restore.md        # Environment restore            [haiku]
│       │
│       │  ── SPECIAL: Isolated / Conditional ──
│       ├── phase-ST-self-test.md     # Framework self-validation      [opus]
│       ├── phase-V-vm-testing.md     # VM isolation testing           [sonnet]
│       └── phase-VM-lifecycle.md     # VM startup/shutdown            [sonnet]
│
├── agents/                     # Specialized subagents (integrated into phases)
│   ├── coverage-reviewer.md    # Test coverage analysis (integrated into Phase 2)
│   ├── security-scanner.md     # Security pattern matching (integrated into Phase 5)
│   └── test-analyzer.md        # Test result analysis (integrated into Phase 2)
│
├── examples/
│   └── test-skill.local.md     # Local configuration example
│
├── docs/
│   └── ARCHITECTURE.md         # This file
│
├── .github/
│   └── workflows/
│       └── security.yml        # Daily security scanning (pinned to SHAs)
│
├── plugin.json                 # Claude Code plugin manifest
├── VERSION                     # Current version
├── CHANGELOG.md                # Version history
├── README.md                   # User documentation
├── INSTALL.md                  # Installation guide for third-party users
├── SKILL.md                    # Claude.ai web upload version
└── LICENSE                     # MIT License
```

---

## Component Details

### Dispatcher (commands/test.md)

The dispatcher is the entry point for `/test` commands. It:

1. **Parses arguments** — Handles `--phase=X`, `--interactive`, shortcuts
2. **Builds execution plan** — Respects tier dependencies
3. **Selects models** — Assigns opus/sonnet/haiku per phase complexity
4. **Spawns subagents** — Uses Task tool for parallel/sequential execution
5. **Tracks progress** — Creates TaskCreate/TaskUpdate entries for each phase
6. **Enforces gates** — Blocks at tier boundaries until all phases complete
7. **Generates summary** — Aggregates results from all phases

**Key sections:**
- Quick Reference and argument parsing
- Available Phases table
- Subagent Model Selection table (opus/sonnet/haiku)
- Task Progress Tracking instructions
- Dependency graph and tier execution algorithm
- Inline fallback instructions for missing phase files

### Phase Files (skills/test-phases/)

Each phase file contains a standardized structure (v2.0.1+):

```markdown
# Phase X: Name

> **Model**: `opus` | **Tier**: 3 (Analysis) | **Modifies Files**: No
> **Task Tracking**: Call `TaskUpdate(taskId, status="in_progress")` at start...
> **Key Tools**: `Bash`, `WebSearch` for CVE lookups...

## Purpose
[Description]

## Section 1: [Category]
```​bash
# Executable code
```

## Output Format
Status: PASS / ISSUES / FAIL
Issues: [count]
```

**Configuration header fields (added in v2.0.1):**

| Field | Purpose |
|-------|---------|
| **Model** | Which model tier the subagent runs on (opus/sonnet/haiku) |
| **Tier** | Where in the execution graph this phase sits |
| **Modifies Files** | Whether the phase writes to the project |
| **Task Tracking** | Instructions for reporting progress via TaskUpdate |
| **Key Tools** | Phase-specific guidance on available tools |

### Agents (agents/)

Specialized subagents that are now integrated into their respective phases. The agent files remain as reference documentation:

| Agent | Purpose | Integrated Into |
|-------|---------|-----------------|
| coverage-reviewer.md | Deep coverage analysis | Phase 2 |
| security-scanner.md | Security pattern matching | Phase 5 |
| test-analyzer.md | Test failure root cause | Phase 2 |

---

## Model Tiering (Opus 4.6)

Each phase is assigned to an optimal model based on task complexity:

```
┌─────────────────────────────────────────────────────────────────────┐
│                      MODEL TIER ASSIGNMENTS                         │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  OPUS (9 phases)          Complex analysis, multi-step reasoning    │
│  ├── Phase 1  Discovery   Architecture detection, framework ID     │
│  ├── Phase 5  Security    8-tool security suite, CVE analysis       │
│  ├── Phase 7  Quality     LSP integration, complexity analysis      │
│  ├── Phase 10 Fix         Multi-file auto-fixing, refactoring       │
│  ├── Phase A  App Test    Sandbox deployment testing                │
│  ├── Phase P  Production  Live system validation                    │
│  ├── Phase D  Docker      Image/registry validation                 │
│  ├── Phase G  GitHub      Repository security audit                 │
│  └── Phase ST Self-Test   Framework meta-validation                 │
│                                                                     │
│  SONNET (9 phases)        Standard testing and verification         │
│  ├── Phase 0  Pre-Flight  Environment + config checks               │
│  ├── Phase 2  Execute     Test runner + analysis + coverage         │
│  ├── Phase 2a Runtime     Service health probes                     │
│  ├── Phase 6  Deps        Dependency auditing                       │
│  ├── Phase 12 Verify      Re-run verification                      │
│  ├── Phase 13 Docs        Documentation sync                       │
│  ├── Phase I  Infra       Infrastructure checks                    │
│  ├── Phase V  VM Test     VM isolation testing                      │
│  └── Phase VM Lifecycle   VM startup/shutdown management            │
│                                                                     │
│  HAIKU (2 phases)         Lightweight, fast operations              │
│  ├── Phase S  Snapshot    BTRFS snapshot creation                   │
│  └── Phase C  Restore     Environment cleanup                      │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

**Why tier models?** Cost and latency optimization. A BTRFS snapshot (Phase S) doesn't need opus-level reasoning — haiku runs it in a fraction of the time and cost. But security analysis (Phase 5) benefits from opus's deeper reasoning to understand vulnerability context and remediation strategies.

---

## Tier Execution Model

Phases execute in **9 tiers** with strict dependencies:

```
┌─────────────────────────────────────────────────────────────────────┐
│                         EXECUTION FLOW                              │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  TIER 0   [S] [0]  ───────────────────────────────────  PARALLEL   │
│              │                                                      │
│              ▼ GATE 1: Safety Ready                                │
│  TIER 1   [1] Discovery  ──────────────────────────────  BLOCKING  │
│              │                                                      │
│              ▼ GATE 2: Project Known                               │
│  TIER 2   [2] [2a]  ───────────────────────────────────  PARALLEL  │
│              │                                                      │
│              ▼ GATE 3: Tests Complete                              │
│  TIER 3   [5][6][7][I] ───────────────────────────────  PARALLEL   │
│              │                                                      │
│              ▼ GATE 4: Analysis Complete                           │
│  TIER 4   [10] Fix  ───────────────────────────────────  BLOCKING  │
│              │                                                      │
│              ▼ GATE 5: Fixes Applied                               │
│  TIER 5   [A] [P] [D] [G]  ──────────────────────────  CONDITIONAL│
│              │                                                      │
│              ▼ GATE 6: Validation Complete                         │
│  TIER 6   [12] Verify  ─────────────────────── LOOPS TO TIER 4    │
│              │                                                      │
│              ▼ GATE 7: Verified                                    │
│  TIER 7   [13] Docs  ────────────────────────────────────  ALWAYS  │
│              │                                                      │
│              ▼ GATE 8: Docs Complete                               │
│  TIER 8   [C] Cleanup  ────────────────────────────────── ALWAYS   │
│                                                                     │
│  SPECIAL  [ST] Self-Test  ───────────────────────────────  ISOLATED│
│           [V] VM Testing  ───────────────────────────  CONDITIONAL │
│           [VM] VM Lifecycle  ─────────────────────────────  SUPPORT│
│           Only run explicitly or when conditions are met            │
└─────────────────────────────────────────────────────────────────────┘
```

### Parallel vs Sequential Execution

| Tier | Phases | Mode | Model(s) | Rationale |
|------|--------|------|----------|-----------|
| 0 | S, 0 | Parallel | haiku, sonnet | Independent safety setup |
| 1 | 1 | Sequential | opus | Everything depends on discovery |
| 2 | 2, 2a | Parallel | sonnet, sonnet | Independent test execution |
| 3 | 5,6,7,I | Parallel | mixed | All read-only analysis |
| 4 | 10 | Sequential | opus | Modifies files — must be isolated |
| 5 | A, P, D, G | Conditional | opus | Based on discovery results |
| 6 | 12 | Sequential | sonnet | Final verification |
| 7 | 13 | Sequential | sonnet | Documentation sync |
| 8 | C | Sequential | haiku | Cleanup must be last |

---

## Task Progress Tracking

The dispatcher creates a task for each phase at the start of an audit:

```
TaskCreate("Run Phase S: Snapshot", status="pending")
TaskCreate("Run Phase 0: Pre-Flight", status="pending")
TaskCreate("Run Phase 1: Discovery", status="pending", blockedBy=["S", "0"])
...
```

As phases execute, subagents update their own task status:

```
TaskUpdate(taskId, status="in_progress")   # Phase starting
TaskUpdate(taskId, status="completed")     # Phase done
```

This gives the user real-time visibility:

```
Phase S: Snapshot                 (completed)
Phase 0: Pre-Flight               (completed)
Phase 1: Discovery               (in_progress) — Detecting project type...
Phase 2: Execute Tests            (pending, blocked by Phase 1)
Phase 5: Security                 (pending, blocked by Phase 1)
```

---

## Allowed Tools (15 total)

The dispatcher declares 15 tools available to all subagents:

| Category | Tools | Purpose |
|----------|-------|---------|
| **File I/O** | Bash, Read, Write, Edit, Glob, Grep | Core file operations |
| **Subagents** | Task, TaskOutput, TaskStop | Spawning and managing subagents |
| **Progress** | TaskCreate, TaskUpdate, TaskList | Real-time phase tracking |
| **Interaction** | AskUserQuestion | Interactive mode decisions |
| **Notebooks** | NotebookEdit | Jupyter notebook support |
| **Research** | WebSearch | CVE lookups, error research |

Phase configuration headers tell each subagent which tools are most relevant for its task. For example, Phase 5 (Security) emphasizes `WebSearch` for CVE lookups, while Phase 2 (Execute) emphasizes `Bash` for running test suites.

---

## Security Toolchain (Phase 5)

Phase 5 integrates **7 security tools** in a comprehensive audit:

### Static Analysis (SAST)

| Tool | Languages | Purpose |
|------|-----------|---------|
| bandit | Python | Security vulnerability detection |
| semgrep | Multi | Pattern-based security scanning |
| CodeQL | Multi | Deep semantic analysis |

### Dependency Scanning

| Tool | Ecosystem | Purpose |
|------|-----------|---------|
| pip-audit | Python | CVE detection in packages |
| trivy | Filesystem | Container/filesystem vulnerabilities |
| grype | Filesystem | SBOM-based vulnerability scanning |
| checkov | IaC | Infrastructure-as-Code security |

### Security Audit Sections

1. **GitHub Security** — Dependabot, secret scanning, CodeQL workflows
2. **Local Project** — Secrets detection, SAST, dependency scanning
3. **Installed App** — Permissions, service security, config sync

---

## Special Phases

### Phase ST (Self-Test) — Isolated

Phase ST is a **meta-testing** phase that validates the test-skill framework itself:

- **Never** included in normal `/test` runs
- **Only** runs when explicitly called: `/test --phase=ST`
- **No dependencies** — runs completely standalone

**Validates (10 sections):**
1. All 20 phase files exist and are readable
2. Symlinks point to correct targets
3. Dispatcher contains all phase references and shortcuts
4. All security and core tools are installed
5. All phase files have valid bash blocks
6. **Opus 4.6 integration** — configuration headers present, model tier assignments match dispatcher, all 15 tools declared

### Phase V (VM Testing) — Conditional

Runs applications in fully isolated libvirt/QEMU virtual machines for testing operations that could affect the host system (PAM changes, kernel parameters, systemd units).

### Phase VM-Lifecycle — Support

Manages automatic VM startup and shutdown for Phase V. Tracks which VMs were started by `/test` to ensure cleanup.

### Conditional Phases (P, D, G)

These phases skip automatically based on Discovery (Phase 1) results:

| Phase | Condition to RUN | Condition to SKIP |
|-------|------------------|-------------------|
| P | App installed on system | No installable app or not installed |
| D | Dockerfile + registry package | No Dockerfile or no registry |
| G | GitHub remote + gh authenticated | No remote or gh not authenticated |

---

## Context Efficiency

### Before (Monolithic)

```
Total skill size: ~3,652 lines
Loaded every invocation: 3,652 lines
Context consumed: HIGH
```

### After (Modular)

```
Dispatcher: ~1,000 lines (always loaded)
Per phase: 50-400 lines (on-demand)
Typical audit (10 phases): ~2,500 lines
Context consumed: ~32% reduction for typical audits
Context consumed: ~93% reduction for single-phase runs
```

### Model Cost Optimization

By assigning cheaper models to simpler phases:

```
Without tiering: 20 phases x opus cost = $$$
With tiering:    9 x opus + 9 x sonnet + 2 x haiku = ~45% cost reduction
```

---

## Data Flow

```
┌──────────────────────────────────────────────────────────────────────┐
│                         DATA FLOW                                    │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  /test command                                                       │
│       │                                                              │
│       ▼                                                              │
│  ┌─────────────────┐                                                │
│  │   Dispatcher    │    TaskCreate (per phase)                       │
│  │   (test.md)     │────────────────────────►  Task List             │
│  └────────┬────────┘                          (progress tracking)    │
│           │                                                          │
│           ▼                                                          │
│  ┌─────────────────┐     ┌──────────────────┐                       │
│  │  Parse Args     │────►│ Build Execution  │                       │
│  │  --phase=X      │     │ Plan + Model Map │                       │
│  └─────────────────┘     └────────┬─────────┘                       │
│                                   │                                  │
│           ┌───────────────────────┼───────────────────────┐         │
│           ▼                       ▼                       ▼         │
│  ┌─────────────────┐     ┌─────────────────┐     ┌────────────────┐│
│  │ Task (haiku)    │     │ Task (opus)     │     │ Task (sonnet)  ││
│  │ Phase S Snapshot│     │ Phase 5 Security│     │ Phase 6 Deps   ││
│  │ TaskUpdate ──►  │     │ TaskUpdate ──►  │     │ TaskUpdate ──► ││
│  └────────┬────────┘     └────────┬────────┘     └────────┬───────┘│
│           │                       │                       │         │
│           └───────────────────────┼───────────────────────┘         │
│                                   │                                  │
│                                   ▼                                  │
│                          ┌─────────────────┐                        │
│                          │ Aggregate       │                        │
│                          │ Results         │                        │
│                          └────────┬────────┘                        │
│                                   │                                  │
│                                   ▼                                  │
│                          ┌─────────────────┐                        │
│                          │ Final Summary   │                        │
│                          │ Report          │                        │
│                          └─────────────────┘                        │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

---

## Extension Points

### Adding a New Phase

1. Create `skills/test-phases/phase-X-name.md` with configuration header:
   ```markdown
   > **Model**: `sonnet` | **Tier**: 3 (Analysis) | **Modifies Files**: No
   > **Task Tracking**: Call `TaskUpdate(taskId, status="in_progress")` at start...
   > **Key Tools**: `Bash`, `Read`, `Grep`...
   ```
2. Add to Available Phases table in `commands/test.md`
3. Add to Quick Dependency Reference with tier and model assignment
4. Add to Subagent Model Selection table
5. Add to tier execution algorithm lists (e.g., Tier 3 parallel array in dispatcher)
6. Update Phase ST expected phases list (EXPECTED_MODELS map)
7. Document in this ARCHITECTURE.md
8. Update README.md, SKILL.md, and CHANGELOG.md phase tables

### Adding a New Shortcut

In `commands/test.md`, add to the shortcuts parsing section:
```markdown
- `shortcut` → `--phase=X` (description)
```

---

## v4.0.0 Audit

The v4.0.0 release consolidated the phase inventory from 27 to 21 phases:

### Phases Merged
| Deleted Phase | Merged Into | Rationale |
|---------------|-------------|-----------|
| Phase 3 (Report) | Phase 2 (Execute) | Test result analysis belongs with test execution |
| Phase 4 (Cleanup) | Phase 7 (Quality) | Dead code removal is a quality concern |
| Phase 8 (Coverage) | Phase 2 (Execute) | Coverage measurement belongs with test execution |
| Phase 9 (Debug) | Phase 2 (Execute) | Failure analysis belongs with test execution |
| Phase 11 (Config) | Phase 0 (Preflight) | Configuration audit belongs with environment validation |
| Phase M (Mocking) | Phase 0 (Preflight) | Sandbox setup belongs with preflight checks |

### Other Changes
- **Bloat reduction** — Phase 1 (50 to 23 KB), Phase P (46 to 20 KB), Phase V (54 to 22 KB)
- **Project-agnostic** — All hardcoded project references removed; manifest-driven detection only
- **Orphaned agents** — coverage-reviewer, security-scanner, and test-analyzer agent files integrated into Phases 2 and 5
- **Phase handoff contracts** — Phase 2 output schema and Phase 10 input expectations defined
- **test-legacy.md** — 130 KB monolithic predecessor removed (superseded since v2.0)

---

## Version History

| Version | Key Changes |
|---------|-------------|
| 4.1.0 | Phase H dissolved (21 to 20 phases), cross-component analysis distributed to Phases 5, 6, 7, I |
| 4.0.0 | Phase consolidation (27 to 21), bloat reduction, project-agnostic, agents integrated |
| 3.0.1 | Canonical help block, Phase ST grep fix, argument-hint update |
| 3.0.0 | Phase I/H dispatcher fixes, Tier 3 execution lists corrected, documentation audit |
| 2.0.1 | Opus 4.6 phase config headers, Phase ST Section 6 validation |
| 2.0.0 | Opus 4.6 model pinning, subagent tiering, 16 tools, task tracking |
| 1.0.5 | Phase ST (self-test), consolidated Phase 5 security |
| 1.0.4 | Phase SEC added (now consolidated into Phase 5) |
| 1.0.3 | Multi-segment version badges |
| 1.0.2 | Phase H (holistic), Phase I (infrastructure) |
| 1.0.1 | SKILL.md for Claude.ai, BTRFS detection fix |
| 1.0.0 | Initial public release with 18 phases |

---

## Related Documents

- [INSTALL.md](../INSTALL.md) — Installation guide for third-party users
- [README.md](../README.md) — User documentation
- [CHANGELOG.md](../CHANGELOG.md) — Detailed version history
- [SKILL.md](../SKILL.md) — Claude.ai web upload version
- [commands/test.md](../commands/test.md) — Dispatcher source
