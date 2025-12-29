# Phase 10: Fix Issues

## Execution Mode

This phase behaves differently based on execution mode:

| Mode | Behavior |
|------|----------|
| **Autonomous** (default) | Fix ALL issues, loop until clean, no manual items |
| **Interactive** (`--interactive`) | May skip complex fixes, may list "manual required" |

---

## Autonomous Mode (Default)

**CRITICAL: This phase MUST fix ALL issues found by prior phases.**

There is no "manual fix required" category. If an issue was identified, it gets fixed.

### Core Directive

Fix EVERY issue regardless of:
- Priority (critical, high, medium, low, advisory)
- Severity (error, warning, info)
- Complexity (simple typo or complex refactor)
- Type (code, tests, config, documentation)

The only exceptions requiring user input are:
1. **SAFETY**: Destructive operations on production data
2. **ARCHITECTURE**: Complete system rewrites (rare)
3. **EXTERNAL**: Missing credentials or external service access

---

## Interactive Mode (`--interactive`)

When running with `--interactive`, this phase MAY:
- Skip complex fixes that require judgment
- Output "manual required" items for user review
- Output "recommendations" for optional improvements
- Skip logic errors if intent is unclear
- Skip security-related changes for user review

### Safety Rules (Interactive Only)

**Auto-fix if:**
- Fix is deterministic (one correct solution)
- Change is reversible (git tracked)
- No business logic changes
- Tests exist to verify fix

**Skip and report if:**
- Logic errors requiring judgment
- Architecture changes
- Security-related code
- Code without tests

---

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

### Autonomous Mode Output

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

### Interactive Mode Output

```
═══════════════════════════════════════════════════════════════════
  PHASE 10: AUTO-FIX (Interactive)
═══════════════════════════════════════════════════════════════════

Issues Received: 47
Auto-Fixed: 42
Manual Required: 5

By Category:
  Formatting:        12 files fixed
  Import Sorting:     8 files fixed
  Lint Errors:       15 fixes
  Type Errors:        3 fixed, 2 skipped
  Test Failures:      2 fixed, 2 skipped
  Security:           2 packages updated
  Documentation:      1 skipped (unclear intent)

VERIFICATION:
  Tests: 234 passed, 2 failed
  Lint:  0 errors ✅
  Types: 2 errors remaining

MANUAL REQUIRED:
1. src/api/auth.py:45 - Logic error: unclear if null check intended
2. src/utils/db.py:23 - Security: review SQL construction
3. tests/test_api.py:89 - Test expects old behavior
4. tests/test_api.py:112 - Test expects old behavior
5. library/utils.py:34 - Missing type annotation for complex generic

Status: ⚠️ ISSUES - 5 items require manual review
```

---

## Autonomous Mode Rules

If you find yourself wanting to write "requires manual fix" or "skipped" - STOP.

Ask yourself: "Can I identify what the fix should be?"
- If YES → Fix it
- If NO → Gather more context until you CAN identify the fix

The only valid "skip" is when the issue requires:
- Production database access you don't have
- External API credentials not available
- Explicit user architectural decision

Everything else gets fixed. Now.

## Interactive Mode Rules

In interactive mode, it's acceptable to:
- List items for manual review
- Skip complex judgment calls
- Output recommendations

But still prefer fixing over skipping when possible.
