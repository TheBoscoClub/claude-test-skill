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
