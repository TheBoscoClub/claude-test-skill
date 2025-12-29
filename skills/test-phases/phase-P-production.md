# Phase P: Production Validation

## Purpose

Validate that a project's **installed production application** is running correctly on the system. This phase compares the expected installation state (from manifest + install script analysis) against the actual system state.

**Key Difference from Phase A:**
- Phase A: Tests installation *in a sandbox* - "does the install process work?"
- Phase P: Validates *live production* - "is the installed app healthy on this system?"

## When to Run This Phase

Run after:
- Running a project's `install.sh` or equivalent
- Deploying services via systemd
- Any production deployment

**Prerequisites**: The application must already be installed on the system.

## Manifest File: `install-manifest.json`

Projects should provide an `install-manifest.json` describing expected installation state:

```json
{
  "name": "my-app",
  "version": "1.0.0",
  "install_type": "user",

  "binaries": [
    {
      "name": "my-app",
      "paths": ["~/.local/bin/my-app", "/usr/local/bin/my-app"],
      "version_flag": "--version",
      "health_check": "my-app --health"
    }
  ],

  "services": [
    {
      "name": "my-app.service",
      "type": "user",
      "expected_state": "active",
      "health_endpoint": "http://localhost:8080/health"
    }
  ],

  "config_files": [
    {
      "path": "~/.config/my-app/config.yml",
      "required": true,
      "validate_command": "my-app config validate"
    }
  ],

  "data_directories": [
    {
      "path": "~/.local/share/my-app",
      "required": true,
      "min_permissions": "700"
    }
  ],

  "environment": {
    "required_vars": ["MY_APP_HOME"],
    "optional_vars": ["MY_APP_DEBUG"]
  },

  "ports": [
    {
      "port": 8080,
      "protocol": "tcp",
      "service": "my-app.service"
    }
  ],

  "health_checks": [
    {
      "name": "API responding",
      "command": "curl -sf http://localhost:8080/health",
      "timeout": 5
    }
  ]
}
```

## Step 1: Load Manifest and Analyze Install Script

```bash
load_production_manifest() {
    local PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
    local MANIFEST_FILE=""

    echo "═══════════════════════════════════════════════════════════════════"
    echo "  PHASE P: PRODUCTION VALIDATION"
    echo "═══════════════════════════════════════════════════════════════════"
    echo ""

    # Find manifest file
    for candidate in "install-manifest.json" ".install-manifest.json" "manifest.json"; do
        if [[ -f "$PROJECT_DIR/$candidate" ]]; then
            MANIFEST_FILE="$PROJECT_DIR/$candidate"
            break
        fi
    done

    if [[ -n "$MANIFEST_FILE" ]]; then
        echo "✅ Found manifest: $MANIFEST_FILE"
        export PROD_MANIFEST="$MANIFEST_FILE"

        # Extract key fields
        export APP_NAME=$(jq -r '.name // "unknown"' "$MANIFEST_FILE")
        export INSTALL_TYPE=$(jq -r '.install_type // "user"' "$MANIFEST_FILE")
        echo "   App: $APP_NAME"
        echo "   Install type: $INSTALL_TYPE"
    else
        echo "⚠️ No manifest found - will infer from install script"
        export PROD_MANIFEST=""

        # Try to infer app name from project directory
        export APP_NAME=$(basename "$PROJECT_DIR" | tr '[:upper:]' '[:lower:]')
    fi
    echo ""
}

analyze_install_script() {
    local PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
    local INSTALL_SCRIPT="$PROJECT_DIR/install.sh"
    local INFERRED_FILE="/tmp/phase-p-inferred-$$.json"

    echo "───────────────────────────────────────────────────────────────────"
    echo "  Analyzing Install Script"
    echo "───────────────────────────────────────────────────────────────────"
    echo ""

    if [[ ! -f "$INSTALL_SCRIPT" ]]; then
        echo "ℹ️ No install.sh found"
        return 0
    fi

    echo "Parsing: $INSTALL_SCRIPT"
    echo ""

    # Initialize inferred data
    local INFERRED_BINS=()
    local INFERRED_SERVICES=()
    local INFERRED_CONFIGS=()
    local INFERRED_PREFIX=""

    # Extract PREFIX/install location
    INFERRED_PREFIX=$(grep -oP '(?<=PREFIX=["'"'"']?)[^"'"'"'\s]+' "$INSTALL_SCRIPT" | head -1)
    if [[ -z "$INFERRED_PREFIX" ]]; then
        INFERRED_PREFIX=$(grep -oP '(?<=INSTALL_DIR=["'"'"']?)[^"'"'"'\s]+' "$INSTALL_SCRIPT" | head -1)
    fi
    echo "  Inferred PREFIX: ${INFERRED_PREFIX:-~/.local}"

    # Extract binary installations (cp/install commands to bin/)
    while IFS= read -r line; do
        local bin_name=$(echo "$line" | grep -oP '[\w-]+(?=\s*$)' | head -1)
        if [[ -n "$bin_name" ]]; then
            INFERRED_BINS+=("$bin_name")
        fi
    done < <(grep -E 'cp.*bin/|install.*bin/' "$INSTALL_SCRIPT" 2>/dev/null)

    # Extract systemd service names
    while IFS= read -r service; do
        INFERRED_SERVICES+=("$service")
    done < <(grep -oP '[\w-]+\.service' "$INSTALL_SCRIPT" 2>/dev/null | sort -u)

    # Also check systemd directory in project
    if [[ -d "$PROJECT_DIR/systemd" ]]; then
        while IFS= read -r service_file; do
            local svc=$(basename "$service_file")
            if [[ ! " ${INFERRED_SERVICES[*]} " =~ " ${svc} " ]]; then
                INFERRED_SERVICES+=("$svc")
            fi
        done < <(find "$PROJECT_DIR/systemd" -name "*.service" 2>/dev/null)
    fi

    # Extract config file paths
    while IFS= read -r config; do
        INFERRED_CONFIGS+=("$config")
    done < <(grep -oP '(?<=\.config/)[^\s"'"'"']+' "$INSTALL_SCRIPT" 2>/dev/null | sort -u)

    echo "  Inferred binaries: ${INFERRED_BINS[*]:-none}"
    echo "  Inferred services: ${INFERRED_SERVICES[*]:-none}"
    echo "  Inferred configs: ${INFERRED_CONFIGS[*]:-none}"
    echo ""

    # Export for later steps
    export INFERRED_PREFIX="${INFERRED_PREFIX:-$HOME/.local}"
    export INFERRED_BINS="${INFERRED_BINS[*]}"
    export INFERRED_SERVICES="${INFERRED_SERVICES[*]}"
    export INFERRED_CONFIGS="${INFERRED_CONFIGS[*]}"
}
```

