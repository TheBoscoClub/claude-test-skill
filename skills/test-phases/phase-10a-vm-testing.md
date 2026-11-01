# Phase 10a: VM Testing

> **Model**: `sonnet` | **Phase**: 10a | **Modifies Files**: VM only
> **Task Tracking**: Call `TaskUpdate(taskId, status="in_progress")` at start, `TaskUpdate(taskId, status="completed")` when done.
> **Key Tools**: `Bash` for virsh/SSH commands (use `timeout` for hung operations). Use `AskUserQuestion` if VM connectivity fails.

Test apps, releases, system-level changes in isolated VMs.

## When to Use

| Scenario | Phase 10a? |
| --- | --- |
| PAM/auth modifications | Yes |
| systemd service changes | Yes |
| Kernel parameters / boot changes | Yes |
| Cross-distro testing | Yes |
| Reboot cycle testing | Yes |
| App logic testing | No (Phase 9a) |
| Production validation | No (Phase 9b) |

**Triggers:** `vm-test-manifest.json` with `enabled: true`, dangerous operations detected, staged release, `--phase=V`, isolation level `vm-required`/`vm-recommended`.

## CRITICAL: Production Data Isolation

Test VMs MUST NOT live-mount production storage (no NFS, CIFS, virtiofs, virtio-9p). Copying data *into* the VM via scp/rsync is allowed.

## VM Configuration

**Storage locations** come from the installation, never from this skill: `paths.iso_dir` (ISO library for new VMs) and `paths.vm_storage_dirs` (a list of directories holding VM disk images) in `~/.claude/config/project-vm-map.json`. Neither has a built-in default. `create_test_vm` is the only code that writes under them: without either key it refuses before touching anything. Phase 2's `detect_vm_availability` only lists ISOs found there (read-only). `create_test_vm` also refuses a name libvirt already defines — it never destroys or undefines an existing VM.

**Which VMs this phase may touch**: only VMs the map lists under `vms`, chosen by `resolve_test_vm` or validated by `check_test_vm` (`skills/test-phases/lib/test-vm.sh`, see `phase-10b-vm-lifecycle.md` § Test VM Selection). Each function below that acts on an existing VM sources that file itself. Snapshot deletes go only through `delete_pretest_snapshot`, which refuses anything but a `pre-test-YYYYMMDD-HHMMSS` name, any name containing `pristine` and any configured `pristine_snapshot`, so a pristine snapshot is never deleted. A QA VM (`"role": "qa"`) is never touched. Example:

```json
{ "paths": { "iso_dir": "/srv/isos", "vm_storage_dirs": ["/srv/vm-images"] } }
```

### VM Test Manifest: `vm-test-manifest.json`

```json
{
  "vm_testing": {
    "enabled": true,
    "default_vm": "example-test-vm",
    "dangerous_operations": ["pam_modification", "systemd_service_install", "kernel_params"],
    "pristine_snapshot": "pristine",
    "post_test_restore": true,
    "test_environments": [
      { "name": "example-test-vm", "type": "existing", "vm_name": "example-test-vm", "snapshot": "pristine" },
      { "name": "ubuntu-lts", "type": "create", "iso_pattern": "ubuntu-*-desktop-amd64.iso", "memory_mb": 4096, "disk_gb": 40 }
    ],
    "ssh_config": { "user": "testuser", "key": "~/.ssh/vm_test_key", "port": 22 },
    "test_sequences": [
      { "name": "install-and-reboot", "steps": ["deploy", "install", "reboot", "validate"] },
      { "name": "pam-change-test", "steps": ["snapshot", "deploy", "modify_pam", "reboot", "test_login", "restore"] }
    ]
  }
}
```

## Step 1: Detect VM Environment

```bash
detect_vm_environment() {
    command -v virsh &>/dev/null || { echo "libvirt/virsh not installed"; return 1; }
    systemctl is-active libvirtd &>/dev/null || sudo systemctl start libvirtd

    echo "Existing VMs:"
    virsh list --all 2>/dev/null | tail -n +3 | while read -r line; do [[ -n "$line" ]] && echo "  $line"; done

    echo "VM Snapshots:"
    for vm in $(virsh list --all --name 2>/dev/null); do
        local snaps=$(virsh snapshot-list "$vm" --name 2>/dev/null | grep -v "^$")
        [[ -n "$snaps" ]] && { echo "  $vm:"; echo "$snaps" | sed 's/^/    /'; }
    done
}
```

