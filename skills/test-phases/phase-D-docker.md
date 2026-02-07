# Phase D: Docker Validation

> **Model**: `opus` | **Tier**: 5 (Post-fix, Conditional) | **Modifies Files**: No (validates registry)
> **Task Tracking**: Call `TaskUpdate(taskId, status="in_progress")` at start, `TaskUpdate(taskId, status="completed")` when done.
> **Key Tools**: `Bash` for docker/buildx commands. Use `KillShell` to terminate hung Docker builds. Use `WebSearch` to check for base image vulnerabilities or updated tags.

Validate Docker image builds and registry package synchronization.

## Prerequisites

This phase requires:
- Docker daemon running
- Registry authentication (for push validation)
- Discovery phase results (Docker Status, Registry Image, Registry Status)

## Execution Steps

### 1. Validate Dockerfile Syntax

```bash
validate_dockerfile() {
    local PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"

    if [ ! -f "$PROJECT_DIR/Dockerfile" ]; then
        echo "❌ No Dockerfile found"
        return 1
    fi

    # Check for common Dockerfile issues
    ISSUES=0

    # Check for FROM instruction
    if ! grep -q '^FROM ' "$PROJECT_DIR/Dockerfile"; then
        echo "❌ Missing FROM instruction"
        ((ISSUES++))
    fi

    # Check for unpinned base images (security risk)
    if grep -E '^FROM [^:]+$' "$PROJECT_DIR/Dockerfile" | grep -v 'scratch'; then
        echo "⚠️ Unpinned base image detected (no tag specified)"
    fi

    # Check for latest tag (not recommended for reproducibility)
    if grep -E '^FROM .+:latest' "$PROJECT_DIR/Dockerfile"; then
        echo "⚠️ Using :latest tag (not recommended for production)"
    fi

    # Check for COPY/ADD before dependency install (cache invalidation)
    # This is a common anti-pattern

    echo "Dockerfile syntax: $([ $ISSUES -eq 0 ] && echo '✅ OK' || echo '❌ Issues found')"
    return $ISSUES
}

validate_dockerfile
```

### 2. Test Docker Build (using buildx)

```bash
test_docker_build() {
    local PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
    local PROJECT_NAME=$(basename "$PROJECT_DIR")
    local TEST_TAG="test-build-$$"

    echo "Building Docker image with buildx..."

    # Verify buildx is available
    if ! docker buildx version &>/dev/null; then
        echo "❌ Docker buildx not available"
        echo "   Install with: docker buildx install"
        return 1
    fi

    # Check for multiplatform builder
    BUILDER=$(docker buildx ls 2>/dev/null | grep -E '^\S+\s+\*' | awk '{print $1}')
    if [ "$BUILDER" = "default" ]; then
        echo "⚠️ Using default builder (single-platform only)"
        echo "   For multi-platform, create builder: docker buildx create --use --name multiplatform"
    fi

    # Build without pushing (--load to load into local docker)
    # Note: --load only works for single platform, use --output for multi
    if docker buildx build \
        --tag "${PROJECT_NAME}:${TEST_TAG}" \
        --load \
        "$PROJECT_DIR" 2>&1; then
        echo "✅ Docker buildx build successful"

        # Get image size
        SIZE=$(docker image inspect "${PROJECT_NAME}:${TEST_TAG}" --format='{{.Size}}' 2>/dev/null)
        SIZE_MB=$((SIZE / 1024 / 1024))
        echo "Image size: ${SIZE_MB}MB"

        # Cleanup test image
        docker rmi "${PROJECT_NAME}:${TEST_TAG}" &>/dev/null

        return 0
    else
        echo "❌ Docker buildx build failed"
        return 1
    fi
}

test_docker_build
```

### 3. Validate Registry Package

