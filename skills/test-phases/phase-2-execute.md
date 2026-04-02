# Phase 2: Test Execution & Analysis

> **Model**: `sonnet` | **Tier**: 2 (Execute) | **Modifies Files**: No (runs tests, generates reports)
> **Task Tracking**: Call `TaskUpdate(taskId, status="in_progress")` at start, `TaskUpdate(taskId, status="completed")` when done.
> **Key Tools**: `Bash` for test execution and coverage (use `timeout` for hung processes). `Read`, `Grep` for failure analysis.

Run the project's test suite with coverage, parse results, analyze failures, and produce a structured report for downstream phases.

---

## Step 1: Detect Project Type & Test Framework

Determine the project type from files present in the project root. Check in order — a project may have multiple (e.g., Python + Docker). Use the FIRST match as the primary framework.

| Marker File | Project Type | Test Runner | Coverage Tool |
|-------------|-------------|-------------|---------------|
| `pyproject.toml` or `setup.py` or `requirements.txt` | Python | `pytest` (fallback: `python -m unittest`) | `pytest --cov` |
| `package.json` | Node.js | `npm test` / `jest` / `vitest` | `nyc` / `jest --coverage` / `vitest --coverage` |
| `go.mod` | Go | `go test` | `go test -coverprofile` |
| `Cargo.toml` | Rust | `cargo test` | `cargo tarpaulin` |
| `Makefile` with `test` target | Make-based | `make test` | Depends on underlying language |
| `composer.json` | PHP | `vendor/bin/phpunit` | `phpunit --coverage-text` |

```bash
# Detection logic
if [ -f pyproject.toml ] || [ -f setup.py ] || [ -f requirements.txt ]; then
  PROJECT_TYPE="python"
elif [ -f package.json ]; then
  PROJECT_TYPE="node"
elif [ -f go.mod ]; then
  PROJECT_TYPE="go"
elif [ -f Cargo.toml ]; then
  PROJECT_TYPE="rust"
elif [ -f Makefile ] && grep -q '^test:' Makefile; then
  PROJECT_TYPE="make"
elif [ -f composer.json ]; then
  PROJECT_TYPE="php"
else
  PROJECT_TYPE="unknown"
fi
```

If Phase 1 output is available, use its detected project type and any custom test flags instead of re-detecting.

---

## Step 2: Run Tests with Coverage

Execute tests with a **5-minute timeout** per test suite. Capture all output to `test-output.log`. Run coverage collection inline with tests — do NOT run tests twice (once without coverage, once with).

**PYTEST_EXTRA_FLAGS**: If the dispatcher set this from Phase 1 discovery (e.g., `--vm --hardware` for projects with custom pytest markers), include it. In autonomous mode, defaults to empty (unit tests only).

### Python

```bash
if command -v pytest &>/dev/null; then
  # Find the package source directory for --cov
  # Use src/ layout if present, otherwise use project name from pyproject.toml, otherwise "."
  if [ -d src ]; then
    COV_SOURCE="src"
  elif [ -f pyproject.toml ]; then
    COV_SOURCE=$(python3 -c "
import tomllib, pathlib
d = tomllib.loads(pathlib.Path('pyproject.toml').read_text())
print(d.get('project',{}).get('name', d.get('tool',{}).get('setuptools',{}).get('packages',{}).get('find',{}).get('where',['.']).pop()).replace('-','_'))
" 2>/dev/null || echo ".")
  else
    COV_SOURCE="."
  fi

  timeout 300 pytest -v --tb=short \
    --cov="$COV_SOURCE" --cov-report=term-missing --cov-report=json:coverage.json \
    ${PYTEST_EXTRA_FLAGS:-} 2>&1 | tee test-output.log
  TEST_EXIT=$?
else
  timeout 300 python3 -m unittest discover -v 2>&1 | tee test-output.log
  TEST_EXIT=$?
  # No built-in coverage for unittest discover — note this in the report
fi
```

### Node.js

```bash
# Detect test runner from package.json
if grep -q '"vitest"' package.json 2>/dev/null; then
  timeout 300 npx vitest run --coverage --reporter=verbose 2>&1 | tee test-output.log
elif grep -q '"jest"' package.json 2>/dev/null; then
  timeout 300 npx jest --verbose --coverage 2>&1 | tee test-output.log
elif grep -q '"test"' package.json 2>/dev/null; then
  timeout 300 npx nyc npm test 2>&1 | tee test-output.log
fi
TEST_EXIT=$?
```

