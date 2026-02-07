# Claude Code Test Skill

A comprehensive 27-phase autonomous project audit system for Claude Code with full GitHub integration.

[![Security Scan](https://github.com/TheBoscoClub/claude-test-skill/actions/workflows/security.yml/badge.svg)](https://github.com/TheBoscoClub/claude-test-skill/actions/workflows/security.yml)
[![GitHub Release](https://img.shields.io/github/v/release/TheBoscoClub/claude-test-skill)](https://github.com/TheBoscoClub/claude-test-skill/releases)

### Version History

| Version | Status | Release |
|---------|--------|---------|
| ![2](https://img.shields.io/badge/2-brightgreen)![0](https://img.shields.io/badge/0-darkgreen)![1](https://img.shields.io/badge/1-green) | Latest patch | [v2.0.1](https://github.com/TheBoscoClub/claude-test-skill/releases/tag/v2.0.1) |
| ![2](https://img.shields.io/badge/2-brightred)![0](https://img.shields.io/badge/0-darkred)![0](https://img.shields.io/badge/0-red) | Prior major | [v2.0.0](https://github.com/TheBoscoClub/claude-test-skill/releases/tag/v2.0.0) |
| ![1](https://img.shields.io/badge/1-brightred)![0](https://img.shields.io/badge/0-darkred)![5](https://img.shields.io/badge/5-red) | Prior patch | [v1.0.5](https://github.com/TheBoscoClub/claude-test-skill/releases/tag/v1.0.5) |
| ![1](https://img.shields.io/badge/1-brightred)![0](https://img.shields.io/badge/0-darkred)![4](https://img.shields.io/badge/4-red) | Prior patch | [v1.0.4](https://github.com/TheBoscoClub/claude-test-skill/releases/tag/v1.0.4) |

<details>
<summary>Badge Color Convention</summary>

Each version segment gets its own badge. The number of badges indicates version depth:

| Level | Current | Prior | Example |
|-------|---------|-------|---------|
| Major (`W.0.0`) | ![W](https://img.shields.io/badge/W-brightgreen) | ![W](https://img.shields.io/badge/W-brightred) | v1.0.0, v2.0.0 |
| Minor (`W.X.0`) | ![W](https://img.shields.io/badge/W-brightgreen)![X](https://img.shields.io/badge/X-darkgreen) | ![W](https://img.shields.io/badge/W-brightred)![X](https://img.shields.io/badge/X-darkred) | v1.1.0, v1.2.0 |
| Patch (`W.X.Y`) | ![W](https://img.shields.io/badge/W-brightgreen)![X](https://img.shields.io/badge/X-darkgreen)![Y](https://img.shields.io/badge/Y-green) | ![W](https://img.shields.io/badge/W-brightred)![X](https://img.shields.io/badge/X-darkred)![Y](https://img.shields.io/badge/Y-red) | v1.0.3, v1.2.1 |
| Tweak (`W.X.Y.Z`) | ![W](https://img.shields.io/badge/W-brightgreen)![X](https://img.shields.io/badge/X-darkgreen)![Y](https://img.shields.io/badge/Y-green)![Z](https://img.shields.io/badge/Z-yellow) | ![W](https://img.shields.io/badge/W-brightred)![X](https://img.shields.io/badge/X-darkred)![Y](https://img.shields.io/badge/Y-red)![Z](https://img.shields.io/badge/Z-orange) | v1.0.3.1 |

**Color Scheme:**
- **Current**: brightgreen → darkgreen → green → yellow
- **Prior**: brightred → darkred → red → orange

</details>

## Overview

The `/test` skill performs a complete autonomous audit of any software project - running tests, scanning for vulnerabilities, checking code quality, validating production deployments, and auditing GitHub repository security settings. It fixes ALL issues automatically and loops until the codebase is clean.

**Key Features:**
- 🔄 **Autonomous**: Fixes all issues without prompting (no "manual items" lists)
- 🧩 **Modular**: 93% context reduction via on-demand phase loading
- 🔒 **Security-First**: Integrated CVE scanning, secret detection, GitHub security auditing
- 🌍 **Multi-Language**: Python, Node.js, Go, Rust, Shell, Docker, YAML
- 📸 **BTRFS Snapshots**: Safe rollback points before modifications
- 🐙 **GitHub Integration**: Full repository security audit and auto-remediation

---

## Quick Start

```bash
/test                    # Full audit (autonomous - fixes everything)
/test security           # Comprehensive security audit (Phase 5)
/test --phase=0-3        # Pre-flight through reporting
/test prodapp            # Validate installed production app
/test docker             # Validate Docker image and registry
/test github             # Audit GitHub repository settings
/test holistic           # Full-stack cross-component analysis
/test --phase=ST         # Validate test-skill framework (meta-testing)
/test --interactive      # Enable prompts for decisions
/test help               # Show all options
```

---

## Phase Overview

| Phase | Name | Description |
|-------|------|-------------|
| **Safety &amp; Setup** |||
| S | Snapshot | BTRFS safety snapshot before modifications |
| M | Mocking | Sandbox environment for safe testing |
| 0 | Pre-Flight | Environment validation, dependencies, permissions |
| 1 | Discovery | Detect project type, test frameworks, tools, GitHub remote |
| **Testing** |||
| 2 | Execute | Run project tests (pytest, npm test, go test, cargo test) |
| 2a | Runtime | Service health checks, stuck process detection |
| 3 | Report | Detailed test results and failure analysis |
| **Analysis** |||
| 4 | Cleanup | Deprecation detection, dead code removal |
| 5 | Security | Comprehensive security (8 tools: bandit, semgrep, shellcheck, CodeQL, pip-audit, trivy, grype, checkov) |
| 6 | Dependencies | Package health, outdated/unused/vulnerable packages |
| 7 | Quality | Linting, complexity analysis (ruff, pylint, eslint, hadolint, yamllint) |
| 8 | Coverage | Test coverage enforcement (85% default) |
| 9 | Debug | Autonomous failure root cause analysis |
| **Remediation** |||
| 10 | Fix | Auto-fix issues (ruff --fix, black, isort, shfmt, codespell) |
| 11 | Config | Configuration audit, env vars, secrets management |
| **Validation** |||
| A | App Test | Deployable application testing in sandbox |
| P | Production | Validate live installed application |
| D | Docker | Validate Docker image and registry package |
| G | GitHub | Audit GitHub repo security (Dependabot, CodeQL, branch protection) |
| 12 | Verify | Re-run tests, confirm no regressions |
| **Finalization** |||
| 13 | Docs | Update documentation to match codebase |
| C | Restore | Cleanup temp files, restore environment |
| **Special** |||
| ST | Self-Test | Validate test-skill framework (explicit only: `--phase=ST`) |

---

## Execution Modes

| Mode | Flag | Behavior |
|------|------|----------|
| **Autonomous** (default) | (none) | Fixes ALL issues, no prompts, loops until clean |
| **Interactive** | `--interactive` | May prompt for decisions, single pass |

### Autonomous Mode (Default)
- Fixes every issue regardless of priority/severity
- No user prompts except for safety/architecture/external blocks
- Loops between Fix (Phase 10) and Verify (Phase 12) until all tests pass
- Documentation automatically synchronized

### Interactive Mode
- May prompt for decisions (e.g., Phase P/D conditional execution)
- May output "manual required" or "recommendation" lists
- Single pass - does not loop until clean
- Useful for exploration or when human judgment needed

---

## Installation

> **Full installation guide:** See [INSTALL.md](INSTALL.md) for detailed instructions including prerequisites, verification, updating, and troubleshooting.

### Quick Install (Symlinks)

```bash
git clone https://github.com/TheBoscoClub/claude-test-skill.git ~/claude-test-skill
mkdir -p ~/.claude/commands ~/.claude/skills
ln -s ~/claude-test-skill/commands/test.md ~/.claude/commands/test.md
ln -s ~/claude-test-skill/skills/test-phases ~/.claude/skills/test-phases
```

### Quick Install (Copy)

```bash
git clone https://github.com/TheBoscoClub/claude-test-skill.git /tmp/claude-test-skill
mkdir -p ~/.claude/commands ~/.claude/skills
cp /tmp/claude-test-skill/commands/test.md ~/.claude/commands/
cp -r /tmp/claude-test-skill/skills/test-phases ~/.claude/skills/
rm -rf /tmp/claude-test-skill
```

### Verify Installation

```bash
# In Claude Code:
/test --phase=ST
```

**Requires:** Claude Code 2.1.0+ (for YAML `allowed-tools` syntax). See [INSTALL.md](INSTALL.md) for full prerequisites.

---

## Tool Detection

Phase 1 (Discovery) automatically detects which tools are installed on your system. The skill uses the tools it finds:

### Code Quality Tools

| Tool | Languages | Purpose | Install |
|------|-----------|---------|---------|
| ruff | Python | Fast linter + formatter | `pip install ruff` |
| pylint | Python | Deep static analysis | `pip install pylint` |
| mypy | Python | Type checking | `pip install mypy` |
| black | Python | Code formatting | `pip install black` |
| isort | Python | Import sorting | `pip install isort` |
| eslint | JS/TS | Linting | `npm install -g eslint` |
| prettier | JS/TS/JSON/MD | Formatting | `npm install -g prettier` |
| hadolint | Docker | Dockerfile linting | OS package manager |
| yamllint | YAML | YAML validation | `pip install yamllint` |
| shellcheck | Shell | Shell script analysis | OS package manager |
| shfmt | Shell | Shell formatting | OS package manager |
| markdownlint-cli | Markdown | Markdown linting | `npm install -g markdownlint-cli` |
| codespell | All | Spelling errors | `pip install codespell` |

### Security Tools

| Tool | Purpose | Install |
|------|---------|---------|
| pip-audit | Python CVE scanning | `pip install pip-audit` |
| bandit | Python security analysis | `pip install bandit` |
| semgrep | Multi-language SAST | `pipx install semgrep` |
| shellcheck | Shell script analysis | OS package manager |
| npm audit | Node.js CVE scanning | (built-in) |
| cargo audit | Rust CVE scanning | `cargo install cargo-audit` |
| trivy | Container/filesystem scanning | OS package manager |
| grype | SBOM vulnerability scanning | OS package manager (AUR: grype-bin) |
| checkov | Infrastructure-as-Code security | `pipx install checkov` |
| CodeQL | Advanced static analysis | GitHub Actions / Local install |

### GitHub Tools

| Tool | Purpose | Install |
|------|---------|---------|
| gh | GitHub CLI for repo auditing | OS package manager |

---

## Configuration

Projects can include `.claude-test.yaml` for customization:

```yaml
# Test coverage requirements
coverage:
  minimum: 85
  fail_on_below: true

# Sandbox configuration
mocking:
  enabled: true
  sandbox_dir: /tmp/claude-test-sandbox-${PROJECT_NAME}

# Cleanup behavior
cleanup:
  after_test: true
  remove_sandbox: true

# Tool-specific settings
tools:
  ruff:
    extend-select: ["I", "UP", "YTT", "ASYNC"]
  pylint:
    disable: ["C0114", "C0115", "C0116"]
```

---

## Phase Dependencies

Phases execute in tiers with strict dependencies:

```
TIER 0: Safety [S, M, 0] ──────────────── Can run in parallel
           │
           ▼
TIER 1: Discovery [1] ──────────────────── GATE: Project Known
           │
           ▼
TIER 2: Testing [2, 2a] ────────────────── Can run in parallel
           │
           ▼
TIER 3: Analysis [3-9, 11] ─────────────── Can run in parallel (read-only)
           │
           ▼
TIER 4: Fix [10] ───────────────────────── MODIFIES FILES (sequential)
           │
           ▼
TIER 5: Validation [P, D, G] ───────────── CONDITIONAL (sequential)
           │
           ▼
TIER 6: Verify [12] ────────────────────── Re-run tests
           │
          ⟲ Loop to Fix if issues found
           │
           ▼
TIER 7: Docs [13] ──────────────────────── ALWAYS runs
           │
           ▼
TIER 8: Cleanup [C] ────────────────────── ALWAYS last
```

### Conditional Phases

**Phase P (Production)** - Skipped if:
- No installable app detected
- App not installed on this system

**Phase D (Docker)** - Skipped if:
- No Dockerfile in project
- No registry package found

**Phase G (GitHub)** - Skipped if:
- No GitHub remote configured
- `gh` CLI not authenticated

---

## GitHub Integration

Phase G performs a comprehensive GitHub repository audit:

### Security Features Audited
- ✅ Dependabot vulnerability alerts
- ✅ Dependabot security updates
- ✅ Secret scanning (if available)
- ✅ Code scanning (CodeQL/ShellCheck workflows)
- ✅ Branch protection rules

### Automatic Remediation
- Enables Dependabot alerts if missing
- Enables automated security updates if missing
- Reports open security alerts for manual review

### Requirements
- `gh` CLI installed and authenticated (`gh auth login`)
- Push access to the repository (for enabling security features)

---

## Architecture

```
claude-test-skill/
├── commands/
│   ├── test.md              # Main dispatcher (~1,000 lines)
│   └── test-legacy.md       # Original monolithic version (backup)
├── skills/
│   └── test-phases/         # 27 phase files (each with Opus 4.6 config header)
│       ├── phase-S-snapshot.md       # [haiku]
│       ├── phase-M-mocking.md        # [haiku]
│       ├── phase-0-preflight.md      # [sonnet]
│       ├── phase-1-discovery.md      # [opus]
│       ├── phase-2-execute.md        # [sonnet]
│       ├── phase-2a-runtime.md       # [sonnet]
│       ├── phase-3-report.md         # [haiku]
│       ├── phase-4-cleanup.md        # [haiku]
│       ├── phase-5-security.md       # [opus]
│       ├── phase-6-dependencies.md   # [sonnet]
│       ├── phase-7-quality.md        # [opus]
│       ├── phase-8-coverage.md       # [sonnet]
│       ├── phase-9-debug.md          # [sonnet]
│       ├── phase-10-fix.md           # [opus]
│       ├── phase-11-config.md        # [sonnet]
│       ├── phase-12-verify.md        # [sonnet]
│       ├── phase-13-docs.md          # [sonnet]
│       ├── phase-A-app-testing.md    # [opus]
│       ├── phase-P-production.md     # [opus]
│       ├── phase-D-docker.md         # [opus]
│       ├── phase-G-github.md         # [opus]
│       ├── phase-H-holistic.md       # [opus]
│       ├── phase-I-infrastructure.md # [sonnet]
│       ├── phase-C-restore.md        # [haiku]
│       ├── phase-ST-self-test.md     # [opus]
│       ├── phase-V-vm-testing.md     # [sonnet]
│       └── phase-VM-lifecycle.md     # [sonnet]
├── agents/
│   ├── coverage-reviewer.md
│   ├── security-scanner.md
│   └── test-analyzer.md
├── docs/
│   └── ARCHITECTURE.md      # System architecture
├── .github/
│   └── workflows/
│       └── security.yml     # Daily security scanning
├── plugin.json
├── INSTALL.md               # Third-party installation guide
├── SKILL.md                 # Claude.ai web upload version
└── README.md
```

### Context Efficiency

The modular architecture significantly reduces context consumption:

| Component | Lines | When Loaded |
|-----------|-------|-------------|
| Dispatcher | ~800 | Always |
| Each Phase | 50-300 | On-demand via subagent |
| **Typical audit** | ~1,500 | vs 3,652 monolithic |

**Result**: ~60% reduction in context for typical audits

---

## Examples

### Full Audit
```bash
/test
```
Runs all phases autonomously, fixes all issues, loops until clean.

### Security-Only Audit
```bash
/test security
# or: /test --phase=5
```
Runs comprehensive security audit with 8 tools (GitHub + local + installed app).

### Pre-Commit Check
```bash
/test --phase=0-3,7
```
Quick validation: Pre-flight, Discovery, Execute, Report, and Quality.

### Production Validation
```bash
/test prodapp
```
Validates the installed production application against `install-manifest.json`.

### GitHub Repository Audit
```bash
/test github
```
Audits GitHub security settings and enables missing protections.

### Framework Self-Test (Meta-Testing)
```bash
/test --phase=ST
```
Validates the test-skill framework itself (phase files, symlinks, tools).
**Note:** Phase ST is never included in normal `/test` runs - explicit only.

---

## Adding Custom Phases

1. Create `~/.claude/skills/test-phases/phase-X-name.md`
2. Add phase to the Available Phases table in `commands/test.md`
3. Define tier placement in dependency graph
4. Document in README

### Phase File Template

```markdown
# Phase X: Your Phase Name

## Purpose
Brief description of what this phase does.

## Steps

### Step 1: First Action
[Instructions for Claude]

### Step 2: Second Action
[Instructions for Claude]

## Output Format

Status: ✅ PASS / ⚠️ ISSUES / ❌ FAIL
Issues Found: [count]
Key Findings:
- [finding 1]
- [finding 2]
```

---

## Troubleshooting

### "Phase G skipped: gh not authenticated"
Run `gh auth login` to authenticate with GitHub.

### "No security tools detected"
Install the recommended tools for your language. Phase 1 will detect them automatically.

### "BTRFS snapshot failed"
Ensure you have sudo access or run on a BTRFS filesystem. Snapshots are optional - the skill continues without them on other filesystems.

### "Phase P skipped: App not installed"
Phase P validates production installations. If the app isn't installed on this system, Phase P correctly skips.

---

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run `/test --phase=ST` to validate framework integrity
5. Run `/test` on the skill itself for full audit
6. Submit a pull request

### Code Quality Standards
- All shell scripts must pass ShellCheck
- All markdown must pass markdownlint
- All YAML must pass yamllint
- No hardcoded secrets or credentials

---

## License

MIT License - See LICENSE file for details.

---

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for detailed version history.

### Recent Releases

- **v2.0.1** - Opus 4.6 phase configuration headers, Phase ST integration validation
- **v2.0.0** - Opus 4.6 model pinning, subagent tiering, 22 tools, task tracking (BREAKING)
- **v1.0.5** - Consolidated security phases, Phase ST (self-test), 8-tool security suite
- **v1.0.4** - Phase SEC (standalone security), Phase P enhancements
- **v1.0.2** - Phase H (holistic), Phase I (infrastructure)

---

## Addendum: On Human Multitasking and Evolution's LTS Release

*Added after a user accidentally typed `/git-release tweak` instead of `/git-release patch` because someone in their Teams meeting said "tweak the memory" at the exact moment they were typing.*

### The Technical Analogy

Human cognition can be modeled as an I/O system where each modality (language, vision, motor) can handle multiple **read-only input streams** concurrently, but has only a **single process table for output**. When a read-only process suddenly needs to write, other read processes can insert data into the write process's I/O register—resulting in cross-talk.

```
┌─────────────────────────────────────────────────────────────┐
│ HUMAN COGNITION: I/O MODEL                                  │
├─────────────────────────────────────────────────────────────┤
│  LANGUAGE MODALITY                                          │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  INPUT STREAMS (read-only, concurrent OK)           │   │
│  │  ├─ Teams meeting audio ──────► buffer[0]           │   │
│  │  ├─ Internal monologue ───────► buffer[1]           │   │
│  │  └─ Reading (if any) ─────────► buffer[2]           │   │
│  └─────────────────────────────────────────────────────┘   │
│                          │                                  │
│                          ▼                                  │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  OUTPUT REGISTER (single writer, NO MUTEX)          │   │
│  │  ┌──────────────────────────────────────────────┐   │   │
│  │  │  "tweak" ← RACE CONDITION: buffer[0] won     │   │   │
│  │  └──────────────────────────────────────────────┘   │   │
│  └─────────────────────────────────────────────────────┘   │
│                          │                                  │
│                          ▼                                  │
│                     Motor Cortex (keystrokes)               │
└─────────────────────────────────────────────────────────────┘
```

### Why Evolution Didn't Fix This

Evolution optimized for **speed over correctness**. The panic-response code demonstrates this clearly:

```c
if (predator_detected) {
    // DO NOT WAIT for environment_scan() to complete
    // Tree collision is survivable. Tiger is not.
    motor_cortex.execute(FLEE);  // non-blocking, fire-and-forget
}
```

**Survivorship bias in action:** Ancestors who stopped to carefully survey escape routes got eaten. Those who face-planted into trees *but survived* passed on their genes.

### Evolution v2.0.0-LTS

```
EVOLUTION v2.0.0-LTS (Homo sapiens)
├── Release: ~300,000 years ago
├── Support Status: ACTIVE (no EOL planned)
├── Known Issues:
│   ├── #4,271: Panic response overwrites output buffer
│   ├── #12,847: Sugar addiction (deprecated food scarcity)
│   └── #89,421: Cannot distinguish real tigers from work emails
├── Patch Frequency: ~1 per 10,000 generations
└── Upgrade Path: None available. You're stuck with this kernel.
```

The original devs are unreachable and left no documentation.

### Regional Considerations

```c
// Region-specific threat assessment
if (location.continent == "Asia" && habitat.includes("forest")) {
    TIGER_THREAT = LITERAL;      // Bengal, Siberian, Indochinese, etc.
    TREE_COLLISION_PRIORITY = ACCEPTABLE_RISK;
} else {
    TIGER_THREAT = METAPHORICAL; // deadlines, managers, merge conflicts
    TREE_COLLISION_PRIORITY = EMBARRASSING;
}
```

In rural India, Nepal, or the Russian Far East, that legacy panic-response code is still very much production-ready. Evolution's LTS release still getting real-world use cases.

---

*This addendum serves as a reminder that humans have eventual consistency at best—and sometimes experience dirty reads.*
