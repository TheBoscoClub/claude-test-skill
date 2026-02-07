# Phase 4: Code Cleanup

> **Model**: `haiku` | **Tier**: 3 (Analysis) | **Modifies Files**: No (read-only)
> **Task Tracking**: Call `TaskUpdate(taskId, status="in_progress")` at start, `TaskUpdate(taskId, status="completed")` when done.
> **Key Tools**: `Bash`, `Grep`, `Glob`. Parallelize with other Tier 3 phases.

Identify dead code, deprecations, and cleanup opportunities.

## Execution Steps

### 1. Find Unused Imports (Python)

```bash
# Using autoflake or manual grep
if command -v autoflake &>/dev/null; then
  autoflake --check --remove-all-unused-imports -r . 2>&1
else
  # Manual check for common patterns
  grep -rn "^import.*#.*unused\|^from.*#.*unused" --include="*.py"
fi
```

### 2. Find Unused Variables

```bash
# Python with pylint
pylint --disable=all --enable=unused-variable,unused-import . 2>/dev/null | head -30

# JavaScript with eslint
npx eslint --rule 'no-unused-vars: warn' . 2>/dev/null | head -30
```

### 3. Find Dead Code

```bash
# Python - vulture
if command -v vulture &>/dev/null; then
  vulture . --min-confidence 80 2>&1 | head -20
fi

# Look for common dead code patterns
grep -rn "# TODO.*delete\|# DEPRECATED\|# REMOVE" --include="*.py" --include="*.js" --include="*.ts"
```

### 4. Find Duplicate Code

```bash
# Python - pylint duplicate checker
pylint --disable=all --enable=duplicate-code . 2>/dev/null | head -20
```

### 5. Find Large Files

```bash
# Files over 500 lines (candidates for splitting)
find . -name "*.py" -o -name "*.js" -o -name "*.ts" | \
  xargs wc -l 2>/dev/null | \
  awk '$1 > 500 {print}' | \
  sort -rn | head -10
```

## Output Format

```
CLEANUP OPPORTUNITIES
─────────────────────
Unused Imports:    12 files
Unused Variables:   8 occurrences
Dead Code:          3 functions
Duplicate Code:     2 blocks
Large Files:        5 files (>500 lines)

TOP PRIORITIES:
1. src/legacy.py - 847 lines, 3 unused imports
2. utils/helpers.js - duplicate of utils/common.js
3. api/deprecated.py - marked for removal
```
