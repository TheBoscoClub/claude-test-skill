---
description: Comprehensive autonomous project audit - testing, security, debugging, fixing, documentation, and code quality (18 phases with BTRFS snapshots) (user)
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, Task
argument-hint: "[help] [component] [--verbose] [--phase=X] [--skip-snapshot] [--output=FILE]"
---

# Comprehensive Autonomous Project Audit

This skill performs a **complete 18-phase autonomous audit** of any project. It doesn't just test—it discovers issues, debugs root causes, applies fixes, and verifies results. **Safety snapshots and sandboxed mocking ensure safe execution.**

---

## HELP MODE

**If the user passes `help` as an argument, display this help section and exit without running the audit.**

### Usage

```
/test                           # Run full audit on current project
/test help                      # Display this help documentation
/test --phase=4                 # Run only Phase 4 (Deprecation Cleanup)
/test --phase=0-3               # Run Phases 0 through 3
/test --skip-snapshot           # Skip BTRFS snapshot (not recommended)
/test --verbose                 # Show detailed output for all operations
/test --output=audit.log        # Save output to specified file
/test component-name            # Run audit focused on specific component
/test --phase=4 --verbose       # Combine options as needed
```

### Options

| Option | Description |
|--------|-------------|
| `help` | Display this help documentation and exit |
| `--phase=X` | Run only phase X (0-13, S for snapshot, 2a for runtime health) |
| `--phase=X-Y` | Run phases X through Y inclusive |
| `--skip-snapshot` | Skip BTRFS snapshot creation (use with caution) |
| `--verbose` | Show detailed output including all commands run |
| `--output=FILE` | Save audit output to FILE (default: `audit-YYYYMMDD-HHMMSS.log`) |
| `component` | Focus audit on specific component/module |

### Phases Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        /test SKILL - 18 PHASES                              │
│  (Comprehensive autonomous project audit with safe mocking & cleanup)       │
├─────────────────────────────────────────────────────────────────────────────┤
│  PHASE S: BTRFS SNAPSHOT                                                    │
│  └── Create read-only safety snapshots before any modifications            │
│                                                                             │
│  PHASE M: SAFE MOCKING ENVIRONMENT                                          │
│  ├── Step 1: Create sandbox directory                                       │
│  ├── Step 2: Create mock command wrappers (rm, sudo, systemctl, curl)      │
│  ├── Step 3: Activate sandbox (update PATH)                                 │
│  └── Step 4: Create mock test data                                          │
│                                                                             │
│  PHASE 0: PRE-FLIGHT CHECKS                                                 │
│  ├── Step 1: Validate project structure                                     │
│  ├── Step 2: Check dependencies installed                                   │
│  ├── Step 3: Verify environment variables                                   │
│  ├── Step 4: Test service connectivity                                      │
│  ├── Step 5: Check file permissions                                         │
│  └── Step 6: Validate service user permissions                              │
│                                                                             │
│  PHASE 1: DISCOVERY                                                         │
│  ├── Step 1: Identify project type                                          │
│  ├── Step 2: Find all test files                                            │
│  ├── Step 3: Locate configuration files                                     │
│  └── Step 4: Map component dependencies                                     │
│                                                                             │
│  PHASE 2: EXECUTE TESTS                                                     │
│  ├── Step 1: Run unit tests                                                 │
│  ├── Step 2: Run integration tests                                          │
│  ├── Step 3: Run E2E tests                                                  │
│  └── Step 4: Verify actual operations (not just status)                     │
│                                                                             │
│  PHASE 2a: RUNTIME SERVICE HEALTH                                           │
│  ├── Step 1: Identify running services                                      │
│  ├── Step 2: Detect stuck processes (sleep loops)                           │
│  ├── Step 3: Verify actual work is happening                                │
│  ├── Step 4: Check non-interactive mode compatibility                       │
│  ├── Step 5: Analyze logs for stuck patterns                                │
│  └── Step 6: Cross-service dependency health                                │
│                                                                             │
│  PHASE 3: REPORT RESULTS                                                    │
│  └── Generate detailed test reports with evidence                           │
│                                                                             │
│  PHASE 4: DEPRECATION CLEANUP                                               │
│  ├── Step 1: Identify deprecated code markers                               │
│  ├── Step 2: Find unused imports/modules                                    │
│  ├── Step 3: Detect dead code paths                                         │
│  ├── Step 4: Remove confirmed dead code                                     │
│  ├── Step 5: DEPLOYMENT VERSION MISMATCH DETECTION                          │
│  │   ├── 5a: Check symlinks point to canonical source                       │
│  │   ├── 5b: Compare installed vs source file versions                      │
│  │   ├── 5c: Validate symlink targets exist                                 │
│  │   └── 5d: Compare systemd service files                                  │
│  └── Step 6: Report deployment mismatches                                   │
│                                                                             │
│  PHASE 5: SECURITY AUDIT                                                    │
│  ├── Step 1: Scan for hardcoded secrets                                     │
│  ├── Step 2: Check for CVEs in dependencies                                 │
│  ├── Step 3: OWASP vulnerability scan                                       │
│  └── Step 4: Review access controls                                         │
│                                                                             │
│  PHASE 6: DEPENDENCY HEALTH                                                 │
│  ├── Step 1: List all dependencies                                          │
│  ├── Step 2: Check for outdated packages                                    │
│  ├── Step 3: Identify unused dependencies                                   │
│  ├── Step 4: Check license compatibility                                    │
│  └── Step 5: Verify dependency security                                     │
│                                                                             │
│  PHASE 7: CODE QUALITY                                                      │
│  ├── Step 1: Run linters (ruff, eslint, etc.)                               │
│  ├── Step 2: Check cyclomatic complexity                                    │
│  ├── Step 3: Identify anti-patterns                                         │
│  └── Step 4: Type safety analysis                                           │
│                                                                             │
│  PHASE 8: TEST COVERAGE                                                     │
│  ├── Step 1: Generate coverage report                                       │
│  ├── Step 2: Identify uncovered critical paths                              │
│  └── Step 3: Recommend high-value tests                                     │
│                                                                             │
│  PHASE 9: DEBUGGING                                                         │
│  ├── Step 1: Analyze test failures                                          │
│  ├── Step 2: Classify failure types                                         │
│  ├── Step 3: Generate fix hypotheses                                        │
│  └── Step 4: Recommend specific fixes                                       │
│                                                                             │
│  PHASE 10: AUTO-FIXING                                                      │
│  ├── Step 1: Prioritize fixes                                               │
│  ├── Step 2: Apply automated fixes                                          │
│  ├── Step 3: Fix security issues                                            │
│  ├── Step 4: Fix failing tests                                              │
│  ├── Step 5: Update dependencies                                            │
│  └── Step 6: Verify each fix                                                │
│                                                                             │
│  PHASE 11: CONFIGURATION AUDIT                                              │
│  ├── Step 1: Validate config file syntax                                    │
│  ├── Step 2: Check environment variables                                    │
│  ├── Step 3: Verify secrets management                                      │
│  └── Step 4: Compare .env with .env.example                                 │
│                                                                             │
│  PHASE 12: FINAL VERIFICATION                                               │
│  ├── Step 1: Re-run full test suite                                         │
│  ├── Step 2: Verify build succeeds                                          │
│  ├── Step 3: Smoke test core functionality                                  │
│  ├── Step 4: Regression check                                               │
│  ├── Step 4a: DEPLOYMENT CONSISTENCY REGRESSION CHECK                       │
│  └── Step 5: Generate final report                                          │
│                                                                             │
│  PHASE 13: DOCUMENTATION                                                     │
│  ├── Step 1: Inventory all documentation files                              │
│  ├── Step 2: Verify documentation accuracy                                  │
│  ├── Step 3: Update stale documentation                                     │
│  └── Step 4: Cross-reference validation                                     │
│                                                                             │
│  PHASE C: CLEANUP (FINAL)                                                    │
│  ├── Step 1: Deactivate sandbox                                             │
│  ├── Step 2: Remove sandbox directory                                       │
│  ├── Step 3: Remove temporary test files                                    │
│  ├── Step 4: BTRFS snapshot cleanup guidance                                │
│  └── Step 5: Generate cleanup summary                                       │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Features

| Feature | Description |
|---------|-------------|
| **BTRFS Snapshots** | Automatic read-only snapshots before modifications for instant rollback |
| **Safe Mocking Environment** | Sandboxed execution prevents accidental data loss from dangerous commands |
| **Project Config File** | Per-project `.claude-test.yaml` customizes thresholds, paths, and behaviors |
| **85% Coverage Enforcement** | Enforces minimum test coverage threshold (configurable) |
| **Stuck Process Detection** | Finds services stuck in sleep loops instead of doing real work |
| **Non-Interactive Mode Checks** | Detects ffmpeg/apt/rm commands that will prompt and hang in services |
| **Version Mismatch Detection** | Finds symlinks pointing to stale versions, service file drift |
| **Python Environment Cleanup** | Identifies outdated venvs, stale .pyc files, unused packages |
| **Service Permission Validation** | Checks if service users can write to required directories |
| **Cascading Failure Detection** | Traces root cause when one failure causes downstream issues |
| **Human-Readable Output** | Clear formatting with emoji indicators and progress tracking |
| **Output Logging** | Saves complete audit log with project name, date, timestamp |
| **Automatic Cleanup** | Restores environment, removes temp files, suggests snapshot cleanup |

### Output Files

The audit automatically creates an output file:

```
Location: <project-dir>/audit-YYYYMMDD-HHMMSS.log

Example: /hddRaid1/ClaudeCodeProjects/<ProjectName>/audit-YYYYMMDD-HHMMSS.log
```

The output file contains:
- Full audit transcript matching CLI output
- Project name and path
- Audit start/end timestamps
- All phase results with evidence
- Summary statistics
- Recommendations

---

## What This Skill Does

| Phase | Name | Description |
|-------|------|-------------|
| S | **BTRFS Snapshot** | **Create safety snapshots of all affected volumes before modifications** |
| M | **Safe Mocking** | **Create sandboxed environment, mock dangerous commands** |
| 0 | Pre-Flight | Validate environment, dependencies, **load .claude-test.yaml config** |
| 1 | Discovery | Identify all testable components, test infrastructure, logging |
| 2 | Execute Tests | Run actual operations, not just status checks |
| 2a | **Runtime Service Health** | **Detect stuck processes, non-interactive failures, permission errors** |
| 3 | Report Results | Detailed per-component test reports with evidence |
| 4 | Deprecation Cleanup | Find and remove dead code, unused files, **detect deployment version mismatches** |
| 5 | Security Audit | Scan for secrets, CVEs, OWASP vulnerabilities |
| 6 | Dependency Health | Check outdated, unused, vulnerable, unlicensed packages |
| 7 | Code Quality | Linting, complexity, anti-patterns, type safety |
| 8 | **Test Coverage** | **Identify untested paths, ENFORCE 85% MINIMUM (configurable)** |
| 9 | Debugging | Automatically diagnose root causes of failures |
| 10 | Auto-Fixing | Apply fixes, verify, rollback if regression |
| 11 | Configuration | Validate configs, env vars, secrets management |
| 12 | Final Verification | Re-run all checks, confirm no regressions |
| 13 | Documentation | Review and update all docs (after all fixes applied) |
| C | **Cleanup** | **Deactivate sandbox, remove temp files, suggest snapshot cleanup** |

## Key Principles

- **Snapshot-First**: BTRFS snapshots created before ANY modifications for instant rollback
- **Safe-by-Default**: Mocking environment prevents accidental damage from dangerous commands
- **Config-Driven**: Per-project `.claude-test.yaml` customizes behavior, thresholds, paths
- **85% Coverage**: Enforces minimum test coverage (default 85%, configurable)
- **Autonomous**: Runs through all phases without manual intervention where possible
- **Evidence-Based**: Every finding includes proof (file:line, logs, outputs)
- **Self-Healing**: Automatically fixes what it can, documents what it can't
- **Comprehensive**: Covers testing, security, quality, deps, docs, config
- **Non-Destructive**: Verifies before deleting, rolls back failed fixes
- **Deployment-Aware**: Detects mismatches between installed files and project source
- **Clean-Exit**: Always cleans up after itself, restores environment
- **Version-Consistent**: Ensures symlinks, service files, and scripts all match canonical source

## Robustness Requirements

Every phase MUST:
1. **Verify before acting** - Never assume state; check current state first
2. **Detect cascading failures** - One failure often causes others; trace root cause
3. **Check for version drift** - Installed files can diverge from source over time
4. **Validate symlink integrity** - Symlinks can point to stale or wrong versions
5. **Compare timestamps** - Modification dates reveal stale vs current versions
6. **Handle non-interactive mode** - Services run without TTY; detect prompt failures
7. **Check service user context** - Permissions differ between interactive and service users
8. **Detect stuck processes** - Sleep loops and retry patterns indicate failures
9. **Monitor actual work** - "Running" status doesn't mean actual progress
10. **Cross-validate deployments** - Source, installed, and running versions must match

## Output Logging Requirements

**CRITICAL**: Every audit MUST create an output log file that matches the CLI output exactly.

### Output File Creation

At the **START** of every audit, create the output log:

```bash
# Generate output filename
PROJECT_NAME=$(basename "$(pwd)")
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
OUTPUT_FILE="${PROJECT_DIR}/audit-${TIMESTAMP}.log"

# Create header
cat > "$OUTPUT_FILE" << EOF
================================================================================
                     COMPREHENSIVE PROJECT AUDIT REPORT
================================================================================

Project:    ${PROJECT_NAME}
Path:       $(pwd)
Started:    $(date '+%Y-%m-%d %H:%M:%S %Z')
Audit ID:   audit-${TIMESTAMP}

================================================================================
EOF

echo "📄 Audit log: $OUTPUT_FILE"
```

### Logging During Audit

All output MUST be both:
1. Displayed to the user in real-time
2. Appended to the output file

```bash
# Helper function for dual output
log_output() {
    echo "$1" | tee -a "$OUTPUT_FILE"
}

# Use for all phase headers, results, and summaries
log_output "═══════════════════════════════════════════════════════════════════"
log_output "  PHASE 4: DEPRECATION CLEANUP"
log_output "═══════════════════════════════════════════════════════════════════"
```

### Output File Footer

At the **END** of every audit, append the footer:

```bash
cat >> "$OUTPUT_FILE" << EOF

================================================================================
                           AUDIT COMPLETE
================================================================================

Finished:   $(date '+%Y-%m-%d %H:%M:%S %Z')
Duration:   [calculated duration]
Status:     ✅ ALL CLEAR / ⚠️ ISSUES REMAIN / ❌ CRITICAL PROBLEMS

Summary:
  Phases completed: X/16
  Issues found:     X
  Issues fixed:     X
  Manual needed:    X

Output saved to: $OUTPUT_FILE
================================================================================
EOF
```

## Pristine Project Requirements

**The /test skill MUST keep each project as pristine as possible.**

### What "Pristine" Means

A pristine project has:
- ❌ No obsolete code, files, or configurations
- ❌ No deprecated functions or classes still in use
- ❌ No unused imports, variables, or dependencies
- ❌ No stale Python virtual environments or .pyc files
- ❌ No outdated packages with security vulnerabilities
- ❌ No orphaned configuration files from removed features
- ❌ No backup files (.bak, .old, .orig) committed to source
- ❌ No dead symlinks or broken references
- ❌ No service files that don't match project source
- ❌ No version mismatches between installed and source files

### Pristine Checklist (Run in Phase 4)

