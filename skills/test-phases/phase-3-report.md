# Phase 3: Test Results Report

> **Model**: `haiku` | **Tier**: 3 (Analysis) | **Modifies Files**: No (read-only)
> **Task Tracking**: Call `TaskUpdate(taskId, status="in_progress")` at start, `TaskUpdate(taskId, status="completed")` when done.
> **Key Tools**: `Bash`, `Read`, `Grep`. Parallelize with other Tier 3 phases.

Generate comprehensive test results report.

## Purpose

Aggregate results from Phase 2 and create actionable report.

## Execution Steps

### 1. Parse Test Output

Read `test-output.log` and extract:
```bash
# Count results
TOTAL=$(grep -cE "^(PASSED|FAILED|test_|ok |FAIL)" test-output.log)
PASSED=$(grep -cE "^(PASSED|ok )" test-output.log)
FAILED=$(grep -cE "^(FAILED|FAIL )" test-output.log)
```

### 2. Categorize Failures

Group failures by:
- **Unit tests**: `test_*.py`, `*.test.js`
- **Integration tests**: `integration/`, `e2e/`
- **Flaky tests**: Previously passed, now failing

### 3. Generate Report

```markdown
# Test Results Report

Generated: [timestamp]
Project: [project_name]

## Summary

| Metric | Count |
|--------|-------|
| Total Tests | X |
| Passed | Y |
| Failed | Z |
| Skipped | W |
| Pass Rate | XX% |

## Failed Tests

### Critical (blocking)
- test_authentication - security critical
- test_payment_flow - business critical

### Non-Critical
- test_ui_rendering - visual only
- test_deprecated_api - legacy code

## Recommendations

1. Fix critical failures before merge
2. Consider skipping flaky tests with @pytest.mark.skip
3. Add missing test coverage for [module]
```

### 4. Output Files

- `test-report.md` - Human-readable report
- `test-results.json` - Machine-readable results

## Success Criteria

- ✅ PASS: 100% pass rate
- ⚠️ ISSUES: >90% pass rate
- ❌ FAIL: <90% pass rate
