# Phase I: Infrastructure & Runtime Issues

> **Model**: `sonnet` | **Tier**: 3 (Analysis) | **Modifies Files**: No (read-only)
> **Task Tracking**: Call `TaskUpdate(taskId, status="in_progress")` at start, `TaskUpdate(taskId, status="completed")` when done.
> **Key Tools**: `Bash` for system checks. Use `WebSearch` to research infrastructure error patterns. Use `Bash` with `kill` or `timeout` for hung service probes. Parallelize with other Tier 3 phases. Includes cross-component integration surface audit: API contracts, script interfaces, shared file interfaces.

## Purpose

Detect common infrastructure, permission, and runtime configuration issues that cause silent failures in production applications. These issues often manifest as:
- Operations that "fail silently" or report misleading errors
- Services that start but don't function correctly
- Intermittent failures under specific conditions

## Common Issue Patterns

### 1. Proxy Hop-by-hop Header Forwarding

**Problem**: Reverse proxies that forward ALL headers from upstream, including hop-by-hop headers forbidden by HTTP/1.1 and WSGI (PEP 3333).

**Symptoms**:
- WSGI/Waitress errors: `AssertionError: Connection is a "hop-by-hop" header`
- Responses dropped silently
- Intermittent API failures through proxy

**Detection**:
```bash
echo "=== Checking for hop-by-hop header issues ==="

# Find proxy code that forwards headers without filtering
grep -rn "\.headers\.items()" --include="*.py" . 2>/dev/null | while read -r line; do
    file=$(echo "$line" | cut -d: -f1)
    linenum=$(echo "$line" | cut -d: -f2)
    context=$(sed -n "$((linenum-5)),$((linenum+5))p" "$file" 2>/dev/null)
    if ! echo "$context" | grep -qi "hop.by.hop\|HOP_BY_HOP\|connection.*lower\|filter"; then
        echo "WARN: Possible unfiltered header forwarding at $file:$linenum"
    fi
done
```

**Fix Pattern**:
```python
HOP_BY_HOP_HEADERS = frozenset({
    'connection', 'keep-alive', 'proxy-authenticate',
    'proxy-authorization', 'te', 'trailers',
    'transfer-encoding', 'upgrade',
})

for header, value in response.headers.items():
    if header.lower() not in HOP_BY_HOP_HEADERS:
        self.send_header(header, value)
```

---

### 2. Service User Permission Mismatches

**Problem**: Services run as a dedicated user but data directories are owned by a different user.

**Symptoms**:
- "Permission denied" errors only when running as service
- Operations work via CLI but fail through service
- Downloads/writes appear to "fail silently"

**Detection**:
```bash
echo "=== Checking service user permissions ==="

for service_file in /etc/systemd/system/*.service; do
    [[ -f "$service_file" ]] || continue
    service_user=$(grep -E "^User=" "$service_file" 2>/dev/null | cut -d= -f2)
    [[ -z "$service_user" ]] && continue

    work_dirs=$(grep -E "^(WorkingDirectory|ReadWritePaths)" "$service_file" 2>/dev/null)
    for dir in $(echo "$work_dirs" | grep -oE "/[^ \"]+"); do
        [[ -d "$dir" ]] || continue
        owner=$(stat -c %U "$dir" 2>/dev/null)
        if [[ "$owner" != "$service_user" && "$owner" != "root" ]]; then
            echo "WARN: $dir owned by '$owner' but service runs as '$service_user'"
        fi
    done
done
```

---

### 3. Shell Script Variable Typos

**Problem**: Missing `$` in variable references, especially in redirections.

**Symptoms**:
- Scripts create files named literally (e.g., `temp_file` instead of the variable value)
- "Read-only file system" errors
- Scripts work in some directories but not others

**Detection**:
```bash
echo "=== Checking for shell variable typos ==="

# Pattern: : > "word" where word looks like a variable name but has no $
grep -rn ': > "[a-z_]*"' --include="*.sh" . 2>/dev/null | while read -r line; do
    if echo "$line" | grep -qE ': > "(temp|tmp|out|file|log|idx|index|cache)[_a-z]*"'; then
        echo "LIKELY BUG: $line"
        echo "  Should probably be: : > \"\$variable_name\""
    fi
done
```

---

### 4. Systemd Sandboxing Issues

**Problem**: Service uses `ProtectSystem=strict` but `ReadWritePaths` doesn't include all needed directories.

**Symptoms**:
- "Read-only file system" errors
- Service starts but can't write data
- Works manually but not as service

