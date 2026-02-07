# Phase 10: Fix Issues

> **Model**: `opus` | **Tier**: 4 (Fix — BLOCKING) | **Modifies Files**: YES
> **Task Tracking**: Call `TaskUpdate(taskId, status="in_progress")` at start, `TaskUpdate(taskId, status="completed")` when done. This phase blocks ALL subsequent phases.
> **Key Tools**: `Edit`, `Write`, `Bash` for fixes. Use `AskUserQuestion` in `--interactive` mode for architectural decisions. Use `WebSearch` to research best-practice fix patterns. Use `NotebookEdit` if fixes affect Jupyter notebooks.

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

### 1. Code Quality Issues - Auto-Fix Commands

**Python Formatting & Linting:**
```bash
echo "───────────────────────────────────────────────────────────────────"
echo "  Python Auto-Fix"
echo "───────────────────────────────────────────────────────────────────"

# Ruff - Fast, comprehensive (preferred)
if command -v ruff &>/dev/null; then
    echo "Running ruff format..."
    ruff format . 2>&1
    echo ""
    echo "Running ruff check --fix (all fixable issues)..."
    ruff check --fix . 2>&1
    echo ""
    echo "Running ruff check --fix --unsafe-fixes (aggressive fixes)..."
    ruff check --fix --unsafe-fixes . 2>&1
fi

# Black - Code formatting (fallback or additional)
if command -v black &>/dev/null; then
    echo ""
    echo "Running black (formatting)..."
    black . --quiet 2>&1
fi

# isort - Import sorting
if command -v isort &>/dev/null; then
    echo ""
    echo "Running isort (import sorting)..."
    isort . --quiet 2>&1
fi
```

**Shell Script Formatting:**
```bash
echo ""
echo "───────────────────────────────────────────────────────────────────"
echo "  Shell Script Auto-Fix"
echo "───────────────────────────────────────────────────────────────────"

# shfmt - Format shell scripts
if command -v shfmt &>/dev/null; then
    echo "Running shfmt (formatting)..."
    find . -name "*.sh" -not -path "./.snapshots/*" -exec shfmt -w {} \; 2>&1
fi

# Note: ShellCheck doesn't auto-fix, but we can apply common fixes
# ShellCheck issues must be fixed manually or by Claude
```

**JavaScript/TypeScript Formatting & Linting:**
```bash
echo ""
echo "───────────────────────────────────────────────────────────────────"
echo "  JavaScript/TypeScript Auto-Fix"
echo "───────────────────────────────────────────────────────────────────"

if [[ -f package.json ]]; then
    # Prettier - Code formatting
    if command -v prettier &>/dev/null || [[ -f node_modules/.bin/prettier ]]; then
        echo "Running prettier (formatting)..."
        npx prettier --write "**/*.{js,ts,tsx,jsx,json,css,scss,md}" 2>&1
    fi

    # ESLint - Lint and fix
    if command -v eslint &>/dev/null || [[ -f node_modules/.bin/eslint ]]; then
        echo ""
        echo "Running eslint --fix..."
        npx eslint --fix . --ext .js,.ts,.tsx,.jsx 2>&1
    fi
fi
```

**Go Formatting:**
```bash
if [[ -f go.mod ]]; then
    echo ""
    echo "───────────────────────────────────────────────────────────────────"
    echo "  Go Auto-Fix"
    echo "───────────────────────────────────────────────────────────────────"

    echo "Running gofmt..."
    gofmt -w . 2>&1

    echo ""
    echo "Running go mod tidy..."
    go mod tidy 2>&1

    if command -v golangci-lint &>/dev/null; then
        echo ""
        echo "Running golangci-lint --fix..."
        golangci-lint run --fix 2>&1
    fi
fi
```

**Rust Formatting:**
```bash
if [[ -f Cargo.toml ]]; then
    echo ""
    echo "───────────────────────────────────────────────────────────────────"
    echo "  Rust Auto-Fix"
    echo "───────────────────────────────────────────────────────────────────"

    echo "Running cargo fmt..."
    cargo fmt 2>&1

    echo ""
    echo "Running cargo clippy --fix..."
    cargo clippy --fix --allow-dirty --allow-staged 2>&1
fi
```

**Spelling Fixes:**
```bash
echo ""
echo "───────────────────────────────────────────────────────────────────"
echo "  Spelling Auto-Fix"
echo "───────────────────────────────────────────────────────────────────"

if command -v codespell &>/dev/null; then
    echo "Running codespell --write-changes..."
    codespell --write-changes --skip=".git,.venv,venv,node_modules,.snapshots,*.lock,package-lock.json" . 2>&1
fi
```

**YAML Formatting:**
```bash
YAML_FILES=$(find . -name "*.yml" -o -name "*.yaml" 2>/dev/null | grep -v node_modules | grep -v .snapshots | head -1)

if [[ -n "$YAML_FILES" ]]; then
    echo ""
    echo "───────────────────────────────────────────────────────────────────"
    echo "  YAML Auto-Fix"
    echo "───────────────────────────────────────────────────────────────────"

    # yamllint doesn't auto-fix, but prettier can format YAML
    if command -v prettier &>/dev/null; then
        echo "Running prettier on YAML files..."
        npx prettier --write "**/*.{yml,yaml}" 2>&1
    fi
fi
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

**Python Security Fixes:**
```bash
echo ""
echo "───────────────────────────────────────────────────────────────────"
echo "  Security Vulnerability Fixes"
echo "───────────────────────────────────────────────────────────────────"

# pip-audit auto-fix
if command -v pip-audit &>/dev/null; then
    if [[ -f requirements.txt ]] || [[ -f pyproject.toml ]]; then
        echo "Running pip-audit --fix..."
        pip-audit --fix 2>&1

        # If auto-fix fails, try manual upgrade of vulnerable packages
        echo ""
        echo "Checking for remaining vulnerabilities..."
        VULNS=$(pip-audit --progress-spinner=off 2>&1 | grep -c "vulnerability" || echo "0")
        if [[ "$VULNS" -gt 0 ]]; then
            echo "Manual fixes needed for $VULNS vulnerabilities"
            pip-audit --progress-spinner=off 2>&1 | grep -E "^Name|vulnerability"
        fi
    fi
fi

# Bandit findings (security issues in code) - these require manual review
# but we can add usedforsecurity=False to non-crypto MD5/SHA1 calls
```

**Node.js Security Fixes:**
```bash
if [[ -f package.json ]]; then
    echo ""
    echo "Running npm audit fix..."
    npm audit fix 2>&1

    # For stubborn issues, try force (with caution)
    echo ""
    echo "Checking for remaining issues..."
    REMAINING=$(npm audit --json 2>/dev/null | jq '.metadata.vulnerabilities.total // 0')
    if [[ "$REMAINING" -gt 0 ]]; then
        echo "$REMAINING vulnerabilities remain. Trying npm audit fix --force..."
        echo "(Note: This may introduce breaking changes)"
        npm audit fix --force --dry-run 2>&1 | head -20
    fi
fi
```

**Go Security Fixes:**
```bash
if [[ -f go.mod ]]; then
    echo ""
    echo "Updating Go dependencies..."
    go get -u ./... 2>&1
    go mod tidy 2>&1
fi
```

**Rust Security Fixes:**
```bash
if [[ -f Cargo.toml ]]; then
    echo ""
    echo "Updating Rust dependencies..."
    cargo update 2>&1
fi
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
