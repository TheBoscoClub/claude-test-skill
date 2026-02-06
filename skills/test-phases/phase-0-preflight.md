# Phase 0: Pre-Flight Environment Validation

Validate the environment is ready before running any tests. Fail fast on environment issues.

## Step 1: Dependency Verification

```bash
PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"

echo "═══════════════════════════════════════════════════════════════════"
echo "  PHASE 0: PRE-FLIGHT CHECKS"
echo "═══════════════════════════════════════════════════════════════════"

# Python
if [[ -f "$PROJECT_DIR/requirements.txt" ]]; then
    pip check 2>&1 | head -10
    pip freeze | diff - "$PROJECT_DIR/requirements.txt" 2>&1 | head -10
fi

# Node.js
if [[ -f "$PROJECT_DIR/package.json" ]]; then
    npm ls --depth=0 2>&1 | grep -E "WARN|ERR" | head -10 || echo "Dependencies OK"
fi

# Go
if [[ -f "$PROJECT_DIR/go.mod" ]]; then
    go mod verify 2>&1
fi

# Rust
if [[ -f "$PROJECT_DIR/Cargo.toml" ]]; then
    cargo verify-project 2>&1
fi
```

## Step 2: Environment Variables

Find all environment variable references and verify they exist:

```bash
# Find env var references
ENV_REFS=$(grep -roh "os\.environ\[.\|process\.env\.\|os\.getenv(" --include="*.py" --include="*.js" . 2>/dev/null | head -20)

# Check .env.example vs .env
if [[ -f .env.example ]] && [[ -f .env ]]; then
    echo "Checking .env vs .env.example..."
    diff <(grep -E "^[A-Z_]" .env.example | cut -d= -f1 | sort) \
         <(grep -E "^[A-Z_]" .env | cut -d= -f1 | sort) 2>/dev/null | head -10
fi
```

## Step 3: Service Connectivity

```bash
# Check database
pg_isready -h localhost 2>/dev/null || echo "PostgreSQL: N/A"
redis-cli ping 2>/dev/null || echo "Redis: N/A"
```

## Step 4: File Permissions

```bash
# Check writable directories
for dir in logs/ data/ tmp/ uploads/; do
    if [[ -d "$dir" ]]; then
        [[ -w "$dir" ]] && echo "✅ $dir writable" || echo "❌ $dir NOT writable"
    fi
done
```

## Step 5: Service User Permissions

If systemd services exist, verify service user can write to required directories.

```bash
PROJECT_NAME=$(basename "$(pwd)")
SERVICES=$(systemctl list-units --type=service --all 2>/dev/null | grep -i "$PROJECT_NAME" | awk '{print $1}')

for SERVICE in $SERVICES; do
    USER=$(systemctl show "$SERVICE" --property=User --value 2>/dev/null)
    echo "Service $SERVICE runs as: ${USER:-root}"
done
```

## Step 6: VM Isolation Availability

Detect if VM-based isolation (Phase V) is available for dangerous operations testing.

