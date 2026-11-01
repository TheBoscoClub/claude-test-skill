# Phase 10b: VM Lifecycle Management

> **Model**: `sonnet` | **Phase**: 10b | **Modifies Files**: No (manages VMs)
> **Task Tracking**: Call `TaskUpdate(taskId, status="in_progress")` at start, `TaskUpdate(taskId, status="completed")` when done.
> **Key Tools**: `Bash` for virsh commands (use `timeout` for hung operations). Use `AskUserQuestion` if VM fails to start and user needs to choose alternative.

Automatic VM startup/shutdown for isolated testing.

## Purpose

- **Start** the test VM when Phase 2/3 requires VM isolation
- **Detect dirty VMs**: a `post_test_restore=true` VM running at startup means an interrupted test; revert to pristine first
- **Track** whether `/test` started the VM
- **Cleanup (Phase 11)**: `post_test_restore=true` VMs: shut down only, do NOT revert (revert happens at the START of the next run, preserving post-test state). Shared VMs: shut down only if `/test` started it

### Expected VM States

| When | post_test_restore=true VM | Shared VM |
| --- | --- | --- |
| Before `/test` | **Shut down (dirty from the last run, or pristine)** | Running or shut down |
| Startup (this phase) | **Reverted to pristine, then started** — a running VM is force-stopped first | Running or shut down |
| During `/test` | Running (started by /test) | Running |
| After Phase 11 | **Shut down (dirty)** | Restored to original state |

## Test VM Selection

The test VM is always one the installation lists, never one guessed from `virsh list` (a name match would pick a VM reserved for another project). `resolve_test_vm` is the only place it is chosen. It lives in the shared helpers file `skills/test-phases/lib/test-vm.sh`, which Phase 1 (pre-test snapshot sweep), Phase 10a, this phase and Phase 11 (shutdown) each source themselves — each phase runs in its own subagent and reads only its own phase file. There is no built-in default VM.

Precedence, first non-empty wins:

1. `~/.claude/config/project-vm-map.json` `projects.<project>.vm`
2. the project's `vm-test-manifest.json` `vm_testing.default_vm`
3. the map's `default.vm`

It refuses (returns 1, reason on stderr) when nothing is configured; when the map is missing, unreadable, or not a JSON object; when any VM's `exclusive_to` is not null, a project name or a non-empty list of project names (an unreadable lock never reads as "no lock"); when a configured name is not a well-formed VM name (`[A-Za-z0-9][A-Za-z0-9._-]*`, taken exactly as written — never trimmed); when the chosen VM's map entry has `"role": "qa"` (QA VMs receive only released versions; `/test` never runs against them); when the chosen VM is not a key of the map's `vms` (a tracked manifest can choose among the VMs the installation lists, never add one); when the chosen VM is `exclusive_to` other projects only; or when the project has an exclusive VM of its own and the chosen VM is not one of them (`exclusive_to` is a bidirectional lock). `check_test_vm PROJECT_DIR VM` applies the same name, `vms`, QA and exclusivity checks to a VM named some other way (Phase 10a cross-distro testing, the `.test-vm-state` read by both shutdowns), on exactly the string it is given. State-file values are read with `test_vm_state_get FILE KEY` (the value as stored; a repeated key reads as unset), so the name checked is the name every `virsh` call then receives.

Load the helpers before calling any of them, and tell "not loaded" apart from "not configured":

```bash
source "${TEST_PHASES_DIR:-$HOME/.claude/skills/test-phases}/lib/test-vm.sh" &&
    declare -F resolve_test_vm >/dev/null ||
    { echo "ERROR: test-VM helpers not loaded (skills/test-phases/lib/test-vm.sh)"; return 2; }
```

The only snapshot delete the skill issues is `delete_pretest_snapshot VM NAME [PROJECT_DIR]` from the same file: it refuses any name that is not `pre-test-YYYYMMDD-HHMMSS`, any name containing `pristine` (any case), and a configured pristine snapshot (the manifest's `vm_testing.pristine_snapshot` or the map's `vms.<vm>.pristine_snapshot`; an unreadable manifest or map refuses), each check on its own, so a pristine snapshot is never deleted.

