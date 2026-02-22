# Phase V: VM Testing (Heavy Isolation)

> **Model**: `sonnet` | **Tier**: Special (Conditional) | **Modifies Files**: VM only
> **Task Tracking**: Call `TaskUpdate(taskId, status="in_progress")` at start, `TaskUpdate(taskId, status="completed")` when done.
> **Key Tools**: `Bash` for virsh/SSH commands. Use `KillShell` to terminate hung VM operations. Use `AskUserQuestion` if VM connectivity fails and user input is needed.

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
    local VM_IP=""
    local SSH_USER="claude"
    local SSH_KEY="~/.claude/ssh/id_ed25519"
    local INSTALL_SCRIPT=""
    local UPGRADE_SCRIPT=""
    local DEPLOY_SCRIPT=""
    local API_PORT=""
    local WEB_PORT=""

    # ─── PROJECT-AWARE VM ROUTING ──────────────────────────────────
    # Load project-VM mapping (preferred over legacy manifest)
    local VM_MAP="$HOME/.claude/config/project-vm-map.json"
    local PROJECT_NAME=$(basename "$PROJECT_DIR")

    if [[ -f "$VM_MAP" ]]; then
        echo "───────────────────────────────────────────────────────────────────"
        echo "  Project-VM Routing (project-vm-map.json)"
        echo "───────────────────────────────────────────────────────────────────"
        echo ""

        # Check if this project has a dedicated VM
        local MAPPED_VM=$(jq -r ".projects.\"$PROJECT_NAME\".vm // empty" "$VM_MAP")
        INSTALL_SCRIPT=$(jq -r ".projects.\"$PROJECT_NAME\".install_script // empty" "$VM_MAP")
        UPGRADE_SCRIPT=$(jq -r ".projects.\"$PROJECT_NAME\".upgrade_script // empty" "$VM_MAP")
        DEPLOY_SCRIPT=$(jq -r ".projects.\"$PROJECT_NAME\".deploy_script // empty" "$VM_MAP")
        API_PORT=$(jq -r ".projects.\"$PROJECT_NAME\".api_port // empty" "$VM_MAP")
        WEB_PORT=$(jq -r ".projects.\"$PROJECT_NAME\".web_port // empty" "$VM_MAP")

        if [[ -n "$MAPPED_VM" ]]; then
            DEFAULT_VM="$MAPPED_VM"
            VM_IP=$(jq -r ".vms.\"$MAPPED_VM\".ip // empty" "$VM_MAP")
            SSH_USER=$(jq -r ".vms.\"$MAPPED_VM\".ssh_user // \"claude\"" "$VM_MAP")
            SSH_KEY=$(jq -r ".vms.\"$MAPPED_VM\".ssh_key // \"~/.claude/ssh/id_ed25519\"" "$VM_MAP")
            echo "  Project: $PROJECT_NAME"
            echo "  Mapped VM: $MAPPED_VM (dedicated)"
            echo "  VM IP: ${VM_IP:-auto-detect}"
        else
            # Use default VM, but check exclusivity — cannot use reserved VMs
            DEFAULT_VM=$(jq -r '.default.vm // "test-vm-cachyos"' "$VM_MAP")

            # Verify the default VM is not exclusive to another project
            local EXCLUSIVE=$(jq -r ".vms.\"$DEFAULT_VM\".exclusive_to // empty" "$VM_MAP")
            if [[ -n "$EXCLUSIVE" && "$EXCLUSIVE" != "$PROJECT_NAME" ]]; then
                echo "  ❌ ERROR: $DEFAULT_VM is exclusively reserved for $EXCLUSIVE"
                echo "  Cannot use $DEFAULT_VM for project $PROJECT_NAME"
                echo "Exclusivity violation: $DEFAULT_VM reserved for $EXCLUSIVE" >> "$ISSUES_FILE"
                return 1
            fi

            VM_IP=$(jq -r ".vms.\"$DEFAULT_VM\".ip // empty" "$VM_MAP")
            SSH_USER=$(jq -r ".vms.\"$DEFAULT_VM\".ssh_user // \"claude\"" "$VM_MAP")
            SSH_KEY=$(jq -r ".vms.\"$DEFAULT_VM\".ssh_key // \"~/.claude/ssh/id_ed25519\"" "$VM_MAP")
            echo "  Project: $PROJECT_NAME (no dedicated VM)"
            echo "  Using default VM: $DEFAULT_VM"
            echo "  VM IP: ${VM_IP:-auto-detect}"
        fi

    # ─── LEGACY MANIFEST FALLBACK ──────────────────────────────────
    elif [[ -f "$MANIFEST" ]]; then
        DEFAULT_VM=$(jq -r '.vm_testing.default_vm // empty' "$MANIFEST")
    fi

    # Detect environment
    detect_vm_environment

    # If still no VM, try auto-detect
    if [[ -z "$DEFAULT_VM" ]]; then
        echo "No default test VM configured."
        local EXISTING_VM=$(virsh list --all --name 2>/dev/null | grep -iE "test|dev" | head -1)
        if [[ -n "$EXISTING_VM" ]]; then
            echo "Found existing test VM: $EXISTING_VM"
            DEFAULT_VM="$EXISTING_VM"
        else
            echo "⚠️ No test VM found - skipping Phase V"
            return 0
        fi
    fi

    # Expand SSH_KEY tilde
    SSH_KEY="${SSH_KEY/#\~/$HOME}"

    echo ""
    echo "Using VM: $DEFAULT_VM"
    echo ""

    # Auto-detect VM IP if not in config
    if [[ -z "$VM_IP" || "$VM_IP" == "null" ]]; then
        # Start VM if not running
        if ! virsh domstate "$DEFAULT_VM" 2>/dev/null | grep -q running; then
            echo "Starting VM..."
            virsh start "$DEFAULT_VM" 2>/dev/null
            sleep 30
        fi
        VM_IP=$(virsh domifaddr "$DEFAULT_VM" 2>/dev/null | grep -oP '192\.168\.\d+\.\d+|10\.\d+\.\d+\.\d+' | head -1)
    fi

    if [[ -z "$VM_IP" ]]; then
        echo "❌ Could not determine VM IP address"
        echo "VM IP detection failed" >> "$ISSUES_FILE"
        return 1
    fi

    local SSH_CMD="ssh -i $SSH_KEY -o ConnectTimeout=10 -o StrictHostKeyChecking=no $SSH_USER@$VM_IP"

    # ─── STAGED RELEASE LIFECYCLE ──────────────────────────────────
    # If a staged release exists, test the full installation lifecycle
    test_staged_release_lifecycle

    # ─── DOCKER STAGING IMAGES ─────────────────────────────────────
    test_docker_staging

    # ─── LEGACY: MANIFEST-BASED TESTS ─────────────────────────────
    # Fall back to legacy rsync deploy + manifest tests if no staged release
    local STAGED_FILE="$PROJECT_DIR/.staged-release"
    if [[ ! -f "$STAGED_FILE" ]]; then
        # Reset to clean state
        reset_vm_to_clean "$DEFAULT_VM" || true

        # Deploy via rsync
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
    fi

    # ─── GENERATE REPORT ───────────────────────────────────────────
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

