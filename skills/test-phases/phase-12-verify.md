# Phase 12: Final Verification

> **Model**: `sonnet` | **Tier**: 5 (Verify) | **Modifies Files**: No (re-tests only)
> **Task Tracking**: Call `TaskUpdate(taskId, status="in_progress")` at start, `TaskUpdate(taskId, status="completed")` when done.
> **Key Tools**: `Bash` for re-running tests (use `timeout` if verification tests hang).

**Purpose**: After Phase 10 (Fix) has applied changes, re-run all checks to CONFIRM the fixes worked and no regressions were introduced. This is the final gate before the audit is declared complete.

---

## Prerequisites

Phase 12 depends on data from earlier phases:
- **Phase 2 test results**: The baseline pass/fail counts and coverage percentage
- **Phase 10 fix list**: Which issues were fixed and what files were modified
- If Phase 2 did not run or produced no test results, skip Step 1 and Step 5 (regression/coverage comparison) but still run Steps 2-4.

## Step 1: Re-Run Test Suite (Regression Check)

Run the exact same test commands that Phase 2 used. Compare results against Phase 2 baseline.

### 1a. Detect Test Framework

```bash
echo "=== Detecting test framework ==="

# Python
if [ -f pyproject.toml ] || [ -f setup.cfg ] || [ -f pytest.ini ] || [ -f tox.ini ]; then
  if command -v pytest &>/dev/null; then
    echo "Framework: pytest"
    TEST_CMD="pytest"
  elif command -v python &>/dev/null; then
    echo "Framework: unittest"
    TEST_CMD="python -m unittest discover"
  fi
fi

# Node.js
if [ -f package.json ]; then
  if command -v node &>/dev/null; then
    TEST_SCRIPT=$(node -e "const p=require('./package.json'); console.log(p.scripts?.test || '')" 2>/dev/null)
    if [ -n "$TEST_SCRIPT" ] && [ "$TEST_SCRIPT" != "undefined" ] && [ "$TEST_SCRIPT" != "" ]; then
      echo "Framework: npm test ($TEST_SCRIPT)"
      TEST_CMD="npm test"
    fi
  fi
fi

# Go
if [ -f go.mod ]; then
  if command -v go &>/dev/null; then
    echo "Framework: go test"
    TEST_CMD="go test ./..."
  fi
fi

# Rust
if [ -f Cargo.toml ]; then
  if command -v cargo &>/dev/null; then
    echo "Framework: cargo test"
    TEST_CMD="cargo test"
  fi
fi

# Ruby
if [ -f Gemfile ]; then
  if command -v bundle &>/dev/null; then
    if [ -f Rakefile ] && grep -q 'test' Rakefile 2>/dev/null; then
      echo "Framework: rake test"
      TEST_CMD="bundle exec rake test"
    elif [ -d spec ]; then
      echo "Framework: rspec"
      TEST_CMD="bundle exec rspec"
    fi
  fi
fi

if [ -z "$TEST_CMD" ]; then
  echo "No test framework detected. Skipping test re-run."
fi
```

### 1b. Execute Tests with Coverage

```bash
if [ -n "$TEST_CMD" ]; then
  echo "=== Re-running test suite ==="
  echo "Command: $TEST_CMD"

  # Run with coverage where possible
  case "$TEST_CMD" in
    pytest)
      if command -v pytest &>/dev/null; then
        # Check if coverage plugin is available
        if python -c "import pytest_cov" 2>/dev/null; then
          pytest -v --tb=short --cov --cov-report=term-missing 2>&1 | tee /tmp/phase12-test-output.txt
        else
          pytest -v --tb=short 2>&1 | tee /tmp/phase12-test-output.txt
        fi
        TEST_EXIT=$?
      fi
      ;;
    "npm test")
      npm test 2>&1 | tee /tmp/phase12-test-output.txt
      TEST_EXIT=$?
      ;;
    "go test ./...")
      go test -v -count=1 ./... 2>&1 | tee /tmp/phase12-test-output.txt
      TEST_EXIT=$?
      ;;
    "cargo test")
      cargo test 2>&1 | tee /tmp/phase12-test-output.txt
      TEST_EXIT=$?
      ;;
    *)
      $TEST_CMD 2>&1 | tee /tmp/phase12-test-output.txt
      TEST_EXIT=$?
      ;;
  esac

  echo ""
  echo "Test exit code: $TEST_EXIT"
fi
```

### 1c. Parse and Compare Results

