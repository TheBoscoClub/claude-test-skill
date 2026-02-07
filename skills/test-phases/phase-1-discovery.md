# Phase 1: Discovery

> **Model**: `opus` | **Tier**: 1 (Discovery — GATE) | **Modifies Files**: No
> **Task Tracking**: Call `TaskUpdate(taskId, status="in_progress")` at start, `TaskUpdate(taskId, status="completed")` when done. All subsequent phases depend on this — use `addBlocks` to express downstream dependencies.
> **Key Tools**: `Bash`, `Glob`, `Grep`, `Read` for project analysis. Use `WebSearch` to identify framework conventions if an unfamiliar project type is detected.

Identify project type, test framework, and testable components.

## Execution Steps

### 1. Detect Project Type

| File | Type | Test Command |
|------|------|--------------|
| `package.json` | Node.js | `npm test` |
| `pyproject.toml` | Python (modern) | `pytest` |
| `setup.py` | Python (legacy) | `python -m pytest` |
| `requirements.txt` | Python | `pytest` |
| `go.mod` | Go | `go test ./...` |
| `Cargo.toml` | Rust | `cargo test` |
| `Makefile` | Make-based | `make test` |
| `pom.xml` | Java/Maven | `mvn test` |
| `build.gradle` | Java/Gradle | `gradle test` |
| `Dockerfile` | Docker | `docker build` |
| `docker-compose.yml` | Docker Compose | `docker compose up` |

**IMPORTANT: Docker Detection**

Check for Docker files in the project root. This is MANDATORY — do not skip:
```bash
# Check project root for Docker files — ALWAYS report these
ls -la Dockerfile docker-compose.yml .dockerignore compose.yml 2>/dev/null
```
If `Dockerfile` exists, report `Docker Status: exists` in the output.
If `docker-compose.yml` or `compose.yml` exists, report the image name from it.

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
# Test configs
ls -la pytest.ini pyproject.toml jest.config.* vitest.config.* .mocharc.* 2>/dev/null

