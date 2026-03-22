# Phase 1: Discovery

> **Model**: `opus` | **Tier**: 1 (Discovery — GATE) | **Modifies Files**: No
> **Task Tracking**: Call `TaskUpdate(taskId, status="in_progress")` at start, `TaskUpdate(taskId, status="completed")` when done. All subsequent phases depend on this — use `addBlocks` to express downstream dependencies.
> **Key Tools**: `Bash`, `Glob`, `Grep`, `Read` for project analysis. Use `WebSearch` to identify framework conventions if an unfamiliar project type is detected.

Identify project type, test framework, and testable components.

## Output Schema

Phase 1 MUST output all of the following key-value pairs (downstream phases parse them):

```
Project Type: [type]
Test Framework: [framework]
Test Files Found: [count]
Test Command: [command]
Config Files: [list]
Danger Score: [0-100+]
Isolation Level: [sandbox|sandbox-warn|vm-recommended|vm-required]
Danger Indicators: [list or "none"]
MCP Servers Available: [count]
GitHub Status: [not-a-repo|no-remote|not-github|secure|alerts-open|incomplete]
GitHub Repo: [owner/repo or N/A]
GitHub Authenticated: [true|false]
GitHub Alerts: [count]
Staged Release: [valid|invalid|none]
Staged Version: [X.Y.Z or empty]
Staged Tag: [vX.Y.Z or empty]
Staged Commit: [SHA or empty]
Docker Staging Images: [list or none]
Pytest Extra Flags: [--flag1 --flag2 | (none)]
Installable App: [none|manifest|script|python-package|npm-package|go-binary|rust-binary|systemd-service|makefile]
Install Method: [method or N/A]
Production Status: [not-installed|installed|installed-not-running]
Production Details: [details]
Docker Status: [none|exists]
Registry Image: [image name or N/A]
Registry Status: [not-found|found|version-mismatch]
Registry Version: [version or N/A]
Project Version: [version or N/A]
```

---

## MANDATORY Detections (all projects)

### 1. Detect Project Type

| File | Type | Test Command |
|------|------|--------------|
| `package.json` | Node.js | `npm test` |
| `pyproject.toml` | Python (modern) | `pytest` |
| `setup.py` / `requirements.txt` | Python | `pytest` |
| `go.mod` | Go | `go test ./...` |
| `Cargo.toml` | Rust | `cargo test` |
| `Makefile` | Make-based | `make test` |
| `pom.xml` | Java/Maven | `mvn test` |
| `build.gradle` | Java/Gradle | `gradle test` |
| `Dockerfile` | Docker | `docker build` |
| `docker-compose.yml` | Docker Compose | `docker compose up` |

```bash
# MANDATORY: Check for Docker files
ls -la Dockerfile docker-compose.yml .dockerignore compose.yml 2>/dev/null
```

### 2. Find Test Files

```bash
# Python
find . -name "test_*.py" -o -name "*_test.py" | head -20
# JavaScript/TypeScript
find . -name "*.test.js" -o -name "*.spec.ts" | head -20
# Go
find . -name "*_test.go" | head -20
# Rust
grep -r "#\[test\]" src/ tests/ 2>/dev/null | head -20
```

### 3. Identify Config Files

```bash
ls -la pytest.ini pyproject.toml jest.config.* vitest.config.* .mocharc.* 2>/dev/null
ls -la .github/workflows/*.yml .gitlab-ci.yml Jenkinsfile 2>/dev/null
```

### 4. Check Dependencies

```bash
# Python
pip list 2>/dev/null | grep -iE "pytest|unittest|nose"
# Node
npm ls 2>/dev/null | grep -iE "jest|mocha|vitest|playwright"
```

### 5. Detect Available Analysis Tools

