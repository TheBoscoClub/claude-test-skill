---
name: project-audit
description: Autonomous 21-phase project audit with testing, security scanning, code quality, GitHub auditing, and auto-fixing
---

# /test - Modular Project Audit

A comprehensive 21-phase autonomous project audit system with full GitHub integration.

## Quick Reference

```
/test                    # Full audit (autonomous - fixes everything)
/test prodapp            # Validate installed production app (Phase P)
/test docker             # Validate Docker image and registry (Phase D)
/test github             # Audit GitHub repository settings (Phase G)
/test --phase=A          # Run single phase
/test --phase=0-3        # Run phase range
/test --phase=5,6        # Security + Dependencies only
/test --interactive      # Enable interactive mode
/test help               # Show help
```

## Key Features

- **Autonomous**: Fixes ALL issues without prompting, loops until clean
- **21 Phases**: Complete coverage from safety snapshots to documentation sync
- **Multi-Language**: Python, Node.js, Go, Rust, Shell, Docker, YAML
- **20+ Tools**: ruff, pylint, bandit, shellcheck, trivy, CodeQL, and more
- **GitHub Integration**: Dependabot, CodeQL workflows, branch protection audit
- **Context Efficient**: 93% reduction via on-demand phase loading

## Available Phases

| Phase | Name | Description |
|-------|------|-------------|
| S | Snapshot | BTRFS safety snapshot |
| M | Mocking | Sandbox environment |
| 0 | Pre-Flight | Environment validation |
| 1 | Discovery | Detect project type, tools, GitHub |
| 2 | Execute | Run tests |
| 2a | Runtime | Service health checks |
| 3 | Report | Test results |
| 4 | Cleanup | Dead code removal |
| 5 | Security | CVE scanning, SAST |
| 6 | Dependencies | Package health |
| 7 | Quality | Linting, complexity |
| 8 | Coverage | 85% enforcement |
| 9 | Debug | Failure analysis |
| 10 | Fix | Auto-fix issues |
| 11 | Config | Configuration audit |
| A | App Test | Sandbox app testing |
| P | Production | Live app validation |
| D | Docker | Image validation |
| G | GitHub | Repo security audit |
| 12 | Verify | Re-run tests |
| 13 | Docs | Documentation sync |
| C | Restore | Cleanup |

## Autonomous Behavior

The skill operates **entirely non-interactively**:

1. **Fix ALL Issues** - No "manual required" lists
2. **Loop Until Clean** - Phase 10 and 12 repeat until all tests pass
3. **Documentation Sync** - Docs always match codebase state

## Tool Detection

Phase 1 automatically detects installed tools:

**Code Quality**: ruff, pylint, mypy, black, isort, eslint, prettier, hadolint, yamllint, shellcheck, shfmt, markdownlint, codespell

**Security**: pip-audit, bandit, npm audit, cargo audit, trivy, CodeQL

**GitHub**: gh CLI for repository auditing

## Installation

```bash
# Clone and symlink
git clone https://github.com/greogory/test-skill.git ~/test-skill
ln -s ~/test-skill/commands/test.md ~/.claude/commands/test.md
ln -s ~/test-skill/skills/test-phases ~/.claude/skills/test-phases
```

## More Information

- **Repository**: https://github.com/greogory/test-skill
- **Full Documentation**: See README.md
