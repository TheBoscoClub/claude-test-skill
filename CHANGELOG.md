# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

### Changed

### Fixed

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

[Unreleased]: https://github.com/greogory/test-skill/compare/v1.0.1.2...HEAD
[1.0.1.2]: https://github.com/greogory/test-skill/compare/v1.0.1.1...v1.0.1.2
[1.0.1.1]: https://github.com/greogory/test-skill/compare/v1.0.1...v1.0.1.1
[1.0.1]: https://github.com/greogory/test-skill/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/greogory/test-skill/releases/tag/v1.0.0
