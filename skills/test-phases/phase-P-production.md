# Phase P: Production Validation

> **Model**: `opus` | **Tier**: 7 (Conditional) | **Modifies Files**: No (validates live)
> **Task Tracking**: Call `TaskUpdate(taskId, status="in_progress")` at start, `TaskUpdate(taskId, status="completed")` when done.
> **Key Tools**: `Bash` for system validation (use `timeout` for hung service checks). Use `AskUserQuestion` in `--interactive` mode for production remediation decisions.

Validate that a project's installed production application is running correctly. Compares expected state (from `install-manifest.json` + install script analysis) against actual system state.

**Key Difference from Phase A:** Phase A tests installation *in a sandbox*. Phase P validates *live production*.

**Prerequisites:** Application must already be installed on the system.

## Manifest: `install-manifest.json`

```json
{
  "name": "my-app",
  "version": "1.0.0",
  "install_type": "user",
  "binaries": [
    { "name": "my-app", "paths": ["~/.local/bin/my-app"], "version_flag": "--version", "health_check": "my-app --health" }
  ],
  "services": [
    { "name": "my-app.service", "type": "user", "expected_state": "active", "health_endpoint": "http://localhost:8080/health" }
  ],
  "config_files": [
    { "path": "~/.config/my-app/config.yml", "required": true, "validate_command": "my-app config validate" }
  ],
  "data_directories": [
    { "path": "~/.local/share/my-app", "required": true, "min_permissions": "700" }
  ],
  "ports": [
    { "port": 8080, "protocol": "tcp", "service": "my-app.service" }
  ],
  "health_checks": [
    { "name": "API responding", "command": "curl -sf http://localhost:8080/health", "timeout": 5 }
  ]
}
```

## Step 1: Load Manifest and Analyze Install Script

```bash
load_production_manifest() {
    local PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"

    for candidate in "install-manifest.json" ".install-manifest.json" "manifest.json"; do
        [[ -f "$PROJECT_DIR/$candidate" ]] && { export PROD_MANIFEST="$PROJECT_DIR/$candidate"; break; }
    done

    if [[ -n "$PROD_MANIFEST" ]]; then
        export APP_NAME=$(jq -r '.name // "unknown"' "$PROD_MANIFEST")
        export INSTALL_TYPE=$(jq -r '.install_type // "user"' "$PROD_MANIFEST")
    else
        export PROD_MANIFEST="" APP_NAME=$(basename "$PROJECT_DIR" | tr '[:upper:]' '[:lower:]')
    fi
}

analyze_install_script() {
    local PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
    local INSTALL_SCRIPT="$PROJECT_DIR/install.sh"
    [[ ! -f "$INSTALL_SCRIPT" ]] && return 0

    # Extract PREFIX/install location
    local PREFIX=$(grep -oP '(?<=PREFIX=["'"'"']?)[^"'"'"'\s]+' "$INSTALL_SCRIPT" | head -1)
    [[ -z "$PREFIX" ]] && PREFIX=$(grep -oP '(?<=INSTALL_DIR=["'"'"']?)[^"'"'"'\s]+' "$INSTALL_SCRIPT" | head -1)
    export INFERRED_PREFIX="${PREFIX:-$HOME/.local}"

    # Extract binary names from cp/install commands to bin/
    local BINS=()
    while IFS= read -r line; do
        local bn=$(echo "$line" | grep -oP '[\w-]+(?=\s*$)' | head -1)
        [[ -n "$bn" ]] && BINS+=("$bn")
    done < <(grep -E 'cp.*bin/|install.*bin/' "$INSTALL_SCRIPT" 2>/dev/null)
    export INFERRED_BINS="${BINS[*]}"

    # Extract systemd service names
    local SVCS=()
    while IFS= read -r svc; do SVCS+=("$svc"); done < <(grep -oP '[\w-]+\.service' "$INSTALL_SCRIPT" 2>/dev/null | sort -u)
    if [[ -d "$PROJECT_DIR/systemd" ]]; then
        while IFS= read -r sf; do
            local s=$(basename "$sf")
            [[ ! " ${SVCS[*]} " =~ " ${s} " ]] && SVCS+=("$s")
        done < <(find "$PROJECT_DIR/systemd" -name "*.service" 2>/dev/null)
    fi
    export INFERRED_SERVICES="${SVCS[*]}"

    # Extract config file paths
    export INFERRED_CONFIGS=$(grep -oP '(?<=\.config/)[^\s"'"'"']+' "$INSTALL_SCRIPT" 2>/dev/null | sort -u | tr '\n' ' ')
}
```