```bash
if [ -f /tmp/phase12-test-output.txt ]; then
  echo "=== Parsing test results ==="

  # Extract pass/fail counts based on framework
  # pytest format: "X passed, Y failed, Z errors"
  PYTEST_SUMMARY=$(grep -E '[0-9]+ passed' /tmp/phase12-test-output.txt | tail -1)
  if [ -n "$PYTEST_SUMMARY" ]; then
    PASSED=$(echo "$PYTEST_SUMMARY" | grep -oE '[0-9]+ passed' | grep -oE '[0-9]+')
    FAILED=$(echo "$PYTEST_SUMMARY" | grep -oE '[0-9]+ failed' | grep -oE '[0-9]+' || echo "0")
    ERRORS=$(echo "$PYTEST_SUMMARY" | grep -oE '[0-9]+ error' | grep -oE '[0-9]+' || echo "0")
    echo "Phase 12 results: $PASSED passed, ${FAILED:-0} failed, ${ERRORS:-0} errors"
  fi

  # go test format: "ok" or "FAIL"
  GO_PASS=$(grep -c '^ok' /tmp/phase12-test-output.txt 2>/dev/null || echo "0")
  GO_FAIL=$(grep -c '^FAIL' /tmp/phase12-test-output.txt 2>/dev/null || echo "0")
  if [ "$GO_PASS" -gt 0 ] || [ "$GO_FAIL" -gt 0 ]; then
    echo "Phase 12 results: $GO_PASS packages ok, $GO_FAIL packages failed"
  fi

  # cargo test format: "test result: ok. X passed; Y failed"
  CARGO_SUMMARY=$(grep 'test result:' /tmp/phase12-test-output.txt | tail -1)
  if [ -n "$CARGO_SUMMARY" ]; then
    echo "Phase 12 results: $CARGO_SUMMARY"
  fi

  echo ""
  echo "--- Compare against Phase 2 baseline ---"
  echo "If Phase 2 recorded N tests passing, Phase 12 must show >= N passing."
  echo "Any test that passed in Phase 2 but fails now is a REGRESSION."
fi
```

**Subagent instruction**: Compare the Phase 12 pass count against Phase 2's recorded pass count. If any tests that previously passed now fail, report each as `REGRESSION: test_name`. If Phase 2 data is unavailable, report absolute results only.

## Step 2: Verify No Regressions in Specific Fixes

For each fix applied by Phase 10, verify the specific issue is resolved.

```bash
echo "=== Verifying Phase 10 fixes ==="
echo "For each fix Phase 10 applied, run the specific test or check that validates it."
echo "Phase 10 should have recorded which tests correspond to which fixes."
echo ""
echo "If a fix was for:"
echo "  - A test failure: re-run that specific test"
echo "  - A linter issue: re-run the linter on the fixed file"
echo "  - A security finding: re-run the security scanner"
echo "  - A type error: re-run the type checker on the fixed file"
```

**Subagent instruction**: For each fix Phase 10 reported, run the narrowest possible verification. Examples:

- Fix was in `src/auth.py` for a test failure -> `pytest tests/test_auth.py -v`
- Fix was a ruff warning in `app/views.py` -> `ruff check app/views.py`
- Fix was a type error in `lib/utils.ts` -> `npx tsc --noEmit lib/utils.ts`
- Fix was a security finding from bandit -> `bandit -r src/ -f json`

Report each fix as VERIFIED or STILL_FAILING with the specific output.

## Step 3: Build/Compile Check

Verify the project builds cleanly after all Phase 10 changes.

