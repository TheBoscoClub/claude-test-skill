# Phase 0: Pre-Flight Environment Validation

> **Model**: `sonnet` | **Tier**: 1 (Pre-flight) | **Modifies Files**: Creates sandbox directory only
> **Task Tracking**: Call `TaskUpdate(taskId, status="in_progress")` at start, `TaskUpdate(taskId, status="completed")` when done.
> **Key Tools**: `Bash` for environment checks. Use `WebSearch` to verify tool version compatibility if needed.

Validate the environment is ready before running any tests. Fail fast on environment issues.
This phase consolidates all pre-flight work: environment checks, config validation, and sandbox setup.

---

## Step 1: Project Detection & Tool Versions

```bash
PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"

echo "======================================================================="
echo "  PHASE 0: PRE-FLIGHT CHECKS"
echo "======================================================================="

echo ""
echo "-----------------------------------------------------------------------"
echo "  Project Detection & Tool Versions"
echo "-----------------------------------------------------------------------"

# Detect project type
PROJECT_TYPE="unknown"
DETECTED_TYPES=()
[[ -f "$PROJECT_DIR/requirements.txt" || -f "$PROJECT_DIR/pyproject.toml" || -f "$PROJECT_DIR/setup.py" ]] && DETECTED_TYPES+=("python")
[[ -f "$PROJECT_DIR/package.json" ]] && DETECTED_TYPES+=("node")
[[ -f "$PROJECT_DIR/go.mod" ]] && DETECTED_TYPES+=("go")
[[ -f "$PROJECT_DIR/Cargo.toml" ]] && DETECTED_TYPES+=("rust")
[[ -f "$PROJECT_DIR/Dockerfile" || -f "$PROJECT_DIR/docker-compose.yml" ]] && DETECTED_TYPES+=("docker")

if [[ ${#DETECTED_TYPES[@]} -gt 0 ]]; then
    PROJECT_TYPE="${DETECTED_TYPES[0]}"
    echo "  Project types detected: ${DETECTED_TYPES[*]}"
else
    echo "  WARN: No recognized project type detected"
fi

# Validate tool versions
TOOLS_OK=true

if [[ " ${DETECTED_TYPES[*]} " =~ " python " ]]; then
    PYTHON_VER=$(python3 --version 2>/dev/null | awk '{print $2}')
    if [[ -n "$PYTHON_VER" ]]; then
        echo "  PASS: Python $PYTHON_VER"
        # Check if pyproject.toml specifies a required version
        if [[ -f "$PROJECT_DIR/pyproject.toml" ]]; then
            REQ_PY=$(grep -E 'requires-python|python_requires' "$PROJECT_DIR/pyproject.toml" 2>/dev/null | head -1)
            [[ -n "$REQ_PY" ]] && echo "    Required: $REQ_PY"
        fi
    else
        echo "  FAIL: Python not found"
        TOOLS_OK=false
    fi
fi

if [[ " ${DETECTED_TYPES[*]} " =~ " node " ]]; then
    NODE_VER=$(node --version 2>/dev/null)
    NPM_VER=$(npm --version 2>/dev/null)
    if [[ -n "$NODE_VER" ]]; then
        echo "  PASS: Node $NODE_VER, npm $NPM_VER"
        # Check engines constraint
        if [[ -f "$PROJECT_DIR/package.json" ]] && command -v jq &>/dev/null; then
            REQ_NODE=$(jq -r '.engines.node // empty' "$PROJECT_DIR/package.json" 2>/dev/null)
            [[ -n "$REQ_NODE" ]] && echo "    Required: node $REQ_NODE"
        fi
    else
        echo "  FAIL: Node.js not found"
        TOOLS_OK=false
    fi
fi

if [[ " ${DETECTED_TYPES[*]} " =~ " go " ]]; then
    GO_VER=$(go version 2>/dev/null | awk '{print $3}')
    if [[ -n "$GO_VER" ]]; then
        echo "  PASS: $GO_VER"
    else
        echo "  FAIL: Go not found"
        TOOLS_OK=false
    fi
fi

if [[ " ${DETECTED_TYPES[*]} " =~ " rust " ]]; then
    RUST_VER=$(rustc --version 2>/dev/null | awk '{print $2}')
    CARGO_VER=$(cargo --version 2>/dev/null | awk '{print $2}')
    if [[ -n "$RUST_VER" ]]; then
        echo "  PASS: Rust $RUST_VER, Cargo $CARGO_VER"
    else
        echo "  FAIL: Rust toolchain not found"
        TOOLS_OK=false
    fi
fi

# Docker daemon check
if [[ " ${DETECTED_TYPES[*]} " =~ " docker " ]] || [[ -f "$PROJECT_DIR/Dockerfile" ]] || [[ -f "$PROJECT_DIR/docker-compose.yml" ]]; then
    if command -v docker &>/dev/null; then
        if docker info &>/dev/null; then
            DOCKER_VER=$(docker --version 2>/dev/null | awk '{print $3}' | tr -d ',')
            echo "  PASS: Docker $DOCKER_VER (daemon running)"
        else
            echo "  FAIL: Docker installed but daemon not running"
            TOOLS_OK=false
        fi
    else
        echo "  FAIL: Docker not installed"
        TOOLS_OK=false
    fi
fi

echo ""
echo "  Tools status: $([ "$TOOLS_OK" = true ] && echo "PASS" || echo "FAIL")"
```

