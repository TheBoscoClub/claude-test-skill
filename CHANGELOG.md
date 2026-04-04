# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **Phase ST Section 7**: Governing Law validation (presence of all 5 governing rules)
- **Phase ST Section 8**: Phase directive compliance (prohibited language scan, cross-component verification, Phase H absence check)
- **Phase ST Section 9**: Tier dependency validation (Tier 3 composition, gate count, conditional logic)
- **Phase ST Section 10**: Flag and shortcut validation (all CLI flags, all 7 shortcuts, no stale holistic shortcut)

### Changed

- **Phase H dissolved** — Cross-component analysis distributed to every Tier 3 phase:
  - Phase H Step 1 (import/dependency mapping) → Phase 6 (Dependencies)
  - Phase H Step 2 (config sprawl) + Step 4 (quality issues) → Phase 7 (Quality)
  - Phase H Step 3 (data flow tracing) → Phase 5 (Security)
  - Phase H Step 5 (integration surface audit) → Phase I (Infrastructure)
- **Phase count reduction**: 21 phases reduced to 20
- **Holistic analysis as structural property**: All audits now holistic by design — cross-component analysis is a structural property of every analysis phase, not a separate optional phase
- **Opus phase count reduction**: Opus phase count reduced from 10 to 9

### Fixed

### Removed

- **`phase-H-holistic.md`**: Dissolved into Phases 5, 6, 7, I (no functionality lost)
- **`holistic` as separate concept**: All analysis is now inherently holistic — no separate holistic phase needed

## [4.0.0] - 2026-03-22

### Changed

- **BREAKING: Phase consolidation** — 27 phases reduced to 21 via strategic merges
  - Phase 3 (Report) → merged into Phase 2 (Test Execution & Analysis)
  - Phase 4 (Cleanup) → merged into Phase 7 (Code Quality)
  - Phase 8 (Coverage) → merged into Phase 2
  - Phase 9 (Debug) → merged into Phase 2
  - Phase 11 (Config) → merged into Phase 0 (Preflight)
  - Phase M (Mocking) → merged into Phase 0
- **Bloat reduction** — Phase 1 (50→23 KB), Phase P (46→20 KB), Phase V (54→22 KB)
- **Project-agnostic** — Removed all Audiobook-Manager hardcoded references; all phases now use manifest-driven detection

### Fixed

- **KillShell tool references**: Replaced with Bash tool across all phases
- **Phase 0 `VM_AVAILABLE` bug**: Was unconditionally true
- **Phase I broken `grep` syntax**: Fixed Quick Check Summary grep pattern
- **Phase C brittle `sed`-on-JSON parsing**: Replaced with `python3`/`jq`
- **Phase S filesystem detection**: `stat -f -c` was unreliable
- **Insecure plaintext password**: Removed from `vm-test-manifest.json` template
- **Orphaned agents**: `coverage-reviewer`, `security-scanner`, `test-analyzer` integrated into Phases 2 and 5
- **Phase handoff contracts**: Defined Phase 2 output schema and Phase 10 input expectations
- **Version conflict**: Resolved 3.1.0 in `test.md` → canonical from `VERSION` file
- **Stale references**: Deprecated tools and APIs cleaned up

### Removed

- **`test-legacy.md`**: 130 KB monolithic predecessor, superseded since v2.0
- **Merged phases**: Phase 3 (Report), Phase 4 (Cleanup), Phase 8 (Coverage), Phase 9 (Debug), Phase 11 (Config), Phase M (Mocking) — all merged into other phases

## [3.0.1] - 2026-02-18

### Added

- **Canonical help block** — `/test help` now displays a verbatim 90-line ASCII help with all 27 phases organized by tier, shortcuts, special phases (A, V, VM, ST), and behavioral notes
- **`github` shortcut in argument-hint** — Was missing from dispatcher frontmatter

### Fixed

- **Phase ST `grep` option parsing** — Section 6.3 `grep -q "- $tool"` misinterpreted leading dash as option flag; changed to `grep -qF -- "- $tool"`

## [3.0.0] - 2026-02-18

### Added

- **Phase H, I, V in documentation**: Added to README Phase Overview table and SKILL.md Available Phases table
- **ARCHITECTURE.md checklist step**: "Add to tier execution algorithm lists" — prevents the class of bug where a phase file exists but is never wired into the dispatcher

### Changed

- **Phase VM-lifecycle dates**: Example dates updated from 2024 to 2026
- **`test-menu.sh` symlink path**: Corrected to proper location

### Fixed