## Step 2: Validate Installed Binaries

```bash
validate_binaries() {
    local PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
    local ISSUES_FILE="${PROJECT_DIR}/production-issues.log"

    echo "───────────────────────────────────────────────────────────────────"
    echo "  Step 2: Validating Installed Binaries"
    echo "───────────────────────────────────────────────────────────────────"
    echo ""

    local BINARIES=()
    local FOUND=0
    local MISSING=0

    # Get binaries from manifest or inferred
    if [[ -n "$PROD_MANIFEST" ]]; then
        while IFS= read -r bin; do
            BINARIES+=("$bin")
        done < <(jq -r '.binaries[].name // empty' "$PROD_MANIFEST" 2>/dev/null)
    fi

    # Add inferred binaries
    for bin in $INFERRED_BINS; do
        if [[ ! " ${BINARIES[*]} " =~ " ${bin} " ]]; then
            BINARIES+=("$bin")
        fi
    done

    if [[ ${#BINARIES[@]} -eq 0 ]]; then
        echo "ℹ️ No binaries to validate"
        return 0
    fi

    for bin in "${BINARIES[@]}"; do
        echo -n "  $bin: "

        # Check multiple possible locations
        local bin_path=""
        for loc in "$HOME/.local/bin/$bin" "/usr/local/bin/$bin" "/usr/bin/$bin" "$INFERRED_PREFIX/bin/$bin"; do
            loc=$(eval echo "$loc")  # Expand ~
            if [[ -x "$loc" ]]; then
                bin_path="$loc"
                break
            fi
        done

        # Also try which
        if [[ -z "$bin_path" ]]; then
            bin_path=$(which "$bin" 2>/dev/null)
        fi

        if [[ -n "$bin_path" ]]; then
            echo "✅ Found at $bin_path"
            ((FOUND++))

            # Try to get version
            if "$bin_path" --version &>/dev/null; then
                local ver=$("$bin_path" --version 2>&1 | head -1)
                echo "     Version: $ver"
            fi

            # Run health check if defined in manifest
            if [[ -n "$PROD_MANIFEST" ]]; then
                local health_cmd=$(jq -r --arg b "$bin" '.binaries[] | select(.name == $b) | .health_check // empty' "$PROD_MANIFEST")
                if [[ -n "$health_cmd" ]]; then
                    if eval "$health_cmd" &>/dev/null; then
                        echo "     Health: ✅ Passed"
                    else
                        echo "     Health: ❌ Failed" | tee -a "$ISSUES_FILE"
                    fi
                fi
            fi
        else
            echo "❌ NOT FOUND"
            echo "Binary not found: $bin" >> "$ISSUES_FILE"
            ((MISSING++))
        fi
    done

    echo ""
    echo "  Summary: $FOUND found, $MISSING missing"
    echo ""
}
```

