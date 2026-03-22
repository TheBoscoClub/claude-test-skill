# VM Lifecycle Management Module

> **Model**: `sonnet` | **Tier**: 8 (VM infrastructure) | **Modifies Files**: No (manages VMs)
> **Task Tracking**: Call `TaskUpdate(taskId, status="in_progress")` at start, `TaskUpdate(taskId, status="completed")` when done.
> **Key Tools**: `Bash` for virsh commands (use `timeout` for hung operations). Use `AskUserQuestion` if VM fails to start and user needs to choose alternative.

Manages automatic VM startup and shutdown for isolated testing.

## Purpose

- **Start** the test VM when Phase 0/1 determines VM isolation is needed
- **Detect dirty VMs** — if a `post_test_restore=true` VM is running at startup, an interrupted test left it dirty; revert to pristine before proceeding
- **Track** that the VM was started by `/test` (to know what to cleanup)
- **Cleanup (Phase C)** — for `post_test_restore=true` VMs: ALWAYS revert to pristine, shut down, and leave shut down (regardless of who started it). For shared VMs: only shut down if `/test` started it

### Expected VM States

| When | post_test_restore=true VM | Shared VM |
|------|--------------------------|-----------|
| Before `/test` starts | **Shut down + pristine** | Running or shut down |
| During `/test` | Running (started by /test) | Running |
| After Phase C cleanup | **Shut down + pristine** | Restored to original state |

## Default Test VM

**VM Name**: `test-vm-cachyos`
- CachyOS with KDE desktop
- 4GB RAM, 4 vCPUs, 40GB disk
- VNC: 127.0.0.1:5900

## VM Lifecycle State File

Track VM state in project directory:
```
.test-vm-state
├── vm_name: test-vm-cachyos
├── started_by_test: true/false
├── start_time: timestamp
├── isolation_level: vm-required/vm-recommended
└── original_state: running/stopped
```

## Start VM (Called after Discovery)