## Step 2: Create New VM from ISO

```bash
create_test_vm() {
    local VM_NAME="$1" ISO_PATTERN="$2" MEMORY_MB="${3:-4096}" DISK_GB="${4:-40}" UEFI="${5:-false}"
    [[ "$VM_NAME" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || { echo "ERROR: invalid VM name: '$VM_NAME'"; return 1; }
    [[ "$MEMORY_MB" =~ ^[0-9]+$ && "$DISK_GB" =~ ^[0-9]+$ ]] || { echo "ERROR: memory_mb and disk_gb must be integers"; return 1; }
    # Locations from the installation (§ VM Configuration); no built-in default, refuse before touching anything
    local VM_MAP="$HOME/.claude/config/project-vm-map.json" ISO_DIR VM_STORAGE
    ISO_DIR=$(jq -r '.paths.iso_dir // empty | strings | select(startswith("/"))' "$VM_MAP" 2>/dev/null)
    VM_STORAGE=$(jq -r '[.paths.vm_storage_dirs[]? | strings | select(startswith("/"))][0] // empty' "$VM_MAP" 2>/dev/null)
    [[ -n "$ISO_DIR" ]] || { echo "ERROR: set paths.iso_dir in $VM_MAP"; return 1; }
    [[ -n "$VM_STORAGE" ]] || { echo "ERROR: set paths.vm_storage_dirs in $VM_MAP"; return 1; }
    local VM_DISK="${VM_STORAGE%/}/${VM_NAME}.qcow2"

    # Never replace an existing VM: a name libvirt knows, or a disk image already on disk, is refused.
    if virsh dominfo "$VM_NAME" &>/dev/null || sudo virsh dominfo "$VM_NAME" &>/dev/null; then
        echo "ERROR: a VM named $VM_NAME already exists — refusing to replace it (choose another name)"
        return 1
    fi
    [[ -e "$VM_DISK" ]] && { echo "ERROR: $VM_DISK already exists — refusing to overwrite it"; return 1; }

    local ISO_PATH=$(ls "$ISO_DIR"/$ISO_PATTERN 2>/dev/null | head -1)
    [[ -z "$ISO_PATH" ]] && { echo "No ISO matching: $ISO_PATTERN"; return 1; }

    local VIRT_CMD=(virt-install --name "$VM_NAME" --memory "$MEMORY_MB" --vcpus 4
        --disk "path=$VM_DISK,size=$DISK_GB,format=qcow2" --cdrom "$ISO_PATH"
        --os-variant detect=on --network network=default --graphics spice --video virtio --noautoconsole)
    [[ "$UEFI" == "true" ]] && VIRT_CMD+=(--boot uefi)

    "${VIRT_CMD[@]}" && echo "VM created: $VM_NAME (add it under vms in $VM_MAP before /test may use it)" || { echo "Failed to create VM"; return 1; }
}
```

## Step 3: VM Snapshot Management