```bash
# PRISTINE PROJECT AUDIT CHECKLIST

echo "🔍 Checking for non-pristine elements..."

# 1. Obsolete Python artifacts
find . -type d -name "__pycache__" -o -name "*.pyc" -o -name ".pytest_cache" 2>/dev/null | head -10
find . -type d -name ".venv" -o -name "venv" -o -name ".env" 2>/dev/null | while read VENV; do
    if [ -d "$VENV" ]; then
        VENV_AGE=$(stat -c %Y "$VENV")
        NOW=$(date +%s)
        DAYS_OLD=$(( (NOW - VENV_AGE) / 86400 ))
        if [ $DAYS_OLD -gt 90 ]; then
            echo "⚠️  Stale venv (${DAYS_OLD} days old): $VENV"
        fi
    fi
done

# 2. Backup and temporary files
find . -name "*.bak" -o -name "*.old" -o -name "*.orig" -o -name "*~" -o -name "*.swp" 2>/dev/null | head -10

# 3. Deprecated markers in code
grep -rn "@deprecated\|DEPRECATED\|TODO.*remove\|FIXME.*deprecated" --include="*.py" --include="*.js" --include="*.ts" . 2>/dev/null | head -10

# 4. Unused imports (Python)
if command -v ruff &>/dev/null; then
    ruff check . --select F401 2>/dev/null | head -10
fi

# 5. Outdated dependencies
if [ -f requirements.txt ]; then
    pip list --outdated 2>/dev/null | head -10
fi
if [ -f package.json ]; then
    npm outdated 2>/dev/null | head -10
fi

# 6. Dead symlinks
find . -type l ! -exec test -e {} \; -print 2>/dev/null | head -10

# 7. Orphaned config files
for CONFIG in .env.backup config.old settings.bak; do
    [ -f "$CONFIG" ] && echo "⚠️  Orphaned config: $CONFIG"
done

# 8. Empty directories (often remnants of deleted features)
find . -type d -empty 2>/dev/null | grep -v ".git" | head -10

echo "✅ Pristine check complete"
```

### Python-Specific Pristine Requirements

```bash
# Check Python environment health
echo "🐍 Python Environment Audit..."

# 1. Check for requirements.txt vs installed packages mismatch
if [ -f requirements.txt ]; then
    echo "Checking installed vs required packages..."
    pip freeze > /tmp/installed.txt 2>/dev/null
    # Compare and report differences
fi

# 2. Check for outdated packages with known vulnerabilities
if command -v pip-audit &>/dev/null; then
    pip-audit 2>/dev/null | head -20
elif command -v safety &>/dev/null; then
    safety check 2>/dev/null | head -20
fi

# 3. Check for unused packages
if command -v pip-autoremove &>/dev/null; then
    pip-autoremove --list 2>/dev/null | head -10
fi

# 4. Verify virtual environment is current
if [ -n "$VIRTUAL_ENV" ]; then
    PYTHON_VERSION=$(python --version 2>&1)
    echo "Active venv: $VIRTUAL_ENV"
    echo "Python version: $PYTHON_VERSION"

    # Check if venv matches project's python-version file
    if [ -f .python-version ]; then
        EXPECTED=$(cat .python-version)
        if [[ "$PYTHON_VERSION" != *"$EXPECTED"* ]]; then
            echo "⚠️  Python version mismatch: expected $EXPECTED, got $PYTHON_VERSION"
        fi
    fi
fi
```

## Human-Readable Output Formatting

**All output MUST be clear, scannable, and visually organized.**

### Phase Headers

```
═══════════════════════════════════════════════════════════════════════════════
  📋 PHASE 4: DEPRECATION CLEANUP
  Keeping your project pristine by removing dead code and stale files
═══════════════════════════════════════════════════════════════════════════════
```

### Step Headers

```
───────────────────────────────────────────────────────────────────────────────
  Step 5: Deployment Version Mismatch Detection
───────────────────────────────────────────────────────────────────────────────
```

### Status Indicators

| Status | Emoji | Usage |
|--------|-------|-------|
| Success | ✅ | Test passed, check completed successfully |
| Failure | ❌ | Test failed, critical issue found |
| Warning | ⚠️ | Non-critical issue, needs attention |
| Info | ℹ️ | Informational message |
| In Progress | 🔄 | Currently running |
| Skipped | ⏭️ | Intentionally skipped |
| Fixed | 🔧 | Issue was automatically fixed |
| Manual | 👤 | Requires manual intervention |

### Progress Tracking

```
[████████████████████░░░░░░░░░░░░░░░░░░░░] 42% - Phase 6 of 13
```

### Summary Tables

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         PHASE 4 SUMMARY                                     │
├─────────────────┬───────────┬───────────┬───────────────────────────────────┤
│ Check           │ Status    │ Count     │ Details                           │
├─────────────────┼───────────┼───────────┼───────────────────────────────────┤
│ Dead code       │ ✅ Clean  │ 0         │ No unused code found              │
│ Stale files     │ ⚠️ Found  │ 3         │ .bak files in scripts/            │
│ Version mismatch│ ❌ ALERT  │ 1         │ <script-name>                     │
│ Broken symlinks │ ✅ Clean  │ 0         │ All symlinks valid                │
└─────────────────┴───────────┴───────────┴───────────────────────────────────┘
```

### Issue Reporting

```
❌ CRITICAL ISSUE FOUND
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Type:     Version Mismatch
  Location: /usr/local/bin/<script-name>

  Problem:
    Symlink points to: /old/path/<script-name>
    But canonical is:  ${PROJECT_DIR}/scripts/<script-name>

  Evidence:
    - Source file: XX lines (modified YYYY-MM-DD)
    - Installed:   YY lines (modified YYYY-MM-DD)
    - Content differs: [description of difference]

  Impact:
    [Description of impact if stale version is used]

  Recommended Fix:
    sudo rm /usr/local/bin/<script-name>
    sudo ln -s ${PROJECT_DIR}/scripts/<script-name> /usr/local/bin/<script-name>

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Project Configuration Loading

**CRITICAL**: Before starting the audit, load project-specific configuration from `.claude-test.yaml` if present.

### Config File Detection

```bash
# Look for project config file
PROJECT_DIR="$(pwd)"
PROJECT_NAME="$(basename "$PROJECT_DIR")"
CONFIG_FILE=""

# Check for config file in order of preference
for cfg in ".claude-test.yaml" ".claude-test.yml" "claude-test.yaml"; do
    if [ -f "$PROJECT_DIR/$cfg" ]; then
        CONFIG_FILE="$PROJECT_DIR/$cfg"
        echo "✅ Found project config: $CONFIG_FILE"
        break
    fi
done

if [ -z "$CONFIG_FILE" ]; then
    echo "ℹ️  No .claude-test.yaml found - using defaults"
    echo "   Create one from template: ~/.claude/templates/claude-test.yaml.template"
fi
```

### Config Variable Resolution

When a `.claude-test.yaml` is found, parse it and resolve variables:

```bash
# Resolve standard variables in config values:
# ${PROJECT_NAME} -> basename of project directory
# ${PROJECT_DIR}  -> full path to project directory
# ${TIMESTAMP}    -> current YYYYMMDD-HHMMSS
# ${USER}         -> current system user

resolve_config_vars() {
    local value="$1"
    value="${value//\$\{PROJECT_NAME\}/$PROJECT_NAME}"
    value="${value//\$\{PROJECT_DIR\}/$PROJECT_DIR}"
    value="${value//\$\{TIMESTAMP\}/$(date +%Y%m%d-%H%M%S)}"
    value="${value//\$\{USER\}/$USER}"
    echo "$value"
}

# Load key config values (if using yq or python-yaml)
if command -v yq &>/dev/null && [ -n "$CONFIG_FILE" ]; then
    COVERAGE_MIN=$(yq '.coverage.minimum // 85' "$CONFIG_FILE")
    MOCKING_ENABLED=$(yq '.mocking.enabled // true' "$CONFIG_FILE")
    SANDBOX_DIR=$(resolve_config_vars "$(yq '.mocking.sandbox_dir // "/tmp/claude-test-sandbox-'$PROJECT_NAME'"' "$CONFIG_FILE")")
    CLEANUP_AFTER=$(yq '.cleanup.after_test // true' "$CONFIG_FILE")
else
    # Defaults when no config or parser available
    COVERAGE_MIN=85
    MOCKING_ENABLED=true
    SANDBOX_DIR="/tmp/claude-test-sandbox-$PROJECT_NAME"
    CLEANUP_AFTER=true
fi

echo "Config loaded:"
echo "  Coverage minimum: ${COVERAGE_MIN}%"
echo "  Mocking enabled:  $MOCKING_ENABLED"
echo "  Sandbox dir:      $SANDBOX_DIR"
echo "  Cleanup after:    $CLEANUP_AFTER"
```

## Current Project Context

- Project directory: !`pwd`
- Project type: !`[ -f package.json ] && echo "Node.js" || ([ -f requirements.txt ] && echo "Python" || ([ -f Cargo.toml ] && echo "Rust" || ([ -f go.mod ] && echo "Go" || ([ -f Makefile ] && echo "Makefile" || echo "Unknown"))))`
- Has tests directory: !`[ -d tests ] || [ -d test ] || [ -d __tests__ ] || [ -d spec ] && echo "Yes" || echo "No"`
- Has CI config: !`[ -d .github/workflows ] || [ -f .gitlab-ci.yml ] || [ -f Jenkinsfile ] && echo "Yes" || echo "No"`
- Has .claude-test.yaml: !`[ -f .claude-test.yaml ] && echo "Yes" || echo "No"`
- Recent log files: !`find . -name "*.log" -mmin -60 2>/dev/null | head -5 || echo "None found"`

## Test Arguments

User provided: `$ARGUMENTS`

- If a specific component is named, focus testing on that component
- If `--verbose` is passed, show detailed output for each step

## MANDATORY Testing Protocol

**You MUST follow this exact protocol. Do NOT skip steps or just check status.**

### Phase S: BTRFS Safety Snapshot (Pre-Step)

**CRITICAL**: Before ANY modifications, create BTRFS snapshots of all affected volumes and subvolumes for instant rollback capability.

#### Step 1: Identify BTRFS Filesystems and Subvolumes

```bash
# Check if project directory is on BTRFS
PROJECT_DIR="$(pwd)"
PROJECT_FS_TYPE=$(df -T "$PROJECT_DIR" | awk 'NR==2 {print $2}')

if [ "$PROJECT_FS_TYPE" != "btrfs" ]; then
    echo "WARNING: Project is not on BTRFS filesystem. Skipping snapshot."
    echo "Filesystem type: $PROJECT_FS_TYPE"
    # Continue without snapshots, but warn user
else
    echo "✅ Project is on BTRFS filesystem"
fi

# Find the mount point and subvolume for the project directory
findmnt -n -o SOURCE,TARGET,FSTYPE "$PROJECT_DIR"

# List all subvolumes that might be affected
sudo btrfs subvolume list -p "$(df --output=target "$PROJECT_DIR" | tail -1)" | head -20
```

#### Step 2: Determine Affected Paths

```bash
# Paths that will be modified during this audit:
AFFECTED_PATHS=(
    "$PROJECT_DIR"                          # Project source code
    "$PROJECT_DIR/node_modules"             # Node.js dependencies (if exists)
    "$PROJECT_DIR/.venv"                    # Python virtual env (if exists)
    "$PROJECT_DIR/target"                   # Rust build artifacts (if exists)
    "$PROJECT_DIR/dist"                     # Build output (if exists)
    "$PROJECT_DIR/logs"                     # Log files (if exists)
)

# Find which subvolumes contain these paths
for path in "${AFFECTED_PATHS[@]}"; do
    if [ -e "$path" ]; then
        echo "Affected: $path"
        # Get the subvolume ID
        sudo btrfs subvolume show "$path" 2>/dev/null || echo "  (not a subvolume, parent will be snapshotted)"
    fi
done
```

#### Step 3: Create Snapshot Directory

```bash
# Snapshot naming convention:
# audit-YYYYMMDD-HHMMSS-<project-name>-<subvolume-name>
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
PROJECT_NAME=$(basename "$PROJECT_DIR")
SNAPSHOT_BASE="/snapshots/audit"  # Or your preferred snapshot location

# Create snapshot directory if it doesn't exist
sudo mkdir -p "$SNAPSHOT_BASE"
```

#### Step 4: Create Read-Only Snapshots

```bash
# For each affected subvolume, create a read-only snapshot
# The description should be human-readable and include:
# - Timestamp
# - Project name
# - Phase about to run
# - Reason for snapshot

SNAPSHOT_DESC="Pre-audit safety snapshot for $PROJECT_NAME - $(date '+%Y-%m-%d %H:%M:%S')"

# Example snapshot commands (adjust paths based on your setup):

# Snapshot the project subvolume
SNAPSHOT_NAME="audit-${TIMESTAMP}-${PROJECT_NAME}"
sudo btrfs subvolume snapshot -r "$PROJECT_DIR" "$SNAPSHOT_BASE/$SNAPSHOT_NAME"

# Add a description file for human readability
cat > "$SNAPSHOT_BASE/$SNAPSHOT_NAME.info" << EOF
Snapshot: $SNAPSHOT_NAME
Created: $(date '+%Y-%m-%d %H:%M:%S %Z')
Project: $PROJECT_NAME
Source: $PROJECT_DIR
Type: Pre-audit safety snapshot
Reason: Comprehensive autonomous project audit (15 phases)

Phases that may modify files:
- Phase 4: Deprecation Cleanup (removes dead code)
- Phase 5: Security Audit (may remove secrets from code)
- Phase 6: Dependency Health (updates packages)
- Phase 7: Code Quality (auto-fixes linting)
- Phase 10: Auto-Fixing (applies bug fixes)
- Phase 11: Configuration (may update configs)
- Phase 13: Documentation (updates docs - FINAL phase, after all fixes)

Rollback command:
  sudo btrfs subvolume delete "$PROJECT_DIR"
  sudo btrfs subvolume snapshot "$SNAPSHOT_BASE/$SNAPSHOT_NAME" "$PROJECT_DIR"

Cleanup command (after successful audit):
  sudo btrfs subvolume delete "$SNAPSHOT_BASE/$SNAPSHOT_NAME"
  rm "$SNAPSHOT_BASE/$SNAPSHOT_NAME.info"
EOF

echo "✅ Snapshot created: $SNAPSHOT_BASE/$SNAPSHOT_NAME"
echo "📄 Info file: $SNAPSHOT_BASE/$SNAPSHOT_NAME.info"
```

#### Step 5: Snapshot Additional Subvolumes (if needed)

```bash
# If project spans multiple subvolumes, snapshot each one
# Common scenarios:
# - Separate subvolume for node_modules (performance optimization)
# - Separate subvolume for build artifacts
# - Separate subvolume for logs

# Check for nested subvolumes
NESTED_SUBVOLS=$(sudo btrfs subvolume list -o "$PROJECT_DIR" 2>/dev/null)

if [ -n "$NESTED_SUBVOLS" ]; then
    echo "Found nested subvolumes:"
    echo "$NESTED_SUBVOLS"

    # Snapshot each nested subvolume
    while IFS= read -r line; do
        SUBVOL_PATH=$(echo "$line" | awk '{print $NF}')
        SUBVOL_NAME=$(basename "$SUBVOL_PATH")
        NESTED_SNAPSHOT="${SNAPSHOT_BASE}/audit-${TIMESTAMP}-${PROJECT_NAME}-${SUBVOL_NAME}"

        sudo btrfs subvolume snapshot -r "$SUBVOL_PATH" "$NESTED_SNAPSHOT"
        echo "✅ Nested snapshot: $NESTED_SNAPSHOT"
    done <<< "$NESTED_SUBVOLS"
fi
```

#### Step 6: Verify Snapshots

```bash
# List all snapshots just created
echo "=== Snapshots Created for This Audit ==="
sudo btrfs subvolume list -s "$SNAPSHOT_BASE" | grep "$TIMESTAMP"

# Verify snapshot integrity
for snap in "$SNAPSHOT_BASE"/audit-${TIMESTAMP}-*; do
    if [ -d "$snap" ]; then
        # Check snapshot is read-only
        RO_STATUS=$(sudo btrfs property get "$snap" ro 2>/dev/null | grep -o "true\|false")
        if [ "$RO_STATUS" = "true" ]; then
            echo "✅ $snap (read-only: verified)"
        else
            echo "⚠️ $snap (WARNING: not read-only)"
        fi
    fi
done
```

#### Snapshot Report

```markdown
## BTRFS Snapshot Report

### Snapshots Created
| Snapshot Name | Source Path | Size | Read-Only | Info File |
|---------------|-------------|------|-----------|-----------|
| audit-YYYYMMDD-HHMMSS-project | /path/to/project | [size] | ✅ | ✅ |
| audit-YYYYMMDD-HHMMSS-project-node_modules | /path/to/node_modules | [size] | ✅ | ✅ |

### Snapshot Location
- Base path: /snapshots/audit/
- Total snapshots: X
- Total size: [size]

### Rollback Instructions
If issues occur during audit, rollback with:
```bash
# Stop any running processes in the project
# Delete the modified subvolume
sudo btrfs subvolume delete /path/to/project
# Restore from snapshot
sudo btrfs subvolume snapshot /snapshots/audit/audit-YYYYMMDD-HHMMSS-project /path/to/project
```

### Cleanup Instructions
After successful audit completion:
```bash
# Remove audit snapshots
sudo btrfs subvolume delete /snapshots/audit/audit-YYYYMMDD-HHMMSS-*
rm /snapshots/audit/audit-YYYYMMDD-HHMMSS-*.info
```

### Snapshot Status: ✅ READY / ❌ FAILED (do not proceed)
```