## Step 2: Dependency Verification

```bash
echo ""
echo "-----------------------------------------------------------------------"
echo "  Dependency Verification"
echo "-----------------------------------------------------------------------"

DEPS_OK=true

# Python
if [[ -f "$PROJECT_DIR/requirements.txt" ]]; then
    echo "  Python dependencies:"
    PIP_ISSUES=$(pip check 2>&1)
    if [[ $? -eq 0 ]]; then
        echo "    PASS: All dependencies satisfied"
    else
        echo "    FAIL: Dependency issues found:"
        echo "$PIP_ISSUES" | head -10 | sed 's/^/      /'
        DEPS_OK=false
    fi
fi

# Node.js
if [[ -f "$PROJECT_DIR/package.json" ]]; then
    echo "  Node.js dependencies:"
    NPM_ISSUES=$(npm ls --depth=0 2>&1 | grep -E "WARN|ERR" | head -10)
    if [[ -z "$NPM_ISSUES" ]]; then
        echo "    PASS: All dependencies satisfied"
    else
        echo "    FAIL: Dependency issues:"
        echo "$NPM_ISSUES" | sed 's/^/      /'
        DEPS_OK=false
    fi
fi

# Go
if [[ -f "$PROJECT_DIR/go.mod" ]]; then
    echo "  Go dependencies:"
    GO_VERIFY=$(go mod verify 2>&1)
    if [[ $? -eq 0 ]]; then
        echo "    PASS: All modules verified"
    else
        echo "    FAIL: Module verification failed:"
        echo "$GO_VERIFY" | head -5 | sed 's/^/      /'
        DEPS_OK=false
    fi
fi

# Rust
if [[ -f "$PROJECT_DIR/Cargo.toml" ]]; then
    echo "  Rust dependencies:"
    CARGO_VERIFY=$(cargo verify-project 2>&1)
    if [[ $? -eq 0 ]]; then
        echo "    PASS: Project verified"
    else
        echo "    FAIL: Project verification failed:"
        echo "$CARGO_VERIFY" | head -5 | sed 's/^/      /'
        DEPS_OK=false
    fi
fi

echo ""
echo "  Dependencies status: $([ "$DEPS_OK" = true ] && echo "PASS" || echo "FAIL")"
```

## Step 3: Environment Variables

