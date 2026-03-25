# Phase 10: Fix Issues

> **Model**: `opus` | **Tier**: 4 (Fix — BLOCKING) | **Modifies Files**: YES
> **Task Tracking**: Call `TaskUpdate(taskId, status="in_progress")` at start, `TaskUpdate(taskId, status="completed")` when done. This phase blocks ALL subsequent phases.
> **Key Tools**: `Edit`, `Bash` for fixes. `Read`, `Grep` for analysis. `AskUserQuestion` in `--interactive` mode only.

Fix ALL issues found by prior phases. Three categories, executed in order: auto-fixable tool runs, test failures, and audit findings. Every fix is verified before moving on.

---

## Execution Mode

The **Governing Law** applies unconditionally in both modes: all errors, warnings, and issues must be fixed. None may be skipped or deferred.

| Mode | Behavior |
|------|----------|
| **Autonomous** (default) | Fix ALL issues. No prompts except safety/architecture/external. |
| **Interactive** (`--interactive`) | Fix ALL issues. May use `AskUserQuestion` for ambiguous logic or architectural decisions. |

The only valid reasons to prompt the user are: (1) requires credentials/access you don't have, (2) requires an explicit architectural decision from the user. Everything else gets fixed without prompting.

---

## Preparation: Collect Issues from Prior Phases

Before fixing anything, gather the structured output from prior phases. The dispatcher passes findings via the `PHASE_RESULTS` context. Extract:

- **Phase 2 output**: Test failures (test file, test name, error type, traceback)
- **Phase 5 output**: Security findings (file, line, issue type, severity)
- **Phase 6 output**: Dependency vulnerabilities (package, current version, fixed version, CVE)
- **Phase 7 output**: Quality issues (file, line, rule code, message)

Read each phase's output section and build a mental inventory before starting fixes. This prevents duplicate work and helps prioritize.

---

## Category 1: Auto-Fixable (Tool-Driven Fixes)

These are deterministic fixes handled entirely by formatting and linting tools. Run them first because they're safe, fast, and eliminate noise from later categories.

### Step 1.1: Run Formatters

Guard every tool with `command -v` (or check for `node_modules/.bin/TOOL`). Only run tools that exist. Run formatters first — they never change semantics.

| Language | Formatter | Command | Notes |
|----------|-----------|---------|-------|
| Python | ruff format (preferred) or black | `ruff format .` / `black . --quiet` | Run one, not both |
| Python imports | ruff or isort | `ruff check --fix --select I .` / `isort . --quiet` | Run after formatter |
| JS/TS | prettier | `npx prettier --write "**/*.{js,ts,tsx,jsx,json,css,scss}"` | Only if `package.json` exists |
| Go | gofmt | `gofmt -w .` | Only if `go.mod` exists |
| Rust | cargo fmt | `cargo fmt` | Only if `Cargo.toml` exists |
| Shell | shfmt | `find . -name "*.sh" -not -path "./.git/*" -not -path "./.snapshots/*" -exec shfmt -w {} \;` | Guard with `command -v` |

### Step 1.2: Run Lint Auto-Fixers

These fix simple lint violations (unused imports, trailing whitespace, basic code patterns). They CAN change semantics, so they run after formatters.

| Language | Tool | Command | Notes |
|----------|------|---------|-------|
| Python | ruff | `ruff check --fix .` | Do NOT use `--unsafe-fixes` unless you've reviewed the specific rules |
| JS/TS | eslint | `npx eslint --fix . --ext .js,.ts,.tsx,.jsx` | Only if `package.json` exists |
| Go | golangci-lint | `golangci-lint run --fix` | Guard with `command -v` |
| Rust | clippy | `cargo clippy --fix --allow-dirty --allow-staged` | Only if `Cargo.toml` exists |
| Spelling | codespell | `codespell --write-changes --skip=".git,.venv,node_modules,.snapshots,*.lock" .` | Guard with `command -v` |

### Step 1.4: Verify Auto-Fixes Didn't Break Anything

Run the project's test suite after all auto-fixes:

```bash
# Python
pytest --tb=short -q 2>&1

# Node.js
npm test 2>&1

# Go
go test ./... 2>&1

# Rust
cargo test 2>&1
```

**If tests fail after auto-fixes**: A formatting or lint fix broke something. Identify which fix caused the failure by checking `git diff`. Revert the specific file(s) that caused breakage:

```bash
git diff --name-only  # See what changed
git checkout -- path/to/broken_file.py  # Revert specific file
```

Then re-run tests to confirm the revert fixed it. Record the reverted file and why in the output — it will need a manual-style fix in Category 2 or 3.

### Step 1.5: Commit Auto-Fixes

If auto-fixes were applied and tests pass, commit them as a batch:

```bash
git add -A
git commit -m "style: auto-format and lint fixes from /test Phase 10"
```

This creates a clean checkpoint. If later fixes go wrong, you can revert to this point.

---

## Category 2: Test Failures (from Phase 2)

Fix failing tests identified by Phase 2. This requires reading code and making judgment calls about whether the test or the source is wrong.

### Step 2.1: Parse Phase 2 Failures

From Phase 2's structured output, extract each failure. Prioritize by error type:

1. **Import errors** — usually a missing dependency or renamed module. Fix first because they block other tests.
2. **Assertion errors** — the test ran but got wrong results. Most common; fix second.
3. **Runtime errors** (TypeError, AttributeError, etc.) — code crashes during test. Fix third.
4. **Timeout/hang** — test never completes. Fix last (often needs architectural change).

### Step 2.2: Fix Each Failure

For EACH failing test, follow this sequence:

**A. Read the failing test:**
Use `Read` to examine the test file at the failing line. Understand what the test expects.

**B. Read the source under test:**
Use `Read` to examine the module/function being tested. Understand what the code actually does.

**C. Determine the root cause — is the test wrong or the code wrong?**

The test is wrong if:
- It references an old API that was intentionally changed
- It asserts a value that was never correct (copy-paste error)
- It tests behavior that was deliberately changed in a recent commit
- The test setup is missing or incomplete (missing fixtures, wrong mock)

The code is wrong if:
- The test describes the correct/intended behavior and the code doesn't match
- Multiple tests for the same function fail in consistent ways
- The docstring/comments describe behavior the code doesn't implement
- The failure is a regression (code used to work, recent change broke it)

When unclear: check git log for the file to see if recent changes explain the mismatch. If still ambiguous and in `--interactive` mode, ask the user. In autonomous mode, prefer fixing the code (conservative: tests document intent).

**D. Apply the fix:**
Use `Edit` to modify either the test file or the source file. Make the minimal change that fixes the failure.

**E. Verify the fix:**
Re-run ONLY the specific test that failed:

```bash
# Python — run single test
pytest tests/test_foo.py::TestClass::test_method -v

# Node.js — run single test file
npx jest tests/foo.test.js

# Go — run single test
go test ./pkg/foo -run TestBar -v

# Rust — run single test
cargo test test_name -- --exact
```

**F. Check for collateral damage:**
After fixing each test, run the full suite to ensure the fix didn't break other tests:

```bash
pytest --tb=line -q 2>&1 | tail -5
```

If a previously passing test now fails, your fix introduced a regression. Revert it and try a different approach.

### Step 2.3: Handle Cascading Failures

Sometimes fixing one test reveals or fixes others. After fixing all identified failures, run the full suite again. If new failures appear that weren't in Phase 2's output, fix those too — they may have been masked by earlier failures (e.g., an import error that prevented a module from loading).

### Step 2.4: Commit Test Fixes

Once all test failures are resolved and the full suite passes:

```bash
git add -A
git commit -m "fix: resolve test failures identified by /test Phase 2"
```

---

## Category 3: Audit Findings (from Phases 5, 6, 7)

Fix issues found by security analysis (Phase 5), dependency audit (Phase 6), and code quality analysis (Phase 7). These require more judgment than auto-fixes.

### Step 3.1: Security Findings (Phase 5) — Fix First

Security issues take priority. Common patterns and how to fix them:

Common security fix patterns:

| Finding | Fix |
|---------|-----|
| SQL injection (string formatting in queries) | Use parameterized queries with the project's DB library |
| Hardcoded secrets | Move to environment variable or config file; add config to `.gitignore`; note in output if secret was committed (user must rotate) |
| Insecure defaults (`debug=True`, `verify=False`) | Change to secure default; gate dev-only settings behind env vars |
| Weak crypto (MD5/SHA1 for security) | Replace with SHA-256+; for non-security use, add `usedforsecurity=False` (Python 3.9+) |
| Subprocess injection (`shell=True` + user input) | Switch to `shell=False` with argument list |