**Detection**:
```bash
echo "=== Checking systemd sandboxing ==="

for service_file in /etc/systemd/system/*.service; do
    [[ -f "$service_file" ]] || continue
    if grep -q "ProtectSystem=\(strict\|full\)" "$service_file"; then
        rw_paths=$(grep "ReadWritePaths=" "$service_file" | cut -d= -f2)
        if [[ -z "$rw_paths" ]]; then
            echo "WARN: $(basename "$service_file") has ProtectSystem but no ReadWritePaths"
        fi
    fi
done
```

---

### 5. Database/Index on Slow Storage

**Problem**: SQLite database or indexes on HDD instead of SSD/NVMe.

**Symptoms**:
- Slow queries despite small database
- Timeouts on write operations
- Scanner hangs on metadata extraction

**Detection**:
```bash
echo "=== Checking storage tier placement ==="

find /var/lib /srv /opt -name "*.db" -o -name "*.sqlite" 2>/dev/null | while read -r db; do
    device=$(df "$db" 2>/dev/null | tail -1 | awk '{print $1}')
    dev_name=$(basename "$device" | sed 's/[0-9]*$//')
    rotational=$(cat /sys/block/$dev_name/queue/rotational 2>/dev/null)
    if [[ "$rotational" == "1" ]]; then
        echo "WARN: Database on HDD: $db"
    fi
done
```

---

## Quick Check Summary

```bash
echo "=== INFRASTRUCTURE QUICK CHECK ==="

echo -n "[1] Proxy header filtering: "
grep -rq "HOP_BY_HOP" --include="*.py" . 2>/dev/null && echo "OK" || echo "CHECK"

echo -n "[2] Shell variable typos: "
typos=$(grep -rl ': > "[a-z_]*"' --include="*.sh" . 2>/dev/null | wc -l)
[[ "$typos" -gt 0 ]] && echo "WARN ($typos files)" || echo "OK"

echo -n "[3] Systemd sandboxing: "
sandbox_issues=0
for svc in /etc/systemd/system/*.service; do
    [[ -f "$svc" ]] || continue
    if grep -q "ProtectSystem=strict" "$svc" 2>/dev/null && ! grep -q "ReadWritePaths" "$svc" 2>/dev/null; then
        sandbox_issues=$((sandbox_issues + 1))
    fi
done
[[ "$sandbox_issues" -gt 0 ]] && echo "WARN ($sandbox_issues services)" || echo "OK"

echo -n "[4] OOM-killer patterns: "
oom_count=$(dmesg 2>/dev/null | grep -c "Out of memory\|oom-kill\|invoked oom-killer" || echo "0")
[[ "$oom_count" -gt 0 ]] && echo "WARN ($oom_count events in dmesg)" || echo "OK"

echo -n "[5] SELinux/AppArmor conflicts: "
mac_issues=0
if command -v getenforce &>/dev/null && [[ "$(getenforce 2>/dev/null)" == "Enforcing" ]]; then
    mac_denials=$(ausearch -m avc --start recent 2>/dev/null | grep -c "denied" || echo "0")
    [[ "$mac_denials" -gt 0 ]] && mac_issues=$((mac_issues + mac_denials))
fi
if command -v aa-status &>/dev/null; then
    aa_complain=$(aa-status 2>/dev/null | grep -c "complain" || echo "0")
    [[ "$aa_complain" -gt 0 ]] && mac_issues=$((mac_issues + aa_complain))
fi
[[ "$mac_issues" -gt 0 ]] && echo "WARN ($mac_issues)" || echo "OK (or not active)"

echo -n "[6] Database on slow storage: "
slow_db=0
for db in $(find /var/lib /srv /opt -name "*.db" -o -name "*.sqlite" 2>/dev/null | head -20); do
    device=$(df "$db" 2>/dev/null | tail -1 | awk '{print $1}')
    dev_name=$(basename "$device" 2>/dev/null | sed 's/[0-9]*$//')
    rotational=$(cat "/sys/block/$dev_name/queue/rotational" 2>/dev/null)
    [[ "$rotational" == "1" ]] && slow_db=$((slow_db + 1))
done
[[ "$slow_db" -gt 0 ]] && echo "WARN ($slow_db DBs on HDD)" || echo "OK"
```

## Cross-Component Integration Surface Audit

Every phase must analyze infrastructure holistically — not just within individual files but across the entire project's integration boundaries. This section is mandatory for all /test audits.

### API Contract Verification