```bash
echo ""
echo "-----------------------------------------------------------------------"
echo "  Environment Variables"
echo "-----------------------------------------------------------------------"

ENV_OK=true

# Find env var references in source code
ENV_REFS=$(grep -roh 'os\.environ\[.\|process\.env\.\|os\.getenv(' --include="*.py" --include="*.js" "$PROJECT_DIR" 2>/dev/null | wc -l)
echo "  Source code env var references: $ENV_REFS"

# Check .env.example vs .env
if [[ -f "$PROJECT_DIR/.env.example" ]] && [[ -f "$PROJECT_DIR/.env" ]]; then
    MISSING=$(comm -23 \
        <(grep -oE "^[A-Z_]+=" "$PROJECT_DIR/.env.example" | sort) \
        <(grep -oE "^[A-Z_]+=" "$PROJECT_DIR/.env" | sort) 2>/dev/null)
    EXTRA=$(comm -13 \
        <(grep -oE "^[A-Z_]+=" "$PROJECT_DIR/.env.example" | sort) \
        <(grep -oE "^[A-Z_]+=" "$PROJECT_DIR/.env" | sort) 2>/dev/null)

    if [[ -z "$MISSING" ]]; then
        echo "  PASS: .env has all vars from .env.example"
    else
        echo "  FAIL: .env missing vars from .env.example:"
        echo "$MISSING" | sed 's/^/    /'
        ENV_OK=false
    fi
    if [[ -n "$EXTRA" ]]; then
        echo "  WARN: .env has undocumented vars (not in .env.example):"
        echo "$EXTRA" | sed 's/^/    /'
    fi
elif [[ -f "$PROJECT_DIR/.env" ]] && [[ ! -f "$PROJECT_DIR/.env.example" ]]; then
    echo "  WARN: .env exists but no .env.example template"
fi

# Check .env is gitignored
if [[ -f "$PROJECT_DIR/.gitignore" ]]; then
    if grep -q '\.env$\|\.env\b' "$PROJECT_DIR/.gitignore" 2>/dev/null; then
        echo "  PASS: .env is in .gitignore"
    elif [[ -f "$PROJECT_DIR/.env" ]]; then
        echo "  FAIL: .env exists but is NOT in .gitignore (secret leak risk)"
        ENV_OK=false
    fi
fi

echo ""
echo "  Environment status: $([ "$ENV_OK" = true ] && echo "PASS" || echo "FAIL")"
```

## Step 4: Configuration Validation

Validate project configuration files for syntax and best practices. Produces structured findings for Phase 10 (Fix).