- **BREAKING: Phase I never executed** — Phase I (Infrastructure) was missing from the dispatcher's Available Phases table and Tier 3 execution lists, meaning it was never invoked despite having a complete phase file
- **Phase H missing from Tier 3** — Phase H (Holistic) was also missing from Tier 3 parallel execution arrays in the dispatcher
- **Stale tool count** — Multiple docs referenced "22 tools" when the actual count is 16 (README, ARCHITECTURE, CHANGELOG, Phase ST)
- **Stale Phase 13 in Tier 3** — Dispatcher still listed Phase 13 in Tier 3 analysis; it belongs in Tier 7 (Docs)
- **Phase ST false positives** — `EXPECTED_MODELS` map was missing Phase I and Phase VM; unconditional success messages reported "pass" even when earlier checks found failures
- **SECURITY.md stale counts** — File counts inflated by BTRFS snapshots: "12 shell scripts" → 3, "157 markdown files" → 45
- **Menu scripts missing phases** — `test-menu.sh`, `demo-fzf-menu.sh`, and `demo-whiptail-menu.sh` were missing phases P, D, G, H, I, V

## [2.0.1] - 2026-02-07

### Added

- **Opus 4.6 configuration headers**: All 27 phase files now include standardized metadata block with model tier, task tracking instructions, and phase-specific tool guidance
- **Phase ST Section 6**: New Opus 4.6 integration validation — verifies headers, model tiering assignments, 16-tool declaration, and dispatcher consistency
- **Phase ST expected phases list**: Added `phase-V-vm-testing.md` and `phase-VM-lifecycle.md`

### Fixed

- **Phase ST project path**: Corrected from `test-skill` to `claude-test-skill`

## [2.0.0] - 2026-02-06

### Added

- **Opus 4.6 model pinning**: Frontmatter `model: opus` ensures test skill always runs on Opus
- **Subagent model tiering**: Per-phase model selection (opus/sonnet/haiku) based on complexity:
  - Opus: Phases 1, 5, 7, 10, A, P, D, G, H, ST (complex analysis, security, architecture)
  - Sonnet: Phases 0, 2, 2a, 6, 8, 9, 11, 12, 13, I, V, VM (standard testing, coverage, linting)
  - Haiku: Phases S, M, 3, 4, C (snapshots, file checks, simple validation)
- **Task progress tracking**: Integration with `TaskCreate`/`TaskUpdate`/`TaskList` for real-time phase tracking with dependency chains
- **9 new allowed tools**: `TaskOutput`, `TaskStop`, `TaskCreate`, `TaskUpdate`, `TaskList`, `AskUserQuestion`, `KillShell`, `NotebookEdit`, `WebSearch`
- **Background phase execution**: `run_in_background: true` guidance for independent phases

### Changed

- **BREAKING: `allowed-tools` syntax**: Converted from CSV to YAML list syntax (requires Claude Code 2.1+)
- **BREAKING: Tool count expanded**: 7 to 16 tools — older Claude Code versions may reject unknown tools
- **GitHub org migration**: All GitHub URLs updated from `greogory` to `TheBoscoClub` organization
- **CodeFactor badge**: Added to README
- **GitHub Actions security**: Pinned to commit SHAs for supply chain security

## [1.0.5] - 2026-01-14

### Added

- **Phase ST (Self-Test)**: Meta-testing phase that validates the test-skill framework itself
  - Checks all 25 phase files exist and are readable
  - Validates symlink configuration
  - Verifies dispatcher references all phases
  - Confirms all 13 required tools are installed
  - Only runs with explicit `--phase=ST` (never in normal runs)
- **`docs/ARCHITECTURE.md`**: Comprehensive architecture documentation
- **Security tools**: Added `grype` (SBOM scanning), `semgrep` (multi-language SAST), `checkov` (IaC security)

### Changed

- **Phase 5 (Security)**: Consolidated Phase SEC into Phase 5 for comprehensive 8-tool security suite
  - SAST: `bandit`, `semgrep`, `shellcheck`, CodeQL
  - Dependency: `pip-audit`, `trivy`, `grype`, `checkov`
  - Sections: GitHub security, local project, installed app
- **Dispatcher shortcuts**: Added `/test security` shortcut and `--phase=SEC` alias (both map to Phase 5)
- **README update**: Reflects 25-phase system
- **Documentation cleanup**: Removed Phase SEC references

### Removed

- **`phase-SEC-security.md`**: Consolidated into `phase-5-security.md` (no functionality lost)

## [1.0.4] - 2026-01-14

### Added

