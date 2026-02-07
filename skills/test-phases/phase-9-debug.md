# Phase 9: Debug Analysis

> **Model**: `sonnet` | **Tier**: 3 (Analysis) | **Modifies Files**: No (read-only)
> **Task Tracking**: Call `TaskUpdate(taskId, status="in_progress")` at start, `TaskUpdate(taskId, status="completed")` when done.
> **Key Tools**: `Bash`, `Read`, `Grep` for failure analysis. Use `WebSearch` to look up error messages or stack traces. Parallelize with other Tier 3 phases.

Analyze test failures and identify root causes.

## Purpose

For each failure from Phase 2, determine:
- Root cause
- Affected code paths
- Fix complexity

## Execution Steps

### 1. Collect Failure Data

Parse test output for:
```
- Test name and location
- Error type (assertion, exception, timeout)
- Stack trace
- Related test fixtures
```

### 2. Categorize Failures

| Category | Description | Example |
|----------|-------------|---------|
| **Assertion** | Expected vs actual mismatch | `AssertionError: 5 != 6` |
| **Exception** | Unhandled error | `TypeError: None has no attribute` |
| **Timeout** | Test took too long | `TimeoutError after 30s` |
| **Setup** | Fixture/setup failed | `fixture 'db' not found` |
| **Flaky** | Intermittent failure | Passes on retry |

### 3. Trace Root Cause

For each failure:
```python
# 1. Read the failing test
# 2. Identify the assertion/exception line
# 3. Trace back to the source code being tested
# 4. Check recent git changes to that code
git log --oneline -5 -- <failing_file>
git diff HEAD~5 -- <failing_file>
```

### 4. Determine Fix Complexity

| Complexity | Criteria |
|------------|----------|
| **Low** | Typo, wrong value, simple logic |
| **Medium** | Missing edge case, needs refactor |
| **High** | Design flaw, needs architecture change |

## Output Format

```
DEBUG ANALYSIS
──────────────

FAILURE 1: test_user_login
Location:  tests/test_auth.py:45
Type:      Assertion
Error:     Expected status 200, got 401

Root Cause:
  - auth.py:23 - token validation changed
  - Commit abc123 modified validation logic

Fix Complexity: LOW
Suggested Fix: Update expected token format in test

─────────────────────────────────────────────

FAILURE 2: test_data_export
Location:  tests/test_export.py:102
Type:      Exception (KeyError)
Error:     KeyError: 'user_id'

Root Cause:
  - export.py:67 - missing null check
  - User object can be None in edge case

Fix Complexity: MEDIUM
Suggested Fix: Add null check before accessing user_id
```
