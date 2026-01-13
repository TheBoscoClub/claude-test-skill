# Phase A: Deployable Application Testing

## Purpose

Test the project's **deployable/installable application** separately from the source code. This ensures end users have a smooth experience with installation, updates, and migrations.

## When to Run This Phase

Run this phase when the project has:
- An install script (`install.sh`, `setup.py install`, `npm install -g`, etc.)
- A deploy script (`deploy.sh`)
- Systemd service files
- Docker deployment
- Package distribution (`pip`, `npm`, `cargo install`, etc.)

**Skip this phase if**: The project is a library-only or has no standalone deployment.

## Detection Script

```bash
# Detect if project has deployable application
detect_deployable_app() {
    local PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
    local HAS_DEPLOY=false
    local DEPLOY_TYPE=""

    # Check for install scripts
    if [[ -f "$PROJECT_DIR/install.sh" ]]; then
        HAS_DEPLOY=true
        DEPLOY_TYPE="shell-installer"
    elif [[ -f "$PROJECT_DIR/setup.py" ]] && grep -q "entry_points\|scripts" "$PROJECT_DIR/setup.py" 2>/dev/null; then
        HAS_DEPLOY=true
        DEPLOY_TYPE="python-package"
    elif [[ -f "$PROJECT_DIR/package.json" ]] && jq -e '.bin' "$PROJECT_DIR/package.json" >/dev/null 2>&1; then
        HAS_DEPLOY=true
        DEPLOY_TYPE="npm-package"
    elif [[ -f "$PROJECT_DIR/Cargo.toml" ]] && grep -q "\[\[bin\]\]" "$PROJECT_DIR/Cargo.toml" 2>/dev/null; then
        HAS_DEPLOY=true
        DEPLOY_TYPE="rust-binary"
    elif [[ -d "$PROJECT_DIR/systemd" ]] || [[ -d "$PROJECT_DIR/services" ]]; then
        HAS_DEPLOY=true
        DEPLOY_TYPE="systemd-service"
    elif [[ -f "$PROJECT_DIR/Dockerfile" ]] || [[ -f "$PROJECT_DIR/docker-compose.yml" ]]; then
        HAS_DEPLOY=true
        DEPLOY_TYPE="docker"
    elif [[ -f "$PROJECT_DIR/deploy.sh" ]]; then
        HAS_DEPLOY=true
        DEPLOY_TYPE="deploy-script"
    fi

    if $HAS_DEPLOY; then
        echo "$DEPLOY_TYPE"
        return 0
    else
        return 1
    fi
}
```

## Step 1: Create Sandbox Installation Environment

```bash
setup_app_sandbox() {
    local PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
    local SANDBOX_BASE="${SANDBOX_DIR:-/tmp/claude-test-sandbox-$(basename $PROJECT_DIR)}"
    local APP_SANDBOX="${SANDBOX_BASE}/app-install"

    echo "═══════════════════════════════════════════════════════════════════"
    echo "  PHASE A: DEPLOYABLE APPLICATION TESTING"
    echo "═══════════════════════════════════════════════════════════════════"
    echo ""
    echo "Creating isolated sandbox for application testing..."
    echo "Sandbox: $APP_SANDBOX"
    echo ""

    # Create sandbox directory structure
    mkdir -p "$APP_SANDBOX"/{bin,lib,etc,var/log,var/run,home/testuser}
    mkdir -p "$APP_SANDBOX/systemd/user"

    # Create mock home directory
    export TEST_HOME="$APP_SANDBOX/home/testuser"
    export TEST_PREFIX="$APP_SANDBOX"

    # Create environment for sandboxed install
    cat > "$APP_SANDBOX/env.sh" << 'ENVEOF'
export HOME="$TEST_HOME"
export PREFIX="$TEST_PREFIX"
export PATH="$TEST_PREFIX/bin:$PATH"
export XDG_CONFIG_HOME="$TEST_HOME/.config"
export XDG_DATA_HOME="$TEST_HOME/.local/share"
export SANDBOX_MODE=true
ENVEOF

    echo "✅ Sandbox created: $APP_SANDBOX"
    echo ""
}
```

## Step 2: Test Installation