## Step 2: Validate Installed Binaries

```bash
validate_binaries() {
    local PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
    local ISSUES_FILE="${PROJECT_DIR}/production-issues.log"
    local BINARIES=() FOUND=0 MISSING=0

    # Collect from manifest + inferred
    [[ -n "$PROD_MANIFEST" ]] && while IFS= read -r b; do BINARIES+=("$b"); done < <(jq -r '.binaries[].name // empty' "$PROD_MANIFEST" 2>/dev/null)
    for b in $INFERRED_BINS; do [[ ! " ${BINARIES[*]} " =~ " ${b} " ]] && BINARIES+=("$b"); done

    [[ ${#BINARIES[@]} -eq 0 ]] && return 0

    for bin in "${BINARIES[@]}"; do
        local bin_path=""
        for loc in "$HOME/.local/bin/$bin" "/usr/local/bin/$bin" "/usr/bin/$bin" "$INFERRED_PREFIX/bin/$bin"; do
            loc=$(eval echo "$loc")
            [[ -x "$loc" ]] && { bin_path="$loc"; break; }
        done
        [[ -z "$bin_path" ]] && bin_path=$(which "$bin" 2>/dev/null)

        if [[ -n "$bin_path" ]]; then
            echo "  $bin: found at $bin_path"
            "$bin_path" --version &>/dev/null && echo "     Version: $("$bin_path" --version 2>&1 | head -1)"
            ((FOUND++))

            # Run manifest health check if defined
            if [[ -n "$PROD_MANIFEST" ]]; then
                local hc=$(jq -r --arg b "$bin" '.binaries[] | select(.name == $b) | .health_check // empty' "$PROD_MANIFEST")
                [[ -n "$hc" ]] && { eval "$hc" &>/dev/null && echo "     Health: PASS" || echo "     Health: FAIL" | tee -a "$ISSUES_FILE"; }
            fi
        else
            echo "  $bin: NOT FOUND"
            echo "Binary not found: $bin" >> "$ISSUES_FILE"
            ((MISSING++))
        fi
    done
    echo "  Summary: $FOUND found, $MISSING missing"
}
```

## Step 2b: Validate Wrapper Script Targets

Wrapper scripts in `/usr/local/bin/` that `exec` into other scripts will fail silently if the target is missing.

```bash
validate_wrapper_targets() {
    local APP_NAME_LOWER=$(echo "$APP_NAME" | tr '[:upper:]' '[:lower:]' | tr -d '-')
    local ISSUES_FILE="${PROJECT_DIR:-$(pwd)}/production-issues.log"
    local FOUND=0 BROKEN=0

    local wrappers=()
    while IFS= read -r w; do wrappers+=("$w"); done < <(ls /usr/local/bin/${APP_NAME_LOWER}* /usr/local/bin/${APP_NAME}* 2>/dev/null | sort -u)
    [[ ${#wrappers[@]} -eq 0 ]] && return 0

    for wrapper in "${wrappers[@]}"; do
        head -5 "$wrapper" 2>/dev/null | grep -q "exec" || { ((FOUND++)); continue; }
        local target=$(grep -m1 "^exec " "$wrapper" 2>/dev/null | sed 's/^exec //' | awk '{print $1}')
        [[ -z "$target" ]] && continue

        local resolved=$(eval echo "$target" 2>/dev/null || echo "$target")
        if [[ -x "$resolved" ]]; then
            echo "  $(basename "$wrapper"): -> $resolved (OK)"
            ((FOUND++))
        else
            echo "  $(basename "$wrapper"): BROKEN -> $resolved"
            echo "Wrapper script broken: $wrapper -> $resolved" >> "$ISSUES_FILE"
            ((BROKEN++))
        fi
    done

    [[ $BROKEN -gt 0 ]] && echo "  $BROKEN BROKEN WRAPPER(S) — re-run install.sh"
}
```

## Step 3: Validate Running Services