```bash
start_test_vm() {
    local PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
    local ISOLATION_LEVEL="${ISOLATION_LEVEL:-sandbox}"
    local STATE_FILE="${PROJECT_DIR}/.test-vm-state"

    # Read project-specific VM from manifest or project-vm-map, fall back to generic
    local DEFAULT_VM="test-vm-cachyos"
    if [[ -f "${PROJECT_DIR}/vm-test-manifest.json" ]]; then
        local MANIFEST_VM=$(python3 -c "import json; d=json.load(open('${PROJECT_DIR}/vm-test-manifest.json')); print(d.get('vm_testing',{}).get('default_vm',''))" 2>/dev/null)
        [[ -n "$MANIFEST_VM" ]] && DEFAULT_VM="$MANIFEST_VM"
    fi
    local VM_MAP="$HOME/.claude/config/project-vm-map.json"
    if [[ -f "$VM_MAP" ]]; then
        local PROJECT_NAME=$(basename "$PROJECT_DIR")
        local MAP_VM=$(python3 -c "import json; d=json.load(open('$VM_MAP')); print(d.get('projects',{}).get('$PROJECT_NAME',{}).get('vm',''))" 2>/dev/null)
        [[ -n "$MAP_VM" ]] && DEFAULT_VM="$MAP_VM"
    fi

    echo ""
    echo "═══════════════════════════════════════════════════════════════════"
    echo "  VM LIFECYCLE: STARTUP"
    echo "═══════════════════════════════════════════════════════════════════"
    echo ""

    # Only start VM if isolation level requires it
    if [[ "$ISOLATION_LEVEL" != "vm-required" && "$ISOLATION_LEVEL" != "vm-recommended" ]]; then
        echo "  ⚪ VM not needed (isolation level: $ISOLATION_LEVEL)"
        echo "  Using sandbox isolation instead"
        return 0
    fi

    echo "  Isolation Level: $ISOLATION_LEVEL"
    echo "  VM isolation required/recommended"
    echo ""

    # Check if virsh is available
    if ! command -v virsh &>/dev/null; then
        echo "  ❌ virsh not installed - cannot start VM"
        if [[ "$ISOLATION_LEVEL" == "vm-required" ]]; then
            echo "  ⛔ ABORT: VM isolation required but not available"
            return 1
        fi
        echo "  ⚠️ Falling back to sandbox (caution advised)"
        return 0
    fi

    # Check libvirtd service
    if ! systemctl is-active libvirtd &>/dev/null; then
        echo "  Starting libvirtd service..."
        sudo systemctl start libvirtd
        sleep 2
    fi

    # Find a suitable test VM
    local VM_NAME=""
    local TEST_VMS=$(virsh list --all --name 2>/dev/null | grep -E "test|dev" | head -5)

    # Prefer default test VM if it exists
    if virsh dominfo "$DEFAULT_VM" &>/dev/null 2>&1; then
        VM_NAME="$DEFAULT_VM"
    elif [[ -n "$TEST_VMS" ]]; then
        VM_NAME=$(echo "$TEST_VMS" | head -1)
    fi

    if [[ -z "$VM_NAME" ]]; then
        echo "  ❌ No test VM found"
        if [[ "$ISOLATION_LEVEL" == "vm-required" ]]; then
            echo "  ⛔ ABORT: VM isolation required but no VM available"
            echo ""
            echo "  To create a test VM:"
            echo "    1. Ensure ISO exists: /hddRaid1/ISOs/cachyos-*.iso"
            echo "    2. Use libvirt-vm-manager or virt-install"
            echo "    3. Name it with 'test' in the name (e.g., test-vm-cachyos)"
            return 1
        fi
        echo "  ⚠️ Falling back to sandbox (caution advised)"
        return 0
    fi

    echo "  Selected VM: $VM_NAME"

    # Check current VM state
    local CURRENT_STATE=$(virsh domstate "$VM_NAME" 2>/dev/null | tr -d '[:space:]')
    echo "  Current State: $CURRENT_STATE"

    # Read project-specific pristine snapshot name
    local PRISTINE_SNAP=""
    local POST_TEST_RESTORE="false"
    if [[ -f "${PROJECT_DIR}/vm-test-manifest.json" ]]; then
        PRISTINE_SNAP=$(python3 -c "import json; d=json.load(open('${PROJECT_DIR}/vm-test-manifest.json')); print(d.get('vm_testing',{}).get('pristine_snapshot',''))" 2>/dev/null)
        POST_TEST_RESTORE=$(python3 -c "import json; d=json.load(open('${PROJECT_DIR}/vm-test-manifest.json')); print(str(d.get('vm_testing',{}).get('post_test_restore', False)).lower())" 2>/dev/null)
    fi
    PRISTINE_SNAP="${PRISTINE_SNAP:-clean-install}"

    # ─── DIRTY VM DETECTION ─────────────────────────────────────────
    # For post_test_restore=true projects, the VM should ALWAYS be
    # pristine and shut down when we get here. If it's running, a
    # previous test cycle was interrupted and left the VM dirty.
    # Revert to pristine before proceeding.
    if [[ "$CURRENT_STATE" == "running" && "$POST_TEST_RESTORE" == "true" ]]; then
        echo ""
        echo "  ⚠️  VM is running — likely dirty from an interrupted test cycle"
        echo "     Reverting to pristine before proceeding..."
        echo ""

        # Force stop the dirty VM
        sudo virsh destroy "$VM_NAME" 2>/dev/null || true

        # Discard overlay and revert to pristine base
        local OVERLAY="/hddRaid1/VirtualMachines/${VM_NAME}.${PRISTINE_SNAP}"
        local BASE="/hddRaid1/VirtualMachines/${VM_NAME}.qcow2"
        if [[ -f "$OVERLAY" ]]; then
            # DISCARD changes — do NOT commit overlay into base
            sudo virsh snapshot-delete "$VM_NAME" "$PRISTINE_SNAP" --metadata 2>/dev/null
            sudo virt-xml "$VM_NAME" --edit target=vda --disk path="$BASE" 2>/dev/null
            # Fix circular backingStore refs
            sudo virsh dumpxml "$VM_NAME" > /tmp/vm-fix.xml
            python3 -c "
import xml.etree.ElementTree as ET
tree = ET.parse('/tmp/vm-fix.xml')
for disk in tree.getroot().iter('disk'):
    for bs in disk.findall('backingStore'):
        disk.remove(bs)
tree.write('/tmp/vm-fix.xml', xml_declaration=True)
"
            sudo virsh define /tmp/vm-fix.xml 2>/dev/null
            rm -f /tmp/vm-fix.xml
            sudo rm -f "$OVERLAY"
            echo "  ✅ Dirty overlay discarded — base image is pristine"
        fi

        # Recreate pristine snapshot and start clean
        sudo virsh snapshot-create-as "$VM_NAME" "$PRISTINE_SNAP" \
            "Pristine OS with dependencies. No application installed." --disk-only 2>/dev/null
        echo "  ✅ Pristine snapshot recreated"

        CURRENT_STATE="shutoff"
    fi

    # Record original state for cleanup
    local STARTED_BY_TEST="false"

    if [[ "$CURRENT_STATE" == "running" ]]; then
        # Only reached for non-post_test_restore VMs (e.g., shared test-vm-cachyos)
        echo "  ✅ VM already running"
        STARTED_BY_TEST="false"
    else
        echo "  Starting VM..."

        # Start the VM
        if sudo virsh start "$VM_NAME" 2>/dev/null; then
            echo "  ✅ VM started successfully"
            STARTED_BY_TEST="true"
        else
            echo "  ❌ Failed to start VM"
            if [[ "$ISOLATION_LEVEL" == "vm-required" ]]; then
                return 1
            fi
            echo "  ⚠️ Falling back to sandbox"
            return 0
        fi

        # Wait for VM to boot
        echo "  Waiting for VM to boot (30s)..."
        sleep 30
    fi

    # Write state file for cleanup phase
    cat > "$STATE_FILE" << EOF
# Test VM State - Generated by /test
# Do not edit manually

vm_name=$VM_NAME
started_by_test=$STARTED_BY_TEST
original_state=$CURRENT_STATE
isolation_level=$ISOLATION_LEVEL
start_time=$(date -Iseconds)
EOF

    echo ""
    echo "  📝 State saved to: $STATE_FILE"

    # Get VM IP for SSH access
    local VM_IP=$(virsh domifaddr "$VM_NAME" 2>/dev/null | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1)
    if [[ -n "$VM_IP" ]]; then
        echo "  🌐 VM IP: $VM_IP"
        echo "vm_ip=$VM_IP" >> "$STATE_FILE"
    else
        echo "  ⚠️ Could not detect VM IP (may still be booting)"
    fi

    # Check VNC port
    local VNC_PORT=$(virsh vncdisplay "$VM_NAME" 2>/dev/null | grep -oE ':[0-9]+' | tr -d ':')
    if [[ -n "$VNC_PORT" ]]; then
        local VNC_ACTUAL=$((5900 + VNC_PORT))
        echo "  🖥️  VNC: 127.0.0.1:$VNC_ACTUAL"
        echo "vnc_port=$VNC_ACTUAL" >> "$STATE_FILE"
    fi

    # Create pre-test snapshot (MANDATORY)
    # This captures the VM state BEFORE tests run, so we can restore afterward
    local PRE_TEST_SNAPSHOT="pre-test-$(date +%Y%m%d-%H%M%S)"
    echo ""
    echo "  📸 Creating pre-test snapshot: $PRE_TEST_SNAPSHOT"
    if sudo virsh snapshot-create-as "$VM_NAME" "$PRE_TEST_SNAPSHOT" \
        --description "Pre-test state before /test run" --atomic 2>/dev/null; then
        echo "  ✅ Pre-test snapshot created"
        echo "pre_test_snapshot=$PRE_TEST_SNAPSHOT" >> "$STATE_FILE"
    else
        echo "  ⚠️ Failed to create pre-test snapshot (VM may be running)"
        echo "     Tests will proceed but VM state won't be auto-restored"
    fi

    # ─── PRISTINE VM DETECTION & AUTO-INSTALL ─────────────────────
    # If the VM is pristine (no app installed), run install.sh before tests
    install_on_pristine_vm "$VM_NAME" "$VM_IP" "$PROJECT_DIR"

    echo ""
    echo "───────────────────────────────────────────────────────────────────"
    echo "  VM READY FOR TESTING"
    echo "───────────────────────────────────────────────────────────────────"
    echo ""
    echo "VM Name: $VM_NAME"
    echo "Started by /test: $STARTED_BY_TEST"
    echo "State File: $STATE_FILE"
    echo ""

    # Export for other phases
    export TEST_VM_NAME="$VM_NAME"
    export TEST_VM_STARTED="$STARTED_BY_TEST"
    export TEST_VM_IP="$VM_IP"
}
```