**CRITICAL**: If snapshot creation fails, **DO NOT PROCEED** with the audit. Fix snapshot issues first or use `--skip-snapshot` flag only if you accept the risk of no rollback capability.

---

### Phase M: Safe Mocking Environment Setup

**CRITICAL**: Set up safe mocking environment BEFORE running any tests that might execute dangerous operations.

This phase creates an isolated sandbox environment and mocks dangerous commands to prevent accidental data loss, unauthorized network access, or service disruption during testing.

#### When to Enable Mocking

Mocking is enabled when:
1. `MOCKING_ENABLED=true` (from `.claude-test.yaml` or default)
2. Running in CI/CD environment
3. Testing code that contains potentially dangerous operations

#### Step 1: Create Sandbox Environment

```bash
# Create isolated sandbox directory
setup_sandbox() {
    SANDBOX_DIR="${SANDBOX_DIR:-/tmp/claude-test-sandbox-$PROJECT_NAME}"
    ORIGINAL_PATH="$PATH"

    echo "═══════════════════════════════════════════════════════════════════"
    echo "  PHASE M: SAFE MOCKING ENVIRONMENT SETUP"
    echo "═══════════════════════════════════════════════════════════════════"

    if [ "$MOCKING_ENABLED" != "true" ]; then
        echo "⏭️  Mocking disabled - skipping sandbox setup"
        return 0
    fi

    mkdir -p "$SANDBOX_DIR"/{bin,tmp,mock-data,logs}
    chmod 755 "$SANDBOX_DIR"
    chmod 777 "$SANDBOX_DIR/tmp"

    echo "✅ Sandbox created: $SANDBOX_DIR"
}
```

#### Step 2: Create Mock Command Wrappers

```bash
# Create safe wrappers for dangerous commands
create_mock_commands() {
    # Mock rm - only allow deletion within sandbox
    cat > "$SANDBOX_DIR/bin/rm" << 'MOCK_RM'
#!/bin/bash
SANDBOX_DIR="${SANDBOX_DIR:-/tmp/claude-test-sandbox}"
LOG_FILE="$SANDBOX_DIR/logs/mock-commands.log"

echo "[MOCK rm] $(date '+%Y-%m-%d %H:%M:%S') rm $@" >> "$LOG_FILE"

# Parse arguments to find paths
for arg in "$@"; do
    [[ "$arg" == -* ]] && continue

    # Only allow deletion within sandbox or temp directories
    REAL_PATH=$(realpath "$arg" 2>/dev/null || echo "$arg")
    if [[ "$REAL_PATH" == "$SANDBOX_DIR"* ]] || [[ "$REAL_PATH" == /tmp/claude-test-* ]]; then
        /bin/rm "$@"
        exit $?
    else
        echo "[MOCK] Blocked: rm $arg (outside sandbox)" | tee -a "$LOG_FILE"
        exit 0
    fi
done
MOCK_RM
    chmod +x "$SANDBOX_DIR/bin/rm"

    # Mock sudo - run without privileges, log the attempt
    cat > "$SANDBOX_DIR/bin/sudo" << 'MOCK_SUDO'
#!/bin/bash
SANDBOX_DIR="${SANDBOX_DIR:-/tmp/claude-test-sandbox}"
LOG_FILE="$SANDBOX_DIR/logs/mock-commands.log"

echo "[MOCK sudo] $(date '+%Y-%m-%d %H:%M:%S') sudo $@" >> "$LOG_FILE"
echo "[MOCK] Would run as root: $@"

# Try to run without sudo (may fail, that's expected)
"$@" 2>/dev/null
exit 0
MOCK_SUDO
    chmod +x "$SANDBOX_DIR/bin/sudo"

    # Mock systemctl - simulate service operations
    cat > "$SANDBOX_DIR/bin/systemctl" << 'MOCK_SYSTEMCTL'
#!/bin/bash
SANDBOX_DIR="${SANDBOX_DIR:-/tmp/claude-test-sandbox}"
LOG_FILE="$SANDBOX_DIR/logs/mock-commands.log"

echo "[MOCK systemctl] $(date '+%Y-%m-%d %H:%M:%S') systemctl $@" >> "$LOG_FILE"

case "$1" in
    status)
        echo "● mock-$2.service - Mock Service (SANDBOX MODE)"
        echo "     Loaded: loaded (mock)"
        echo "     Active: active (running) [MOCKED]"
        ;;
    start|stop|restart|reload)
        echo "[MOCK] Would $1 service: $2"
        ;;
    daemon-reload)
        echo "[MOCK] Would reload systemd daemon"
        ;;
    *)
        echo "[MOCK] systemctl $@"
        ;;
esac
exit 0
MOCK_SYSTEMCTL
    chmod +x "$SANDBOX_DIR/bin/systemctl"

    # Mock dangerous network commands
    for cmd in curl wget; do
        cat > "$SANDBOX_DIR/bin/$cmd" << MOCK_NET
#!/bin/bash
SANDBOX_DIR="\${SANDBOX_DIR:-/tmp/claude-test-sandbox}"
LOG_FILE="\$SANDBOX_DIR/logs/mock-commands.log"

echo "[MOCK $cmd] \$(date '+%Y-%m-%d %H:%M:%S') $cmd \$@" >> "\$LOG_FILE"

# Allow localhost connections, mock external
for arg in "\$@"; do
    if [[ "\$arg" == *"localhost"* ]] || [[ "\$arg" == *"127.0.0.1"* ]] || [[ "\$arg" == *"::1"* ]]; then
        /usr/bin/$cmd "\$@"
        exit \$?
    fi
done

echo "[MOCK] Would make network request: $cmd \$@"
echo '{"status": "mocked", "message": "External network call blocked in sandbox"}'
exit 0
MOCK_NET
        chmod +x "$SANDBOX_DIR/bin/$cmd"
    done

    echo "✅ Mock commands created in $SANDBOX_DIR/bin/"
}
```

#### Step 3: Activate Sandbox

```bash
# Add mock commands to PATH (first, so they override real commands)
activate_sandbox() {
    export PATH="$SANDBOX_DIR/bin:$PATH"
    export SANDBOX_ACTIVE=true
    export MOCK_LOG="$SANDBOX_DIR/logs/mock-commands.log"

    echo "✅ Sandbox activated - dangerous commands will be mocked"
    echo "   Mock log: $MOCK_LOG"
}
```

#### Step 4: Create Mock Test Data

```bash
# Create mock data for tests that need sample files
create_mock_data() {
    MOCK_DATA_DIR="$SANDBOX_DIR/mock-data"

    # Create sample files for different test scenarios
    echo "Sample text content for testing" > "$MOCK_DATA_DIR/sample.txt"
    echo '{"test": true, "data": [1,2,3]}' > "$MOCK_DATA_DIR/sample.json"
    echo "key: value" > "$MOCK_DATA_DIR/sample.yaml"

    # Create mock API responses
    mkdir -p "$MOCK_DATA_DIR/api-responses"
    echo '{"status": "ok", "mocked": true}' > "$MOCK_DATA_DIR/api-responses/health.json"
    echo '{"users": [{"id": 1, "name": "Test User"}]}' > "$MOCK_DATA_DIR/api-responses/users.json"

    echo "✅ Mock data created in $MOCK_DATA_DIR/"
}
```

#### Step 5: Mocking Status Report

```markdown
## Safe Mocking Environment Report

### Sandbox Status
| Component | Status | Location |
|-----------|--------|----------|
| Sandbox directory | ✅ Created | $SANDBOX_DIR |
| Mock commands | ✅ Installed | $SANDBOX_DIR/bin/ |
| Mock data | ✅ Created | $SANDBOX_DIR/mock-data/ |
| PATH updated | ✅ Active | Mock commands take priority |

### Mocked Commands
| Command | Behavior |
|---------|----------|
| `rm` | Only allows deletion within sandbox |
| `sudo` | Runs without privileges, logs attempt |
| `systemctl` | Simulates service operations |
| `curl`/`wget` | Allows localhost, blocks external |

### Mock Log
All mocked command invocations are logged to:
`$SANDBOX_DIR/logs/mock-commands.log`

### Mocking Status: ✅ ACTIVE / ⏭️ SKIPPED
```

**NOTE**: Mocking will be deactivated in Phase C (Cleanup) after all tests complete.

---

### Phase 0: Pre-Flight Environment Validation

Before running ANY tests, validate the environment is ready. Fail fast on environment issues.

#### Step 1: Dependency Verification
```bash
# Check package manager and dependencies by project type
# Python
[ -f requirements.txt ] && pip check && pip freeze | diff - requirements.txt
[ -f pyproject.toml ] && poetry check

# Node.js
[ -f package.json ] && npm ls --depth=0 2>&1 | grep -E "WARN|ERR" || echo "OK"

# Go
[ -f go.mod ] && go mod verify

# Rust
[ -f Cargo.toml ] && cargo verify-project
```

#### Step 2: Environment Variables
```
❌ WRONG: Assuming .env is loaded
✅ RIGHT: Explicitly check all required env vars exist and are non-empty
```

You MUST:
- Find all referenced environment variables in code (grep for `os.environ`, `process.env`, `os.Getenv`, etc.)
- Check each required variable exists: `[ -n "$VAR_NAME" ] || echo "Missing: VAR_NAME"`
- Validate format where applicable (URLs, API keys, paths)
- Check .env.example vs actual .env for missing variables

#### Step 3: Service Connectivity
```bash
# Check required services are accessible
# Database
pg_isready -h localhost -p 5432 || echo "PostgreSQL not available"
redis-cli ping || echo "Redis not available"

# External APIs (with timeout)
curl -sf --max-time 5 https://api.example.com/health || echo "API unreachable"
```

#### Step 4: File System Permissions
```bash
# Verify required directories exist and are writable
for dir in logs/ data/ tmp/ uploads/; do
  [ -d "$dir" ] && [ -w "$dir" ] || echo "Directory issue: $dir"
done

# Check config files are readable
for cfg in config.yaml .env settings.json; do
  [ -f "$cfg" ] && [ -r "$cfg" ] || echo "Config not readable: $cfg"
done
```

#### Step 5: Resource Availability
```bash
# Disk space (warn if <1GB free)
df -h . | awk 'NR==2 {if ($4 ~ /M/ && int($4) < 1000) print "Low disk space: "$4}'

# Check port availability if service needs to bind
lsof -i :8080 && echo "Port 8080 already in use"
```

#### Step 6: Service User Permission Validation
**CRITICAL**: This step catches permission bugs that cause cascading service failures. DO NOT SKIP.

```bash
# Find all systemd services related to this project
PROJECT_NAME=$(basename "$(pwd)")
PROJECT_SERVICES=$(systemctl list-units --type=service --all | grep -i "$PROJECT_NAME" | awk '{print $1}')

if [ -n "$PROJECT_SERVICES" ]; then
    echo "=== Service User Permission Audit ==="

    for SERVICE in $PROJECT_SERVICES; do
        # Get the service user
        SERVICE_USER=$(systemctl show "$SERVICE" --property=User --value 2>/dev/null)
        [ -z "$SERVICE_USER" ] && SERVICE_USER="root"

        echo "Service: $SERVICE (runs as: $SERVICE_USER)"

        # Get the working directory
        WORK_DIR=$(systemctl show "$SERVICE" --property=WorkingDirectory --value 2>/dev/null)
        [ -z "$WORK_DIR" ] && WORK_DIR="$(pwd)"

        # Get all paths the service might write to
        # Check ExecStart for output directories, log paths, etc.
        EXEC_CMD=$(systemctl show "$SERVICE" --property=ExecStart --value 2>/dev/null)

        # Common write locations to check
        WRITE_PATHS=(
            "$WORK_DIR"
            "/tmp/${PROJECT_NAME}*"
            "/var/log/${PROJECT_NAME}*"
            "$(pwd)/logs"
            "$(pwd)/data"
            "$(pwd)/output"
        )

        for WRITE_PATH in "${WRITE_PATHS[@]}"; do
            # Resolve wildcards
            for RESOLVED_PATH in $WRITE_PATH; do
                if [ -e "$RESOLVED_PATH" ]; then
                    # Check if service user can write
                    if sudo -u "$SERVICE_USER" test -w "$RESOLVED_PATH" 2>/dev/null; then
                        echo "  ✅ $SERVICE_USER CAN write to: $RESOLVED_PATH"
                    else
                        echo "  ❌ $SERVICE_USER CANNOT write to: $RESOLVED_PATH"
                        echo "     FIX: sudo chown -R $SERVICE_USER:$SERVICE_USER $RESOLVED_PATH"
                        echo "     OR:  sudo chmod 775 $RESOLVED_PATH && sudo usermod -aG \$(stat -c '%G' $RESOLVED_PATH) $SERVICE_USER"
                    fi
                fi
            done
        done

        # Check group memberships
        echo "  Groups: $(id -Gn "$SERVICE_USER" 2>/dev/null || echo 'unknown')"
        echo ""
    done
fi
```

```
❌ WRONG: Assuming service user has write permissions to all directories
✅ RIGHT: Explicitly verify service user can write to EVERY output directory
```

You MUST check:
- Service user (from `systemctl show <service> --property=User`)
- All directories the service writes to (output, logs, staging, cache)
- Group memberships needed for shared access
- tmpfs/ramdisk directories that may reset on reboot
- Cross-service dependencies (if Service A writes, can Service B read?)

Common permission bug patterns:
1. Directory owned by interactive user but service runs as system user (check .claude-test.yaml service.user)
2. Directory mode 755 (owner-write-only) when group-write needed
3. Missing group membership for shared directories
4. tmpfs permissions reset after reboot

#### Pre-Flight Report
```markdown
## Pre-Flight Check Results

| Check | Status | Details |
|-------|--------|---------|
| Dependencies | ✅/❌ | [version mismatches, missing packages] |
| Environment Variables | ✅/❌ | [missing: VAR1, VAR2] |
| Service Connectivity | ✅/❌ | [database: ok, redis: failed] |
| File Permissions | ✅/❌ | [logs/ not writable] |
| Resources | ✅/❌ | [disk: 50GB free, ports: clear] |

**Pre-Flight Status**: ✅ READY / ❌ BLOCKED (fix issues before proceeding)
```

**CRITICAL**: If pre-flight fails, STOP and fix environment issues before proceeding to Phase 1.

### Phase 1: Discovery (What to Test)

1. **Identify ALL testable components** in this project:
   - Entry points (main scripts, CLI commands, API servers)
   - Core modules/functions with business logic
   - External integrations (APIs, databases, file systems)
   - Scheduled tasks/cron jobs/workers
   - Build/compile processes

2. **Find test infrastructure**:
   - Test frameworks (pytest, jest, cargo test, go test, etc.)
   - Test configuration files
   - Mock/fixture data
   - Test databases or test environments

3. **Locate logging**:
   - Log file paths (check common locations: logs/, /var/log/, ~/.local/share/)
   - Logging configuration
   - Systemd journal entries if applicable: `journalctl -u SERVICE_NAME --since "1 hour ago"`

### Phase 2: Execute Tests (Run ACTUAL Operations)

For EACH identified component, you MUST:

#### Step 1: Run Actual Operations
```
❌ WRONG: Just checking if the service is running
✅ RIGHT: Actually trigger the operation and observe behavior
```

Examples by project type:
- **API**: Make actual HTTP requests with curl/httpie, not just health checks
- **CLI tool**: Run real commands with real inputs
- **Script**: Execute with test data, not just `--help`
- **Processor**: Feed actual test files through the pipeline
- **Worker**: Trigger a job and watch it complete

#### Step 2: Verify Output EXISTS and is CORRECT
```
❌ WRONG: "The command completed without errors"
✅ RIGHT: "The output file /path/to/output.json contains 47 records with valid schema"
```

You MUST:
- Check that output files were created
- Verify file contents are valid (parse JSON/YAML, check expected fields)
- Compare against expected values if available
- Check database records were created/modified
- Verify API responses contain expected data