## Step 3: Validate Running Services

```bash
validate_services() {
    local PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
    local ISSUES_FILE="${PROJECT_DIR}/production-issues.log"

    echo "───────────────────────────────────────────────────────────────────"
    echo "  Step 3: Validating Running Services"
    echo "───────────────────────────────────────────────────────────────────"
    echo ""

    local SERVICES=()
    local HEALTHY=0
    local UNHEALTHY=0

    # Get services from manifest
    if [[ -n "$PROD_MANIFEST" ]]; then
        while IFS= read -r svc; do
            SERVICES+=("$svc")
        done < <(jq -r '.services[].name // empty' "$PROD_MANIFEST" 2>/dev/null)
    fi

    # Add inferred services
    for svc in $INFERRED_SERVICES; do
        if [[ ! " ${SERVICES[*]} " =~ " ${svc} " ]]; then
            SERVICES+=("$svc")
        fi
    done

    if [[ ${#SERVICES[@]} -eq 0 ]]; then
        echo "ℹ️ No services to validate"
        return 0
    fi

    for svc in "${SERVICES[@]}"; do
        echo "  $svc:"

        # Determine service type (user vs system)
        local svc_type="user"
        if [[ -n "$PROD_MANIFEST" ]]; then
            svc_type=$(jq -r --arg s "$svc" '.services[] | select(.name == $s) | .type // "user"' "$PROD_MANIFEST")
        fi

        local systemctl_cmd="systemctl"
        [[ "$svc_type" == "user" ]] && systemctl_cmd="systemctl --user"

        # Check if service exists
        if ! $systemctl_cmd list-unit-files "$svc" &>/dev/null; then
            echo "     ❌ Service not installed"
            echo "Service not installed: $svc" >> "$ISSUES_FILE"
            ((UNHEALTHY++))
            continue
        fi

        # Get service status
        local status=$($systemctl_cmd is-active "$svc" 2>/dev/null)
        local enabled=$($systemctl_cmd is-enabled "$svc" 2>/dev/null)

        echo "     Status: $status"
        echo "     Enabled: $enabled"

        # Check expected state from manifest
        local expected_state="active"
        if [[ -n "$PROD_MANIFEST" ]]; then
            expected_state=$(jq -r --arg s "$svc" '.services[] | select(.name == $s) | .expected_state // "active"' "$PROD_MANIFEST")
        fi

        if [[ "$status" == "$expected_state" ]]; then
            echo "     ✅ State matches expected ($expected_state)"
            ((HEALTHY++))
        else
            echo "     ❌ Expected: $expected_state, Got: $status" | tee -a "$ISSUES_FILE"
            ((UNHEALTHY++))

            # Show recent logs for failed services
            if [[ "$status" != "active" ]]; then
                echo "     Recent logs:"
                $systemctl_cmd status "$svc" --no-pager 2>&1 | tail -5 | sed 's/^/       /'
            fi
        fi

        # Check health endpoint if defined
        if [[ -n "$PROD_MANIFEST" ]]; then
            local health_url=$(jq -r --arg s "$svc" '.services[] | select(.name == $s) | .health_endpoint // empty' "$PROD_MANIFEST")
            if [[ -n "$health_url" ]]; then
                echo -n "     Health endpoint: "
                if curl -sf "$health_url" &>/dev/null; then
                    echo "✅ Responding"
                else
                    echo "❌ Not responding" | tee -a "$ISSUES_FILE"
                fi
            fi
        fi
        echo ""
    done

    echo "  Summary: $HEALTHY healthy, $UNHEALTHY unhealthy"
    echo ""
}
```

## Step 4: Validate Configuration Files