### Go

```bash
timeout 300 go test -v -coverprofile=coverage.out ./... 2>&1 | tee test-output.log
TEST_EXIT=$?

# Generate coverage summary if tests ran
if [ -f coverage.out ]; then
  go tool cover -func=coverage.out 2>&1 | tee -a test-output.log
fi
```

### Rust

```bash
timeout 300 cargo test 2>&1 | tee test-output.log
TEST_EXIT=$?

# Coverage with tarpaulin (if available)
if command -v cargo-tarpaulin &>/dev/null; then
  timeout 300 cargo tarpaulin --out Json --output-dir . 2>&1 | tee -a test-output.log
fi
```

### Make-based

```bash
timeout 300 make test 2>&1 | tee test-output.log
TEST_EXIT=$?
```

### Timeout Handling

If `timeout` exits with code 124, the test suite was killed for exceeding the 5-minute limit. Record this as a critical failure:

```bash
if [ "$TEST_EXIT" -eq 124 ]; then
  echo "CRITICAL: Test suite timed out after 300 seconds" >> test-output.log
fi
```

If a test process hangs, use `timeout --signal=KILL` to forcefully terminate it and its subprocesses.

---

## Step 3: Parse Test Results

Extract structured counts from `test-output.log`. Parsing varies by framework.

### Python (pytest)

```bash
# pytest summary line format: "X passed, Y failed, Z skipped in Ns"
SUMMARY=$(grep -E "^=+ .* =+$" test-output.log | tail -1)
PASSED=$(echo "$SUMMARY" | grep -oP '\d+(?= passed)' || echo 0)
FAILED=$(echo "$SUMMARY" | grep -oP '\d+(?= failed)' || echo 0)
SKIPPED=$(echo "$SUMMARY" | grep -oP '\d+(?= skipped)' || echo 0)
ERRORS=$(echo "$SUMMARY" | grep -oP '\d+(?= error)' || echo 0)
DURATION=$(echo "$SUMMARY" | grep -oP '[\d.]+(?=s)' || echo "?")
TOTAL=$((PASSED + FAILED + SKIPPED + ERRORS))
```

### Go

```bash
PASSED=$(grep -c "^--- PASS:" test-output.log || echo 0)
FAILED=$(grep -c "^--- FAIL:" test-output.log || echo 0)
SKIPPED=$(grep -c "^--- SKIP:" test-output.log || echo 0)
TOTAL=$((PASSED + FAILED + SKIPPED))
```

### Rust (cargo test)

```bash
# "test result: ok. X passed; Y failed; Z ignored"
SUMMARY=$(grep "^test result:" test-output.log | tail -1)
PASSED=$(echo "$SUMMARY" | grep -oP '\d+(?= passed)' || echo 0)
FAILED=$(echo "$SUMMARY" | grep -oP '\d+(?= failed)' || echo 0)
SKIPPED=$(echo "$SUMMARY" | grep -oP '\d+(?= ignored)' || echo 0)
TOTAL=$((PASSED + FAILED + SKIPPED))
```

### Node.js (jest/vitest)

```bash
# "Tests: X passed, Y failed, Z skipped, W total"
PASSED=$(grep -oP '\d+(?= passed)' test-output.log | tail -1 || echo 0)
FAILED=$(grep -oP '\d+(?= failed)' test-output.log | tail -1 || echo 0)
SKIPPED=$(grep -oP '\d+(?= skipped)' test-output.log | tail -1 || echo 0)
TOTAL=$((PASSED + FAILED + SKIPPED))
```

### Coverage Parsing

```bash
# Python (from coverage.json)
if [ -f coverage.json ]; then
  COVERAGE_PCT=$(python3 -c "
import json, pathlib
d = json.loads(pathlib.Path('coverage.json').read_text())
print(round(d.get('totals',{}).get('percent_covered', 0), 1))
" 2>/dev/null || echo "?")
fi

# Go (from coverage.out)
if [ -f coverage.out ]; then
  COVERAGE_PCT=$(go tool cover -func=coverage.out 2>/dev/null | grep '^total:' | awk '{print $3}' | tr -d '%')
fi

# Rust (from tarpaulin JSON)
if [ -f tarpaulin-report.json ]; then
  COVERAGE_PCT=$(python3 -c "
import json, pathlib
d = json.loads(pathlib.Path('tarpaulin-report.json').read_text())
covered = sum(1 for f in d.get('files',[]) for t in f.get('traces',[]) if t.get('stats',{}).get('Line',0) > 0)
total = sum(len(f.get('traces',[])) for f in d.get('files',[]))
print(round(covered/total*100, 1) if total else 0)
" 2>/dev/null || echo "?")
fi
```

