# Claude Code Test Skill

A comprehensive 21-phase autonomous project audit system for Claude Code with full GitHub integration.

![Version](https://img.shields.io/badge/version-1.0.2.1-blue)
[![Security Scan](https://github.com/greogory/test-skill/actions/workflows/security.yml/badge.svg)](https://github.com/greogory/test-skill/actions/workflows/security.yml)
[![GitHub Release](https://img.shields.io/github/v/release/greogory/test-skill)](https://github.com/greogory/test-skill/releases)

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
/test --phase=5          # Security audit only
/test --phase=0-3        # Pre-flight through reporting
/test prodapp            # Validate installed production app
/test docker             # Validate Docker image and registry
/test github             # Audit GitHub repository settings
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
| 5 | Security | CVE scanning, secrets detection, SAST (bandit, shellcheck, trivy, CodeQL) |
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

### Option 1: Symlinks (Recommended for Development)

Symlinks allow edits in this project to be immediately live in Claude Code:

```bash
# Clone the repository
git clone https://github.com/greogory/test-skill.git ~/ClaudeCodeProjects/test-skill

# Remove existing files (if any)
rm -f ~/.claude/commands/test.md
rm -rf ~/.claude/skills/test-phases

# Create symlinks
ln -s ~/ClaudeCodeProjects/test-skill/commands/test.md ~/.claude/commands/test.md
ln -s ~/ClaudeCodeProjects/test-skill/skills/test-phases ~/.claude/skills/test-phases
```

### Option 2: Copy (Standalone Installation)

```bash
# Clone and copy
git clone https://github.com/greogory/test-skill.git /tmp/test-skill
cp /tmp/test-skill/commands/test.md ~/.claude/commands/
cp -r /tmp/test-skill/skills/test-phases ~/.claude/skills/
rm -rf /tmp/test-skill
```

### Option 3: Claude.ai Web Upload

You can upload this skill directly to your Claude.ai account for use in the web interface:

1. Download the `SKILL.md` file from this repository
2. Go to [claude.ai](https://claude.ai) → Settings → Skills
3. Click "Upload skill" and select the `SKILL.md` file
4. The skill will be available in your Claude.ai projects

**Note**: The Claude.ai version provides the skill reference and instructions. For full autonomous execution with all 21 phases, use Claude Code (Options 1 or 2).

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
| npm audit | Node.js CVE scanning | (built-in) |
| cargo audit | Rust CVE scanning | `cargo install cargo-audit` |
| trivy | Container/filesystem scanning | OS package manager |
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
test-skill/
├── commands/
│   ├── test.md              # Main dispatcher (~800 lines)
│   └── test-legacy.md       # Original monolithic version (backup)
├── skills/
│   └── test-phases/
│       ├── phase-S-snapshot.md
│       ├── phase-M-mocking.md
│       ├── phase-0-preflight.md
│       ├── phase-1-discovery.md
│       ├── phase-2-execute.md
│       ├── phase-2a-runtime.md
│       ├── phase-3-report.md
│       ├── phase-4-cleanup.md
│       ├── phase-5-security.md
│       ├── phase-6-dependencies.md
│       ├── phase-7-quality.md
│       ├── phase-8-coverage.md
│       ├── phase-9-debug.md
│       ├── phase-10-fix.md
│       ├── phase-11-config.md
│       ├── phase-12-verify.md
│       ├── phase-13-docs.md
│       ├── phase-A-app-testing.md
│       ├── phase-P-production.md
│       ├── phase-D-docker.md
│       ├── phase-G-github.md
│       └── phase-C-restore.md
├── agents/
│   ├── coverage-reviewer.md
│   ├── security-scanner.md
│   └── test-analyzer.md
├── examples/
│   └── test-skill.local.md
├── .github/
│   └── workflows/
│       └── security.yml     # Daily security scanning
├── plugin.json
├── .gitignore
├── .yamllint.yml
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
/test --phase=5,6
```
Runs only Security (5) and Dependencies (6) phases.

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
4. Run `/test` on the skill itself (meta-testing!)
5. Submit a pull request

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

### v1.0.0 (2026-01-09)
- Added Phase G: GitHub repository security audit
- Added comprehensive tool detection in Phase 1
- Integrated 20+ code quality and security tools
- Added GitHub security workflow with daily scanning
- Full user documentation
- Public repository release

### Initial Development (2025-12-27)
- Created modular architecture from monolithic skill
- 93% context reduction via on-demand phase loading
- 18 phases covering complete audit lifecycle
- BTRFS snapshot safety system
- Multi-language support

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