#### Step 3: Check Logs for ANY Errors
```
❌ WRONG: Ignoring logs
✅ RIGHT: grep -i "error\|warn\|fail\|exception" across ALL log files
```

You MUST:
- Search ALL relevant log files for errors, warnings, failures
- Check systemd journal if services are involved
- Review stderr output from commands
- Look for stack traces or unexpected messages

#### Step 4: Test the ENTIRE Pipeline
```
❌ WRONG: Testing components in isolation only
✅ RIGHT: Feed input through START to FINISH and verify final output
```

Example full pipeline test:
1. Create test input data
2. Run the first processing step
3. Verify intermediate output
4. Run subsequent steps
5. Verify final output
6. Check all logs generated along the way
7. Clean up test artifacts

### Phase 2a: Runtime Service Health (CRITICAL - DO NOT SKIP)

**This phase catches bugs where services appear "running" but are NOT doing actual work.** Examples:
- ffmpeg not starting because of missing `-y` flag (prompts for input in non-interactive mode)
- Workers stuck in retry loops instead of processing
- Services waiting on failed dependencies
- Processes cycling through skip logic instead of executing

#### Step 1: Identify Running Services
```bash
PROJECT_NAME=$(basename "$(pwd)")
PROJECT_SERVICES=$(systemctl list-units --type=service --state=running | grep -i "$PROJECT_NAME" | awk '{print $1}')

if [ -z "$PROJECT_SERVICES" ]; then
    echo "No running services found for project: $PROJECT_NAME"
else
    echo "=== Runtime Service Health Audit ==="
    echo "Found services: $PROJECT_SERVICES"
fi
```

#### Step 2: Process Activity Monitoring (Detect Stuck Processes)

**CRITICAL**: A service can be "running" but have workers stuck in sleep loops. This step detects that pattern.

```bash
for SERVICE in $PROJECT_SERVICES; do
    echo ""
    echo "=== Analyzing: $SERVICE ==="

    # Get process tree
    MAIN_PID=$(systemctl show "$SERVICE" --property=MainPID --value)
    if [ "$MAIN_PID" -gt 0 ]; then
        echo "Main PID: $MAIN_PID"

        # Check what child processes are doing
        echo "Child process states:"
        ps --ppid "$MAIN_PID" -o pid,stat,wchan,comm,args --forest 2>/dev/null | head -30

        # Count processes by state
        echo ""
        echo "Process state summary:"
        ps --ppid "$MAIN_PID" -o stat 2>/dev/null | tail -n +2 | sort | uniq -c

        # CRITICAL: Check for stuck sleep loops
        SLEEP_COUNT=$(ps --ppid "$MAIN_PID" -o comm 2>/dev/null | grep -c "sleep")
        TOTAL_CHILDREN=$(ps --ppid "$MAIN_PID" 2>/dev/null | tail -n +2 | wc -l)

        if [ "$TOTAL_CHILDREN" -gt 0 ]; then
            SLEEP_RATIO=$((SLEEP_COUNT * 100 / TOTAL_CHILDREN))
            if [ "$SLEEP_RATIO" -gt 50 ]; then
                echo ""
                echo "⚠️ WARNING: $SLEEP_RATIO% of child processes are sleeping!"
                echo "   This may indicate workers stuck in retry/skip loops"
                echo "   Expected: Active workers (ffmpeg, python, node, etc.)"
                echo "   Found: Mostly sleep processes"
                echo ""
                echo "   DIAGNOSE: Check service logs for skip/retry messages"
                echo "   journalctl -u $SERVICE --since '5 minutes ago' | grep -i 'skip\|retry\|wait\|error'"
            fi
        fi

        # Check for expected worker processes
        echo ""
        echo "Looking for active worker processes:"
        ps aux | grep -E "ffmpeg|python|node|ruby|java|cargo|go run" | grep -v grep | head -10 || echo "  No active workers found"
    fi
done
```

#### Step 3: Verify Actual Work is Happening

```bash
for SERVICE in $PROJECT_SERVICES; do
    echo ""
    echo "=== Work Verification: $SERVICE ==="

    # Check for output file creation in last 5 minutes
    # Adjust paths based on service type
    OUTPUT_DIRS=(
        "/tmp/${PROJECT_NAME}*"
        "$(pwd)/output"
        "$(pwd)/data"
        "/hddRaid1/${PROJECT_NAME}*/output"
        "/hddRaid1/${PROJECT_NAME}*/staging"
    )

    echo "Checking for recent output file creation..."
    RECENT_FILES_FOUND=0
    for OUTPUT_DIR in "${OUTPUT_DIRS[@]}"; do
        for RESOLVED_DIR in $OUTPUT_DIR; do
            if [ -d "$RESOLVED_DIR" ]; then
                RECENT=$(find "$RESOLVED_DIR" -type f -mmin -5 2>/dev/null | head -5)
                if [ -n "$RECENT" ]; then
                    echo "  ✅ Recent files in $RESOLVED_DIR:"
                    echo "$RECENT" | sed 's/^/     /'
                    RECENT_FILES_FOUND=1
                fi
            fi
        done
    done

    if [ "$RECENT_FILES_FOUND" -eq 0 ]; then
        echo "  ⚠️ No files created in last 5 minutes - service may be stuck"
    fi

    # Check CPU usage - workers should be using CPU
    echo ""
    echo "CPU usage by service processes:"
    MAIN_PID=$(systemctl show "$SERVICE" --property=MainPID --value)
    if [ "$MAIN_PID" -gt 0 ]; then
        ps --ppid "$MAIN_PID" -o pid,%cpu,%mem,comm --sort=-%cpu 2>/dev/null | head -10
    fi
done
```

#### Step 4: Non-Interactive Mode Compatibility Check

**CRITICAL**: Commands that prompt for user input WILL FAIL in service context.

```bash
echo "=== Non-Interactive Mode Audit ==="

# Common commands that need flags for non-interactive use
INTERACTIVE_PATTERNS=(
    "ffmpeg.*-i.*[^-]y"       # ffmpeg without -y (prompts for overwrite)
    "rm [^-]*-i"              # rm -i (prompts for confirmation)
    "cp [^-]*-i"              # cp -i (prompts for overwrite)
    "mv [^-]*-i"              # mv -i (prompts for overwrite)
    "apt.*install[^-]*-y"     # apt install without -y
    "yum.*install[^-]*-y"     # yum install without -y
    "pip install.*--no-input" # pip without --no-input when needed
    "read -p"                 # bash read with prompt
    "input\("                 # Python input() - blocks in non-interactive
    "readline\(\)"            # Node.js readline
)

# Search for potential interactive command issues
echo "Scanning for commands that may hang in non-interactive mode..."

for PATTERN in "${INTERACTIVE_PATTERNS[@]}"; do
    MATCHES=$(grep -rn "$PATTERN" --include="*.sh" --include="*.py" --include="*.js" . 2>/dev/null | head -5)
    if [ -n "$MATCHES" ]; then
        echo ""
        echo "⚠️ Potential interactive command found:"
        echo "$MATCHES"
    fi
done

# Specific check: ffmpeg without -y flag
FFMPEG_CMDS=$(grep -rn "ffmpeg" --include="*.sh" --include="*.py" . 2>/dev/null | grep -v "\-y" | head -10)
if [ -n "$FFMPEG_CMDS" ]; then
    echo ""
    echo "❌ CRITICAL: ffmpeg commands without -y flag (will prompt for overwrite):"
    echo "$FFMPEG_CMDS"
    echo ""
    echo "   FIX: Add -y flag to all ffmpeg commands for non-interactive use"
    echo "   Example: ffmpeg -y -i input.mp3 output.opus"
fi

# Check for stdin requirements in service commands
for SERVICE in $PROJECT_SERVICES; do
    EXEC_CMD=$(systemctl show "$SERVICE" --property=ExecStart --value 2>/dev/null)
    if echo "$EXEC_CMD" | grep -qE "read|input|prompt"; then
        echo ""
        echo "⚠️ Service $SERVICE may require stdin:"
        echo "   Command: $EXEC_CMD"
    fi
done
```

#### Step 5: Log Analysis for Stuck Patterns

```bash
echo ""
echo "=== Service Log Analysis (Last 10 Minutes) ==="

for SERVICE in $PROJECT_SERVICES; do
    echo ""
    echo "--- $SERVICE ---"

    # Check for common stuck patterns in logs
    echo "Checking for stuck/error patterns..."

    # Pattern 1: Repeated skip messages (indicates nothing being processed)
    SKIP_COUNT=$(journalctl -u "$SERVICE" --since "10 minutes ago" --no-pager 2>/dev/null | grep -ci "skip")
    if [ "$SKIP_COUNT" -gt 20 ]; then
        echo "  ⚠️ High skip count: $SKIP_COUNT (may indicate all items being skipped)"
    fi

    # Pattern 2: Overwrite prompts (ffmpeg, etc.)
    OVERWRITE_PROMPTS=$(journalctl -u "$SERVICE" --since "10 minutes ago" --no-pager 2>/dev/null | grep -i "overwrite\|already exists\|\[y/N\]")
    if [ -n "$OVERWRITE_PROMPTS" ]; then
        echo "  ❌ CRITICAL: Overwrite prompts detected (command waiting for input):"
        echo "$OVERWRITE_PROMPTS" | head -5 | sed 's/^/     /'
    fi

    # Pattern 3: Permission denied errors
    PERM_ERRORS=$(journalctl -u "$SERVICE" --since "10 minutes ago" --no-pager 2>/dev/null | grep -i "permission denied")
    if [ -n "$PERM_ERRORS" ]; then
        echo "  ❌ Permission denied errors:"
        echo "$PERM_ERRORS" | head -5 | sed 's/^/     /'
    fi

    # Pattern 4: Retry/retry loop patterns
    RETRY_COUNT=$(journalctl -u "$SERVICE" --since "10 minutes ago" --no-pager 2>/dev/null | grep -ci "retry\|retrying\|will retry")
    if [ "$RETRY_COUNT" -gt 10 ]; then
        echo "  ⚠️ High retry count: $RETRY_COUNT (may indicate persistent failure)"
    fi

    # Pattern 5: Failed status in logs
    FAIL_COUNT=$(journalctl -u "$SERVICE" --since "10 minutes ago" --no-pager 2>/dev/null | grep -ci "failed\|error\|exception")
    if [ "$FAIL_COUNT" -gt 0 ]; then
        echo "  ⚠️ Error count: $FAIL_COUNT"
        echo "  Recent errors:"
        journalctl -u "$SERVICE" --since "10 minutes ago" --no-pager 2>/dev/null | grep -i "failed\|error\|exception" | tail -5 | sed 's/^/     /'
    fi
done
```

#### Step 6: Cross-Service Dependency Health

```bash
echo ""
echo "=== Cross-Service Dependency Check ==="

# Check if output from one service is being consumed by another
# Example: converter produces files → mover consumes files

for SERVICE in $PROJECT_SERVICES; do
    echo ""
    echo "Service: $SERVICE"

    # Check for inter-service communication (files, sockets, pipes)
    MAIN_PID=$(systemctl show "$SERVICE" --property=MainPID --value)

    # File-based dependencies
    echo "  Checking file-based dependencies..."
    lsof -p "$MAIN_PID" 2>/dev/null | grep -E "REG|DIR" | awk '{print $9}' | sort -u | head -10

    # Socket-based dependencies
    echo "  Checking socket connections..."
    ss -tulpn 2>/dev/null | grep "$MAIN_PID" | head -5 || echo "    No network sockets"
done

# Check for orphaned files (created by one service, never processed by another)
echo ""
echo "Checking for orphaned staging files..."
STAGING_DIRS=(
    "/tmp/${PROJECT_NAME}*"
    "$(pwd)/staging"
    "$(pwd)/.tmp"
)

for STAGING_DIR in "${STAGING_DIRS[@]}"; do
    for RESOLVED_DIR in $STAGING_DIR; do
        if [ -d "$RESOLVED_DIR" ]; then
            OLD_FILES=$(find "$RESOLVED_DIR" -type f -mmin +30 2>/dev/null | wc -l)
            if [ "$OLD_FILES" -gt 0 ]; then
                echo "  ⚠️ $OLD_FILES files older than 30 minutes in $RESOLVED_DIR"
                echo "     This may indicate the consuming service is not processing files"
            fi
        fi
    done
done
```

#### Runtime Service Health Report

```markdown
## Runtime Service Health Report

### Service Process Status
| Service | Main PID | Child Processes | Sleep % | Active Workers | Status |
|---------|----------|-----------------|---------|----------------|--------|
| [name]  | [pid]    | [count]         | [%]     | [count]        | ✅/⚠️/❌ |

### Work Output Verification
| Service | Recent Files (5min) | CPU Usage | Status |
|---------|---------------------|-----------|--------|
| [name]  | [count]             | [%]       | ✅/⚠️/❌ |

### Non-Interactive Mode Issues
| File | Line | Command | Issue | Fix |
|------|------|---------|-------|-----|
| script.sh | 45 | ffmpeg -i ... | Missing -y flag | Add -y after ffmpeg |

### Stuck Pattern Detection
| Service | Skips | Retries | Errors | Overwrite Prompts | Status |
|---------|-------|---------|--------|-------------------|--------|
| [name]  | [cnt] | [cnt]   | [cnt]  | [cnt]             | ✅/⚠️/❌ |

### Cross-Service Dependencies
| Producer Service | Consumer Service | Interface | Orphaned Files | Status |
|------------------|------------------|-----------|----------------|--------|
| converter        | mover            | /tmp/staging | [count]     | ✅/⚠️/❌ |

### Critical Issues Found
- [ ] [Service] processes stuck in sleep loop (X% sleeping)
- [ ] [Service] ffmpeg commands missing -y flag
- [ ] [Service] permission denied writing to [path]
- [ ] [Service] overwrite prompts detected in logs

### Runtime Health Score: [0-100]
- Process Activity: X/25
- Output Generation: X/25
- Non-Interactive Compatibility: X/25
- Log Health: X/25

**Status**: ✅ HEALTHY / ⚠️ DEGRADED / ❌ FAILING
```

**CRITICAL**: If this phase finds issues:
1. **Stuck in sleep loops**: Check skip conditions in service code - something is causing all items to be skipped
2. **No active workers**: Service is running but subprocess spawning is failing
3. **Missing -y flag**: Add non-interactive flags to all commands that prompt
4. **Permission denied**: Fix ownership/permissions (see Phase 0 Step 6)
5. **Overwrite prompts**: Commands need non-interactive flags (-y, -f, --yes, etc.)

---

### Phase 3: Report Results

After testing each component, report:

```markdown
## Component: [NAME]

### Operations Performed
- [ ] What was actually executed (exact commands)

### Output Verification
- [ ] Output location: [path]
- [ ] Output exists: Yes/No
- [ ] Output valid: Yes/No (describe validation)
- [ ] Output content: [summary of what was produced]

### Log Analysis
- [ ] Log files checked: [list]
- [ ] Errors found: [count] - [details]
- [ ] Warnings found: [count] - [details]

### Pipeline Status
- [ ] Input → Output flow: Working/Broken at [step]
- [ ] Data integrity: Verified/Issues found

### Verdict: ✅ PASS / ⚠️ ISSUES / ❌ FAIL
```

### Phase 4: Deprecation Cleanup (Remove Dead Code)

After testing, identify and remove deprecated/dead components:

#### Step 1: Identify Deprecated Code
```
Search for deprecation markers:
- @deprecated annotations/decorators
- TODO: remove, FIXME: deprecated, DEPRECATED comments
- Unused imports/modules (no references anywhere)
- Dead code paths (unreachable functions, unused classes)
- Legacy compatibility shims no longer needed
- Old API versions superseded by new implementations
- Backup files (.bak, .old, .deprecated extensions)
```

#### Step 2: Verify Before Removal
```
❌ WRONG: Blindly deleting anything marked deprecated
✅ RIGHT: Verify no active code paths reference the deprecated component
```

You MUST:
- Use grep/ripgrep to find ALL references to the component
- Check import statements across the entire codebase
- Verify no configuration files reference it
- Confirm no tests depend on it (or update tests accordingly)
- Check for dynamic references (string-based imports, reflection)

#### Step 3: Remove Deprecated Components
For each confirmed deprecated item:
1. Remove the dead code/file
2. Remove any associated tests that only test the removed code
3. Remove references from configuration files
4. Clean up any orphaned imports
5. Remove from documentation (will be updated in Phase 13)

