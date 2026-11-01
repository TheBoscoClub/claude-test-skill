# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

> **Note on the v3.0.1 → v4.1.1 tag gap**: The `[4.0.0]` and (implicit) `4.1.0` entries
> below were cut internally as VERSION-file bumps and CHANGELOG entries but were never
> individually git-tagged or published as GitHub releases. `v4.1.1` is therefore the
> first tagged release in the `4.x` series — its release notes cumulatively cover the
> phase consolidation (`4.0.0`: 27 → 21), Phase H dissolution (`4.1.0`: 21 → 20), and
> this release's documentation-only additions. The `[4.0.0]` comparison link below
> points at a tag that does not exist on GitHub; it is preserved for historical
> continuity.

## [Unreleased]

### Added

- **Regression test `tests/test-vm-lib.sh`** — exercises the shipping VM code (Phase 1 sweep, Phase 10a create/reset/snapshot/cross-distro/`run_phase_V`, Phase 10b start/shutdown) with logging stubs for `virsh` and `sudo`, one phase per shell as in a real run: helpers missing, unlisted or exclusive VMs, every destructive branch and the deploy identity. No VM is touched. 36/36 against this tree; 24 of 36 fail against the tree before the fix
- **Self-test Section 11 runs the regression tests** — `tests/test-*.sh` (the `dqi` and `pqy` guards) were run by nothing, so a regression would have gone unseen. Phase ST now runs every one and fails on a non-zero exit or an empty `tests/` directory
- **`--budget` flag** — drops the Opus floor so judgement-tier phases run on the session model; a cheaper audit becomes an explicit choice rather than a side effect of the session
- **Semgrep CI workflow** (`.github/workflows/semgrep.yml`): runs `semgrep ci` — Code (SAST), Secrets and Supply Chain — diff-aware on pull requests, full on pushes to `main`, weekly on schedule and on manual dispatch, reporting to the Semgrep AppSec Platform deployment. Engine image pinned `tag@digest`; the sole credential is the Agent (CI) scoped `SEMGREP_APP_TOKEN` org secret — no GitHub App is installed and Semgrep is granted no code access

### Removed

- **gstack companion references removed** (`commands/test.md` Companion Tools section, `phase-5a-security.md` `/gstack-cso` paragraph, `phase-9a-app-testing.md` companion list): the gstack skills were uninstalled from the host on 2026-10-08; `/test` never invoked them.
- **`TaskOutput` dropped from the dispatcher's `allowed-tools`** (`commands/test.md`) — the tool no longer exists in Claude Code, so the entry granted nothing. Self-test 6.3 now expects 15 tools, and the `docs/ARCHITECTURE.md` tool table is corrected to the declared set (it listed `Task` and omitted `TaskGet` and `WebFetch`)

### Changed