After each security fix, run the relevant test(s). If no test covers the fixed code, note it in the output — Phase 12 should add coverage.

### Step 3.2: Dependency Issues (Phase 6) — Fix Second

Use the language-appropriate audit-fix tool:

| Language | Auto-fix command | Manual fallback | Notes |
|----------|-----------------|-----------------|-------|
| Python | `pip-audit --fix` | `pip install --upgrade PKG` then update requirements.txt | Guard with `command -v` |
| Node.js | `npm audit fix` | `npm install PKG@version` | NEVER use `--force` (major version bumps break things) |
| Go | `go get -u PKG && go mod tidy` | — | — |
| Rust | `cargo update -p PKG` | — | — |

After updating dependencies, ALWAYS run the full test suite. Dependency updates can introduce breaking changes.

**Pinned versions with CVEs**: Update the pin to the minimum fixed version, not to latest. This minimizes breakage risk.

### Step 3.3: Quality Issues (Phase 7) — Fix Third

Quality issues from linters, complexity analysis, and dead code detection. Handle by subcategory:

**Remaining Lint Warnings** (not auto-fixed by Category 1): Read each warning, understand the code, fix manually. Common: unused variables (remove or prefix `_`), unreachable code (remove), bare `except:` (specify type), mutable default args (use `None`).

**High Complexity**: Extract helpers, use early returns, replace long if/elif with dicts. Run tests after refactoring.

**Dead Code**: Remove unused functions/classes/imports. Check for dynamic usage first (`getattr`, plugin loading, CLI entry points) with `Grep` — dead code detectors have false positives.

**Type Errors** (mypy, pyright, tsc): Add/correct annotations. Run the type checker after fixes. Use `# type: ignore[specific-error]` only as last resort.

### Step 3.4: Commit Audit Fixes

Once all audit findings are resolved:

```bash
git add -A
git commit -m "fix: resolve security, dependency, and quality findings from /test audit"
```

---

## Final Verification

After all three categories are complete, run a final comprehensive check:

```bash
# 1. Full test suite
pytest --tb=short -q 2>&1  # (or project-appropriate test command)

# 2. Lint check (should be clean)
ruff check . 2>&1  # (or project-appropriate linter)

# 3. Security scan (should show no new issues)
bandit -r src/ -q 2>&1  # (or project-appropriate security scanner)
```

If ANY check fails, go back and fix. Do not proceed to Phase 12 with known failures.

---

## Rules

Per the **Governing Law** (see test.md): all errors, warnings, and issues must be fixed. None may be skipped or deferred.

1. **Fix everything** — every identified issue gets fixed. No dismissals based on prior state, cosmetic nature, or severity classification.
2. **Verify every fix** — after each fix, run the relevant test(s). A fix without verification is not a fix.
3. **Don't break passing tests** — if a fix causes a previously passing test to fail, revert the fix and try a different approach. Record it in the output.
4. **Commit in batches by category** — auto-fixes together, test fixes together, audit fixes together. This makes rollback possible if a batch causes problems.
5. **Track what was fixed** — produce the structured output below so Phase 12 and the final report know what changed.

---

## Output Format

Produce this structured output at the end of the phase:

```
FIXES_APPLIED:
- file: path/to/file.py
  category: auto-format|test-fix|security|quality|dependency
  description: what was changed and why
  verified: true|false
  test_command: pytest tests/test_foo.py -k test_bar
```

Then produce the summary block:

```
═══════════════════════════════════════════════════════════════════
  PHASE 10: FIX ALL ISSUES
═══════════════════════════════════════════════════════════════════

Issues Received: N    Issues Fixed: N

By Category:
  Auto-Format: X files | Lint Auto-Fix: X | Test Failures: X
  Security: X | Dependencies: X updated | Quality: X

Verification:  Tests: N passed, 0 failed | Lint: 0 errors | Security: 0 new

Commits:
  1. abc1234 style: auto-format and lint fixes
  2. def5678 fix: resolve test failures
  3. ghi9012 fix: resolve audit findings

Status: PASS - All issues resolved
```

In `--interactive` mode, if a fix requires user input (credentials, architectural decision), append a `BLOCKED` section listing those items with the specific blocker. These are not deferred — they are actively blocked and must be resolved before /test can complete. Status becomes: `BLOCKED - N fixed, M awaiting user input`.