## Production Data Isolation (MANDATORY)

**No test VM managed by this lifecycle module may have LIVE ACCESS to production storage.**

- **NEVER** configure NFS, CIFS, virtiofs, or virtio-9p mounts from the host's production paths into the VM
- Copying data *into* the VM (scp, rsync) is fine — once on the VM's disk, it's isolated
- Test VM libraries should be ≤275GB on the VM's own disk

## Install on Pristine VM (Called after VM boots)

When a VM starts from a pristine snapshot (OS + deps only, no application installed),
the test framework must bootstrap the application before tests can run.

This function:
1. Detects whether the app is installed (using the `detects_pristine_by` check from `vm-test-manifest.json`)
2. If pristine AND `vm-test-manifest.json` has an `install` section with `required_on_pristine: true`:
   - Copies the project to the VM
   - Runs the install command non-interactively (e.g., `install.sh --system`)
3. The service user/group (if any) is a no-login service account created by the install script

```bash
install_on_pristine_vm() {
    local VM_NAME="$1"
    local VM_IP="$2"
    local PROJECT_DIR="${3:-$(pwd)}"
    local MANIFEST="${PROJECT_DIR}/vm-test-manifest.json"

    # Skip if no manifest or install not required
    if [[ ! -f "$MANIFEST" ]]; then
        return 0
    fi

    local REQUIRED=$(python3 -c "import json; d=json.load(open('$MANIFEST')); print(str(d.get('vm_testing',{}).get('install',{}).get('required_on_pristine', False)).lower())" 2>/dev/null)
    if [[ "$REQUIRED" != "true" ]]; then
        return 0
    fi

    # Read SSH config from manifest or use defaults
    local SSH_USER=$(python3 -c "import json; d=json.load(open('$MANIFEST')); print(d.get('ssh_config',{}).get('user','claude'))" 2>/dev/null)
    local SSH_KEY=$(python3 -c "import json; d=json.load(open('$MANIFEST')); print(d.get('ssh_config',{}).get('key','~/.claude/ssh/id_ed25519'))" 2>/dev/null)
    SSH_KEY="${SSH_KEY/#\~/$HOME}"

    local SSH_CMD="ssh -i $SSH_KEY -o ConnectTimeout=10 -o StrictHostKeyChecking=no $SSH_USER@$VM_IP"

    # Detect pristine state using manifest's detects_pristine_by field (defaults to checking if install dir exists)
    local DETECT_CMD=$(python3 -c "import json; d=json.load(open('$MANIFEST')); print(d.get('vm_testing',{}).get('install',{}).get('detects_pristine_by','test -d /opt/\$(basename(\"$(pwd)\"))'))" 2>/dev/null)

    if $SSH_CMD "$DETECT_CMD" &>/dev/null 2>&1; then
        echo "  ✅ Application already installed on VM (not pristine)"
        return 0
    fi

    echo ""
    echo "  ┌─────────────────────────────────────────────────────────────┐"
    echo "  │  PRISTINE VM DETECTED — Running fresh install              │"
    echo "  └─────────────────────────────────────────────────────────────┘"
    echo ""

    local INSTALL_CMD=$(python3 -c "import json; d=json.load(open('$MANIFEST')); print(d.get('vm_testing',{}).get('install',{}).get('command','./install.sh --system'))" 2>/dev/null)

    # Copy project to VM staging area
    echo "  Copying project to VM /tmp/fresh-install/..."
    rsync -az --exclude='.git' --exclude='venv' --exclude='__pycache__' \
        --exclude='node_modules' --exclude='.venv' --exclude='*.pyc' \
        --exclude='.snapshots' --exclude='*.tar.gz' \
        -e "ssh -i $SSH_KEY -o StrictHostKeyChecking=no" \
        "$PROJECT_DIR/" "$SSH_USER@$VM_IP:/tmp/fresh-install/"

    if [[ $? -ne 0 ]]; then
        echo "  ❌ Failed to copy project to VM"
        return 1
    fi
    echo "  ✅ Project copied"

    # Run install command on VM (non-interactive via --system flag)
    echo "  Running: $INSTALL_CMD"
    if $SSH_CMD "cd /tmp/fresh-install && sudo bash -c '$INSTALL_CMD'" 2>&1; then
        echo "  ✅ Fresh install completed"
    else
        echo "  ❌ Fresh install FAILED"
        echo "     The VM may not have a functioning application"
        return 1
    fi

    # Verify: check that the pristine detection now passes (app is installed)
    if $SSH_CMD "$DETECT_CMD" &>/dev/null 2>&1; then
        echo "  ✅ Verified: application installed successfully"
    else
        echo "  ⚠️ Install completed but pristine detection still fails"
    fi

    # Verify: check VERSION file if install dir is defined in manifest
    local INSTALL_DIR=$(python3 -c "import json; d=json.load(open('$MANIFEST')); print(d.get('vm_testing',{}).get('install',{}).get('install_dir',''))" 2>/dev/null)
    if [[ -n "$INSTALL_DIR" ]]; then
        local REMOTE_VERSION=$($SSH_CMD "cat ${INSTALL_DIR}/VERSION 2>/dev/null" 2>/dev/null)
        if [[ -n "$REMOTE_VERSION" ]]; then
            echo "  ✅ Verified: version $REMOTE_VERSION installed"
        fi
    fi

    # Clean up staging area
    $SSH_CMD "rm -rf /tmp/fresh-install" 2>/dev/null

    # ─── POST-INSTALL: Docker container database initialization ──────
    # After revert to pristine, BOTH native app DB and Docker container DB
    # must be initialized. The native app DB is created by install.sh above.
    # The Docker container DB needs separate initialization if Docker testing
    # is configured in the manifest.
    local HAS_DOCKERFILE=$(python3 -c "import json,os; d=json.load(open('$MANIFEST')); print('true' if os.path.exists(os.path.join('$PROJECT_DIR','Dockerfile')) else 'false')" 2>/dev/null)
    if [[ "$HAS_DOCKERFILE" == "true" ]]; then
        echo "  Dockerfile detected — Docker container DB will be initialized by Phase D"
    fi

    echo ""
}
```