```bash
echo ""
echo "───────────────────────────────────────────────────────────────────"
echo "  VM Isolation Availability"
echo "───────────────────────────────────────────────────────────────────"

detect_vm_availability() {
    VM_AVAILABLE=false
    VM_DETAILS=""
    EXISTING_VMS=()
    ISO_LIBRARY=""

    # Check for libvirt/virsh
    if ! command -v virsh &>/dev/null; then
        echo "  ⚪ virsh not installed"
        echo "VM Available: false"
        echo "VM Details: libvirt not installed"
        return 1
    fi

    # Check libvirt service
    if ! systemctl is-active libvirtd &>/dev/null; then
        echo "  ⚠️ libvirtd service not running"
        echo "VM Available: false"
        echo "VM Details: libvirtd not active"
        return 1
    fi

    # Check for existing VMs
    RUNNING_VMS=$(virsh list --name 2>/dev/null | grep -v '^$')
    ALL_VMS=$(virsh list --all --name 2>/dev/null | grep -v '^$')

    if [ -n "$ALL_VMS" ]; then
        VM_AVAILABLE=true
        while IFS= read -r vm; do
            if echo "$RUNNING_VMS" | grep -q "^$vm$"; then
                EXISTING_VMS+=("$vm (running)")
            else
                EXISTING_VMS+=("$vm (stopped)")
            fi
        done <<< "$ALL_VMS"
        echo "  ✅ libvirt available"
        echo "  Existing VMs:"
        for vm in "${EXISTING_VMS[@]}"; do
            echo "    - $vm"
        done
    else
        echo "  ✅ libvirt available (no VMs configured)"
    fi

    # Check for ISO library (for creating new VMs)
    ISO_PATHS=("/hddRaid1/ISOs" "$HOME/ISOs" "/var/lib/libvirt/images")
    for path in "${ISO_PATHS[@]}"; do
        if [ -d "$path" ]; then
            ISO_COUNT=$(find "$path" -name "*.iso" -type f 2>/dev/null | wc -l)
            if [ "$ISO_COUNT" -gt 0 ]; then
                ISO_LIBRARY="$path ($ISO_COUNT ISOs)"
                echo "  ISO Library: $ISO_LIBRARY"
                break
            fi
        fi
    done

    # Check for test-specific VMs (naming convention: *-test, *-dev, test-*)
    TEST_VMS=$(echo "$ALL_VMS" | grep -E "test|dev" || true)
    if [ -n "$TEST_VMS" ]; then
        echo "  Test VMs Available:"
        while IFS= read -r vm; do
            echo "    - $vm"
        done <<< "$TEST_VMS"
    fi

    # Check SSH connectivity to common test VMs
    if [ -n "$TEST_VMS" ]; then
        echo ""
        echo "  SSH Connectivity:"
        while IFS= read -r vm; do
            if echo "$RUNNING_VMS" | grep -q "^$vm$"; then
                # Try to get VM IP
                VM_IP=$(virsh domifaddr "$vm" 2>/dev/null | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1)
                if [ -n "$VM_IP" ]; then
                    if timeout 2 ssh -o BatchMode=yes -o ConnectTimeout=2 "$VM_IP" echo "ok" &>/dev/null; then
                        echo "    ✅ $vm ($VM_IP) - SSH ready"
                    else
                        echo "    ⚠️ $vm ($VM_IP) - SSH not ready"
                    fi
                else
                    echo "    ⚪ $vm - No IP detected"
                fi
            fi
        done <<< "$TEST_VMS"
    fi

    VM_AVAILABLE=true
    echo ""
    echo "VM Available: $VM_AVAILABLE"
    echo "VM Count: $(echo "$ALL_VMS" | grep -c . || echo 0)"
    echo "ISO Library: ${ISO_LIBRARY:-none}"

    export VM_AVAILABLE EXISTING_VMS ISO_LIBRARY
}

detect_vm_availability
```

## Step 7: Physical Test Hardware (Optional)

Detect SSH-accessible physical test machines (Raspberry Pi, spare systems, etc.)

```bash
echo ""
echo "───────────────────────────────────────────────────────────────────"
echo "  Physical Test Hardware"
echo "───────────────────────────────────────────────────────────────────"

detect_physical_test_hardware() {
    PHYSICAL_HOSTS_FILE="$HOME/.config/test-skill/physical-hosts.conf"
    PHYSICAL_HOSTS=()

    if [ ! -f "$PHYSICAL_HOSTS_FILE" ]; then
        echo "  ⚪ No physical test hosts configured"
        echo "  (Create $PHYSICAL_HOSTS_FILE to add test hardware)"
        echo "Physical Hosts: none"
        return 0
    fi

    echo "  Checking configured hosts:"
    while IFS='=' read -r name host; do
        [[ "$name" =~ ^#.*$ ]] && continue  # Skip comments
        [[ -z "$name" ]] && continue        # Skip empty lines

        name=$(echo "$name" | tr -d '[:space:]')
        host=$(echo "$host" | tr -d '[:space:]')

        if timeout 3 ssh -o BatchMode=yes -o ConnectTimeout=2 "$host" echo "ok" &>/dev/null; then
            echo "    ✅ $name ($host) - reachable"
            PHYSICAL_HOSTS+=("$name:$host:online")
        else
            echo "    ❌ $name ($host) - unreachable"
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
| Dependencies | ✅/❌ | [details] |
| Environment Variables | ✅/❌ | [missing vars] |
| Service Connectivity | ✅/❌ | [status] |
| File Permissions | ✅/❌ | [issues] |
| Service Permissions | ✅/❌ | [issues] |
| VM Availability | ✅/❌ | [count VMs, ISO library] |
| Physical Test Hosts | ✅/❌ | [count online] |

**Pre-Flight Status**: ✅ READY / ❌ BLOCKED

─────────────────────────────────────────────────────────────────
  ISOLATION CAPABILITIES
─────────────────────────────────────────────────────────────────

Sandbox (Phase M): [Available/Not Available]
VM Isolation (Phase V): [Available - X VMs/Not Available]
Physical Hardware: [X hosts online/Not configured]
ISO Library: [path (count)/None]

Note: Isolation requirements are determined by Phase 1 (Discovery).
Phase 0 only reports WHAT is available, not what is NEEDED.
```
