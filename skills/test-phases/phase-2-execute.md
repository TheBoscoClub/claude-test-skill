# Phase 2: Execute Tests

> **Model**: `sonnet` | **Tier**: 2 (Execute) | **Modifies Files**: No (runs tests)
> **Task Tracking**: Call `TaskUpdate(taskId, status="in_progress")` at start, `TaskUpdate(taskId, status="completed")` when done.
> **Key Tools**: `Bash` for test execution. Use `KillShell` to terminate hung test processes. Can parallel with Phase 2a.

Run the project's test suite and capture results.

## Execution Steps

### 1. Run Tests Based on Project Type

**Python:**

**Note:** If Phase 1 discovery detected custom pytest options and the user selected
any (interactive mode) or the dispatcher set them, they will be available in
`PYTEST_EXTRA_FLAGS`. The dispatcher sets this from the "Pytest Extra Flags" line
in the Phase 1 output. In autonomous mode, this defaults to empty (unit tests only).

```bash
# Prefer pytest
# PYTEST_EXTRA_FLAGS is set by the dispatcher from Phase 1 discovery results
# Example: "--vm --hardware" or empty
if command -v pytest &>/dev/null; then
  pytest -v --tb=short ${PYTEST_EXTRA_FLAGS:-} 2>&1 | tee test-output.log
else
  python -m unittest discover -v 2>&1 | tee test-output.log
fi
```

**Node.js:**
```bash
# Check package.json for test script
if grep -q '"test"' package.json; then
  npm test 2>&1 | tee test-output.log
fi
```

**Go:**
```bash
go test -v ./... 2>&1 | tee test-output.log
```

**Rust:**
```bash
cargo test 2>&1 | tee test-output.log
```

**Make-based:**
```bash
make test 2>&1 | tee test-output.log
```

### 2. Parse Results

Extract from output:
- Total tests run
- Tests passed
- Tests failed
- Tests skipped
- Execution time

### 3. Capture Failures

For each failed test, record:
- Test name
- File location
- Error message
- Stack trace (truncated)

## Output Format

```
═══════════════════════════════════════════════════════════════════
  TEST EXECUTION RESULTS
═══════════════════════════════════════════════════════════════════

Total:   42 tests
Passed:  40 ✅
Failed:   2 ❌
Skipped:  0 ⏭️
Time:    3.2s

FAILURES:
─────────────────────────────────────────────────────────────────
test_user_login (tests/test_auth.py:45)
  AssertionError: Expected 200, got 401
─────────────────────────────────────────────────────────────────
```

## Exit Criteria

- ✅ PASS: All tests pass
- ⚠️ ISSUES: Some tests skipped
- ❌ FAIL: Any test failures