```bash
echo "=== Build verification ==="

# Python
if [ -f pyproject.toml ] || [ -f setup.py ] || [ -f setup.cfg ]; then
  if command -v pip &>/dev/null; then
    echo "--- Python build check ---"
    # Prefer editable install to verify importability
    pip install -e . --dry-run 2>&1 | tail -5
    if [ $? -eq 0 ]; then
      pip install -e . 2>&1 | tail -5
      BUILD_EXIT=$?
      if [ $BUILD_EXIT -eq 0 ]; then
        echo "Python editable install: SUCCESS"
      else
        echo "FINDING: Python editable install FAILED (exit $BUILD_EXIT)"
      fi
    fi
  fi
  # Also try building a distribution if build module is available
  if command -v python &>/dev/null && python -c "import build" 2>/dev/null; then
    echo "--- Python distribution build ---"
    python -m build --no-isolation 2>&1 | tail -10
    [ $? -eq 0 ] && echo "Distribution build: SUCCESS" || echo "FINDING: Distribution build FAILED"
  fi
fi

# Node.js
if [ -f package.json ]; then
  if command -v npm &>/dev/null; then
    echo "--- Node.js build check ---"
    # Check if build script exists
    BUILD_SCRIPT=$(node -e "const p=require('./package.json'); console.log(p.scripts?.build || '')" 2>/dev/null)
    if [ -n "$BUILD_SCRIPT" ] && [ "$BUILD_SCRIPT" != "undefined" ] && [ "$BUILD_SCRIPT" != "" ]; then
      npm run build 2>&1 | tail -15
      [ $? -eq 0 ] && echo "npm build: SUCCESS" || echo "FINDING: npm build FAILED"
    else
      echo "No build script in package.json (skipping)"
    fi

    # TypeScript compilation check
    if [ -f tsconfig.json ]; then
      if command -v npx &>/dev/null; then
        echo "--- TypeScript compilation ---"
        npx tsc --noEmit 2>&1 | tail -15
        [ $? -eq 0 ] && echo "TypeScript check: SUCCESS" || echo "FINDING: TypeScript compilation errors"
      fi
    fi
  fi
fi

# Go
if [ -f go.mod ]; then
  if command -v go &>/dev/null; then
    echo "--- Go build check ---"
    go build ./... 2>&1
    [ $? -eq 0 ] && echo "Go build: SUCCESS" || echo "FINDING: Go build FAILED"

    # Also vet
    go vet ./... 2>&1
    [ $? -eq 0 ] && echo "Go vet: SUCCESS" || echo "FINDING: Go vet found issues"
  fi
fi

# Rust
if [ -f Cargo.toml ]; then
  if command -v cargo &>/dev/null; then
    echo "--- Rust build check ---"
    cargo build 2>&1 | tail -15
    [ $? -eq 0 ] && echo "Cargo build: SUCCESS" || echo "FINDING: Cargo build FAILED"

    # Also check with clippy
    if command -v cargo-clippy &>/dev/null || cargo clippy --version &>/dev/null 2>&1; then
      cargo clippy -- -D warnings 2>&1 | tail -15
      [ $? -eq 0 ] && echo "Clippy: SUCCESS" || echo "FINDING: Clippy warnings after fixes"
    fi
  fi
fi
```

## Step 4: Smoke Test

If the project defines a smoke test command, run it. Otherwise attempt a basic startup check.

```bash
echo "=== Smoke test ==="

# Check install-manifest.json for smoke test command
if [ -f install-manifest.json ]; then
  if command -v python3 &>/dev/null; then
    SMOKE_CMD=$(python3 -c "
import json
with open('install-manifest.json') as f:
    m = json.load(f)
cmd = m.get('smoke_test') or m.get('smokeTest') or m.get('test_command')
if cmd:
    print(cmd)
" 2>/dev/null)
    if [ -n "$SMOKE_CMD" ]; then
      echo "Smoke test from install-manifest.json: $SMOKE_CMD"
      timeout 30 bash -c "$SMOKE_CMD" 2>&1
      SMOKE_EXIT=$?
      if [ $SMOKE_EXIT -eq 0 ]; then
        echo "Smoke test: SUCCESS"
      elif [ $SMOKE_EXIT -eq 124 ]; then
        echo "FINDING: Smoke test timed out (30s)"
      else
        echo "FINDING: Smoke test FAILED (exit $SMOKE_EXIT)"
      fi
    fi
  fi
fi

# Check package.json for start script (brief startup test)
if [ -f package.json ]; then
  START_SCRIPT=$(node -e "const p=require('./package.json'); console.log(p.scripts?.start || '')" 2>/dev/null)
  if [ -n "$START_SCRIPT" ] && [ "$START_SCRIPT" != "undefined" ] && [ "$START_SCRIPT" != "" ]; then
    echo "--- Brief startup test (5s timeout) ---"
    timeout 5 npm start 2>&1 | tail -5
    # Exit 124 (timeout) is expected and OK -- app started and ran for 5s
    STARTUP_EXIT=$?
    if [ $STARTUP_EXIT -eq 124 ] || [ $STARTUP_EXIT -eq 0 ]; then
      echo "Startup test: SUCCESS (app started without crash)"
    else
      echo "FINDING: Application failed to start (exit $STARTUP_EXIT)"
    fi
  fi
fi

# Python CLI entry point check
if [ -f pyproject.toml ]; then
  ENTRY_POINT=$(grep -A 5 '\[project.scripts\]' pyproject.toml 2>/dev/null | grep '=' | head -1 | cut -d'"' -f2 | cut -d"'" -f2)
  if [ -n "$ENTRY_POINT" ] && command -v "$ENTRY_POINT" &>/dev/null; then
    echo "--- CLI entry point check ---"
    timeout 5 "$ENTRY_POINT" --help 2>&1 | head -5
    [ $? -eq 0 ] || [ $? -eq 124 ] && echo "CLI entry point: SUCCESS" || echo "FINDING: CLI entry point --help failed"
  fi
fi

# Docker build check (do not run container, just verify build)
if [ -f Dockerfile ]; then
  if command -v docker &>/dev/null; then
    echo "--- Docker build check ---"
    # Only do a dry-run syntax check, not a full build (too slow for verification)
    if command -v hadolint &>/dev/null; then
      hadolint Dockerfile 2>&1 | head -10
      [ $? -eq 0 ] && echo "Dockerfile lint: SUCCESS" || echo "FINDING: Dockerfile has lint issues"
    else
      echo "Dockerfile present (hadolint not available for lint check)"
    fi
  fi
fi
```