```bash
validate_configs() {
    local PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
    local ISSUES_FILE="${PROJECT_DIR}/production-issues.log"

    echo "───────────────────────────────────────────────────────────────────"
    echo "  Step 4: Validating Configuration Files"
    echo "───────────────────────────────────────────────────────────────────"
    echo ""

    local CONFIGS=()
    local VALID=0
    local INVALID=0

    # Get configs from manifest
    if [[ -n "$PROD_MANIFEST" ]]; then
        while IFS= read -r cfg; do
            CONFIGS+=("$cfg")
        done < <(jq -r '.config_files[].path // empty' "$PROD_MANIFEST" 2>/dev/null)
    fi

    # Add inferred configs with common prefixes
    for cfg in $INFERRED_CONFIGS; do
        local full_path="$HOME/.config/$cfg"
        if [[ ! " ${CONFIGS[*]} " =~ " ${full_path} " ]]; then
            CONFIGS+=("$full_path")
        fi
    done

    if [[ ${#CONFIGS[@]} -eq 0 ]]; then
        echo "ℹ️ No config files to validate"
        return 0
    fi

    for cfg in "${CONFIGS[@]}"; do
        local expanded_cfg=$(eval echo "$cfg")
        echo -n "  $expanded_cfg: "

        if [[ -f "$expanded_cfg" ]]; then
            echo "✅ Exists"
            ((VALID++))

            # Check permissions
            local perms=$(stat -c "%a" "$expanded_cfg" 2>/dev/null)
            echo "     Permissions: $perms"

            # Run validation command if specified
            if [[ -n "$PROD_MANIFEST" ]]; then
                local validate_cmd=$(jq -r --arg c "$cfg" '.config_files[] | select(.path == $c) | .validate_command // empty' "$PROD_MANIFEST")
                if [[ -n "$validate_cmd" ]]; then
                    if eval "$validate_cmd" &>/dev/null; then
                        echo "     Validation: ✅ Passed"
                    else
                        echo "     Validation: ❌ Failed" | tee -a "$ISSUES_FILE"
                    fi
                fi
            fi
        else
            # Check if required
            local required=true
            if [[ -n "$PROD_MANIFEST" ]]; then
                required=$(jq -r --arg c "$cfg" '.config_files[] | select(.path == $c) | .required // true' "$PROD_MANIFEST")
            fi

            if [[ "$required" == "true" ]]; then
                echo "❌ MISSING (required)"
                echo "Missing required config: $expanded_cfg" >> "$ISSUES_FILE"
                ((INVALID++))
            else
                echo "⚠️ Missing (optional)"
            fi
        fi
    done

    echo ""
    echo "  Summary: $VALID valid, $INVALID invalid"
    echo ""
}
```

## Step 5: Validate Data Directories

```bash
validate_data_dirs() {
    local PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
    local ISSUES_FILE="${PROJECT_DIR}/production-issues.log"

    echo "───────────────────────────────────────────────────────────────────"
    echo "  Step 5: Validating Data Directories"
    echo "───────────────────────────────────────────────────────────────────"
    echo ""

    if [[ -z "$PROD_MANIFEST" ]]; then
        echo "ℹ️ No manifest - skipping data directory validation"
        return 0
    fi

    local count=$(jq '.data_directories | length' "$PROD_MANIFEST" 2>/dev/null)
    if [[ "$count" == "0" ]] || [[ -z "$count" ]]; then
        echo "ℹ️ No data directories defined in manifest"
        return 0
    fi

    jq -c '.data_directories[]' "$PROD_MANIFEST" 2>/dev/null | while read -r dir_obj; do
        local path=$(echo "$dir_obj" | jq -r '.path')
        local expanded_path=$(eval echo "$path")
        local required=$(echo "$dir_obj" | jq -r '.required // true')
        local min_perms=$(echo "$dir_obj" | jq -r '.min_permissions // "700"')

        echo -n "  $expanded_path: "

        if [[ -d "$expanded_path" ]]; then
            echo "✅ Exists"

            local perms=$(stat -c "%a" "$expanded_path" 2>/dev/null)
            echo "     Permissions: $perms (min: $min_perms)"

            # Check permissions are at least as restrictive
            if [[ "$perms" -le "$min_perms" ]]; then
                echo "     ✅ Permissions OK"
            else
                echo "     ⚠️ Permissions more permissive than recommended" | tee -a "$ISSUES_FILE"
            fi

            # Show size
            local size=$(du -sh "$expanded_path" 2>/dev/null | cut -f1)
            echo "     Size: $size"
        else
            if [[ "$required" == "true" ]]; then
                echo "❌ MISSING (required)"
                echo "Missing required directory: $expanded_path" >> "$ISSUES_FILE"
            else
                echo "⚠️ Missing (optional)"
            fi
        fi
    done
    echo ""
}
```

