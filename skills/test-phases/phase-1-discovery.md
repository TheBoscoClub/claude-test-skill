# Phase 1: Discovery

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

### 4b. Detect GitHub Repository

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