## Shutdown VM (Called during Phase C Cleanup)

```bash
shutdown_test_vm() {
    local PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
    local STATE_FILE="${PROJECT_DIR}/.test-vm-state"

    echo ""
    echo "───────────────────────────────────────────────────────────────────"
    echo "  VM Lifecycle Cleanup"
    echo "───────────────────────────────────────────────────────────────────"
    echo ""

    # Check if state file exists
    if [[ ! -f "$STATE_FILE" ]]; then
        echo "  ✓ No VM was managed by /test (no state file)"
        return 0
    fi

    # Read state file
    local VM_NAME=$(grep "^vm_name=" "$STATE_FILE" | cut -d= -f2)
    local STARTED_BY_TEST=$(grep "^started_by_test=" "$STATE_FILE" | cut -d= -f2)
    local ORIGINAL_STATE=$(grep "^original_state=" "$STATE_FILE" | cut -d= -f2)
    local PRE_TEST_SNAPSHOT=$(grep "^pre_test_snapshot=" "$STATE_FILE" | cut -d= -f2)

    echo "  VM: $VM_NAME"
    echo "  Started by /test: $STARTED_BY_TEST"
    echo "  Original State: $ORIGINAL_STATE"
    echo "  Pre-test Snapshot: ${PRE_TEST_SNAPSHOT:-none}"
    echo ""

    # Restore VM to pristine state (MANDATORY after testing)
    # Check vm-test-manifest.json for project-specific pristine snapshot
    local PRISTINE_SNAP=""
    local POST_TEST_RESTORE="false"
    if [[ -f "${PROJECT_DIR}/vm-test-manifest.json" ]]; then
        PRISTINE_SNAP=$(python3 -c "import json; d=json.load(open('${PROJECT_DIR}/vm-test-manifest.json')); print(d.get('vm_testing',{}).get('pristine_snapshot',''))" 2>/dev/null)
        POST_TEST_RESTORE=$(python3 -c "import json; d=json.load(open('${PROJECT_DIR}/vm-test-manifest.json')); print(str(d.get('vm_testing',{}).get('post_test_restore', False)).lower())" 2>/dev/null)
    fi

    if [[ "$POST_TEST_RESTORE" == "true" && -n "$PRISTINE_SNAP" ]]; then
        echo "  📸 Reverting to pristine snapshot: $PRISTINE_SNAP"
        echo "     (post_test_restore=true — DISCARD all test changes, shut down)"

        # Force stop VM
        sudo virsh destroy "$VM_NAME" 2>/dev/null || true

        # For external snapshots: DISCARD overlay (do NOT commit — that bakes
        # test changes into the base). Repoint VM to clean base, recreate snapshot.
        local OVERLAY="/hddRaid1/VirtualMachines/${VM_NAME}.${PRISTINE_SNAP}"
        local BASE="/hddRaid1/VirtualMachines/${VM_NAME}.qcow2"

        if [[ -f "$OVERLAY" ]]; then
            # Delete snapshot metadata first
            sudo virsh snapshot-delete "$VM_NAME" "$PRISTINE_SNAP" --metadata 2>/dev/null
            # Repoint VM directly to base image (discards overlay)
            sudo virt-xml "$VM_NAME" --edit target=vda --disk path="$BASE" 2>/dev/null
            # Fix circular backingStore refs that virt-xml sometimes leaves
            sudo virsh dumpxml "$VM_NAME" > /tmp/vm-fix.xml
            python3 -c "
import xml.etree.ElementTree as ET
tree = ET.parse('/tmp/vm-fix.xml')
for disk in tree.getroot().iter('disk'):
    for bs in disk.findall('backingStore'):
        disk.remove(bs)
tree.write('/tmp/vm-fix.xml', xml_declaration=True)
"
            sudo virsh define /tmp/vm-fix.xml 2>/dev/null
            rm -f /tmp/vm-fix.xml
            # Remove overlay file (all test changes discarded)
            sudo rm -f "$OVERLAY"
            echo "  ✅ Overlay discarded — base image is pristine"
            # Recreate pristine snapshot for next test run
            sudo virsh snapshot-create-as "$VM_NAME" "$PRISTINE_SNAP" \
                "Pristine OS with dependencies. No application installed." --disk-only 2>/dev/null
            echo "  ✅ Pristine snapshot recreated"
        else
            # Fallback: try internal snapshot revert
            if sudo virsh snapshot-revert "$VM_NAME" "$PRISTINE_SNAP" 2>/dev/null; then
                echo "  ✅ Reverted to pristine snapshot"
            else
                echo "  ❌ Failed to restore pristine state"
                echo "     Manual cleanup may be needed"
            fi
        fi

        # VM is now shut down and pristine — leave it that way
        echo "  ✅ VM left shut down and pristine (ready for next test run)"
        rm -f "$STATE_FILE"
        echo "  📝 Removed state file: $STATE_FILE"
        echo ""
        return 0
    elif [[ -n "$PRE_TEST_SNAPSHOT" ]]; then
        echo "  📸 Reverting to pre-test snapshot: $PRE_TEST_SNAPSHOT"

        # Must destroy running VM before reverting
        sudo virsh destroy "$VM_NAME" 2>/dev/null || true

        if sudo virsh snapshot-revert "$VM_NAME" "$PRE_TEST_SNAPSHOT" 2>/dev/null; then
            echo "  ✅ Reverted to pre-test state"

            # Delete the temporary pre-test snapshot
            echo "  🗑️  Deleting temporary snapshot..."
            if sudo virsh snapshot-delete "$VM_NAME" "$PRE_TEST_SNAPSHOT" 2>/dev/null; then
                echo "  ✅ Pre-test snapshot deleted"
            else
                echo "  ⚠️ Failed to delete snapshot (cleanup manually)"
            fi
        else
            echo "  ❌ Failed to revert to pre-test snapshot"
            echo "     VM may have accumulated test artifacts"
        fi
    fi
    echo ""

    # Only shutdown if we started it
    if [[ "$STARTED_BY_TEST" != "true" ]]; then
        echo "  ✓ VM was already running - leaving it running"
        echo "    (VM was not started by /test)"
        rm -f "$STATE_FILE"
        return 0
    fi

    # Check if VM is still running
    local CURRENT_STATE=$(virsh domstate "$VM_NAME" 2>/dev/null | tr -d '[:space:]')

    if [[ "$CURRENT_STATE" != "running" ]]; then
        echo "  ✓ VM already stopped"
        rm -f "$STATE_FILE"
        return 0
    fi

    echo "  Shutting down VM to preserve system resources..."

    # Try graceful shutdown first
    echo "  Attempting graceful shutdown..."
    sudo virsh shutdown "$VM_NAME" 2>/dev/null

    # Wait for shutdown (max 60 seconds)
    local WAIT_COUNT=0
    while [[ $WAIT_COUNT -lt 12 ]]; do
        sleep 5
        CURRENT_STATE=$(virsh domstate "$VM_NAME" 2>/dev/null | tr -d '[:space:]')
        if [[ "$CURRENT_STATE" != "running" ]]; then
            echo "  ✅ VM shut down gracefully"
            rm -f "$STATE_FILE"
            return 0
        fi
        ((WAIT_COUNT++))
        echo "    Waiting... ($((WAIT_COUNT * 5))s)"
    done

    # Force stop if graceful didn't work
    echo "  ⚠️ Graceful shutdown timeout - forcing stop..."
    sudo virsh destroy "$VM_NAME" 2>/dev/null

    if [[ $? -eq 0 ]]; then
        echo "  ✅ VM force stopped"
    else
        echo "  ❌ Failed to stop VM - may need manual intervention"
        echo "     Run: sudo virsh destroy $VM_NAME"
    fi

    # Clean up state file
    rm -f "$STATE_FILE"
    echo ""
    echo "  📝 Removed state file: $STATE_FILE"
    echo ""

    # Summary
    echo "VM Cleanup Complete:"
    echo "  - VM $VM_NAME stopped"
    echo "  - System resources freed (4GB RAM, 4 vCPUs)"
}
```