```bash
manage_vm_snapshot() {
    local VM_NAME="$1" ACTION="$2" SNAPSHOT_NAME="${3:-clean-install}"

    case "$ACTION" in
        create)
            virsh domstate "$VM_NAME" 2>/dev/null | grep -q running && { virsh shutdown "$VM_NAME"; sleep 10; }
            virsh snapshot-create-as "$VM_NAME" "$SNAPSHOT_NAME" --description "Test snapshot $(date '+%Y-%m-%d %H:%M')"
            ;;
        restore)
            virsh destroy "$VM_NAME" 2>/dev/null
            virsh snapshot-revert "$VM_NAME" "$SNAPSHOT_NAME"
            ;;
        list)   virsh snapshot-list "$VM_NAME" ;;
        delete)
            # Only pre-test snapshots are ever deleted (never a pristine one): lib/test-vm.sh refuses the rest
            source "${TEST_PHASES_DIR:-$HOME/.claude/skills/test-phases}/lib/test-vm.sh" &&
                declare -F delete_pretest_snapshot >/dev/null ||
                { echo "ERROR: test-VM helpers not loaded (skills/test-phases/lib/test-vm.sh)"; return 2; }
            delete_pretest_snapshot "$VM_NAME" "$SNAPSHOT_NAME"
            ;;
    esac
}

# Reset to pristine state — checks manifest for snapshot name, falls back to standard names.
# Revert only: never deletes, recreates or edits a snapshot or a disk, and never uses qemu-img commit
# (that bakes changes into the base image). Only a VM the installation lists may be reset.
reset_vm_to_pristine() {
    local VM_NAME="$1" PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
    local PRISTINE_SNAP="" SNAPS=""

    source "${TEST_PHASES_DIR:-$HOME/.claude/skills/test-phases}/lib/test-vm.sh" &&
        declare -F check_test_vm >/dev/null ||
        { echo "ERROR: test-VM helpers not loaded (skills/test-phases/lib/test-vm.sh)"; return 2; }
    check_test_vm "$PROJECT_DIR" "$VM_NAME" || { echo "Refusing to reset $VM_NAME (reason above)"; return 1; }

    [[ -f "${PROJECT_DIR}/vm-test-manifest.json" ]] && \
        PRISTINE_SNAP=$(python3 -c "import json; d=json.load(open('${PROJECT_DIR}/vm-test-manifest.json')); print(d.get('vm_testing',{}).get('pristine_snapshot',''))" 2>/dev/null)

    SNAPS=$(virsh snapshot-list "$VM_NAME" --name 2>/dev/null)
    if [[ -n "$PRISTINE_SNAP" ]] && grep -qxF -- "$PRISTINE_SNAP" <<<"$SNAPS"; then
        manage_vm_snapshot "$VM_NAME" restore "$PRISTINE_SNAP"
    elif grep -qxF pristine <<<"$SNAPS"; then
        manage_vm_snapshot "$VM_NAME" restore "pristine"
    elif grep -qxF clean-install <<<"$SNAPS"; then
        manage_vm_snapshot "$VM_NAME" restore "clean-install"
    else
        echo "No pristine or clean snapshot found for $VM_NAME"
        return 1
    fi
}

reset_vm_to_clean() { reset_vm_to_pristine "$@"; }
```

## Step 4: Deploy to VM via SSH

```bash
deploy_to_vm() {
    local VM_NAME="$1" PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
    local SSH_USER="${VM_SSH_USER:-testuser}" SSH_KEY="${VM_SSH_KEY:-~/.ssh/vm_test_key}"

    # Start VM if needed
    virsh domstate "$VM_NAME" 2>/dev/null | grep -q running || { virsh start "$VM_NAME"; sleep 30; }

    # Get VM IP
    local VM_IP=$(virsh domifaddr "$VM_NAME" 2>/dev/null | grep -oP '192\.168\.\d+\.\d+|10\.\d+\.\d+\.\d+' | head -1)
    [[ -z "$VM_IP" ]] && { echo "Could not determine VM IP"; return 1; }

    # Test SSH
    ssh -i "$SSH_KEY" -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$SSH_USER@$VM_IP" "echo 'SSH OK'" &>/dev/null || { echo "SSH failed"; return 1; }

    # Deploy
    local DEPLOY_DIR="/tmp/test-deploy-$(basename $PROJECT_DIR)"
    ssh -i "$SSH_KEY" "$SSH_USER@$VM_IP" "mkdir -p $DEPLOY_DIR"
    rsync -avz --exclude='.git' --exclude='node_modules' --exclude='__pycache__' --exclude='.venv' \
        -e "ssh -i $SSH_KEY" "$PROJECT_DIR/" "$SSH_USER@$VM_IP:$DEPLOY_DIR/"

    export VM_IP VM_SSH_USER="$SSH_USER" VM_SSH_KEY="$SSH_KEY" VM_DEPLOY_DIR="$DEPLOY_DIR"
}
```

## Step 5: Run Tests in VM

Driven by manifest `test_sequences` or detected dangerous operations.