## VM Lifecycle State File

State file `.test-vm-state` in the project directory.

## Start VM (Called after Discovery)

```bash
start_test_vm() {
    local PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
    local ISOLATION_LEVEL="${ISOLATION_LEVEL:-sandbox}"
    local STATE_FILE="${PROJECT_DIR}/.test-vm-state"

    local VM_MAP="$HOME/.claude/config/project-vm-map.json"

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

    # The test VM: only one the installation lists (resolve_test_vm, § Test VM Selection).
    # No fallback to a name taken from `virsh list` — it could be another project's exclusive VM.
    source "${TEST_PHASES_DIR:-$HOME/.claude/skills/test-phases}/lib/test-vm.sh" &&
        declare -F resolve_test_vm >/dev/null ||
        { echo "  ⛔ ERROR: test-VM helpers not loaded (skills/test-phases/lib/test-vm.sh)"; return 2; }
    local VM_NAME=""
    if ! VM_NAME=$(resolve_test_vm "$PROJECT_DIR"); then
        echo "  ⛔ ABORT: no usable test VM is configured (reason above)"
        return 1
    fi

    if ! virsh dominfo "$VM_NAME" &>/dev/null; then
        echo "  ❌ Configured test VM is not defined in libvirt: $VM_NAME"
        if [[ "$ISOLATION_LEVEL" == "vm-required" ]]; then
            echo "  ⛔ ABORT: VM isolation required but no VM available"
            echo ""
            echo "  To create a test VM:"
            echo "    1. Put an install ISO in the directory named by paths.iso_dir in $VM_MAP"
            echo "    2. Create the VM with virt-install or virt-manager"
            echo "    3. Name it in $VM_MAP (default.vm, or projects.<project>.vm)"
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

    # Read external qcow2 pristine config from project-vm-map.json
    local PRISTINE_TYPE=""
    local PRISTINE_PATH=""
    local ACTIVE_DISK=""
    if [[ -f "$VM_MAP" ]]; then
        local PROJECT_NAME_FOR_MAP=$(basename "$PROJECT_DIR")
        PRISTINE_TYPE=$(python3 -c "
import json; d=json.load(open('$VM_MAP'))
# Check project-level first, then VM-level
p = d.get('projects',{}).get('$PROJECT_NAME_FOR_MAP',{}).get('pristine_type','')
if not p:
    p = d.get('vms',{}).get('$VM_NAME',{}).get('pristine_type','')
print(p)" 2>/dev/null)
        PRISTINE_PATH=$(python3 -c "
import json; d=json.load(open('$VM_MAP'))
p = d.get('projects',{}).get('$PROJECT_NAME_FOR_MAP',{}).get('pristine_path','')
if not p:
    p = d.get('vms',{}).get('$VM_NAME',{}).get('pristine_path','')
print(p)" 2>/dev/null)
        ACTIVE_DISK=$(python3 -c "
import json; d=json.load(open('$VM_MAP'))
p = d.get('projects',{}).get('$PROJECT_NAME_FOR_MAP',{}).get('active_disk','')
if not p:
    p = d.get('vms',{}).get('$VM_NAME',{}).get('active_disk','')
print(p)" 2>/dev/null)
    fi

    # ─── EXTERNAL QCOW2 VALIDATION (manual-recovery source; /test never restores from it) ────
    if [[ "$PRISTINE_TYPE" == "external_qcow2" ]]; then
        if [[ ! -f "$PRISTINE_PATH" ]]; then
            echo "  ⛔ ABORT: External pristine qcow2 not found: $PRISTINE_PATH"
            return 1
        fi
        local PRISTINE_SIZE=$(stat -c%s "$PRISTINE_PATH" 2>/dev/null || echo 0)
        if [[ "$PRISTINE_SIZE" -lt 1073741824 ]]; then
            echo "  ⛔ ABORT: External pristine qcow2 is too small ($(( PRISTINE_SIZE / 1048576 ))MB < 1GB): $PRISTINE_PATH"
            echo "     Expected a full disk image > 1GB"
            return 1
        fi
        echo "  Pristine type: external_qcow2"
        echo "  Pristine path: $PRISTINE_PATH ($(( PRISTINE_SIZE / 1073741824 ))GB)"
        echo "  Active disk:   $ACTIVE_DISK"
    fi

    # ─── DIRTY VM DETECTION ─────────────────────────────────────────
    # For post_test_restore=true projects, the VM may be dirty from
    # a previous test cycle (shut down but not reverted, or still
    # running from an interrupted run). Revert to pristine before
    # proceeding. The post-test cleanup only shuts down — revert
    # happens HERE at the start of the next test run.
    if [[ "$POST_TEST_RESTORE" == "true" ]]; then
        echo ""
        echo "  🔄 post_test_restore=true — reverting to pristine before testing"

        if [[ "$CURRENT_STATE" == "running" ]]; then
            echo "  ⚠️  VM is running — likely dirty from an interrupted test cycle"
            # Force stop the dirty VM
            sudo virsh destroy "$VM_NAME" 2>/dev/null || true
        fi

        echo "     Reverting to pristine snapshot: $PRISTINE_SNAP"

        # ─── PRIMARY: virsh snapshot-revert ──────────────────────────
        if sudo virsh snapshot-revert "$VM_NAME" "$PRISTINE_SNAP" 2>/dev/null; then
            echo "  ✅ Reverted to pristine via virsh snapshot-revert"
        else
            echo "  ⚠️  virsh snapshot-revert failed — internal snapshot may be corrupted"

            # ─── NO AUTOMATIC FALLBACK ───────────────────────────────────
            # Restoring from the external pristine image means overwriting the active disk (which holds
            # the internal pristine snapshot) and dropping snapshot metadata. A pristine snapshot is never
            # deleted, so /test never does this itself: it stops and names the manual recovery.
            echo "  ⛔ ABORT: cannot revert $VM_NAME to $PRISTINE_SNAP — manual recovery required"
            if [[ "$PRISTINE_TYPE" == "external_qcow2" && -n "$PRISTINE_PATH" ]]; then
                echo "     External pristine image: $PRISTINE_PATH (active disk: ${ACTIVE_DISK:-not set})"
                echo "     Restore it by hand following the pristine-restore procedure; /test does not overwrite disks"
            fi
            return 1
        fi

        CURRENT_STATE="shutoff"
    fi

    # Record original state for cleanup
    local STARTED_BY_TEST="false"

    if [[ "$CURRENT_STATE" == "running" ]]; then
        # Only reached for non-post_test_restore VMs (e.g., a shared default VM)
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

    # Create pre-test snapshot (MANDATORY for legacy snapshot VMs)
    # For external_qcow2 VMs, the pristine file IS the restore point — no libvirt snapshot needed
    if [[ "$PRISTINE_TYPE" == "external_qcow2" ]]; then
        echo ""
        echo "  📸 Pre-test snapshot: SKIPPED (external qcow2 — pristine file is the restore point)"
        echo "pristine_type=external_qcow2" >> "$STATE_FILE"
        echo "pristine_path=$PRISTINE_PATH" >> "$STATE_FILE"
        echo "active_disk=$ACTIVE_DISK" >> "$STATE_FILE"
    else
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

No test VM may have LIVE ACCESS to production storage.

- **NEVER** configure NFS, CIFS, virtiofs, or virtio-9p mounts from host production paths into the VM
- Copying data *into* the VM (scp, rsync) is fine
- Test VM data libraries live on the VM's own disk and must fit within it

## Install on Pristine VM (Called after VM boots)

A VM started from a pristine snapshot (OS + deps, no app) must be bootstrapped before tests. The function:

1. Detects app presence via `detects_pristine_by` in `vm-test-manifest.json`
2. If pristine AND `install.required_on_pristine: true`: copies the project to the VM and runs the install command non-interactively (e.g., `install.sh --system`)
3. Any service user/group is a no-login account created by the install script

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

    # SSH identity: the map's vms.<vm> entry (the installation knows its VMs), else the manifest's
    # ssh_config — the same order as Phase 10a run_phase_V. No built-in default.
    local VM_MAP="$HOME/.claude/config/project-vm-map.json"
    local SSH_USER=$(jq -r --arg vm "$VM_NAME" '.vms[$vm].ssh_user // empty | strings' "$VM_MAP" 2>/dev/null)
    local SSH_KEY=$(jq -r --arg vm "$VM_NAME" '.vms[$vm].ssh_key // empty | strings' "$VM_MAP" 2>/dev/null)
    [[ -z "$SSH_USER" ]] && SSH_USER=$(jq -r '.vm_testing.ssh_config.user // .ssh_config.user // empty | strings' "$MANIFEST" 2>/dev/null)
    [[ -z "$SSH_KEY" ]] && SSH_KEY=$(jq -r '.vm_testing.ssh_config.key // .ssh_config.key // empty | strings' "$MANIFEST" 2>/dev/null)
    if [[ -z "$SSH_USER" || -z "$SSH_KEY" ]]; then
        echo "  ❌ No SSH user/key for $VM_NAME: set vms.<vm>.ssh_user and ssh_key in $VM_MAP, or ssh_config in vm-test-manifest.json"
        return 1
    fi
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

    # Verify: every enabled timer matching the manifest's unit_pattern is also
    # active. Catches the "enable without --now" class of upgrade bug:
    # a new release adds a timer, install/upgrade
    # creates the .wants/ symlink, but the unit never gets started in the
    # current boot — so the feature is silently broken until the next reboot.
    # `is-enabled` alone passes; we need is-active too.
    #
    # Manifest opt-in (vm-test-manifest.json):
    #   "vm_testing": { "install": {
    #     "assert_enabled_timers_active": {
    #         "unit_pattern": "myapp-*"   # systemctl glob; matches install scope
    #     }
    #   }}
    #
    # Shutdown-only units (WantedBy=halt.target reboot.target shutdown.target
    # *only*) are exempted — they are designed to activate at shutdown, not at
    # boot, so 'enabled but inactive' is correct for them.
    local UNIT_PATTERN=$(python3 -c "import json; d=json.load(open('$MANIFEST')); print(d.get('vm_testing',{}).get('install',{}).get('assert_enabled_timers_active',{}).get('unit_pattern',''))" 2>/dev/null)
    if [[ -n "$UNIT_PATTERN" ]]; then
        echo "  Verifying enabled timers are active (pattern: ${UNIT_PATTERN})..."
        # Probe per-unit on the VM. We split into two SSH commands for clarity:
        # (1) list enabled timer files matching the pattern, (2) check is-active
        # for each. Keeping the inner shell snippet single-quoted avoids host-side
        # globbing of $UNIT_PATTERN.
        local TIMER_RESULT
        TIMER_RESULT=$($SSH_CMD "bash -s" <<REMOTE_PROBE
set -u
shopt -s nullglob
fail=0
for unit_path in /etc/systemd/system/${UNIT_PATTERN}.timer; do
    [[ -f "\$unit_path" ]] || continue
    unit=\$(basename "\$unit_path")
    state=\$(systemctl is-enabled "\$unit" 2>/dev/null || echo unknown)
    [[ "\$state" == "enabled" ]] || continue
    active=\$(systemctl is-active "\$unit" 2>/dev/null || echo unknown)
    if [[ "\$active" != "active" ]]; then
        echo "  ⚠️  enabled but \$active: \$unit"
        fail=1
    fi
done
exit \$fail
REMOTE_PROBE
        )
        local TIMER_EXIT=$?
        if [[ $TIMER_EXIT -eq 0 ]]; then
            echo "  ✅ All enabled timers are active"
        else
            echo "  ❌ One or more enabled timers are NOT active (see above)"
            echo "$TIMER_RESULT"
            echo "     This is the 'enable without --now' bug class."
            echo "     Fix: install/upgrade scripts must use 'enable --now' for runtime units."
            return 1
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
        echo "  Dockerfile detected — Docker container DB will be initialized by Phase 9c"
    fi

    echo ""
}
```

