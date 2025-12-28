# Phase 10: Auto-Fix

Automatically fix safe, deterministic issues.

## Safety Rules

**ONLY auto-fix if:**
- Fix is deterministic (one correct solution)
- Change is reversible (git tracked)
- No business logic changes
- Tests exist to verify fix

**NEVER auto-fix:**
- Logic errors requiring judgment
- Architecture changes
- Security-related code
- Code without tests

## Auto-Fixable Categories

### 1. Formatting Issues

```bash
# Python
black . --quiet
ruff format .

# JavaScript/TypeScript
npx prettier --write "**/*.{js,ts,tsx}"

# Go
gofmt -w .
```

### 2. Import Sorting

```bash
# Python
isort . --quiet
ruff check --fix --select I .

# JavaScript
npx eslint --fix --rule 'import/order: error' .
```

### 3. Unused Imports

```bash
# Python (with autoflake)
autoflake --in-place --remove-all-unused-imports -r .

# Or with ruff
ruff check --fix --select F401 .
```

### 4. Simple Lint Fixes

```bash
# Python - safe auto-fixes only
ruff check --fix --select E,W,F .

# JavaScript
npx eslint --fix .
```

### 5. Type Annotation Fixes

```bash
# Add missing return types (Python)
# Only if type is obvious from return statement
```

## Execution Flow

```
1. Create backup (Phase S snapshot if BTRFS)
2. Run formatters
3. Run import sorters
4. Run safe lint fixes
5. Run tests to verify
6. If tests fail, revert all changes
7. Report what was fixed
```

## Output Format

```
AUTO-FIX RESULTS
────────────────
Formatting:       12 files fixed
Import Sorting:    8 files fixed
Unused Imports:    5 removed
Lint Fixes:       23 issues fixed

VERIFICATION:
Tests before:  42 passed, 3 failed
Tests after:   42 passed, 3 failed ✅ (no regression)

SKIPPED (requires manual fix):
- src/api/auth.py:45 - logic error
- src/utils/db.py:23 - security-related
```