```bash
run_vm_tests() {
    local VM_NAME="$1" TEST_TYPE="${2:-basic}"
    local SSH_CMD="ssh -i $VM_SSH_KEY $VM_SSH_USER@$VM_IP"

    case "$TEST_TYPE" in
        basic)
            $SSH_CMD "cd $VM_DEPLOY_DIR && ls -la"
            $SSH_CMD "cd $VM_DEPLOY_DIR && [[ -f install.sh ]] && bash -n install.sh && echo 'install.sh syntax OK'"
            ;;
        install)
            $SSH_CMD "cd $VM_DEPLOY_DIR && [[ -f install.sh ]] && bash install.sh --user"
            $SSH_CMD "which $(basename $PROJECT_DIR) 2>/dev/null && echo 'Binary installed' || echo 'Binary not in PATH'"
            ;;
        pam)
            $SSH_CMD "sudo cp -r /etc/pam.d /etc/pam.d.backup"
            $SSH_CMD "cd $VM_DEPLOY_DIR && [[ -f install.sh ]] && sudo bash install.sh --system"
            $SSH_CMD "echo 'Login OK'" &>/dev/null && echo "PAM modification safe" || { echo "PAM modification BROKE LOGIN"; return 1; }
            ;;
        systemd)
            $SSH_CMD "cd $VM_DEPLOY_DIR && [[ -f install.sh ]] && sudo bash install.sh --system"
            local APP=$(basename $PROJECT_DIR | tr '[:upper:]' '[:lower:]')
            $SSH_CMD "systemctl status $APP.service 2>/dev/null || systemctl --user status $APP.service 2>/dev/null"
            ;;
        reboot)
            $SSH_CMD "cd $VM_DEPLOY_DIR && [[ -f install.sh ]] && bash install.sh"
            $SSH_CMD "sudo reboot" 2>/dev/null || true
            sleep 60
            local retries=10
            while [[ $retries -gt 0 ]]; do
                $SSH_CMD "echo 'Back online'" &>/dev/null && break
                ((retries--)); sleep 10
            done
            [[ $retries -eq 0 ]] && { echo "VM did not come back"; return 1; }
            $SSH_CMD "which $(basename $PROJECT_DIR) && $(basename $PROJECT_DIR) --version"
            ;;
    esac
}
```

## Step 6: Cross-Distro Testing

```bash
run_cross_distro_tests() {
    # VMs come from configuration only: the arguments, else the manifest's test_environments entries of
    # type "existing" (their vm_name). No built-in names. Each must pass check_test_vm (listed under the
    # map's vms, exclusivity respected) before it is reset, started or deployed to.
    local PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
    local MANIFEST="$PROJECT_DIR/vm-test-manifest.json"
    source "${TEST_PHASES_DIR:-$HOME/.claude/skills/test-phases}/lib/test-vm.sh" &&
        declare -F check_test_vm >/dev/null ||
        { echo "ERROR: test-VM helpers not loaded (skills/test-phases/lib/test-vm.sh)"; return 2; }
    local DISTROS=("$@")
    if [[ ${#DISTROS[@]} -eq 0 && -f "$MANIFEST" ]]; then
        mapfile -t DISTROS < <(jq -r '.vm_testing.test_environments[]? | select(.type == "existing") | .vm_name // empty | strings' "$MANIFEST" 2>/dev/null)
    fi
    [[ ${#DISTROS[@]} -gt 0 ]] || { echo "Cross-distro: no VMs configured (vm_testing.test_environments, type existing) — skipped"; return 0; }
    local RESULTS=()

    for distro in "${DISTROS[@]}"; do
        check_test_vm "$PROJECT_DIR" "$distro" || { RESULTS+=("$distro: REFUSED (not a VM this project may use)"); continue; }
        virsh dominfo "$distro" &>/dev/null || { RESULTS+=("$distro: SKIPPED"); continue; }
        reset_vm_to_clean "$distro" || { RESULTS+=("$distro: FAILED (reset)"); continue; }
        virsh start "$distro" 2>/dev/null; sleep 30

        if deploy_to_vm "$distro" && run_vm_tests "$distro" "install"; then
            RESULTS+=("$distro: PASSED")
        else
            RESULTS+=("$distro: FAILED")
        fi
        virsh shutdown "$distro" 2>/dev/null
    done

    echo "Cross-Distro Summary:"
    for r in "${RESULTS[@]}"; do echo "  $r"; done
}
```

## Step 7: Docker Image Testing in VM

```bash
test_docker_in_vm() {
    local VM_NAME="$1" DOCKER_IMAGE="$2"
    local SSH_CMD="ssh -i $VM_SSH_KEY $VM_SSH_USER@$VM_IP"

    $SSH_CMD "command -v docker" &>/dev/null || { echo "Docker not in VM"; return 1; }
    $SSH_CMD "docker pull $DOCKER_IMAGE"
    $SSH_CMD "docker run --rm $DOCKER_IMAGE --version" || \
    $SSH_CMD "docker run --rm -d --name test-container $DOCKER_IMAGE && sleep 5 && docker logs test-container && docker stop test-container"
}
```