---

## Step 4: Failure Analysis

For each failed test, perform root-cause analysis. Skip this step if all tests passed.

### 4a. Collect Failure Details

For each failure, extract:
- **Test name** and **file:line** location
- **Error type**: assertion, exception, timeout, setup/fixture, import
- **Error message** and **stack trace** (truncated to 15 lines max)

```bash
# Python (pytest) — extract FAILED blocks from test-output.log
# Look for "FAILED" markers and the preceding traceback
grep -B 20 "^FAILED " test-output.log
```

### 4b. Categorize Each Failure

| Category | Signal | Likely Root Cause |
|----------|--------|-------------------|
| **Assertion** | `AssertionError`, `AssertionFailure` | Expected behavior changed — code bug or outdated test expectation |
| **Exception** | `TypeError`, `KeyError`, `ValueError`, `NullPointerException` | Missing null check, wrong type, API contract broken |
| **Timeout** | `TimeoutError`, exit code 124 | Infinite loop, deadlock, slow external dependency |
| **Setup/Fixture** | `fixture not found`, `setUp failed`, `before() error` | Missing test dependency, broken fixture, environment issue |
| **Import** | `ImportError`, `ModuleNotFoundError` | Missing dependency, wrong virtualenv, circular import |
| **Flaky** | Passed on previous runs, fails intermittently | Race condition, time-dependent, external service dependency |

For complex or recurring test failures, the dispatcher may invoke the `test-analyzer` agent (see `agents/test-analyzer.md`), which performs deeper root-cause analysis including flakiness detection and affected code path tracing.

### 4c. Check Git History for Recent Changes

For each failing test's source file AND the code file it tests:

```bash
# Check if the failing file or its test target changed recently
git log --oneline -5 -- <source_file>
git log --oneline -5 -- <test_file>

# Check the diff to understand what changed
git diff HEAD~5 -- <source_file>
```

If a file was modified in the last 5 commits, the failure is likely a **regression** — flag it as higher priority.

### 4d. Determine Fix Complexity

| Complexity | Criteria | Examples |
|------------|----------|----------|
| **Trivial** | Typo, wrong constant, simple value fix | Wrong expected value in assertion |
| **Low** | One-line logic fix, missing null check | Add `if x is not None` guard |
| **Medium** | Multi-line change, needs refactoring | Missing edge case handling, API contract change |
| **High** | Architectural issue, design flaw | Circular dependency, fundamental race condition |

---

## Step 5: Identify Low-Coverage Areas

Skip this step if coverage data is unavailable.

### Coverage Threshold

Default coverage target: **80%** (configurable per project via `pyproject.toml` `[tool.coverage.report] fail_under`, `jest.config.js` `coverageThreshold`, or `Cargo.toml` `[package.metadata.tarpaulin]`).

### Flag Problem Files

```bash
# Python: files below 50% coverage from coverage.json
python3 -c "
import json, pathlib
d = json.loads(pathlib.Path('coverage.json').read_text())
files = d.get('files', {})
for fname, data in sorted(files.items(), key=lambda x: x[1].get('summary',{}).get('percent_covered',100)):
    pct = data.get('summary',{}).get('percent_covered', 100)
    if pct < 80:
        missing = data.get('summary',{}).get('missing_lines', 0)
        excluded = data.get('summary',{}).get('excluded_lines', 0)
        marker = 'CRITICAL' if pct < 50 else 'LOW'
        print(f'  [{marker}] {fname}: {pct:.0f}% ({missing} lines uncovered)')
" 2>/dev/null
```

Priority for coverage improvement:
1. **Files < 50%**: Critical — likely core logic with no tests
2. **Files 50-79%**: Low — error handling or edge cases untested
3. **Files >= 80%**: Acceptable — minor gaps

For deep coverage analysis beyond these automated checks, the dispatcher may invoke the `coverage-reviewer` agent (see `agents/coverage-reviewer.md`), which provides targeted test recommendations and priority rankings for coverage gaps.

---

## Step 6: Test Fixture Schema Compliance