## Integration Points

### After Phase 1 (Discovery) Completes

The dispatcher should call `start_test_vm` when:
1. Discovery determines `ISOLATION_LEVEL` is `vm-required` or `vm-recommended`
2. Phase 0 detected `VM_AVAILABLE=true`

```
# In dispatcher, after Discovery completes:
if [[ "$ISOLATION_LEVEL" =~ ^vm-(required|recommended)$ ]] && [[ "$VM_AVAILABLE" == "true" ]]; then
    # Load and execute VM startup
    source ~/.claude/skills/test-phases/phase-VM-lifecycle.md
    start_test_vm
fi
```

### During Phase C (Cleanup)

Phase C should call `shutdown_test_vm` to clean up:

```
# In Phase C cleanup:
source ~/.claude/skills/test-phases/phase-VM-lifecycle.md
shutdown_test_vm
```

## State File Format

`.test-vm-state` contains:
```
vm_name=test-vm-cachyos
started_by_test=true
original_state=shutoff
isolation_level=vm-required
start_time=2026-02-18T15:30:00-05:00
vm_ip=192.168.122.45
vnc_port=5900
pre_test_snapshot=pre-test-20260218-153000
```

## Report Format

### Startup Report
```
═══════════════════════════════════════════════════════════════════
  VM LIFECYCLE: STARTUP
═══════════════════════════════════════════════════════════════════

  Isolation Level: vm-required
  VM isolation required/recommended

  Selected VM: test-vm-cachyos
  Current State: shutoff
  Reverting to pristine snapshot...
  Starting VM...
  ✅ VM started successfully
  Waiting for VM to boot (30s)...

  📝 State saved to: .test-vm-state
  🌐 VM IP: 192.168.122.45
  🖥️  VNC: 127.0.0.1:5900

  📸 Creating pre-test snapshot: pre-test-20260218-153000
  ✅ Pre-test snapshot created

───────────────────────────────────────────────────────────────────
  VM READY FOR TESTING
───────────────────────────────────────────────────────────────────

VM Name: test-vm-cachyos
Started by /test: true
State File: .test-vm-state
Pre-test Snapshot: pre-test-20260218-153000
```

### Cleanup Report
```
───────────────────────────────────────────────────────────────────
  VM Lifecycle Cleanup
───────────────────────────────────────────────────────────────────

  VM: test-vm-cachyos
  Started by /test: true
  Original State: shutoff
  Pre-test Snapshot: pre-test-20260218-153000

  📸 Reverting to pre-test snapshot: pre-test-20260218-153000
  ✅ Reverted to pre-test state
  🗑️  Deleting temporary snapshot...
  ✅ Pre-test snapshot deleted

  Shutting down VM to preserve system resources...
  Attempting graceful shutdown...
    Waiting... (5s)
    Waiting... (10s)
  ✅ VM shut down gracefully

  📝 Removed state file: .test-vm-state

VM Cleanup Complete:
  - VM test-vm-cachyos restored to pristine state
  - VM test-vm-cachyos stopped
  - System resources freed (4GB RAM, 4 vCPUs)
```

## Manual Override

To keep the VM running after /test completes:
```bash
# Before running /test:
export TEST_KEEP_VM_RUNNING=true

# Or add to vm-test-manifest.json:
{
  "vm_testing": {
    "keep_running_after_test": true
  }
}
```