## Step 4b: Staged Release Installation Lifecycle

If Discovery reported a valid staged release, test the full installation lifecycle on the VM.
This exercises the same scripts a real user would run: `install.sh` → `upgrade.sh` → `deploy.sh`.

```bash
test_staged_release_lifecycle() {
    local PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
    local STAGED_FILE="$PROJECT_DIR/.staged-release"

    if [[ ! -f "$STAGED_FILE" ]]; then
        echo "  No staged release detected — skipping lifecycle test"
        return 0
    fi

    source "$STAGED_FILE"

    echo ""
    echo "───────────────────────────────────────────────────────────────────"
    echo "  Staged Release Lifecycle Test"
    echo "───────────────────────────────────────────────────────────────────"
    echo ""
    echo "  Version: ${version:-unknown}"
    echo "  Tag: ${tag:-unknown}"
    echo "  Commit: ${commit:-unknown}"
    echo ""

    local LIFECYCLE_RESULTS=()
    local LIFECYCLE_FAILED=false

    # 1. Copy project to VM staging area
    echo "  [1/6] Copying project to VM staging area..."
    rsync -az --exclude='.git' --exclude='venv' --exclude='__pycache__' \
        --exclude='node_modules' --exclude='.venv' --exclude='*.pyc' \
        -e "ssh -i $SSH_KEY -o StrictHostKeyChecking=no" \
        "$PROJECT_DIR/" "$SSH_USER@$VM_IP:/tmp/staged-release/"

    if [[ $? -eq 0 ]]; then
        LIFECYCLE_RESULTS+=("Copy to VM|PASS")
        echo "       ✅ Files copied"
    else
        LIFECYCLE_RESULTS+=("Copy to VM|FAIL")
        echo "       ❌ Copy failed"
        echo "Staged release: copy to VM failed" >> "$ISSUES_FILE"
        return 1
    fi

    # 2. FRESH INSTALL via install.sh
    local SCRIPT_TO_RUN=""
    if [[ -n "$INSTALL_SCRIPT" ]]; then
        SCRIPT_TO_RUN="$INSTALL_SCRIPT"
    elif $SSH_CMD "[[ -f /tmp/staged-release/install.sh ]]" 2>/dev/null; then
        SCRIPT_TO_RUN="./install.sh"
    fi

    if [[ -n "$SCRIPT_TO_RUN" ]]; then
        echo "  [2/6] Running fresh install: $SCRIPT_TO_RUN"
        if $SSH_CMD "cd /tmp/staged-release && sudo bash $SCRIPT_TO_RUN" 2>&1; then
            # Verify install
            local REMOTE_VERSION=$($SSH_CMD "cat /opt/*/VERSION 2>/dev/null" 2>/dev/null | head -1)
            if [[ "$REMOTE_VERSION" == "$version" ]]; then
                LIFECYCLE_RESULTS+=("Fresh Install|PASS")
                echo "       ✅ Install succeeded (version: $REMOTE_VERSION)"
            else
                LIFECYCLE_RESULTS+=("Fresh Install|WARN")
                echo "       ⚠️ Install completed but version mismatch: expected $version, got ${REMOTE_VERSION:-nothing}"
            fi
        else
            LIFECYCLE_RESULTS+=("Fresh Install|FAIL")
            LIFECYCLE_FAILED=true
            echo "       ❌ Install failed"
            echo "Staged release: install.sh failed" >> "$ISSUES_FILE"
        fi
    else
        LIFECYCLE_RESULTS+=("Fresh Install|SKIP")
        echo "  [2/6] No install script found — skipping"
    fi

    # 3. Verify Install — check services and API
    echo "  [3/6] Verifying installation..."
    local INSTALL_VERIFIED=false

    # Check version
    local FINAL_VERSION=$($SSH_CMD "cat /opt/*/VERSION 2>/dev/null" 2>/dev/null | head -1)
    echo "       Version on VM: ${FINAL_VERSION:-unknown}"

    # Check API if port is configured
    if [[ -n "$API_PORT" ]]; then
        local API_STATUS=$($SSH_CMD "curl -s -o /dev/null -w '%{http_code}' http://localhost:$API_PORT/api/system/version 2>/dev/null" 2>/dev/null)
        echo "       API health (port $API_PORT): HTTP ${API_STATUS:-timeout}"
        if [[ "$API_STATUS" == "200" ]]; then
            INSTALL_VERIFIED=true
        fi
    fi

    if [[ "$INSTALL_VERIFIED" == "true" ]]; then
        LIFECYCLE_RESULTS+=("Verify Install|PASS")
        echo "       ✅ Installation verified"
    else
        LIFECYCLE_RESULTS+=("Verify Install|WARN")
        echo "       ⚠️ Installation not fully verified (API may need time to start)"
    fi

    # 4. UPGRADE via upgrade.sh (idempotent — same version upgrade)
    SCRIPT_TO_RUN=""
    if [[ -n "$UPGRADE_SCRIPT" ]]; then
        SCRIPT_TO_RUN="$UPGRADE_SCRIPT"
    elif $SSH_CMD "[[ -f /tmp/staged-release/upgrade.sh ]]" 2>/dev/null; then
        SCRIPT_TO_RUN="./upgrade.sh"
    fi

    if [[ -n "$SCRIPT_TO_RUN" ]]; then
        echo "  [4/6] Running upgrade: $SCRIPT_TO_RUN"
        if $SSH_CMD "cd /tmp/staged-release && sudo bash $SCRIPT_TO_RUN" 2>&1; then
            LIFECYCLE_RESULTS+=("Upgrade|PASS")
            echo "       ✅ Upgrade completed"
        else
            LIFECYCLE_RESULTS+=("Upgrade|FAIL")
            LIFECYCLE_FAILED=true
            echo "       ❌ Upgrade failed"
            echo "Staged release: upgrade.sh failed" >> "$ISSUES_FILE"
        fi
    else
        LIFECYCLE_RESULTS+=("Upgrade|SKIP")
        echo "  [4/6] No upgrade script — skipping"
    fi

    # 5. DEPLOY via deploy.sh
    SCRIPT_TO_RUN=""
    if [[ -n "$DEPLOY_SCRIPT" ]]; then
        SCRIPT_TO_RUN="$DEPLOY_SCRIPT"
    elif $SSH_CMD "[[ -f /tmp/staged-release/deploy.sh ]]" 2>/dev/null; then
        SCRIPT_TO_RUN="./deploy.sh"
    fi

    if [[ -n "$SCRIPT_TO_RUN" ]]; then
        echo "  [5/6] Running deploy: $SCRIPT_TO_RUN"
        if $SSH_CMD "cd /tmp/staged-release && sudo bash $SCRIPT_TO_RUN" 2>&1; then
            LIFECYCLE_RESULTS+=("Deploy|PASS")
            echo "       ✅ Deploy completed"
        else
            LIFECYCLE_RESULTS+=("Deploy|FAIL")
            LIFECYCLE_FAILED=true
            echo "       ❌ Deploy failed"
            echo "Staged release: deploy.sh failed" >> "$ISSUES_FILE"
        fi
    else
        LIFECYCLE_RESULTS+=("Deploy|SKIP")
        echo "  [5/6] No deploy script — skipping"
    fi

    # 6. Final verification: services running, API responding, version correct
    echo "  [6/6] Post-lifecycle verification..."
    FINAL_VERSION=$($SSH_CMD "cat /opt/*/VERSION 2>/dev/null" 2>/dev/null | head -1)
    echo "       Final version: ${FINAL_VERSION:-unknown}"

    if [[ -n "$API_PORT" ]]; then
        # Give services time to restart
        sleep 3
        API_STATUS=$($SSH_CMD "curl -s -o /dev/null -w '%{http_code}' http://localhost:$API_PORT/api/system/version 2>/dev/null" 2>/dev/null)
        echo "       API health (port $API_PORT): HTTP ${API_STATUS:-timeout}"
    fi

    if [[ "$FINAL_VERSION" == "$version" ]]; then
        LIFECYCLE_RESULTS+=("Final Verify|PASS")
        echo "       ✅ Version verified: $FINAL_VERSION"
    else
        LIFECYCLE_RESULTS+=("Final Verify|WARN")
        echo "       ⚠️ Version mismatch: expected $version, got ${FINAL_VERSION:-unknown}"
    fi

    # Cleanup staging area
    $SSH_CMD "rm -rf /tmp/staged-release" 2>/dev/null

    # Print lifecycle summary table
    echo ""
    echo "  ┌──────────────────────┬────────┐"
    echo "  │ Step                 │ Status │"
    echo "  ├──────────────────────┼────────┤"
    for result in "${LIFECYCLE_RESULTS[@]}"; do
        local step="${result%%|*}"
        local status="${result##*|}"
        printf "  │ %-20s │ %-6s │\n" "$step" "$status"
    done
    echo "  └──────────────────────┴────────┘"

    if [[ "$LIFECYCLE_FAILED" == "true" ]]; then
        echo ""
        echo "  ❌ Staged release lifecycle had failures"
        return 1
    else
        echo ""
        echo "  ✅ Staged release lifecycle completed"
        return 0
    fi
}
```