```bash
validate_services() {
    local ISSUES_FILE="${PROJECT_DIR:-$(pwd)}/production-issues.log"
    local SERVICES=() HEALTHY=0 UNHEALTHY=0

    [[ -n "$PROD_MANIFEST" ]] && while IFS= read -r s; do SERVICES+=("$s"); done < <(jq -r '.services[].name // empty' "$PROD_MANIFEST" 2>/dev/null)
    for s in $INFERRED_SERVICES; do [[ ! " ${SERVICES[*]} " =~ " ${s} " ]] && SERVICES+=("$s"); done
    [[ ${#SERVICES[@]} -eq 0 ]] && return 0

    for svc in "${SERVICES[@]}"; do
        local svc_type="user"
        [[ -n "$PROD_MANIFEST" ]] && svc_type=$(jq -r --arg s "$svc" '.services[] | select(.name == $s) | .type // "user"' "$PROD_MANIFEST")
        local cmd="systemctl"; [[ "$svc_type" == "user" ]] && cmd="systemctl --user"

        local status=$($cmd is-active "$svc" 2>/dev/null)
        local expected="active"
        [[ -n "$PROD_MANIFEST" ]] && expected=$(jq -r --arg s "$svc" '.services[] | select(.name == $s) | .expected_state // "active"' "$PROD_MANIFEST")

        if [[ "$status" == "$expected" ]]; then
            echo "  $svc: $status (OK)"; ((HEALTHY++))
        else
            echo "  $svc: $status (expected: $expected)" | tee -a "$ISSUES_FILE"; ((UNHEALTHY++))
            [[ "$status" != "active" ]] && $cmd status "$svc" --no-pager 2>&1 | tail -3 | sed 's/^/       /'
        fi

        # Health endpoint
        [[ -n "$PROD_MANIFEST" ]] && {
            local url=$(jq -r --arg s "$svc" '.services[] | select(.name == $s) | .health_endpoint // empty' "$PROD_MANIFEST")
            [[ -n "$url" ]] && { curl -sf "$url" &>/dev/null && echo "     Endpoint: OK" || echo "     Endpoint: FAIL" | tee -a "$ISSUES_FILE"; }
        }
    done
    echo "  Summary: $HEALTHY healthy, $UNHEALTHY unhealthy"
}
```

## Step 4: Validate Configuration Files

```bash
validate_configs() {
    local ISSUES_FILE="${PROJECT_DIR:-$(pwd)}/production-issues.log"
    local CONFIGS=() VALID=0 INVALID=0

    [[ -n "$PROD_MANIFEST" ]] && while IFS= read -r c; do CONFIGS+=("$c"); done < <(jq -r '.config_files[].path // empty' "$PROD_MANIFEST" 2>/dev/null)
    for c in $INFERRED_CONFIGS; do
        local fp="$HOME/.config/$c"
        [[ ! " ${CONFIGS[*]} " =~ " ${fp} " ]] && CONFIGS+=("$fp")
    done
    [[ ${#CONFIGS[@]} -eq 0 ]] && return 0

    for cfg in "${CONFIGS[@]}"; do
        local exp=$(eval echo "$cfg")
        if [[ -f "$exp" ]]; then
            echo "  $exp: EXISTS ($(stat -c '%a' "$exp"))"
            ((VALID++))
            [[ -n "$PROD_MANIFEST" ]] && {
                local vcmd=$(jq -r --arg c "$cfg" '.config_files[] | select(.path == $c) | .validate_command // empty' "$PROD_MANIFEST")
                [[ -n "$vcmd" ]] && { eval "$vcmd" &>/dev/null && echo "     Validation: PASS" || echo "     Validation: FAIL" | tee -a "$ISSUES_FILE"; }
            }
        else
            local req=true
            [[ -n "$PROD_MANIFEST" ]] && req=$(jq -r --arg c "$cfg" '.config_files[] | select(.path == $c) | .required // true' "$PROD_MANIFEST")
            [[ "$req" == "true" ]] && { echo "  $exp: MISSING (required)"; echo "Missing config: $exp" >> "$ISSUES_FILE"; ((INVALID++)); } || echo "  $exp: missing (optional)"
        fi
    done
}
```

## Step 5: Validate Data Directories