## Step 6: Validate Ports and Network

```bash
validate_ports() {
    local PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
    local ISSUES_FILE="${PROJECT_DIR}/production-issues.log"

    echo "───────────────────────────────────────────────────────────────────"
    echo "  Step 6: Validating Ports and Network"
    echo "───────────────────────────────────────────────────────────────────"
    echo ""

    if [[ -z "$PROD_MANIFEST" ]]; then
        echo "ℹ️ No manifest - skipping port validation"
        return 0
    fi

    local count=$(jq '.ports | length' "$PROD_MANIFEST" 2>/dev/null)
    if [[ "$count" == "0" ]] || [[ -z "$count" ]]; then
        echo "ℹ️ No ports defined in manifest"
        return 0
    fi

    jq -c '.ports[]' "$PROD_MANIFEST" 2>/dev/null | while read -r port_obj; do
        local port=$(echo "$port_obj" | jq -r '.port')
        local protocol=$(echo "$port_obj" | jq -r '.protocol // "tcp"')
        local service=$(echo "$port_obj" | jq -r '.service // "unknown"')

        echo -n "  Port $port/$protocol ($service): "

        # Check if port is listening
        if ss -tuln 2>/dev/null | grep -q ":$port "; then
            echo "✅ Listening"

            # Show what's using it
            local proc=$(ss -tulnp 2>/dev/null | grep ":$port " | grep -oP '(?<=users:\(\()[^)]+' | head -1)
            if [[ -n "$proc" ]]; then
                echo "     Process: $proc"
            fi
        else
            echo "❌ NOT LISTENING"
            echo "Port $port not listening (expected by $service)" >> "$ISSUES_FILE"
        fi
    done
    echo ""
}
```

## Step 7: Run Custom Health Checks

```bash
run_health_checks() {
    local PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
    local ISSUES_FILE="${PROJECT_DIR}/production-issues.log"

    echo "───────────────────────────────────────────────────────────────────"
    echo "  Step 7: Running Custom Health Checks"
    echo "───────────────────────────────────────────────────────────────────"
    echo ""

    if [[ -z "$PROD_MANIFEST" ]]; then
        echo "ℹ️ No manifest - skipping health checks"
        return 0
    fi

    local count=$(jq '.health_checks | length' "$PROD_MANIFEST" 2>/dev/null)
    if [[ "$count" == "0" ]] || [[ -z "$count" ]]; then
        echo "ℹ️ No health checks defined in manifest"
        return 0
    fi

    local passed=0
    local failed=0

    jq -c '.health_checks[]' "$PROD_MANIFEST" 2>/dev/null | while read -r check_obj; do
        local name=$(echo "$check_obj" | jq -r '.name')
        local cmd=$(echo "$check_obj" | jq -r '.command')
        local timeout_sec=$(echo "$check_obj" | jq -r '.timeout // 10')

        echo -n "  $name: "

        if timeout "$timeout_sec" bash -c "$cmd" &>/dev/null; then
            echo "✅ Passed"
            ((passed++))
        else
            echo "❌ Failed"
            echo "Health check failed: $name" >> "$ISSUES_FILE"
            ((failed++))
        fi
    done

    echo ""
    echo "  Summary: $passed passed, $failed failed"
    echo ""
}
```

## Step 8: Check Service Logs for Errors