```bash
test_installation() {
    local PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
    local DEPLOY_TYPE="$1"
    local APP_SANDBOX="${SANDBOX_BASE}/app-install"
    local ISSUES_FILE="${PROJECT_DIR}/app-test-issues.log"

    echo "───────────────────────────────────────────────────────────────────"
    echo "  Step 2: Testing Installation ($DEPLOY_TYPE)"
    echo "───────────────────────────────────────────────────────────────────"
    echo ""

    # Initialize issues file
    echo "# Application Test Issues - $(date '+%Y-%m-%d %H:%M:%S')" > "$ISSUES_FILE"
    echo "" >> "$ISSUES_FILE"

    # Source sandbox environment
    source "$APP_SANDBOX/env.sh"

    case "$DEPLOY_TYPE" in
        shell-installer)
            echo "Testing shell installer..."
            # Run install script with sandbox prefix
            if ! timeout 300 bash "$PROJECT_DIR/install.sh" --user --data-dir "$APP_SANDBOX/data" 2>&1 | tee -a "$ISSUES_FILE.install.log"; then
                echo "❌ INSTALL FAILED" >> "$ISSUES_FILE"
                echo "See: $ISSUES_FILE.install.log" >> "$ISSUES_FILE"
                return 1
            fi
            ;;
        python-package)
            echo "Testing Python package installation..."
            pip install --user --prefix="$APP_SANDBOX" "$PROJECT_DIR" 2>&1 | tee -a "$ISSUES_FILE.install.log"
            ;;
        npm-package)
            echo "Testing npm package installation..."
            npm install --prefix="$APP_SANDBOX" "$PROJECT_DIR" 2>&1 | tee -a "$ISSUES_FILE.install.log"
            ;;
        docker)
            echo "Testing Docker build..."
            docker build -t "test-app-$(basename $PROJECT_DIR)" "$PROJECT_DIR" 2>&1 | tee -a "$ISSUES_FILE.install.log"
            ;;
        *)
            echo "Unknown deploy type: $DEPLOY_TYPE"
            ;;
    esac

    # Check for common installation issues
    echo ""
    echo "Checking for installation issues..."

    # Check if binaries were created
    if [[ -z "$(ls -A $APP_SANDBOX/bin 2>/dev/null)" ]]; then
        echo "⚠️ WARNING: No binaries installed to $APP_SANDBOX/bin" | tee -a "$ISSUES_FILE"
    fi

    # Check for permission issues
    find "$APP_SANDBOX" -type f ! -executable -name "*.sh" 2>/dev/null | while read f; do
        echo "⚠️ Script not executable: $f" | tee -a "$ISSUES_FILE"
    done

    echo "✅ Installation test complete"
}
```

## Step 3: Test Application Functionality

```bash
test_app_functionality() {
    local APP_SANDBOX="${SANDBOX_BASE}/app-install"
    local ISSUES_FILE="${PROJECT_DIR}/app-test-issues.log"

    echo ""
    echo "───────────────────────────────────────────────────────────────────"
    echo "  Step 3: Testing Application Functionality"
    echo "───────────────────────────────────────────────────────────────────"
    echo ""

    source "$APP_SANDBOX/env.sh"

    # Find installed commands
    local COMMANDS=($(ls "$APP_SANDBOX/bin" 2>/dev/null))

    if [[ ${#COMMANDS[@]} -eq 0 ]]; then
        echo "⚠️ No commands found to test"
        return 0
    fi

    for cmd in "${COMMANDS[@]}"; do
        echo "Testing command: $cmd"

        # Test --help
        if "$APP_SANDBOX/bin/$cmd" --help >/dev/null 2>&1; then
            echo "  ✅ --help works"
        else
            echo "  ❌ --help failed" | tee -a "$ISSUES_FILE"
        fi

        # Test --version if available
        if "$APP_SANDBOX/bin/$cmd" --version >/dev/null 2>&1; then
            echo "  ✅ --version works"
        fi

        # Test without arguments (should give usage, not crash)
        if timeout 5 "$APP_SANDBOX/bin/$cmd" 2>&1 | head -5 >/dev/null; then
            echo "  ✅ Runs without crash"
        else
            echo "  ⚠️ May have issues running without arguments" | tee -a "$ISSUES_FILE"
        fi
    done
}
```

## Step 4: Test Upgrade Path