```bash
validate_data_dirs() {
    local ISSUES_FILE="${PROJECT_DIR:-$(pwd)}/production-issues.log"
    [[ -z "$PROD_MANIFEST" ]] && return 0

    jq -c '.data_directories[]' "$PROD_MANIFEST" 2>/dev/null | while read -r obj; do
        local path=$(echo "$obj" | jq -r '.path') expanded=$(eval echo "$(echo "$obj" | jq -r '.path')")
        local required=$(echo "$obj" | jq -r '.required // true')
        local min_perms=$(echo "$obj" | jq -r '.min_permissions // "700"')

        if [[ -d "$expanded" ]]; then
            local perms=$(stat -c "%a" "$expanded") size=$(du -sh "$expanded" 2>/dev/null | cut -f1)
            echo "  $expanded: EXISTS ($perms, $size)"
            [[ "$perms" -gt "$min_perms" ]] && echo "     Permissions more permissive than $min_perms" | tee -a "$ISSUES_FILE"
        elif [[ "$required" == "true" ]]; then
            echo "  $expanded: MISSING (required)"
            echo "Missing directory: $expanded" >> "$ISSUES_FILE"
        fi
    done
}
```

## Step 5a: Validate Permissions and Ownership

```bash
validate_permissions_and_ownership() {
    local PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
    local ISSUES_FILE="$PROJECT_DIR/production-issues.log"

    # Find installation directory
    local INSTALL_DIR=""
    [[ -n "$PROD_MANIFEST" ]] && INSTALL_DIR=$(jq -r '.install_dir // empty' "$PROD_MANIFEST" 2>/dev/null)
    if [[ -z "$INSTALL_DIR" ]]; then
        for loc in "/opt/$APP_NAME" "/opt/${APP_NAME,,}" "/usr/local/lib/$APP_NAME"; do
            [[ -d "$loc" ]] && { INSTALL_DIR="$loc"; break; }
        done
    fi
    [[ -z "$INSTALL_DIR" || ! -d "$INSTALL_DIR" ]] && return 0

    local is_system=false issues=0
    [[ "$INSTALL_DIR" == /opt/* || "$INSTALL_DIR" == /usr/* ]] && is_system=true

    # Determine expected owner
    local EXPECTED_USER="$USER" EXPECTED_GROUP="$USER"
    if [[ "$is_system" == "true" ]]; then
        [[ -n "$PROD_MANIFEST" ]] && { EXPECTED_USER=$(jq -r '.service_user // empty' "$PROD_MANIFEST"); EXPECTED_GROUP=$(jq -r '.service_group // empty' "$PROD_MANIFEST"); }
        [[ -z "$EXPECTED_USER" ]] && EXPECTED_USER="${APP_NAME,,}"
        [[ -z "$EXPECTED_GROUP" ]] && EXPECTED_GROUP="$EXPECTED_USER"
        id "$EXPECTED_USER" &>/dev/null || { EXPECTED_USER="root"; EXPECTED_GROUP="root"; }
    fi

    # Check ownership of all subdirectories (dynamically discovered)
    for subdir in $(find "$INSTALL_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null); do
        local wrong=$(find "$INSTALL_DIR/$subdir" \( ! -user "$EXPECTED_USER" -o ! -group "$EXPECTED_GROUP" \) 2>/dev/null | wc -l)
        [[ "$wrong" -gt 0 ]] && { echo "  $subdir/: $wrong files wrong owner" | tee -a "$ISSUES_FILE"; ((issues++)); } || echo "  $subdir/: ownership OK"
    done

    # Check directory/file permissions and script executability
    local bad_dirs=$(find "$INSTALL_DIR" -type d -perm 700 2>/dev/null | wc -l)
    [[ "$bad_dirs" -gt 0 ]] && { echo "  $bad_dirs dirs have 700 perms" | tee -a "$ISSUES_FILE"; ((issues++)); }

    local bad_files=$(find "$INSTALL_DIR" \( -name "*.py" -o -name "*.html" -o -name "*.css" -o -name "*.js" \) \( -perm 600 -o -perm 700 \) 2>/dev/null | wc -l)
    [[ "$bad_files" -gt 0 ]] && { echo "  $bad_files source files have restrictive perms" | tee -a "$ISSUES_FILE"; ((issues++)); }

    local non_exec=$(find "$INSTALL_DIR" -name "*.sh" ! -perm -u+x 2>/dev/null | wc -l)
    [[ "$non_exec" -gt 0 ]] && { echo "  $non_exec shell scripts not executable" | tee -a "$ISSUES_FILE"; ((issues++)); }

    [[ "$issues" -eq 0 ]] && echo "  All permissions and ownership correct"
}
```

