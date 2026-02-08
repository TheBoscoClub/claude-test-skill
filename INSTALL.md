# Installation Guide

Complete installation instructions for the Claude Code Test Skill (`/test`).

## Prerequisites

### Required

- **Claude Code** version **2.1.0 or later** — the skill uses YAML list syntax for `allowed-tools` which is not supported in earlier versions
- **Git** — for cloning the repository

### Recommended

These tools are detected automatically by Phase 1 (Discovery) and used when available. The skill works without them, but functionality will be reduced.

**Code Quality:**

| Tool | Install | Used By |
|------|---------|---------|
| [ruff](https://docs.astral.sh/ruff/) | `pip install ruff` | Phase 7 (lint), Phase 10 (auto-fix) |
| [markdownlint-cli](https://github.com/igorshubovych/markdownlint-cli) | `npm install -g markdownlint-cli` | Phase 7, Phase 13 |
| [codespell](https://github.com/codespell-project/codespell) | `pip install codespell` | Phase 7, Phase 10 |

**Security:**

| Tool | Install | Used By |
|------|---------|---------|
| [bandit](https://bandit.readthedocs.io/) | `pip install bandit` | Phase 5 (Python SAST) |
| [pip-audit](https://pypi.org/project/pip-audit/) | `pip install pip-audit` | Phase 5 (Python CVE) |
| [trivy](https://trivy.dev/) | OS package manager | Phase 5 (filesystem scan) |
| [grype](https://github.com/anchore/grype) | OS package manager | Phase 5 (SBOM scan) |
| [semgrep](https://semgrep.dev/) | `pipx install semgrep` | Phase 5 (multi-language SAST) |
| [checkov](https://www.checkov.io/) | `pipx install checkov` | Phase 5 (IaC security) |

**GitHub Integration:**

| Tool | Install | Used By |
|------|---------|---------|
| [gh](https://cli.github.com/) | OS package manager | Phase G (GitHub audit) |

> **Note:** You don't need ALL of these. The skill gracefully skips tools that aren't installed and reports what it found. Start with `ruff` and `bandit` for the best coverage-to-effort ratio.

---

## Installation Methods

### Method 1: Symlinks (Recommended)

Symlinks keep the skill up to date — just `git pull` to get new versions.

```bash
# 1. Clone the repository
git clone https://github.com/TheBoscoClub/claude-test-skill.git ~/claude-test-skill

# 2. Create the Claude Code directories (if they don't exist)
mkdir -p ~/.claude/commands
mkdir -p ~/.claude/skills

# 3. Remove existing files (if upgrading from a previous install)
rm -f ~/.claude/commands/test.md
rm -rf ~/.claude/skills/test-phases

# 4. Create symlinks
ln -s ~/claude-test-skill/commands/test.md ~/.claude/commands/test.md
ln -s ~/claude-test-skill/skills/test-phases ~/.claude/skills/test-phases
```

**You can clone to any directory you prefer** — just adjust the symlink paths accordingly.

### Method 2: Direct Copy (Standalone)

If you don't want a git clone on disk, copy the files directly:

```bash
# 1. Clone to a temp directory
git clone https://github.com/TheBoscoClub/claude-test-skill.git /tmp/claude-test-skill

# 2. Create the Claude Code directories
mkdir -p ~/.claude/commands
mkdir -p ~/.claude/skills

# 3. Copy files
cp /tmp/claude-test-skill/commands/test.md ~/.claude/commands/
cp -r /tmp/claude-test-skill/skills/test-phases ~/.claude/skills/

# 4. Clean up
rm -rf /tmp/claude-test-skill
```

> **Downside:** Updates require repeating this process. Symlinks (Method 1) are easier to maintain.

### Method 3: Claude.ai Web Upload (Limited)

For the Claude.ai web interface (not Claude Code CLI):

1. Download `SKILL.md` from the [repository](https://github.com/TheBoscoClub/claude-test-skill)
2. Go to [claude.ai](https://claude.ai) → Settings → Skills
3. Upload the `SKILL.md` file

> **Note:** The web version provides the skill reference only. Full autonomous execution with all 27 phases requires Claude Code (Methods 1 or 2).

---

## Verification

After installation, verify everything is working:

```bash
# 1. Check that the command file is accessible
ls -la ~/.claude/commands/test.md

# 2. Check that phase files are accessible
ls ~/.claude/skills/test-phases/ | wc -l
# Expected: 27 files

# 3. Run the self-test (validates the framework)
# In Claude Code:
/test --phase=ST
```

Phase ST checks:
- All 27 phase files exist and are readable
- Symlinks point to correct targets
- Dispatcher references all phases
- Security tools are installed
- Opus 4.6 configuration headers are present
- Model tier assignments are correct

---

## Updating

### If installed via symlinks (Method 1):

```bash
cd ~/claude-test-skill
git pull
```

That's it — symlinks automatically pick up the new files.

### If installed via copy (Method 2):

```bash
# Re-clone and overwrite
git clone https://github.com/TheBoscoClub/claude-test-skill.git /tmp/claude-test-skill
cp /tmp/claude-test-skill/commands/test.md ~/.claude/commands/
rm -rf ~/.claude/skills/test-phases
cp -r /tmp/claude-test-skill/skills/test-phases ~/.claude/skills/
rm -rf /tmp/claude-test-skill
```

---

## Uninstalling

```bash
# Remove the command and skill files
rm -f ~/.claude/commands/test.md
rm -rf ~/.claude/skills/test-phases

# Remove the cloned repository (if using Method 1)
rm -rf ~/claude-test-skill
```

---

## Configuration (Optional)

Projects can include a `.claude-test.yaml` file for per-project customization:

```yaml
# Test coverage requirements
coverage:
  minimum: 85
  fail_on_below: true

# Sandbox configuration
mocking:
  enabled: true

# Tool-specific settings
tools:
  ruff:
    extend-select: ["I", "UP", "YTT", "ASYNC"]
```

---

## File Structure After Installation

```
~/.claude/
├── commands/
│   └── test.md              → ~/claude-test-skill/commands/test.md (symlink)
└── skills/
    └── test-phases/          → ~/claude-test-skill/skills/test-phases/ (symlink)
        ├── phase-0-preflight.md
        ├── phase-1-discovery.md
        ├── phase-2-execute.md
        ├── phase-2a-runtime.md
        ├── phase-3-report.md
        ├── phase-4-cleanup.md
        ├── phase-5-security.md
        ├── phase-6-dependencies.md
        ├── phase-7-quality.md
        ├── phase-8-coverage.md
        ├── phase-9-debug.md
        ├── phase-10-fix.md
        ├── phase-11-config.md
        ├── phase-12-verify.md
        ├── phase-13-docs.md
        ├── phase-A-app-testing.md
        ├── phase-C-restore.md
        ├── phase-D-docker.md
        ├── phase-G-github.md
        ├── phase-H-holistic.md
        ├── phase-I-infrastructure.md
        ├── phase-M-mocking.md
        ├── phase-P-production.md
        ├── phase-S-snapshot.md
        ├── phase-ST-self-test.md
        ├── phase-V-vm-testing.md
        └── phase-VM-lifecycle.md
```

---

## Troubleshooting

### "/test" doesn't work

- Verify `~/.claude/commands/test.md` exists and is readable
- If using symlinks, verify the symlink target exists: `readlink -f ~/.claude/commands/test.md`
- Ensure you're running Claude Code 2.1.0 or later

### "Phase file not found"

- Verify `~/.claude/skills/test-phases/` directory exists and contains `.md` files
- If using symlinks, verify: `ls -la ~/.claude/skills/test-phases/`

### "Phase G skipped: gh not authenticated"

- Install `gh`: see [cli.github.com](https://cli.github.com/)
- Authenticate: `gh auth login`

### "No security tools detected"

- This is a warning, not an error — the skill continues without them
- Install the recommended tools above for better coverage

### "BTRFS snapshot failed"

- Phase S (Snapshot) requires a BTRFS filesystem and sudo access
- On non-BTRFS systems, Phase S is skipped automatically — this is safe

### Phase ST reports failures

- Run `/test --phase=ST` to see detailed output
- Most common: missing phase files (re-run installation) or missing symlinks

---

## More Information

- [README.md](README.md) — Feature overview and usage examples
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — System architecture and design
- [CHANGELOG.md](CHANGELOG.md) — Version history
- [Repository](https://github.com/TheBoscoClub/claude-test-skill) — Source code