## Step 4c: Docker Staging Image Testing

After the install/upgrade/deploy lifecycle, test Docker staging images if they exist:

```bash
test_docker_staging() {
    local PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
    local STAGED_FILE="$PROJECT_DIR/.staged-release"

    # Need version info for matching
    local version=""
    if [[ -f "$STAGED_FILE" ]]; then
        source "$STAGED_FILE"
    fi

    if [[ -z "$version" ]]; then
        # Try VERSION file
        if [[ -f "$PROJECT_DIR/VERSION" ]]; then
            version=$(cat "$PROJECT_DIR/VERSION" | tr -d '[:space:]')
        else
            return 0
        fi
    fi

    local PROJECT_NAME_LOWER=$(basename "$PROJECT_DIR" | tr '[:upper:]' '[:lower:]')
    local STAGING_IMAGES=""

    if command -v docker &>/dev/null; then
        STAGING_IMAGES=$(docker images --format '{{.Repository}}:{{.Tag}}' 2>/dev/null | \
            grep -iE "${PROJECT_NAME_LOWER}.*(${version}|rc|staging)" | head -5)
    fi

    if [[ -z "$STAGING_IMAGES" ]]; then
        echo "  No Docker staging images found for v${version}"
        return 0
    fi

    echo ""
    echo "───────────────────────────────────────────────────────────────────"
    echo "  Docker Staging Image Test"
    echo "───────────────────────────────────────────────────────────────────"
    echo ""
    echo "  Staging images found:"
    echo "$STAGING_IMAGES" | sed 's/^/    /'

    # Transfer to VM and test if Docker is available there
    if $SSH_CMD "command -v docker" &>/dev/null 2>&1; then
        local IMAGE=$(echo "$STAGING_IMAGES" | head -1)
        echo ""
        echo "  Transferring $IMAGE to VM..."
        docker save "$IMAGE" | $SSH_CMD "docker load" 2>&1

        echo "  Running container smoke test..."
        # Try --version first, then --help, then run detached
        local DOCKER_OK=false
        if $SSH_CMD "docker run --rm $IMAGE --version" 2>/dev/null; then
            DOCKER_OK=true
        elif $SSH_CMD "docker run --rm -d --name test-staged $IMAGE && sleep 5 && docker logs test-staged && docker stop test-staged" 2>/dev/null; then
            DOCKER_OK=true
        fi

        if [[ "$DOCKER_OK" == "true" ]]; then
            echo "  ✅ Docker staging test completed"
        else
            echo "  ⚠️ Docker staging test completed with warnings"
        fi
    else
        echo "  Docker not available on VM — skipping container test"
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
- **Discovery reports a valid staged release** (`.staged-release` exists and tag is valid)
- Discovery `ISOLATION_LEVEL` is `vm-required` or `vm-recommended`

Phase V is **skipped** when:
- No test VMs available and no ISOs to create from
- libvirt/virsh not installed
- Project has no install scripts, dangerous operations, or staged release
- No staged release AND isolation level is `sandbox` or `sandbox-warn`

## Project-VM Routing

Phase V reads `~/.claude/config/project-vm-map.json` to determine the correct VM:

| Routing Scenario | VM Used | Source |
|------------------|---------|--------|
| Project has dedicated VM | Dedicated VM | `projects.<name>.vm` |
| Project has no entry | Default VM | `default.vm` |
| Default VM is exclusive to another project | **ERROR** | Exclusivity violation |

**Exclusivity**: When a VM has `exclusive_to` set, ONLY that project can use it, and the project can ONLY use that VM. This prevents cross-contamination.

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

### Staged Release Lifecycle
| Step | Script | Status | Duration |
|------|--------|--------|----------|
| Copy to VM | rsync | PASS/FAIL | Xs |
| Fresh Install | install.sh | PASS/FAIL/SKIP | Xs |
| Verify Install | (version + API check) | PASS/FAIL | Xs |
| Upgrade | upgrade.sh | PASS/FAIL/SKIP | Xs |
| Deploy | deploy.sh | PASS/FAIL/SKIP | Xs |
| Final Verify | (version + API check) | PASS/FAIL | Xs |
| Docker Image | (transfer + smoke test) | PASS/FAIL/SKIP | Xs |

| Attribute | Value |
|-----------|-------|
| Version | X.Y.Z |
| Tag | vX.Y.Z |
| VM | vm-name (IP) |
| Final Version Verified | Yes/No |

### Issues Found
- [List from vm-test-issues.log]

### Phase V Status: ✅ PASSED / ❌ FAILED
```
