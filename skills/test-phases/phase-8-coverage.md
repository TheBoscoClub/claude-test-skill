# Phase 8: Test Coverage

> **Model**: `sonnet` | **Tier**: 3 (Analysis) | **Modifies Files**: No (read-only)
> **Task Tracking**: Call `TaskUpdate(taskId, status="in_progress")` at start, `TaskUpdate(taskId, status="completed")` when done.
> **Key Tools**: `Bash` for coverage tools, `Read` for coverage reports. Use `NotebookEdit` if project contains Jupyter notebooks that need coverage. Parallelize with other Tier 3 phases.

Measure and analyze test coverage.

## Target

Default minimum: **85%** coverage (configurable)

## Execution Steps

### 1. Run Coverage

**Python:**
```bash
if command -v pytest &>/dev/null; then
  pytest --cov=. --cov-report=term-missing --cov-report=json 2>&1
else
  coverage run -m pytest 2>&1
  coverage report -m 2>&1
  coverage json 2>&1
fi
```

**Node.js:**
```bash
# Jest
npx jest --coverage 2>&1

# Vitest
npx vitest run --coverage 2>&1

# NYC/Istanbul
npx nyc npm test 2>&1
```

**Go:**
```bash
go test -coverprofile=coverage.out ./...
go tool cover -func=coverage.out
```

**Rust:**
```bash
cargo tarpaulin --out Json 2>&1
```

### 2. Parse Coverage Report

Extract:
- Overall coverage percentage
- Per-file coverage
- Uncovered lines

### 3. Identify Low Coverage Files

```bash
# Files below 50% coverage are critical
# Files below 80% need attention
```

### 4. Find Untested Functions

Look for:
- Public functions without tests
- Complex functions (high cyclomatic) without tests
- Error handling paths not covered

## Output Format

```
COVERAGE REPORT
───────────────
Overall:         78% ⚠️ (target: 85%)
Statements:      82%
Branches:        71%
Functions:       85%

LOW COVERAGE FILES:
File                    Coverage   Uncovered Lines
──────────────────────────────────────────────────
src/api/auth.py         45%       23-45, 67-89
src/utils/parser.py     62%       101-120
src/handlers/error.py   38%       12-50

RECOMMENDATIONS:
1. Add tests for auth.py login/logout flows
2. Test error handling in parser.py
3. Add edge case tests for error.py
```

## Success Criteria

- ✅ PASS: Coverage ≥ 85%
- ⚠️ ISSUES: Coverage 70-84%
- ❌ FAIL: Coverage < 70%