```bash
echo ""
echo "-----------------------------------------------------------------------"
echo "  Configuration Validation"
echo "-----------------------------------------------------------------------"

CONFIG_ISSUES=()
CONFIG_OK=true

# --- pyproject.toml ---
if [[ -f "$PROJECT_DIR/pyproject.toml" ]]; then
    echo "  pyproject.toml:"
    # Syntax check
    if python3 -c "import tomllib; tomllib.load(open('$PROJECT_DIR/pyproject.toml','rb'))" 2>/dev/null || \
       python3 -c "import toml; toml.load('$PROJECT_DIR/pyproject.toml')" 2>/dev/null; then
        echo "    PASS: Valid TOML syntax"
    else
        echo "    FAIL: Invalid TOML syntax"
        CONFIG_ISSUES+=("pyproject.toml:syntax:Invalid TOML")
        CONFIG_OK=false
    fi
    # Required sections
    if grep -q '\[project\]' "$PROJECT_DIR/pyproject.toml" 2>/dev/null; then
        echo "    PASS: [project] section present"
    else
        echo "    WARN: Missing [project] section"
        CONFIG_ISSUES+=("pyproject.toml:structure:Missing [project] section")
    fi
    if grep -q '\[build-system\]' "$PROJECT_DIR/pyproject.toml" 2>/dev/null; then
        echo "    PASS: [build-system] section present"
    else
        echo "    WARN: Missing [build-system] section"
        CONFIG_ISSUES+=("pyproject.toml:structure:Missing [build-system] section")
    fi
    if grep -qE 'requires-python|python_requires' "$PROJECT_DIR/pyproject.toml" 2>/dev/null; then
        echo "    PASS: Python version constraint specified"
    else
        echo "    WARN: No Python version constraint"
        CONFIG_ISSUES+=("pyproject.toml:field:No requires-python specified")
    fi
fi

# --- package.json ---
if [[ -f "$PROJECT_DIR/package.json" ]]; then
    echo "  package.json:"
    if command -v jq &>/dev/null; then
        if jq empty "$PROJECT_DIR/package.json" 2>/dev/null; then
            echo "    PASS: Valid JSON syntax"
        else
            echo "    FAIL: Invalid JSON syntax"
            CONFIG_ISSUES+=("package.json:syntax:Invalid JSON")
            CONFIG_OK=false
        fi
        # Required fields
        for field in name version; do
            if jq -e ".$field" "$PROJECT_DIR/package.json" &>/dev/null; then
                echo "    PASS: '$field' field present"
            else
                echo "    WARN: Missing '$field' field"
                CONFIG_ISSUES+=("package.json:field:Missing $field")
            fi
        done
        if jq -e '.scripts.test' "$PROJECT_DIR/package.json" &>/dev/null; then
            echo "    PASS: test script defined"
        else
            echo "    WARN: No test script defined"
            CONFIG_ISSUES+=("package.json:field:No scripts.test defined")
        fi
        if jq -e '.engines.node' "$PROJECT_DIR/package.json" &>/dev/null; then
            echo "    PASS: Node engine version specified"
        else
            echo "    WARN: No engines.node constraint"
            CONFIG_ISSUES+=("package.json:field:No engines.node specified")
        fi
    else
        echo "    SKIP: jq not installed, cannot validate JSON structure"
    fi
fi

# --- Cargo.toml ---
if [[ -f "$PROJECT_DIR/Cargo.toml" ]]; then
    echo "  Cargo.toml:"
    if cargo verify-project --manifest-path "$PROJECT_DIR/Cargo.toml" &>/dev/null; then
        echo "    PASS: Valid Cargo manifest"
    else
        echo "    FAIL: Invalid Cargo manifest"
        CONFIG_ISSUES+=("Cargo.toml:syntax:Invalid manifest")
        CONFIG_OK=false
    fi
    if grep -q '\[package\]' "$PROJECT_DIR/Cargo.toml" 2>/dev/null; then
        echo "    PASS: [package] section present"
    fi
    if grep -qE '^edition\s*=' "$PROJECT_DIR/Cargo.toml" 2>/dev/null; then
        echo "    PASS: Rust edition specified"
    else
        echo "    WARN: No Rust edition specified"
        CONFIG_ISSUES+=("Cargo.toml:field:No edition specified")
    fi
fi

# --- Dockerfile ---
if [[ -f "$PROJECT_DIR/Dockerfile" ]]; then
    echo "  Dockerfile:"
    # Pinned base image (not using :latest or bare name)
    FROM_LINE=$(grep -E '^FROM ' "$PROJECT_DIR/Dockerfile" | head -1)
    if echo "$FROM_LINE" | grep -qE ':.+' && ! echo "$FROM_LINE" | grep -q ':latest'; then
        echo "    PASS: Base image is pinned ($FROM_LINE)"
    else
        echo "    WARN: Base image may not be pinned ($FROM_LINE)"
        CONFIG_ISSUES+=("Dockerfile:practice:Unpinned base image")
    fi
    # Non-root user
    if grep -q '^USER ' "$PROJECT_DIR/Dockerfile" 2>/dev/null; then
        echo "    PASS: Non-root USER directive present"
    else
        echo "    WARN: No USER directive (container runs as root)"
        CONFIG_ISSUES+=("Dockerfile:security:No non-root USER directive")
    fi
    # HEALTHCHECK
    if grep -q '^HEALTHCHECK ' "$PROJECT_DIR/Dockerfile" 2>/dev/null; then
        echo "    PASS: HEALTHCHECK defined"
    else
        echo "    WARN: No HEALTHCHECK defined"
        CONFIG_ISSUES+=("Dockerfile:practice:No HEALTHCHECK")
    fi
    # hadolint if available
    if command -v hadolint &>/dev/null; then
        HADOLINT_OUT=$(hadolint "$PROJECT_DIR/Dockerfile" 2>&1 | head -10)
        if [[ -z "$HADOLINT_OUT" ]]; then
            echo "    PASS: hadolint found no issues"
        else
            echo "    WARN: hadolint findings:"
            echo "$HADOLINT_OUT" | sed 's/^/      /'
        fi
    fi
fi

# --- docker-compose.yml ---
if [[ -f "$PROJECT_DIR/docker-compose.yml" ]]; then
    echo "  docker-compose.yml:"
    if python3 -c "import yaml; yaml.safe_load(open('$PROJECT_DIR/docker-compose.yml'))" 2>/dev/null; then
        echo "    PASS: Valid YAML syntax"
    else
        echo "    FAIL: Invalid YAML syntax"
        CONFIG_ISSUES+=("docker-compose.yml:syntax:Invalid YAML")
        CONFIG_OK=false
    fi
fi

# --- CI/CD Workflows ---
if [[ -d "$PROJECT_DIR/.github/workflows" ]]; then
    echo "  CI/CD workflows:"
    WORKFLOW_COUNT=0
    WORKFLOW_ERRORS=0
    for f in "$PROJECT_DIR"/.github/workflows/*.yml "$PROJECT_DIR"/.github/workflows/*.yaml; do
        [[ -f "$f" ]] || continue
        WORKFLOW_COUNT=$((WORKFLOW_COUNT + 1))
        FNAME=$(basename "$f")
        if python3 -c "import yaml; yaml.safe_load(open('$f'))" 2>/dev/null; then
            echo "    PASS: $FNAME valid YAML"
        else
            echo "    FAIL: $FNAME invalid YAML"
            CONFIG_ISSUES+=("$FNAME:syntax:Invalid YAML")
            WORKFLOW_ERRORS=$((WORKFLOW_ERRORS + 1))
            CONFIG_OK=false
        fi
    done
    echo "    Checked $WORKFLOW_COUNT workflow(s), $WORKFLOW_ERRORS error(s)"
fi

# Print structured issues summary for Phase 10
if [[ ${#CONFIG_ISSUES[@]} -gt 0 ]]; then
    echo ""
    echo "  Config issues (structured for Phase 10):"
    for issue in "${CONFIG_ISSUES[@]}"; do
        IFS=':' read -r file category detail <<< "$issue"
        echo "    [$category] $file: $detail"
    done
fi

echo ""
echo "  Configuration status: $([ "$CONFIG_OK" = true ] && echo "PASS" || echo "FAIL")"
```