```bash
test_upgrade() {
    local PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
    local APP_SANDBOX="${SANDBOX_BASE}/app-install"
    local ISSUES_FILE="${PROJECT_DIR}/app-test-issues.log"

    echo ""
    echo "───────────────────────────────────────────────────────────────────"
    echo "  Step 4: Testing Upgrade Path"
    echo "───────────────────────────────────────────────────────────────────"
    echo ""

    # Check if upgrade script exists
    if [[ -f "$PROJECT_DIR/upgrade.sh" ]]; then
        echo "Testing upgrade script..."

        # Simulate upgrade from installed version
        if timeout 300 bash "$PROJECT_DIR/upgrade.sh" --target "$APP_SANDBOX" --dry-run 2>&1 | tee -a "$ISSUES_FILE.upgrade.log"; then
            echo "✅ Upgrade dry-run successful"
        else
            echo "❌ Upgrade script has issues" | tee -a "$ISSUES_FILE"
        fi
    else
        echo "ℹ️ No upgrade.sh found - skipping upgrade test"
    fi
}
```

## Step 5: Test Migration Paths

```bash
test_migration() {
    local PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
    local ISSUES_FILE="${PROJECT_DIR}/app-test-issues.log"

    echo ""
    echo "───────────────────────────────────────────────────────────────────"
    echo "  Step 5: Testing Migration Paths"
    echo "───────────────────────────────────────────────────────────────────"
    echo ""

    # Find migration scripts
    local MIGRATION_SCRIPTS=($(find "$PROJECT_DIR" -name "migrate*.sh" -o -name "*-migration.sh" 2>/dev/null))

    if [[ ${#MIGRATION_SCRIPTS[@]} -eq 0 ]]; then
        echo "ℹ️ No migration scripts found"
        return 0
    fi

    for script in "${MIGRATION_SCRIPTS[@]}"; do
        local script_name=$(basename "$script")
        echo "Testing: $script_name"

        # Check syntax
        if bash -n "$script" 2>&1; then
            echo "  ✅ Syntax valid"
        else
            echo "  ❌ Syntax error" | tee -a "$ISSUES_FILE"
        fi

        # Check for help/dry-run support
        if grep -q "\-\-help\|\-\-dry-run" "$script"; then
            echo "  ✅ Has help/dry-run options"
        else
            echo "  ⚠️ No --help or --dry-run option" | tee -a "$ISSUES_FILE"
        fi
    done
}
```

## Step 6: Performance and Race Condition Testing

```bash
test_performance() {
    local APP_SANDBOX="${SANDBOX_BASE}/app-install"
    local ISSUES_FILE="${PROJECT_DIR}/app-test-issues.log"

    echo ""
    echo "───────────────────────────────────────────────────────────────────"
    echo "  Step 6: Performance & Race Condition Testing"
    echo "───────────────────────────────────────────────────────────────────"
    echo ""

    source "$APP_SANDBOX/env.sh"

    # Find main command
    local MAIN_CMD=$(ls "$APP_SANDBOX/bin" 2>/dev/null | head -1)

    if [[ -z "$MAIN_CMD" ]]; then
        echo "⚠️ No command to test"
        return 0
    fi

    # Startup time test
    echo "Testing startup time..."
    local START_TIME=$(date +%s%N)
    timeout 10 "$APP_SANDBOX/bin/$MAIN_CMD" --help >/dev/null 2>&1
    local END_TIME=$(date +%s%N)
    local STARTUP_MS=$(( (END_TIME - START_TIME) / 1000000 ))

    if [[ $STARTUP_MS -gt 5000 ]]; then
        echo "  ⚠️ Slow startup: ${STARTUP_MS}ms (>5s)" | tee -a "$ISSUES_FILE"
    elif [[ $STARTUP_MS -gt 1000 ]]; then
        echo "  ⚠️ Moderate startup: ${STARTUP_MS}ms"
    else
        echo "  ✅ Fast startup: ${STARTUP_MS}ms"
    fi

    # Concurrent execution test (race conditions)
    echo ""
    echo "Testing concurrent execution..."
    for i in {1..3}; do
        timeout 5 "$APP_SANDBOX/bin/$MAIN_CMD" --help &
    done
    wait

    # Check for lock files or PID files left behind
    local STALE_LOCKS=$(find "$APP_SANDBOX" -name "*.lock" -o -name "*.pid" 2>/dev/null)
    if [[ -n "$STALE_LOCKS" ]]; then
        echo "  ⚠️ Stale lock/pid files after concurrent run:" | tee -a "$ISSUES_FILE"
        echo "$STALE_LOCKS" | tee -a "$ISSUES_FILE"
    else
        echo "  ✅ No stale locks after concurrent execution"
    fi
}
```