```bash
check_tool() {
    local name="$1" cmd="$2"
    if command -v "$cmd" &>/dev/null; then
        echo "  [ok] $name ($cmd)"
        return 0
    else
        echo "  [--] $name (not installed)"
        return 1
    fi
}

echo "Python:";      for t in ruff mypy pylint bandit black isort pip-audit radon pydocstyle; do check_tool "$t" "$t"; done
echo "Shell:";        check_tool "shfmt" "shfmt"
echo "JS/TS:";        for t in eslint prettier tsc; do check_tool "$t" "$t"; done
echo "YAML:";         check_tool "yamllint" "yamllint"
echo "Docker:";       check_tool "hadolint" "hadolint"
echo "Docs:";         for t in markdownlint codespell; do check_tool "$t" "$t"; done
echo "Security:";     for t in codeql trivy grype; do check_tool "$t" "$t"; done
echo "Go:";           for t in golangci-lint govulncheck; do check_tool "$t" "$t"; done
echo "Rust:";         for t in cargo-clippy cargo-audit; do check_tool "$t" "$t"; done
```

### 6. Isolation Level Detection

Scan project for dangerous system-modifying patterns and assign a danger score.

```bash
detect_isolation_level() {
    local PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
    local DANGER_SCORE=0
    local DANGER_INDICATORS=()

    # CRITICAL (100 pts each): PAM, bootloader
    grep -rqE "pam\.d|pam_|libpam|security/pam" "$PROJECT_DIR" --include="*.sh" --include="*.py" --include="*.conf" --include="Makefile" 2>/dev/null && { DANGER_INDICATORS+=("PAM configuration changes"); ((DANGER_SCORE += 100)); }
    find "$PROJECT_DIR" -name "*.pam" -o -name "*pam*.conf" 2>/dev/null | grep -q . && { DANGER_INDICATORS+=("PAM config files"); ((DANGER_SCORE += 100)); }
    grep -rqE "bootctl|efibootmgr|grub-|loader/entries|cmdline|kernel-install" "$PROJECT_DIR" --include="*.sh" --include="*.py" 2>/dev/null && { DANGER_INDICATORS+=("Bootloader/kernel changes"); ((DANGER_SCORE += 100)); }

    # HIGH (70-90 pts): kernel modules, sysctl, sudo/polkit, systemd system services, display manager, D-Bus system bus
    grep -rqE "modprobe|insmod|rmmod|\.ko\b|depmod|/lib/modules" "$PROJECT_DIR" --include="*.sh" --include="*.py" 2>/dev/null && { DANGER_INDICATORS+=("Kernel module ops"); ((DANGER_SCORE += 90)); }
    grep -rqE "sudoers|polkit|pkla|\.rules" "$PROJECT_DIR" --include="*.sh" --include="*.py" --include="*.rules" 2>/dev/null && { DANGER_INDICATORS+=("sudo/polkit rules"); ((DANGER_SCORE += 80)); }
    grep -rqE "/etc/systemd/system|systemctl\s+(enable|disable|mask)\s+[^-]|systemctl\s+daemon-reload" "$PROJECT_DIR" --include="*.sh" --include="*.py" 2>/dev/null && { DANGER_INDICATORS+=("System systemd modifications"); ((DANGER_SCORE += 80)); }
    grep -rqE "sddm|gdm|lightdm|/etc/X11|xorg\.conf" "$PROJECT_DIR" --include="*.sh" --include="*.conf" --include="*.py" 2>/dev/null && { DANGER_INDICATORS+=("Display manager config"); ((DANGER_SCORE += 80)); }
    grep -rqE "sysctl\s+-w|sysctl\.d|/proc/sys" "$PROJECT_DIR" --include="*.sh" --include="*.py" --include="*.conf" 2>/dev/null && { DANGER_INDICATORS+=("sysctl changes"); ((DANGER_SCORE += 70)); }
    grep -rqE "/etc/dbus-1|dbus-1/system\.d" "$PROJECT_DIR" --include="*.sh" --include="*.conf" --include="*.py" 2>/dev/null && { DANGER_INDICATORS+=("D-Bus system bus mods"); ((DANGER_SCORE += 70)); }
    grep -rqE "udisksctl|mkfs\.|parted|fdisk|gdisk" "$PROJECT_DIR" --include="*.sh" --include="*.py" 2>/dev/null && { DANGER_INDICATORS+=("Disk/device management"); ((DANGER_SCORE += 70)); }

    # MEDIUM (40-60 pts): system service files, init.d, udev, network, firewall, fstab, compositor, package mgr
    find "$PROJECT_DIR" -name "*.service" -exec grep -L "WantedBy=default.target" {} \; 2>/dev/null | grep -q . && { DANGER_INDICATORS+=("System-level service files"); ((DANGER_SCORE += 60)); }
    find "$PROJECT_DIR" -path "*/init.d/*" -o -name "*.init" 2>/dev/null | grep -q . && { DANGER_INDICATORS+=("init.d scripts"); ((DANGER_SCORE += 60)); }
    find "$PROJECT_DIR" -name "*.rules" 2>/dev/null | xargs grep -l "SUBSYSTEM\|KERNEL\|ATTR" 2>/dev/null | grep -q . && { DANGER_INDICATORS+=("udev rules"); ((DANGER_SCORE += 60)); }
    grep -rqE "/etc/fstab" "$PROJECT_DIR" --include="*.sh" --include="*.py" 2>/dev/null && { DANGER_INDICATORS+=("fstab modifications"); ((DANGER_SCORE += 60)); }
    grep -rqE "kwinrc|mutter|weston|sway/config|hyprland" "$PROJECT_DIR" --include="*.sh" --include="*.conf" 2>/dev/null && { DANGER_INDICATORS+=("Window compositor config"); ((DANGER_SCORE += 50)); }
    grep -rqE "/etc/systemd/network|/etc/NetworkManager|nmcli\s+con|ip\s+(addr|link|route)" "$PROJECT_DIR" --include="*.sh" --include="*.py" --include="*.conf" 2>/dev/null && { DANGER_INDICATORS+=("Network config changes"); ((DANGER_SCORE += 50)); }
    grep -rqE "iptables|nftables|firewall-cmd|ufw" "$PROJECT_DIR" --include="*.sh" --include="*.py" 2>/dev/null && { DANGER_INDICATORS+=("Firewall rules"); ((DANGER_SCORE += 50)); }
    grep -rqE "pacman\s+-S|apt\s+install|dnf\s+install|yum\s+install" "$PROJECT_DIR" --include="*.sh" --include="*.py" 2>/dev/null && { DANGER_INDICATORS+=("System package installation"); ((DANGER_SCORE += 40)); }

    # LOW (30 pts): BTRFS
    grep -rqE "btrfs\s+subvolume|btrfs\s+property" "$PROJECT_DIR" --include="*.sh" --include="*.py" 2>/dev/null && { DANGER_INDICATORS+=("BTRFS subvolume ops"); ((DANGER_SCORE += 30)); }

    # Thresholds: 0-29=sandbox, 30-59=sandbox-warn, 60-99=vm-recommended, 100+=vm-required
    local ISOLATION_LEVEL="sandbox"
    [ "$DANGER_SCORE" -ge 100 ] && ISOLATION_LEVEL="vm-required"
    [ "$DANGER_SCORE" -ge 60 ] && [ "$DANGER_SCORE" -lt 100 ] && ISOLATION_LEVEL="vm-recommended"
    [ "$DANGER_SCORE" -ge 30 ] && [ "$DANGER_SCORE" -lt 60 ] && ISOLATION_LEVEL="sandbox-warn"

    echo "Danger Score: $DANGER_SCORE"
    echo "Isolation Level: $ISOLATION_LEVEL"
    echo "Danger Indicators: ${DANGER_INDICATORS[*]:-none}"
    export ISOLATION_LEVEL DANGER_SCORE
}

detect_isolation_level
```