#### Step 4: Report Deprecation Cleanup
```markdown
## Deprecation Cleanup Report

### Items Removed
| Component | Type | Reason | Files Affected |
|-----------|------|--------|----------------|
| [name]    | function/class/file | [why deprecated] | [list] |

### Items Retained
| Component | Reason for Keeping |
|-----------|-------------------|
| [name]    | [still has references in X] |

### Cleanup Actions
- [ ] Removed X deprecated functions
- [ ] Deleted Y unused files
- [ ] Cleaned up Z orphaned imports
```

#### Step 5: Deployment Version Mismatch Detection

**CRITICAL**: Detect stale deployments where installed files differ from project source.

This catches bugs like:
- Symlinks pointing to old script versions in wrong directories
- Installed binaries that don't match current source code
- Multiple copies of same file with different versions across deployment paths
- Service files with outdated configurations

```bash
# Step 5a: Identify deployment locations
echo "=== Deployment Version Mismatch Detection ==="

# Find all symlinks in common install locations pointing into project
PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
INSTALL_DIRS="/usr/local/bin /usr/bin /opt /etc/systemd/system"

echo "Checking symlinks pointing to project..."
for DIR in $INSTALL_DIRS; do
    if [ -d "$DIR" ]; then
        find "$DIR" -type l 2>/dev/null | while read LINK; do
            TARGET=$(readlink -f "$LINK" 2>/dev/null)
            if [[ "$TARGET" == *"$PROJECT_DIR"* ]] || [[ "$TARGET" == *"$(basename $PROJECT_DIR)"* ]]; then
                echo "Found: $LINK -> $TARGET"
            fi
        done
    fi
done

# Step 5b: Check for version mismatches in duplicate files
echo ""
echo "Checking for duplicate files with different content..."

# Find all script/config files in project
find "$PROJECT_DIR" -type f \( -name "*.sh" -o -name "*.py" -o -name "*.service" -o -name "*.conf" \) 2>/dev/null | while read SRC_FILE; do
    BASENAME=$(basename "$SRC_FILE")

    # Look for same filename in other common locations
    for CHECK_DIR in /usr/local/bin /opt /etc/systemd/system /hddRaid1; do
        FOUND=$(find "$CHECK_DIR" -name "$BASENAME" -type f 2>/dev/null | head -5)
        for FOUND_FILE in $FOUND; do
            if [ -f "$FOUND_FILE" ] && [ "$FOUND_FILE" != "$SRC_FILE" ]; then
                # Compare files
                if ! diff -q "$SRC_FILE" "$FOUND_FILE" >/dev/null 2>&1; then
                    SRC_LINES=$(wc -l < "$SRC_FILE" 2>/dev/null || echo "?")
                    FOUND_LINES=$(wc -l < "$FOUND_FILE" 2>/dev/null || echo "?")
                    SRC_DATE=$(stat -c %Y "$SRC_FILE" 2>/dev/null || echo "0")
                    FOUND_DATE=$(stat -c %Y "$FOUND_FILE" 2>/dev/null || echo "0")

                    echo "❌ VERSION MISMATCH DETECTED:"
                    echo "   Source:    $SRC_FILE ($SRC_LINES lines)"
                    echo "   Installed: $FOUND_FILE ($FOUND_LINES lines)"
                    if [ "$SRC_DATE" -gt "$FOUND_DATE" ]; then
                        echo "   ⚠️  Source is NEWER - installed version is STALE"
                    else
                        echo "   ⚠️  Installed is NEWER - source may be outdated"
                    fi
                    echo ""
                fi
            fi
        done
    done
done

# Step 5c: Validate symlink targets exist and are correct
echo ""
echo "Validating symlink integrity..."
find /usr/local/bin /etc/systemd/system -type l 2>/dev/null | while read LINK; do
    TARGET=$(readlink "$LINK")
    RESOLVED=$(readlink -f "$LINK" 2>/dev/null)

    if [ ! -e "$RESOLVED" ]; then
        echo "❌ BROKEN SYMLINK: $LINK -> $TARGET (target does not exist)"
    elif [[ "$TARGET" == *"$PROJECT_DIR"* ]] || [[ "$RESOLVED" == *"$PROJECT_DIR"* ]]; then
        # Check if there's a newer version in the project source
        BASENAME=$(basename "$TARGET")
        CANONICAL_SOURCE=$(find "$PROJECT_DIR" -name "$BASENAME" -type f 2>/dev/null | head -1)

        if [ -n "$CANONICAL_SOURCE" ] && [ "$CANONICAL_SOURCE" != "$RESOLVED" ]; then
            if ! diff -q "$CANONICAL_SOURCE" "$RESOLVED" >/dev/null 2>&1; then
                echo "❌ SYMLINK VERSION MISMATCH:"
                echo "   Symlink: $LINK"
                echo "   Points to: $RESOLVED"
                echo "   But canonical source is: $CANONICAL_SOURCE"
                echo "   Files differ - symlink may point to wrong version!"
            fi
        fi
    fi
done

# Step 5d: Check systemd service file consistency
echo ""
echo "Checking systemd service file consistency..."
if [ -d "$PROJECT_DIR/systemd" ] || [ -d "$PROJECT_DIR/services" ]; then
    SVC_DIR=$([ -d "$PROJECT_DIR/systemd" ] && echo "$PROJECT_DIR/systemd" || echo "$PROJECT_DIR/services")

    for SVC_FILE in "$SVC_DIR"/*.service; do
        [ -f "$SVC_FILE" ] || continue
        BASENAME=$(basename "$SVC_FILE")
        INSTALLED="/etc/systemd/system/$BASENAME"

        if [ -f "$INSTALLED" ]; then
            if ! diff -q "$SVC_FILE" "$INSTALLED" >/dev/null 2>&1; then
                echo "❌ SERVICE FILE MISMATCH:"
                echo "   Source:    $SVC_FILE"
                echo "   Installed: $INSTALLED"
                echo "   Differences:"
                diff --color=always "$SVC_FILE" "$INSTALLED" | head -20
                echo ""
            fi
        else
            echo "⚠️  Service not installed: $BASENAME"
        fi
    done
fi
```

#### Step 6: Report Deployment Mismatches
```markdown
## Deployment Version Mismatch Report

### Critical Mismatches Found
| Source File | Installed Location | Issue | Recommendation |
|-------------|-------------------|-------|----------------|
| scripts/foo.sh | /usr/local/bin/foo | Source newer (76 vs 86 lines) | Update symlink or reinstall |
| systemd/bar.service | /etc/systemd/system/bar.service | Different content | Reinstall service file |

### Symlink Issues
| Symlink | Target | Issue |
|---------|--------|-------|
| /usr/local/bin/<tool> | /old/path/<tool> | Broken - target missing |
| /usr/local/bin/<script> | /legacy/path/<script> | Wrong version - should be ${PROJECT_DIR}/scripts/<script> |

### Actions Required
- [ ] Update symlinks to point to canonical source
- [ ] Reinstall stale service files
- [ ] Remove orphaned deployment files
- [ ] Run `systemctl daemon-reload` after service file updates
```

### Phase 5: Security Audit

Scan for security vulnerabilities, exposed secrets, and common attack vectors.

#### Step 1: Secret Detection
```bash
# Search for hardcoded secrets in codebase
# API keys, passwords, tokens, private keys

# Common patterns to grep for:
grep -rE "(api[_-]?key|apikey|secret[_-]?key|password|passwd|pwd)\s*[=:]\s*['\"][^'\"]+['\"]" --include="*.py" --include="*.js" --include="*.ts" --include="*.go" --include="*.rs" --include="*.java" .

# AWS keys
grep -rE "AKIA[0-9A-Z]{16}" .

# Private keys
grep -rE "-----BEGIN (RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----" .

# JWT tokens
grep -rE "eyJ[A-Za-z0-9_-]*\.eyJ[A-Za-z0-9_-]*\.[A-Za-z0-9_-]*" .

# Check .gitignore for sensitive files
grep -E "\.env|\.pem|\.key|credentials|secrets" .gitignore || echo "WARNING: Sensitive file patterns may not be gitignored"
```

#### Step 2: Dependency Vulnerability Scan
```bash
# Python
pip-audit || safety check || echo "Install: pip install pip-audit"

# Node.js
npm audit --json | jq '.vulnerabilities | to_entries[] | {name: .key, severity: .value.severity}'

# Go
govulncheck ./... || echo "Install: go install golang.org/x/vuln/cmd/govulncheck@latest"

# Rust
cargo audit || echo "Install: cargo install cargo-audit"

# Ruby
bundle audit check --update
```

#### Step 3: Code Vulnerability Patterns
```
Search for common vulnerability patterns:

SQL Injection:
- String concatenation in SQL queries
- f-strings or .format() in SQL
- User input directly in queries

Command Injection:
- os.system(), subprocess with shell=True
- exec(), eval() with user input
- child_process.exec() with string interpolation

XSS (Cross-Site Scripting):
- innerHTML assignments
- dangerouslySetInnerHTML
- Unescaped template variables

Path Traversal:
- User input in file paths without sanitization
- open(user_input) patterns

Insecure Deserialization:
- pickle.loads() with untrusted data
- yaml.load() without SafeLoader
- JSON.parse() on untrusted input used in eval
```

#### Step 4: Authentication & Authorization Review
```
Check for:
- Hardcoded credentials or default passwords
- Missing authentication on sensitive endpoints
- Broken access control (users accessing other users' data)
- Session management issues
- Missing CSRF protection
- Weak password requirements
- Missing rate limiting
```

#### Step 5: Configuration Security
```bash
# Check for debug mode in production configs
grep -rE "(DEBUG|debug)\s*[=:]\s*(true|True|1)" --include="*.py" --include="*.js" --include="*.json" --include="*.yaml" .

# Check for insecure protocols
grep -rE "http://" --include="*.py" --include="*.js" --include="*.ts" . | grep -v "localhost\|127.0.0.1\|http://$"

# Check for disabled SSL verification
grep -rE "(verify\s*=\s*False|SSL_VERIFY.*false|rejectUnauthorized.*false)" .
```

#### Security Audit Report
```markdown
## Security Audit Report

### Secrets Detected
| Type | File | Line | Severity | Status |
|------|------|------|----------|--------|
| API Key | config.py | 23 | 🔴 HIGH | Needs removal |

### Dependency Vulnerabilities
| Package | Version | CVE | Severity | Fix Available |
|---------|---------|-----|----------|---------------|
| lodash | 4.17.15 | CVE-2021-23337 | HIGH | 4.17.21 |

### Code Vulnerabilities
| Type | File | Line | Risk | Recommendation |
|------|------|------|------|----------------|
| SQL Injection | db.py | 45 | HIGH | Use parameterized queries |

### Configuration Issues
| Issue | Location | Risk |
|-------|----------|------|
| Debug mode enabled | settings.py | MEDIUM |

### Security Score: [0-100]
- Secrets: X/25
- Dependencies: X/25
- Code: X/25
- Configuration: X/25
```

### Phase 6: Dependency Health

Audit all project dependencies for freshness, security, and necessity.

#### Step 1: Identify All Dependencies
```bash
# Generate full dependency tree
# Python
pip freeze > /tmp/current_deps.txt
pipdeptree --warn silence

# Node.js
npm ls --all --json > /tmp/npm_deps.json

# Go
go mod graph

# Rust
cargo tree
```

#### Step 2: Check for Outdated Packages
```bash
# Python
pip list --outdated --format=json | jq '.[] | {name: .name, current: .version, latest: .latest_version}'

# Node.js
npm outdated --json

# Go
go list -u -m all 2>/dev/null | grep '\['

# Rust
cargo outdated
```

#### Step 3: Find Unused Dependencies
```bash
# Python - check imports vs requirements
# List all imports
grep -rh "^import \|^from .* import" --include="*.py" . | sort -u > /tmp/imports.txt
# Compare with requirements.txt

# Node.js
npx depcheck

# Go
go mod tidy -v 2>&1 | grep "unused"
```

#### Step 4: License Compliance Check
```bash
# Python
pip-licenses --format=markdown

# Node.js
npx license-checker --summary

# Check for problematic licenses
# GPL in proprietary code, etc.
```

#### Step 5: Dependency Quality Assessment
```
For each major dependency, evaluate:
- Last update date (stale if >1 year)
- Open issues count
- Maintenance status (archived, deprecated)
- Download trends (declining = concerning)
- Alternative packages available
```

#### Dependency Health Report
```markdown
## Dependency Health Report

### Outdated Packages
| Package | Current | Latest | Behind By | Risk |
|---------|---------|--------|-----------|------|
| requests | 2.25.0 | 2.31.0 | 2 years | MEDIUM |

### Unused Dependencies (can be removed)
- [ ] package1 - no imports found
- [ ] package2 - only in dev, not used

### Security Vulnerabilities (from Phase 5)
[Reference Phase 5 findings]

### License Issues
| Package | License | Compatibility |
|---------|---------|---------------|
| gpl-pkg | GPL-3.0 | ⚠️ Review needed |

### Stale/Unmaintained Packages
| Package | Last Update | Status | Alternative |
|---------|-------------|--------|-------------|
| old-pkg | 2019-03-15 | Archived | new-pkg |

### Recommendations
- [ ] Update X critical packages
- [ ] Remove Y unused dependencies
- [ ] Replace Z unmaintained packages
```

### Phase 7: Code Quality Audit

Analyze code quality, complexity, and adherence to best practices.

#### Step 1: Run Project Linters
```bash
# Python
ruff check . --output-format=json || pylint **/*.py --output-format=json || flake8 . --format=json

# Node.js/TypeScript
npx eslint . --format=json || echo "ESLint not configured"

# Go
golangci-lint run --out-format=json

# Rust
cargo clippy --message-format=json
```

#### Step 2: Code Complexity Analysis
```bash
# Python - cyclomatic complexity
radon cc . -a -s --json || echo "Install: pip install radon"

# JavaScript
npx eslint . --rule 'complexity: [error, 10]'

# Generic - lines of code, function length
cloc . --json
```

#### Step 3: Identify Anti-Patterns
```
Search for common anti-patterns:

# God classes/modules (files > 500 lines)
find . -name "*.py" -o -name "*.js" -o -name "*.ts" | xargs wc -l | sort -n | tail -20

# Deep nesting (>4 levels)
# Functions with too many parameters (>5)
# Magic numbers and strings
# Duplicate code blocks
# Global state mutations
# Overly complex conditionals
```

#### Step 4: TODO/FIXME/HACK Inventory
```bash
# Find all technical debt markers
grep -rn "TODO\|FIXME\|HACK\|XXX\|BUG\|OPTIMIZE" --include="*.py" --include="*.js" --include="*.ts" --include="*.go" --include="*.rs" . | head -50
```

#### Step 5: Type Safety Check
```bash
# Python
mypy . --ignore-missing-imports || echo "MyPy not configured"

# TypeScript
npx tsc --noEmit

# Check for 'any' type abuse
grep -rn ": any" --include="*.ts" . | wc -l
```

#### Code Quality Report
```markdown
## Code Quality Report

### Linting Summary
| Category | Errors | Warnings | Info |
|----------|--------|----------|------|
| Style | X | Y | Z |
| Logic | X | Y | Z |
| Security | X | Y | Z |

### Complexity Hotspots
| File | Function | Complexity | Recommendation |
|------|----------|------------|----------------|
| utils.py | process_data | 25 | Refactor into smaller functions |

### Anti-Patterns Found
| Pattern | Count | Locations |
|---------|-------|-----------|
| God class (>500 LOC) | 2 | [files] |
| Deep nesting (>4) | 5 | [files] |
| Magic numbers | 12 | [files] |

### Technical Debt (TODOs)
| Priority | Count | Oldest |
|----------|-------|--------|
| FIXME | 3 | 2022-01-15 |
| TODO | 15 | 2021-06-20 |
| HACK | 2 | 2023-03-01 |

### Type Safety
- Type coverage: X%
- Any types used: Y
- Missing type hints: Z functions

### Code Quality Score: [0-100]
```

### Phase 8: Test Coverage Analysis

Analyze test coverage and identify critical untested code paths.

**CRITICAL**: This phase enforces the minimum coverage requirement (default: 85%). Coverage below this threshold will cause the audit to flag the project as non-compliant. Configure via `.claude-test.yaml`:

```yaml
coverage:
  minimum: 85      # Required percentage
  fail_on_below: true  # Whether to fail audit if below
```