## Step 7: Usability Audit

```bash
test_usability() {
    local PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
    local ISSUES_FILE="${PROJECT_DIR}/app-test-issues.log"

    echo ""
    echo "───────────────────────────────────────────────────────────────────"
    echo "  Step 7: Usability Audit"
    echo "───────────────────────────────────────────────────────────────────"
    echo ""

    # Check install script UX
    if [[ -f "$PROJECT_DIR/install.sh" ]]; then
        echo "Auditing install.sh UX..."

        # Check for help option
        if grep -q "\-\-help" "$PROJECT_DIR/install.sh"; then
            echo "  ✅ Has --help option"
        else
            echo "  ⚠️ Missing --help option" | tee -a "$ISSUES_FILE"
        fi

        # Check for dry-run option
        if grep -q "\-\-dry-run" "$PROJECT_DIR/install.sh"; then
            echo "  ✅ Has --dry-run option"
        else
            echo "  ⚠️ Missing --dry-run option" | tee -a "$ISSUES_FILE"
        fi

        # Check for uninstall option
        if grep -q "\-\-uninstall\|uninstall" "$PROJECT_DIR/install.sh"; then
            echo "  ✅ Has uninstall capability"
        else
            echo "  ⚠️ No uninstall option" | tee -a "$ISSUES_FILE"
        fi

        # Check for non-interactive mode
        if grep -q "read -r\|read -p" "$PROJECT_DIR/install.sh"; then
            if grep -q "\-\-yes\|\-y\|--non-interactive" "$PROJECT_DIR/install.sh"; then
                echo "  ✅ Has non-interactive mode"
            else
                echo "  ⚠️ Has prompts but no --yes flag for automation" | tee -a "$ISSUES_FILE"
            fi
        fi

        # Check for progress feedback
        if grep -qE "echo.*\.\.\.|printf.*\.\.\.|spinner|progress" "$PROJECT_DIR/install.sh"; then
            echo "  ✅ Has progress feedback"
        else
            echo "  ⚠️ Limited progress feedback during install" | tee -a "$ISSUES_FILE"
        fi
    fi

    # Check for README installation docs
    if [[ -f "$PROJECT_DIR/README.md" ]]; then
        if grep -qi "install\|setup\|getting started" "$PROJECT_DIR/README.md"; then
            echo "  ✅ README has installation section"
        else
            echo "  ⚠️ README lacks installation instructions" | tee -a "$ISSUES_FILE"
        fi
    fi
}
```

## Step 8: Generate Issues Report

```bash
generate_app_issues_report() {
    local PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
    local ISSUES_FILE="${PROJECT_DIR}/app-test-issues.log"

    echo ""
    echo "═══════════════════════════════════════════════════════════════════"
    echo "  PHASE A: APPLICATION TEST SUMMARY"
    echo "═══════════════════════════════════════════════════════════════════"
    echo ""

    if [[ -f "$ISSUES_FILE" ]] && [[ $(wc -l < "$ISSUES_FILE") -gt 2 ]]; then
        local ISSUE_COUNT=$(grep -c "❌\|⚠️" "$ISSUES_FILE" 2>/dev/null || echo 0)
        echo "Issues found: $ISSUE_COUNT"
        echo ""
        echo "Issues recorded to: $ISSUES_FILE"
        echo ""
        cat "$ISSUES_FILE"
        echo ""
        echo "───────────────────────────────────────────────────────────────────"
        echo ""
        echo "To fix these issues, address each item in the issues file,"
        echo "then re-run: /test --phase=A"
        echo ""
        return 1
    else
        echo "✅ All application tests passed!"
        rm -f "$ISSUES_FILE" 2>/dev/null
        return 0
    fi
}
```

## Phase A Execution Order

```bash
run_phase_A() {
    local PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
    local PHASE_A_RESULT=0

    # Detect deployable app
    local DEPLOY_TYPE=$(detect_deployable_app)
    if [[ $? -ne 0 ]]; then
        echo "ℹ️ No deployable application detected - skipping Phase A"
        return 0
    fi

    echo "Detected deployment type: $DEPLOY_TYPE"

    # CRITICAL: Ensure cleanup runs even if tests fail or script is interrupted
    trap 'cleanup_app_sandbox' EXIT

    # Run all steps
    setup_app_sandbox
    test_installation "$DEPLOY_TYPE" || PHASE_A_RESULT=1
    test_app_functionality || PHASE_A_RESULT=1
    test_upgrade || PHASE_A_RESULT=1
    test_migration || PHASE_A_RESULT=1
    test_performance || PHASE_A_RESULT=1
    test_usability || PHASE_A_RESULT=1
    generate_app_issues_report || PHASE_A_RESULT=1

    # Cleanup runs automatically via trap, but also call explicitly
    # to ensure it runs before generating final report
    cleanup_app_sandbox

    # Remove trap since we already cleaned up
    trap - EXIT

    return $PHASE_A_RESULT
}
```