**Dispatcher Integration:**
- `vm-required` + no VM available: ABORT
- `vm-required` or `vm-recommended` + VM available: Phase V
- `sandbox-warn`: Standard test execution (Phase 2) with extra monitoring
- `sandbox`: Standard test execution (Phase 2)

---

## OPTIONAL Detections (project-type-specific)

### 1b. Detect Staged Release

Check for `.staged-release` breadcrumb written by `/git-release --local`:

```bash
detect_staged_release() {
    local PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
    local STAGED_FILE="$PROJECT_DIR/.staged-release"

    if [[ ! -f "$STAGED_FILE" ]]; then
        echo "Staged Release: none"
        return 0
    fi

    source "$STAGED_FILE"

    # Verify tag exists and points to correct commit
    local STAGED_STATUS="invalid"
    if [[ -n "$tag" ]] && git tag -l "$tag" 2>/dev/null | grep -q "$tag"; then
        local TAG_COMMIT=$(git rev-list -n 1 "$tag" 2>/dev/null)
        [[ "$TAG_COMMIT" == "$commit"* ]] && STAGED_STATUS="valid"
    fi

    echo "Staged Release: $STAGED_STATUS"
    echo "Staged Version: ${version:-}"
    echo "Staged Tag: ${tag:-}"
    echo "Staged Commit: ${commit:-}"

    # Detect Docker staging images
    if [[ -f "$PROJECT_DIR/Dockerfile" ]] && command -v docker &>/dev/null; then
        local PROJECT_NAME=$(basename "$PROJECT_DIR" | tr '[:upper:]' '[:lower:]')
        local DOCKER_STAGING=$(docker images --format '{{.Repository}}:{{.Tag}}' 2>/dev/null | \
            grep -iE "${PROJECT_NAME}.*(rc|staging|${version:-NOMATCH})" | head -5)
        echo "Docker Staging Images: ${DOCKER_STAGING:-none}"
    else
        echo "Docker Staging Images: none"
    fi
}

detect_staged_release
```

