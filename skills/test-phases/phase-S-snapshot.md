# Phase S: Safety Snapshots (BTRFS + VM)

> **Model**: `haiku` | **Tier**: 0 (Pre-test) | **Modifies Files**: No (creates snapshot)
> **Task Tracking**: Call `TaskUpdate(taskId, status="in_progress")` at start, `TaskUpdate(taskId, status="completed")` when done.
> **Key Tools**: `Bash` for btrfs/virsh commands. Use `Bash` with `timeout` if a snapshot command hangs.

Create read-only safety snapshots before making changes.

## Prerequisites

- Project must be on a BTRFS filesystem
- User must have sudo access for btrfs and virsh commands

## Execution

### Step 1: Clean Up Prior Audit Snapshots (MANDATORY)

Before creating a new snapshot, scan for existing audit/pre-test snapshots and delete any whose purpose has been fulfilled. This is the **primary and authoritative** snapshot cleanup mechanism (see `~/.claude/rules/projects.md`).

```bash
PROJECT_DIR="$(pwd)"
PROJECT_NAME="$(basename $PROJECT_DIR)"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
SNAPSHOT_DIR="${PROJECT_DIR}/.snapshots"

# Clean up prior snapshots whose fixes have been committed/released
if [[ -d "$SNAPSHOT_DIR" ]]; then
  HAS_REMOTE=$(git -C "$PROJECT_DIR" remote -v 2>/dev/null | head -1)

  for snap in "$SNAPSHOT_DIR"/snap-pre-test-* "$SNAPSHOT_DIR"/audit-*; do
    [[ -e "$snap" ]] || continue
    SNAP_NAME="$(basename "$snap")"

    if [[ -n "$HAS_REMOTE" ]]; then
      # GitHub project: keep until fixes are in a release
      # Check if any release tag exists that post-dates the snapshot
      SNAP_DATE=$(echo "$SNAP_NAME" | grep -oP '\d{8}')
      if [[ -n "$SNAP_DATE" ]]; then
        LATEST_TAG=$(git -C "$PROJECT_DIR" tag --sort=-creatordate 2>/dev/null | head -1)
        if [[ -n "$LATEST_TAG" ]]; then
          TAG_DATE=$(git -C "$PROJECT_DIR" log -1 --format='%Y%m%d' "$LATEST_TAG" 2>/dev/null)
          if [[ -n "$TAG_DATE" ]] && [[ "$TAG_DATE" -ge "$SNAP_DATE" ]]; then
            echo "  Deleting $SNAP_NAME (fixes included in release $LATEST_TAG)"
            sudo btrfs subvolume delete "$snap" 2>/dev/null
            continue
          fi
        fi
      fi
      echo "  Keeping $SNAP_NAME (fixes not yet in a GitHub release)"
    else
      # Local-only project: keep until fixes are committed
      # Check if there are uncommitted changes
      UNCOMMITTED=$(git -C "$PROJECT_DIR" status --porcelain 2>/dev/null | wc -l)
      if [[ "$UNCOMMITTED" -eq 0 ]]; then
        echo "  Deleting $SNAP_NAME (all changes committed, local-only project)"
        sudo btrfs subvolume delete "$snap" 2>/dev/null
      else
        echo "  Keeping $SNAP_NAME (uncommitted changes exist)"
      fi
    fi
  done
fi
```

### Step 2: Create BTRFS Project Snapshot

Snapshots are stored inside the project directory at `.snapshots/` to avoid polluting the top-level projects directory.

**Naming convention**: `snap-pre-test-YYYYMMDD-HHMMSS` (enforced below).