#### Step 1: Run Coverage Tools
```bash
# Python
pytest --cov=. --cov-report=json --cov-report=term-missing

# Node.js
npm run test -- --coverage --coverageReporters=json

# Go
go test -coverprofile=coverage.out ./...
go tool cover -func=coverage.out

# Rust
cargo tarpaulin --out Json
```

#### Step 2: Identify Coverage Gaps
```
Analyze coverage report for:
- Files with 0% coverage (completely untested)
- Files with <50% coverage (poorly tested)
- Critical paths without coverage (auth, payments, data mutations)
- Branches never taken (conditional logic untested)
- Error handlers never triggered
```

#### Step 3: Classify Untested Code by Risk
```
HIGH RISK (must have tests):
- Authentication/authorization logic
- Payment/financial calculations
- Data validation and sanitization
- Security-sensitive operations
- Core business logic

MEDIUM RISK (should have tests):
- API endpoint handlers
- Database operations
- External service integrations
- State management

LOW RISK (nice to have tests):
- Utility functions
- Formatting/display logic
- Configuration loading
```

#### Step 4: Identify Dead Code
```bash
# Code that's never executed AND never tested = likely dead
# Cross-reference coverage with grep for usage

# Python
vulture . --min-confidence 80

# JavaScript
npx ts-prune  # For TypeScript
```

#### Step 5: Test Quality Assessment
```
Evaluate existing tests:
- Are tests actually asserting meaningful outcomes?
- Do tests cover edge cases?
- Are there flaky tests?
- Test execution time (slow tests = less likely to run)
- Test isolation (do tests depend on each other?)
```

#### Coverage Report
```markdown
## Test Coverage Report

### Overall Coverage
| Metric | Value | Target | Status |
|--------|-------|--------|--------|
| Line coverage | 65% | 80% | ⚠️ Below target |
| Branch coverage | 45% | 70% | ❌ Critical |
| Function coverage | 78% | 90% | ⚠️ Below target |

### Uncovered Critical Paths
| File | Function/Class | Risk | Priority |
|------|---------------|------|----------|
| auth.py | validate_token | HIGH | P0 |
| payments.py | process_refund | HIGH | P0 |

### Files Needing Tests
| File | Coverage | Lines Uncovered | Priority |
|------|----------|-----------------|----------|
| core/engine.py | 12% | 245 | HIGH |
| api/handlers.py | 34% | 120 | HIGH |

### Dead Code Candidates
| File | Lines | Reason |
|------|-------|--------|
| legacy.py | 1-150 | No coverage, no references |

### Recommended Test Additions
1. [ ] Add tests for auth.validate_token (HIGH)
2. [ ] Add tests for payments.process_refund (HIGH)
3. [ ] Add edge case tests for api/handlers.py
```

#### Step 6: Enforce Minimum Coverage Requirement (85%)

**CRITICAL**: This step enforces the coverage threshold from `.claude-test.yaml` (default: 85%).

```bash
# Enforce minimum coverage
check_coverage_threshold() {
    local MIN_COVERAGE="${COVERAGE_MIN:-85}"
    local FAIL_ON_BELOW="${COVERAGE_FAIL_ON_BELOW:-true}"
    local COVERAGE=0

    echo ""
    echo "═══════════════════════════════════════════════════════════════════"
    echo "  COVERAGE THRESHOLD CHECK (Minimum: ${MIN_COVERAGE}%)"
    echo "═══════════════════════════════════════════════════════════════════"

    # Extract coverage percentage based on available report
    if [ -f ".coverage" ] && command -v coverage &>/dev/null; then
        COVERAGE=$(coverage report --format=total 2>/dev/null | tail -1)
    elif [ -f "coverage.json" ]; then
        COVERAGE=$(jq '.totals.percent_covered // 0' coverage.json 2>/dev/null)
    elif [ -f "coverage/coverage-summary.json" ]; then
        COVERAGE=$(jq '.total.lines.pct // 0' coverage/coverage-summary.json 2>/dev/null)
    elif [ -f "coverage.out" ]; then
        # Go coverage
        COVERAGE=$(go tool cover -func=coverage.out 2>/dev/null | grep total | awk '{print $3}' | tr -d '%')
    fi

    # Handle empty or invalid coverage
    COVERAGE=$(echo "$COVERAGE" | tr -d '% ' | head -1)
    [ -z "$COVERAGE" ] && COVERAGE=0

    echo ""
    echo "  Current coverage: ${COVERAGE}%"
    echo "  Minimum required: ${MIN_COVERAGE}%"
    echo ""

    # Compare using bc for floating point
    if (( $(echo "$COVERAGE < $MIN_COVERAGE" | bc -l 2>/dev/null || echo 1) )); then
        echo "❌ COVERAGE BELOW MINIMUM THRESHOLD"
        echo ""
        echo "  Coverage: ${COVERAGE}% < ${MIN_COVERAGE}% (required)"
        echo ""
        echo "  Actions required:"
        echo "  1. Add tests for uncovered critical paths (see report above)"
        echo "  2. Prioritize HIGH and MEDIUM risk uncovered code"
        echo "  3. Ensure all business logic has test coverage"
        echo ""

        if [ "$FAIL_ON_BELOW" = "true" ]; then
            echo "  ⚠️  AUDIT WILL FLAG THIS AS NON-COMPLIANT"
            COVERAGE_STATUS="FAIL"
        else
            echo "  ℹ️  Continuing audit (fail_on_below: false)"
            COVERAGE_STATUS="WARN"
        fi
    else
        echo "✅ COVERAGE MEETS MINIMUM REQUIREMENT"
        echo ""
        echo "  ${COVERAGE}% >= ${MIN_COVERAGE}%"
        COVERAGE_STATUS="PASS"
    fi

    echo ""
    echo "═══════════════════════════════════════════════════════════════════"

    return $( [ "$COVERAGE_STATUS" = "PASS" ] && echo 0 || echo 1 )
}

# Run the check
check_coverage_threshold
```

#### Coverage Enforcement Report

```markdown
## Coverage Enforcement Summary

| Metric | Value | Threshold | Status |
|--------|-------|-----------|--------|
| Line Coverage | ${COVERAGE}% | ${MIN_COVERAGE}% | ${COVERAGE_STATUS} |

### Components Below Threshold
| Component | Coverage | Gap | Priority |
|-----------|----------|-----|----------|
| [component] | X% | -(85-X)% | HIGH |

### Enforcement Result: ✅ PASS / ⚠️ WARN / ❌ FAIL
```

---

### Phase 9: Autonomous Debugging

When tests fail or issues are found, automatically diagnose root causes.

#### Step 1: Failure Classification
```
Categorize each failure:

BUILD FAILURES:
- Syntax errors
- Import/dependency errors
- Compilation errors
- Type errors

RUNTIME FAILURES:
- Null/undefined reference
- Index out of bounds
- Type mismatch
- Resource not found

LOGIC FAILURES:
- Assertion failures
- Wrong output values
- Missing expected behavior
- Race conditions

ENVIRONMENT FAILURES:
- Missing dependencies
- Service unavailable
- Permission denied
- Configuration errors
```

#### Step 2: Stack Trace Analysis
```
For each failure:
1. Parse the full stack trace
2. Identify the failing line and file
3. Read surrounding context (±20 lines)
4. Identify the root cause location vs. symptom location
5. Check if it's in project code vs. library code
```

#### Step 3: Root Cause Correlation
```bash
# Check git blame for recent changes to failing code
git log --oneline -10 -- <failing_file>
git diff HEAD~5 -- <failing_file>

# Find related changes
git log --oneline --all --grep="<function_name>"

# Check if failure is new
git bisect start
git bisect bad HEAD
git bisect good <last_known_good>
```

#### Step 4: Pattern Recognition
```
Common root causes to check:

NULL/UNDEFINED:
- Uninitialized variables
- Missing null checks
- Async operations completing out of order

TYPE ERRORS:
- Implicit type coercion
- Missing type conversions
- Schema changes not propagated

RESOURCE ERRORS:
- Connection timeouts
- File handle exhaustion
- Memory leaks

STATE ERRORS:
- Race conditions
- Stale cache
- Inconsistent state after partial failure
```

#### Step 5: Hypothesis Generation
```markdown
For each failure, generate ranked hypotheses:

## Failure: test_user_login fails with NullPointerException

### Hypothesis 1 (HIGH confidence)
- **Root cause**: User object is null because database query returned no results
- **Evidence**: Line 45 calls user.getName() but user could be null
- **Fix**: Add null check before accessing user properties

### Hypothesis 2 (MEDIUM confidence)
- **Root cause**: Test database not seeded with test user
- **Evidence**: Test setup doesn't insert test user
- **Fix**: Add user creation to test setup

### Hypothesis 3 (LOW confidence)
- **Root cause**: Race condition in async user loading
- **Evidence**: Test passes intermittently
- **Fix**: Add await/synchronization
```

#### Debugging Report
```markdown
## Autonomous Debugging Report

### Failures Analyzed: [count]

### Failure 1: [test name / error message]
| Attribute | Value |
|-----------|-------|
| Type | Runtime / Logic / Build / Environment |
| File | path/to/file.py:123 |
| Root Cause | [identified cause] |
| Confidence | HIGH / MEDIUM / LOW |
| Fix Complexity | Simple / Moderate / Complex |

**Stack Trace Summary**:
[Condensed relevant portion]

**Root Cause Analysis**:
[Detailed explanation]

**Recommended Fix**:
[Specific code change needed]

### Debug Summary
| Category | Count | Auto-Fixable |
|----------|-------|--------------|
| Null references | 3 | 2 |
| Type errors | 1 | 1 |
| Logic errors | 2 | 0 |
| Config errors | 1 | 1 |
```

### Phase 10: Autonomous Fixing

Apply fixes for all identified issues, then verify the fixes work.

#### Step 1: Prioritize Fixes
```
Fix order (highest priority first):
1. Build/compilation errors (nothing works without this)
2. Security vulnerabilities (especially exposed secrets)
3. Test failures (restore green build)
4. Critical code quality issues (blocking bugs)
5. Dependency updates (security patches)
6. Non-critical improvements (nice-to-have)
```

#### Step 2: Apply Automated Fixes
```bash
# Linting/formatting auto-fix
# Python
ruff check . --fix
black .
isort .

# Node.js
npx eslint . --fix
npx prettier --write .

# Go
gofmt -w .
go mod tidy

# Rust
cargo fmt
cargo fix --allow-dirty
```

#### Step 3: Fix Security Issues
```
For each security issue:
1. Remove hardcoded secrets → move to environment variables
2. Update vulnerable dependencies → npm audit fix / pip install --upgrade
3. Fix code vulnerabilities → apply secure coding patterns
4. Update insecure configurations → disable debug mode, enable TLS
```

#### Step 4: Fix Failing Tests
```
For each test failure (from Phase 9):
1. Apply the recommended fix from debugging analysis
2. If fix requires code change:
   - Make minimal change to fix the issue
   - Don't refactor unrelated code
   - Add comments explaining non-obvious fixes
3. If fix requires test change:
   - Update test expectations if behavior intentionally changed
   - Fix test setup/teardown if environment issue
   - Skip flaky tests with TODO to investigate
```

#### Step 5: Dependency Updates
```bash
# Apply safe updates (patch/minor versions)
# Python
pip install --upgrade <package>  # For each outdated

# Node.js
npm update  # Updates within semver range
npm audit fix  # Security fixes

# Go
go get -u ./...

# Rust
cargo update
```

#### Step 6: Verify Each Fix
```
After EACH fix batch:
1. Run the specific test that was failing
2. Run related tests (same module/component)
3. Run full test suite if safe
4. Check for regressions

If fix causes new failures:
- Rollback the fix
- Document as "needs manual intervention"
- Move to next fix
```

#### Fix Report
```markdown
## Autonomous Fix Report

### Fixes Applied: [count]

### Fix Summary by Category
| Category | Attempted | Succeeded | Failed | Manual Needed |
|----------|-----------|-----------|--------|---------------|
| Linting/Format | 45 | 45 | 0 | 0 |
| Security | 5 | 4 | 1 | 1 |
| Test Failures | 8 | 6 | 2 | 2 |
| Dependencies | 12 | 12 | 0 | 0 |

### Detailed Fix Log

#### Fix 1: [description]
- **Issue**: Hardcoded API key in config.py
- **Fix Applied**: Moved to environment variable
- **Files Changed**: config.py, .env.example
- **Verification**: ✅ Tests pass

#### Fix 2: [description]
- **Issue**: SQL injection vulnerability in db.py:45
- **Fix Applied**: Changed to parameterized query
- **Files Changed**: db.py
- **Verification**: ✅ Tests pass

### Fixes Requiring Manual Intervention
| Issue | Reason | Recommendation |
|-------|--------|----------------|
| Complex refactor needed | Logic change required | [details] |

### Post-Fix Test Results
- Tests passing: X/Y
- New failures introduced: 0
- Regressions: 0
```

### Phase 11: Configuration Audit

Validate all configuration files and environment setup.

#### Step 1: Configuration File Validation
```bash
# JSON syntax validation
find . -name "*.json" -exec sh -c 'jq . "$1" > /dev/null 2>&1 || echo "Invalid JSON: $1"' _ {} \;

# YAML syntax validation
find . -name "*.yaml" -o -name "*.yml" | xargs -I {} sh -c 'python -c "import yaml; yaml.safe_load(open(\"{}}\"))" 2>&1 || echo "Invalid YAML: {}"'

# TOML validation
find . -name "*.toml" -exec sh -c 'python -c "import tomllib; tomllib.load(open(\"$1\", \"rb\"))" 2>&1 || echo "Invalid TOML: $1"' _ {} \;

# INI validation
find . -name "*.ini" -o -name "*.cfg" | xargs -I {} python -c "import configparser; configparser.ConfigParser().read('{}')"
```

#### Step 2: Schema Compliance
```
For each config file with a schema:
- Validate against JSON Schema if available
- Check required fields are present
- Verify value types match expectations
- Check enum values are valid options
```

#### Step 3: Environment Consistency
```bash
# Compare environment files
diff .env.example .env 2>/dev/null || echo "Check .env vs .env.example"

# Find all environment references in code
grep -rh "process\.env\.\|os\.environ\|os\.getenv\|env\." --include="*.py" --include="*.js" --include="*.ts" . | \
  grep -oE "[A-Z_][A-Z0-9_]*" | sort -u > /tmp/env_refs.txt

# Compare with documented env vars
comm -23 /tmp/env_refs.txt <(grep -E "^[A-Z_]" .env.example 2>/dev/null | cut -d= -f1 | sort)
```

#### Step 4: Secrets Management
```
Verify secrets are properly managed:
- No secrets in version control
- Secrets use environment variables or secret manager
- Rotation policies documented
- Access properly restricted
- No secrets in logs
```

#### Step 5: Environment-Specific Configs
```
Compare dev/staging/prod configurations:
- Feature flags consistency
- Service URLs appropriate for environment
- Debug settings disabled in production
- Logging levels appropriate
- Resource limits configured
```

#### Configuration Report
```markdown
## Configuration Audit Report

### File Validation
| File | Syntax | Schema | Status |
|------|--------|--------|--------|
| config.json | ✅ Valid | ✅ Compliant | OK |
| settings.yaml | ❌ Invalid | N/A | Line 45: unexpected indent |

### Environment Variables
| Variable | In Code | In .env | In .env.example | Status |
|----------|---------|---------|-----------------|--------|
| API_KEY | ✅ | ✅ | ✅ | OK |
| DB_URL | ✅ | ✅ | ❌ | Missing from example |
| OLD_VAR | ❌ | ✅ | ✅ | Unused - remove |

### Secrets Status
| Secret | Storage | Rotation | Status |
|--------|---------|----------|--------|
| DB_PASSWORD | Env var | Unknown | ⚠️ Add rotation policy |
| API_KEY | Env var | 90 days | ✅ OK |

### Environment Consistency
| Setting | Dev | Staging | Prod | Issue |
|---------|-----|---------|------|-------|
| DEBUG | true | true | true | ❌ Should be false in prod |
| LOG_LEVEL | debug | debug | debug | ⚠️ Consider 'info' for prod |

### Configuration Health Score: [0-100]
```

### Phase 12: Final Verification

Re-run all checks after fixes to confirm everything works.

#### Step 1: Full Test Suite
```bash
# Run complete test suite
# Python
pytest -v --tb=short

# Node.js
npm test

# Go
go test -v ./...

# Rust
cargo test
```