# CI configs
ls -la .github/workflows/*.yml .gitlab-ci.yml Jenkinsfile 2>/dev/null
```

### 4. Check Dependencies

```bash
# Python
pip list 2>/dev/null | grep -iE "pytest|unittest|nose"

# Node
npm ls 2>/dev/null | grep -iE "jest|mocha|vitest|playwright"
```

### 4a. Detect Available Analysis Tools

Detect which code analysis, security, and quality tools are installed locally:

```bash
echo ""
echo "───────────────────────────────────────────────────────────────────"
echo "  Available Analysis Tools"
echo "───────────────────────────────────────────────────────────────────"

declare -A TOOLS_AVAILABLE

# Python Tools
check_tool() {
    local name="$1"
    local cmd="$2"
    if command -v "$cmd" &>/dev/null; then
        echo "  ✅ $name ($cmd)"
        TOOLS_AVAILABLE["$name"]=1
        return 0
    else
        echo "  ⚪ $name (not installed)"
        TOOLS_AVAILABLE["$name"]=0
        return 1
    fi
}

echo ""
echo "Python:"
check_tool "ruff" "ruff"
check_tool "mypy" "mypy"
check_tool "pylint" "pylint"
check_tool "bandit" "bandit"
check_tool "black" "black"
check_tool "isort" "isort"
check_tool "pip-audit" "pip-audit"
check_tool "radon" "radon"
check_tool "pydocstyle" "pydocstyle"

echo ""
echo "Shell:"
check_tool "shellcheck" "shellcheck"
check_tool "shfmt" "shfmt"

echo ""
echo "JavaScript/TypeScript:"
check_tool "eslint" "eslint"
check_tool "prettier" "prettier"
check_tool "tsc" "tsc"

echo ""
echo "YAML/Config:"
check_tool "yamllint" "yamllint"

echo ""
echo "Docker:"
check_tool "hadolint" "hadolint"

echo ""
echo "Documentation:"
check_tool "markdownlint" "markdownlint"
check_tool "codespell" "codespell"

echo ""
echo "Security:"
check_tool "codeql" "codeql"
check_tool "trivy" "trivy"
check_tool "grype" "grype"

echo ""
echo "Go:"
check_tool "golangci-lint" "golangci-lint"
check_tool "govulncheck" "govulncheck"

echo ""
echo "Rust:"
check_tool "cargo-clippy" "cargo-clippy"
check_tool "cargo-audit" "cargo-audit"

# Export tools status for other phases
export TOOLS_AVAILABLE
```

### 4b. Detect Available MCP Servers

Detect which MCP (Model Context Protocol) servers are available for enhanced testing:

```bash
echo ""
echo "───────────────────────────────────────────────────────────────────"
echo "  Available MCP Servers"
echo "───────────────────────────────────────────────────────────────────"

detect_mcp_servers() {
    local SETTINGS_FILE="$HOME/.claude/settings.json"
    declare -A MCP_AVAILABLE

    if [ ! -f "$SETTINGS_FILE" ]; then
        echo "  ⚪ No Claude settings found"
        echo "MCP Servers: none"
        return 0
    fi

    # Check for enabled plugins that provide MCP functionality
    echo ""
    echo "  Testing/Automation:"

    # Playwright - E2E browser testing
    if grep -q '"playwright@claude-plugins-official": true' "$SETTINGS_FILE" 2>/dev/null; then
        echo "    ✅ playwright (E2E browser testing)"
        MCP_AVAILABLE["playwright"]=1
    else
        echo "    ⚪ playwright (disabled - enable for E2E testing)"
        MCP_AVAILABLE["playwright"]=0
    fi

    echo ""
    echo "  Code Intelligence:"

    # LSP servers for type checking and diagnostics
    for lsp in pyright-lsp typescript-lsp rust-analyzer-lsp gopls-lsp clangd-lsp; do
        if grep -q "\"${lsp}@claude-plugins-official\": true" "$SETTINGS_FILE" 2>/dev/null; then
            echo "    ✅ $lsp"
            MCP_AVAILABLE["$lsp"]=1
        fi
    done

    echo ""
    echo "  Codebase Analysis:"

    # Context7 - codebase context
    if grep -q '"context7@claude-plugins-official": true' "$SETTINGS_FILE" 2>/dev/null; then
        echo "    ✅ context7 (codebase context)"
        MCP_AVAILABLE["context7"]=1
    else
        echo "    ⚪ context7 (disabled)"
        MCP_AVAILABLE["context7"]=0
    fi

    # Greptile - code search
    if grep -q '"greptile@claude-plugins-official": true' "$SETTINGS_FILE" 2>/dev/null; then
        echo "    ✅ greptile (code search)"
        MCP_AVAILABLE["greptile"]=1
    else
        echo "    ⚪ greptile (disabled)"
        MCP_AVAILABLE["greptile"]=0
    fi

    # Count enabled MCP servers
    local mcp_count=0
    for key in "${!MCP_AVAILABLE[@]}"; do
        if [ "${MCP_AVAILABLE[$key]}" -eq 1 ]; then
            ((mcp_count++))
        fi
    done

    echo ""
    echo "MCP Servers Available: $mcp_count"

    # Export for other phases
    export MCP_AVAILABLE
}

detect_mcp_servers
```

**MCP Server Usage in /test Phases:**

| MCP Server | Phase | Usage |
|------------|-------|-------|
| **playwright** | A, 2a | Run E2E browser tests for web UIs |
| **pyright-lsp** | 7 | Real-time Python type checking with project context |
| **typescript-lsp** | 7 | TypeScript type checking and diagnostics |
| **rust-analyzer-lsp** | 7 | Rust analysis and diagnostics |
| **gopls-lsp** | 7 | Go analysis and diagnostics |
| **clangd-lsp** | 7 | C/C++ analysis and diagnostics |
| **context7** | 1, 5 | Enhanced codebase understanding |
| **greptile** | 1 | Semantic code search |

**Note:** When MCP servers are available, phases should prefer them over CLI tools for richer, context-aware analysis.

### 4b-2. Auto-Enable MCP Servers for Testing

When certain MCP servers would benefit testing but are disabled, `/test` can temporarily enable them:

```bash
auto_enable_mcp_servers() {
    local PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
    local SETTINGS_FILE="$HOME/.claude/settings.json"
    local MCP_ENABLED_FILE="${PROJECT_DIR}/.test-mcp-enabled"
    local ENABLED_SERVERS=()

    # Check if settings file is writable
    if [ ! -w "$SETTINGS_FILE" ]; then
        echo "  ⚠️ Cannot modify settings.json (not writable)"
        return 1
    fi

    echo ""
    echo "───────────────────────────────────────────────────────────────────"
    echo "  Auto-Enable MCP Servers"
    echo "───────────────────────────────────────────────────────────────────"

    # Determine which servers would help this project
    local NEED_PLAYWRIGHT=false
    local NEED_PYRIGHT=false
    local NEED_TYPESCRIPT=false

    # Check for web UI (needs playwright)
    if [[ -d "$PROJECT_DIR/frontend" ]] || \
       [[ -d "$PROJECT_DIR/web" ]] || \
       [[ -f "$PROJECT_DIR/index.html" ]] || \
       grep -qE "react|vue|angular|svelte|next" "$PROJECT_DIR/package.json" 2>/dev/null; then
        NEED_PLAYWRIGHT=true
    fi

    # Check for Python (needs pyright-lsp)
    if find "$PROJECT_DIR" -name "*.py" -not -path "*/.venv/*" -not -path "*/venv/*" | head -1 | grep -q .; then
        NEED_PYRIGHT=true
    fi

    # Check for TypeScript (needs typescript-lsp)
    if [[ -f "$PROJECT_DIR/tsconfig.json" ]] || \
       find "$PROJECT_DIR" -name "*.ts" -o -name "*.tsx" 2>/dev/null | head -1 | grep -q .; then
        NEED_TYPESCRIPT=true
    fi

    # Enable needed but disabled servers
    enable_plugin() {
        local plugin="$1"
        local plugin_key="${plugin}@claude-plugins-official"

        # Check if disabled
        if grep -q "\"$plugin_key\": false" "$SETTINGS_FILE" 2>/dev/null; then
            echo "  🔌 Enabling $plugin for testing..."

            # Use sed to enable (replace false with true)
            sed -i "s/\"$plugin_key\": false/\"$plugin_key\": true/" "$SETTINGS_FILE"

            # Track for cleanup
            ENABLED_SERVERS+=("$plugin")
            echo "    ✅ Enabled $plugin"
            return 0
        else
            echo "  ✓ $plugin already enabled or not installed"
            return 1
        fi
    }

    # Enable servers based on project needs
    if $NEED_PLAYWRIGHT; then
        if grep -q '"playwright@claude-plugins-official": false' "$SETTINGS_FILE" 2>/dev/null; then
            enable_plugin "playwright"
        fi
    fi

    if $NEED_PYRIGHT; then
        if grep -q '"pyright-lsp@claude-plugins-official": false' "$SETTINGS_FILE" 2>/dev/null; then
            enable_plugin "pyright-lsp"
        fi
    fi

    if $NEED_TYPESCRIPT; then
        if grep -q '"typescript-lsp@claude-plugins-official": false' "$SETTINGS_FILE" 2>/dev/null; then
            enable_plugin "typescript-lsp"
        fi
    fi

    # Save list of enabled servers for cleanup
    if [ ${#ENABLED_SERVERS[@]} -gt 0 ]; then
        printf '%s\n' "${ENABLED_SERVERS[@]}" > "$MCP_ENABLED_FILE"
        echo ""
        echo "  📝 Saved enabled servers list to: $MCP_ENABLED_FILE"
        echo "     (Phase C will disable these during cleanup)"
    else
        echo ""
        echo "  ✓ No servers needed to be enabled"
    fi

    echo ""
    echo "MCP Servers Auto-Enabled: ${#ENABLED_SERVERS[@]}"
    for server in "${ENABLED_SERVERS[@]}"; do
        echo "  - $server"
    done

    export MCP_ENABLED_SERVERS=("${ENABLED_SERVERS[@]}")
}

# Run auto-enable if not in read-only mode
if [ "${TEST_READONLY:-false}" != "true" ]; then
    auto_enable_mcp_servers
fi
```

**Auto-Enable Rules:**

| Project Has | MCP Server | Action |
|-------------|------------|--------|
| Web UI (React, Vue, etc.) | playwright | Enable for E2E testing |
| Python files | pyright-lsp | Enable for type checking |
| TypeScript files | typescript-lsp | Enable for TS diagnostics |
| Go files | gopls-lsp | Enable for Go analysis |
| Rust files | rust-analyzer-lsp | Enable for Rust analysis |

**Important:** All auto-enabled servers are tracked in `.test-mcp-enabled` and will be disabled during Phase C (Cleanup).

### 4c. Detect GitHub Repository

Check if the local project has a corresponding GitHub repository:

```bash
echo ""
echo "───────────────────────────────────────────────────────────────────"
echo "  GitHub Repository Detection"
echo "───────────────────────────────────────────────────────────────────"

detect_github_repo() {
    local PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"

    # Initialize variables
    GITHUB_REPO=""
    GITHUB_OWNER=""
    GITHUB_REPO_NAME=""
    GITHUB_REMOTE_URL=""
    GITHUB_AUTHENTICATED=false
    GITHUB_SECURITY_STATUS="unknown"

    # Check for git repo
    if ! git -C "$PROJECT_DIR" rev-parse --git-dir &>/dev/null; then
        echo "  ⚪ Not a git repository"
        echo "GitHub Status: not-a-repo"
        return 1
    fi

    # Get remote URL
    GITHUB_REMOTE_URL=$(git -C "$PROJECT_DIR" remote get-url origin 2>/dev/null)

    if [[ -z "$GITHUB_REMOTE_URL" ]]; then
        echo "  ⚪ No remote origin configured"
        echo "GitHub Status: no-remote"
        return 1
    fi

    # Check if it's a GitHub remote
    if [[ ! "$GITHUB_REMOTE_URL" =~ github\.com ]]; then
        echo "  ⚪ Remote is not GitHub: $GITHUB_REMOTE_URL"
        echo "GitHub Status: not-github"
        return 1
    fi

    # Extract owner/repo
    if [[ "$GITHUB_REMOTE_URL" =~ github\.com[:/]([^/]+)/([^/.]+)(\.git)?$ ]]; then
        GITHUB_OWNER="${BASH_REMATCH[1]}"
        GITHUB_REPO_NAME="${BASH_REMATCH[2]}"
        GITHUB_REPO="$GITHUB_OWNER/$GITHUB_REPO_NAME"
    else
        echo "  ⚠️ Could not parse GitHub URL: $GITHUB_REMOTE_URL"
        echo "GitHub Status: parse-error"
        return 1
    fi

    echo "  Repository: $GITHUB_REPO"
    echo "  Remote URL: $GITHUB_REMOTE_URL"

    # Check gh CLI authentication
    if ! command -v gh &>/dev/null; then
        echo "  ⚠️ GitHub CLI (gh) not installed"
        echo "GitHub Status: gh-not-installed"
        echo "GitHub Repo: $GITHUB_REPO"
        return 0
    fi

    if ! gh auth status &>/dev/null 2>&1; then
        echo "  ⚠️ GitHub CLI not authenticated"
        echo "GitHub Status: not-authenticated"
        echo "GitHub Repo: $GITHUB_REPO"
        return 0
    fi

    GITHUB_AUTHENTICATED=true
    echo "  ✅ GitHub CLI authenticated"

    # Check repository existence and access
    if ! gh repo view "$GITHUB_REPO" &>/dev/null 2>&1; then
        echo "  ⚠️ Cannot access repository (may be deleted or private without access)"
        echo "GitHub Status: no-access"
        echo "GitHub Repo: $GITHUB_REPO"
        return 0
    fi

    # Check security features
    echo ""
    echo "  Security Features:"

    # Dependabot alerts
    if gh api "repos/$GITHUB_REPO/vulnerability-alerts" &>/dev/null 2>&1; then
        echo "    ✅ Dependabot alerts: Enabled"
        DEPENDABOT_ENABLED=true
    else
        echo "    ⚠️ Dependabot alerts: Not enabled"
        DEPENDABOT_ENABLED=false
    fi

    # Check for security workflows
    WORKFLOWS=$(gh api "repos/$GITHUB_REPO/contents/.github/workflows" 2>/dev/null | jq -r '.[].name' 2>/dev/null)
    if echo "$WORKFLOWS" | grep -qiE "codeql|security|shellcheck"; then
        echo "    ✅ Security workflows: Found"
        SECURITY_WORKFLOWS=true
    else
        echo "    ⚠️ Security workflows: Not found"
        SECURITY_WORKFLOWS=false
    fi

    # Check open security alerts count
    DEPENDABOT_ALERTS=$(gh api "repos/$GITHUB_REPO/dependabot/alerts?state=open" --jq 'length' 2>/dev/null || echo "0")
    CODE_SCANNING_ALERTS=$(gh api "repos/$GITHUB_REPO/code-scanning/alerts?state=open" --jq 'length' 2>/dev/null || echo "0")
    SECRET_ALERTS=$(gh api "repos/$GITHUB_REPO/secret-scanning/alerts?state=open" --jq 'length' 2>/dev/null || echo "0")

    echo ""
    echo "  Open Security Alerts:"
    echo "    Dependabot: $DEPENDABOT_ALERTS"
    echo "    Code Scanning: $CODE_SCANNING_ALERTS"
    echo "    Secret Scanning: $SECRET_ALERTS"

    TOTAL_ALERTS=$((DEPENDABOT_ALERTS + CODE_SCANNING_ALERTS + SECRET_ALERTS))

    # Determine overall status
    if [[ "$TOTAL_ALERTS" -gt 0 ]]; then
        GITHUB_SECURITY_STATUS="alerts-open"
    elif [[ "$DEPENDABOT_ENABLED" == "true" ]] && [[ "$SECURITY_WORKFLOWS" == "true" ]]; then
        GITHUB_SECURITY_STATUS="secure"
    else
        GITHUB_SECURITY_STATUS="incomplete"
    fi

    # Check local vs remote sync
    echo ""
    echo "  Sync Status:"
    LOCAL_COMMITS=$(git -C "$PROJECT_DIR" rev-list --count HEAD ^origin/main 2>/dev/null || git -C "$PROJECT_DIR" rev-list --count HEAD ^origin/master 2>/dev/null || echo "0")
    REMOTE_COMMITS=$(git -C "$PROJECT_DIR" rev-list --count origin/main ^HEAD 2>/dev/null || git -C "$PROJECT_DIR" rev-list --count origin/master ^HEAD 2>/dev/null || echo "0")

    if [[ "$LOCAL_COMMITS" -gt 0 ]]; then
        echo "    ⚠️ $LOCAL_COMMITS local commit(s) not pushed"
    fi
    if [[ "$REMOTE_COMMITS" -gt 0 ]]; then
        echo "    ⚠️ $REMOTE_COMMITS remote commit(s) not pulled"
    fi
    if [[ "$LOCAL_COMMITS" -eq 0 ]] && [[ "$REMOTE_COMMITS" -eq 0 ]]; then
        echo "    ✅ In sync with remote"
    fi

    # Export results
    echo ""
    echo "GitHub Status: $GITHUB_SECURITY_STATUS"
    echo "GitHub Repo: $GITHUB_REPO"
    echo "GitHub Alerts: $TOTAL_ALERTS"
    echo "GitHub Authenticated: $GITHUB_AUTHENTICATED"

    export GITHUB_REPO GITHUB_OWNER GITHUB_REPO_NAME GITHUB_AUTHENTICATED GITHUB_SECURITY_STATUS
}

detect_github_repo
```

### 4d. Detect Custom Pytest Options

Check if the project registers custom pytest command-line options that gate optional test categories:

```bash
echo ""
echo "───────────────────────────────────────────────────────────────────"
echo "  Custom Pytest Options"
echo "───────────────────────────────────────────────────────────────────"

detect_pytest_options() {
    local PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
    local CONFTEST=""
    local CUSTOM_FLAGS=()
    local CUSTOM_HELP=()

    # Find conftest.py (check common locations)
    for f in "$PROJECT_DIR/conftest.py" \
             "$PROJECT_DIR/tests/conftest.py" \
             "$PROJECT_DIR/library/tests/conftest.py"; do
        if [ -f "$f" ]; then
            CONFTEST="$f"
            break
        fi
    done

    if [ -z "$CONFTEST" ]; then
        echo "  ⚪ No conftest.py found"
        echo "Pytest Extra Flags: (none)"
        return 0
    fi

    echo "  Scanning: $CONFTEST"

    # Extract addoption flags and their help text
    # Handles both single-line and multi-line addoption() calls
    # Uses Python for reliable parsing since conftest.py is Python
    local CUSTOM_RESOURCE=()

    while IFS='|' read -r flag help resource; do
        if [ -n "$flag" ]; then
            CUSTOM_FLAGS+=("$flag")
            CUSTOM_HELP+=("${help:-No description}")
            CUSTOM_RESOURCE+=("${resource:-other}")
            echo "    Found: $flag — ${help:-No description} [${resource:-other}]"
        fi
    done < <(python3 - "$CONFTEST" <<'PYEOF'
import re, sys
with open(sys.argv[1]) as f:
    content = f.read()
# Match addoption() blocks spanning multiple lines
# Uses \n\s*\) to find the closing paren on its own line (Python style)
pattern = re.compile(r'addoption\s*\(\s*["\x27](--[^"\x27]+)["\x27](.*?)\n\s*\)', re.DOTALL)
for match in pattern.finditer(content):
    block = match.group(0)
    flag = match.group(1)
    help_match = re.search(r'help\s*=\s*["\x27]([^"\x27]+)["\x27]', block)
    help_text = help_match.group(1) if help_match else "No description"
    # Classify flag as resource type based on name and help text
    # vm|hardware flags require physical resources or human presence
    flag_lower = flag.lower()
    help_lower = help_text.lower()
    if any(kw in flag_lower or kw in help_lower for kw in ["vm", "virtual machine", "integration"]):
        resource = "vm"
    elif any(kw in flag_lower or kw in help_lower for kw in [
        "hardware", "fido", "fido2", "yubikey", "webauthn", "passkey",
        "security key", "authenticator", "biometric", "touch"
    ]):
        resource = "hardware"
    else:
        resource = "other"
    print(f"{flag}|{help_text}|{resource}")
PYEOF
)

    if [ ${#CUSTOM_FLAGS[@]} -eq 0 ]; then
        echo "  ⚪ No custom pytest options found"
        echo "Pytest Extra Flags: (none)"
        return 0
    fi

    echo ""
    echo "  Detected ${#CUSTOM_FLAGS[@]} custom pytest option(s)"

    # Export for dispatcher to use with AskUserQuestion
    export PYTEST_CUSTOM_FLAGS="${CUSTOM_FLAGS[*]}"
    export PYTEST_CUSTOM_HELP="${CUSTOM_HELP[*]}"

    # Output flag details for the dispatcher to parse
    # Format: Pytest Custom Option: --flag | help text | resource-type
    # resource-type is: vm, hardware, or other
    for i in "${!CUSTOM_FLAGS[@]}"; do
        echo "Pytest Custom Option: ${CUSTOM_FLAGS[$i]} | ${CUSTOM_HELP[$i]} | ${CUSTOM_RESOURCE[$i]}"
    done
}

detect_pytest_options
```

**Dispatcher Interaction (after this step completes):**

Each detected flag has a resource type: `vm`, `hardware`, or `other`.

**Resource flags (`vm`, `hardware`) ALWAYS prompt — even in autonomous mode.**
These require physical resources or human presence that cannot be automated:
- `vm` — needs test VM running, takes longer, deliberate resource allocation
- `hardware` — needs physical human action (touch security key, approve passkey)

**Other flags** follow normal mode rules (prompt in interactive, skip in autonomous).

**Prompt behavior:**

1. **Resource flags detected** (any mode): Use `AskUserQuestion` to ask the user:
   - **Question**: "This project has tests requiring VM or hardware resources. Which should be included?"
   - **Options** (multiSelect: true): One option per `vm`/`hardware` flag
   - If `--hardware` is selected, append a reminder:
     "Hardware tests will require manual action (e.g., touch your security key when it flashes, or approve on your passkey device). Stay attentive during Phase 2."

2. **Only `other` flags detected + autonomous mode**: Skip the question, default to no extra flags.

3. **Only `other` flags detected + interactive mode**: Prompt as normal.

The dispatcher records the final selection in the discovery output as:
```
Pytest Extra Flags: --vm --hardware
```
(or `Pytest Extra Flags: (none)` if no flags selected or no custom options found)

### 5. Detect Installable Application

Determine if this project produces an installable/deployable application:

```bash
# Check for install indicators
INSTALLABLE_APP="none"
INSTALL_METHOD=""

# Explicit install manifest (highest priority)
if [ -f "install-manifest.json" ] || [ -f ".install-manifest.json" ]; then
    INSTALLABLE_APP="manifest"
    INSTALL_METHOD="install-manifest.json"
# Install script
elif [ -f "install.sh" ] || [ -f "scripts/install.sh" ]; then
    INSTALLABLE_APP="script"
    INSTALL_METHOD="install.sh"
# Python package with entry points
elif [ -f "pyproject.toml" ] && grep -q '\[project.scripts\]' pyproject.toml 2>/dev/null; then
    INSTALLABLE_APP="python-package"
    INSTALL_METHOD="pip install"
elif [ -f "setup.py" ] && grep -q 'entry_points\|scripts' setup.py 2>/dev/null; then
    INSTALLABLE_APP="python-package"
    INSTALL_METHOD="pip install"
# Node.js with bin
elif [ -f "package.json" ] && grep -q '"bin"' package.json 2>/dev/null; then
    INSTALLABLE_APP="npm-package"
    INSTALL_METHOD="npm install -g"
# Go binary
elif [ -f "go.mod" ] && [ -d "cmd" ]; then
    INSTALLABLE_APP="go-binary"
    INSTALL_METHOD="go install"
# Rust binary
elif [ -f "Cargo.toml" ] && grep -q '\[\[bin\]\]' Cargo.toml 2>/dev/null; then
    INSTALLABLE_APP="rust-binary"
    INSTALL_METHOD="cargo install"
# Systemd service files in project
elif ls *.service systemd/*.service 2>/dev/null | head -1; then
    INSTALLABLE_APP="systemd-service"
    INSTALL_METHOD="systemctl"
# Makefile with install target
elif [ -f "Makefile" ] && grep -q '^install:' Makefile 2>/dev/null; then
    INSTALLABLE_APP="makefile"
    INSTALL_METHOD="make install"
fi

echo "Installable App: $INSTALLABLE_APP"
echo "Install Method: $INSTALL_METHOD"
```

### 6. Check Production Installation Status

If an installable app exists, determine if it's installed on this system:

```bash
check_production_status() {
    local PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
    local PROJECT_NAME=$(basename "$PROJECT_DIR")
    local PRODUCTION_STATUS="unknown"
    local PRODUCTION_DETAILS=""

    # Method 1: Check install-manifest.json for binary paths
    if [ -f "install-manifest.json" ]; then
        # Extract first binary path and check if it exists
        BINARY_PATH=$(grep -o '"paths"[[:space:]]*:[[:space:]]*\[[^]]*\]' install-manifest.json 2>/dev/null | \
                      grep -o '"[^"]*"' | head -1 | tr -d '"' | sed "s|~|$HOME|g")
        if [ -n "$BINARY_PATH" ] && [ -x "$BINARY_PATH" ]; then
            PRODUCTION_STATUS="installed"
            PRODUCTION_DETAILS="Found: $BINARY_PATH"
        fi
    fi

    # Method 2: Check common install locations for project name
    if [ "$PRODUCTION_STATUS" = "unknown" ]; then
        for path in "$HOME/.local/bin/$PROJECT_NAME" \
                    "/usr/local/bin/$PROJECT_NAME" \
                    "/usr/bin/$PROJECT_NAME"; do
            if [ -x "$path" ]; then
                PRODUCTION_STATUS="installed"
                PRODUCTION_DETAILS="Found: $path"
                break
            fi
        done
    fi

    # Method 3: Check for running systemd service
    if [ "$PRODUCTION_STATUS" = "unknown" ]; then
        if systemctl --user is-active "$PROJECT_NAME.service" &>/dev/null || \
           systemctl is-active "$PROJECT_NAME.service" &>/dev/null; then
            PRODUCTION_STATUS="installed"
            PRODUCTION_DETAILS="Service running: $PROJECT_NAME.service"
        fi
    fi

    # Method 4: Check if service file exists (even if not running)
    if [ "$PRODUCTION_STATUS" = "unknown" ]; then
        if [ -f "$HOME/.config/systemd/user/$PROJECT_NAME.service" ] || \
           [ -f "/etc/systemd/system/$PROJECT_NAME.service" ]; then
            PRODUCTION_STATUS="installed-not-running"
            PRODUCTION_DETAILS="Service installed but not active"
        fi
    fi

    # Default if nothing found
    if [ "$PRODUCTION_STATUS" = "unknown" ]; then
        PRODUCTION_STATUS="not-installed"
        PRODUCTION_DETAILS="No production installation detected"
    fi

    echo "Production Status: $PRODUCTION_STATUS"
    echo "Production Details: $PRODUCTION_DETAILS"
}

check_production_status
```

### 7. Detect Docker Image and Registry Package

Determine if this project has a Docker image and corresponding registry package:

```bash
check_docker_status() {
    local PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
    local PROJECT_NAME=$(basename "$PROJECT_DIR")
    local DOCKER_STATUS="none"
    local REGISTRY_STATUS="not-found"
    local REGISTRY_IMAGE=""
    local REGISTRY_VERSION=""
    local PROJECT_VERSION=""

    # Check for Dockerfile
    if [ -f "$PROJECT_DIR/Dockerfile" ]; then
        DOCKER_STATUS="exists"

        # Try to determine registry image name
        # Method 1: Check .docker-image file
        if [ -f "$PROJECT_DIR/.docker-image" ]; then
            REGISTRY_IMAGE=$(cat "$PROJECT_DIR/.docker-image" | tr -d '[:space:]')
        # Method 2: Parse from docker-compose.yml
        elif [ -f "$PROJECT_DIR/docker-compose.yml" ]; then
            REGISTRY_IMAGE=$(grep -E '^\s+image:' "$PROJECT_DIR/docker-compose.yml" | head -1 | sed 's/.*image:\s*//' | tr -d '"'"'" | tr -d '[:space:]')
        # Method 3: Derive from git remote (GHCR convention)
        else
            GIT_REMOTE=$(git -C "$PROJECT_DIR" remote get-url origin 2>/dev/null)
            if [[ "$GIT_REMOTE" =~ github\.com[:/]([^/]+)/([^/.]+) ]]; then
                OWNER="${BASH_REMATCH[1]}"
                REPO="${BASH_REMATCH[2]}"
                REGISTRY_IMAGE="ghcr.io/${OWNER,,}/${REPO,,}"  # lowercase
            fi
        fi

        # Get project version
        if [ -f "$PROJECT_DIR/VERSION" ]; then
            PROJECT_VERSION=$(cat "$PROJECT_DIR/VERSION" | tr -d '[:space:]')
        fi

        # Check if registry image exists
        if [ -n "$REGISTRY_IMAGE" ]; then
            # Try to get manifest from registry (GHCR, Docker Hub)
            if command -v docker &>/dev/null; then
                # Check for specific version tag
                if [ -n "$PROJECT_VERSION" ]; then
                    if docker manifest inspect "${REGISTRY_IMAGE}:${PROJECT_VERSION}" &>/dev/null; then
                        REGISTRY_STATUS="found"
                        REGISTRY_VERSION="$PROJECT_VERSION"
                    elif docker manifest inspect "${REGISTRY_IMAGE}:latest" &>/dev/null; then
                        REGISTRY_STATUS="version-mismatch"
                        REGISTRY_VERSION="latest (expected: $PROJECT_VERSION)"
                    fi
                else
                    # No version file, just check if any image exists
                    if docker manifest inspect "${REGISTRY_IMAGE}:latest" &>/dev/null; then
                        REGISTRY_STATUS="found"
                        REGISTRY_VERSION="latest"
                    fi
                fi
            fi
        fi
    fi

    echo "Docker Status: $DOCKER_STATUS"
    echo "Registry Image: ${REGISTRY_IMAGE:-N/A}"
    echo "Registry Status: $REGISTRY_STATUS"
    echo "Registry Version: ${REGISTRY_VERSION:-N/A}"
    echo "Project Version: ${PROJECT_VERSION:-N/A}"
}