```bash
# List all API route definitions with their HTTP methods and paths
echo "=== Backend API Routes ==="
grep -rn "@app\.route\|@router\.\(get\|post\|put\|delete\|patch\)" --include="*.py" "$PROJECT_ROOT" \
  | grep -v ".venv\|.snapshots\|test" | sort

# List all frontend API calls with their URLs and methods
echo "=== Frontend API Calls ==="
grep -rn "fetch(\|axios\.\|http\.\|\.get(\|\.post(\|\.put(\|\.delete(" \
  --include="*.js" --include="*.ts" --include="*.jsx" --include="*.tsx" "$PROJECT_ROOT" \
  | grep -v "node_modules\|.snapshots\|test" | sort

# Cross-reference: extract URL paths from both sides and diff
echo "=== Backend paths ==="
grep -rn "@app\.route\|@router\." --include="*.py" "$PROJECT_ROOT" \
  | grep -v ".venv\|.snapshots\|test" \
  | grep -oP "['\"]\/[^'\"]*['\"]" | sort -u > /tmp/phase-I-integration-backend-routes.txt

echo "=== Frontend paths ==="
grep -rn "fetch(\|axios\." --include="*.js" --include="*.ts" "$PROJECT_ROOT" \
  | grep -v "node_modules\|.snapshots\|test" \
  | grep -oP "['\"]\/api[^'\"]*['\"]" | sort -u > /tmp/phase-I-integration-frontend-routes.txt

# Show routes called by frontend but not defined in backend
comm -23 /tmp/phase-I-integration-frontend-routes.txt /tmp/phase-I-integration-backend-routes.txt 2>/dev/null
```

### Shell Script Interface Audit

```bash
# Find scripts that call other scripts
grep -rn "bash \|sh \|\.\/" --include="*.sh" "$PROJECT_ROOT" \
  | grep -v ".snapshots\|.git/" | sort

# Check that called scripts actually exist
grep -rn "source \|^\. \|bash \|sh " --include="*.sh" "$PROJECT_ROOT" \
  | grep -v ".snapshots\|.git/" \
  | grep -oP "[\w./-]+\.sh" | sort -u | while read -r script; do
    found=$(find "$PROJECT_ROOT" -name "$(basename "$script")" -type f 2>/dev/null | head -1)
    if [ -z "$found" ]; then
      echo "MISSING SCRIPT: $script"
    fi
  done
```

### Shared File Interface Audit

```bash
# Find files written by one component and read by another
# Identify file paths mentioned in write operations
echo "=== Write targets ==="
grep -rn "open(.*['\"]w\|write_text\|with open" --include="*.py" "$PROJECT_ROOT" \
  | grep -v ".venv\|.snapshots\|test\|__pycache__" \
  | grep -oP "['\"][^'\"]*\.\(txt\|csv\|json\|log\|idx\|dat\|pid\)['\"]" | sort -u

# Identify file paths mentioned in read operations
echo "=== Read sources ==="
grep -rn "open(.*['\"]r\|read_text\|with open" --include="*.py" "$PROJECT_ROOT" \
  | grep -v ".venv\|.snapshots\|test\|__pycache__" \
  | grep -oP "['\"][^'\"]*\.\(txt\|csv\|json\|log\|idx\|dat\|pid\)['\"]" | sort -u
```

### IPC / Message Protocol Validation

For projects using inter-process communication (protobuf, gRPC, msgpack, JSON-over-socket, etc.), verify that all send/receive paths use the proper message envelope — not raw bytes or ad-hoc serialization.

**Why**: A component that sends `b"\x05" + json_bytes` instead of a proper protobuf `IpcMessage` will cause `invalid tag` or deserialization errors in the receiver. These bugs are invisible to unit tests (which mock the transport) and only manifest in production.

