# Phase 1: Safety Snapshot (BTRFS) + VM Pre-Test Sweep

> **Model**: `haiku` | **Phase**: 1 | **Modifies Files**: No (creates a BTRFS snapshot; deletes leftover VM pre-test snapshots)
> **Task Tracking**: Call `TaskUpdate(taskId, status="in_progress")` at start, `TaskUpdate(taskId, status="completed")` when done.
> **Key Tools**: `Bash` for btrfs/virsh commands. Use `Bash` with `timeout` if a snapshot command hangs.

Create a read-only BTRFS safety snapshot before making changes, and sweep the project VM of `pre-test-*` internal snapshots left by earlier runs. Phase 1 does NOT create a VM snapshot: Phase 10b creates, records and deletes the one for this run (claude-test-skill-hyx, 2026-10-08 — Phase 1 used to create a second one that nothing ever deleted).

## Prerequisites

- Project on a BTRFS filesystem
- sudo for btrfs and virsh

## Execution

### Step 1: Clean Up Prior Audit Snapshots (MANDATORY)

Before creating a new snapshot, delete prior audit/pre-test snapshots whose purpose is fulfilled. This is the **primary and authoritative** cleanup (`~/.claude/rules/projects.md`).

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

Store snapshots in `.snapshots/` inside the project, never the top-level projects directory. Name: `snap-pre-test-YYYYMMDD-HHMMSS`.

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

### Step 3: Sweep Leftover VM Pre-Test Snapshots (MANDATORY)

`~/.claude/scripts/vm-pretest-sweep.sh` is the single sweep (also run by `/close` in `--list` mode). It resolves the VM exactly as Phase 10b does (`vm-test-manifest.json` `vm_testing.default_vm`, overridden by `~/.claude/config/project-vm-map.json` `projects.<name>.vm`, default `test-vm-cachyos`), deletes every snapshot named `pre-test-YYYYMMDD-HHMMSS`, and touches no other name. A pre-test snapshot protects nothing once its run has ended, so none is ever kept. Internal snapshots of a pflash VM delete only while it is shut off; a running VM is reported and left for the next sweep.

```bash
~/.claude/scripts/vm-pretest-sweep.sh --project "$PROJECT_DIR"
# exit 0: nothing left; 1: leftovers remain (VM running) — report them, do not fail the phase
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

The pre-test snapshot for the current run is created by Phase 10b and named in `.test-vm-state` (`pre_test_snapshot=`); Phase 10b cleanup reverts to it and deletes it.

```bash
# VM must be shut off (pflash + raw NVRAM)
sudo virsh snapshot-revert $VM_NAME "$(grep ^pre_test_snapshot= .test-vm-state | cut -d= -f2)"

# For projects with post_test_restore=true in vm-test-manifest.json,
# the Phase 11 cleanup automatically restores the VM to its pristine
# snapshot (e.g., pristine-275g-2026-02-25) after testing completes.
```

## Snapshot Naming Convention

BTRFS snapshots from Phase 1:

- **Location**: `$PROJECT_DIR/.snapshots/`
- **Name**: `snap-pre-test-YYYYMMDD-HHMMSS`
- **Type**: Read-only (`-r` flag)

Any other location or name makes the cleanup scan miss old snapshots.

## Output

Report:

- BTRFS snapshot path
- VM pre-test sweep result (deleted names, or leftovers on a running VM)
- Restore commands