## Step 5: Service Connectivity

```bash
echo ""
echo "-----------------------------------------------------------------------"
echo "  Service Connectivity"
echo "-----------------------------------------------------------------------"

SERVICES_OK=true

# PostgreSQL
if command -v pg_isready &>/dev/null; then
    if pg_isready -h localhost &>/dev/null; then
        echo "  PASS: PostgreSQL reachable"
    else
        echo "  SKIP: PostgreSQL not running (may not be needed)"
    fi
else
    echo "  SKIP: PostgreSQL client not installed"
fi

# Redis
if command -v redis-cli &>/dev/null; then
    if redis-cli ping &>/dev/null; then
        echo "  PASS: Redis reachable"
    else
        echo "  SKIP: Redis not running (may not be needed)"
    fi
else
    echo "  SKIP: Redis client not installed"
fi
```

## Step 6: File & Directory Permissions

```bash
echo ""
echo "-----------------------------------------------------------------------"
echo "  File & Directory Permissions"
echo "-----------------------------------------------------------------------"

PERMS_OK=true

# Check standard writable directories
for dir in logs/ data/ tmp/ uploads/ test-results/ .snapshots/; do
    if [[ -d "$PROJECT_DIR/$dir" ]]; then
        if [[ -w "$PROJECT_DIR/$dir" ]]; then
            echo "  PASS: $dir writable"
        else
            echo "  FAIL: $dir NOT writable"
            PERMS_OK=false
        fi
    fi
done

# Check write access to test artifact directories
TEST_DIRS=("$PROJECT_DIR/test-results" "$PROJECT_DIR/coverage" "$PROJECT_DIR/.pytest_cache")
for dir in "${TEST_DIRS[@]}"; do
    PARENT=$(dirname "$dir")
    if [[ -w "$PARENT" ]]; then
        echo "  PASS: Can create test artifacts in $(basename "$PARENT")/"
        break
    fi
done

# Check if project directory itself is writable (needed for sandbox)
if [[ -w "$PROJECT_DIR" ]]; then
    echo "  PASS: Project directory writable"
else
    echo "  FAIL: Project directory NOT writable (cannot create sandbox)"
    PERMS_OK=false
fi

echo ""
echo "  Permissions status: $([ "$PERMS_OK" = true ] && echo "PASS" || echo "FAIL")"
```