If a canonical schema file exists (e.g., `schema.sql`, `migrations/`), verify that all test fixture DDL matches it exactly. Test fixtures with divergent schemas mask production bugs — tests pass against wrong table definitions while the real database uses different column names, types, or constraints.

This check applies to **all languages** — Python `CREATE TABLE` in test fixtures, Go test helpers, Rust `#[test]` setup code, etc.

```bash
echo ""
echo "-------------------------------------------------------------------"
echo "  Test Fixture Schema Compliance"
echo "-------------------------------------------------------------------"

# Find canonical schema
CANONICAL_SCHEMA=""
for candidate in \
    "*/schema.sql" \
    "*/migrations/*.sql" \
    "*/db/schema.sql" \
    "*/src/db/schema.sql" \
    "*/database/schema.sql"; do
    found=$(find "$PROJECT_ROOT" -path "$candidate" -not -path "*/.snapshots/*" -not -path "*/.venv/*" -not -path "*/node_modules/*" -not -path "*/.git/*" 2>/dev/null | head -1)
    if [[ -n "$found" ]]; then
        CANONICAL_SCHEMA="$found"
        break
    fi
done

if [[ -z "$CANONICAL_SCHEMA" ]]; then
    echo "No canonical schema found — skipping fixture compliance check."
else
    echo "Canonical schema: $CANONICAL_SCHEMA"

    # Find all CREATE TABLE in test files
    TEST_DDL=$(grep -rn "CREATE TABLE" \
        --include="*.py" --include="*.rs" --include="*.go" --include="*.js" --include="*.ts" --include="*.sql" \
        "$PROJECT_ROOT" 2>/dev/null \
        | grep -v ".snapshots\|.venv\|node_modules\|__pycache__\|.git/" \
        | grep -v "$CANONICAL_SCHEMA" \
        | grep -iE "test|fixture|spec|_test\.")

    if [[ -z "$TEST_DDL" ]]; then
        echo "No test fixture DDL found."
    else
        FIXTURE_ISSUES=0
        CANONICAL_TABLES=$(grep -i "CREATE TABLE" "$CANONICAL_SCHEMA" | sed -E 's/.*CREATE TABLE (IF NOT EXISTS )?//' | sed 's/[( ].*//' | sort)

        for table in $CANONICAL_TABLES; do
            # Extract canonical columns
            CANONICAL_COLS=$(sed -n "/CREATE TABLE.*$table/,/);/p" "$CANONICAL_SCHEMA" \
                | grep -v "CREATE TABLE\|PRIMARY KEY\|UNIQUE(\|CHECK(\|INDEX\|FOREIGN KEY\|);" \
                | sed -E 's/^\s+//' | cut -d' ' -f1 | grep -v '^$' | sort)

            # Find test files with this table's DDL
            TABLE_REFS=$(echo "$TEST_DDL" | grep "$table")
            if [[ -z "$TABLE_REFS" ]]; then
                continue
            fi

            while IFS= read -r ref; do
                ref_file=$(echo "$ref" | cut -d: -f1)
                ref_linenum=$(echo "$ref" | cut -d: -f2)

                # Extract columns from the fixture's CREATE TABLE
                REF_COLS=$(sed -n "${ref_linenum},/);/p" "$ref_file" 2>/dev/null \
                    | grep -v "CREATE TABLE\|PRIMARY KEY\|UNIQUE(\|CHECK(\|INDEX\|FOREIGN KEY\|);" \
                    | sed -E 's/^\s+//' | cut -d' ' -f1 | grep -v '^$' | sort)

                MISSING=$(comm -23 <(echo "$CANONICAL_COLS") <(echo "$REF_COLS") 2>/dev/null | tr '\n' ', ')
                EXTRA=$(comm -13 <(echo "$CANONICAL_COLS") <(echo "$REF_COLS") 2>/dev/null | tr '\n' ', ')

                if [[ -n "$MISSING" || -n "$EXTRA" ]]; then
                    echo "FIXTURE DRIFT: table '$table' in $ref_file:$ref_linenum"
                    [[ -n "$MISSING" ]] && echo "  Missing (in canonical, not in fixture): $MISSING"
                    [[ -n "$EXTRA" ]] && echo "  Extra (in fixture, not in canonical): $EXTRA"
                    FIXTURE_ISSUES=$((FIXTURE_ISSUES + 1))
                fi
            done <<< "$TABLE_REFS"
        done

        if [[ "$FIXTURE_ISSUES" -eq 0 ]]; then
            echo "All test fixture DDL matches canonical schema."
        else
            echo ""
            echo "TOTAL FIXTURE DRIFT ISSUES: $FIXTURE_ISSUES"
            echo "Fix: Update test fixtures to match $CANONICAL_SCHEMA exactly."
        fi
    fi
fi
```