## Staged Release Lifecycle Test

If Discovery reported a valid staged release, test install -> upgrade -> deploy on the VM.

```bash
test_staged_release_lifecycle() {
    local PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
    local STAGED_FILE="$PROJECT_DIR/.staged-release"
    [[ ! -f "$STAGED_FILE" ]] && return 0

    source "$STAGED_FILE"
    local LIFECYCLE_RESULTS=() LIFECYCLE_FAILED=false

    # 1. Copy to VM
    rsync -az --exclude='.git' --exclude='venv' --exclude='__pycache__' --exclude='node_modules' \
        -e "ssh -i $SSH_KEY -o StrictHostKeyChecking=no" "$PROJECT_DIR/" "$SSH_USER@$VM_IP:/tmp/staged-release/"
    [[ $? -eq 0 ]] && LIFECYCLE_RESULTS+=("Copy|PASS") || { LIFECYCLE_RESULTS+=("Copy|FAIL"); return 1; }

    # 2. Fresh install
    local SCRIPT=""
    [[ -n "$INSTALL_SCRIPT" ]] && SCRIPT="$INSTALL_SCRIPT"
    [[ -z "$SCRIPT" ]] && $SSH_CMD "[[ -f /tmp/staged-release/install.sh ]]" 2>/dev/null && SCRIPT="./install.sh --system"

    # Check manifest for install command override
    local MANIFEST="$PROJECT_DIR/vm-test-manifest.json"
    [[ -f "$MANIFEST" ]] && {
        local MC=$(python3 -c "import json; d=json.load(open('$MANIFEST')); print(d.get('vm_testing',{}).get('install',{}).get('command',''))" 2>/dev/null)
        [[ -n "$MC" ]] && SCRIPT="$MC"
    }

    if [[ -n "$SCRIPT" ]]; then
        $SSH_CMD "cd /tmp/staged-release && sudo bash -c '$SCRIPT'" 2>&1 && LIFECYCLE_RESULTS+=("Install|PASS") || { LIFECYCLE_RESULTS+=("Install|FAIL"); LIFECYCLE_FAILED=true; }
    else
        LIFECYCLE_RESULTS+=("Install|SKIP")
    fi

    # 3. Verify install (version + API)
    local FINAL_VERSION=$($SSH_CMD "cat /opt/*/VERSION 2>/dev/null" 2>/dev/null | head -1)
    [[ -n "$API_PORT" ]] && {
        local STATUS=$($SSH_CMD "curl -s -o /dev/null -w '%{http_code}' http://localhost:$API_PORT/api/system/version 2>/dev/null" 2>/dev/null)
        echo "  API (port $API_PORT): HTTP ${STATUS:-timeout}"
    }
    LIFECYCLE_RESULTS+=("Verify|$([[ "$FINAL_VERSION" == "$version" ]] && echo PASS || echo WARN)")

    # 4. Upgrade
    local USCRIPT=""
    [[ -n "$UPGRADE_SCRIPT" ]] && USCRIPT="$UPGRADE_SCRIPT"
    [[ -z "$USCRIPT" ]] && $SSH_CMD "[[ -f /tmp/staged-release/upgrade.sh ]]" 2>/dev/null && USCRIPT="./upgrade.sh"
    if [[ -n "$USCRIPT" ]]; then
        $SSH_CMD "cd /tmp/staged-release && sudo bash $USCRIPT" 2>&1 && LIFECYCLE_RESULTS+=("Upgrade|PASS") || { LIFECYCLE_RESULTS+=("Upgrade|FAIL"); LIFECYCLE_FAILED=true; }
    else
        LIFECYCLE_RESULTS+=("Upgrade|SKIP")
    fi

    # 5. Deploy
    local DSCRIPT=""
    [[ -n "$DEPLOY_SCRIPT" ]] && DSCRIPT="$DEPLOY_SCRIPT"
    [[ -z "$DSCRIPT" ]] && $SSH_CMD "[[ -f /tmp/staged-release/deploy.sh ]]" 2>/dev/null && DSCRIPT="./deploy.sh"
    if [[ -n "$DSCRIPT" ]]; then
        $SSH_CMD "cd /tmp/staged-release && sudo bash $DSCRIPT" 2>&1 && LIFECYCLE_RESULTS+=("Deploy|PASS") || { LIFECYCLE_RESULTS+=("Deploy|FAIL"); LIFECYCLE_FAILED=true; }
    else
        LIFECYCLE_RESULTS+=("Deploy|SKIP")
    fi

    # 6. Final verify
    FINAL_VERSION=$($SSH_CMD "cat /opt/*/VERSION 2>/dev/null" 2>/dev/null | head -1)
    [[ -n "$API_PORT" ]] && { sleep 3; $SSH_CMD "curl -s -o /dev/null -w '%{http_code}' http://localhost:$API_PORT/api/system/version 2>/dev/null"; }
    LIFECYCLE_RESULTS+=("Final|$([[ "$FINAL_VERSION" == "$version" ]] && echo PASS || echo WARN)")

    $SSH_CMD "rm -rf /tmp/staged-release" 2>/dev/null

    # Summary
    for r in "${LIFECYCLE_RESULTS[@]}"; do printf "  %-15s %s\n" "${r%%|*}" "${r##*|}"; done
    [[ "$LIFECYCLE_FAILED" == "true" ]] && return 1 || return 0
}
```