```bash
validate_registry_package() {
    local REGISTRY_IMAGE="$1"
    local PROJECT_VERSION="$2"

    if [ -z "$REGISTRY_IMAGE" ]; then
        echo "⚠️ No registry image configured"
        return 1
    fi

    echo "Checking registry: $REGISTRY_IMAGE"

    # Check version tag exists
    if [ -n "$PROJECT_VERSION" ]; then
        if docker manifest inspect "${REGISTRY_IMAGE}:${PROJECT_VERSION}" &>/dev/null; then
            echo "✅ Version tag exists: ${PROJECT_VERSION}"

            # Check platforms available
            PLATFORMS=$(docker manifest inspect "${REGISTRY_IMAGE}:${PROJECT_VERSION}" 2>/dev/null | \
                        grep -o '"architecture"[[:space:]]*:[[:space:]]*"[^"]*"' | \
                        sed 's/.*"\([^"]*\)"/\1/' | sort -u | tr '\n' ',' | sed 's/,$//')
            echo "Platforms: ${PLATFORMS:-unknown}"
        else
            echo "❌ Version tag missing: ${PROJECT_VERSION}"

            # Check if latest exists
            if docker manifest inspect "${REGISTRY_IMAGE}:latest" &>/dev/null; then
                echo "⚠️ :latest exists but version tag is missing"
                echo "   Expected: ${REGISTRY_IMAGE}:${PROJECT_VERSION}"
                return 1
            else
                echo "❌ No registry package found at all"
                return 1
            fi
        fi
    fi

    # Check latest tag
    if docker manifest inspect "${REGISTRY_IMAGE}:latest" &>/dev/null; then
        echo "✅ Latest tag exists"
    else
        echo "⚠️ No :latest tag (optional but recommended)"
    fi

    return 0
}

# Get values from Discovery phase or re-detect
REGISTRY_IMAGE="${REGISTRY_IMAGE:-}"
PROJECT_VERSION="${PROJECT_VERSION:-}"

if [ -z "$REGISTRY_IMAGE" ]; then
    # Try to detect
    GIT_REMOTE=$(git remote get-url origin 2>/dev/null)
    if [[ "$GIT_REMOTE" =~ github\.com[:/]([^/]+)/([^/.]+) ]]; then
        OWNER="${BASH_REMATCH[1]}"
        REPO="${BASH_REMATCH[2]}"
        REGISTRY_IMAGE="ghcr.io/${OWNER,,}/${REPO,,}"
    fi
fi

if [ -z "$PROJECT_VERSION" ] && [ -f "VERSION" ]; then
    PROJECT_VERSION=$(cat VERSION | tr -d '[:space:]')
fi

validate_registry_package "$REGISTRY_IMAGE" "$PROJECT_VERSION"
```

### 4. Version Synchronization Check

```bash
check_version_sync() {
    local PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
    local ISSUES=0

    echo "Checking version synchronization..."

    # Get project version
    if [ -f "$PROJECT_DIR/VERSION" ]; then
        PROJECT_VERSION=$(cat "$PROJECT_DIR/VERSION" | tr -d '[:space:]')
    elif [ -f "$PROJECT_DIR/package.json" ]; then
        PROJECT_VERSION=$(grep '"version"' "$PROJECT_DIR/package.json" | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
    fi

    # Get latest git tag
    GIT_TAG=$(git -C "$PROJECT_DIR" describe --tags --abbrev=0 2>/dev/null | sed 's/^v//')

    # Check Dockerfile has version label
    DOCKER_VERSION=$(grep -E 'LABEL.*version=' "$PROJECT_DIR/Dockerfile" 2>/dev/null | \
                     sed 's/.*version=["'"'"']\?\([^"'"'"' ]*\).*/\1/')

    echo "Project VERSION file: ${PROJECT_VERSION:-N/A}"
    echo "Latest git tag: ${GIT_TAG:-N/A}"
    echo "Dockerfile LABEL version: ${DOCKER_VERSION:-N/A}"

    # Check consistency
    if [ -n "$PROJECT_VERSION" ] && [ -n "$GIT_TAG" ]; then
        if [ "$PROJECT_VERSION" != "$GIT_TAG" ]; then
            echo "⚠️ VERSION file ($PROJECT_VERSION) != git tag ($GIT_TAG)"
            ((ISSUES++))
        fi
    fi

    if [ -n "$PROJECT_VERSION" ] && [ -n "$DOCKER_VERSION" ]; then
        if [ "$PROJECT_VERSION" != "$DOCKER_VERSION" ]; then
            echo "⚠️ VERSION file ($PROJECT_VERSION) != Dockerfile LABEL ($DOCKER_VERSION)"
            ((ISSUES++))
        fi
    fi

    return $ISSUES
}

check_version_sync
```