check_docker_status
```

## Output

Report in this format:
```
═══════════════════════════════════════════════════════════════════
  DISCOVERY RESULTS
═══════════════════════════════════════════════════════════════════

Project Type: [type]
Test Framework: [framework]
Test Files Found: [count]
Test Command: [command]
Config Files: [list]

─────────────────────────────────────────────────────────────────
  ISOLATION LEVEL
─────────────────────────────────────────────────────────────────

Danger Score: [score]
Isolation Level: [sandbox|sandbox-warn|vm-recommended|vm-required]
Danger Indicators: [list or "none"]

Phase M/V Recommendation:
  - sandbox: Use Phase M (standard mocking/containerization)
  - sandbox-warn: Use Phase M with extra monitoring
  - vm-recommended: Prefer Phase V if VM available
  - vm-required: MUST use Phase V - abort if no VM

─────────────────────────────────────────────────────────────────
  MCP SERVERS
─────────────────────────────────────────────────────────────────

MCP Servers Available: [count]

Testing/Automation:
  playwright: [Enabled|Disabled]

Code Intelligence (LSP):
  pyright-lsp: [Enabled|Disabled]
  typescript-lsp: [Enabled|Disabled]
  rust-analyzer-lsp: [Enabled|Disabled]
  gopls-lsp: [Enabled|Disabled]
  clangd-lsp: [Enabled|Disabled]