## Step 7: Service User Permissions

If systemd services exist, verify service user can write to required directories.

```bash
echo ""
echo "-----------------------------------------------------------------------"
echo "  Service User Permissions"
echo "-----------------------------------------------------------------------"

PROJECT_NAME=$(basename "$PROJECT_DIR")
SERVICES=$(systemctl list-units --type=service --all 2>/dev/null | grep -i "$PROJECT_NAME" | awk '{print $1}')

if [[ -n "$SERVICES" ]]; then
    for SERVICE in $SERVICES; do
        USER=$(systemctl show "$SERVICE" --property=User --value 2>/dev/null)
        STATE=$(systemctl show "$SERVICE" --property=ActiveState --value 2>/dev/null)
        echo "  Service $SERVICE runs as: ${USER:-root} (state: $STATE)"
    done
else
    echo "  SKIP: No systemd services found for $PROJECT_NAME"
fi
```

## Step 8: Sandbox Setup

Create an isolated sandbox environment for test artifacts and set test-mode environment variables.

```bash
echo ""
echo "-----------------------------------------------------------------------"
echo "  Sandbox Setup"
echo "-----------------------------------------------------------------------"

SANDBOX_OK=true

# Create sandbox directory for test artifacts
SANDBOX_DIR="$PROJECT_DIR/.test-sandbox"
if mkdir -p "$SANDBOX_DIR" 2>/dev/null; then
    echo "  PASS: Sandbox directory created at $SANDBOX_DIR"
else
    echo "  FAIL: Cannot create sandbox directory"
    SANDBOX_OK=false
fi

# Create subdirectories for organized test output
for subdir in artifacts logs coverage tmp; do
    mkdir -p "$SANDBOX_DIR/$subdir" 2>/dev/null
done

# Set environment variables for test isolation
export TEST_MODE=1
export TEST_SANDBOX_DIR="$SANDBOX_DIR"
export TEST_ARTIFACTS_DIR="$SANDBOX_DIR/artifacts"
export TEST_TMP_DIR="$SANDBOX_DIR/tmp"

# Project-type-specific test env vars
case "$PROJECT_TYPE" in
    python)
        export PYTHONDONTWRITEBYTECODE=1
        export PYTEST_TMPDIR="$SANDBOX_DIR/tmp"
        echo "  PASS: Python test env configured (PYTHONDONTWRITEBYTECODE, PYTEST_TMPDIR)"
        ;;
    node)
        export NODE_ENV=test
        echo "  PASS: Node test env configured (NODE_ENV=test)"
        ;;
    go)
        export GO_ENV=test
        echo "  PASS: Go test env configured (GO_ENV=test)"
        ;;
    rust)
        export RUST_TEST=1
        echo "  PASS: Rust test env configured (RUST_TEST=1)"
        ;;
esac

# Detect and start mock services
if [[ -f "$PROJECT_DIR/docker-compose.test.yml" ]]; then
    echo "  Found docker-compose.test.yml — starting test services..."
    if command -v docker &>/dev/null && docker info &>/dev/null; then
        if docker compose -f "$PROJECT_DIR/docker-compose.test.yml" up -d 2>/dev/null || \
           docker-compose -f "$PROJECT_DIR/docker-compose.test.yml" up -d 2>/dev/null; then
            echo "  PASS: Test services started via docker-compose.test.yml"
            echo "  NOTE: Cleanup command: docker compose -f $PROJECT_DIR/docker-compose.test.yml down"
        else
            echo "  WARN: Failed to start test services"
        fi
    else
        echo "  SKIP: Docker not available, cannot start test services"
    fi
else
    echo "  SKIP: No docker-compose.test.yml found (no mock services needed)"
fi

# Verify production data isolation
if [[ -f "$PROJECT_DIR/.env" ]]; then
    # Check for production database URLs in .env
    PROD_INDICATORS=$(grep -iE '(DATABASE_URL|DB_HOST|REDIS_URL)' "$PROJECT_DIR/.env" 2>/dev/null | grep -ivE '(localhost|127\.0\.0\.1|test|sandbox|mock)' || true)
    if [[ -n "$PROD_INDICATORS" ]]; then
        echo "  WARN: .env may contain production service URLs (not localhost/test):"
        echo "$PROD_INDICATORS" | sed 's/=.*/=***/' | sed 's/^/    /'
    else
        echo "  PASS: No production service URLs detected in .env"
    fi
fi

echo ""
echo "  Sandbox status: $([ "$SANDBOX_OK" = true ] && echo "PASS" || echo "FAIL")"
echo "  Sandbox dir: $SANDBOX_DIR"
echo "  Cleanup: rm -rf $SANDBOX_DIR"
```