- **Phase SEC (Security)**: New standalone comprehensive security testing phase covering:
  - GitHub security features audit (Dependabot, secret scanning, CodeQL)
  - Local project security (SAST with `bandit`/`shellcheck`, dependency scanning, secret detection)
  - Installed app security (permissions, config sync, service security, database)
  - Can be invoked standalone with `/test --phase SEC`
- **Phase P Step 2b**: Validate wrapper script targets (prevents silent `exec` failures at runtime)
- **Phase P Step 5b**: Validate production/development separation (critical isolation check)

### Changed

- **Version badge colors**: Darkgreen for minor, green for patch (improved contrast)

## [1.0.3.1] - 2026-01-13

### Added

- **Multi-segment version badges**: Each version segment gets its own colored badge in README
- **Version badge scheme docs**: Documented in `/git-release` skill

### Changed

- **Version history table colors**: Now uses hierarchical colors (brightgreen→green→darkgreen→yellow for current, brightred→red→darkred→orange for prior)

## [1.0.3] - 2026-01-13

### Added

- **README addendum**: "On Human Multitasking and Evolution's LTS Release" — a humorous exploration of cognitive race conditions, inspired by a Teams meeting cross-talk incident

## [1.0.2.1] - 2026-01-13

### Fixed

- **Phase A cleanup**: Call `cleanup_app_sandbox()` at end of phase (was defined but never called)
- **Phase A exit trap**: Use `trap EXIT` to guarantee cleanup even on test failures
- **Phase A background processes**: Stop background processes spawned from sandbox bin directory
- **Phase D container cleanup**: Enhanced with graceful 10-second timeout
- **Phase D test containers**: Stop containers from test images and test-prefixed names
- **Phase D docker-compose shutdown**: Gracefully shutdown docker-compose services after testing

## [1.0.2] - 2026-01-13

### Added

- **Phase H (Holistic)**: Full-stack cross-component analysis for detecting issues that span multiple layers
- **Phase I (Infrastructure)**: Infrastructure and runtime issue detection for environment validation
- **`holistic` shortcut**: `/test holistic` command

### Changed

- **`commands/test.md` update**: Added Phase H documentation and argument hints
- **Phase execution table**: Updated with Phase H dependencies

## [1.0.1.2] - 2026-01-09

### Added

- **`CHANGELOG.md`**: Tracking project history
- **Version badge**: Added to `README.md`
- **Version footer**: Added to `commands/test.md`
- **Version reference**: Added to `SKILL.md`

## [1.0.1.1] - 2026-01-09

### Changed

- **Untrack `.yamllint.yml`**: Local tool config removed from git
- **`.gitignore` additions**: Added `.bandit`, `pyproject.toml`, and `.claude-exit` patterns

### Fixed

- **Phase S BTRFS detection**: Use `stat -f` for reliable detection (fixes false negatives on nested subvolumes)

## [1.0.1] - 2026-01-06

### Added

- **Claude.ai upload instructions**: Added to README
- **`SKILL.md`**: Claude.ai skill upload compatibility

### Fixed

- **SKILL.md frontmatter**: Simplified for Claude.ai parser compatibility

## [1.0.0] - 2026-01-05

### Added

- **Phase G**: GitHub repository security audit with auto-remediation
- **GitHub Actions security workflow**: `shellcheck`, `yamllint`, `markdownlint`
- **Code analysis integration**: Comprehensive tools across audit phases
- **Universal `.gitignore` patterns**: Claude Code entries
- **Phase D**: Docker validation module
- **Phase P**: Production validation module
- **Autonomous resolution directive**: Fixes ALL issues without prompting
- **`--interactive` flag**: Optional interactive mode
- **18 complete audit phase files**: Full modular audit system
- **Interactive menu demos**: `test-menu.sh`, `demo-fzf-menu.sh`, `demo-whiptail-menu.sh`
- **Full Claude Code plugin structure**: Commands, skills, symlinks
- **Symlink installation instructions**: Setup documentation

### Changed

- **Modular plugin architecture**: Converted from monolithic design (93% context reduction)
- **On-demand phase loading**: All phases load via subagents

[Unreleased]: https://github.com/TheBoscoClub/claude-test-skill/compare/v4.0.0...HEAD
[4.0.0]: https://github.com/TheBoscoClub/claude-test-skill/compare/v3.0.1...v4.0.0
[3.0.1]: https://github.com/TheBoscoClub/claude-test-skill/compare/v3.0.0...v3.0.1
[3.0.0]: https://github.com/TheBoscoClub/claude-test-skill/compare/v2.0.1...v3.0.0
[2.0.1]: https://github.com/TheBoscoClub/claude-test-skill/compare/v2.0.0...v2.0.1
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