### 5. Verify Image Contains Current Application Version and Code

**CRITICAL**: After a successful build, verify the Docker image has the correct
version and current code installed. This catches stale COPY instructions, missing
files, and version mismatches.

```bash
verify_image_contents() {
    local PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
    local PROJECT_NAME=$(basename "$PROJECT_DIR" | tr '[:upper:]' '[:lower:]')
    local TEST_TAG="test-verify-$$"
    local ISSUES=0

    echo "Verifying image contains current application code..."

    # Build a fresh image for verification
    if ! docker buildx build --tag "${PROJECT_NAME}:${TEST_TAG}" --load "$PROJECT_DIR" &>/dev/null; then
        echo "❌ Cannot build image for verification"
        return 1
    fi

    # Get expected version from project
    local EXPECTED_VERSION=""
    if [ -f "$PROJECT_DIR/VERSION" ]; then
        EXPECTED_VERSION=$(cat "$PROJECT_DIR/VERSION" | tr -d '[:space:]')
    fi

    # Check VERSION file inside container
    CONTAINER_VERSION=$(docker run --rm "${PROJECT_NAME}:${TEST_TAG}" \
        cat /app/VERSION 2>/dev/null | tr -d '[:space:]')
    if [ -n "$EXPECTED_VERSION" ]; then
        if [ "$CONTAINER_VERSION" = "$EXPECTED_VERSION" ]; then
            echo "✅ VERSION file in image: $CONTAINER_VERSION (matches project)"
        else
            echo "❌ VERSION mismatch: image has '$CONTAINER_VERSION', project has '$EXPECTED_VERSION'"
            ((ISSUES++))
        fi
    fi

    # Check that key application files exist in the image
    # Detect key files from project structure
    MISSING_FILES=0
    for check_file in "VERSION" "library/backend/app.py" "library/config.py" "library/requirements.txt"; do
        if [ -f "$PROJECT_DIR/$check_file" ]; then
            if docker run --rm "${PROJECT_NAME}:${TEST_TAG}" test -f "/app/$check_file" 2>/dev/null; then
                echo "  ✅ /app/$check_file exists"
            else
                echo "  ❌ /app/$check_file MISSING from image"
                ((MISSING_FILES++))
            fi
        fi
    done
    if [ $MISSING_FILES -gt 0 ]; then
        echo "❌ $MISSING_FILES expected file(s) missing from image"
        ((ISSUES++))
    fi

    # Check Python dependencies are installed
    DEPS_OK=$(docker run --rm "${PROJECT_NAME}:${TEST_TAG}" \
        python3 -c "import flask; print('ok')" 2>/dev/null)
    if [ "$DEPS_OK" = "ok" ]; then
        echo "✅ Python dependencies installed (flask importable)"
    else
        echo "❌ Python dependencies NOT properly installed"
        ((ISSUES++))
    fi

    # Check that the API can at least start (basic smoke test)
    # Run container briefly and check if it responds
    CONTAINER_ID=$(docker run -d --name "test-smoke-$$" \
        -e "DATABASE_PATH=/tmp/test.db" \
        "${PROJECT_NAME}:${TEST_TAG}" sleep 30 2>/dev/null)
    if [ -n "$CONTAINER_ID" ]; then
        # Try importing the app module
        IMPORT_OK=$(docker exec "$CONTAINER_ID" \
            python3 -c "import sys; sys.path.insert(0, '/app'); from library.backend.app import app; print('ok')" 2>/dev/null)
        if [ "$IMPORT_OK" = "ok" ]; then
            echo "✅ Application module imports successfully"
        else
            echo "⚠️ Application module import failed (may need runtime deps)"
        fi
        docker rm -f "$CONTAINER_ID" &>/dev/null
    fi

    # Cleanup
    docker rmi "${PROJECT_NAME}:${TEST_TAG}" &>/dev/null

    echo ""
    echo "Image Content Verification: $([ $ISSUES -eq 0 ] && echo '✅ PASS' || echo '❌ ISSUES')"
    echo "Issues: $ISSUES"
    return $ISSUES
}

verify_image_contents
```