```bash
echo ""
echo "-------------------------------------------------------------------"
echo "  IPC / Message Protocol Validation"
echo "-------------------------------------------------------------------"

# Step 1: Detect IPC protocol definitions
PROTO_FILES=$(find "$PROJECT_ROOT" -name "*.proto" -not -path "*/.snapshots/*" -not -path "*/.git/*" 2>/dev/null)
MSGPACK_USAGE=$(grep -rl "msgpack\|MessagePack" --include="*.py" --include="*.rs" --include="*.go" "$PROJECT_ROOT" 2>/dev/null | grep -v ".snapshots\|.venv\|node_modules" | head -1)

IPC_ISSUES=0

if [[ -n "$PROTO_FILES" ]]; then
    echo "Protobuf definitions found:"
    echo "$PROTO_FILES"

    # Step 2: Find the envelope message type (top-level wrapper)
    # Convention: a message with multiple "oneof" fields, or named *Message/*Envelope/*Request
    ENVELOPE_TYPES=$(grep -h "^message " $PROTO_FILES | sed 's/message //' | sed 's/ {//' \
        | grep -iE "Message$|Envelope$|Request$|Wrapper$|Ipc" | head -5)

    if [[ -n "$ENVELOPE_TYPES" ]]; then
        echo "Envelope message types: $ENVELOPE_TYPES"

        # Step 3: Find all send() / write() calls on IPC channels
        # Look for socket send, client.send, stream.write patterns
        SEND_CALLS=$(grep -rn "\.send(\|\.write(\|\.send_message(\|\.write_all(" \
            --include="*.py" --include="*.rs" --include="*.go" --include="*.js" --include="*.ts" \
            "$PROJECT_ROOT" 2>/dev/null \
            | grep -v ".snapshots\|.venv\|node_modules\|__pycache__\|.git/\|test\|_test\." \
            | grep -iv "http\|smtp\|email\|log\|print\|websocket\|ws\.")

        if [[ -n "$SEND_CALLS" ]]; then
            echo ""
            echo "Checking IPC send paths for proper envelope usage..."

            # Step 4: Flag send calls that use raw bytes instead of protobuf serialization
            # Pattern: sending b"..." or bytes directly instead of .SerializeToString()
            RAW_SENDS=$(echo "$SEND_CALLS" | grep -E 'send\(b"|send\(b'\''|send\(bytes|send\(json\.|send\(str\.' | head -20)
            if [[ -n "$RAW_SENDS" ]]; then
                echo "RAW BYTE SENDS (should use protobuf envelope):"
                echo "$RAW_SENDS"
                IPC_ISSUES=$((IPC_ISSUES + $(echo "$RAW_SENDS" | wc -l)))
            fi

            # Pattern: sending with magic byte prefix (b"\x01" + payload, etc.)
            MAGIC_SENDS=$(echo "$SEND_CALLS" | grep -E 'b"\\\\x[0-9a-f]+"|b'\''\\x[0-9a-f]+'\''' | head -20)
            if [[ -n "$MAGIC_SENDS" ]]; then
                echo "MAGIC BYTE PREFIX SENDS (should use protobuf message type):"
                echo "$MAGIC_SENDS"
                IPC_ISSUES=$((IPC_ISSUES + $(echo "$MAGIC_SENDS" | wc -l)))
            fi

            # Step 5: Verify send calls reference protobuf types
            # Check that send paths import and use the generated protobuf module
            SEND_FILES=$(echo "$SEND_CALLS" | cut -d: -f1 | sort -u)
            for f in $SEND_FILES; do
                # Check if this file imports protobuf types
                HAS_PROTO_IMPORT=$(grep -c "import.*_pb2\|use.*proto\|proto::\|protobuf\|prost::" "$f" 2>/dev/null)
                SEND_COUNT=$(echo "$SEND_CALLS" | grep "^$f:" | wc -l)
                if [[ "$SEND_COUNT" -gt 0 && "$HAS_PROTO_IMPORT" -eq 0 ]]; then
                    echo "WARNING: $f has $SEND_COUNT IPC send(s) but no protobuf import"
                    IPC_ISSUES=$((IPC_ISSUES + 1))
                fi
            done
        fi
    else
        echo "No clear envelope message type found in proto files."
        echo "Consider defining a top-level IpcMessage with oneof fields."
    fi
elif [[ -n "$MSGPACK_USAGE" ]]; then
    echo "MessagePack IPC detected — manual review recommended."
else
    echo "No IPC protocol definitions found — skipping."
fi

if [[ "$IPC_ISSUES" -eq 0 ]]; then
    echo "IPC protocol validation: OK (or not applicable)"
else
    echo ""
    echo "TOTAL IPC PROTOCOL ISSUES: $IPC_ISSUES"
fi
```

### Integration Surface Checklist

```
[ ] API contracts verified (backend routes vs frontend calls)
[ ] Script dependencies verified (called scripts exist)
[ ] Shared file interfaces audited
[ ] IPC protocol envelope usage verified
```

## References

- PEP 3333: Python Web Server Gateway Interface
- RFC 2616: HTTP/1.1 Hop-by-hop Headers
- systemd.exec(5): Service sandboxing directives