When Discovery reports `Staged Release: valid`, Phase V is triggered and routes to the correct VM via `project-vm-map.json`.

### 4b. Detect Available MCP Servers

```bash
detect_mcp_servers() {
    local SETTINGS_FILE="$HOME/.claude/settings.json"
    [ ! -f "$SETTINGS_FILE" ] && { echo "MCP Servers Available: 0"; return 0; }

    local mcp_count=0
    for plugin in playwright pyright-lsp typescript-lsp rust-analyzer-lsp gopls-lsp clangd-lsp context7 greptile; do
        if grep -q "\"${plugin}@claude-plugins-official\": true" "$SETTINGS_FILE" 2>/dev/null; then
            echo "  [ok] $plugin"
            ((mcp_count++))
        fi
    done
    echo "MCP Servers Available: $mcp_count"
}

detect_mcp_servers
```

**MCP usage by phase:** playwright (A, 2a for E2E), LSP servers (7 for type checking), context7/greptile (1, 5 for codebase analysis). Prefer MCP over CLI when available.

### 4b-2. Auto-Enable MCP Servers for Testing

When needed MCP servers are disabled, temporarily enable them (tracked in `.test-mcp-enabled` for Phase C cleanup):

```bash
auto_enable_mcp_servers() {
    local PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
    local SETTINGS_FILE="$HOME/.claude/settings.json"
    local MCP_ENABLED_FILE="${PROJECT_DIR}/.test-mcp-enabled"
    local ENABLED_SERVERS=()

    [ ! -w "$SETTINGS_FILE" ] && return 1

    # Detect project needs
    local NEED_PLAYWRIGHT=false NEED_PYRIGHT=false NEED_TYPESCRIPT=false
    [[ -d "$PROJECT_DIR/frontend" || -d "$PROJECT_DIR/web" || -f "$PROJECT_DIR/index.html" ]] && NEED_PLAYWRIGHT=true
    grep -qE "react|vue|angular|svelte|next" "$PROJECT_DIR/package.json" 2>/dev/null && NEED_PLAYWRIGHT=true
    find "$PROJECT_DIR" -name "*.py" -not -path "*/.venv/*" -not -path "*/venv/*" | head -1 | grep -q . && NEED_PYRIGHT=true
    [[ -f "$PROJECT_DIR/tsconfig.json" ]] && NEED_TYPESCRIPT=true

    enable_plugin() {
        local plugin="$1"
        if grep -q "\"${plugin}@claude-plugins-official\": false" "$SETTINGS_FILE" 2>/dev/null; then
            sed -i "s/\"${plugin}@claude-plugins-official\": false/\"${plugin}@claude-plugins-official\": true/" "$SETTINGS_FILE"
            ENABLED_SERVERS+=("$plugin")
        fi
    }

    $NEED_PLAYWRIGHT && enable_plugin "playwright"
    $NEED_PYRIGHT && enable_plugin "pyright-lsp"
    $NEED_TYPESCRIPT && enable_plugin "typescript-lsp"

    [ ${#ENABLED_SERVERS[@]} -gt 0 ] && printf '%s\n' "${ENABLED_SERVERS[@]}" > "$MCP_ENABLED_FILE"
    echo "MCP Servers Auto-Enabled: ${#ENABLED_SERVERS[@]}"
}

[ "${TEST_READONLY:-false}" != "true" ] && auto_enable_mcp_servers
```

