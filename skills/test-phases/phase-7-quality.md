# Phase 7: Code Quality

Linting, complexity analysis, and style checks.

## Execution Steps

### 1. Run Linters

**Python:**
```bash
# Ruff (fast, modern)
if command -v ruff &>/dev/null; then
  ruff check . 2>&1 | head -50
# Flake8 (traditional)
elif command -v flake8 &>/dev/null; then
  flake8 . --max-line-length=100 2>&1 | head -50
fi

# Type checking
if command -v mypy &>/dev/null; then
  mypy . --ignore-missing-imports 2>&1 | head -30
fi
```

**JavaScript/TypeScript:**
```bash
npx eslint . --ext .js,.ts,.tsx 2>&1 | head -50
npx tsc --noEmit 2>&1 | head -30
```

**Go:**
```bash
golangci-lint run 2>&1 | head -50
# or
go vet ./... 2>&1
```

**Rust:**
```bash
cargo clippy 2>&1 | head -50
```

### 2. Complexity Analysis

**Python:**
```bash
# Radon for cyclomatic complexity
if command -v radon &>/dev/null; then
  radon cc . -a -s 2>&1 | head -30
fi
```

**JavaScript:**
```bash
npx eslint . --rule 'complexity: [warn, 10]' 2>&1 | head -30
```

### 3. Code Formatting Check

```bash
# Python
black --check . 2>&1 | head -20
# or
ruff format --check . 2>&1 | head -20

# JavaScript/TypeScript
npx prettier --check "**/*.{js,ts,tsx}" 2>&1 | head -20

# Go (always formatted)
gofmt -l . 2>&1 | head -20
```

### 4. Documentation Coverage

```bash
# Python - check docstrings
pydocstyle . 2>&1 | wc -l
```

## Output Format

```
CODE QUALITY REPORT
───────────────────
Linting Issues:     23 errors, 45 warnings
Type Errors:        5
Complexity:         3 functions above threshold
Formatting:         12 files need formatting
Doc Coverage:       67%

HIGH PRIORITY:
File                          Issue
────────────────────────────────────────────────
src/api/handlers.py:45        Cyclomatic complexity 15 (max 10)
src/utils/parser.py:23        Type error: incompatible return
```
