# Phase 6: Dependency Health

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
  pip-audit 2>&1
elif command -v safety &>/dev/null; then
  safety check 2>&1
fi
```

**Node.js:**
```bash
npm audit 2>&1
```

**Go:**
```bash
if command -v govulncheck &>/dev/null; then
  govulncheck ./... 2>&1
fi
```

**Rust:**
```bash
if command -v cargo-audit &>/dev/null; then
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
