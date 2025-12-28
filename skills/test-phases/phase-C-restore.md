# Phase C: Cleanup/Restore

Clean up test artifacts and optionally restore from snapshot.

## Purpose

- Remove temporary files created during audit
- Optionally restore from BTRFS snapshot
- Reset environment to pre-audit state

## Execution Steps

### 1. Remove Test Artifacts

```bash
# Remove coverage files
rm -f .coverage coverage.json coverage.xml htmlcov/ -r

# Remove test output
rm -f test-output.log test-report.md test-results.json

# Remove build artifacts
rm -rf build/ dist/ *.egg-info/
rm -rf node_modules/.cache/
rm -rf target/debug/ (keep release)
rm -rf __pycache__/ .pytest_cache/ .mypy_cache/

# Remove sandbox
rm -rf ./sandbox-*/
```

### 2. Stop Test Services

```bash
# Stop docker test containers
if [ -f "docker-compose.test.yml" ]; then
  docker-compose -f docker-compose.test.yml down -v
fi

# Kill any test processes
pkill -f "pytest\|jest\|vitest" 2>/dev/null || true
```

### 3. Reset Environment Variables

```bash
# Unset test-specific vars
unset NODE_ENV FLASK_ENV DJANGO_SETTINGS_MODULE GO_ENV RUST_TEST
```

### 4. BTRFS Snapshot Restore (Optional)

```bash
# Only if user explicitly requests restore
if [ "$RESTORE_SNAPSHOT" = "true" ]; then
  SNAPSHOT_PATH="$1"
  PROJECT_DIR="$(pwd)"

  if [ -d "$SNAPSHOT_PATH" ]; then
    echo "⚠️ This will REPLACE current project with snapshot!"
    echo "Snapshot: $SNAPSHOT_PATH"
    echo "Target: $PROJECT_DIR"

    # Restore process
    cd ..
    sudo btrfs subvolume delete "$PROJECT_DIR"
    sudo btrfs subvolume snapshot "$SNAPSHOT_PATH" "$PROJECT_DIR"
    cd "$PROJECT_DIR"

    echo "✅ Restored from snapshot"
  fi
fi
```

### 5. Clean Up Snapshots (Optional)

```bash
# List audit snapshots
ls -la /snapshots/audit/ 2>/dev/null

# Delete old snapshots (keep last 3)
ls -t /snapshots/audit/audit-* 2>/dev/null | tail -n +4 | while read snap; do
  sudo btrfs subvolume delete "$snap"
done
```

## Output Format

```
CLEANUP COMPLETE
────────────────

Removed:
  ✅ Test artifacts (3 files)
  ✅ Build cache (45MB freed)
  ✅ Test containers stopped

Environment:
  ✅ Test env vars unset
  ✅ Services stopped

Snapshots:
  📸 /snapshots/audit/audit-20231215-143022-myproject
  📸 /snapshots/audit/audit-20231214-091545-myproject
  🗑️ Deleted 2 old snapshots

Project restored to clean state.
```

## When to Restore

Use snapshot restore when:
- Auto-fix broke something
- Want to undo all audit changes
- Need clean state for fresh audit

Do NOT restore when:
- Fixes were intentional
- Changes should be committed
- Audit was successful
