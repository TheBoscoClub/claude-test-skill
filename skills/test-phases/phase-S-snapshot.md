# Phase S: BTRFS Snapshot

Create a read-only safety snapshot before making changes.

## Prerequisites

- Project must be on a BTRFS filesystem
- User must have sudo access for btrfs commands
- Snapshot directory must exist: `/snapshots/audit/`

## Execution

```bash
PROJECT_DIR="$(pwd)"
PROJECT_NAME="$(basename $PROJECT_DIR)"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
SNAPSHOT_DIR="/snapshots/audit"
SNAPSHOT_PATH="$SNAPSHOT_DIR/audit-$TIMESTAMP-$PROJECT_NAME"

# Verify BTRFS
if ! df -T "$PROJECT_DIR" | grep -q btrfs; then
  echo "⚠️ Not a BTRFS filesystem - skipping snapshot"
  exit 0
fi

# Create snapshot directory if needed
sudo mkdir -p "$SNAPSHOT_DIR"

# Create read-only snapshot
sudo btrfs subvolume snapshot -r "$PROJECT_DIR" "$SNAPSHOT_PATH"

echo "✅ Snapshot created: $SNAPSHOT_PATH"
```

## Recovery

To restore from snapshot:
```bash
# Delete current (if needed)
sudo btrfs subvolume delete "$PROJECT_DIR"

# Restore from snapshot (creates writable copy)
sudo btrfs subvolume snapshot "$SNAPSHOT_PATH" "$PROJECT_DIR"
```

## Output

Report:
- Snapshot path created
- Snapshot size
- Command to restore if needed