- **Test VM selection is configured-only** — `resolve_test_vm` is the one place a VM is chosen. It lives in `skills/test-phases/lib/test-vm.sh`, which Phases 1, 10a and 10b each source themselves (each phase's subagent reads only its own phase file; a missing helper file is an error, exit 2, never "nothing configured"): `~/.claude/config/project-vm-map.json` `projects.<project>.vm`, then the manifest's `vm_testing.default_vm`, then the map's `default.vm`. The VM must be listed under the map's `vms` — a tracked manifest can choose among the installation's VMs, never add one. It refuses when nothing is configured, the map is missing, unreadable or not an object, the VM is unlisted, or it is `exclusive_to` another project (in either direction). Phase 10a cross-distro testing takes its VMs from the manifest's `test_environments` (type `existing`) through the same check; the built-in `cachyos-test ubuntu-test fedora-test` list is gone. The fallback that took the first `virsh list` name containing `test` or `dev` is gone — it could pick another project's exclusive VM. There is no built-in default VM
- **Host locations are installation keys with no default**: the ISO library (`paths.iso_dir`), VM image directories (`paths.vm_storage_dirs`) and SSH identity (`vms.<vm>.ssh_user` / `ssh_key`, or the manifest's `ssh_config`) are read from `project-vm-map.json`. `create_test_vm` refuses without them; it is the only reader of `paths.*`
- **Phase 1's pre-test snapshot sweep is part of the skill** (`sweep_pretest_snapshots`) instead of a call to a host-only script; it sources the shared helpers and uses `resolve_test_vm`, so it sweeps exactly the VM Phase 10b snapshots, and deletes through `delete_pretest_snapshot`
- **Self-test finds the checkout** from the installed `commands/test.md` symlink, or `$TEST_SKILL_PROJECT`, instead of a fixed path
- **Markdown lint lints the tracked list**: `git ls-files -z -- '*.md'`, refusing an empty list rather than passing vacuously; the job's checkout sets `persist-credentials: false`
- **Markdown lint is a CI gate**: `.github/workflows/security.yml` runs markdownlint-cli 0.48.0 (pinned, same as local)
  over every tracked `*.md`, replacing a `markdownlint-cli2-action` step set to `continue-on-error: true` that could
  never fail; `.markdownlint.json` stays the tracked config and `.markdownlintignore` is new — 34 files reformatted
  (delimiter rows, fence languages, blank lines, one nested-fence repair in `docs/ARCHITECTURE.md` and
  `agents/test-analyzer.md`), three per-line or per-block disables with reasons in the comment
- **Always-loaded rules trimmed**: narrative, incidents and mechanism moved verbatim from `CLAUDE.md` and `.claude/rules/*.md` into `.claude/docs/rules-reference/` (not auto-loaded) — loaded size 6,114 → 6,521 chars, every binding rule kept (lossless check: each removed line found whole in a reference doc; independent review) — size rose slightly: host paths moved to a gitignored local rule and the review restored corrected Phase 11 text
- **live-sync baseline**: an empty `live-sync.conf` and the live-sync pre-commit gate; host paths are never tracked
  in this public repository, so the `tm` launcher stays at the repository root
- **`AGENTS.md` regenerated from the house template**: `bd doctor` entry (previously a local note pointing at `bd preflight`) now marked unsupported in embedded mode (bd 1.0.3 prints troubleshooting only); blank line added before the prompting-commands list and a spaced table separator (markdownlint MD032, MD060)
- **Judgement-tier phases follow the session model, with an Opus floor** — phases 3, 5a, 5c, 6, 9a–9d and ST were pinned to `opus`, so a Fable session audited below its builder. They now run on `JUDGEMENT_MODEL`, resolved once per run to the more capable of the session model and `opus` (`fable` > `opus` > `sonnet` > `haiku`) and stated in the final report; QA modules use it too. The Opus floor is deliberate — a Sonnet or Haiku session still audits judgement phases on Opus unless `--budget` is passed. The `sonnet` and `haiku` tiers are unchanged. The dispatcher's frontmatter `model: opus` is removed, so the dispatcher itself runs on the session model
- **Self-test 6.2 and 6.4 enforce the judgement tier** — 6.2 expects `judgement` in the nine phase headers; 6.4 fails on a frontmatter model pin, a missing `JUDGEMENT_MODEL` resolution or `--budget` flag, or a subagent spawn hard-coded to `opus`

### Fixed

- **Phase 10a deploys with the configured SSH identity** — `run_phase_V` resolved the user and key from the map or manifest but never exported them, so `deploy_to_vm` and `run_vm_tests` fell back to `testuser` and `~/.ssh/vm_test_key`; it now exports `VM_SSH_USER` / `VM_SSH_KEY` (case in `tests/test-vm-lib.sh`)
- **The `post_test_restore` lifecycle table agrees with Phase 10b again** (`.claude/rules/vm-testing.md`) — the trim left the startup row saying "Shut down → start normally" beside a later row saying revert; restored as one startup row (force-stop if running, then revert to pristine in either state, then start), and the "Before" row no longer claims the VM is pristine. Phase 10b's own state table and Phase 1's recovery note (which still said Phase 11 restores pristine) are corrected the same way
- **Phase 9d Step 8 can count orphaned bd issues again** — it grepped `bd preflight` output for "orphan", but on bd 1.0.3 that command prints a PR checklist for bd's own Go repository and exits 0, so the count was always zero. It now runs `bd orphans --json` through the parse-checked `json_count` (`null` is a real zero; a `bd` failure or non-JSON output is reported UNKNOWN, not clean), with `bd stale` and `bd lint` shown as information. Regression test `tests/test-bd-health.sh` extracts Step 8 from the skill and runs it in a throwaway bd repository: 9/9 against the fix, 8 of 9 failing against the old step
- **Self-test 6.3 no longer reports success on failure** — its summary line printed `✅ Dispatcher declares 14/15 core allowed tools` even with a tool missing; it is now conditional, and the expected total is derived from `EXPECTED_TOOLS` instead of a hardcoded count

### Security

- **Host paths out of `vm-testing.md`**: the operator's ISO and image paths moved to gitignored `.claude/rules/local-vm-paths.md`
- **No installation values left in the tree** (bd `claude-test-skill-zy9`): host paths, VM names and hardware sizes, VM snapshot names, a username, a private-range address, the Semgrep deployment name, other projects' names and pointers to host-only scripts are replaced with placeholders, generic wording or installation keys — phases 1, 2, 8, 9b, 10a, 10b, 11 and ST, the template manifest, rules, design docs, `CLAUDE.md`, `test-menu.sh`, `.gitignore` and two older CHANGELOG entries
- **`/test` never deletes a pristine snapshot, an existing VM or a disk** — the only snapshot delete is `delete_pretest_snapshot` (`lib/test-vm.sh`), which refuses any name but `pre-test-YYYYMMDD-HHMMSS` and the project's `pristine_snapshot`; Phase 10b validates the state file's `pre_test_snapshot` before reverting to or deleting it. `reset_vm_to_pristine` only reverts (its external-overlay branch deleted the pristine snapshot's metadata and the overlay); Phase 10b no longer restores an external pristine qcow2 by itself (it overwrote the active disk and deleted every snapshot's metadata, pristine included) — a failed revert stops for manual recovery. `create_test_vm` refuses an existing VM name or disk instead of `virsh undefine --remove-all-storage`, validates its arguments and runs `virt-install` from an argument array instead of `eval`
- **Host-identifier guard map** `.claude/local-scrub-map.txt` is gitignored; the guard hooks that read it live in `.git/hooks`, installed per machine
- **Every deletion target is a literal absolute path or a `"${VAR:?}"` expansion** (the `trap` cleanups in `tests/test-bd-health.sh`, `test-gh-json.sh`, `test-scan-count.sh`) — an empty or unset variable now aborts instead of deleting from `/` or the cwd
- **Keep bd issues local**: `.beads/issues.jsonl` is now gitignored and
  untracked, and bd's `export.git-add` is off — the issue tracker stays on
  the maintainer's machine instead of being published with every commit

## [4.1.1] - 2026-04-23

### Added

- **Phase ST Section 7**: Governing Law validation (presence of all 5 governing rules)
- **Phase ST Section 8**: Phase directive compliance (prohibited language scan, cross-component verification, Phase H absence check)
- **Phase ST Section 9**: Tier dependency validation (Tier 3 composition, gate count, conditional logic)
- **Phase ST Section 10**: Flag and shortcut validation (all CLI flags, all 7 shortcuts, no stale holistic shortcut)
- **Companion Tools section in `commands/test.md`**: Points at gstack skills that complement `/test` for narrower or strategic jobs without replacing any phase — `/gstack-health` (fast pulse), `/gstack-cso --skills` (skill supply-chain blind spot), `/gstack-qa`/`/gstack-benchmark`/`/gstack-canary` (web-facing companions), `/gstack-autoplan` (strategic sign-off), `/gstack-investigate` (root-cause debugging). Explicit note that the Governing Law still applies and a companion run does not satisfy `/test`'s completeness requirement
- **`/gstack-cso --skills` reference in `phase-5a-security.md`**: Optional companion covering skill-supply-chain (curl-pipe-to-shell, unjustified credential access, writes outside skill dir, non-public MCP endpoints) — a blind spot not covered by Phase 5a's own tooling
- **`/gstack-qa`, `/gstack-qa-only`, `/gstack-benchmark`, `/gstack-canary` references in `phase-9a-app-testing.md`**: Optional web-facing companions for projects where Phase 3 detected a web UI; all invoked out-of-phase by the user, Phase 9a proceeds autonomously regardless

### Changed

- **Phase H dissolved** — Cross-component analysis distributed to every Tier 3 phase:
  - Phase H Step 1 (import/dependency mapping) → Phase 6 (Dependencies)
  - Phase H Step 2 (config sprawl) + Step 4 (quality issues) → Phase 7 (Quality)
  - Phase H Step 3 (data flow tracing) → Phase 5 (Security)
  - Phase H Step 5 (integration surface audit) → Phase I (Infrastructure)
- **Phase count reduction**: 21 phases reduced to 20
- **Holistic analysis as structural property**: All audits now holistic by design — cross-component analysis is a structural property of every analysis phase, not a separate optional phase
- **Opus phase count reduction**: Opus phase count reduced from 10 to 9

### Removed

- **`phase-H-holistic.md`**: Dissolved into Phases 5, 6, 7, I (no functionality lost)
- **`holistic` as separate concept**: All analysis is now inherently holistic — no separate holistic phase needed

### Fixed

- **`plugin.json` version drift**: Synced from stale `4.0.0` to current `VERSION` file value `4.1.0`. Pre-existing drift — both files should now match per `rules/development-tools.md` single-canonical-source + keep-packaging-in-sync rules

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
- **Project-agnostic** — Removed all hardcoded references to one specific project; all phases now use manifest-driven detection

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

[Unreleased]: https://github.com/TheBoscoClub/claude-test-skill/compare/v4.1.1...HEAD
[4.1.1]: https://github.com/TheBoscoClub/claude-test-skill/compare/v3.0.1...v4.1.1
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
