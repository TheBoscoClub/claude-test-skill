# Claude Test Skill

A comprehensive 18-phase autonomous project audit system for Claude Code.

> **Status**: Local-only development project. See [Future Considerations](#future-considerations-public-release) for thoughts on community release.

## What This Does

The `/test` skill performs a complete autonomous audit of any software project:

| Phase | Name | Description |
|-------|------|-------------|
| S | BTRFS Snapshot | Safety snapshots before modifications |
| M | Safe Mocking | Sandbox environment, mock dangerous commands |
| 0 | Pre-Flight | Validate environment, dependencies, permissions |
| 1 | Discovery | Identify testable components |
| 2 | Execute Tests | Run actual operations, verify outputs |
| 2a | Runtime Health | Detect stuck processes, non-interactive failures |
| 3 | Report Results | Detailed per-component reports |
| 4 | Deprecation | Remove dead code, detect version mismatches |
| 5 | Security | Secrets, CVEs, GitHub Dependabot integration |
| 6 | Dependencies | Outdated, unused, vulnerable packages |
| 7 | Code Quality | Linting, complexity, anti-patterns |
| 8 | Coverage | 85% minimum enforcement (configurable) |
| 9 | Debugging | Autonomous root cause analysis |
| 10 | Auto-Fixing | Apply and verify fixes |
| 11 | Configuration | Validate configs, env vars, secrets |
| 12 | Verification | Re-run all checks, confirm no regressions |
| 13 | Documentation | Update docs after all fixes |
| A | App Testing | Deployable application testing in sandbox |
| C | Cleanup | Restore environment, cleanup temp files |

## Architecture

```
claude-test-skill/
├── commands/
│   ├── test.md              # Lightweight dispatcher (231 lines)
│   └── test-legacy.md       # Original monolithic version (backup)
└── skills/
    └── test-phases/
        ├── phase-0-preflight.md
        ├── phase-5-security.md
        ├── phase-A-app-testing.md
        └── ... (other phases)
```

### Context Efficiency

The original skill was 3,652 lines (130KB) that loaded entirely into context. The modular version:

- **Dispatcher**: 231 lines - always loaded
- **Phases**: Loaded on-demand via Task subagents
- **Result**: ~93% reduction in base context consumption

## Installation (Current - Local)

```bash
# Copy to your Claude Code config
cp commands/test.md ~/.claude/commands/
cp -r skills/test-phases ~/.claude/skills/
```

## Usage

```bash
/test                    # Full audit
/test --phase=5          # Security audit only
/test --phase=0-3        # Pre-flight through reporting
/test help               # Show all options
```

## Configuration

Projects can include `.claude-test.yaml`:

```yaml
coverage:
  minimum: 85
  fail_on_below: true

mocking:
  enabled: true
  sandbox_dir: /tmp/claude-test-sandbox-${PROJECT_NAME}

cleanup:
  after_test: true
  remove_sandbox: true
```

---

## Future Considerations: Public Release

*Captured from discussion on 2025-12-27*

### Why This Could Be Valuable to the Community

| Capability | Community Benefit |
|------------|-------------------|
| 18-phase autonomous audit | Standardized testing methodology |
| Multi-language support (Python, Node, Go, Rust) | Works across ecosystems |
| BTRFS snapshot safety | Safe experimentation |
| Modular phase architecture | Low context consumption, extensible |
| GitHub security integration | Automated vulnerability management |
| 85% coverage enforcement | Quality standards |
| Deployable app testing | End-to-end validation |

### Key Questions to Resolve Before Public Release

#### 1. Distribution Method

- **Claude plugins system?** - Native integration, but still evolving
- **Git clone into `~/.claude/`?** - Simple but manual updates
- **npm/pip package?** - Familiar to devs, handles versioning
- **GitHub releases?** - Download and extract

#### 2. Customization vs. Standardization

- Should phases be overridable per-project?
- How much should `.claude-test.yaml` control?
- Should users be able to add custom phases?
- How to handle language/framework-specific extensions?

#### 3. Scope

- Just the `/test` skill, or a broader "Claude Code Quality Toolkit"?
- Include related skills like `/git-release`?
- Should it bundle recommended MCP servers?
- What about IDE integrations?

#### 4. Maintenance Model

- Who accepts PRs for language-specific improvements?
- How to handle breaking changes to phase structure?
- Versioning strategy (semver?)
- Documentation standards for contributors

#### 5. Technical Requirements for Public Release

- [ ] Remove any system-specific paths (BTRFS assumptions, etc.)
- [ ] Make BTRFS snapshots optional with graceful fallback
- [ ] Test on macOS, Windows WSL, various Linux distros
- [ ] Create installation script that detects environment
- [ ] Add uninstall/upgrade scripts
- [ ] Comprehensive documentation for each phase
- [ ] Example outputs for different project types
- [ ] CI/CD for testing the test skill itself (meta!)

### Potential Project Names

- `claude-test` - Simple, clear
- `claude-code-audit` - Emphasizes comprehensive nature
- `cc-quality` - Short, memorable
- `claude-project-health` - Descriptive

### License Considerations

- MIT - Maximum adoption, minimal friction
- Apache 2.0 - Patent protection
- Consider Anthropic's preferences for community tools

---

## Development Notes

### Adding a New Phase

1. Create `skills/test-phases/phase-X-name.md`
2. Add to phase table in `commands/test.md`
3. Include in dispatcher's phase loading logic
4. Document in this README

### Testing Changes

Since this is a testing tool, validate changes by:
1. Running `/test` on itself (meta-testing)
2. Running on diverse project types (Python, Node, Go, Rust)
3. Testing with and without GitHub remotes
4. Testing on BTRFS and non-BTRFS filesystems

---

## Changelog

### 2025-12-27
- Initial project creation from `~/.claude/` skill files
- Modular architecture (93% context reduction)
- Added Phase A: Deployable Application Testing
- Added GitHub security integration (Dependabot, secret scanning, code scanning)
- Graceful handling for projects without GitHub remotes
