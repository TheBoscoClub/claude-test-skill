# Phase S: Safety Snapshots (BTRFS + VM)

Create read-only safety snapshots before making changes.

## Prerequisites

- Project must be on a BTRFS filesystem
- User must have sudo access for btrfs and virsh commands
- Snapshot directory must exist: `/snapshots/audit/`

## Execution

### BTRFS Project Snapshot

```bash
PROJECT_DIR="$(pwd)"
PROJECT_NAME="$(basename $PROJECT_DIR)"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
SNAPSHOT_DIR="/snapshots/audit"
SNAPSHOT_PATH="$SNAPSHOT_DIR/audit-$TIMESTAMP-$PROJECT_NAME"

# Verify BTRFS (use stat -f which works reliably for nested subvolumes)
# Note: df -T can fail for nested subvolumes, showing "-" instead of "btrfs"
FSTYPE=$(stat -f -c %T "$PROJECT_DIR" 2>/dev/null || echo "unknown")
if [[ "$FSTYPE" != "btrfs" ]]; then
  # Fallback: check if btrfs subvolume show succeeds
  if ! sudo btrfs subvolume show "$PROJECT_DIR" &>/dev/null; then
    echo "Not a BTRFS filesystem ($FSTYPE) - skipping BTRFS snapshot"
    SNAPSHOT_PATH=""
  fi
fi

if [[ -n "$SNAPSHOT_PATH" ]]; then
  # Create snapshot directory if needed
  sudo mkdir -p "$SNAPSHOT_DIR"

  # Create read-only snapshot
  sudo btrfs subvolume snapshot -r "$PROJECT_DIR" "$SNAPSHOT_PATH"

  echo "BTRFS snapshot created: $SNAPSHOT_PATH"
fi
```

### VM Snapshot (example-test-vm)

```bash
if command -v virsh &>/dev/null && sudo virsh dominfo example-test-vm &>/dev/null 2>&1; then
  VM_STATE=$(sudo virsh domstate example-test-vm 2>/dev/null | tr -d '[:space:]')
  SNAP_NAME="pre-test-$TIMESTAMP"
  SNAP_DESC="Pre-test snapshot for ${PROJECT_NAME} v$(cat VERSION 2>/dev/null || echo 'unknown')"

  if sudo virsh snapshot-create-as example-test-vm "$SNAP_NAME" "$SNAP_DESC"; then
    echo "VM snapshot created: $SNAP_NAME (state: $VM_STATE)"
  else
    echo "VM snapshot failed (non-fatal) - continuing"
  fi
else
  echo "virsh not available or example-test-vm not found - skipping VM snapshot"
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
sudo virsh snapshot-list example-test-vm

# Revert to a specific snapshot
sudo virsh snapshot-revert example-test-vm "pre-test-YYYYMMDD-HHMMSS"

# Delete a snapshot (optional cleanup)
sudo virsh snapshot-delete example-test-vm "pre-test-YYYYMMDD-HHMMSS"
```

## Output

Report:
- BTRFS snapshot path created
- VM snapshot name and VM state at time of snapshot
- Commands to restore if needed
