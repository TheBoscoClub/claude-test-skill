# Phase D: Docker Validation

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

### 5. Docker Compose Validation (if exists)

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