## Shutdown VM (Called during Phase 11 Cleanup)

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

    # The state file is data, not authority: a snapshot it names is reverted to or deleted only when it is a
    # pre-test name (delete_pretest_snapshot, lib/test-vm.sh). Anything else — "pristine", the manifest's
    # pristine_snapshot, a hand edit — is reported and left alone.
    source "${TEST_PHASES_DIR:-$HOME/.claude/skills/test-phases}/lib/test-vm.sh" &&
        declare -F delete_pretest_snapshot check_test_vm test_vm_state_get is_pretest_snapshot >/dev/null ||
        { echo "  ⛔ ERROR: test-VM helpers not loaded (skills/test-phases/lib/test-vm.sh) — VM left as is"; return 2; }

    # Read the state file. vm_name and pre_test_snapshot are read exactly as stored (test_vm_state_get: no
    # trimming, a duplicated key reads as unset), so the name check_test_vm validates is the name acted on.
    local VM_NAME STARTED_BY_TEST ORIGINAL_STATE PRE_TEST_SNAPSHOT
    VM_NAME=$(test_vm_state_get "$STATE_FILE" vm_name)
    STARTED_BY_TEST=$(grep "^started_by_test=" "$STATE_FILE" | cut -d= -f2)
    ORIGINAL_STATE=$(grep "^original_state=" "$STATE_FILE" | cut -d= -f2)
    PRE_TEST_SNAPSHOT=$(test_vm_state_get "$STATE_FILE" pre_test_snapshot)
    # The VM it names gets the same check: only a VM this project may use (listed under vms, exclusivity
    # honoured) is stopped, reverted or has a snapshot deleted. A stale or foreign state file is left in place.
    check_test_vm "$PROJECT_DIR" "$VM_NAME" ||
        { echo "  ⛔ $STATE_FILE names $VM_NAME, not a VM this project may use — left alone (state file kept)"; return 1; }
    if [[ -n "$PRE_TEST_SNAPSHOT" ]] && ! is_pretest_snapshot "$PRE_TEST_SNAPSHOT"; then
        echo "  ⛔ $STATE_FILE names pre_test_snapshot=$PRE_TEST_SNAPSHOT, which is not a pre-test-YYYYMMDD-HHMMSS name"
        echo "     Not reverting to it and not deleting it"
        PRE_TEST_SNAPSHOT=""
    fi

    echo "  VM: $VM_NAME"
    echo "  Started by /test: $STARTED_BY_TEST"
    echo "  Original State: $ORIGINAL_STATE"
    echo "  Pre-test Snapshot: ${PRE_TEST_SNAPSHOT:-none}"
    echo ""

    # Check vm-test-manifest.json for project-specific config
    local PRISTINE_SNAP=""
    local POST_TEST_RESTORE="false"
    if [[ -f "${PROJECT_DIR}/vm-test-manifest.json" ]]; then
        PRISTINE_SNAP=$(python3 -c "import json; d=json.load(open('${PROJECT_DIR}/vm-test-manifest.json')); print(d.get('vm_testing',{}).get('pristine_snapshot',''))" 2>/dev/null)
        POST_TEST_RESTORE=$(python3 -c "import json; d=json.load(open('${PROJECT_DIR}/vm-test-manifest.json')); print(str(d.get('vm_testing',{}).get('post_test_restore', False)).lower())" 2>/dev/null)
    fi

    if [[ "$POST_TEST_RESTORE" == "true" ]]; then
        echo "  post_test_restore=true — shutting down VM only (preserving post-test state)"
        echo "  Will revert to pristine at start of next test run."
        echo ""

        # Graceful shutdown with force-stop fallback
        local CURRENT_STATE=$(virsh domstate "$VM_NAME" 2>/dev/null | tr -d '[:space:]')
        if [[ "$CURRENT_STATE" == "running" ]]; then
            echo "  Attempting graceful shutdown..."
            sudo virsh shutdown "$VM_NAME" 2>/dev/null

            local WAIT_COUNT=0
            while [[ $WAIT_COUNT -lt 12 ]]; do
                sleep 5
                CURRENT_STATE=$(virsh domstate "$VM_NAME" 2>/dev/null | tr -d '[:space:]')
                if [[ "$CURRENT_STATE" != "running" ]]; then
                    echo "  ✅ VM shut down gracefully"
                    break
                fi
                ((WAIT_COUNT++))
                echo "    Waiting... ($((WAIT_COUNT * 5))s)"
            done

            if [[ "$CURRENT_STATE" == "running" ]]; then
                echo "  ⚠️ Graceful shutdown timeout — forcing stop..."
                sudo virsh destroy "$VM_NAME" 2>/dev/null || true
                echo "  ✅ VM force stopped"
            fi
        else
            echo "  ✅ VM already stopped"
        fi

        echo "  ✅ VM shut down. Will revert to pristine at start of next test run."
        rm -f "${STATE_FILE:?}"
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
            if delete_pretest_snapshot "$VM_NAME" "$PRE_TEST_SNAPSHOT" "$PROJECT_DIR"; then
                echo "  ✅ Pre-test snapshot deleted"
            else
                echo "  ⚠️ Failed to delete snapshot (the next /test Phase 1 sweep removes it)"
            fi
        else
            echo "  ❌ Failed to revert to pre-test snapshot — kept as the only way back"
            echo "     VM may have accumulated test artifacts; the next /test Phase 1 sweep deletes the snapshot"
        fi
    fi
    echo ""

    # Only shutdown if we started it
    if [[ "$STARTED_BY_TEST" != "true" ]]; then
        echo "  ✓ VM was already running - leaving it running"
        echo "    (VM was not started by /test)"
        rm -f "${STATE_FILE:?}"
        return 0
    fi

    # Check if VM is still running
    local CURRENT_STATE=$(virsh domstate "$VM_NAME" 2>/dev/null | tr -d '[:space:]')

    if [[ "$CURRENT_STATE" != "running" ]]; then
        echo "  ✓ VM already stopped"
        rm -f "${STATE_FILE:?}"
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
            rm -f "${STATE_FILE:?}"
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
    rm -f "${STATE_FILE:?}"
    echo ""
    echo "  📝 Removed state file: $STATE_FILE"
    echo ""

    # Summary
    echo "VM Cleanup Complete:"
    echo "  - VM $VM_NAME stopped"
    echo "  - System resources freed (the VM's RAM and vCPUs)"
}
```

## Integration Points

### After Phase 3 (Discovery) Completes

Dispatcher calls `start_test_vm` when `ISOLATION_LEVEL` is `vm-required` or `vm-recommended` AND Phase 2 detected `VM_AVAILABLE=true`:

```text
# In dispatcher, after Discovery completes:
if [[ "$ISOLATION_LEVEL" =~ ^vm-(required|recommended)$ ]] && [[ "$VM_AVAILABLE" == "true" ]]; then
    # Load and execute VM startup
    source ~/.claude/skills/test-phases/phase-10b-vm-lifecycle.md
    start_test_vm
