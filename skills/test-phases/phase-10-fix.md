# Phase 10: Fix ALL Issues

**CRITICAL: This phase MUST fix ALL issues found by prior phases.**

There is no "manual fix required" category. If an issue was identified, it gets fixed.

## Core Directive

Fix EVERY issue regardless of:
- Priority (critical, high, medium, low, advisory)
- Severity (error, warning, info)
- Complexity (simple typo or complex refactor)
- Type (code, tests, config, documentation)

The only exceptions requiring user input are:
1. **SAFETY**: Destructive operations on production data
2. **ARCHITECTURE**: Complete system rewrites (rare)
3. **EXTERNAL**: Missing credentials or external service access

## Fix Categories

### 1. Code Quality Issues
```bash
# Formatting
black . --quiet || ruff format .
npx prettier --write "**/*.{js,ts,tsx,json,md}"
gofmt -w .

# Import sorting
isort . --quiet
ruff check --fix --select I .

# Linting (ALL rules, not just safe)
ruff check --fix .
npx eslint --fix .
```

### 2. Test Failures
- Analyze failing tests
- Fix the code OR the test (whichever is wrong)
- If test is outdated, update it
- If code is buggy, fix the bug
- Add missing test fixtures

### 3. Type Errors
```bash
# Python - fix type annotations
mypy . --show-error-codes 2>&1 | while read line; do
  # Parse and fix each error
done

# TypeScript - fix type errors
npx tsc --noEmit 2>&1 | while read line; do
  # Parse and fix each error
done
```

### 4. Security Vulnerabilities
```bash
# Upgrade vulnerable packages
pip-audit --fix
npm audit fix
cargo update

# If audit fix doesn't work, manually update constraints
```

### 5. Deprecated Code
- Replace deprecated function calls
- Update to current APIs
- Remove dead code paths

### 6. Configuration Issues
- Fix invalid config values
- Add missing required fields
- Update outdated paths/versions

### 7. Logic Errors
- Analyze the intent from context, tests, and docs
- Implement the correct logic
- Add test to prevent regression

### 8. Missing Documentation
- Add missing docstrings
- Add missing type hints
- Update outdated comments

## Execution Flow

```
1. Collect ALL issues from phases 3-9, 11
2. Group by file to minimize edit passes
3. For each issue:
   a. Read current code
   b. Analyze the fix needed
   c. Apply the fix
   d. Verify fix doesn't break tests
4. Run full test suite
5. If new issues found, fix those too
6. Loop until ALL tests pass and ALL issues resolved
7. Report what was fixed
```

## Verification Loop

```
REPEAT:
  Run tests
  IF tests fail:
    Analyze new failures
    Fix new issues
  UNTIL all tests pass

REPEAT:
  Run all analysis phases (3-9, 11)
  IF new issues found:
    Fix them
  UNTIL no issues remain
```

## Output Format

```
═══════════════════════════════════════════════════════════════════
  PHASE 10: FIX ALL ISSUES
═══════════════════════════════════════════════════════════════════

Issues Received: 47
Issues Fixed: 47

By Category:
  Formatting:        12 files
  Import Sorting:     8 files
  Lint Errors:       15 fixes
  Type Errors:        5 fixes
  Test Failures:      4 fixes
  Security:           2 packages updated
  Documentation:      1 docstring added

VERIFICATION:
  Tests: 236 passed, 0 failed ✅
  Lint:  0 errors ✅
  Types: 0 errors ✅

Status: ✅ PASS - All issues resolved
```

## NO EXCEPTIONS

If you find yourself wanting to write "requires manual fix" or "skipped" - STOP.

Ask yourself: "Can I identify what the fix should be?"
- If YES → Fix it
- If NO → Gather more context until you CAN identify the fix

The only valid "skip" is when the issue requires:
- Production database access you don't have
- External API credentials not available
- Explicit user architectural decision

Everything else gets fixed. Now.