```bash
SNAPSHOT_PATH="$SNAPSHOT_DIR/snap-pre-test-$TIMESTAMP"

# Verify BTRFS filesystem
# Use df -T as primary method, fall back to btrfs subvolume show
FSTYPE=$(df -T "$PROJECT_DIR" 2>/dev/null | tail -1 | awk '{print $2}')
if [[ "$FSTYPE" != "btrfs" ]]; then
  # Fallback: check if btrfs subvolume show succeeds (works for nested subvolumes)
  if ! sudo btrfs subvolume show "$PROJECT_DIR" &>/dev/null; then
    echo "Not a BTRFS filesystem ($FSTYPE) - skipping BTRFS snapshot"
    SNAPSHOT_PATH=""
  else
    echo "BTRFS detected via subvolume check (df reported: $FSTYPE)"
  fi
fi

if [[ -n "$SNAPSHOT_PATH" ]]; then
  # Check available disk space before creating snapshot (need at least 1 GB free)
  AVAIL_KB=$(df "$PROJECT_DIR" 2>/dev/null | tail -1 | awk '{print $4}')
  if [[ -n "$AVAIL_KB" ]] && [[ "$AVAIL_KB" -lt 1048576 ]]; then
    echo "⚠️ Low disk space ($(( AVAIL_KB / 1024 )) MB free) — snapshot may fail"
    echo "   Proceeding anyway (BTRFS snapshots are COW and initially use no extra space)"
  fi

  # Create snapshot directory if needed
  mkdir -p "$SNAPSHOT_DIR"

  # Create read-only snapshot
  sudo btrfs subvolume snapshot -r "$PROJECT_DIR" "$SNAPSHOT_PATH"

  echo "BTRFS snapshot created: $SNAPSHOT_PATH"
fi
```

### VM Snapshot

Detects the project's test VM from `vm-test-manifest.json` or `project-vm-map.json`.

```bash
# Determine the project's test VM
VM_NAME="test-vm-cachyos"  # default
if [[ -f "vm-test-manifest.json" ]]; then
  VM_NAME=$(python3 -c "import json; d=json.load(open('vm-test-manifest.json')); print(d.get('vm_testing',{}).get('default_vm','test-vm-cachyos'))" 2>/dev/null)
fi

if command -v virsh &>/dev/null && sudo virsh dominfo "$VM_NAME" &>/dev/null 2>&1; then
  VM_STATE=$(sudo virsh domstate "$VM_NAME" 2>/dev/null | tr -d '[:space:]')
  SNAP_NAME="pre-test-$TIMESTAMP"
  SNAP_DESC="Pre-test snapshot for ${PROJECT_NAME} v$(cat VERSION 2>/dev/null || echo 'unknown')"

  if sudo virsh snapshot-create-as "$VM_NAME" "$SNAP_NAME" "$SNAP_DESC"; then
    echo "VM snapshot created: $SNAP_NAME on $VM_NAME (state: $VM_STATE)"
  else
    echo "VM snapshot failed (non-fatal) - continuing"
  fi
else
  echo "virsh not available or $VM_NAME not found - skipping VM snapshot"
fi
```

## Recovery

### Restore BTRFS Snapshot
```bash
# Delete current (if needed)
sudo btrfs subvolume delete "$PROJECT_DIR"

# Restore from snapshot (creates writable copy)
sudo btrfs subvolume snapshot "$SNAPSHOT_PATH" "$PROJECT_DIR"
```

### Restore VM Snapshot
```bash
# List available snapshots
sudo virsh snapshot-list $VM_NAME

# Revert to pre-test snapshot
sudo virsh snapshot-revert $VM_NAME "pre-test-YYYYMMDD-HHMMSS"

# Delete a snapshot (optional cleanup)
sudo virsh snapshot-delete $VM_NAME "pre-test-YYYYMMDD-HHMMSS"

# For projects with post_test_restore=true in vm-test-manifest.json,
# the Phase C cleanup automatically restores the VM to its pristine
# snapshot (e.g., pristine-275g-2026-02-25) after testing completes.
```

## Snapshot Naming Convention

All BTRFS snapshots created by Phase S follow this pattern:
- **Location**: `$PROJECT_DIR/.snapshots/`
- **Name**: `snap-pre-test-YYYYMMDD-HHMMSS`
- **Type**: Read-only (`-r` flag)

Phase S (this phase) handles snapshot cleanup before creating new ones. Using a different location or naming pattern will cause the cleanup scan to miss old snapshots.

## Output

Report:
- BTRFS snapshot path created
- VM snapshot name and VM state at time of snapshot
- Commands to restore if needed