fi
```

### During Phase 11 (Cleanup)

Phase 11 runs its own `shutdown_test_vm` (`phase-11-cleanup.md` § 3a); the function above is this phase's
copy. Both call `check_test_vm` on the VM `.test-vm-state` names before any `virsh` call: a VM that fails the
check (malformed name, not listed under `vms`, a QA VM, or exclusive to another project) is left alone, the state file stays in place
and the function returns 1.

## State File Format

`.test-vm-state` keys: `vm_name`, `started_by_test`, `original_state`, `isolation_level`, `start_time`, `vm_ip`, `vnc_port`, `pre_test_snapshot` (plus `pristine_type`, `pristine_path`, `active_disk` for external_qcow2).

## Report Format

Report the echo output of `start_test_vm` / `shutdown_test_vm` as printed.

### Startup Report

Banner, isolation level, selected VM, state, boot, state file, VM IP, VNC, pre-test snapshot, "VM READY FOR TESTING".

### Cleanup Report (post_test_restore=true)

VM info, "shutting down VM only (preserving post-test state)", graceful shutdown, state file removed.

### Cleanup Report (refused)

`names VM, not a VM this project may use — left alone (state file kept)`, after the reason from `check_test_vm`.

### Cleanup Report (shared VM)

VM info, revert to pre-test snapshot, snapshot deleted, shutdown, state file removed, "VM Cleanup Complete".

## Manual Override

Keep the VM running after /test:

```bash
# Before running /test:
export TEST_KEEP_VM_RUNNING=true
```

Or add to `vm-test-manifest.json`:

```json
{
  "vm_testing": {
    "keep_running_after_test": true
  }
}
```