## Step 5b: Validate Production/Development Separation

Production installations MUST NOT reference development directories.

```bash
validate_prod_dev_separation() {
    local PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
    local ISSUES_FILE="$PROJECT_DIR/production-issues.log"
    local issues=0

    local DEV_PATTERNS=("/hddRaid1/ClaudeCodeProjects/" "/home/.*/ClaudeCodeProjects/" "/home/.*/Projects/" "/home/.*/dev/" "/home/.*/src/")
    local grep_pattern=$(printf "%s\\|" "${DEV_PATTERNS[@]}"); grep_pattern="${grep_pattern%\\|}"

    # Determine install dir (reuse from Step 5a or detect)
    local INSTALL_DIR=""
    [[ -n "$PROD_MANIFEST" ]] && INSTALL_DIR=$(jq -r '.install_dir // empty' "$PROD_MANIFEST" 2>/dev/null)
    if [[ -z "$INSTALL_DIR" ]]; then
        for loc in "/opt/$APP_NAME" "/opt/${APP_NAME,,}" "/usr/local/lib/$APP_NAME"; do
            [[ -d "$loc" ]] && { INSTALL_DIR="$loc"; break; }
        done
    fi

    local APP_NAME_LOWER=$(echo "$APP_NAME" | tr '[:upper:]' '[:lower:]' | tr -d '-')

    # 1. System systemd services
    local sys_svcs=$(grep -l -E "$grep_pattern" /etc/systemd/system/${APP_NAME_LOWER}*.service /etc/systemd/system/${APP_NAME}*.service 2>/dev/null || true)
    [[ -n "$sys_svcs" ]] && { echo "  CRITICAL: System services reference dev paths: $sys_svcs" | tee -a "$ISSUES_FILE"; ((issues++)); }

    # 2. User systemd services
    local user_svcs=$(grep -l -E "$grep_pattern" "$HOME/.config/systemd/user/${APP_NAME_LOWER}"*.service "$HOME/.config/systemd/user/${APP_NAME}"*.service 2>/dev/null || true)
    [[ -n "$user_svcs" ]] && { echo "  CRITICAL: User services reference dev paths" | tee -a "$ISSUES_FILE"; ((issues++)); }

    # 3. Installed scripts referencing dev paths
    if [[ -n "$INSTALL_DIR" && -d "$INSTALL_DIR" ]]; then
        local bad_scripts=$(grep -rl -E "$grep_pattern" "$INSTALL_DIR" --include="*.sh" --include="*.py" --include="*.conf" 2>/dev/null | wc -l)
        [[ "$bad_scripts" -gt 0 ]] && { echo "  CRITICAL: $bad_scripts installed files reference dev paths" | tee -a "$ISSUES_FILE"; ((issues++)); }

        # 4. Symlinks pointing to dev directories
        local bad_links=$(find "$INSTALL_DIR" -type l 2>/dev/null | while read -r l; do
            local t=$(readlink -f "$l" 2>/dev/null); echo "$t" | grep -qE "$grep_pattern" && echo "$l"
        done | wc -l)
        [[ "$bad_links" -gt 0 ]] && { echo "  CRITICAL: $bad_links symlinks point to dev dirs" | tee -a "$ISSUES_FILE"; ((issues++)); }

        # 5. Config files with dev paths
        local bad_cfgs=$(find "$INSTALL_DIR" \( -name "*.conf" -o -name "*.env" -o -name "*.yml" -o -name "*.yaml" -o -name "config*.py" \) -exec grep -l -E "$grep_pattern" {} \; 2>/dev/null | wc -l)
        [[ "$bad_cfgs" -gt 0 ]] && { echo "  CRITICAL: $bad_cfgs config files reference dev paths" | tee -a "$ISSUES_FILE"; ((issues++)); }
    fi

    [[ "$issues" -eq 0 ]] && echo "  Production/Development separation clean" || echo "  $issues prod/dev separation violations found"
}
```