```bash
check_service_logs() {
    local PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
    local ISSUES_FILE="${PROJECT_DIR}/production-issues.log"

    echo "───────────────────────────────────────────────────────────────────"
    echo "  Step 8: Checking Service Logs for Errors"
    echo "───────────────────────────────────────────────────────────────────"
    echo ""

    local SERVICES=()

    # Collect services
    if [[ -n "$PROD_MANIFEST" ]]; then
        while IFS= read -r svc; do
            SERVICES+=("$svc")
        done < <(jq -r '.services[].name // empty' "$PROD_MANIFEST" 2>/dev/null)
    fi
    for svc in $INFERRED_SERVICES; do
        if [[ ! " ${SERVICES[*]} " =~ " ${svc} " ]]; then
            SERVICES+=("$svc")
        fi
    done

    if [[ ${#SERVICES[@]} -eq 0 ]]; then
        echo "ℹ️ No services to check logs for"
        return 0
    fi

    for svc in "${SERVICES[@]}"; do
        echo "  $svc (last 1 hour):"

        # Determine service type
        local svc_type="user"
        if [[ -n "$PROD_MANIFEST" ]]; then
            svc_type=$(jq -r --arg s "$svc" '.services[] | select(.name == $s) | .type // "user"' "$PROD_MANIFEST")
        fi

        local journal_cmd="journalctl --user"
        [[ "$svc_type" == "system" ]] && journal_cmd="journalctl"

        # Count errors in last hour
        local errors=$($journal_cmd -u "$svc" --since "1 hour ago" -p err --no-pager 2>/dev/null | wc -l)
        local warnings=$($journal_cmd -u "$svc" --since "1 hour ago" -p warning --no-pager 2>/dev/null | wc -l)

        echo "     Errors: $errors"
        echo "     Warnings: $warnings"

        if [[ "$errors" -gt 0 ]]; then
            echo "     Recent errors:" | tee -a "$ISSUES_FILE"
            $journal_cmd -u "$svc" --since "1 hour ago" -p err --no-pager 2>/dev/null | tail -3 | sed 's/^/       /' | tee -a "$ISSUES_FILE"
        fi
        echo ""
    done
}
```

## Step 9: Generate Production Validation Report

```bash
generate_production_report() {
    local PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
    local ISSUES_FILE="${PROJECT_DIR}/production-issues.log"

    echo "═══════════════════════════════════════════════════════════════════"
    echo "  PHASE P: PRODUCTION VALIDATION SUMMARY"
    echo "═══════════════════════════════════════════════════════════════════"
    echo ""

    if [[ -f "$ISSUES_FILE" ]] && [[ -s "$ISSUES_FILE" ]]; then
        local issue_count=$(wc -l < "$ISSUES_FILE")
        echo "❌ ISSUES FOUND: $issue_count"
        echo ""
        echo "Issues recorded to: $ISSUES_FILE"
        echo ""
        echo "───────────────────────────────────────────────────────────────────"
        cat "$ISSUES_FILE"
        echo "───────────────────────────────────────────────────────────────────"
        echo ""
        echo "To resolve:"
        echo "  1. Fix each issue listed above"
        echo "  2. Re-run: /test --phase=P"
        echo ""
        return 1
    else
        echo "✅ ALL PRODUCTION VALIDATION CHECKS PASSED"
        echo ""
        echo "The installed application appears healthy."
        rm -f "$ISSUES_FILE" 2>/dev/null
        return 0
    fi
}
```

## Phase P Execution Order

```bash
run_phase_P() {
    local PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"

    # Initialize issues file
    local ISSUES_FILE="${PROJECT_DIR}/production-issues.log"
    > "$ISSUES_FILE"

    # Run all validation steps
    load_production_manifest
    analyze_install_script
    validate_binaries
    validate_services
    validate_configs
    validate_data_dirs
    validate_ports
    run_health_checks
    check_service_logs
    generate_production_report

    return $?
}
```

## Report Format

```markdown
## Phase P: Production Validation Report

### Environment
| Attribute | Value |
|-----------|-------|
| App Name | [from manifest or inferred] |
| Install Type | user/system |
| Manifest | [path or "inferred"] |

### Binaries
| Binary | Status | Location | Version |
|--------|--------|----------|---------|
| app-cli | ✅ Found | ~/.local/bin/app-cli | 1.2.3 |
| app-daemon | ❌ Missing | - | - |

### Services
| Service | Expected | Actual | Enabled |
|---------|----------|--------|---------|
| app.service | active | active | yes |
| app-worker.service | active | failed | yes |

### Configuration
| Config File | Status | Valid |
|-------------|--------|-------|
| ~/.config/app/config.yml | ✅ Exists | ✅ Yes |

### Ports
| Port | Protocol | Status | Process |
|------|----------|--------|---------|
| 8080 | tcp | ✅ Listening | app-daemon |

### Health Checks
| Check | Status |
|-------|--------|
| API responding | ✅ Passed |
| Database connected | ❌ Failed |

### Log Analysis (Last Hour)
| Service | Errors | Warnings |
|---------|--------|----------|
| app.service | 0 | 2 |

### Issues Found
- [List from production-issues.log]

### Phase P Status: ✅ HEALTHY / ❌ ISSUES FOUND
```