Codebase Analysis:
  context7: [Enabled|Disabled]
  greptile: [Enabled|Disabled]

MCP Recommendations:
  - Phase 7 (Quality): Use LSP servers for [language] type checking
  - Phase A/2a (Testing): Use playwright for E2E tests (if web UI detected)

─────────────────────────────────────────────────────────────────
  GITHUB REPOSITORY
─────────────────────────────────────────────────────────────────

GitHub Status: [not-a-repo|no-remote|not-github|secure|alerts-open|incomplete]
GitHub Repo: [owner/repo or N/A]
GitHub Authenticated: [true|false]

Security Features:
  Dependabot Alerts: [Enabled|Not enabled]
  Security Workflows: [Found|Not found]

Open Alerts:
  Dependabot: [count]
  Code Scanning: [count]
  Secret Scanning: [count]

Sync Status: [In sync|X local commits not pushed|X remote commits not pulled]

Phase G Recommendation: [SKIP|RUN]
  - SKIP: No GitHub repo or not authenticated
  - RUN: GitHub repo detected with authenticated access

─────────────────────────────────────────────────────────────────
  PYTEST CUSTOM OPTIONS
─────────────────────────────────────────────────────────────────

Pytest Extra Flags: [--flag1 --flag2 | (none)]

─────────────────────────────────────────────────────────────────
  PRODUCTION APP DETECTION