#### Step 2: Build Verification
```bash
# Ensure project builds cleanly
# Python
python -m py_compile **/*.py

# Node.js
npm run build

# Go
go build ./...

# Rust
cargo build --release
```

#### Step 3: Smoke Test
```
Run basic functionality test:
1. Start the application/service
2. Hit main endpoints or run main commands
3. Verify core features work
4. Check logs for errors during operation
5. Graceful shutdown
```

#### Step 4: Regression Check
```
Compare before/after:
- Test count: same or more
- Test pass rate: same or better
- Build time: not significantly worse
- No new warnings introduced
- No new security vulnerabilities
```

#### Step 4a: Deployment Consistency Regression Check

**CRITICAL**: Verify all deployed files match project source after fixes.

```bash
# Re-run deployment mismatch detection from Phase 4, Step 5
# This catches regressions where fixes introduced new mismatches

echo "=== Post-Fix Deployment Consistency Check ==="

PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
MISMATCHES=0

# Check all symlinks still point to correct versions
echo "Verifying symlinks..."
for LINK in /usr/local/bin/* /etc/systemd/system/*.service; do
    [ -L "$LINK" ] || continue
    TARGET=$(readlink -f "$LINK" 2>/dev/null)

    # If symlink points into project, verify it's the canonical source
    if [[ "$TARGET" == *"$(basename $PROJECT_DIR)"* ]]; then
        BASENAME=$(basename "$TARGET")
        CANONICAL=$(find "$PROJECT_DIR" -name "$BASENAME" -type f ! -path "*/.git/*" 2>/dev/null | head -1)

        if [ -n "$CANONICAL" ] && [ "$CANONICAL" != "$TARGET" ]; then
            if ! diff -q "$CANONICAL" "$TARGET" >/dev/null 2>&1; then
                echo "❌ REGRESSION: $LINK points to stale version"
                echo "   Current target: $TARGET"
                echo "   Should be: $CANONICAL"
                ((MISMATCHES++))
            fi
        fi
    fi
done

# Check systemd service files are in sync
echo "Verifying systemd service files..."
for SVC_DIR in "$PROJECT_DIR/systemd" "$PROJECT_DIR/services"; do
    [ -d "$SVC_DIR" ] || continue
    for SVC in "$SVC_DIR"/*.service; do
        [ -f "$SVC" ] || continue
        INSTALLED="/etc/systemd/system/$(basename $SVC)"
        if [ -f "$INSTALLED" ] && ! diff -q "$SVC" "$INSTALLED" >/dev/null 2>&1; then
            echo "❌ REGRESSION: Service file mismatch: $(basename $SVC)"
            ((MISMATCHES++))
        fi
    done
done

# Check for orphaned files from previous installs
echo "Checking for orphaned deployment files..."
for INSTALLED in /usr/local/bin/*; do
    [ -L "$INSTALLED" ] || continue
    TARGET=$(readlink "$INSTALLED")

    # If points to project but file doesn't exist in current source
    if [[ "$TARGET" == *"$(basename $PROJECT_DIR)"* ]]; then
        if [ ! -e "$TARGET" ]; then
            echo "❌ ORPHANED: $INSTALLED -> $TARGET (target missing)"
            ((MISMATCHES++))
        fi
    fi
done

if [ $MISMATCHES -gt 0 ]; then
    echo ""
    echo "⚠️  DEPLOYMENT REGRESSION: $MISMATCHES mismatches found!"
    echo "   Run Phase 4 Step 5-6 to identify and fix deployment issues."
else
    echo "✅ All deployed files match project source"
fi
```

#### Step 5: Generate Final Report
```markdown
## Final Verification Report

### Test Results
| Suite | Before | After | Change |
|-------|--------|-------|--------|
| Unit tests | 45/50 | 50/50 | +5 ✅ |
| Integration | 10/12 | 12/12 | +2 ✅ |
| E2E | 5/5 | 5/5 | = |

### Build Status
- Clean build: ✅
- No warnings: ✅
- Artifacts generated: ✅

### Smoke Test
- Application starts: ✅
- Core functionality: ✅
- No errors in logs: ✅

### Regression Summary
- New test failures: 0
- New warnings: 0
- New vulnerabilities: 0

### Deployment Consistency
| Check | Status |
|-------|--------|
| Symlinks point to correct source | ✅/❌ |
| Service files match source | ✅/❌ |
| No orphaned deployment files | ✅/❌ |
| No version mismatches | ✅/❌ |

### Final Status: ✅ ALL CLEAR / ⚠️ ISSUES REMAIN / ❌ CRITICAL PROBLEMS
```

### Phase 13: Documentation Review & Update (FINAL PHASE)

**This phase runs LAST** so that all documentation reflects changes made during the audit (fixes, security updates, configuration changes, etc.).

#### Step 1: Inventory All Documentation
```
Find all documentation files:
- README.md, README.rst, README.txt
- docs/ directory contents
- CHANGELOG.md, HISTORY.md
- CONTRIBUTING.md, CODE_OF_CONDUCT.md
- API documentation (OpenAPI/Swagger specs, docstrings)
- Wiki pages (if stored in repo)
- Inline code comments for complex logic
- Configuration file comments
- Man pages, help text
```

#### Step 2: Verify Documentation Accuracy
For EACH documentation file, verify:

```
❌ WRONG: "Documentation exists"
✅ RIGHT: "Documentation accurately reflects current implementation"
```

You MUST check:
- **Installation instructions**: Do they work? Are versions current?
- **Usage examples**: Do they run successfully with current code?
- **API references**: Do endpoints/functions match actual implementation?
- **Configuration options**: Are all options documented? Any removed?
- **Dependencies**: Are listed dependencies accurate and versions correct?
- **File paths**: Do referenced paths exist?
- **Screenshots/diagrams**: Do they reflect current UI/architecture?

#### Step 3: Update Stale Documentation
For each outdated item:
1. Update to reflect current implementation
2. Remove references to deprecated/removed features
3. Add documentation for new features discovered during testing
4. **Document fixes applied during this audit** (Phase 10)
5. **Document configuration changes** (Phase 11)
6. Fix broken links and references
7. Update version numbers and dates
8. Ensure consistent formatting and style

#### Step 4: Cross-Reference Validation
Ensure documentation consistency:
- README mentions same features as code provides
- API docs match actual API responses
- Config docs match actual config options
- CHANGELOG reflects recent changes accurately
- **CHANGELOG includes fixes applied during this audit**

#### Step 5: Report Documentation Status
```markdown
## Documentation Review Report (Phase 13 - FINAL)

### Files Reviewed
| File | Status | Updates Made |
|------|--------|--------------|
| README.md | ✅ Current / ⚠️ Updated / ❌ Major rewrite | [summary] |

### Issues Found & Fixed
- [ ] [file]: [what was wrong] → [what was fixed]

### Updates From This Audit
Documentation updated to reflect changes made during audit:
- [ ] [fix from Phase 10]: documented in [file]
- [ ] [config change from Phase 11]: documented in [file]

### New Documentation Added
- [ ] [file]: [what was added and why]

### Documentation Health
- Total files reviewed: [count]
- Files requiring updates: [count]
- Files now current: [count]

### Verification
- [ ] All installation instructions tested and working
- [ ] All code examples executed successfully
- [ ] All internal links validated
- [ ] All external links checked (or noted as unchecked)
- [ ] CHANGELOG updated with audit fixes
```

## Testing Commands by Project Type

### Python Projects
```bash
# Run test suite with coverage
pytest -v --tb=short --cov=. --cov-report=term-missing

# Run specific module tests
pytest tests/test_MODULE.py -v

# Check for import errors
python -c "import MODULE_NAME"
```

### Node.js Projects
```bash
# Run test suite
npm test
# or
yarn test

# Run with coverage
npm run test:coverage

# Check for require errors
node -e "require('./src/index.js')"
```

### Go Projects
```bash
# Run all tests with verbose output
go test -v ./...

# Run with race detection
go test -race ./...

# Run specific package
go test -v ./pkg/NAME
```

### Rust Projects
```bash
# Run all tests
cargo test

# Run with output
cargo test -- --nocapture

# Run specific test
cargo test TEST_NAME
```

### Generic/Script Projects
```bash
# Run main script with test input
./main.sh --test-mode

# Verify script syntax
bash -n script.sh

# Run with debug output
bash -x script.sh TEST_INPUT
```

## Final Summary Format

After ALL phases are complete, provide this comprehensive report:

```markdown
# Comprehensive Project Audit Report

**Project**: [name]
**Audit Date**: [date/time]
**Audit Duration**: [time elapsed]
**Claude Model**: [model used]

---

## BTRFS Snapshot Information

| Attribute | Value |
|-----------|-------|
| Snapshot Location | `/snapshots/audit/` |
| Snapshot Name | `audit-YYYYMMDD-HHMMSS-[project]` |
| Created | [timestamp] |
| Read-Only | ✅ Verified |
| Subvolumes Snapshotted | [count] |

**Rollback Command** (if needed):
```bash
sudo btrfs subvolume delete /path/to/project
sudo btrfs subvolume snapshot /snapshots/audit/audit-YYYYMMDD-HHMMSS-project /path/to/project
```

**Cleanup Command** (after successful audit):
```bash
sudo btrfs subvolume delete /snapshots/audit/audit-YYYYMMDD-HHMMSS-*
rm /snapshots/audit/audit-YYYYMMDD-HHMMSS-*.info
```

---

## Executive Summary

| Phase | Status | Issues Found | Issues Fixed | Manual Required |
|-------|--------|--------------|--------------|-----------------|
| S. BTRFS Snapshot | ✅/❌/⏭️ | - | - | - |
| 0. Pre-Flight | ✅/❌ | X | X | X |
| 1. Discovery | ✅/❌ | - | - | - |
| 2. Execute Tests | ✅/❌ | X | X | X |
| 3. Report Results | ✅/❌ | - | - | - |
| 4. Deprecation Cleanup | ✅/❌ | X | X | X |
| 5. Security Audit | ✅/❌ | X | X | X |
| 6. Dependency Health | ✅/❌ | X | X | X |
| 7. Code Quality | ✅/❌ | X | X | X |
| 8. Test Coverage | ✅/❌ | X | X | X |
| 9. Debugging | ✅/❌ | X | X | X |
| 10. Auto-Fixing | ✅/❌ | X | X | X |
| 11. Config Audit | ✅/❌ | X | X | X |
| 12. Final Verification | ✅/❌ | - | - | - |
| 13. Documentation | ✅/❌ | X | X | X |

**Overall Health Score**: [0-100] / 100

---

## Phase Summaries

### Pre-Flight (Phase 0)
- Environment ready: ✅/❌
- Dependencies verified: ✅/❌
- Services connected: ✅/❌
- Blockers: [list or "None"]

### Testing (Phases 1-3)
| Component | Operations | Output | Logs | Pipeline | Status |
|-----------|------------|--------|------|----------|--------|
| [name]    | ✅/❌      | ✅/❌  | ✅/❌| ✅/❌    | PASS/FAIL |

### Runtime Service Health (Phase 2a)
| Service | Process Activity | Output Generation | Non-Interactive | Log Health | Status |
|---------|------------------|-------------------|-----------------|------------|--------|
| [name]  | ✅/❌           | ✅/❌            | ✅/❌          | ✅/❌     | ✅/⚠️/❌ |

**Critical Checks**:
- [ ] No processes stuck in sleep loops (>50% sleeping = ❌)
- [ ] Active workers running (ffmpeg, python, node, etc.)
- [ ] Files being created in output directories
- [ ] No "overwrite? [y/N]" prompts in logs
- [ ] No "permission denied" errors

### Deprecation Cleanup (Phase 4)
| Action | Count | Details |
|--------|-------|---------|
| Files removed | X | [list] |
| Functions/classes removed | X | [list] |
| Dead code eliminated | X | [list] |

### Security (Phase 5)
| Category | Critical | High | Medium | Low | Fixed |
|----------|----------|------|--------|-----|-------|
| Secrets | X | X | X | X | X |
| Dependencies | X | X | X | X | X |
| Code | X | X | X | X | X |
| Config | X | X | X | X | X |

**Security Score**: [0-100]

### Dependencies (Phase 6)
| Metric | Count |
|--------|-------|
| Total dependencies | X |
| Outdated | X |
| Vulnerable | X |
| Unused (removed) | X |
| Updated | X |

### Code Quality (Phase 7)
| Metric | Value |
|--------|-------|
| Linting errors fixed | X |
| Complexity hotspots | X |
| Anti-patterns found | X |
| Type coverage | X% |

**Code Quality Score**: [0-100]

### Test Coverage (Phase 8)
| Metric | Before | After | Target |
|--------|--------|-------|--------|
| Line coverage | X% | X% | 80% |
| Branch coverage | X% | X% | 70% |
| Function coverage | X% | X% | 90% |

### Debugging & Fixing (Phases 9-10)
| Category | Found | Auto-Fixed | Manual Required |
|----------|-------|------------|-----------------|
| Build errors | X | X | X |
| Runtime errors | X | X | X |
| Logic errors | X | X | X |
| Config errors | X | X | X |

### Configuration (Phase 11)
| Check | Status |
|-------|--------|
| All configs valid | ✅/❌ |
| Env vars documented | ✅/❌ |
| Secrets secure | ✅/❌ |
| Environments consistent | ✅/❌ |

### Final Verification (Phase 12)
| Check | Before | After |
|-------|--------|-------|
| Tests passing | X/Y | X/Y |
| Build clean | ✅/❌ | ✅/❌ |
| No regressions | - | ✅/❌ |

### Documentation (Phase 13 - FINAL)
| Metric | Value |
|--------|-------|
| Files reviewed | X |
| Files updated | X |
| Files now current | X |
| Broken links fixed | X |
| Audit changes documented | X |

---

## Issues Requiring Manual Intervention

| # | Phase | Issue | Severity | Recommendation |
|---|-------|-------|----------|----------------|
| 1 | [X] | [description] | HIGH/MED/LOW | [action needed] |

---

## Changes Made (Git Diff Summary)

Files modified: [count]
Lines added: [count]
Lines removed: [count]

Key changes:
- [file]: [summary of change]

---

## Recommendations

### Immediate (P0)
- [ ] [Critical items that must be addressed]

### Short-term (P1)
- [ ] [Important items for next sprint]

### Long-term (P2)
- [ ] [Technical debt to address eventually]

---

## Audit Metadata

- Start time: [timestamp]
- End time: [timestamp]
- Phases completed: X/15 (including Phase S)
- Total issues found: X
- Total issues fixed: X
- Manual intervention required: X items

### BTRFS Snapshot Status
- Snapshot created: ✅ Yes / ❌ No / ⏭️ Skipped (--skip-snapshot)
- Snapshot location: [path or "N/A"]
- Recommended action:
  - If audit successful: **Delete snapshot** (cleanup command above)
  - If audit failed: **Keep snapshot** for potential rollback

**Final Status**: ✅ ALL CLEAR / ⚠️ ISSUES REMAIN / ❌ CRITICAL PROBLEMS

### Legend
- ✅ = Passed/Complete
- ❌ = Failed/Issues
- ⏭️ = Skipped (intentionally)
- ⚠️ = Warning/Partial
```

## Important Reminders

### BTRFS Snapshot (Phase S)
1. **DO NOT** proceed with audit if snapshot creation fails
2. **DO NOT** skip snapshots unless user explicitly passes `--skip-snapshot`
3. **DO NOT** create writable snapshots - always use `-r` for read-only
4. **DO** check filesystem type before attempting BTRFS operations
5. **DO** create human-readable .info files for each snapshot
6. **DO** include rollback and cleanup instructions in snapshot report
7. **DO** snapshot ALL subvolumes that will be modified (nested included)
8. **DO** verify snapshots are read-only after creation
9. **DO** use consistent naming: `audit-YYYYMMDD-HHMMSS-<project>[-subvol]`
10. **DO** report snapshot location at start of audit for easy rollback reference

### Pre-Flight (Phase 0)
11. **DO NOT** proceed if environment validation fails - fix first
12. **DO NOT** assume dependencies are installed - verify explicitly
13. **DO** check ALL required environment variables exist
14. **DO** verify service connectivity before testing
15. **DO** fail fast on environment issues