### 4c. Detect GitHub Repository

```bash
detect_github_repo() {
    local PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"

    git -C "$PROJECT_DIR" rev-parse --git-dir &>/dev/null || { echo "GitHub Status: not-a-repo"; return 1; }

    local REMOTE_URL=$(git -C "$PROJECT_DIR" remote get-url origin 2>/dev/null)
    [[ -z "$REMOTE_URL" ]] && { echo "GitHub Status: no-remote"; return 1; }
    [[ ! "$REMOTE_URL" =~ github\.com ]] && { echo "GitHub Status: not-github"; return 1; }

    # Extract owner/repo
    [[ "$REMOTE_URL" =~ github\.com[:/]([^/]+)/([^/.]+)(\.git)?$ ]] || { echo "GitHub Status: parse-error"; return 1; }
    local OWNER="${BASH_REMATCH[1]}" REPO="${BASH_REMATCH[2]}"
    echo "GitHub Repo: $OWNER/$REPO"

    # Check gh CLI auth
    command -v gh &>/dev/null || { echo "GitHub Status: gh-not-installed"; echo "GitHub Authenticated: false"; return 0; }
    gh auth status &>/dev/null 2>&1 || { echo "GitHub Status: not-authenticated"; echo "GitHub Authenticated: false"; return 0; }
    echo "GitHub Authenticated: true"

    gh repo view "$OWNER/$REPO" &>/dev/null 2>&1 || { echo "GitHub Status: no-access"; return 0; }

    # Security alerts
    local DEP_ALERTS=$(gh api "repos/$OWNER/$REPO/dependabot/alerts?state=open" --jq 'length' 2>/dev/null || echo "0")
    local CODE_ALERTS=$(gh api "repos/$OWNER/$REPO/code-scanning/alerts?state=open" --jq 'length' 2>/dev/null || echo "0")
    local SECRET_ALERTS=$(gh api "repos/$OWNER/$REPO/secret-scanning/alerts?state=open" --jq 'length' 2>/dev/null || echo "0")
    local TOTAL=$((DEP_ALERTS + CODE_ALERTS + SECRET_ALERTS))

    echo "GitHub Alerts: $TOTAL"

    # Sync status
    local LOCAL=$(git -C "$PROJECT_DIR" rev-list --count HEAD ^origin/main 2>/dev/null || git -C "$PROJECT_DIR" rev-list --count HEAD ^origin/master 2>/dev/null || echo "0")
    local REMOTE=$(git -C "$PROJECT_DIR" rev-list --count origin/main ^HEAD 2>/dev/null || git -C "$PROJECT_DIR" rev-list --count origin/master ^HEAD 2>/dev/null || echo "0")
    [[ "$LOCAL" -gt 0 ]] && echo "  $LOCAL local commit(s) not pushed"
    [[ "$REMOTE" -gt 0 ]] && echo "  $REMOTE remote commit(s) not pulled"

    [[ "$TOTAL" -gt 0 ]] && echo "GitHub Status: alerts-open" || echo "GitHub Status: secure"
}

detect_github_repo
```

### 4d. Detect Custom Pytest Options

