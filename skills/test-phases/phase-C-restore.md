# Phase C: Cleanup/Restore

> **Model**: `haiku` | **Tier**: last (Final) | **Modifies Files**: Cleans up
> **Task Tracking**: Call `TaskUpdate(taskId, status="in_progress")` at start, `TaskUpdate(taskId, status="completed")` when done.
> **Key Tools**: `Bash` for cleanup. Use `Bash` with `kill` to terminate any lingering test processes.

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

### 3a. Shutdown Test VM (if started by /test)

Shutdown the test VM if it was started by this audit to preserve system resources.

```bash
shutdown_test_vm() {
    local PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
    local STATE_FILE="${PROJECT_DIR}/.test-vm-state"

    echo ""
    echo "───────────────────────────────────────────────────────────────────"
    echo "  VM Lifecycle Cleanup"
    echo "───────────────────────────────────────────────────────────────────"
    echo ""

    # Check if state file exists and is readable
    if [[ ! -f "$STATE_FILE" ]]; then
        echo "  ✓ No VM was managed by /test (no state file)"
        return 0
    fi

    if [[ ! -r "$STATE_FILE" ]]; then
        echo "  ⚠️ State file exists but is not readable: $STATE_FILE"
        return 1
    fi

    # Read state file with validation
    local VM_NAME=$(grep "^vm_name=" "$STATE_FILE" 2>/dev/null | cut -d= -f2)
    local STARTED_BY_TEST=$(grep "^started_by_test=" "$STATE_FILE" 2>/dev/null | cut -d= -f2)
    local ORIGINAL_STATE=$(grep "^original_state=" "$STATE_FILE" 2>/dev/null | cut -d= -f2)

    if [[ -z "$VM_NAME" ]]; then
        echo "  ⚠️ State file missing vm_name — removing stale state file"
        rm -f "$STATE_FILE"
        return 0
    fi

    echo "  VM: $VM_NAME"
    echo "  Started by /test: $STARTED_BY_TEST"
    echo "  Original State: $ORIGINAL_STATE"
    echo ""

    # Check for override to keep VM running
    if [[ "$TEST_KEEP_VM_RUNNING" == "true" ]]; then
        echo "  ⚠️ TEST_KEEP_VM_RUNNING=true - leaving VM running"
        rm -f "$STATE_FILE"
        return 0
    fi

    # Only shutdown if we started it
    if [[ "$STARTED_BY_TEST" != "true" ]]; then
        echo "  ✓ VM was already running - leaving it running"
        echo "    (VM was not started by /test)"
        rm -f "$STATE_FILE"
        return 0
    fi

    # Check if VM is still running
    local CURRENT_STATE=$(virsh domstate "$VM_NAME" 2>/dev/null | tr -d '[:space:]')

    if [[ "$CURRENT_STATE" != "running" ]]; then
        echo "  ✓ VM already stopped"
        rm -f "$STATE_FILE"
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
            rm -f "$STATE_FILE"
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
    rm -f "$STATE_FILE"
    echo ""
    echo "  📝 Removed state file: $STATE_FILE"

    echo ""
    echo "VM Cleanup Complete:"
    echo "  - VM $VM_NAME stopped (was: running, original: $ORIGINAL_STATE)"
    echo "  - System resources freed (4GB RAM, 4 vCPUs)"
    echo "  - State file removed: $STATE_FILE"
}

shutdown_test_vm
```

### 3b. Disable Auto-Enabled MCP Servers

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
            echo "  Disabling $plugin..."

            # Use python3 for safe JSON manipulation (sed on JSON is brittle)
            if command -v python3 &>/dev/null; then
                python3 -c "
import json, sys
with open('$SETTINGS_FILE', 'r') as f:
    data = json.load(f)
if '$plugin_key' in data.get('mcpServers', {}):
    data['mcpServers']['$plugin_key'] = False
elif '$plugin_key' in data:
    data['$plugin_key'] = False
with open('$SETTINGS_FILE', 'w') as f:
    json.dump(data, f, indent=2)
" 2>/dev/null
            elif command -v jq &>/dev/null; then
                local tmp_file=$(mktemp)
                jq ".[\"$plugin_key\"] = false" "$SETTINGS_FILE" > "$tmp_file" && mv "$tmp_file" "$SETTINGS_FILE"
            else
                echo "    ⚠️ No python3 or jq available — cannot safely modify JSON"
                continue
            fi

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
# Snapshot location: Phase S creates snapshots inside the project's .snapshots/ directory.
# Verify the snapshot directory exists before attempting cleanup.
PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
SNAPSHOT_DIR="${PROJECT_DIR}/.snapshots"

if [[ -d "$SNAPSHOT_DIR" ]]; then
    echo "Audit snapshots in $SNAPSHOT_DIR:"
    ls -la "$SNAPSHOT_DIR"/snap-* 2>/dev/null || echo "  (none found)"

    # Delete old snapshots (keep last 3)
    ls -t "$SNAPSHOT_DIR"/snap-* 2>/dev/null | tail -n +4 | while read snap; do
        echo "  Deleting old snapshot: $(basename "$snap")"
        sudo btrfs subvolume delete "$snap" 2>/dev/null || rm -rf "$snap"
    done
else
    echo "  ℹ️ No snapshot directory found at $SNAPSHOT_DIR — nothing to clean up"
fi
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

VM Lifecycle:
  🖥️ test-vm-cachyos shutdown
  ✅ System resources freed (4GB RAM, 4 vCPUs)

MCP Servers:
  🔌 Disabled playwright (was auto-enabled)
  🔌 Disabled pyright-lsp (was auto-enabled)
  ✅ 2 servers restored to pre-test state

Snapshots:
  📸 .snapshots/snap-pre-test-20231215-143022
  📸 .snapshots/snap-pre-test-20231214-091545
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
