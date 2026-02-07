# Phase 6: Dependency Health

> **Model**: `sonnet` | **Tier**: 3 (Analysis) | **Modifies Files**: No (read-only)
> **Task Tracking**: Call `TaskUpdate(taskId, status="in_progress")` at start, `TaskUpdate(taskId, status="completed")` when done.
> **Key Tools**: `Bash` for audit commands. Use `WebSearch` to look up CVE details for flagged vulnerabilities. Parallelize with other Tier 3 phases.

Check package health, outdated deps, and vulnerabilities.

## Execution Steps

### 1. List Dependencies

**Python:**
```bash
pip list --format=columns 2>/dev/null | head -30
pip list --outdated 2>/dev/null
```

**Node.js:**
```bash
npm ls --depth=0 2>/dev/null
npm outdated 2>/dev/null
```

**Go:**
```bash
go list -m all 2>/dev/null | head -30
```

**Rust:**
```bash
cargo tree --depth=1 2>/dev/null | head -30
cargo outdated 2>/dev/null
```

### 2. Check for Vulnerabilities

**Python:**
```bash
if command -v pip-audit &>/dev/null; then
    echo "Running pip-audit with fix suggestions..."
    # Show vulnerabilities with fix versions
    pip-audit --progress-spinner=off --desc on 2>&1

    # Check if auto-fix is available
    echo ""
    echo "Checking auto-fix availability..."
    pip-audit --fix --dry-run 2>&1 | head -20
elif command -v safety &>/dev/null; then
    safety check --full-report 2>&1
fi

# Also check for outdated packages with known issues
if command -v pip &>/dev/null; then
    echo ""
    echo "Checking pip dependency tree for conflicts..."
    pip check 2>&1
fi
```

**Node.js:**
```bash
if [[ -f package.json ]]; then
    echo "Running npm audit..."
    npm audit 2>&1

    echo ""
    echo "Checking for auto-fix availability..."
    npm audit fix --dry-run 2>&1 | head -20
fi
```

**Go:**
```bash
if command -v govulncheck &>/dev/null && [[ -f go.mod ]]; then
    echo "Running govulncheck..."
    govulncheck ./... 2>&1
fi
```

**Rust:**
```bash
if command -v cargo-audit &>/dev/null && [[ -f Cargo.toml ]]; then
    echo "Running cargo audit..."
    cargo audit 2>&1
fi
```

### 3. Check Dependency Conflicts

```bash
# Python
pip check 2>&1

# Node
npm ls 2>&1 | grep -E "UNMET|invalid"
```

### 4. License Check

```bash
# Python
pip-licenses --format=markdown 2>/dev/null | head -20

# Node
npx license-checker --summary 2>/dev/null
```

## Output Format

```
DEPENDENCY HEALTH
─────────────────
Total Packages:     45
Outdated:           8 (minor), 2 (major)
Vulnerabilities:    1 critical, 3 high
Conflicts:          0
License Issues:     0

CRITICAL UPDATES NEEDED:
Package         Current   Latest    Severity
───────────────────────────────────────────
requests        2.25.0    2.31.0    HIGH (CVE-2023-XXXX)
lodash          4.17.15   4.17.21   CRITICAL
```