```bash
detect_pytest_options() {
    local PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
    local CONFTEST=""

    for f in $(find "$PROJECT_DIR" -maxdepth 3 -name "conftest.py" 2>/dev/null); do
        [ -f "$f" ] && { CONFTEST="$f"; break; }
    done

    [ -z "$CONFTEST" ] && { echo "Pytest Extra Flags: (none)"; return 0; }

    local CUSTOM_FLAGS=() CUSTOM_RESOURCE=()
    while IFS='|' read -r flag help resource; do
        [ -n "$flag" ] && { CUSTOM_FLAGS+=("$flag"); CUSTOM_RESOURCE+=("${resource:-other}"); }
    done < <(python3 - "$CONFTEST" <<'PYEOF'
import re, sys
with open(sys.argv[1]) as f:
    content = f.read()
pattern = re.compile(r'addoption\s*\(\s*["\x27](--[^"\x27]+)["\x27](.*?)\n\s*\)', re.DOTALL)
for match in pattern.finditer(content):
    block = match.group(0)
    flag = match.group(1)
    help_match = re.search(r'help\s*=\s*["\x27]([^"\x27]+)["\x27]', block)
    help_text = help_match.group(1) if help_match else "No description"
    flag_lower = flag.lower()
    help_lower = help_text.lower()
    if any(kw in flag_lower or kw in help_lower for kw in ["vm", "virtual machine", "integration"]):
        resource = "vm"
    elif any(kw in flag_lower or kw in help_lower for kw in ["hardware", "fido", "fido2", "yubikey", "webauthn", "passkey", "security key", "authenticator", "biometric", "touch"]):
        resource = "hardware"
    else:
        resource = "other"
    print(f"{flag}|{help_text}|{resource}")
PYEOF
)

    [ ${#CUSTOM_FLAGS[@]} -eq 0 ] && { echo "Pytest Extra Flags: (none)"; return 0; }

    for i in "${!CUSTOM_FLAGS[@]}"; do
        echo "Pytest Custom Option: ${CUSTOM_FLAGS[$i]} | ${CUSTOM_RESOURCE[$i]}"
    done
}

detect_pytest_options
```

**Resource flags (`vm`, `hardware`) ALWAYS prompt** (even in autonomous mode) since they require physical resources. Other flags follow normal mode rules. The dispatcher records the final selection as `Pytest Extra Flags: --vm --hardware` (or `(none)`).

### 5. Detect Installable Application

```bash
INSTALLABLE_APP="none"
INSTALL_METHOD=""

if [ -f "install-manifest.json" ] || [ -f ".install-manifest.json" ]; then
    INSTALLABLE_APP="manifest"; INSTALL_METHOD="install-manifest.json"
elif [ -f "install.sh" ] || [ -f "scripts/install.sh" ]; then
    INSTALLABLE_APP="script"; INSTALL_METHOD="install.sh"
elif [ -f "pyproject.toml" ] && grep -q '\[project.scripts\]' pyproject.toml 2>/dev/null; then
    INSTALLABLE_APP="python-package"; INSTALL_METHOD="pip install"
elif [ -f "setup.py" ] && grep -q 'entry_points\|scripts' setup.py 2>/dev/null; then
    INSTALLABLE_APP="python-package"; INSTALL_METHOD="pip install"
elif [ -f "package.json" ] && grep -q '"bin"' package.json 2>/dev/null; then
    INSTALLABLE_APP="npm-package"; INSTALL_METHOD="npm install -g"
elif [ -f "go.mod" ] && [ -d "cmd" ]; then
    INSTALLABLE_APP="go-binary"; INSTALL_METHOD="go install"
elif [ -f "Cargo.toml" ] && grep -q '\[\[bin\]\]' Cargo.toml 2>/dev/null; then
    INSTALLABLE_APP="rust-binary"; INSTALL_METHOD="cargo install"
elif ls *.service systemd/*.service 2>/dev/null | head -1; then
    INSTALLABLE_APP="systemd-service"; INSTALL_METHOD="systemctl"
elif [ -f "Makefile" ] && grep -q '^install:' Makefile 2>/dev/null; then
    INSTALLABLE_APP="makefile"; INSTALL_METHOD="make install"
fi

echo "Installable App: $INSTALLABLE_APP"
echo "Install Method: $INSTALL_METHOD"
```

### 6. Check Production Installation Status

```bash
check_production_status() {
    local PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
    local PROJECT_NAME=$(basename "$PROJECT_DIR")
    local STATUS="not-installed" DETAILS="No production installation detected"

    # Check install-manifest.json binary paths
    if [ -f "install-manifest.json" ]; then
        local BIN=$(grep -o '"paths"[[:space:]]*:[[:space:]]*\[[^]]*\]' install-manifest.json 2>/dev/null | grep -o '"[^"]*"' | head -1 | tr -d '"' | sed "s|~|$HOME|g")
        [ -n "$BIN" ] && [ -x "$BIN" ] && { STATUS="installed"; DETAILS="Found: $BIN"; }
    fi

    # Check common bin locations
    if [ "$STATUS" = "not-installed" ]; then
        for p in "$HOME/.local/bin/$PROJECT_NAME" "/usr/local/bin/$PROJECT_NAME" "/usr/bin/$PROJECT_NAME"; do
            [ -x "$p" ] && { STATUS="installed"; DETAILS="Found: $p"; break; }
        done
    fi

    # Check systemd services
    if [ "$STATUS" = "not-installed" ]; then
        if systemctl --user is-active "$PROJECT_NAME.service" &>/dev/null || systemctl is-active "$PROJECT_NAME.service" &>/dev/null; then
            STATUS="installed"; DETAILS="Service running: $PROJECT_NAME.service"
        elif [ -f "$HOME/.config/systemd/user/$PROJECT_NAME.service" ] || [ -f "/etc/systemd/system/$PROJECT_NAME.service" ]; then
            STATUS="installed-not-running"; DETAILS="Service installed but not active"
        fi
    fi

    echo "Production Status: $STATUS"
    echo "Production Details: $DETAILS"
}

check_production_status
```

