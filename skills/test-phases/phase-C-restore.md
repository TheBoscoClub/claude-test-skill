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

### 3a. Disable Auto-Enabled MCP Servers

Restore MCP servers to their pre-test state:

```bash
restore_mcp_servers() {
    local PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
    local SETTINGS_FILE="$HOME/.claude/settings.json"
    local MCP_ENABLED_FILE="${PROJECT_DIR}/.test-mcp-enabled"

    echo ""
    echo "───────────────────────────────────────────────────────────────────"
    echo "  MCP Server Cleanup"
    echo "───────────────────────────────────────────────────────────────────"

    # Check if we have a list of enabled servers
    if [ ! -f "$MCP_ENABLED_FILE" ]; then
        echo "  ✓ No MCP servers were auto-enabled (nothing to restore)"
        return 0
    fi

    # Check if settings file is writable
    if [ ! -w "$SETTINGS_FILE" ]; then
        echo "  ⚠️ Cannot modify settings.json (not writable)"
        echo "     MCP servers remain enabled"
        rm -f "$MCP_ENABLED_FILE"
        return 1
    fi

    # Disable each server that was enabled
    local disabled_count=0
    while IFS= read -r plugin; do
        [ -z "$plugin" ] && continue

        local plugin_key="${plugin}@claude-plugins-official"

        # Check if still enabled (might have been manually disabled)
        if grep -q "\"$plugin_key\": true" "$SETTINGS_FILE" 2>/dev/null; then
            echo "  🔌 Disabling $plugin..."

            # Use sed to disable (replace true with false)
            sed -i "s/\"$plugin_key\": true/\"$plugin_key\": false/" "$SETTINGS_FILE"

            echo "    ✅ Disabled $plugin"
            ((disabled_count++))
        else
            echo "  ✓ $plugin already disabled"
        fi
    done < "$MCP_ENABLED_FILE"

    # Remove the tracking file
    rm -f "$MCP_ENABLED_FILE"
    echo ""
    echo "  📝 Removed tracking file: $MCP_ENABLED_FILE"
    echo ""
    echo "MCP Servers Restored: $disabled_count disabled"
}

restore_mcp_servers
```

**What This Does:**
1. Reads `.test-mcp-enabled` to find which servers were auto-enabled
2. Disables each server in `settings.json`
3. Removes the tracking file
4. Reports what was restored

**Note:** If the user manually enabled a server during testing that was in the list, it will still be disabled. This ensures clean restoration to pre-test state.

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

MCP Servers:
  🔌 Disabled playwright (was auto-enabled)
  🔌 Disabled pyright-lsp (was auto-enabled)
  ✅ 2 servers restored to pre-test state

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