## Step 5: Coverage Comparison

If Phase 2 recorded a coverage percentage, verify it has not decreased.

```bash
echo "=== Coverage comparison ==="

# Extract coverage from Phase 12 test output
if [ -f /tmp/phase12-test-output.txt ]; then
  # pytest-cov format: "TOTAL    XXX    XXX    XX%"
  COV_LINE=$(grep -E '^TOTAL\s' /tmp/phase12-test-output.txt | tail -1)
  if [ -n "$COV_LINE" ]; then
    PHASE12_COV=$(echo "$COV_LINE" | grep -oE '[0-9]+%' | tr -d '%')
    echo "Phase 12 coverage: ${PHASE12_COV}%"
    echo "Compare against Phase 2 baseline. Coverage must not decrease."
  fi

  # Jest/istanbul format: "All files  |  XX.XX |"
  JEST_COV=$(grep -E 'All files' /tmp/phase12-test-output.txt | grep -oE '[0-9]+\.[0-9]+' | head -1)
  if [ -n "$JEST_COV" ]; then
    echo "Phase 12 coverage: ${JEST_COV}%"
  fi

  # Go coverage: "coverage: XX.X% of statements"
  GO_COV=$(grep -oE 'coverage: [0-9.]+%' /tmp/phase12-test-output.txt | tail -1 | grep -oE '[0-9.]+')
  if [ -n "$GO_COV" ]; then
    echo "Phase 12 coverage: ${GO_COV}%"
  fi
fi
```

**Subagent instruction**: If Phase 2 recorded a coverage number, compare it to Phase 12's number. If coverage decreased, report `REGRESSION: Coverage dropped from X% to Y%`. Small decreases (<1%) due to new code without tests may be acceptable but should still be flagged.

## Exit Criteria

**ALL of these must be true for PASS:**

1. All tests that passed in Phase 2 still pass (no regressions)
2. Phase 12 pass count >= Phase 2 pass count
3. Every Phase 10 fix individually verified as working
4. Build/compile succeeds without errors
5. Coverage has not decreased from Phase 2 baseline (if measured)

**Result classification:**

| Result | Criteria |
|--------|----------|
| **PASS** | All 5 criteria met |
| **WARN** | Tests pass but coverage decreased slightly, or smoke test unavailable |
| **FAIL** | Any test regression, build failure, or Phase 10 fix not verified |

## Failure Handling

If tests still fail after Phase 10:

1. **Do NOT loop** -- Phase 12 is verification only, it does not apply fixes
2. Report each still-failing test with its output
3. For each failure, state whether it was a Phase 10 fix target (fix didn't work) or a regression (new failure introduced by Phase 10 changes)
4. Include the specific error messages so the user can decide next steps
5. Set overall result to FAIL with a clear summary

## Output Format

```
FINAL VERIFICATION
──────────────────

Test Suite:
  Phase 2 baseline:  42 passed, 2 failed
  Phase 12 results:  44 passed, 0 failed
  Regressions:       0
  New passes:        2 (from Phase 10 fixes)

Fix Verification:
  Fix #1 (test_auth_login):     VERIFIED
  Fix #2 (ruff E501 in app.py): VERIFIED
  Fix #3 (type error utils.ts): VERIFIED

Build:
  Python editable install: SUCCESS
  Distribution build:      SUCCESS

Smoke Test:
  CLI --help:              SUCCESS

Coverage:
  Phase 2:  87%
  Phase 12: 89% (+2%)

OVERALL: PASS
```