## Docker Staging Image Test

```bash
test_docker_staging() {
    local PROJECT_DIR="${PROJECT_DIR:-$(pwd)}" version=""
    [[ -f "$PROJECT_DIR/.staged-release" ]] && source "$PROJECT_DIR/.staged-release"
    [[ -z "$version" && -f "$PROJECT_DIR/VERSION" ]] && version=$(cat "$PROJECT_DIR/VERSION" | tr -d '[:space:]')
    [[ -z "$version" ]] && return 0

    local NAME_LOWER=$(basename "$PROJECT_DIR" | tr '[:upper:]' '[:lower:]')
    local IMAGES=$(docker images --format '{{.Repository}}:{{.Tag}}' 2>/dev/null | grep -iE "${NAME_LOWER}.*(${version}|rc|staging)" | head -5)
    [[ -z "$IMAGES" ]] && return 0

    if $SSH_CMD "command -v docker" &>/dev/null 2>&1; then
        local IMAGE=$(echo "$IMAGES" | head -1)
        docker save "$IMAGE" | $SSH_CMD "docker load" 2>&1
        $SSH_CMD "docker run --rm $IMAGE --version" 2>/dev/null || \
        $SSH_CMD "docker run --rm -d --name test-staged $IMAGE && sleep 5 && docker logs test-staged && docker stop test-staged" 2>/dev/null
    fi
}
```

## GUI/VNC Testing

```python
#!/usr/bin/env python3
"""GUI test automation via VNC. Requires: pip install vncdotool service-identity"""
from vncdotool import api
import time

def test_graphical_login(vnc_host="127.0.0.1", vnc_port=5901, password=None):
    client = api.connect(f'{vnc_host}::{vnc_port}')
    try:
        client.mouseMove(640, 350)
        client.mousePress(1)
        time.sleep(1)
        for char in password:
            if char.isupper():
                client.keyDown('shift'); client.keyPress(char.lower()); client.keyUp('shift')
            elif char in '!@#$%':
                shift_map = {'!':'1','@':'2','#':'3','$':'4','%':'5'}
                client.keyDown('shift'); client.keyPress(shift_map.get(char,char)); client.keyUp('shift')
            else:
                client.keyPress(char)
            time.sleep(0.05)
        client.keyPress('enter')
        time.sleep(15)
        client.captureScreen('/tmp/gui-test-result.png')
    finally:
        client.disconnect()
```

```bash
# VNC helpers
get_vnc_port() {
    local URL=$(sudo virsh domdisplay "$1" 2>/dev/null)
    [[ "$URL" == vnc://* ]] && echo $((5900 + $(echo "$URL" | sed 's/vnc:\/\/[^:]*://'))) || echo "SPICE"
}

capture_vm_screen() {
    local PORT=$(get_vnc_port "$1") OUTPUT="${2:-/tmp/$1-screenshot.png}"
    [[ "$PORT" == "SPICE" ]] && return 1
    python3 -c "from vncdotool import api; c=api.connect('127.0.0.1::$PORT'); c.captureScreen('$OUTPUT'); c.disconnect()"
}
```

## Phase 10a Execution Order