## Cleanup (MANDATORY)

**This cleanup MUST run at the end of Phase A, even if tests fail.**

```bash
cleanup_app_sandbox() {
    local PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
    local SANDBOX_BASE="${SANDBOX_DIR:-/tmp/claude-test-sandbox-$(basename $PROJECT_DIR)}"
    local APP_SANDBOX="${SANDBOX_BASE}/app-install"

    echo ""
    echo "═══════════════════════════════════════════════════════════════════"
    echo "  PHASE A CLEANUP"
    echo "═══════════════════════════════════════════════════════════════════"
    echo ""

    # ─────────────────────────────────────────────────────────────────
    # 1. STOP BACKGROUND PROCESSES started during testing
    # ─────────────────────────────────────────────────────────────────

    # Stop any processes running from sandbox bin directory
    if [[ -d "$APP_SANDBOX/bin" ]]; then
        for bin in "$APP_SANDBOX/bin"/*; do
            if [[ -x "$bin" ]]; then
                local bin_name=$(basename "$bin")
                # Find and gracefully stop processes
                pgrep -f "$APP_SANDBOX/bin/$bin_name" 2>/dev/null | while read pid; do
                    echo "Stopping sandbox process: $bin_name (PID: $pid)"
                    kill -TERM "$pid" 2>/dev/null
                    sleep 1
                    kill -0 "$pid" 2>/dev/null && kill -KILL "$pid" 2>/dev/null
                done
            fi
        done
    fi

    # Stop any test services that might be running
    if [[ -d "$APP_SANDBOX/systemd/user" ]]; then
        for service in "$APP_SANDBOX/systemd/user"/*.service; do
            if [[ -f "$service" ]]; then
                local svc_name=$(basename "$service")
                systemctl --user stop "$svc_name" 2>/dev/null || true
            fi
        done
    fi

    # ─────────────────────────────────────────────────────────────────
    # 2. REMOVE SANDBOX DIRECTORY
    # ─────────────────────────────────────────────────────────────────

    if [[ -d "$APP_SANDBOX" ]]; then
        echo "Removing sandbox: $APP_SANDBOX"
        rm -rf "$APP_SANDBOX"
        echo "✅ Sandbox removed"
    fi

    # Also clean any orphaned test sandboxes older than 1 hour
    find /tmp -maxdepth 1 -name "claude-test-sandbox-*" -type d -mmin +60 2>/dev/null | while read old_sandbox; do
        echo "Removing stale sandbox: $old_sandbox"
        rm -rf "$old_sandbox"
    done

    # ─────────────────────────────────────────────────────────────────
    # 3. CLEANUP TEST ARTIFACTS
    # ─────────────────────────────────────────────────────────────────

    # Remove temporary log files created during testing
    rm -f "$PROJECT_DIR"/*.install.log 2>/dev/null

    echo ""
    echo "✅ Phase A cleanup complete"
}
```

## Report Format

```markdown
## Phase A: Application Testing Report

### Deployment Detection
| Attribute | Value |
|-----------|-------|
| Deploy Type | [shell-installer/python-package/npm-package/docker/...] |
| Install Script | [path or N/A] |
| Upgrade Script | [path or N/A] |
| Migration Scripts | [count] |

### Test Results
| Test | Status | Details |
|------|--------|---------|
| Installation | ✅/❌ | [details] |
| Functionality | ✅/❌ | [details] |
| Upgrade Path | ✅/❌ | [details] |
| Migration | ✅/❌ | [details] |
| Performance | ✅/⚠️/❌ | Startup: Xms |
| Usability | ✅/⚠️/❌ | [missing features] |

### Issues Found
[List from app-test-issues.log]

### Recommendations
- [ ] [Fix 1]
- [ ] [Fix 2]

### Phase A Status: ✅ PASS / ❌ ISSUES FOUND (see app-test-issues.log)
```
