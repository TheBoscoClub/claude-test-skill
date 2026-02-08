# Test-Skill Architecture

> Version: 2.0.1

This document describes the architecture of the claude-test-skill plugin for Claude Code, a modular 27-phase autonomous project audit system.

---

## Overview

The test-skill follows a **dispatcher + subagent** architecture that achieves ~93% context reduction compared to a monolithic approach. Instead of loading all 27 phases into context, only the dispatcher (~1,000 lines) is loaded, and individual phases are invoked on-demand via Task tool subagents with per-phase model selection.

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
│  │  [Phase 3]   [Phase 4]   [Phase 6]   [Phase 7]   [Phase 8]  │  │
│  │   haiku       haiku       sonnet      opus        sonnet     │  │
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
│   ├── test.md                 # Main dispatcher (~1,000 lines)
│   └── test-legacy.md          # Original monolithic version (backup)
│
├── skills/
│   └── test-phases/            # 27 phase files
│       │
│       │  ── TIER 0: Safety Gates ──
│       ├── phase-S-snapshot.md       # BTRFS safety snapshot          [haiku]
│       ├── phase-M-mocking.md        # Sandbox environment            [haiku]
│       ├── phase-0-preflight.md      # Environment validation         [sonnet]
│       │
│       │  ── TIER 1: Discovery ──
│       ├── phase-1-discovery.md      # Project detection (GATE)       [opus]
│       │
│       │  ── TIER 2: Testing ──
│       ├── phase-2-execute.md        # Run tests                      [sonnet]
│       ├── phase-2a-runtime.md       # Service health                 [sonnet]
│       │
│       │  ── TIER 3: Analysis (Read-Only) ──
│       ├── phase-3-report.md         # Test results                   [haiku]
│       ├── phase-4-cleanup.md        # Dead code detection            [haiku]
│       ├── phase-5-security.md       # Comprehensive security         [opus]
│       ├── phase-6-dependencies.md   # Package health                 [sonnet]
│       ├── phase-7-quality.md        # Linting, complexity            [opus]
│       ├── phase-8-coverage.md       # Test coverage                  [sonnet]
│       ├── phase-9-debug.md          # Failure analysis               [sonnet]
│       ├── phase-11-config.md        # Configuration audit            [sonnet]
│       ├── phase-H-holistic.md       # Cross-component analysis       [opus]
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
├── agents/                     # Specialized subagents
│   ├── coverage-reviewer.md    # Test coverage analysis
│   ├── security-scanner.md     # Security pattern matching
│   └── test-analyzer.md        # Test result analysis
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
Status: ✅ PASS / ⚠️ ISSUES / ❌ FAIL
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

Specialized subagents for complex analysis:

| Agent | Purpose | Used By |
|-------|---------|---------|
| coverage-reviewer.md | Deep coverage analysis | Phase 8 |
| security-scanner.md | Security pattern matching | Phase 5 |
| test-analyzer.md | Test failure root cause | Phase 9 |

---

## Model Tiering (Opus 4.6)

Each phase is assigned to an optimal model based on task complexity:

```
┌─────────────────────────────────────────────────────────────────────┐
│                      MODEL TIER ASSIGNMENTS                         │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  OPUS (10 phases)         Complex analysis, multi-step reasoning    │
│  ├── Phase 1  Discovery   Architecture detection, framework ID     │
│  ├── Phase 5  Security    8-tool security suite, CVE analysis       │
│  ├── Phase 7  Quality     LSP integration, complexity analysis      │
│  ├── Phase 10 Fix         Multi-file auto-fixing, refactoring       │
│  ├── Phase A  App Test    Sandbox deployment testing                │
│  ├── Phase P  Production  Live system validation                    │
│  ├── Phase D  Docker      Image/registry validation                 │
│  ├── Phase G  GitHub      Repository security audit                 │
│  ├── Phase H  Holistic    Cross-component reasoning                 │
│  └── Phase ST Self-Test   Framework meta-validation                 │
│                                                                     │
│  SONNET (12 phases)       Standard testing and verification         │
│  ├── Phase 0  Pre-Flight  Environment checks                       │
│  ├── Phase 2  Execute     Test runner                               │
│  ├── Phase 2a Runtime     Service health probes                     │
│  ├── Phase 6  Deps        Dependency auditing                       │
│  ├── Phase 8  Coverage    Coverage measurement                      │
│  ├── Phase 9  Debug       Failure root cause                        │
│  ├── Phase 11 Config      Configuration validation                  │
│  ├── Phase 12 Verify      Re-run verification                      │
│  ├── Phase 13 Docs        Documentation sync                       │
│  ├── Phase I  Infra       Infrastructure checks                    │
│  ├── Phase V  VM Test     VM isolation testing                      │
│  └── Phase VM Lifecycle   VM startup/shutdown management            │
│                                                                     │
│  HAIKU (5 phases)         Lightweight, fast operations              │
│  ├── Phase S  Snapshot    BTRFS snapshot creation                   │
│  ├── Phase M  Mocking     Sandbox setup                             │
│  ├── Phase 3  Report      Result aggregation                        │
│  ├── Phase 4  Cleanup     Dead code scan                            │
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
│  TIER 0   [S] [M] [0]  ────────────────────────────────  PARALLEL  │
│              │                                                      │
│              ▼ GATE 1: Safety Ready                                │
│  TIER 1   [1] Discovery  ──────────────────────────────  BLOCKING  │
│              │                                                      │
│              ▼ GATE 2: Project Known                               │
│  TIER 2   [2] [2a]  ───────────────────────────────────  PARALLEL  │
│              │                                                      │
│              ▼ GATE 3: Tests Complete                              │
│  TIER 3   [3][4][5][6][7][8][9][11][H][I]  ────────────  PARALLEL  │
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
│  TIER 8   [C] Cleanup  ──────────────────────────────────  ALWAYS  │
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
| 0 | S, M, 0 | Parallel | haiku, haiku, sonnet | Independent safety setup |
| 1 | 1 | Sequential | opus | Everything depends on discovery |
| 2 | 2, 2a | Parallel | sonnet, sonnet | Independent test execution |
| 3 | 3-9, 11, H, I | Parallel | mixed | All read-only analysis |
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
✅ Phase S: Snapshot                 (completed)
✅ Phase 0: Pre-Flight               (completed)
⏳ Phase 1: Discovery               (in_progress) — Detecting project type...
⬜ Phase 2: Execute Tests            (pending, blocked by Phase 1)
⬜ Phase 5: Security                 (pending, blocked by Phase 1)
```

---

## Allowed Tools (22 total)

The dispatcher declares 22 tools available to all subagents:

| Category | Tools | Purpose |
|----------|-------|---------|
| **File I/O** | Bash, Read, Write, Edit, Glob, Grep | Core file operations |
| **Subagents** | Task, TaskOutput, TaskStop | Spawning and managing subagents |
| **Progress** | TaskCreate, TaskUpdate, TaskList | Real-time phase tracking |
| **Interaction** | AskUserQuestion | Interactive mode decisions |
| **Process** | KillShell | Terminate hung commands |
| **Notebooks** | NotebookEdit | Jupyter notebook support |
| **Research** | WebSearch | CVE lookups, error research |

Phase configuration headers tell each subagent which tools are most relevant for its task. For example, Phase 5 (Security) emphasizes `WebSearch` for CVE lookups, while Phase 2 (Execute) emphasizes `KillShell` for hung test processes.

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

**Validates (6 sections):**
1. All 27 phase files exist and are readable
2. Symlinks point to correct targets
3. Dispatcher contains all phase references and shortcuts
4. All security and core tools are installed
5. All phase files have valid bash blocks
6. **Opus 4.6 integration** — configuration headers present, model tier assignments match dispatcher, all 22 tools declared

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
Without tiering: 27 phases × opus cost = $$$
With tiering:    10 × opus + 12 × sonnet + 5 × haiku = ~40% cost reduction
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
│  │ Phase 3 Report  │     │ Phase 5 Security│     │ Phase 8 Cover. ││
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
5. Update Phase ST expected phases list
6. Document in this ARCHITECTURE.md
7. Update README.md phase count and table

### Adding a New Agent

1. Create `agents/agent-name.md`
2. Document purpose and interface
3. Reference from relevant phase files

### Adding a New Shortcut

In `commands/test.md`, add to the shortcuts parsing section:
```markdown
- `shortcut` → `--phase=X` (description)
```

---

## Version History

| Version | Key Changes |
|---------|-------------|
| 2.0.1 | Opus 4.6 phase config headers, Phase ST Section 6 validation |
| 2.0.0 | Opus 4.6 model pinning, subagent tiering, 22 tools, task tracking |
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