### 7. Detect Docker Image and Registry Package

```bash
check_docker_status() {
    local PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
    local PROJECT_NAME=$(basename "$PROJECT_DIR")

    [ ! -f "$PROJECT_DIR/Dockerfile" ] && { echo "Docker Status: none"; return 0; }

    echo "Docker Status: exists"
    local REGISTRY_IMAGE="" REGISTRY_STATUS="not-found" REGISTRY_VERSION="" PROJECT_VERSION=""

    # Determine registry image name
    if [ -f "$PROJECT_DIR/.docker-image" ]; then
        REGISTRY_IMAGE=$(cat "$PROJECT_DIR/.docker-image" | tr -d '[:space:]')
    elif [ -f "$PROJECT_DIR/docker-compose.yml" ]; then
        REGISTRY_IMAGE=$(grep -E '^\s+image:' "$PROJECT_DIR/docker-compose.yml" | head -1 | sed 's/.*image:\s*//' | tr -d '"'"'" | tr -d '[:space:]')
    else
        local GIT_REMOTE=$(git -C "$PROJECT_DIR" remote get-url origin 2>/dev/null)
        [[ "$GIT_REMOTE" =~ github\.com[:/]([^/]+)/([^/.]+) ]] && REGISTRY_IMAGE="ghcr.io/${BASH_REMATCH[1],,}/${BASH_REMATCH[2],,}"
    fi

    [ -f "$PROJECT_DIR/VERSION" ] && PROJECT_VERSION=$(cat "$PROJECT_DIR/VERSION" | tr -d '[:space:]')

    # Check registry
    if [ -n "$REGISTRY_IMAGE" ] && command -v docker &>/dev/null; then
        if [ -n "$PROJECT_VERSION" ] && docker manifest inspect "${REGISTRY_IMAGE}:${PROJECT_VERSION}" &>/dev/null; then
            REGISTRY_STATUS="found"; REGISTRY_VERSION="$PROJECT_VERSION"
        elif docker manifest inspect "${REGISTRY_IMAGE}:latest" &>/dev/null; then
            [ -n "$PROJECT_VERSION" ] && REGISTRY_STATUS="version-mismatch" || REGISTRY_STATUS="found"
            REGISTRY_VERSION="latest"
        fi
    fi

    echo "Registry Image: ${REGISTRY_IMAGE:-N/A}"
    echo "Registry Status: $REGISTRY_STATUS"
    echo "Registry Version: ${REGISTRY_VERSION:-N/A}"
    echo "Project Version: ${PROJECT_VERSION:-N/A}"
}

check_docker_status
```

---

## Gate Decisions (for dispatcher)

| Phase | Condition | Action |
|-------|-----------|--------|
| **P** | `Installable App: none` | SKIP |
| **P** | `Production Status: installed` | RUN |
| **P** | `Production Status: not-installed` | PROMPT user |
| **D** | `Docker Status: none` | SKIP |
| **D** | `Docker Status: exists` + `Registry: found` | RUN |
| **D** | `Docker Status: exists` + `Registry: not-found` | PROMPT user |
| **G** | No GitHub repo or not authenticated | SKIP |
| **G** | GitHub repo with auth | RUN |
| **V** | `Staged Release: valid` | RUN |
| **V** | `Isolation Level: vm-required` | RUN (abort if no VM) |
| **V** | `Isolation Level: vm-recommended` + VM available | RUN |