### Testing (Phases 1-3)
16. **DO NOT** just report "tests pass" - show evidence
17. **DO NOT** skip log checking - errors hide in logs
18. **DO NOT** test only happy paths - try edge cases
19. **DO NOT** assume previous state - verify current state
20. **DO** use actual test data, not mocks where possible
21. **DO** verify outputs at each stage
22. **DO** report specific file paths, line numbers, error messages

### Runtime Service Health (Phase 2a) - CRITICAL
23. **DO NOT** assume a "running" service is actually working - verify with process inspection
24. **DO NOT** skip checking for stuck sleep loops - this is a major bug pattern
25. **DO NOT** ignore services where >50% of child processes are sleeping
26. **DO NOT** assume ffmpeg/imagemagick/etc. have -y flag - always verify non-interactive compatibility
27. **DO** check for "overwrite? [y/N]" and "already exists" patterns in logs
28. **DO** verify active worker processes exist (ffmpeg, python, node, etc.)
29. **DO** check if output files are actually being created in last 5 minutes
30. **DO** check for "permission denied" errors that cascade to stuck processes
31. **DO** verify cross-service dependencies (if converter outputs to staging, mover must read from staging)
32. **DO** check for orphaned files in staging directories (>30min old = not being processed)
33. **DO** analyze service user permissions before assuming write access
34. **DO** detect when services are cycling through skip logic instead of processing

### Deprecation Cleanup (Phase 4)
35. **DO NOT** remove code without verifying zero references
36. **DO NOT** delete files that might be dynamically loaded
37. **DO** search entire codebase before removing anything
38. **DO** check for string-based/dynamic imports
39. **DO** remove associated tests when removing deprecated code
40. **DO** clean up orphaned configuration entries

### Deployment Version Mismatch Detection (Phase 4, Step 5-6)
41. **DO NOT** assume symlinks point to correct source - verify explicitly
42. **DO NOT** skip checking /usr/local/bin, /etc/systemd/system, /opt for stale deployments
43. **DO NOT** ignore line count differences - they indicate version mismatches
44. **DO** compare file modification dates to identify stale vs newer versions
45. **DO** check all symlinks resolve to existing, correct targets
46. **DO** verify systemd service files match project source
47. **DO** detect orphaned deployment files from previous installs
48. **DO** check for same-named files in different paths (e.g., /hddRaid1/Project vs /hddRaid1/ClaudeCodeProjects/Project)
49. **DO** report canonical source location when mismatches found
50. **DO** run `systemctl daemon-reload` recommendation when service files updated
51. **DO** flag any script installed from non-project-source locations

### Documentation (Phase 13 - FINAL)
52. **DO NOT** mark docs as "current" without verification
53. **DO NOT** leave references to removed features
54. **DO** test all code examples in documentation
55. **DO** verify all file paths mentioned actually exist
56. **DO** update version numbers and dates
57. **DO** ensure README reflects actual current functionality
58. **DO** fix or note all broken links

### Security (Phase 5)
59. **DO NOT** ignore hardcoded secrets - always report and fix
60. **DO NOT** skip dependency vulnerability scans
61. **DO** treat all security findings as high priority
62. **DO** check for OWASP Top 10 vulnerabilities
63. **DO** verify secrets are in environment variables, not code
64. **DO** check .gitignore for sensitive file patterns

### Dependencies (Phase 6)
65. **DO NOT** blindly update to latest versions - check compatibility
66. **DO NOT** leave unused dependencies in the project
67. **DO** check for security vulnerabilities in ALL dependencies
68. **DO** verify license compatibility
69. **DO** identify and document stale/unmaintained packages
70. **DO** prefer well-maintained alternatives for deprecated packages

### Code Quality (Phase 7)
71. **DO NOT** ignore linting errors - fix or explicitly acknowledge
72. **DO NOT** leave complexity hotspots undocumented
73. **DO** run all available linters for the project type
74. **DO** identify and report anti-patterns
75. **DO** inventory all TODO/FIXME/HACK comments
76. **DO** check type safety where applicable

### Test Coverage (Phase 8)
77. **DO NOT** accept 0% coverage on critical paths
78. **DO NOT** count dead code as "covered"
79. **DO** prioritize coverage for auth, payments, security code
80. **DO** identify branches and conditions never tested
81. **DO** recommend specific high-value tests to add

### Debugging (Phase 9)
82. **DO NOT** stop at the symptom - find the root cause
83. **DO NOT** guess - use evidence from stack traces and logs
84. **DO** classify failures by type (build/runtime/logic/env)
85. **DO** correlate failures with recent git changes
86. **DO** generate ranked hypotheses with confidence levels
87. **DO** provide specific, actionable fix recommendations

### Autonomous Fixing (Phase 10)
88. **DO NOT** apply fixes without verification
89. **DO NOT** batch fixes that might interact - fix sequentially
90. **DO** prioritize: build errors → security → tests → quality
91. **DO** rollback fixes that cause regressions (or use BTRFS snapshot)
92. **DO** document fixes that require manual intervention
93. **DO** re-run tests after each fix batch
94. **DO** use auto-fix tools (ruff --fix, eslint --fix, etc.)

### Configuration (Phase 11)
95. **DO NOT** skip config file syntax validation
96. **DO NOT** leave undocumented environment variables
97. **DO** compare .env with .env.example for consistency
98. **DO** verify no secrets in version control
99. **DO** check for debug mode enabled in production configs
100. **DO** validate environment-specific config consistency

### Final Verification (Phase 12)
101. **DO NOT** skip final verification after fixes
102. **DO NOT** consider audit complete until all tests pass
103. **DO** run full test suite after all fixes
104. **DO** verify build completes successfully
105. **DO** perform smoke test of core functionality
106. **DO** check for regressions introduced by fixes
107. **DO** generate comprehensive final report with all metrics
108. **DO** include snapshot cleanup instructions if audit successful

### Deployment Consistency Regression (Phase 12, Step 4a)
109. **DO NOT** skip deployment consistency check after fixes
110. **DO NOT** assume symlinks are still correct after code changes
111. **DO** re-verify all symlinks point to canonical project source
112. **DO** confirm service files still match after updates
113. **DO** detect any new orphaned deployment files created during audit
114. **DO** include deployment consistency status in final report

### Help Mode
115. **DO** check if first argument is "help" before starting audit
116. **DO** display complete help documentation when help is requested
117. **DO** exit immediately after displaying help (do not run audit)
118. **DO** include all phases, steps, options, and features in help output

### Output Logging
119. **DO NOT** skip creating output log file at audit start
120. **DO NOT** display output only to terminal - always log to file too
121. **DO** create output file with format: audit-YYYYMMDD-HHMMSS.log
122. **DO** include project name, path, and timestamps in log header
123. **DO** use `tee -a` or equivalent to dual-output all content
124. **DO** append final summary and completion status to log footer
125. **DO** announce log file location at start and end of audit

### Pristine Project
126. **DO NOT** consider audit complete if pristine violations remain
127. **DO NOT** skip Python environment health checks
128. **DO** check for stale __pycache__, .pyc, .pytest_cache artifacts
129. **DO** detect virtual environments older than 90 days
130. **DO** find and report .bak, .old, .orig, .swp backup files
131. **DO** identify unused imports with ruff or pylint
132. **DO** check for outdated dependencies with pip list --outdated
133. **DO** detect dead symlinks and orphaned config files
134. **DO** find empty directories (often remnants of deleted features)
135. **DO** report deprecated markers (@deprecated, TODO: remove)

### Human-Readable Output
136. **DO NOT** produce wall-of-text output - use visual separators
137. **DO NOT** mix errors with info - group by severity
138. **DO** use consistent emoji indicators (✅❌⚠️ℹ️🔄⏭️🔧👤)
139. **DO** format phase headers with box-drawing characters
140. **DO** use tables for summary data with aligned columns
141. **DO** include progress indicators for long-running phases
142. **DO** format critical issues with full context (type, location, evidence, impact, fix)
143. **DO** make output scannable - key info should be visible at a glance

### Cleanup (Phase C)
144. **DO** run cleanup phase after all other phases complete
145. **DO** deactivate sandbox and restore original PATH
146. **DO** remove mock command wrappers
147. **DO** remove sandbox directory if cleanup.remove_sandbox is true
148. **DO** remove temporary test artifacts (__pycache__, .coverage, etc.)
149. **DO** keep audit log files unless explicitly configured otherwise
150. **DO** suggest BTRFS snapshot cleanup if audit was successful
151. **DO** log all cleanup actions to the audit log
152. **DO** report any cleanup failures without failing the overall audit

---

## Phase C: Cleanup (Final Phase)

**This phase runs LAST** after all testing, fixing, and verification is complete. It cleans up all test artifacts and restores the environment.

### Step 1: Deactivate Sandbox

```bash
cleanup_sandbox() {
    echo ""
    echo "═══════════════════════════════════════════════════════════════════"
    echo "  PHASE C: CLEANUP"
    echo "═══════════════════════════════════════════════════════════════════"

    # Restore original PATH
    if [ -n "$ORIGINAL_PATH" ]; then
        export PATH="$ORIGINAL_PATH"
        echo "✅ Restored original PATH"
    fi

    # Unset sandbox variables
    unset SANDBOX_ACTIVE
    unset MOCK_LOG

    echo "✅ Sandbox deactivated"
}
```

### Step 2: Remove Sandbox Directory

```bash
remove_sandbox() {
    local REMOVE_SANDBOX="${CLEANUP_REMOVE_SANDBOX:-true}"

    if [ "$REMOVE_SANDBOX" = "true" ] && [ -d "$SANDBOX_DIR" ]; then
        # Kill any mock servers first
        if [ -f "$SANDBOX_DIR/mock_server.pid" ]; then
            kill $(cat "$SANDBOX_DIR/mock_server.pid") 2>/dev/null
            echo "✅ Stopped mock server"
        fi

        # Remove sandbox directory
        rm -rf "$SANDBOX_DIR"
        echo "✅ Removed sandbox: $SANDBOX_DIR"
    elif [ -d "$SANDBOX_DIR" ]; then
        echo "ℹ️  Sandbox preserved (cleanup.remove_sandbox: false)"
        echo "   Location: $SANDBOX_DIR"
    fi
}
```

### Step 3: Remove Temporary Test Files

```bash
remove_temp_files() {
    local REMOVE_TEMP="${CLEANUP_REMOVE_TEMP:-true}"

    if [ "$REMOVE_TEMP" != "true" ]; then
        echo "ℹ️  Temporary files preserved (cleanup.remove_temp_files: false)"
        return 0
    fi

    echo "🧹 Cleaning temporary test files..."

    # Python artifacts
    find "$PROJECT_DIR" -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null
    find "$PROJECT_DIR" -type f -name "*.pyc" -delete 2>/dev/null
    find "$PROJECT_DIR" -type d -name ".pytest_cache" -exec rm -rf {} + 2>/dev/null
    find "$PROJECT_DIR" -type d -name ".mypy_cache" -exec rm -rf {} + 2>/dev/null
    find "$PROJECT_DIR" -type d -name ".ruff_cache" -exec rm -rf {} + 2>/dev/null
    rm -f "$PROJECT_DIR/.coverage" 2>/dev/null
    rm -f "$PROJECT_DIR/coverage.xml" 2>/dev/null
    rm -rf "$PROJECT_DIR/htmlcov" 2>/dev/null

    # Node.js artifacts
    rm -rf "$PROJECT_DIR/node_modules/.cache" 2>/dev/null
    rm -rf "$PROJECT_DIR/.npm" 2>/dev/null

    # Go artifacts
    rm -f "$PROJECT_DIR/coverage.out" 2>/dev/null

    # Rust artifacts (but keep target for builds)
    # Only clean debug build artifacts, not release
    # rm -rf "$PROJECT_DIR/target/debug/.fingerprint" 2>/dev/null

    # General
    rm -f "$PROJECT_DIR/coverage.json" 2>/dev/null
    rm -rf "$PROJECT_DIR/coverage" 2>/dev/null

    echo "✅ Temporary files cleaned"
}
```

### Step 4: BTRFS Snapshot Cleanup Guidance

```bash
suggest_snapshot_cleanup() {
    local AUDIT_STATUS="${AUDIT_STATUS:-unknown}"
    local SNAPSHOT_PATH="${SNAPSHOT_PATH:-}"

    echo ""
    echo "───────────────────────────────────────────────────────────────────"
    echo "  BTRFS SNAPSHOT CLEANUP"
    echo "───────────────────────────────────────────────────────────────────"

    if [ -z "$SNAPSHOT_PATH" ]; then
        echo "ℹ️  No snapshot was created (--skip-snapshot or non-BTRFS)"
        return 0
    fi

    if [ "$AUDIT_STATUS" = "success" ]; then
        echo "✅ Audit completed successfully"
        echo ""
        echo "   The pre-audit snapshot is no longer needed."
        echo "   To reclaim disk space, run:"
        echo ""
        echo "   sudo btrfs subvolume delete $SNAPSHOT_PATH"
        echo "   rm ${SNAPSHOT_PATH}.info"
        echo ""
    else
        echo "⚠️  Audit had issues or was interrupted"
        echo ""
        echo "   Consider keeping the snapshot for potential rollback."
        echo "   Snapshot location: $SNAPSHOT_PATH"
        echo ""
        echo "   To rollback to pre-audit state:"
        echo "   sudo btrfs subvolume delete $PROJECT_DIR"
        echo "   sudo btrfs subvolume snapshot $SNAPSHOT_PATH $PROJECT_DIR"
        echo ""
    fi
}
```

### Step 5: Cleanup Summary

```bash
cleanup_summary() {
    echo ""
    echo "═══════════════════════════════════════════════════════════════════"
    echo "  CLEANUP COMPLETE"
    echo "═══════════════════════════════════════════════════════════════════"
    echo ""
    echo "  Actions performed:"
    echo "  ✅ Sandbox deactivated"
    [ "$CLEANUP_REMOVE_SANDBOX" = "true" ] && echo "  ✅ Sandbox directory removed"
    [ "$CLEANUP_REMOVE_TEMP" = "true" ] && echo "  ✅ Temporary test files cleaned"
    [ "$CLEANUP_KEEP_LOGS" = "true" ] && echo "  ✅ Audit logs preserved"
    echo ""
    echo "  Audit log saved to: $OUTPUT_FILE"
    echo ""
}
```

### Cleanup Report

```markdown
## Phase C: Cleanup Report

### Actions Performed
| Action | Status | Details |
|--------|--------|---------|
| Sandbox deactivated | ✅ | PATH restored to original |
| Mock servers stopped | ✅ | PID file cleaned up |
| Sandbox removed | ✅/⏭️ | ${SANDBOX_DIR} |
| Temp files cleaned | ✅/⏭️ | __pycache__, .coverage, etc. |
| Logs preserved | ✅ | ${OUTPUT_FILE} |

### BTRFS Snapshot Status
| Snapshot | Status | Recommendation |
|----------|--------|----------------|
| ${SNAPSHOT_PATH} | [exists/deleted] | [keep for rollback/delete to reclaim space] |

### Environment Status
- PATH: Restored to original
- Sandbox: Deactivated
- Mock commands: Removed
- Working directory: Clean

### Cleanup Status: ✅ COMPLETE
```

---

## Complete Execution Order

The /test skill executes phases in this order:

```
1. PHASE S:  BTRFS Snapshot (safety backup)
2. PHASE M:  Safe Mocking Setup (sandbox creation)
3. PHASE 0:  Pre-Flight Checks (environment validation)
4. PHASE 1:  Discovery (identify testable components)
5. PHASE 2:  Execute Tests (run actual operations)
6. PHASE 2a: Runtime Service Health (detect stuck processes)
7. PHASE 3:  Report Results (detailed test reports)
8. PHASE 8:  Test Coverage Analysis (moved earlier to inform fixes)
           └─ Step 6: 85% Coverage Enforcement
9. PHASE 9:  Debugging (analyze failures)
10. PHASE 4:  Deprecation Cleanup (remove dead code)
11. PHASE 5:  Security Audit (scan vulnerabilities)
12. PHASE 6:  Dependency Health (check packages)
13. PHASE 7:  Code Quality (linting, complexity)
14. PHASE 10: Auto-Fixing (apply fixes)
15. PHASE 11: Configuration Audit (validate configs)
16. PHASE 12: Final Verification (re-run all checks)
17. PHASE 13: Documentation (update docs - FINAL content phase)
18. PHASE C:  Cleanup (restore environment - FINAL phase)
```

Each phase builds on findings from previous phases for comprehensive coverage.