---

## Phase Output

This phase MUST produce the following structured output. Downstream phases (especially Phase 10 Fix) depend on this exact format.

```
===============================================================
  PHASE 2: TEST EXECUTION & ANALYSIS
===============================================================

PROJECT TYPE: python
TEST RUNNER:  pytest
TEST EXIT CODE: 1

--- TEST RESULTS ---
Total:    42
Passed:   38
Failed:    3
Skipped:   1
Errors:    0
Duration: 12.4s

--- COVERAGE ---
Overall:  74.2% [BELOW TARGET: 80%]

Low Coverage Files:
  [CRITICAL] src/api/auth.py: 45% (34 lines uncovered)
  [LOW]      src/utils/parser.py: 62% (19 lines uncovered)

--- FAILURE ANALYSIS ---

FAILURE 1/3:
  Test:       test_user_login
  Location:   tests/test_auth.py:45
  Category:   Assertion
  Error:      AssertionError: Expected status 200, got 401
  Root Cause: auth.py:23 — token validation logic changed in commit abc1234 (2 days ago)
  Complexity: LOW
  Suggestion: Update token format in auth.py:23 to match new API spec

FAILURE 2/3:
  Test:       test_data_export
  Location:   tests/test_export.py:102
  Category:   Exception (KeyError)
  Error:      KeyError: 'user_id'
  Root Cause: export.py:67 — missing null check, user object can be None
  Complexity: LOW
  Suggestion: Add guard: if user is not None before accessing user.user_id

FAILURE 3/3:
  Test:       test_concurrent_writes
  Location:   tests/test_db.py:201
  Category:   Flaky (Timeout)
  Error:      TimeoutError after 30s
  Root Cause: Race condition in connection pool under load
  Complexity: HIGH
  Suggestion: Redesign connection pool locking to eliminate race condition

--- SUMMARY VERDICT ---
Status: FAIL
Issues Requiring Fix: 3 (all failures must be fixed per Governing Law)
Coverage Gap: 5.8% below target

===============================================================
```

### Output Fields Reference

These fields are consumed by Phase 10 (Fix) and the final report:

| Field | Type | Description |
|-------|------|-------------|
| `PROJECT_TYPE` | string | Detected project type (python, node, go, rust, make, php, unknown) |
| `TEST_RUNNER` | string | Actual test runner used (pytest, jest, go test, cargo test, etc.) |
| `TEST_EXIT_CODE` | int | Exit code from the test runner (0=pass, 1=fail, 124=timeout) |
| `TOTAL` | int | Total tests discovered and executed |
| `PASSED` | int | Tests that passed |
| `FAILED` | int | Tests that failed |
| `SKIPPED` | int | Tests skipped or ignored |
| `ERRORS` | int | Collection/setup errors (distinct from test failures) |
| `DURATION` | string | Total test execution time |
| `COVERAGE_PCT` | float | Overall coverage percentage (or "?" if unavailable) |
| `COVERAGE_TARGET` | int | Target coverage percentage (default 80) |
| Per-failure: `Test` | string | Test function/method name |
| Per-failure: `Location` | string | file:line of the failing test |
| Per-failure: `Category` | string | Assertion, Exception, Timeout, Setup, Import, Flaky |
| Per-failure: `Error` | string | Error message (one line) |
| Per-failure: `Root Cause` | string | Source file:line and explanation |
| Per-failure: `Complexity` | string | Trivial, Low, Medium, High |
| Per-failure: `Suggestion` | string | Recommended fix action |

### Exit Criteria

| Verdict | Condition |
|---------|-----------|
| **PASS** | All tests pass AND coverage >= target |
| **PASS (with warnings)** | All tests pass AND coverage < target |
| **FAIL** | Any non-flaky test failures |
| **FAIL (critical)** | Test suite timed out, import errors, or setup failures preventing test execution |

---

## Cleanup

Remove temporary test artifacts after output is captured:

```bash
# Clean up generated files (keep test-output.log for Phase 10)
rm -f coverage.out coverage.json tarpaulin-report.json
# Do NOT delete test-output.log — Phase 10 needs it for fix verification
```