## Step 9: VM Isolation Availability

Detect if VM-based isolation (Phase V) is available for dangerous operations testing.

```bash
echo ""
echo "-----------------------------------------------------------------------"
echo "  VM Isolation Availability"
echo "-----------------------------------------------------------------------"

detect_vm_availability() {
    VM_AVAILABLE=false
    VM_DETAILS=""
    EXISTING_VMS=()
    ISO_LIBRARY=""

    # Check for libvirt/virsh
    if ! command -v virsh &>/dev/null; then
        echo "  SKIP: virsh not installed"
        echo "VM Available: false"
        echo "VM Details: libvirt not installed"
        return 1
    fi

    # Check libvirt service
    if ! systemctl is-active libvirtd &>/dev/null; then
        echo "  WARN: libvirtd service not running"
        echo "VM Available: false"
        echo "VM Details: libvirtd not active"
        return 1
    fi

    # Check for existing VMs
    RUNNING_VMS=$(sudo virsh list --name 2>/dev/null | grep -v '^$')
    ALL_VMS=$(sudo virsh list --all --name 2>/dev/null | grep -v '^$')

    if [[ -z "$ALL_VMS" ]]; then
        echo "  PASS: libvirt available (no VMs configured)"
        echo "VM Available: false"
        echo "VM Details: No VMs exist"
        return 0
    fi

    # VMs exist — enumerate them
    echo "  PASS: libvirt available"
    echo "  Existing VMs:"
    while IFS= read -r vm; do
        if echo "$RUNNING_VMS" | grep -q "^$vm$"; then
            EXISTING_VMS+=("$vm (running)")
            echo "    - $vm (running)"
        else
            EXISTING_VMS+=("$vm (stopped)")
            echo "    - $vm (stopped)"
        fi
    done <<< "$ALL_VMS"

    # Check for ISO library (for creating new VMs)
    ISO_PATHS=("/hddRaid1/ISOs" "$HOME/ISOs" "/hddRaid1/VirtualMachines")
    for path in "${ISO_PATHS[@]}"; do
        if [[ -d "$path" ]]; then
            ISO_COUNT=$(find "$path" -name "*.iso" -type f 2>/dev/null | wc -l)
            if [[ "$ISO_COUNT" -gt 0 ]]; then
                ISO_LIBRARY="$path ($ISO_COUNT ISOs)"
                echo "  ISO Library: $ISO_LIBRARY"
                break
            fi
        fi
    done

    # Check for test-specific VMs (naming convention: *-test, *-dev, test-*)
    TEST_VMS=$(echo "$ALL_VMS" | grep -E "test|dev" || true)
    if [[ -n "$TEST_VMS" ]]; then
        echo "  Test VMs Available:"
        while IFS= read -r vm; do
            echo "    - $vm"
        done <<< "$TEST_VMS"
    fi

    # Check SSH connectivity to running test VMs
    if [[ -n "$TEST_VMS" ]]; then
        echo ""
        echo "  SSH Connectivity:"
        while IFS= read -r vm; do
            if echo "$RUNNING_VMS" | grep -q "^$vm$"; then
                VM_IP=$(sudo virsh domifaddr "$vm" 2>/dev/null | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1)
                if [[ -n "$VM_IP" ]]; then
                    if timeout 2 ssh -o BatchMode=yes -o ConnectTimeout=2 "$VM_IP" echo "ok" &>/dev/null; then
                        echo "    PASS: $vm ($VM_IP) - SSH ready"
                    else
                        echo "    WARN: $vm ($VM_IP) - SSH not ready"
                    fi
                else
                    echo "    SKIP: $vm - No IP detected"
                fi
            fi
        done <<< "$TEST_VMS"
    fi

    # Only set VM_AVAILABLE=true if test VMs actually exist
    if [[ -n "$TEST_VMS" ]]; then
        VM_AVAILABLE=true
    fi

    echo ""
    echo "VM Available: $VM_AVAILABLE"
    echo "VM Count: $(echo "$ALL_VMS" | grep -c . || echo 0)"
    echo "ISO Library: ${ISO_LIBRARY:-none}"

    export VM_AVAILABLE EXISTING_VMS ISO_LIBRARY
}

detect_vm_availability
```

