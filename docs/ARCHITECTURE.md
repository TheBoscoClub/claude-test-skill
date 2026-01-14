# Test-Skill Architecture

> Version: 1.0.5 (aligned with test.md v1.0.1.3)

This document describes the architecture of the test-skill plugin for Claude Code, a modular 25-phase autonomous project audit system.

---

## Overview

The test-skill follows a **dispatcher + subagent** architecture that achieves ~93% context reduction compared to a monolithic approach. Instead of loading all 25 phases into context, only the dispatcher (~840 lines) is loaded, and individual phases are invoked on-demand via Task tool subagents.

```
┌─────────────────────────────────────────────────────────────────────┐
│                      TEST-SKILL ARCHITECTURE                        │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌─────────────┐    spawn     ┌──────────────────────────────────┐ │
│  │ Dispatcher  │──────────────► Task Subagent (Phase 5)          │ │
│  │ test.md     │              │ Reads: phase-5-security.md       │ │
│  │ (~840 lines)│◄─────────────│ Returns: Summary only            │ │
│  └─────────────┘   summary    └──────────────────────────────────┘ │
│        │                                                            │
│        │ spawn (parallel)                                           │
│        ▼                                                            │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  [Phase 3] [Phase 4] [Phase 6] [Phase 7] [Phase 8] [Phase 9] │  │
│  │  Running in parallel - each in its own subagent context       │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Directory Structure

```
test-skill/
├── commands/
│   ├── test.md                 # Main dispatcher (v1.0.1.3, ~840 lines)
│   └── test-legacy.md          # Original monolithic version (backup)
│
├── skills/
│   └── test-phases/            # 25 phase files
│       │
│       │  ── TIER 0: Safety Gates ──
│       ├── phase-S-snapshot.md       # BTRFS safety snapshot
│       ├── phase-M-mocking.md        # Sandbox environment
│       ├── phase-0-preflight.md      # Environment validation
│       │
│       │  ── TIER 1: Discovery ──
│       ├── phase-1-discovery.md      # Project detection
│       │
│       │  ── TIER 2: Testing ──
│       ├── phase-2-execute.md        # Run tests
│       ├── phase-2a-runtime.md       # Service health
│       │
│       │  ── TIER 3: Analysis (Read-Only) ──
│       ├── phase-3-report.md         # Test results
│       ├── phase-4-cleanup.md        # Dead code detection
│       ├── phase-5-security.md       # Comprehensive security (8 tools)
│       ├── phase-6-dependencies.md   # Package health
│       ├── phase-7-quality.md        # Linting, complexity
│       ├── phase-8-coverage.md       # Test coverage
│       ├── phase-9-debug.md          # Failure analysis
│       ├── phase-11-config.md        # Configuration audit
│       ├── phase-H-holistic.md       # Cross-component analysis
│       │
│       │  ── TIER 4: Modifications ──
│       ├── phase-10-fix.md           # Auto-fixing
│       │
│       │  ── TIER 5: Validation (Conditional) ──
│       ├── phase-A-app-testing.md    # Sandbox app testing
│       ├── phase-P-production.md     # Production validation
│       ├── phase-D-docker.md         # Docker/registry validation
│       ├── phase-G-github.md         # GitHub security audit
│       │
│       │  ── TIER 6: Verification ──
│       ├── phase-12-verify.md        # Re-run tests
│       │
│       │  ── TIER 7: Documentation ──
│       ├── phase-13-docs.md          # Doc synchronization
│       │
│       │  ── TIER 8: Cleanup ──
│       ├── phase-C-restore.md        # Environment restore
│       ├── phase-I-infrastructure.md # Infrastructure issues
│       │
│       │  ── SPECIAL: Isolated ──
│       └── phase-ST-self-test.md     # Framework self-validation
│
├── agents/                     # Specialized subagents
│   ├── coverage-reviewer.md    # Test coverage analysis
│   ├── security-scanner.md     # Security scanning
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
│       └── security.yml        # Daily security scanning
│
├── plugin.json                 # Claude Code plugin manifest
├── VERSION                     # Current version (1.0.4)
├── CHANGELOG.md                # Version history
├── README.md                   # User documentation
├── SKILL.md                    # Claude.ai web upload version
└── LICENSE                     # MIT License
```

---

## Component Details

### Dispatcher (commands/test.md)

The dispatcher is the entry point for `/test` commands. It:

1. **Parses arguments** - Handles `--phase=X`, `--interactive`, shortcuts
2. **Builds execution plan** - Respects tier dependencies
3. **Spawns subagents** - Uses Task tool for parallel/sequential execution
4. **Enforces gates** - Blocks at tier boundaries until all phases complete
5. **Generates summary** - Aggregates results from all phases

**Key sections:**
- Quick Reference (~50 lines)
- Available Phases table
- Dependency graph (ASCII art)
- Execution algorithm (pseudocode)
- Special phase handling documentation

### Phase Files (skills/test-phases/)

Each phase file contains:
- **Purpose** - What the phase does
- **Bash blocks** - Executable shell code
- **Output format** - Standardized status reporting
- **Integration notes** - Dependencies, side effects

**Phase file structure:**
```markdown
# Phase X: Name

