# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

### Changed

### Fixed

## [2.0.0] - 2026-02-06

### Added
- **Opus 4.6 model pinning**: Frontmatter `model: opus` ensures test skill always runs on Opus
- **Subagent model tiering**: Per-phase model selection (opus/sonnet/haiku) based on complexity:
  - Opus: Phases 1, 5, 7, 10, A, P, D, G, H, ST (complex analysis, security, architecture)
  - Sonnet: Phases 0, 2, 2a, 6, 8, 9, 11, 12, 13, V (standard testing, coverage, linting)
  - Haiku: Phases S, M, 3, 4, C (snapshots, file checks, simple validation)
- **Task progress tracking**: Integration with TaskCreate/TaskUpdate/TaskList for real-time phase tracking with dependency chains
- **9 new allowed tools**: TaskOutput, TaskStop, TaskCreate, TaskUpdate, TaskList, AskUserQuestion, KillShell, NotebookEdit, WebSearch
- **Background phase execution**: `run_in_background: true` guidance for independent phases

### Changed
- **BREAKING**: `allowed-tools` converted from CSV to YAML list syntax (requires Claude Code 2.1+)
- **BREAKING**: Tool count expanded from 13 to 22 tools — older Claude Code versions may reject unknown tools
- All GitHub URLs updated from `greogory` to `TheBoscoClub` organization
- CodeFactor badge added to README
- GitHub Actions pinned to commit SHAs for supply chain security

## [1.0.5] - 2026-01-14

### Added
- **Phase ST (Self-Test)**: Meta-testing phase that validates the test-skill framework itself
  - Checks all 25 phase files exist and are readable
  - Validates symlink configuration
  - Verifies dispatcher references all phases
  - Confirms all 13 required tools are installed
  - Only runs with explicit `--phase=ST` (never in normal runs)
- **docs/ARCHITECTURE.md**: Comprehensive architecture documentation
- **Security tools**: Added grype (SBOM scanning), semgrep (multi-language SAST), checkov (IaC security)

### Changed
- **Phase 5 (Security)**: Consolidated Phase SEC into Phase 5 for comprehensive 8-tool security suite
  - SAST: bandit, semgrep, shellcheck, CodeQL
  - Dependency: pip-audit, trivy, grype, checkov
  - Sections: GitHub security, local project, installed app
- **Dispatcher**: Added `/test security` shortcut and `--phase=SEC` alias (both map to Phase 5)
- Updated README.md to reflect 25-phase system
- Updated all documentation to remove Phase SEC references

### Removed
- **phase-SEC-security.md**: Consolidated into phase-5-security.md (no functionality lost)

## [1.0.4] - 2026-01-14

### Added
- **Phase SEC (Security)**: New standalone comprehensive security testing phase covering:
  - GitHub security features audit (Dependabot, secret scanning, CodeQL)
  - Local project security (SAST with bandit/shellcheck, dependency scanning, secret detection)
  - Installed app security (permissions, config sync, service security, database)
  - Can be invoked standalone with `/test --phase SEC`
- **Phase P Step 2b**: Validate wrapper script targets (prevents silent `exec` failures at runtime)
- **Phase P Step 5b**: Validate production/development separation (critical isolation check)

### Changed
- Version badge color scheme: darkgreen for minor, green for patch (improved contrast)

## [1.0.3.1] - 2026-01-13

### Added
- Multi-segment version badges in README: each version segment gets its own colored badge
- Version badge scheme documentation in `/git-release` skill

### Changed
- Version history table now uses hierarchical colors (brightgreen→green→darkgreen→yellow for current, brightred→red→darkred→orange for prior)

## [1.0.3] - 2026-01-13

### Added
- README addendum: "On Human Multitasking and Evolution's LTS Release" — a humorous exploration of cognitive race conditions, inspired by a Teams meeting cross-talk incident

## [1.0.2.1] - 2026-01-13

### Fixed
- **Phase A**: Call `cleanup_app_sandbox()` at end of phase (was defined but never called)
- **Phase A**: Use `trap EXIT` to guarantee cleanup even on test failures
- **Phase A**: Stop background processes spawned from sandbox bin directory
- **Phase D**: Enhanced container cleanup with graceful 10-second timeout
- **Phase D**: Stop containers from test images and test-prefixed names
- **Phase D**: Gracefully shutdown docker-compose services after testing

## [1.0.2] - 2026-01-13

### Added
- **Phase H (Holistic)**: Full-stack cross-component analysis for detecting issues that span multiple layers
- **Phase I (Infrastructure)**: Infrastructure and runtime issue detection for environment validation
- `holistic` shortcut command (`/test holistic`)

### Changed
- Updated commands/test.md with Phase H documentation and argument hints
- Updated phase execution table with Phase H dependencies

## [1.0.1.2] - 2026-01-09

### Added
- CHANGELOG.md for tracking project history
- Version badge in README.md
- Version footer in commands/test.md
- Version reference in SKILL.md

## [1.0.1.1] - 2026-01-09

### Fixed
- Phase S: Use `stat -f` for reliable BTRFS detection (fixes false negatives on nested subvolumes)

### Changed
- Untrack `.yamllint.yml` (local tool config)
- Add `.bandit` and `pyproject.toml` to `.gitignore`
- Add `.claude-exit` patterns to `.gitignore`

## [1.0.1] - 2026-01-06

### Added
- Claude.ai web upload instructions in README
- SKILL.md for Claude.ai skill upload compatibility

### Fixed
- Simplify SKILL.md frontmatter for Claude.ai parser

## [1.0.0] - 2026-01-05

### Added
- Phase G: GitHub repository security audit with auto-remediation
- GitHub Actions security workflow (shellcheck, yamllint, markdownlint)
- Comprehensive code analysis tools integration across audit phases
- Universal Claude Code `.gitignore` patterns
- Phase D: Docker validation module
- Phase P: Production validation module
- Autonomous resolution directive - fixes ALL issues without prompting
- `--interactive` flag for optional interactive mode
- 18 complete audit phase files
- Interactive menu demos
- Full Claude Code plugin structure
- Symlink installation instructions

### Changed
- Converted to modular plugin architecture (93% context reduction)
- All phases load on-demand via subagents

[Unreleased]: https://github.com/TheBoscoClub/claude-test-skill/compare/v2.0.0...HEAD
[2.0.0]: https://github.com/TheBoscoClub/claude-test-skill/compare/v1.0.5...v2.0.0
[1.0.5]: https://github.com/TheBoscoClub/claude-test-skill/compare/v1.0.4...v1.0.5
[1.0.4]: https://github.com/TheBoscoClub/claude-test-skill/compare/v1.0.3.1...v1.0.4
[1.0.3.1]: https://github.com/TheBoscoClub/claude-test-skill/compare/v1.0.3...v1.0.3.1
[1.0.3]: https://github.com/TheBoscoClub/claude-test-skill/compare/v1.0.2.1...v1.0.3
[1.0.2.1]: https://github.com/TheBoscoClub/claude-test-skill/compare/v1.0.2...v1.0.2.1
[1.0.2]: https://github.com/TheBoscoClub/claude-test-skill/compare/v1.0.1.2...v1.0.2
[1.0.1.2]: https://github.com/TheBoscoClub/claude-test-skill/compare/v1.0.1.1...v1.0.1.2
[1.0.1.1]: https://github.com/TheBoscoClub/claude-test-skill/compare/v1.0.1...v1.0.1.1
[1.0.1]: https://github.com/TheBoscoClub/claude-test-skill/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/TheBoscoClub/claude-test-skill/releases/tag/v1.0.0