```bash
run_phase_V() {
    local PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
    local ISSUES_FILE="$PROJECT_DIR/vm-test-issues.log"
    > "$ISSUES_FILE"

    local MANIFEST="$PROJECT_DIR/vm-test-manifest.json"
    local DEFAULT_VM="" VM_IP="" SSH_USER="" SSH_KEY=""
    local INSTALL_SCRIPT="" UPGRADE_SCRIPT="" DEPLOY_SCRIPT="" API_PORT="" WEB_PORT=""

    # Project-VM routing via project-vm-map.json
    local VM_MAP="$HOME/.claude/config/project-vm-map.json"
    local PROJECT_NAME=$(basename "$PROJECT_DIR")

    # The VM: resolve_test_vm from the shared helpers (phase-10b-vm-lifecycle.md § Test VM Selection). This
    # phase's subagent reads only this file, so it loads them itself. Listed VMs only — no name guessed from
    # `virsh list`, no built-in default.
    source "${TEST_PHASES_DIR:-$HOME/.claude/skills/test-phases}/lib/test-vm.sh" &&
        declare -F resolve_test_vm >/dev/null ||
        { echo "ERROR: test-VM helpers not loaded (skills/test-phases/lib/test-vm.sh)"; return 2; }
    DEFAULT_VM=$(resolve_test_vm "$PROJECT_DIR") || { echo "ERROR: no usable test VM is configured (reason above)"; return 1; }

    if [[ -f "$VM_MAP" ]]; then
        INSTALL_SCRIPT=$(jq -r ".projects.\"$PROJECT_NAME\".install_script // empty" "$VM_MAP")
        UPGRADE_SCRIPT=$(jq -r ".projects.\"$PROJECT_NAME\".upgrade_script // empty" "$VM_MAP")
        DEPLOY_SCRIPT=$(jq -r ".projects.\"$PROJECT_NAME\".deploy_script // empty" "$VM_MAP")
        API_PORT=$(jq -r ".projects.\"$PROJECT_NAME\".api_port // empty" "$VM_MAP")
        VM_IP=$(jq -r ".vms.\"$DEFAULT_VM\".ip // empty" "$VM_MAP")
        SSH_USER=$(jq -r ".vms.\"$DEFAULT_VM\".ssh_user // empty" "$VM_MAP")
        SSH_KEY=$(jq -r ".vms.\"$DEFAULT_VM\".ssh_key // empty" "$VM_MAP")
    fi
    # SSH identity: the map's vms.<vm> entry, else the manifest's ssh_config. No built-in default.
    if [[ -f "$MANIFEST" ]]; then
        [[ -z "$SSH_USER" ]] && SSH_USER=$(jq -r '.vm_testing.ssh_config.user // .ssh_config.user // empty' "$MANIFEST")
        [[ -z "$SSH_KEY" ]] && SSH_KEY=$(jq -r '.vm_testing.ssh_config.key // .ssh_config.key // empty' "$MANIFEST")
    fi
    [[ -n "$SSH_USER" && -n "$SSH_KEY" ]] || {
        echo "ERROR: no SSH user/key for $DEFAULT_VM: set vms.<vm>.ssh_user and ssh_key in $VM_MAP, or ssh_config in vm-test-manifest.json"
        return 1
    }

    detect_vm_environment

    SSH_KEY="${SSH_KEY/#\~/$HOME}"
    # deploy_to_vm and run_vm_tests read the identity from VM_SSH_USER / VM_SSH_KEY
    export VM_SSH_USER="$SSH_USER" VM_SSH_KEY="$SSH_KEY"

    # Auto-detect VM IP if needed
    if [[ -z "$VM_IP" || "$VM_IP" == "null" ]]; then
        virsh domstate "$DEFAULT_VM" 2>/dev/null | grep -q running || { virsh start "$DEFAULT_VM" 2>/dev/null; sleep 30; }
        VM_IP=$(virsh domifaddr "$DEFAULT_VM" 2>/dev/null | grep -oP '192\.168\.\d+\.\d+|10\.\d+\.\d+\.\d+' | head -1)
    fi
    [[ -z "$VM_IP" ]] && { echo "Could not determine VM IP"; return 1; }

    local SSH_CMD="ssh -i $SSH_KEY -o ConnectTimeout=10 -o StrictHostKeyChecking=no $SSH_USER@$VM_IP"

    # Staged release lifecycle test
    test_staged_release_lifecycle

    # Docker staging test
    test_docker_staging

    # Legacy manifest-based tests (if no staged release)
    if [[ ! -f "$PROJECT_DIR/.staged-release" ]]; then
        reset_vm_to_clean "$DEFAULT_VM" || true

        # Fresh install on pristine VM if needed
        local PRISTINE_CHECK="getent passwd \$(whoami)"
        [[ -f "$MANIFEST" ]] && PRISTINE_CHECK=$(jq -r '.vm_testing.install.detects_pristine_by // "getent passwd \$(whoami)"' "$MANIFEST" 2>/dev/null)
        if ! $SSH_CMD "$PRISTINE_CHECK" &>/dev/null 2>&1; then
            local ICMD=""
            [[ -f "$MANIFEST" ]] && ICMD=$(jq -r '.vm_testing.install.command // empty' "$MANIFEST" 2>/dev/null)
            [[ -z "$ICMD" && -f "$PROJECT_DIR/install.sh" ]] && ICMD="./install.sh --system"
            if [[ -n "$ICMD" ]]; then
                rsync -az --exclude='.git' --exclude='venv' --exclude='__pycache__' --exclude='.snapshots' \
                    -e "ssh -i $SSH_KEY -o StrictHostKeyChecking=no" "$PROJECT_DIR/" "$SSH_USER@$VM_IP:/tmp/fresh-install/"
                $SSH_CMD "cd /tmp/fresh-install && sudo bash -c '$ICMD'" 2>&1 || { echo "Fresh install failed" >> "$ISSUES_FILE"; return 1; }
                $SSH_CMD "rm -rf /tmp/fresh-install" 2>/dev/null
            fi
        fi

        deploy_to_vm "$DEFAULT_VM" || { echo "Deploy failed" >> "$ISSUES_FILE"; return 1; }
        [[ -f "$PROJECT_DIR/install.sh" ]] && run_vm_tests "$DEFAULT_VM" "install" || echo "Install test failed" >> "$ISSUES_FILE"

        # Run dangerous operation tests from manifest
        if [[ -f "$MANIFEST" ]]; then
            local DANGEROUS=$(jq -r '.vm_testing.dangerous_operations[]? // empty' "$MANIFEST")
            echo "$DANGEROUS" | grep -q "pam_modification" && run_vm_tests "$DEFAULT_VM" "pam" || echo "PAM test failed" >> "$ISSUES_FILE"
            echo "$DANGEROUS" | grep -q "systemd_service_install" && run_vm_tests "$DEFAULT_VM" "systemd" || echo "systemd test failed" >> "$ISSUES_FILE"
            echo "$DANGEROUS" | grep -q "reboot_required" && run_vm_tests "$DEFAULT_VM" "reboot" || echo "Reboot test failed" >> "$ISSUES_FILE"
        fi
    fi

    # Summary
    if [[ -s "$ISSUES_FILE" ]]; then
        echo "Issues found:"; cat "$ISSUES_FILE"; return 1
    else
        echo "All VM tests passed"; rm -f "$ISSUES_FILE"; return 0
    fi
}
```

## Project-VM Routing

Phase 10a chooses the VM with `resolve_test_vm` (`skills/test-phases/lib/test-vm.sh`; `phase-10b-vm-lifecycle.md` § Test VM Selection), which reads `~/.claude/config/project-vm-map.json` and the project's `vm-test-manifest.json`. Whatever is chosen must be listed under the map's `vms`:

| Scenario | VM Used |
| --- | --- |
| Project has dedicated VM | `projects.<name>.vm` |
| No map entry, manifest names one | manifest `vm_testing.default_vm` |
| Neither | `default.vm` |
| Nothing configured | ERROR (no built-in default, no name guessed from `virsh list`) |
| Chosen VM not listed under the map's `vms` (or no map) | ERROR |
| Chosen VM exclusive to another project | ERROR |

**Exclusivity:** `exclusive_to` is bidirectional: only that project uses the VM, and it uses only that VM.

## Conditional Execution Summary

**Runs when:** manifest `enabled: true`, dangerous operations, `--phase=V`, staged release, isolation `vm-required`/`vm-recommended`.

**Skipped when:** no VMs, no libvirt, no install scripts/dangerous ops/staged release, isolation `sandbox`/`sandbox-warn`.