### 6. Docker Compose Validation (if exists)

```bash
validate_compose() {
    local PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"

    if [ ! -f "$PROJECT_DIR/docker-compose.yml" ] && [ ! -f "$PROJECT_DIR/compose.yml" ]; then
        echo "No docker-compose.yml found (optional)"
        return 0
    fi

    COMPOSE_FILE="$PROJECT_DIR/docker-compose.yml"
    [ -f "$PROJECT_DIR/compose.yml" ] && COMPOSE_FILE="$PROJECT_DIR/compose.yml"

    echo "Validating: $(basename $COMPOSE_FILE)"

    # Validate syntax
    if docker compose -f "$COMPOSE_FILE" config &>/dev/null; then
        echo "✅ Compose file syntax valid"
    else
        echo "❌ Compose file syntax error"
        docker compose -f "$COMPOSE_FILE" config 2>&1 | head -5
        return 1
    fi

    # Check for hardcoded secrets
    if grep -E '(password|secret|key|token)\s*[:=]\s*[^$]' "$COMPOSE_FILE" 2>/dev/null | grep -v '\${'; then
        echo "⚠️ Potential hardcoded secrets in compose file"
    fi

    return 0
}

validate_compose
```

## Output

Report in this format:
```
═══════════════════════════════════════════════════════════════════
  PHASE D: DOCKER VALIDATION
═══════════════════════════════════════════════════════════════════

Dockerfile:
  Syntax: ✅ Valid
  Base Image: python:3.11-slim (pinned)

Buildx Test:
  Status: ✅ Successful
  Builder: multiplatform (docker-container)
  Image Size: 245MB

Registry Package:
  Image: ghcr.io/owner/repo
  Version Tag: ✅ 3.2.0 exists
  Latest Tag: ✅ exists
  Platforms: amd64, arm64

Version Sync:
  VERSION file: 3.2.0
  Git tag: v3.2.0
  Registry: 3.2.0
  Status: ✅ All synchronized

Docker Compose:
  Status: ✅ Valid (optional)

───────────────────────────────────────────────────────────────────

Status: ✅ PASS / ⚠️ ISSUES / ❌ FAIL
Issues: [count]
```

## Issue Categories

| Category | Severity | Description |
|----------|----------|-------------|
| Buildx unavailable | ❌ FAIL | Docker buildx not installed |
| Build failure | ❌ FAIL | Docker image won't build |
| Missing registry tag | ⚠️ ISSUE | Version tag missing from registry |
| Version mismatch | ⚠️ ISSUE | VERSION file != registry tag |
| Default builder | ⚠️ WARN | Using default builder (no multi-platform) |
| Unpinned base | ⚠️ WARN | Base image not pinned (reproducibility) |
| Missing platforms | ⚠️ WARN | Registry image not multi-platform (amd64 only) |
| Hardcoded secrets | ⚠️ ISSUE | Secrets in Dockerfile/compose |

## Cleanup (MANDATORY)

After all Docker tests complete, **always** clean up resources to prevent orphaned containers:

```bash
cleanup_docker_phase() {
    local PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
    local PROJECT_NAME=$(basename "$PROJECT_DIR" | tr '[:upper:]' '[:lower:]')

    echo "Cleaning up Docker test resources..."

    # ─────────────────────────────────────────────────────────────
    # 1. STOP TEST CONTAINERS (graceful shutdown with timeout)
    # ─────────────────────────────────────────────────────────────

    # Stop containers started from test images (test-build-* pattern)
    for container in $(docker ps -q --filter "ancestor=${PROJECT_NAME}:test-*" 2>/dev/null); do
        echo "Stopping test container: $container"
        docker stop --time 10 "$container" 2>/dev/null || docker kill "$container" 2>/dev/null || true
    done

    # Stop any containers with test- prefix in name
    for container in $(docker ps -q --filter "name=test-" 2>/dev/null); do
        echo "Stopping test container: $container"
        docker stop --time 10 "$container" 2>/dev/null || docker kill "$container" 2>/dev/null || true
    done

    # Stop containers started via docker-compose during testing
    COMPOSE_FILE=""
    [ -f "$PROJECT_DIR/docker-compose.yml" ] && COMPOSE_FILE="$PROJECT_DIR/docker-compose.yml"
    [ -f "$PROJECT_DIR/compose.yml" ] && COMPOSE_FILE="$PROJECT_DIR/compose.yml"

    if [ -n "$COMPOSE_FILE" ]; then
        # Check if any compose services are running
        RUNNING=$(docker compose -f "$COMPOSE_FILE" ps -q 2>/dev/null)
        if [ -n "$RUNNING" ]; then
            echo "Stopping docker-compose services..."
            docker compose -f "$COMPOSE_FILE" down --timeout 10 2>/dev/null || true
        fi
    fi

    # ─────────────────────────────────────────────────────────────
    # 2. STOP BUILDX BUILDER CONTAINERS
    # ─────────────────────────────────────────────────────────────

    for container in $(docker ps -q --filter "name=buildx_buildkit" 2>/dev/null); do
        echo "Stopping buildx container: $container"
        docker stop --time 10 "$container" 2>/dev/null || true
    done

    # ─────────────────────────────────────────────────────────────
    # 3. REMOVE TEST IMAGES
    # ─────────────────────────────────────────────────────────────

    # Remove dangling test images (images tagged as test-* during builds)
    docker images --filter "reference=*:test-*" -q 2>/dev/null | xargs -r docker rmi 2>/dev/null || true
    docker images --filter "reference=${PROJECT_NAME}:test-*" -q 2>/dev/null | xargs -r docker rmi 2>/dev/null || true

    # ─────────────────────────────────────────────────────────────
    # 4. PRUNE BUILD CACHE (if too large)
    # ─────────────────────────────────────────────────────────────

    CACHE_SIZE=$(docker system df --format '{{.BuildCache}}' 2>/dev/null | grep -oP '\d+\.?\d*' | head -1)
    if [[ "${CACHE_SIZE%.*}" -gt 5 ]] 2>/dev/null; then
        echo "Build cache >5GB, pruning..."
        docker builder prune -f --filter "until=24h" 2>/dev/null || true
    fi

    # ─────────────────────────────────────────────────────────────
    # 5. VERIFY CLEANUP
    # ─────────────────────────────────────────────────────────────

    REMAINING=$(docker ps -q --filter "name=test-" --filter "name=buildx_buildkit" 2>/dev/null | wc -l)
    if [ "$REMAINING" -eq 0 ]; then
        echo "✅ Docker cleanup complete - all test containers stopped"
    else
        echo "⚠️ Docker cleanup: $REMAINING container(s) may still be running"
        docker ps --filter "name=test-" --filter "name=buildx_buildkit" --format "  - {{.Names}} ({{.Status}})" 2>/dev/null
    fi
}

cleanup_docker_phase
```

### Why Cleanup Matters

| Resource | Problem if Left | Cleanup Action |
|----------|-----------------|----------------|
| Test containers | Consume memory/CPU, hold ports | `docker stop --time 10` (graceful) |
| Compose services | Multiple containers left running | `docker compose down --timeout 10` |
| Buildx containers | Consume memory, stay running indefinitely | `docker stop buildx_buildkit*` |
| Test images | Consume disk space | `docker rmi *:test-*` |
| Build cache | Can grow to 10s of GB | `docker builder prune` |

### Graceful Shutdown

The cleanup uses `--time 10` (10 second timeout) to allow containers to:
1. Receive SIGTERM and shutdown gracefully
2. Flush logs and close connections
3. Save state if applicable

If graceful shutdown fails, containers are forcefully killed as a fallback.

**This cleanup runs automatically at the end of Phase D, not in Phase C (Restore).** Docker resources should be cleaned immediately after Docker testing, not left until session cleanup.
