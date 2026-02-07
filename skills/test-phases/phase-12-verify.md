# Phase 12: Final Verification

> **Model**: `sonnet` | **Tier**: 6 (Verify) | **Modifies Files**: No (re-tests)
> **Task Tracking**: Call `TaskUpdate(taskId, status="in_progress")` at start, `TaskUpdate(taskId, status="completed")` when done.
> **Key Tools**: `Bash` for re-running tests. Use `KillShell` if verification tests hang.

End-to-end verification that all fixes work.

## Purpose

After all phases complete:
- Verify fixes didn't break anything
- Confirm all tests pass
- Validate build succeeds
- Check no regressions

## Execution Steps

### 1. Clean Build

```bash
# Remove all build artifacts
rm -rf build/ dist/ .eggs/ *.egg-info/
rm -rf node_modules/.cache/
rm -rf target/ (Rust)
rm -rf __pycache__/ .pytest_cache/

# Fresh install
pip install -e . 2>/dev/null || npm ci 2>/dev/null || go mod download
```

### 2. Full Test Suite

```bash
# Run ALL tests (not just changed)
pytest -v 2>&1 || npm test 2>&1 || go test ./... 2>&1 || cargo test 2>&1
```

### 3. Build Verification

```bash
# Python
python -m build 2>&1 || pip wheel . 2>&1

# Node.js
npm run build 2>&1

# Go
go build ./... 2>&1

# Rust
cargo build --release 2>&1
```

### 4. Type Check

```bash
# Python
mypy . --ignore-missing-imports 2>&1

# TypeScript
npx tsc --noEmit 2>&1
```

### 5. Integration Tests (if exist)

```bash
if [ -d "tests/integration" ] || [ -d "tests/e2e" ]; then
  pytest tests/integration/ tests/e2e/ -v 2>&1
fi

if [ -f "package.json" ] && grep -q "test:e2e" package.json; then
  npm run test:e2e 2>&1
fi
```

### 6. Smoke Test

```bash
# Try to run the application briefly
timeout 10 python -m app 2>&1 || \
timeout 10 npm start 2>&1 || \
timeout 10 ./target/release/app 2>&1
```

## Output Format

```
FINAL VERIFICATION
──────────────────

Build:
  ✅ Clean build successful
  ✅ No compilation errors
  ✅ Package built: dist/myapp-1.0.0.tar.gz

Tests:
  ✅ Unit tests: 42/42 passed
  ✅ Integration tests: 8/8 passed
  ✅ E2E tests: 5/5 passed

Type Check:
  ✅ No type errors

Smoke Test:
  ✅ Application starts
  ✅ Health endpoint responds

OVERALL: ✅ VERIFIED
```

## Exit Criteria

- ✅ PASS: All checks pass
- ⚠️ ISSUES: Minor warnings only
- ❌ FAIL: Any test/build failure