## Purpose
[Description]

## Section 1: [Category]
```bash
# Executable code
```

## Output Format
Status: ✅ PASS / ⚠️ ISSUES / ❌ FAIL
Issues: [count]
```

### Agents (agents/)

Specialized subagents for complex analysis:

| Agent | Purpose | Used By |
|-------|---------|---------|
| coverage-reviewer.md | Deep coverage analysis | Phase 8 |
| security-scanner.md | Security pattern matching | Phase 5 |
| test-analyzer.md | Test failure root cause | Phase 9 |

---

## Tier Execution Model

Phases execute in **8 tiers** with strict dependencies:

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
│  TIER 3   [3][4][5][6][7][8][9][11][H]  ───────────────  PARALLEL  │
│              │                                                      │
│              ▼ GATE 4: Analysis Complete                           │
│  TIER 4   [10] Fix  ───────────────────────────────────  BLOCKING  │
│              │                                                      │
│              ▼ GATE 5: Fixes Applied                               │
│  TIER 5   [A] [P] [D] [G]  ────────────────────────────  CONDITIONAL│
│              │                                                      │
│              ▼ GATE 6: Validation Complete                         │
│  TIER 6   [12] Verify  ─────────────────────── LOOPS TO TIER 4    │
│              │                                                      │
│              ▼ GATE 7: Verified                                    │
│  TIER 7   [13] Docs  ──────────────────────────────────  ALWAYS    │
│              │                                                      │
│              ▼ GATE 8: Docs Complete                               │
│  TIER 8   [C] Cleanup  ────────────────────────────────  ALWAYS    │
│                                                                     │
│  SPECIAL  [ST] Self-Test  ─────────────────────────────  ISOLATED  │
│           Only runs with explicit --phase=ST                        │
└─────────────────────────────────────────────────────────────────────┘
```

### Parallel vs Sequential Execution

| Tier | Phases | Mode | Rationale |
|------|--------|------|-----------|
| 0 | S, M, 0 | Parallel | Independent safety setup |
| 1 | 1 | Sequential | Everything depends on discovery |
| 2 | 2, 2a | Parallel | Independent test execution |
| 3 | 3-9, 11, H | Parallel | All read-only analysis |
| 4 | 10 | Sequential | Modifies files - must be isolated |
| 5 | A, P, D, G | Conditional | Based on discovery results |
| 6 | 12 | Sequential | Final verification |
| 7 | 13 | Sequential | Documentation sync |
| 8 | C | Sequential | Cleanup must be last |

---

## Security Toolchain (Phase 5)

Phase 5 integrates **8 security tools** in a comprehensive audit:

### Static Analysis (SAST)
| Tool | Languages | Purpose |
|------|-----------|---------|
| bandit | Python | Security vulnerability detection |
| semgrep | Multi | Pattern-based security scanning |
| shellcheck | Shell | Shell script analysis |
| CodeQL | Multi | Deep semantic analysis |

### Dependency Scanning
| Tool | Ecosystem | Purpose |
|------|-----------|---------|
| pip-audit | Python | CVE detection in packages |
| trivy | Filesystem | Container/filesystem vulnerabilities |
| grype | Filesystem | SBOM-based vulnerability scanning |
| checkov | IaC | Infrastructure-as-Code security |

### Security Audit Sections
1. **GitHub Security** - Dependabot, secret scanning, CodeQL workflows
2. **Local Project** - Secrets detection, SAST, dependency scanning
3. **Installed App** - Permissions, service security, config sync

---

## Special Phases

### Phase ST (Self-Test) - Isolated

Phase ST is a **meta-testing** phase that validates the test-skill framework itself:

- **Never** included in normal `/test` runs
- **Only** runs when explicitly called: `/test --phase=ST`
- **No dependencies** - runs completely standalone

**Validates:**
- All 25 phase files exist and are readable
- Symlinks point to correct targets
- Dispatcher contains all phase references
- All 13 required tools are installed

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
Dispatcher: ~840 lines (always loaded)
Per phase: 50-400 lines (on-demand)
Typical audit (10 phases): ~2,000 lines
Context consumed: ~45% of monolithic
```

### Efficiency Calculation
```
Monolithic: 3,652 lines
Modular (typical): 840 + (10 × 150) = 2,340 lines
Reduction: 36% for typical audit
Reduction: 93% for single-phase runs
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
│  │   Dispatcher    │                                                │
│  │   (test.md)     │                                                │
│  └────────┬────────┘                                                │
│           │                                                          │
│           ▼                                                          │
│  ┌─────────────────┐     ┌─────────────────┐                        │
│  │  Parse Args     │────►│ Build Execution │                        │
│  │  --phase=X      │     │ Plan            │                        │
│  └─────────────────┘     └────────┬────────┘                        │
│                                   │                                  │
│           ┌───────────────────────┼───────────────────────┐         │
│           ▼                       ▼                       ▼         │
│  ┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐│
│  │ Task Subagent   │     │ Task Subagent   │     │ Task Subagent   ││
│  │ Phase 3         │     │ Phase 5         │     │ Phase 7         ││
│  │ (Read phase-3)  │     │ (Read phase-5)  │     │ (Read phase-7)  ││
│  └────────┬────────┘     └────────┬────────┘     └────────┬────────┘│
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

1. Create `skills/test-phases/phase-X-name.md`
2. Add to Available Phases table in `commands/test.md`
3. Add to Quick Dependency Reference
4. Update dependency graph
5. Document in this ARCHITECTURE.md
6. Update README.md phase count

### Adding a New Agent

1. Create `agents/agent-name.md`
2. Document purpose and interface
3. Reference from relevant phase files

### Adding a New Shortcut

In `commands/test.md`, add to the shortcuts section:
```markdown
- `shortcut` → `--phase=X` (description)
```

---

## Version History

| Version | Key Changes |
|---------|-------------|
| 1.0.5 | Phase ST (self-test), consolidated Phase 5 security |
| 1.0.4 | Phase SEC added (now consolidated into Phase 5) |
| 1.0.3 | Multi-segment version badges |
| 1.0.2 | Phase H (holistic), Phase I (infrastructure) |
| 1.0.1 | SKILL.md for Claude.ai, BTRFS detection fix |
| 1.0.0 | Initial public release with 18 phases |

---

## Related Documents

- [README.md](../README.md) - User documentation
- [CHANGELOG.md](../CHANGELOG.md) - Detailed version history
- [SKILL.md](../SKILL.md) - Claude.ai web upload version
- [commands/test.md](../commands/test.md) - Dispatcher source