## Step 6: Validate Ports and Network

```bash
validate_ports() {
    local ISSUES_FILE="${PROJECT_DIR:-$(pwd)}/production-issues.log"
    [[ -z "$PROD_MANIFEST" ]] && return 0

    jq -c '.ports[]' "$PROD_MANIFEST" 2>/dev/null | while read -r obj; do
        local port=$(echo "$obj" | jq -r '.port') service=$(echo "$obj" | jq -r '.service // "unknown"')
        if ss -tuln 2>/dev/null | grep -q ":$port "; then
            echo "  Port $port ($service): LISTENING"
        else
            echo "  Port $port ($service): NOT LISTENING"
            echo "Port $port not listening" >> "$ISSUES_FILE"
        fi
    done
}
```

## Step 7: Run Custom Health Checks

```bash
run_health_checks() {
    local ISSUES_FILE="${PROJECT_DIR:-$(pwd)}/production-issues.log"
    [[ -z "$PROD_MANIFEST" ]] && return 0

    jq -c '.health_checks[]' "$PROD_MANIFEST" 2>/dev/null | while read -r obj; do
        local name=$(echo "$obj" | jq -r '.name') cmd=$(echo "$obj" | jq -r '.command') t=$(echo "$obj" | jq -r '.timeout // 10')
        if timeout "$t" bash -c "$cmd" &>/dev/null; then
            echo "  $name: PASS"
        else
            echo "  $name: FAIL"
            echo "Health check failed: $name" >> "$ISSUES_FILE"
        fi
    done
}
```

## Step 8: Check Service Logs for Errors

```bash
check_service_logs() {
    local ISSUES_FILE="${PROJECT_DIR:-$(pwd)}/production-issues.log"
    local SERVICES=()

    [[ -n "$PROD_MANIFEST" ]] && while IFS= read -r s; do SERVICES+=("$s"); done < <(jq -r '.services[].name // empty' "$PROD_MANIFEST" 2>/dev/null)
    for s in $INFERRED_SERVICES; do [[ ! " ${SERVICES[*]} " =~ " ${s} " ]] && SERVICES+=("$s"); done
    [[ ${#SERVICES[@]} -eq 0 ]] && return 0

    for svc in "${SERVICES[@]}"; do
        local svc_type="user"
        [[ -n "$PROD_MANIFEST" ]] && svc_type=$(jq -r --arg s "$svc" '.services[] | select(.name == $s) | .type // "user"' "$PROD_MANIFEST")
        local jcmd="journalctl --user"; [[ "$svc_type" == "system" ]] && jcmd="journalctl"

        local errors=$($jcmd -u "$svc" --since "1 hour ago" -p err --no-pager 2>/dev/null | wc -l)
        local warnings=$($jcmd -u "$svc" --since "1 hour ago" -p warning --no-pager 2>/dev/null | wc -l)
        echo "  $svc: $errors errors, $warnings warnings (last hour)"
        [[ "$errors" -gt 0 ]] && $jcmd -u "$svc" --since "1 hour ago" -p err --no-pager 2>/dev/null | tail -3 | sed 's/^/       /' | tee -a "$ISSUES_FILE"
    done
}
```

## Execution Order

```bash
run_phase_P() {
    local PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
    local ISSUES_FILE="$PROJECT_DIR/production-issues.log"
    > "$ISSUES_FILE"

    load_production_manifest
    analyze_install_script
    validate_binaries
    validate_wrapper_targets
    validate_services
    validate_configs
    validate_data_dirs
    validate_permissions_and_ownership
    validate_prod_dev_separation
    validate_ports
    run_health_checks
    check_service_logs

    # Summary
    if [[ -s "$ISSUES_FILE" ]]; then
        echo ""; echo "ISSUES FOUND: $(wc -l < "$ISSUES_FILE")"
        cat "$ISSUES_FILE"
        echo "To resolve: fix each issue, then re-run /test --phase=P"
        return 1
    else
        echo "ALL PRODUCTION VALIDATION CHECKS PASSED"
        rm -f "$ISSUES_FILE"
        return 0
    fi
}
```
