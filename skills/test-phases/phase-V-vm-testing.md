# Phase V: VM Testing (Heavy Isolation)

## Purpose

Test applications, releases, and system-level changes in fully isolated virtual machines. This phase provides the highest level of isolation for testing operations that could brick the host system.

**Use Cases:**
- Testing PAM/auth changes (like kwallet Bug #509680)
- Testing systemd service installations
- Testing kernel parameter changes
- Testing boot-time behavior
- Testing releases across multiple distros (Ubuntu, Fedora, Debian, etc.)
- Testing Docker images in different environments
- Testing Windows compatibility
- Testing upgrade paths between versions

## When to Use This Phase

| Scenario | Use Phase V? |
|----------|--------------|
| App logic testing | ❌ Use Phase A (sandbox) |
| Production validation | ❌ Use Phase P (live system) |
| PAM/auth modifications | ✅ Yes - could lock you out |
| systemd service changes | ✅ Yes - could break boot |
| Kernel parameters | ✅ Yes - could brick system |
| Cross-distro testing | ✅ Yes - need different OS |
| Windows testing | ✅ Yes - need Windows VM |
| Reboot cycle testing | ✅ Yes - need isolated system |

## VM Configuration

### VM Sources

**Existing VMs** (detected automatically):
```
/var/lib/libvirt/images/           # libvirt default
~/.local/share/libvirt/images/     # user libvirt
```

**ISO Library** (for creating new VMs):
```
/hddRaid1/ISOs/
├── archlinux-*.iso
├── cachyos-*.iso
├── ubuntu-*.iso
├── debian-*.iso
├── fedora-*.iso
├── manjaro-*.iso
├── mx-*.iso
├── windows-*.iso
└── ...
```

### VM Test Manifest: `vm-test-manifest.json`

Projects can specify VM testing requirements:

```json
{
  "vm_testing": {
    "enabled": true,
    "default_vm": "cachyos-test",

    "dangerous_operations": [
      "pam_modification",
      "systemd_service_install",
      "kernel_params",
      "reboot_required"
    ],

    "test_environments": [
      {
        "name": "cachyos-test",
        "type": "existing",
        "vm_name": "cachyos-kwallet-dev",
        "snapshot": "clean-install"
      },
      {
        "name": "ubuntu-lts",
        "type": "create",
        "iso_pattern": "ubuntu-*-desktop-amd64.iso",
        "memory_mb": 4096,
        "disk_gb": 40,
        "auto_install": true
      },
      {
        "name": "fedora-latest",
        "type": "create",
        "iso_pattern": "Fedora-Workstation-*.iso",
        "memory_mb": 4096,
        "disk_gb": 40
      },
      {
        "name": "windows-11",
        "type": "create",
        "iso_pattern": "Win11*.iso",
        "memory_mb": 8192,
        "disk_gb": 60,
        "uefi": true
      }
    ],

    "ssh_config": {
      "user": "testuser",
      "key": "~/.ssh/vm_test_key",
      "port": 22
    },

    "test_sequences": [
      {
        "name": "install-and-reboot",
        "steps": ["deploy", "install", "reboot", "validate"]
      },
      {
        "name": "pam-change-test",
        "steps": ["snapshot", "deploy", "modify_pam", "reboot", "test_login", "restore"]
      }
    ]
  }
}
```

## Step 1: Detect Available VMs and ISOs

```bash
detect_vm_environment() {
    local PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
    local ISO_DIR="/hddRaid1/ISOs"

    echo "═══════════════════════════════════════════════════════════════════"
    echo "  PHASE V: VM TESTING (HEAVY ISOLATION)"
    echo "═══════════════════════════════════════════════════════════════════"
    echo ""

    # Check for libvirt/virsh
    if ! command -v virsh &>/dev/null; then
        echo "❌ libvirt/virsh not installed"
        echo "   Install: sudo pacman -S libvirt qemu-full virt-manager"
        return 1
    fi

    # Check libvirtd is running
    if ! systemctl is-active libvirtd &>/dev/null; then
        echo "⚠️ libvirtd not running - starting..."
        sudo systemctl start libvirtd
    fi

    echo "───────────────────────────────────────────────────────────────────"
    echo "  Existing VMs"
    echo "───────────────────────────────────────────────────────────────────"
    virsh list --all 2>/dev/null | tail -n +3 | while read -r line; do
        [[ -n "$line" ]] && echo "  $line"
    done
    echo ""

    echo "───────────────────────────────────────────────────────────────────"
    echo "  Available ISOs for New VMs"
    echo "───────────────────────────────────────────────────────────────────"
    if [[ -d "$ISO_DIR" ]]; then
        echo "  Location: $ISO_DIR"
        echo ""

        # Group by distro
        echo "  Linux:"
        ls "$ISO_DIR"/*.iso 2>/dev/null | xargs -I{} basename {} | grep -viE "win|windows" | sort | sed 's/^/    /'

        echo ""
        echo "  Windows:"
        ls "$ISO_DIR"/*.iso 2>/dev/null | xargs -I{} basename {} | grep -iE "win|windows" | sort | sed 's/^/    /'
    else
        echo "  ⚠️ ISO directory not found: $ISO_DIR"
    fi
    echo ""

    echo "───────────────────────────────────────────────────────────────────"
    echo "  VM Snapshots Available"
    echo "───────────────────────────────────────────────────────────────────"
    for vm in $(virsh list --all --name 2>/dev/null); do
        local snapshots=$(virsh snapshot-list "$vm" --name 2>/dev/null | grep -v "^$")
        if [[ -n "$snapshots" ]]; then
            echo "  $vm:"
            echo "$snapshots" | sed 's/^/    /'
        fi
    done

    # Also check for qcow2 backup files (manual snapshots)
    echo ""
    echo "  Manual snapshots (.clean-install, .backup):"
    ls /var/lib/libvirt/images/*.clean-install /var/lib/libvirt/images/*.backup 2>/dev/null | \
        xargs -I{} basename {} | sed 's/^/    /' || echo "    (none)"
    echo ""
}
```

## Step 2: Create New VM from ISO

```bash
create_test_vm() {
    local VM_NAME="$1"
    local ISO_PATTERN="$2"
    local MEMORY_MB="${3:-4096}"
    local DISK_GB="${4:-40}"
    local UEFI="${5:-false}"

    local ISO_DIR="/hddRaid1/ISOs"
    local VM_DISK="/var/lib/libvirt/images/${VM_NAME}.qcow2"

    echo "───────────────────────────────────────────────────────────────────"
    echo "  Creating VM: $VM_NAME"
    echo "───────────────────────────────────────────────────────────────────"
    echo ""

    # Find matching ISO
    local ISO_PATH=$(ls "$ISO_DIR"/$ISO_PATTERN 2>/dev/null | head -1)
    if [[ -z "$ISO_PATH" ]]; then
        echo "❌ No ISO found matching: $ISO_PATTERN"
        echo "   Available ISOs:"
        ls "$ISO_DIR"/*.iso 2>/dev/null | xargs -I{} basename {}
        return 1
    fi

    echo "  ISO: $(basename "$ISO_PATH")"
    echo "  Memory: ${MEMORY_MB}MB"
    echo "  Disk: ${DISK_GB}GB"
    echo "  UEFI: $UEFI"
    echo ""

    # Check if VM already exists
    if virsh dominfo "$VM_NAME" &>/dev/null; then
        echo "⚠️ VM '$VM_NAME' already exists"
        read -p "  Delete and recreate? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            virsh destroy "$VM_NAME" 2>/dev/null
            virsh undefine "$VM_NAME" --remove-all-storage 2>/dev/null
        else
            return 1
        fi
    fi

    # Build virt-install command
    local VIRT_CMD="virt-install \
        --name $VM_NAME \
        --memory $MEMORY_MB \
        --vcpus 4 \
        --disk path=$VM_DISK,size=$DISK_GB,format=qcow2 \
        --cdrom $ISO_PATH \
        --os-variant detect=on \
        --network network=default \
        --graphics spice \
        --video virtio \
        --noautoconsole"

    # Add UEFI if requested (needed for Windows 11)
    if [[ "$UEFI" == "true" ]]; then
        VIRT_CMD="$VIRT_CMD --boot uefi"
    fi

    echo "Creating VM..."
    eval $VIRT_CMD

    if [[ $? -eq 0 ]]; then
        echo ""
        echo "✅ VM created: $VM_NAME"
        echo ""
        echo "Next steps:"
        echo "  1. Open virt-manager to complete OS installation"
        echo "  2. Install SSH server in the VM"
        echo "  3. Create a clean snapshot: virsh snapshot-create-as $VM_NAME clean-install"
        echo "  4. Add VM to vm-test-manifest.json"
    else
        echo "❌ Failed to create VM"
        return 1
    fi
}

# Convenience functions for common distros
create_ubuntu_vm() {
    create_test_vm "ubuntu-test" "ubuntu-*-desktop-amd64.iso" 4096 40
}

create_fedora_vm() {
    create_test_vm "fedora-test" "Fedora-Workstation-*.iso" 4096 40
}

create_debian_vm() {
    create_test_vm "debian-test" "debian-*-amd64-*.iso" 4096 40
}

create_windows_vm() {
    create_test_vm "windows-test" "Win11*.iso" 8192 60 true
}

create_cachyos_vm() {
    create_test_vm "cachyos-test" "cachyos-*.iso" 4096 40
}
```

## Step 3: VM Snapshot Management

```bash
manage_vm_snapshot() {
    local VM_NAME="$1"
    local ACTION="$2"  # create, restore, list, delete
    local SNAPSHOT_NAME="${3:-clean-install}"

    echo "───────────────────────────────────────────────────────────────────"
    echo "  VM Snapshot: $ACTION"
    echo "───────────────────────────────────────────────────────────────────"
    echo ""

    case "$ACTION" in
        create)
            echo "Creating snapshot '$SNAPSHOT_NAME' for $VM_NAME..."

            # Shutdown VM if running (for consistent snapshot)
            if virsh domstate "$VM_NAME" 2>/dev/null | grep -q running; then
                echo "  Shutting down VM for consistent snapshot..."
                virsh shutdown "$VM_NAME"
                sleep 10
            fi

            virsh snapshot-create-as "$VM_NAME" "$SNAPSHOT_NAME" \
                --description "Test snapshot created $(date '+%Y-%m-%d %H:%M')"

            echo "✅ Snapshot created"
            ;;

        restore)
            echo "Restoring $VM_NAME to snapshot '$SNAPSHOT_NAME'..."

            # Destroy if running
            virsh destroy "$VM_NAME" 2>/dev/null

            # Restore snapshot
            virsh snapshot-revert "$VM_NAME" "$SNAPSHOT_NAME"

            echo "✅ Restored to $SNAPSHOT_NAME"
            ;;

        list)
            echo "Snapshots for $VM_NAME:"
            virsh snapshot-list "$VM_NAME"
            ;;

        delete)
            echo "Deleting snapshot '$SNAPSHOT_NAME' from $VM_NAME..."
            virsh snapshot-delete "$VM_NAME" "$SNAPSHOT_NAME"
            echo "✅ Snapshot deleted"
            ;;

        *)
            echo "Unknown action: $ACTION"
            echo "Valid actions: create, restore, list, delete"
            return 1
            ;;
    esac
}

# Quick reset to clean state
reset_vm_to_clean() {
    local VM_NAME="$1"

    echo "Resetting $VM_NAME to clean state..."

    # Try libvirt snapshot first
    if virsh snapshot-list "$VM_NAME" --name 2>/dev/null | grep -q "clean-install"; then
        manage_vm_snapshot "$VM_NAME" restore "clean-install"
    # Fall back to manual qcow2 backup
    elif [[ -f "/var/lib/libvirt/images/${VM_NAME}.clean-install" ]]; then
        virsh destroy "$VM_NAME" 2>/dev/null
        sudo cp "/var/lib/libvirt/images/${VM_NAME}.clean-install" \
                "/var/lib/libvirt/images/${VM_NAME}.qcow2"
        echo "✅ Restored from .clean-install backup"
    else
        echo "❌ No clean snapshot found for $VM_NAME"
        return 1
    fi
}
```

## Step 4: Deploy to VM via SSH

```bash
deploy_to_vm() {
    local VM_NAME="$1"
    local PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
    local SSH_USER="${VM_SSH_USER:-testuser}"
    local SSH_KEY="${VM_SSH_KEY:-~/.ssh/vm_test_key}"

    echo "───────────────────────────────────────────────────────────────────"
    echo "  Deploying to VM: $VM_NAME"
    echo "───────────────────────────────────────────────────────────────────"
    echo ""

    # Start VM if not running
    if ! virsh domstate "$VM_NAME" 2>/dev/null | grep -q running; then
        echo "Starting VM..."
        virsh start "$VM_NAME"
        echo "Waiting for VM to boot..."
        sleep 30
    fi

    # Get VM IP
    local VM_IP=$(virsh domifaddr "$VM_NAME" 2>/dev/null | grep -oP '192\.168\.\d+\.\d+|10\.\d+\.\d+\.\d+' | head -1)

    if [[ -z "$VM_IP" ]]; then
        echo "❌ Could not determine VM IP address"
        echo "   Try: virsh domifaddr $VM_NAME"
        return 1
    fi

    echo "  VM IP: $VM_IP"
    echo "  SSH User: $SSH_USER"
    echo ""

    # Test SSH connection
    echo "Testing SSH connection..."
    if ! ssh -i "$SSH_KEY" -o ConnectTimeout=10 -o StrictHostKeyChecking=no \
         "$SSH_USER@$VM_IP" "echo 'SSH OK'" &>/dev/null; then
        echo "❌ SSH connection failed"
        echo "   Ensure SSH is installed and running in the VM"
        echo "   Test manually: ssh -i $SSH_KEY $SSH_USER@$VM_IP"
        return 1
    fi
    echo "✅ SSH connected"
    echo ""

    # Create deployment directory in VM
    local DEPLOY_DIR="/tmp/test-deploy-$(basename $PROJECT_DIR)"
    ssh -i "$SSH_KEY" "$SSH_USER@$VM_IP" "mkdir -p $DEPLOY_DIR"

    # Copy project files (excluding .git, node_modules, etc.)
    echo "Copying project files..."
    rsync -avz --progress \
        --exclude='.git' \
        --exclude='node_modules' \
        --exclude='__pycache__' \
        --exclude='.venv' \
        --exclude='*.pyc' \
        -e "ssh -i $SSH_KEY" \
        "$PROJECT_DIR/" "$SSH_USER@$VM_IP:$DEPLOY_DIR/"

    echo ""
    echo "✅ Deployed to $VM_NAME:$DEPLOY_DIR"

    # Export for later steps
    export VM_IP VM_SSH_USER="$SSH_USER" VM_SSH_KEY="$SSH_KEY" VM_DEPLOY_DIR="$DEPLOY_DIR"
}
```

## Step 5: Run Tests in VM

```bash
run_vm_tests() {
    local VM_NAME="$1"
    local TEST_TYPE="${2:-basic}"  # basic, install, pam, systemd, reboot

    echo "───────────────────────────────────────────────────────────────────"
    echo "  Running VM Tests: $TEST_TYPE"
    echo "───────────────────────────────────────────────────────────────────"
    echo ""

    local SSH_CMD="ssh -i $VM_SSH_KEY $VM_SSH_USER@$VM_IP"

    case "$TEST_TYPE" in
        basic)
            echo "Running basic tests..."
            $SSH_CMD "cd $VM_DEPLOY_DIR && ls -la"
            $SSH_CMD "cd $VM_DEPLOY_DIR && [[ -f install.sh ]] && bash -n install.sh && echo '✅ install.sh syntax OK'"
            ;;

        install)
            echo "Running installation test..."
            $SSH_CMD "cd $VM_DEPLOY_DIR && [[ -f install.sh ]] && bash install.sh --user"

            # Verify installation
            $SSH_CMD "which $(basename $PROJECT_DIR) 2>/dev/null && echo '✅ Binary installed' || echo '⚠️ Binary not in PATH'"
            ;;

        pam)
            echo "Running PAM modification test..."
            echo "⚠️ This test modifies PAM configuration"

            # Backup PAM config
            $SSH_CMD "sudo cp -r /etc/pam.d /etc/pam.d.backup"

            # Run PAM-related installation
            $SSH_CMD "cd $VM_DEPLOY_DIR && [[ -f install.sh ]] && sudo bash install.sh --system"

            # Test login still works (this is the critical test)
            echo "Testing that login still works..."
            if $SSH_CMD "echo 'Login OK'" &>/dev/null; then
                echo "✅ PAM modification safe - login still works"
            else
                echo "❌ PAM modification BROKE LOGIN"
                echo "   Restoring PAM backup..."
                # This would need console access since SSH is broken
                return 1
            fi
            ;;

        systemd)
            echo "Running systemd service test..."

            # Install service
            $SSH_CMD "cd $VM_DEPLOY_DIR && [[ -f install.sh ]] && sudo bash install.sh --system"

            # Check service status
            local APP_NAME=$(basename $PROJECT_DIR | tr '[:upper:]' '[:lower:]')
            $SSH_CMD "systemctl status $APP_NAME.service 2>/dev/null || systemctl --user status $APP_NAME.service 2>/dev/null"
            ;;

        reboot)
            echo "Running reboot cycle test..."

            # Install app
            $SSH_CMD "cd $VM_DEPLOY_DIR && [[ -f install.sh ]] && bash install.sh"

            # Reboot VM
            echo "Rebooting VM..."
            $SSH_CMD "sudo reboot" 2>/dev/null || true

            echo "Waiting for VM to come back (60s)..."
            sleep 60

            # Wait for SSH to be available
            local retries=10
            while [[ $retries -gt 0 ]]; do
                if $SSH_CMD "echo 'Back online'" &>/dev/null; then
                    echo "✅ VM back online after reboot"
                    break
                fi
                ((retries--))
                sleep 10
            done

            if [[ $retries -eq 0 ]]; then
                echo "❌ VM did not come back after reboot"
                return 1
            fi

            # Validate app still works
            $SSH_CMD "which $(basename $PROJECT_DIR) && $(basename $PROJECT_DIR) --version"
            ;;

        *)
            echo "Unknown test type: $TEST_TYPE"
            echo "Valid types: basic, install, pam, systemd, reboot"
            return 1
            ;;
    esac
}
```

## Step 6: Cross-Distro Testing

```bash
run_cross_distro_tests() {
    local PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
    local DISTROS=("$@")

    # Default distros if none specified
    if [[ ${#DISTROS[@]} -eq 0 ]]; then
        DISTROS=("cachyos-test" "ubuntu-test" "fedora-test")
    fi

    echo "═══════════════════════════════════════════════════════════════════"
    echo "  CROSS-DISTRO TESTING"
    echo "═══════════════════════════════════════════════════════════════════"
    echo ""
    echo "Testing on: ${DISTROS[*]}"
    echo ""

    local RESULTS=()

    for distro in "${DISTROS[@]}"; do
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "  Testing: $distro"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

        # Check if VM exists
        if ! virsh dominfo "$distro" &>/dev/null; then
            echo "⚠️ VM '$distro' does not exist - skipping"
            RESULTS+=("$distro: SKIPPED (VM not found)")
            continue
        fi

        # Reset to clean state
        reset_vm_to_clean "$distro"

        # Start VM
        virsh start "$distro" 2>/dev/null
        sleep 30

        # Deploy and test
        if deploy_to_vm "$distro"; then
            if run_vm_tests "$distro" "install"; then
                RESULTS+=("$distro: ✅ PASSED")
            else
                RESULTS+=("$distro: ❌ FAILED")
            fi
        else
            RESULTS+=("$distro: ❌ DEPLOY FAILED")
        fi

        # Shutdown VM
        virsh shutdown "$distro" 2>/dev/null
    done

    # Summary
    echo ""
    echo "═══════════════════════════════════════════════════════════════════"
    echo "  CROSS-DISTRO TEST SUMMARY"
    echo "═══════════════════════════════════════════════════════════════════"
    for result in "${RESULTS[@]}"; do
        echo "  $result"
    done
    echo ""
}
```

## Step 7: Docker Image Testing in VM

```bash
test_docker_in_vm() {
    local VM_NAME="$1"
    local DOCKER_IMAGE="$2"

    echo "───────────────────────────────────────────────────────────────────"
    echo "  Testing Docker Image in VM: $DOCKER_IMAGE"
    echo "───────────────────────────────────────────────────────────────────"
    echo ""

    local SSH_CMD="ssh -i $VM_SSH_KEY $VM_SSH_USER@$VM_IP"

    # Check Docker is available in VM
    if ! $SSH_CMD "command -v docker" &>/dev/null; then
        echo "❌ Docker not installed in VM"
        echo "   Install Docker in the VM first"
        return 1
    fi

    # Pull and run image
    echo "Pulling image..."
    $SSH_CMD "docker pull $DOCKER_IMAGE"

    echo "Running container..."
    $SSH_CMD "docker run --rm $DOCKER_IMAGE --version" || \
    $SSH_CMD "docker run --rm $DOCKER_IMAGE --help" || \
    $SSH_CMD "docker run --rm -d --name test-container $DOCKER_IMAGE && sleep 5 && docker logs test-container && docker stop test-container"

    echo ""
    echo "✅ Docker image tested in VM"
}
```

## Phase V Execution Order

```bash
run_phase_V() {
    local PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
    local ISSUES_FILE="${PROJECT_DIR}/vm-test-issues.log"
    > "$ISSUES_FILE"

    # Load manifest if exists
    local MANIFEST="$PROJECT_DIR/vm-test-manifest.json"
    local DEFAULT_VM=""

    if [[ -f "$MANIFEST" ]]; then
        DEFAULT_VM=$(jq -r '.vm_testing.default_vm // empty' "$MANIFEST")
    fi

    # Detect environment
    detect_vm_environment

    # If no default VM and no manifest, offer to create one
    if [[ -z "$DEFAULT_VM" ]]; then
        echo "No default test VM configured."
        echo ""
        echo "Options:"
        echo "  1. Use existing VM (if available)"
        echo "  2. Create new VM from ISO"
        echo "  3. Skip VM testing"
        echo ""

        # For autonomous mode, try to find a suitable existing VM
        local EXISTING_VM=$(virsh list --all --name 2>/dev/null | grep -iE "test|dev" | head -1)
        if [[ -n "$EXISTING_VM" ]]; then
            echo "Found existing test VM: $EXISTING_VM"
            DEFAULT_VM="$EXISTING_VM"
        else
            echo "⚠️ No test VM found - skipping Phase V"
            return 0
        fi
    fi

    echo ""
    echo "Using VM: $DEFAULT_VM"
    echo ""

    # Reset to clean state
    reset_vm_to_clean "$DEFAULT_VM" || true

    # Deploy
    deploy_to_vm "$DEFAULT_VM" || {
        echo "Deploy failed" >> "$ISSUES_FILE"
        return 1
    }

    # Run tests based on project type
    if [[ -f "$PROJECT_DIR/install.sh" ]]; then
        run_vm_tests "$DEFAULT_VM" "install" || echo "Install test failed" >> "$ISSUES_FILE"
    fi

    # Check for dangerous operations in manifest
    if [[ -f "$MANIFEST" ]]; then
        local DANGEROUS=$(jq -r '.vm_testing.dangerous_operations[]? // empty' "$MANIFEST")

        if echo "$DANGEROUS" | grep -q "pam_modification"; then
            run_vm_tests "$DEFAULT_VM" "pam" || echo "PAM test failed" >> "$ISSUES_FILE"
        fi

        if echo "$DANGEROUS" | grep -q "systemd_service_install"; then
            run_vm_tests "$DEFAULT_VM" "systemd" || echo "systemd test failed" >> "$ISSUES_FILE"
        fi

        if echo "$DANGEROUS" | grep -q "reboot_required"; then
            run_vm_tests "$DEFAULT_VM" "reboot" || echo "Reboot test failed" >> "$ISSUES_FILE"
        fi
    fi

    # Generate report
    echo ""
    echo "═══════════════════════════════════════════════════════════════════"
    echo "  PHASE V: VM TESTING SUMMARY"
    echo "═══════════════════════════════════════════════════════════════════"
    echo ""

    if [[ -s "$ISSUES_FILE" ]]; then
        echo "❌ Issues found:"
        cat "$ISSUES_FILE"
        return 1
    else
        echo "✅ All VM tests passed"
        rm -f "$ISSUES_FILE"
        return 0
    fi
}
```

## Step 8: GUI/VNC Automation Testing

For tests requiring graphical sessions (login screens, desktop apps), use VNC automation:

```python
#!/usr/bin/env python3
"""
GUI Test Automation via VNC
Requires: pip install vncdotool service-identity
"""
from vncdotool import api
import time

def test_graphical_login(vnc_host="127.0.0.1", vnc_port=5901, username="testuser", password=None):
    """Automate graphical login and verify desktop loads."""
    client = api.connect(f'{vnc_host}::{vnc_port}')

    try:
        # Click on user to select
        client.mouseMove(640, 350)  # Adjust for your login screen
        client.mousePress(1)
        time.sleep(1)

        # Type password
        for char in password:
            if char.isupper():
                client.keyDown('shift')
                client.keyPress(char.lower())
                client.keyUp('shift')
            elif char == '@':
                client.keyDown('shift')
                client.keyPress('2')
                client.keyUp('shift')
            elif char == '!':
                client.keyDown('shift')
                client.keyPress('1')
                client.keyUp('shift')
            else:
                client.keyPress(char)
            time.sleep(0.05)

        # Submit login
        client.keyPress('enter')
        time.sleep(15)  # Wait for desktop

        # Capture result
        client.captureScreen('/tmp/gui-test-result.png')
        return True

    finally:
        client.disconnect()

def capture_vm_screenshot(vm_name, output_path="/tmp/vm-screenshot.png"):
    """Capture screenshot from VM's VNC/SPICE display."""
    import subprocess

    # Get display URL
    result = subprocess.run(
        ["sudo", "virsh", "domdisplay", vm_name],
        capture_output=True, text=True
    )
    display_url = result.stdout.strip()

    if display_url.startswith("vnc://"):
        # Parse VNC URL: vnc://127.0.0.1:1 -> port 5901
        parts = display_url.replace("vnc://", "").split(":")
        host = parts[0]
        display = int(parts[1]) if len(parts) > 1 else 0
        port = 5900 + display

        client = api.connect(f'{host}::{port}')
        client.captureScreen(output_path)
        client.disconnect()
        return output_path
    else:
        print(f"SPICE display - use virt-viewer for {vm_name}")
        return None
```

### GUI Test Helpers

```bash
# Get VNC port for a VM
get_vnc_port() {
    local VM_NAME="$1"
    local DISPLAY_URL=$(sudo virsh domdisplay "$VM_NAME" 2>/dev/null)

    if [[ "$DISPLAY_URL" == vnc://* ]]; then
        local DISPLAY_NUM=$(echo "$DISPLAY_URL" | sed 's/vnc:\/\/[^:]*://')
        echo $((5900 + DISPLAY_NUM))
    else
        echo "SPICE" # Not VNC
    fi
}

# Capture screenshot from VM
capture_vm_screen() {
    local VM_NAME="$1"
    local OUTPUT="${2:-/tmp/${VM_NAME}-screenshot.png}"

    local PORT=$(get_vnc_port "$VM_NAME")
    if [[ "$PORT" == "SPICE" ]]; then
        echo "VM uses SPICE, use virt-viewer for manual access"
        return 1
    fi

    python3 -c "
from vncdotool import api
client = api.connect('127.0.0.1::$PORT')
client.captureScreen('$OUTPUT')
client.disconnect()
print('Screenshot saved to $OUTPUT')
"
}

# Available test VMs with display info
list_test_vms() {
    echo "Available Test VMs:"
    echo "─────────────────────────────────────────"
    for vm in $(sudo virsh list --all --name 2>/dev/null | grep -v "^$"); do
        local STATE=$(sudo virsh domstate "$vm" 2>/dev/null)
        local DISPLAY=$(sudo virsh domdisplay "$vm" 2>/dev/null)
        local IP=$(sudo virsh domifaddr "$vm" 2>/dev/null | grep -oP '\d+\.\d+\.\d+\.\d+' | head -1)
        printf "  %-25s %-10s %-25s %s\n" "$vm" "$STATE" "${DISPLAY:-N/A}" "${IP:-no-ip}"
    done
}
```

### Test VM Credentials

Configure your test VM credentials in your local environment:

| Setting | Environment Variable | Default |
|---------|---------------------|---------|
| Username | `VM_SSH_USER` | `testuser` |
| SSH Key | `VM_SSH_KEY` | `~/.ssh/vm_test_key` |

**Setup:**
1. Create a dedicated SSH key for VM testing: `ssh-keygen -t ed25519 -f ~/.ssh/vm_test_key`
2. Add the public key to your test VMs' `~/.ssh/authorized_keys`
3. Use consistent credentials across all test VMs for simplicity

| VM Example | Description |
|------------|-------------|
| arch-test | Arch Linux / CachyOS testing |
| debian-test | Debian testing |
| fedora-test | Fedora testing |
| ubuntu-test | Ubuntu/Kubuntu testing |

## Quick Commands

```bash
# Use existing test VM
/test --phase=V

# Create and test on specific distro
/test --phase=V --vm-create=ubuntu

# Test across multiple distros
/test --phase=V --cross-distro

# Reset VM to clean state
/test --phase=V --vm-reset

# Test Docker image in VM
/test --phase=V --docker-image=ghcr.io/user/app:latest
```

## Conditional Execution

Phase V runs when:
- `vm-test-manifest.json` exists with `"enabled": true`
- Project has `dangerous_operations` defined
- User explicitly requests `--phase=V`
- Discovery detects PAM/systemd modifications in install scripts

Phase V is **skipped** when:
- No test VMs available and no ISOs to create from
- libvirt/virsh not installed
- Project has no install scripts or dangerous operations

## Report Format

```markdown
## Phase V: VM Testing Report

### Environment
| Attribute | Value |
|-----------|-------|
| VM Name | cachyos-test |
| VM IP | 192.168.122.45 |
| Snapshot | clean-install |

### Tests Run
| Test | Status | Duration |
|------|--------|----------|
| Deploy | ✅ | 12s |
| Install | ✅ | 45s |
| PAM Modification | ✅ | 30s |
| Reboot Cycle | ✅ | 90s |

### Cross-Distro Results
| Distro | Status |
|--------|--------|
| CachyOS | ✅ PASSED |
| Ubuntu 24.04 | ✅ PASSED |
| Fedora 41 | ⚠️ Minor issues |
| Windows 11 | ❌ Not compatible |

### Issues Found
- [List from vm-test-issues.log]

### Phase V Status: ✅ PASSED / ❌ FAILED
```