─────────────────────────────────────────────────────────────────

Installable App: [none|manifest|script|python-package|npm-package|go-binary|rust-binary|systemd-service|makefile]
Install Method: [method or N/A]
Production Status: [not-installed|installed|installed-not-running]
Production Details: [details]

Phase P Recommendation: [SKIP|RUN|PROMPT]
  - SKIP: No installable app detected
  - RUN: Production app is installed on this system
  - PROMPT: Installable app exists but not detected on system

─────────────────────────────────────────────────────────────────
  DOCKER DETECTION
─────────────────────────────────────────────────────────────────

Docker Status: [none|exists]
Registry Image: [image name or N/A]
Registry Status: [not-found|found|version-mismatch]
Registry Version: [version or N/A]
Project Version: [version or N/A]

Phase D Recommendation: [SKIP|RUN|PROMPT]
  - SKIP: No Dockerfile detected
  - RUN: Dockerfile exists and registry package found
  - PROMPT: Dockerfile exists but no registry package found
```

## Isolation Level Detection

Determine whether sandbox (Phase M) or full VM (Phase V) isolation is required for safe testing.

### Danger Pattern Detection

```bash
detect_isolation_level() {
    local PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
    local ISOLATION_LEVEL="sandbox"  # Default: safe for sandbox
    local DANGER_SCORE=0
    local DANGER_INDICATORS=()

    echo ""
    echo "───────────────────────────────────────────────────────────────────"
    echo "  Isolation Level Detection"
    echo "───────────────────────────────────────────────────────────────────"

    # === CRITICAL: System Authentication & Security ===

    # PAM modifications (can lock you out of your system)
    if grep -rqE "pam\.d|pam_|libpam|security/pam" "$PROJECT_DIR" --include="*.sh" --include="*.py" --include="*.conf" --include="Makefile" 2>/dev/null; then
        DANGER_INDICATORS+=("PAM configuration changes detected")
        ((DANGER_SCORE += 100))
    fi

    # PAM config files in project
    if find "$PROJECT_DIR" -name "*.pam" -o -name "*pam*.conf" 2>/dev/null | grep -q .; then
        DANGER_INDICATORS+=("PAM config files in project")
        ((DANGER_SCORE += 100))
    fi

    # sudo/polkit rules
    if grep -rqE "sudoers|polkit|pkla|\.rules" "$PROJECT_DIR" --include="*.sh" --include="*.py" --include="*.rules" 2>/dev/null; then
        DANGER_INDICATORS+=("sudo/polkit rules modifications")
        ((DANGER_SCORE += 80))
    fi

    # === CRITICAL: Boot & Kernel ===

    # Bootloader modifications (systemd-boot, grub)
    if grep -rqE "bootctl|efibootmgr|grub-|loader/entries|cmdline|kernel-install" "$PROJECT_DIR" --include="*.sh" --include="*.py" 2>/dev/null; then
        DANGER_INDICATORS+=("Bootloader/kernel parameter changes")
        ((DANGER_SCORE += 100))
    fi

    # Kernel modules
    if grep -rqE "modprobe|insmod|rmmod|\.ko\b|depmod|/lib/modules" "$PROJECT_DIR" --include="*.sh" --include="*.py" 2>/dev/null; then
        DANGER_INDICATORS+=("Kernel module operations")
        ((DANGER_SCORE += 90))
    fi

    # sysctl modifications
    if grep -rqE "sysctl\s+-w|sysctl\.d|/proc/sys" "$PROJECT_DIR" --include="*.sh" --include="*.py" --include="*.conf" 2>/dev/null; then
        DANGER_INDICATORS+=("sysctl kernel parameter changes")
        ((DANGER_SCORE += 70))
    fi

    # === HIGH: System Services ===

    # Systemd system-level services (not user-level)
    if grep -rqE "/etc/systemd/system|systemctl\s+(enable|disable|mask)\s+[^-]|systemctl\s+daemon-reload" "$PROJECT_DIR" --include="*.sh" --include="*.py" 2>/dev/null; then
        DANGER_INDICATORS+=("System-level systemd service modifications")
        ((DANGER_SCORE += 80))
    fi

    # System service files in project (*.service not in user paths)
    if find "$PROJECT_DIR" -name "*.service" -exec grep -L "WantedBy=default.target" {} \; 2>/dev/null | grep -q .; then
        DANGER_INDICATORS+=("System-level service files detected")
        ((DANGER_SCORE += 60))
    fi

    # init.d scripts
    if find "$PROJECT_DIR" -path "*/init.d/*" -o -name "*.init" 2>/dev/null | grep -q .; then
        DANGER_INDICATORS+=("init.d scripts detected")
        ((DANGER_SCORE += 60))
    fi

    # === HIGH: Display & Graphics ===

    # Display manager config (SDDM, GDM, LightDM)
    if grep -rqE "sddm|gdm|lightdm|/etc/X11|xorg\.conf|Xsetup|Xsession" "$PROJECT_DIR" --include="*.sh" --include="*.conf" --include="*.py" 2>/dev/null; then
        DANGER_INDICATORS+=("Display manager configuration changes")
        ((DANGER_SCORE += 80))
    fi

    # Wayland/X11 compositor config
    if grep -rqE "kwinrc|mutter|weston|sway/config|hyprland" "$PROJECT_DIR" --include="*.sh" --include="*.conf" 2>/dev/null; then
        DANGER_INDICATORS+=("Window compositor configuration")
        ((DANGER_SCORE += 50))
    fi

    # === HIGH: D-Bus System Bus ===

    # D-Bus system configuration (not session)
    if grep -rqE "/etc/dbus-1|dbus-1/system\.d|org\.freedesktop\.(systemd|login|UDisks|NetworkManager)" "$PROJECT_DIR" --include="*.sh" --include="*.conf" --include="*.py" 2>/dev/null; then
        DANGER_INDICATORS+=("D-Bus system bus modifications")
        ((DANGER_SCORE += 70))
    fi

    # === MEDIUM: Hardware & Devices ===

    # udev rules
    if find "$PROJECT_DIR" -name "*.rules" 2>/dev/null | xargs grep -l "SUBSYSTEM\|KERNEL\|ATTR" 2>/dev/null | grep -q .; then
        DANGER_INDICATORS+=("udev rules detected")
        ((DANGER_SCORE += 60))
    fi

    # Device management
    if grep -rqE "udisksctl|lsblk.*-o|blkid|mount\s+-o|umount|mkfs\.|parted|fdisk|gdisk" "$PROJECT_DIR" --include="*.sh" --include="*.py" 2>/dev/null; then
        DANGER_INDICATORS+=("Disk/device management operations")
        ((DANGER_SCORE += 70))
    fi

    # === MEDIUM: Network ===

    # Network configuration (system-level)
    if grep -rqE "/etc/systemd/network|/etc/NetworkManager|nmcli\s+con|ifconfig|ip\s+(addr|link|route)" "$PROJECT_DIR" --include="*.sh" --include="*.py" --include="*.conf" 2>/dev/null; then
        DANGER_INDICATORS+=("Network configuration changes")
        ((DANGER_SCORE += 50))
    fi

    # Firewall rules
    if grep -rqE "iptables|nftables|firewall-cmd|ufw" "$PROJECT_DIR" --include="*.sh" --include="*.py" 2>/dev/null; then
        DANGER_INDICATORS+=("Firewall rule modifications")
        ((DANGER_SCORE += 50))
    fi

    # === MEDIUM: Package Management ===

    # System package manager operations
    if grep -rqE "pacman\s+-S|apt\s+install|dnf\s+install|yum\s+install|zypper\s+in" "$PROJECT_DIR" --include="*.sh" --include="*.py" 2>/dev/null; then
        DANGER_INDICATORS+=("System package installation")
        ((DANGER_SCORE += 40))
    fi

    # === LOW: Filesystem ===

    # BTRFS subvolume operations
    if grep -rqE "btrfs\s+subvolume|btrfs\s+property" "$PROJECT_DIR" --include="*.sh" --include="*.py" 2>/dev/null; then
        DANGER_INDICATORS+=("BTRFS subvolume operations")
        ((DANGER_SCORE += 30))
    fi

    # fstab modifications
    if grep -rqE "/etc/fstab|systemctl\s+daemon-reload.*mount" "$PROJECT_DIR" --include="*.sh" --include="*.py" 2>/dev/null; then
        DANGER_INDICATORS+=("fstab mount modifications")
        ((DANGER_SCORE += 60))
    fi

    # === Determine Isolation Level ===

    # Thresholds:
    # 0-29:   sandbox (safe - app logic only)
    # 30-59:  sandbox-warn (sandbox OK but be careful)
    # 60-99:  vm-recommended (VM strongly recommended)
    # 100+:   vm-required (MUST use VM)

    if [ "$DANGER_SCORE" -ge 100 ]; then
        ISOLATION_LEVEL="vm-required"
    elif [ "$DANGER_SCORE" -ge 60 ]; then
        ISOLATION_LEVEL="vm-recommended"
    elif [ "$DANGER_SCORE" -ge 30 ]; then
        ISOLATION_LEVEL="sandbox-warn"
    else
        ISOLATION_LEVEL="sandbox"
    fi

    # Output results
    echo ""
    echo "  Danger Score: $DANGER_SCORE"
    echo "  Isolation Level: $ISOLATION_LEVEL"
    echo ""

    if [ ${#DANGER_INDICATORS[@]} -gt 0 ]; then
        echo "  Danger Indicators Found:"
        for indicator in "${DANGER_INDICATORS[@]}"; do
            echo "    ⚠️  $indicator"
        done
    else
        echo "  ✅ No dangerous patterns detected"
    fi

    echo ""

    # Export for other phases
    export ISOLATION_LEVEL DANGER_SCORE

    # Machine-readable output
    echo "Isolation Level: $ISOLATION_LEVEL"
    echo "Danger Score: $DANGER_SCORE"
    echo "Danger Indicators: ${DANGER_INDICATORS[*]:-none}"
}

detect_isolation_level
```

### Isolation Level Meanings

| Level | Score | Meaning | Testing Approach |
|-------|-------|---------|------------------|
| `sandbox` | 0-29 | Safe for containerized testing | Use Phase M (mocking/sandbox) |
| `sandbox-warn` | 30-59 | Sandbox OK but monitor closely | Use Phase M with extra logging |
| `vm-recommended` | 60-99 | VM isolation strongly recommended | Prefer Phase V if available |
| `vm-required` | 100+ | **MUST use VM isolation** | Phase V mandatory; abort if no VM |

### Dispatcher Integration

When the dispatcher sees `ISOLATION_LEVEL`:

```
IF ISOLATION_LEVEL == "vm-required":
    IF no VM available (Phase V prerequisites not met):
        ABORT with "CRITICAL: This project requires VM isolation but no VM is available"
        EXIT 1
    ELSE:
        LOG "VM isolation required - Phase V will be used"
        SET USE_VM=true

ELIF ISOLATION_LEVEL == "vm-recommended":
    IF VM available:
        LOG "VM isolation recommended and available - using Phase V"
        SET USE_VM=true
    ELSE:
        WARN "VM isolation recommended but not available"
        WARN "Proceeding with sandbox (Phase M) - exercise caution"
        SET USE_VM=false

ELIF ISOLATION_LEVEL == "sandbox-warn":
    LOG "Sandbox isolation with monitoring"
    SET USE_VM=false
    SET EXTRA_MONITORING=true

ELSE:  # sandbox
    LOG "Standard sandbox isolation sufficient"
    SET USE_VM=false
```

---

## Phase P Gate Decision

Based on discovery results, the dispatcher should:

| Installable App | Production Status | Action |
|-----------------|-------------------|--------|
| `none` | N/A | **SKIP** Phase P |
| Any | `installed` | **RUN** Phase P |
| Any | `installed-not-running` | **RUN** Phase P (check why not running) |
| Any | `not-installed` | **PROMPT** user: "App exists but not installed. Skip Phase P?" |

## Phase D Gate Decision

Based on discovery results, the dispatcher should:

| Docker Status | Registry Status | Action |
|---------------|-----------------|--------|
| `none` | N/A | **SKIP** Phase D |
| `exists` | `found` | **RUN** Phase D |
| `exists` | `version-mismatch` | **RUN** Phase D (flag version sync issue) |
| `exists` | `not-found` | **PROMPT** user: "Dockerfile exists but no registry package. Skip Phase D?" |