## Step 10: Physical Test Hardware (Optional)

Detect SSH-accessible physical test machines (Raspberry Pi, spare systems, etc.)

```bash
echo ""
echo "-----------------------------------------------------------------------"
echo "  Physical Test Hardware"
echo "-----------------------------------------------------------------------"

detect_physical_test_hardware() {
    PHYSICAL_HOSTS_FILE="$HOME/.config/test-skill/physical-hosts.conf"
    PHYSICAL_HOSTS=()

    if [[ ! -f "$PHYSICAL_HOSTS_FILE" ]]; then
        echo "  SKIP: No physical test hosts configured"
        echo "  (Create $PHYSICAL_HOSTS_FILE to add test hardware)"
        echo "Physical Hosts: none"
        return 0
    fi

    echo "  Checking configured hosts:"
    while IFS='=' read -r name host; do
        [[ "$name" =~ ^#.*$ ]] && continue
        [[ -z "$name" ]] && continue

        name=$(echo "$name" | tr -d '[:space:]')
        host=$(echo "$host" | tr -d '[:space:]')

        if timeout 3 ssh -o BatchMode=yes -o ConnectTimeout=2 "$host" echo "ok" &>/dev/null; then
            echo "    PASS: $name ($host) - reachable"
            PHYSICAL_HOSTS+=("$name:$host:online")
        else
            echo "    FAIL: $name ($host) - unreachable"
            PHYSICAL_HOSTS+=("$name:$host:offline")
        fi
    done < "$PHYSICAL_HOSTS_FILE"

    ONLINE_COUNT=$(printf '%s\n' "${PHYSICAL_HOSTS[@]}" | grep -c ":online$" || echo 0)
    echo ""
    echo "Physical Hosts: $ONLINE_COUNT online"

    export PHYSICAL_HOSTS
}

detect_physical_test_hardware
```

**Physical Hosts Configuration Format** (`~/.config/test-skill/physical-hosts.conf`):
```
# Test Hardware Configuration
# Format: name=user@hostname_or_ip

rpi4-test=pi@192.168.1.50
spare-desktop=bosco@testbox.local
```

## Report Format

```
## Pre-Flight Check Results

| Check | Status | Details |
|-------|--------|---------|
| Project Detection | PASS/FAIL | [types detected] |
| Tool Versions | PASS/FAIL | [versions] |
| Dependencies | PASS/FAIL | [issues] |
| Environment Variables | PASS/FAIL | [missing vars] |
| Configuration Validation | PASS/FAIL | [N issues found] |
| Service Connectivity | PASS/SKIP | [status] |
| File Permissions | PASS/FAIL | [issues] |
| Service Permissions | PASS/SKIP | [issues] |
| Sandbox Setup | PASS/FAIL | [sandbox path] |
| VM Availability | PASS/SKIP | [count VMs, ISO library] |
| Physical Test Hosts | PASS/SKIP | [count online] |

**Pre-Flight Status**: PASS READY / FAIL BLOCKED

-----------------------------------------------------------------------
  ISOLATION CAPABILITIES
-----------------------------------------------------------------------

Sandbox: [Created at path / Failed]
VM Isolation (Phase V): [Available - X test VMs / Not Available]
Physical Hardware: [X hosts online / Not configured]
ISO Library: [path (count) / None]

-----------------------------------------------------------------------
  CONFIG ISSUES (for Phase 10)
-----------------------------------------------------------------------

[category] file: description
[category] file: description

Note: Isolation requirements are determined by Phase 1 (Discovery).
Phase 0 only reports WHAT is available, not what is NEEDED.
```
