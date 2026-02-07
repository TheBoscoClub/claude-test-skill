# Phase I: Infrastructure & Runtime Issues

> **Model**: `sonnet` | **Tier**: 3 (Analysis) | **Modifies Files**: No (read-only)
> **Task Tracking**: Call `TaskUpdate(taskId, status="in_progress")` at start, `TaskUpdate(taskId, status="completed")` when done.
> **Key Tools**: `Bash` for system checks. Use `WebSearch` to research infrastructure error patterns. Use `KillShell` for hung service probes. Parallelize with other Tier 3 phases.

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
typos=$(grep -rc ': > "[a-z_]*"' --include="*.sh" . 2>/dev/null | grep -cv ':0$')
[[ "$typos" -gt 0 ]] && echo "WARN ($typos files)" || echo "OK"

echo -n "[3] Systemd sandboxing: "
grep -l "ProtectSystem=strict" /etc/systemd/system/*.service 2>/dev/null | \
    xargs -I{} grep -L "ReadWritePaths" {} 2>/dev/null | wc -l | \
    xargs -I{} sh -c '[[ {} -gt 0 ]] && echo "WARN" || echo "OK"'
```

## References

- PEP 3333: Python Web Server Gateway Interface
- RFC 2616: HTTP/1.1 Hop-by-hop Headers
- systemd.exec(5): Service sandboxing directives
