# Phase 0: Pre-Flight Environment Validation

Validate the environment is ready before running any tests. Fail fast on environment issues.

## Step 1: Dependency Verification

```bash
PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"

echo "═══════════════════════════════════════════════════════════════════"
echo "  PHASE 0: PRE-FLIGHT CHECKS"
echo "═══════════════════════════════════════════════════════════════════"

# Python
if [[ -f "$PROJECT_DIR/requirements.txt" ]]; then
    pip check 2>&1 | head -10
    pip freeze | diff - "$PROJECT_DIR/requirements.txt" 2>&1 | head -10
fi

# Node.js
if [[ -f "$PROJECT_DIR/package.json" ]]; then
    npm ls --depth=0 2>&1 | grep -E "WARN|ERR" | head -10 || echo "Dependencies OK"
fi

# Go
if [[ -f "$PROJECT_DIR/go.mod" ]]; then
    go mod verify 2>&1
fi

# Rust
if [[ -f "$PROJECT_DIR/Cargo.toml" ]]; then
    cargo verify-project 2>&1
fi
```

## Step 2: Environment Variables

Find all environment variable references and verify they exist:

```bash
# Find env var references
ENV_REFS=$(grep -roh "os\.environ\[.\|process\.env\.\|os\.getenv(" --include="*.py" --include="*.js" . 2>/dev/null | head -20)

# Check .env.example vs .env
if [[ -f .env.example ]] && [[ -f .env ]]; then
    echo "Checking .env vs .env.example..."
    diff <(grep -E "^[A-Z_]" .env.example | cut -d= -f1 | sort) \
         <(grep -E "^[A-Z_]" .env | cut -d= -f1 | sort) 2>/dev/null | head -10
fi
```

## Step 3: Service Connectivity

```bash
# Check database
pg_isready -h localhost 2>/dev/null || echo "PostgreSQL: N/A"
redis-cli ping 2>/dev/null || echo "Redis: N/A"
```

## Step 4: File Permissions

```bash
# Check writable directories
for dir in logs/ data/ tmp/ uploads/; do
    if [[ -d "$dir" ]]; then
        [[ -w "$dir" ]] && echo "✅ $dir writable" || echo "❌ $dir NOT writable"
    fi
done
```

## Step 5: Service User Permissions

If systemd services exist, verify service user can write to required directories.

```bash
PROJECT_NAME=$(basename "$(pwd)")
SERVICES=$(systemctl list-units --type=service --all 2>/dev/null | grep -i "$PROJECT_NAME" | awk '{print $1}')

for SERVICE in $SERVICES; do
    USER=$(systemctl show "$SERVICE" --property=User --value 2>/dev/null)
    echo "Service $SERVICE runs as: ${USER:-root}"
done
```

## Report Format

```
## Pre-Flight Check Results

| Check | Status | Details |
|-------|--------|---------|
| Dependencies | ✅/❌ | [details] |
| Environment Variables | ✅/❌ | [missing vars] |
| Service Connectivity | ✅/❌ | [status] |
| File Permissions | ✅/❌ | [issues] |
| Service Permissions | ✅/❌ | [issues] |

**Pre-Flight Status**: ✅ READY / ❌ BLOCKED
```
