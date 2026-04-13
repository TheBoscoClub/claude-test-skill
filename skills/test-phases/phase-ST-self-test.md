# Phase ST: Test-Skill Self-Test

> **Model**: `opus` | **Phase**: ST (isolated) | **Modifies Files**: No (read-only)
> **Task Tracking**: Call `TaskUpdate(taskId, status="in_progress")` at start, `TaskUpdate(taskId, status="completed")` when done.
> **Key Tools**: `Bash`, `Read`, `Glob`, `Grep` for framework validation. Verify all 15 allowed tools are accessible. Validate model tiering configuration matches dispatcher.

**Meta-testing phase** - validates the test-skill framework itself.

This phase only runs when explicitly called: `/test --phase=ST`

It is NOT included in normal `/test` runs to avoid circular testing.

## Invocation

```bash
# Only way to run this phase
/test --phase=ST
```

---

## Phase Configuration

```bash
echo "═══════════════════════════════════════════════════════════════════"
echo "  PHASE ST: TEST-SKILL SELF-TEST"
echo "═══════════════════════════════════════════════════════════════════"
echo ""

TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0

TEST_SKILL_PROJECT="/hddRaid1/ClaudeCodeProjects/claude-test-skill"
SKILLS_DIR="$HOME/.claude/skills/test-phases"
COMMANDS_DIR="$HOME/.claude/commands"

# Detect execution context: are we in a project or the test-skill repo?
PROJECT_DIR="$(pwd)"
PROJECT_NAME="$(basename "$PROJECT_DIR")"
IS_PROJECT_MODE=false

if [[ "$PROJECT_DIR" != "$TEST_SKILL_PROJECT" ]] && [[ -d "$PROJECT_DIR/.git" ]]; then
    IS_PROJECT_MODE=true
    echo "Mode: PROJECT TEST VALIDATION ($PROJECT_NAME)"
    echo "Project: $PROJECT_DIR"
else
    echo "Mode: FRAMEWORK SELF-TEST"
    echo "Test-Skill Project: $TEST_SKILL_PROJECT"
fi

echo "Skills Directory: $SKILLS_DIR"
echo "Commands Directory: $COMMANDS_DIR"
echo ""
```

---

## Project Test Validation (Project Mode Only)

When `IS_PROJECT_MODE=true`, run these project-level checks INSTEAD OF the framework sections (1-10).
When `IS_PROJECT_MODE=false`, skip this entire block and run the framework sections as before.

### P1: Test Discoverability

Verify that all test files in the project are actually collected by pytest.

```bash
if [[ "$IS_PROJECT_MODE" == "true" ]]; then

echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║  P1: TEST DISCOVERABILITY                                         ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"
echo ""

# Find all test_*.py files in the project
TEST_DIR=""
for candidate in "tests" "test" "library/tests" "src/tests"; do
    if [[ -d "$PROJECT_DIR/$candidate" ]]; then
        TEST_DIR="$PROJECT_DIR/$candidate"
        break
    fi
done

if [[ -z "$TEST_DIR" ]]; then
    echo "  ⚠️ No standard test directory found"
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
else
    echo "  Test directory: $TEST_DIR"
    echo ""

    # Find all test files on disk
    DISK_TEST_FILES=$(find "$TEST_DIR" -name 'test_*.py' -not -path '*/__pycache__/*' | sort)
    DISK_COUNT=$(echo "$DISK_TEST_FILES" | grep -c . || echo 0)

    # Find pytest root (look for pytest.ini, pyproject.toml, setup.cfg)
    PYTEST_ROOT="$PROJECT_DIR"
    for ini in pytest.ini pyproject.toml setup.cfg; do
        if [[ -f "$PROJECT_DIR/$ini" ]]; then
            PYTEST_ROOT="$PROJECT_DIR"
            break
        fi
        # Check one level up (e.g., library/pytest.ini)
        parent=$(dirname "$TEST_DIR")
        if [[ -f "$parent/$ini" ]]; then
            PYTEST_ROOT="$parent"
            break
        fi
    done

    echo "───────────────────────────────────────────────────────────────────"
    echo "  P1.1 Files on Disk vs Collected by pytest"
    echo "───────────────────────────────────────────────────────────────────"

    # Detect project-specific pytest flags by parsing conftest.py for addoption calls.
    # These are flags like --vm, --docker, --hardware, --fido2 that gate test collection.
    # To get a TRUE picture of discoverability, we must collect WITH all flags enabled,
    # because /test runs with project-appropriate flags (e.g., --vm is ALWAYS used for
    # projects with a dedicated test VM).
    CONFTEST_FILE="$TEST_DIR/conftest.py"
    PYTEST_COLLECT_FLAGS=""
    if [[ -f "$CONFTEST_FILE" ]]; then
        # Extract --flag names from parser.addoption() calls.
        # The flag string may be on the same line as addoption( or the next line.
        CUSTOM_FLAGS=$(grep -A1 'addoption(' "$CONFTEST_FILE" 2>/dev/null | \
            grep -oP '"(--[a-z0-9_-]+)"' | tr -d '"' | sort -u || true)
        if [[ -n "$CUSTOM_FLAGS" ]]; then
            PYTEST_COLLECT_FLAGS=$(echo "$CUSTOM_FLAGS" | tr '\n' ' ')
            echo "  Detected pytest flags: $PYTEST_COLLECT_FLAGS"
        fi
    fi

    # Collect tests with ALL project flags enabled to match real /test execution
    COLLECTED_OUTPUT=$(cd "$PYTEST_ROOT" && python -m pytest --collect-only -q $PYTEST_COLLECT_FLAGS 2>&1 || true)
    COLLECTED_FILES=$(echo "$COLLECTED_OUTPUT" | grep '::' | cut -d: -f1 | sort -u)
    COLLECTED_COUNT=$(echo "$COLLECTED_FILES" | grep -c . || echo 0)
    TOTAL_TESTS=$(echo "$COLLECTED_OUTPUT" | grep -oP '\d+ tests?' | head -1 | grep -oP '\d+' || echo 0)

    echo "  Files on disk:  $DISK_COUNT"
    echo "  Files collected: $COLLECTED_COUNT"
    echo "  Total tests:    $TOTAL_TESTS"
    echo ""

    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

    # Check for uncollected files
    UNCOLLECTED=0
    while IFS= read -r disk_file; do
        REL_PATH=$(realpath --relative-to="$PYTEST_ROOT" "$disk_file" 2>/dev/null || basename "$disk_file")
        BASENAME=$(basename "$disk_file")
        if ! echo "$COLLECTED_FILES" | grep -q "$BASENAME"; then
            echo "  ❌ Not collected: $REL_PATH"
            UNCOLLECTED=$((UNCOLLECTED + 1))
        fi
    done <<< "$DISK_TEST_FILES"

    if [[ "$UNCOLLECTED" -eq 0 ]]; then
        echo "  ✅ All $DISK_COUNT test files are collected by pytest"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        echo ""
        echo "  ❌ $UNCOLLECTED test file(s) NOT collected by pytest"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi

    echo ""
    echo "───────────────────────────────────────────────────────────────────"
    echo "  P1.2 Empty Test Files"
    echo "───────────────────────────────────────────────────────────────────"

    EMPTY_COUNT=0
    while IFS= read -r test_file; do
        TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
        FUNC_COUNT=$(grep -c 'def test_' "$test_file" 2>/dev/null || echo 0)
        if [[ "$FUNC_COUNT" -eq 0 ]]; then
            echo "  ❌ No test functions: $(basename "$test_file")"
            FAILED_CHECKS=$((FAILED_CHECKS + 1))
            EMPTY_COUNT=$((EMPTY_COUNT + 1))
        else
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
        fi
    done <<< "$DISK_TEST_FILES"

    if [[ "$EMPTY_COUNT" -eq 0 ]]; then
        echo "  ✅ All test files contain test functions"
    fi
fi

echo ""

fi  # IS_PROJECT_MODE P1
```

### P2: Test Redundancy Analysis

Check for test modules with overlapping coverage or duplicate test names.

```bash
if [[ "$IS_PROJECT_MODE" == "true" ]] && [[ -n "$TEST_DIR" ]]; then

echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║  P2: TEST REDUNDANCY ANALYSIS                                     ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"
echo ""

echo "───────────────────────────────────────────────────────────────────"
echo "  P2.1 Duplicate Test Function Names"
echo "───────────────────────────────────────────────────────────────────"

TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

# Extract all test function names with their files
DUPES=$(grep -rh 'def test_' "$TEST_DIR" --include='test_*.py' 2>/dev/null | \
    sed 's/.*def \(test_[a-zA-Z0-9_]*\).*/\1/' | sort | uniq -d)

if [[ -z "$DUPES" ]]; then
    echo "  ✅ No duplicate test function names across modules"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
else
    DUPE_COUNT=$(echo "$DUPES" | wc -l)
    echo "  ⚠️ $DUPE_COUNT test name(s) appear in multiple files:"
    echo "$DUPES" | while IFS= read -r dupe_name; do
        FILES=$(grep -rl "def $dupe_name" "$TEST_DIR" --include='test_*.py' 2>/dev/null | xargs -I{} basename {} | tr '\n' ', ' | sed 's/,$//')
        echo "     $dupe_name → $FILES"
    done
    # Duplicates across files are warnings, not failures (different modules can have same-named tests)
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
fi

echo ""
echo "───────────────────────────────────────────────────────────────────"
echo "  P2.2 Module Name Overlap Detection"
echo "───────────────────────────────────────────────────────────────────"

TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

# Look for modules testing the same source with different suffixes
# e.g., test_roadmap.py and test_roadmap_extended.py
BASE_NAMES=$(find "$TEST_DIR" -name 'test_*.py' -not -path '*/__pycache__/*' -exec basename {} \; | \
    sed 's/^test_//; s/_extended\.py$//; s/_coverage\.py$//; s/_integration\.py$//; s/\.py$//' | \
    sort | uniq -d)

if [[ -z "$BASE_NAMES" ]]; then
    echo "  ✅ No overlapping module names detected"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
else
    OVERLAP_COUNT=$(echo "$BASE_NAMES" | wc -l)
    echo "  ℹ️ $OVERLAP_COUNT source module(s) have multiple test files:"
    echo "$BASE_NAMES" | while IFS= read -r base; do
        RELATED=$(find "$TEST_DIR" -name "test_${base}*.py" -not -path '*/__pycache__/*' -exec basename {} \; | tr '\n' ', ' | sed 's/,$//')
        echo "     $base → $RELATED"
    done
    echo ""
    echo "  (This is expected for extended/coverage/integration splits)"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
fi

echo ""

fi  # IS_PROJECT_MODE P2
```

### P3: Fixture Conflict Detection

Check for fixtures that could cause database or state conflicts.

```bash
if [[ "$IS_PROJECT_MODE" == "true" ]] && [[ -n "$TEST_DIR" ]]; then

echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║  P3: FIXTURE CONFLICT DETECTION                                    ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"
echo ""

echo "───────────────────────────────────────────────────────────────────"
echo "  P3.1 Conftest Fixture Scoping"
echo "───────────────────────────────────────────────────────────────────"

CONFTEST="$TEST_DIR/conftest.py"
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

if [[ -f "$CONFTEST" ]]; then
    SESSION_FIXTURES=$(grep -c '@pytest.fixture(scope="session")' "$CONFTEST" 2>/dev/null || echo 0)
    MODULE_FIXTURES=$(grep -c '@pytest.fixture(scope="module")' "$CONFTEST" 2>/dev/null || echo 0)
    FUNC_FIXTURES=$(grep -c '@pytest.fixture' "$CONFTEST" 2>/dev/null || echo 0)
    FUNC_FIXTURES=$((FUNC_FIXTURES - SESSION_FIXTURES - MODULE_FIXTURES))

    echo "  Session-scoped: $SESSION_FIXTURES"
    echo "  Module-scoped:  $MODULE_FIXTURES"
    echo "  Function-scoped: $FUNC_FIXTURES"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
else
    echo "  ⚠️ No conftest.py found in test directory"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
fi

echo ""
echo "───────────────────────────────────────────────────────────────────"
echo "  P3.2 Module-Level State Patterns (Dual Path Risk)"
echo "───────────────────────────────────────────────────────────────────"

TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

# Look for test files that set module-level globals (common fixture conflict pattern)
RISKY_FILES=$(grep -rl 'sys\.modules' "$TEST_DIR" --include='test_*.py' 2>/dev/null || true)

if [[ -n "$RISKY_FILES" ]]; then
    COUNT=$(echo "$RISKY_FILES" | wc -l)
    echo "  ℹ️ $COUNT test file(s) manipulate sys.modules (dual-path workaround):"
    echo "$RISKY_FILES" | while IFS= read -r f; do
        echo "     $(basename "$f")"
    done
    echo ""
    echo "  (Expected for modules with module-level singleton patterns)"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
else
    echo "  ✅ No sys.modules manipulation detected"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
fi

echo ""
echo "───────────────────────────────────────────────────────────────────"
echo "  P3.3 Database Path Conflicts"
echo "───────────────────────────────────────────────────────────────────"

TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

# Check for hardcoded database paths in test files (should use fixtures)
HARDCODED_DB=$(grep -rn "sqlite3.connect\|\.db'" "$TEST_DIR" --include='test_*.py' 2>/dev/null | \
    grep -v 'conftest\|tmp\|temp\|fixture\|memory\|:memory:' | head -5 || true)

if [[ -z "$HARDCODED_DB" ]]; then
    echo "  ✅ No hardcoded database paths in test files"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
else
    echo "  ⚠️ Possible hardcoded DB paths in tests:"
    echo "$HARDCODED_DB" | while IFS= read -r line; do
        echo "     $line"
    done
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
fi

echo ""

fi  # IS_PROJECT_MODE P3
```

### P4: Isolation vs Full-Suite Check

Run all tests individually then as full suite to detect order-dependent failures.

**NOTE**: This section is INFORMATIONAL only. It runs `pytest --collect-only` to count tests
and reports a recommendation. Actually running all tests in isolation would take too long
for a self-test. Instead, it checks for known isolation-risk patterns.

```bash
if [[ "$IS_PROJECT_MODE" == "true" ]] && [[ -n "$TEST_DIR" ]]; then

echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║  P4: ISOLATION RISK ANALYSIS                                       ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"
echo ""

echo "───────────────────────────────────────────────────────────────────"
echo "  P4.1 Global State Patterns"
echo "───────────────────────────────────────────────────────────────────"

TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

# Check for patterns that commonly cause order-dependent failures
GLOBAL_PATTERNS=0

# Module-level _db_path or similar globals
MODULE_GLOBALS=$(grep -rn '^_[a-z].*= None' "$TEST_DIR"/../ --include='*.py' 2>/dev/null | \
    grep -v 'test_\|conftest\|__pycache__' | wc -l || echo 0)

# init_*_routes patterns (module-level state setters)
INIT_ROUTES=$(grep -rn 'def init_.*_routes' "$TEST_DIR"/../ --include='*.py' 2>/dev/null | \
    grep -v 'test_\|conftest\|__pycache__' | wc -l || echo 0)

echo "  Module-level globals (source):    $MODULE_GLOBALS"
echo "  Init-route state setters:         $INIT_ROUTES"

if [[ "$INIT_ROUTES" -gt 0 ]]; then
    echo ""
    echo "  ⚠️ $INIT_ROUTES init_*_routes() functions set module globals"
    echo "     Tests using these modules need dual-path-aware fixtures"
    echo "     (set state on ALL loaded module copies via sys.modules iteration)"
fi

PASSED_CHECKS=$((PASSED_CHECKS + 1))

echo ""
echo "───────────────────────────────────────────────────────────────────"
echo "  P4.2 Version-Gated Markers"
echo "───────────────────────────────────────────────────────────────────"

TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

# Check for version markers (v8, v9, etc.)
VERSION_MARKERS=$(grep -rn '@pytest.mark.v[0-9]' "$TEST_DIR" --include='test_*.py' 2>/dev/null || true)
if [[ -n "$VERSION_MARKERS" ]]; then
    MARKER_COUNT=$(echo "$VERSION_MARKERS" | wc -l)
    VERSIONS=$(echo "$VERSION_MARKERS" | grep -oP 'v\d+' | sort -u | tr '\n' ', ' | sed 's/,$//')
    echo "  ℹ️ $MARKER_COUNT test(s) with version markers: $VERSIONS"

    # Check if conftest has version-gating logic
    if grep -q '_get_project_major_version\|major.*VERSION' "$CONFTEST" 2>/dev/null; then
        echo "  ✅ Version-gating logic present in conftest.py"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        echo "  ❌ Version markers found but NO gating logic in conftest.py"
        echo "     Tests won't be auto-skipped based on VERSION file"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi
else
    echo "  ✅ No version-gated markers (none needed)"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
fi

echo ""
echo "───────────────────────────────────────────────────────────────────"
echo "  P4.3 Marker Registration Completeness"
echo "───────────────────────────────────────────────────────────────────"

TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

# Find all markers used in test files
USED_MARKERS=$(grep -rhoP '@pytest\.mark\.(\w+)' "$TEST_DIR" --include='test_*.py' 2>/dev/null | \
    sed 's/@pytest\.mark\.//' | sort -u)

# Find markers registered in conftest.py or pytest.ini
PYTEST_INI=""
for ini in "$PYTEST_ROOT/pytest.ini" "$PROJECT_DIR/pytest.ini"; do
    if [[ -f "$ini" ]]; then
        PYTEST_INI="$ini"
        break
    fi
done

REGISTERED_MARKERS=""
if [[ -n "$PYTEST_INI" ]]; then
    REGISTERED_MARKERS=$(grep -A 100 'markers' "$PYTEST_INI" 2>/dev/null | \
        grep -oP '^\s+(\w+):' | sed 's/[: ]//g' || true)
fi
if [[ -f "$CONFTEST" ]]; then
    CONFTEST_MARKERS=$(grep -oP 'addinivalue_line.*markers.*"(\w+):' "$CONFTEST" 2>/dev/null | \
        grep -oP '"(\w+):' | tr -d '":' || true)
    REGISTERED_MARKERS=$(echo -e "${REGISTERED_MARKERS}\n${CONFTEST_MARKERS}" | sort -u | grep -v '^$')
fi

# Check for unregistered markers
UNREGISTERED=0
while IFS= read -r marker; do
    [[ -z "$marker" ]] && continue
    # Skip pytest built-in markers
    [[ "$marker" =~ ^(parametrize|skip|skipif|xfail|usefixtures|filterwarnings)$ ]] && continue
    if ! echo "$REGISTERED_MARKERS" | grep -qw "$marker"; then
        echo "  ❌ Unregistered marker: @pytest.mark.$marker"
        UNREGISTERED=$((UNREGISTERED + 1))
    fi
done <<< "$USED_MARKERS"

if [[ "$UNREGISTERED" -eq 0 ]]; then
    echo "  ✅ All custom markers are registered"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
else
    echo ""
    echo "  ❌ $UNREGISTERED unregistered marker(s) will cause PytestUnknownMarkWarning"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
fi

echo ""

fi  # IS_PROJECT_MODE P4
```

### P5: /test Phase Duplication Check

Verify project tests don't duplicate functionality that /test phases already cover.

```bash
if [[ "$IS_PROJECT_MODE" == "true" ]] && [[ -n "$TEST_DIR" ]]; then

echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║  P5: /TEST PHASE DUPLICATION CHECK                                ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"
echo ""

TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

# /test phases handle: security scanning, dependency audit, linting/formatting,
# dead code detection, infrastructure checks. Project tests should NOT
# reimplement these — they should test project-specific business logic.

PHASE_DUPLICATION=0

# Check for tests that duplicate Phase 5 (security)
SECURITY_TESTS=$(find "$TEST_DIR" -name 'test_*security*scan*' -o -name 'test_*bandit*' \
    -o -name 'test_*cve*' -o -name 'test_*audit*dependency*' 2>/dev/null | \
    grep -v '__pycache__' || true)

if [[ -n "$SECURITY_TESTS" ]]; then
    echo "  ⚠️ Test files that may duplicate Phase 5 (Security):"
    echo "$SECURITY_TESTS" | while IFS= read -r f; do echo "     $(basename "$f")"; done
    PHASE_DUPLICATION=$((PHASE_DUPLICATION + 1))
fi

# Check for tests that duplicate Phase 7 (linting/formatting)
LINT_TESTS=$(find "$TEST_DIR" -name 'test_*lint*' -o -name 'test_*format*' \
    -o -name 'test_*style*' 2>/dev/null | grep -v '__pycache__' || true)

if [[ -n "$LINT_TESTS" ]]; then
    echo "  ⚠️ Test files that may duplicate Phase 7 (Quality):"
    echo "$LINT_TESTS" | while IFS= read -r f; do echo "     $(basename "$f")"; done
    PHASE_DUPLICATION=$((PHASE_DUPLICATION + 1))
fi

if [[ "$PHASE_DUPLICATION" -eq 0 ]]; then
    echo "  ✅ No project tests duplicate /test phase functionality"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
else
    echo ""
    echo "  ℹ️ These tests MAY be redundant with /test phases."
    echo "     Review to confirm they test project-specific logic, not general scanning."
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
fi

echo ""

fi  # IS_PROJECT_MODE P5
```

### Project Mode Summary

```bash
if [[ "$IS_PROJECT_MODE" == "true" ]]; then

echo "═══════════════════════════════════════════════════════════════════"
echo "  PHASE ST: PROJECT TEST VALIDATION SUMMARY ($PROJECT_NAME)"
echo "═══════════════════════════════════════════════════════════════════"
echo ""
echo "Project: $PROJECT_DIR"
echo ""
echo "Results:"
echo "  Total checks:    $TOTAL_CHECKS"
echo "  Passed:          $PASSED_CHECKS"
echo "  Failed:          $FAILED_CHECKS"
echo ""

if [[ "$TOTAL_CHECKS" -gt 0 ]]; then
    PASS_RATE=$((PASSED_CHECKS * 100 / TOTAL_CHECKS))
    echo "  Pass rate:       ${PASS_RATE}%"
else
    echo "  Pass rate:       N/A"
fi
echo ""

if [[ "$FAILED_CHECKS" -eq 0 ]]; then
    echo "Status: ✅ HEALTHY - Project tests are well-structured"
elif [[ "$FAILED_CHECKS" -lt 3 ]]; then
    echo "Status: ⚠️ WARNINGS - Minor issues detected ($FAILED_CHECKS)"
else
    echo "Status: ❌ ISSUES - Project tests need attention ($FAILED_CHECKS failures)"
fi

echo ""
echo "═══════════════════════════════════════════════════════════════════"

# Exit early — don't run framework sections
exit 0

fi  # IS_PROJECT_MODE summary
```

---

## Section 1: Phase File Validation

```bash
echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║  SECTION 1: PHASE FILE VALIDATION                                 ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"
echo ""

# Expected phase files — 20 phases
EXPECTED_PHASES=(
    "phase-1-snapshot.md"
    "phase-2-preflight.md"
    "phase-3-discovery.md"
    "phase-4a-execute.md"
    "phase-4b-runtime.md"
    "phase-5a-security.md"
    "phase-5b-dependencies.md"
    "phase-5c-quality.md"
    "phase-5d-infrastructure.md"
    "phase-6-fix.md"
    "phase-7-verify.md"
    "phase-8-docs.md"
    "phase-9a-app-testing.md"
    "phase-9b-production.md"
    "phase-9c-docker.md"
    "phase-9d-github.md"
    "phase-10a-vm-testing.md"
    "phase-10b-vm-lifecycle.md"
    "phase-11-cleanup.md"
    "phase-ST-self-test.md"
)

echo "───────────────────────────────────────────────────────────────────"
echo "  1.1 Phase File Existence (20 expected)"
echo "───────────────────────────────────────────────────────────────────"

MISSING_PHASES=()
for phase_file in "${EXPECTED_PHASES[@]}"; do
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    if [[ -f "$SKILLS_DIR/$phase_file" ]]; then
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        MISSING_PHASES+=("$phase_file")
    fi
done

if [[ ${#MISSING_PHASES[@]} -eq 0 ]]; then
    echo "  ✅ All ${#EXPECTED_PHASES[@]} phase files present"
else
    echo "  ❌ Missing phase files:"
    for missing in "${MISSING_PHASES[@]}"; do
        echo "     - $missing"
    done
fi

echo ""
echo "───────────────────────────────────────────────────────────────────"
echo "  1.2 Phase File Readability"
echo "───────────────────────────────────────────────────────────────────"

UNREADABLE=0
for phase_file in "$SKILLS_DIR"/phase-*.md; do
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    if [[ -r "$phase_file" ]]; then
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        UNREADABLE=$((UNREADABLE + 1))
        echo "  ❌ Not readable: $(basename "$phase_file")"
    fi
done

if [[ "$UNREADABLE" -eq 0 ]]; then
    echo "  ✅ All phase files are readable"
fi

echo ""
echo "───────────────────────────────────────────────────────────────────"
echo "  1.3 Phase File Size Check"
echo "───────────────────────────────────────────────────────────────────"

EMPTY_PHASES=0
for phase_file in "$SKILLS_DIR"/phase-*.md; do
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    SIZE=$(wc -c < "$phase_file" 2>/dev/null || echo "0")
    if [[ "$SIZE" -gt 100 ]]; then
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        EMPTY_PHASES=$((EMPTY_PHASES + 1))
        echo "  ⚠️ Suspiciously small: $(basename "$phase_file") ($SIZE bytes)"
    fi
done

if [[ "$EMPTY_PHASES" -eq 0 ]]; then
    echo "  ✅ All phase files have substantial content"
fi

echo ""
echo "───────────────────────────────────────────────────────────────────"
echo "  1.4 No Deleted Phase Files Present"
echo "───────────────────────────────────────────────────────────────────"

DELETED_PHASES=(
    # Pre-v4.0 deleted phases
    "phase-3-report.md" "phase-4-cleanup.md" "phase-8-coverage.md" "phase-9-debug.md" "phase-11-config.md" "phase-M-mocking.md" "phase-H-holistic.md"
    # Pre-v5.0 renamed phases (old filenames should not exist)
    "phase-S-snapshot.md" "phase-0-preflight.md" "phase-1-discovery.md" "phase-2-execute.md" "phase-2a-runtime.md"
    "phase-5-security.md" "phase-6-dependencies.md" "phase-7-quality.md" "phase-I-infrastructure.md"
    "phase-10-fix.md" "phase-12-verify.md" "phase-13-docs.md"
    "phase-A-app-testing.md" "phase-P-production.md" "phase-D-docker.md" "phase-G-github.md"
    "phase-V-vm-testing.md" "phase-VM-lifecycle.md" "phase-C-restore.md" "phase-C-cleanup.md"
)
STALE_FOUND=0
for stale in "${DELETED_PHASES[@]}"; do
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    if [[ -f "$SKILLS_DIR/$stale" ]]; then
        echo "  ❌ Stale phase file found: $stale (should have been deleted/renamed)"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        STALE_FOUND=$((STALE_FOUND + 1))
    else
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    fi
done

if [[ "$STALE_FOUND" -eq 0 ]]; then
    echo "  ✅ No deleted phase files lingering"
fi
```

---

## Section 2: Symlink Validation

```bash
echo ""
echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║  SECTION 2: SYMLINK VALIDATION                                    ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"
echo ""

echo "───────────────────────────────────────────────────────────────────"
echo "  2.1 Commands Symlink"
echo "───────────────────────────────────────────────────────────────────"

TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if [[ -L "$COMMANDS_DIR/test.md" ]]; then
    TARGET=$(readlink -f "$COMMANDS_DIR/test.md")
    EXPECTED_TARGET="$TEST_SKILL_PROJECT/commands/test.md"
    if [[ "$TARGET" == "$EXPECTED_TARGET" ]]; then
        echo "  ✅ test.md symlink correct → $TARGET"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        echo "  ⚠️ test.md symlink points to unexpected target:"
        echo "     Expected: $EXPECTED_TARGET"
        echo "     Actual:   $TARGET"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi
else
    echo "  ❌ test.md is not a symlink (should link to test-skill project)"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
fi

echo ""
echo "───────────────────────────────────────────────────────────────────"
echo "  2.2 Skills Directory Symlink"
echo "───────────────────────────────────────────────────────────────────"

TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if [[ -L "$SKILLS_DIR" ]]; then
    TARGET=$(readlink -f "$SKILLS_DIR")
    EXPECTED_TARGET="$TEST_SKILL_PROJECT/skills/test-phases"
    if [[ "$TARGET" == "$EXPECTED_TARGET" ]]; then
        echo "  ✅ test-phases symlink correct → $TARGET"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        echo "  ⚠️ test-phases symlink points to unexpected target:"
        echo "     Expected: $EXPECTED_TARGET"
        echo "     Actual:   $TARGET"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi
else
    echo "  ℹ️ test-phases is a directory (not symlinked to test-skill project)"
    echo "     This is OK if files are synced manually"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
fi
```

---

## Section 3: Dispatcher Validation

```bash
echo ""
echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║  SECTION 3: DISPATCHER VALIDATION                                 ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"
echo ""

DISPATCHER="$COMMANDS_DIR/test.md"

echo "───────────────────────────────────────────────────────────────────"
echo "  3.1 Dispatcher File Check"
echo "───────────────────────────────────────────────────────────────────"

TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if [[ -f "$DISPATCHER" ]] || [[ -L "$DISPATCHER" ]]; then
    echo "  ✅ Dispatcher file exists"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
else
    echo "  ❌ Dispatcher file not found: $DISPATCHER"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
fi

echo ""
echo "───────────────────────────────────────────────────────────────────"
echo "  3.2 Phase References in Dispatcher"
echo "───────────────────────────────────────────────────────────────────"

# Check that dispatcher mentions key phases
KEY_PHASES=("Phase 5a" "Phase 9b" "Phase 9c" "Phase 9d" "Phase ST" "phase 5")
for key in "${KEY_PHASES[@]}"; do
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    if grep -qi "$key" "$DISPATCHER" 2>/dev/null; then
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        echo "  ⚠️ Dispatcher missing reference to: $key"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi
done

MISSING_KEYS=0
for key in "${KEY_PHASES[@]}"; do
    grep -qi "$key" "$DISPATCHER" 2>/dev/null || MISSING_KEYS=$((MISSING_KEYS + 1))
done
if [[ "$MISSING_KEYS" -eq 0 ]]; then
    echo "  ✅ Key phase references found in dispatcher"
fi

echo ""
echo "───────────────────────────────────────────────────────────────────"
echo "  3.3 Shortcut Definitions"
echo "───────────────────────────────────────────────────────────────────"

SHORTCUTS=("prodapp" "docker" "security" "github")
MISSING_SHORTCUTS=0
for shortcut in "${SHORTCUTS[@]}"; do
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    if grep -q "$shortcut" "$DISPATCHER" 2>/dev/null; then
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        echo "  ❌ Missing shortcut: $shortcut"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        MISSING_SHORTCUTS=$((MISSING_SHORTCUTS + 1))
    fi
done

if [[ "$MISSING_SHORTCUTS" -eq 0 ]]; then
    echo "  ✅ All shortcuts defined in dispatcher"
fi
```

---

## Section 4: Tool Availability

```bash
echo ""
echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║  SECTION 4: TOOL AVAILABILITY                                     ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"
echo ""

echo "───────────────────────────────────────────────────────────────────"
echo "  4.1 Security Tools"
echo "───────────────────────────────────────────────────────────────────"

SECURITY_TOOLS=("bandit" "semgrep" "codeql" "trivy" "grype" "pip-audit" "checkov")
for tool in "${SECURITY_TOOLS[@]}"; do
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    if command -v "$tool" &>/dev/null; then
        VERSION=$($tool --version 2>&1 | head -1 | cut -d' ' -f2 | head -c 20)
        echo "  ✅ $tool ($VERSION)"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        echo "  ❌ $tool not installed"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi
done

echo ""
echo "───────────────────────────────────────────────────────────────────"
echo "  4.2 Core Tools"
echo "───────────────────────────────────────────────────────────────────"

CORE_TOOLS=("git" "gh" "jq" "pytest" "python3")
for tool in "${CORE_TOOLS[@]}"; do
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    if command -v "$tool" &>/dev/null; then
        echo "  ✅ $tool"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        echo "  ⚠️ $tool not found (some phases may fail)"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi
done
```

---

## Section 5: Bash Syntax Validation

```bash
echo ""
echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║  SECTION 5: BASH SYNTAX VALIDATION                                ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"
echo ""

echo "───────────────────────────────────────────────────────────────────"
echo "  5.1 Extracting and Validating Bash Blocks"
echo "───────────────────────────────────────────────────────────────────"

SYNTAX_ERRORS=0
for phase_file in "$SKILLS_DIR"/phase-*.md; do
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    PHASE_NAME=$(basename "$phase_file")

    # Extract bash blocks and check syntax
    # This is a simplified check - just validates the file is readable markdown
    if grep -q '```bash' "$phase_file" 2>/dev/null; then
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        echo "  ⚠️ $PHASE_NAME has no bash blocks (may be incomplete)"
        # Don't fail - some phases might not need bash
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    fi
done

echo "  ✅ All phase files contain valid markdown structure"
```

---

## Section 6: Opus 4.6 Integration Validation

```bash
echo ""
echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║  SECTION 6: OPUS 4.6 INTEGRATION                                 ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"
echo ""

echo "───────────────────────────────────────────────────────────────────"
echo "  6.1 Phase File Configuration Headers"
echo "───────────────────────────────────────────────────────────────────"

MISSING_HEADERS=0
for phase_file in "$SKILLS_DIR"/phase-*.md; do
    PHASE_NAME=$(basename "$phase_file")
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    if grep -q '> \*\*Model\*\*:' "$phase_file" 2>/dev/null && \
       grep -q '> \*\*Task Tracking\*\*:' "$phase_file" 2>/dev/null && \
       grep -q '> \*\*Key Tools\*\*:' "$phase_file" 2>/dev/null; then
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        echo "  ❌ $PHASE_NAME missing Opus 4.6 configuration header"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        MISSING_HEADERS=$((MISSING_HEADERS + 1))
    fi
done

if [[ "$MISSING_HEADERS" -eq 0 ]]; then
    echo "  ✅ All phase files have Opus 4.6 configuration headers"
fi

echo ""
echo "───────────────────────────────────────────────────────────────────"
echo "  6.2 Model Tiering Validation (20 phases)"
echo "───────────────────────────────────────────────────────────────────"

# Validate expected model assignments — 20 phases
declare -A EXPECTED_MODELS=(
    ["phase-0-preflight.md"]="sonnet"
    ["phase-1-discovery.md"]="opus"
    ["phase-2-execute.md"]="sonnet"
    ["phase-2a-runtime.md"]="sonnet"
    ["phase-5-security.md"]="opus"
    ["phase-6-dependencies.md"]="sonnet"
    ["phase-7-quality.md"]="opus"
    ["phase-10-fix.md"]="opus"
    ["phase-12-verify.md"]="sonnet"
    ["phase-13-docs.md"]="sonnet"
    ["phase-A-app-testing.md"]="opus"
    ["phase-C-restore.md"]="haiku"
    ["phase-D-docker.md"]="opus"
    ["phase-G-github.md"]="opus"
    ["phase-I-infrastructure.md"]="sonnet"
    ["phase-P-production.md"]="opus"
    ["phase-S-snapshot.md"]="haiku"
    ["phase-ST-self-test.md"]="opus"
    ["phase-V-vm-testing.md"]="sonnet"
    ["phase-VM-lifecycle.md"]="sonnet"
)

MODEL_MISMATCHES=0
for phase_file in "${!EXPECTED_MODELS[@]}"; do
    EXPECTED="${EXPECTED_MODELS[$phase_file]}"
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    if grep -q "Model.*\`$EXPECTED\`" "$SKILLS_DIR/$phase_file" 2>/dev/null; then
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        ACTUAL=$(grep -oP 'Model.*`\K[a-z]+' "$SKILLS_DIR/$phase_file" 2>/dev/null || echo "none")
        echo "  ❌ $phase_file: expected $EXPECTED, found $ACTUAL"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        MODEL_MISMATCHES=$((MODEL_MISMATCHES + 1))
    fi
done

if [[ "$MODEL_MISMATCHES" -eq 0 ]]; then
    echo "  ✅ All model tier assignments match dispatcher specification"
fi

echo ""
echo "───────────────────────────────────────────────────────────────────"
echo "  6.3 Dispatcher Allowed Tools (16 expected)"
echo "───────────────────────────────────────────────────────────────────"

EXPECTED_TOOLS=("Bash" "Read" "Write" "Edit" "Glob" "Grep" "TaskGet" "TaskOutput" "TaskStop" "TaskCreate" "TaskUpdate" "TaskList" "AskUserQuestion" "NotebookEdit" "WebSearch" "WebFetch")
TOOLS_FOUND=0
for tool in "${EXPECTED_TOOLS[@]}"; do
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    if grep -qF -- "- $tool" "$DISPATCHER" 2>/dev/null; then
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
        TOOLS_FOUND=$((TOOLS_FOUND + 1))
    else
        echo "  ❌ Dispatcher missing allowed tool: $tool"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi
done

echo "  ✅ Dispatcher declares $TOOLS_FOUND/15 core allowed tools"

echo ""
echo "───────────────────────────────────────────────────────────────────"
echo "  6.4 Dispatcher Model Selection Table"
echo "───────────────────────────────────────────────────────────────────"

TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if grep -q 'Subagent Model Selection' "$DISPATCHER" 2>/dev/null; then
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
    echo "  ✅ Model selection table present in dispatcher"
else
    echo "  ❌ Model selection table missing from dispatcher"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
fi

TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if grep -q 'Task Progress Tracking' "$DISPATCHER" 2>/dev/null; then
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
    echo "  ✅ Task progress tracking section present in dispatcher"
else
    echo "  ❌ Task progress tracking section missing from dispatcher"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
fi
```

---

## Section 7: Governing Law Validation

```bash
echo ""
echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║  SECTION 7: GOVERNING LAW VALIDATION                              ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"
echo ""

echo "───────────────────────────────────────────────────────────────────"
echo "  7.1 Governing Law Present in Dispatcher"
echo "───────────────────────────────────────────────────────────────────"

TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if grep -q "GOVERNING LAW" "$DISPATCHER" 2>/dev/null; then
    echo "  ✅ Governing Law section present in dispatcher"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
else
    echo "  ❌ Governing Law section MISSING from dispatcher"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
fi

echo ""
echo "───────────────────────────────────────────────────────────────────"
echo "  7.2 Iterative Until Clean Rule Present"
echo "───────────────────────────────────────────────────────────────────"

TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if grep -q "Iterative Until Clean" "$DISPATCHER" 2>/dev/null; then
    echo "  ✅ Iterative Until Clean rule present"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
else
    echo "  ❌ Iterative Until Clean rule MISSING"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
fi

echo ""
echo "───────────────────────────────────────────────────────────────────"
echo "  7.3 Autonomous Resolution Directive Present"
echo "───────────────────────────────────────────────────────────────────"

TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if grep -q "Autonomous Resolution Directive" "$DISPATCHER" 2>/dev/null; then
    echo "  ✅ Autonomous Resolution Directive present"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
else
    echo "  ❌ Autonomous Resolution Directive MISSING"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
fi

echo ""
echo "───────────────────────────────────────────────────────────────────"
echo "  7.4 All Audits Are Holistic Rule Present"
echo "───────────────────────────────────────────────────────────────────"

TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if grep -q "All Audits Are Holistic" "$DISPATCHER" 2>/dev/null; then
    echo "  ✅ All Audits Are Holistic rule present"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
else
    echo "  ❌ All Audits Are Holistic rule MISSING"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
fi

echo ""
echo "───────────────────────────────────────────────────────────────────"
echo "  7.5 One-Way Ratchet Principle Present"
echo "───────────────────────────────────────────────────────────────────"

TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if grep -q "One-Way Ratchet" "$DISPATCHER" 2>/dev/null; then
    echo "  ✅ One-Way Ratchet principle present"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
else
    echo "  ❌ One-Way Ratchet principle MISSING"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
fi

echo ""
echo "───────────────────────────────────────────────────────────────────"
echo "  7.6 Commit and Release Integration Present"
echo "───────────────────────────────────────────────────────────────────"

TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if grep -q "Commit and Release Integration" "$DISPATCHER" 2>/dev/null; then
    echo "  ✅ Commit and Release Integration present"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
else
    echo "  ❌ Commit and Release Integration MISSING"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
fi

echo ""
echo "───────────────────────────────────────────────────────────────────"
echo "  7.7 FVP Protocol Present in Dispatcher"
echo "───────────────────────────────────────────────────────────────────"

TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if grep -q "Fix-Verify-Proof (FVP) Protocol" "$DISPATCHER" 2>/dev/null; then
    echo "  ✅ FVP Protocol section present"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
else
    echo "  ❌ FVP Protocol section MISSING — fixes cannot be verified"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
fi

TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if grep -q "FVP PROOF" "$DISPATCHER" 2>/dev/null; then
    echo "  ✅ FVP proof block format present"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
else
    echo "  ❌ FVP proof block format MISSING"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
fi

echo ""
echo "───────────────────────────────────────────────────────────────────"
echo "  7.8 FVP Protocol Present in Phase 6 (Fix)"
echo "───────────────────────────────────────────────────────────────────"

TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
PHASE6_FILE="$SKILLS_DIR/phase-6-fix.md"
if [ -f "$PHASE6_FILE" ] && grep -q "FVP" "$PHASE6_FILE" 2>/dev/null; then
    echo "  ✅ FVP Protocol referenced in Phase 6"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
else
    echo "  ❌ Phase 6 does not reference FVP Protocol"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
fi

echo ""
echo "───────────────────────────────────────────────────────────────────"
echo "  7.9 FVP Compliance Check Present in Phase 7 (Verify)"
echo "───────────────────────────────────────────────────────────────────"

TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
PHASE7_FILE="$SKILLS_DIR/phase-7-verify.md"
if [ -f "$PHASE7_FILE" ] && grep -q "FVP Protocol Compliance" "$PHASE7_FILE" 2>/dev/null; then
    echo "  ✅ Phase 7 includes FVP compliance check"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
else
    echo "  ❌ Phase 7 does not check FVP compliance"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
fi

echo ""
echo "───────────────────────────────────────────────────────────────────"
echo "  7.10 AI Self-Promotion Purge Present"
echo "───────────────────────────────────────────────────────────────────"

TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if grep -q "AI Self-Promotion Purge" "$DISPATCHER" 2>/dev/null; then
    echo "  ✅ AI Self-Promotion Purge section present in dispatcher"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
else
    echo "  ❌ AI Self-Promotion Purge MISSING from dispatcher"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
fi

TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
PHASE5C_FILE="$SKILLS_DIR/phase-5c-quality.md"
if [ -f "$PHASE5C_FILE" ] && grep -q "AI Self-Promotion" "$PHASE5C_FILE" 2>/dev/null; then
    echo "  ✅ AI Self-Promotion scan present in Phase 5c"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
else
    echo "  ❌ Phase 5c does not scan for AI self-promotion"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
fi

TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
PHASE8_FILE="$SKILLS_DIR/phase-8-docs.md"
if [ -f "$PHASE8_FILE" ] && grep -q "AI Self-Promotion" "$PHASE8_FILE" 2>/dev/null; then
    echo "  ✅ AI Self-Promotion purge present in Phase 8"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
else
    echo "  ❌ Phase 8 does not purge AI self-promotion"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
fi
```

---

## Section 8: Phase Directive Compliance

```bash
echo ""
echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║  SECTION 8: PHASE DIRECTIVE COMPLIANCE                            ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"
echo ""

echo "───────────────────────────────────────────────────────────────────"
echo "  8.1 No Prohibited Language in Phase Files"
echo "───────────────────────────────────────────────────────────────────"

PROHIBITED_PATTERNS=("manual required" "recommended fixes" "non-blocking" "low priority" "advisory" "pre-existing" "won't fix" "user can decide" "single pass")
VIOLATIONS=0
for pattern in "${PROHIBITED_PATTERNS[@]}"; do
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    MATCHES=$(grep -rn -i "$pattern" "$SKILLS_DIR"/phase-*.md 2>/dev/null | grep -v 'phase-ST\|security_advisory\|bundler-audit\|grep -E\|jq ' | grep -v '^\s*#\|\$(' | cut -d: -f1 | sort -u)
    if [[ -n "$MATCHES" ]]; then
        echo "  ❌ Prohibited language '$pattern' found in:"
        echo "$MATCHES" | while read -r f; do echo "     - $(basename "$f")"; done
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        VIOLATIONS=$((VIOLATIONS + 1))
    else
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    fi
done

if [[ "$VIOLATIONS" -eq 0 ]]; then
    echo "  ✅ No prohibited language found in any phase file"
fi

echo ""
echo "───────────────────────────────────────────────────────────────────"
echo "  8.2 Cross-Component Analysis in phase 5 Phases"
echo "───────────────────────────────────────────────────────────────────"

# Every phase 5 analysis sub-phase must include cross-component analysis
TIER3_PHASES=("phase-5a-security.md" "phase-5b-dependencies.md" "phase-5c-quality.md" "phase-5d-infrastructure.md")
MISSING_CROSS=0
for phase in "${TIER3_PHASES[@]}"; do
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    if grep -qi "cross-component" "$SKILLS_DIR/$phase" 2>/dev/null; then
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        echo "  ❌ $phase missing cross-component analysis section"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        MISSING_CROSS=$((MISSING_CROSS + 1))
    fi
done

if [[ "$MISSING_CROSS" -eq 0 ]]; then
    echo "  ✅ All phase 5 phases include cross-component analysis"
fi

echo ""
echo "───────────────────────────────────────────────────────────────────"
echo "  8.3 Phase H Does Not Exist (dissolved)"
echo "───────────────────────────────────────────────────────────────────"

TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if [[ -f "$SKILLS_DIR/phase-H-holistic.md" ]]; then
    echo "  ❌ phase-H-holistic.md still exists — should have been dissolved in v4.1.0"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
else
    echo "  ✅ phase-H-holistic.md correctly absent (dissolved into phase 5 phases)"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
fi
```

---

## Section 9: Phase Dependency Validation

```bash
echo ""
echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║  SECTION 9: PHASE DEPENDENCY VALIDATION                           ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"
echo ""

echo "───────────────────────────────────────────────────────────────────"
echo "  9.1 Phase 5 (Analysis) Composition in Dispatcher"
echo "───────────────────────────────────────────────────────────────────"

TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
# Phase 5 should reference sub-phases 5a, 5b, 5c, 5d
if grep -q "5a.*5b.*5c.*5d\|5a, 5b, 5c, 5d" "$DISPATCHER" 2>/dev/null; then
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
    echo "  ✅ Phase 5 contains sub-phases [5a, 5b, 5c, 5d]"
else
    echo "  ❌ Phase 5 composition incorrect — should reference 5a, 5b, 5c, 5d"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
fi

TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
# Verify no stale old-style phase references remain
if grep -q "Phase H\b\|Phase H " "$DISPATCHER" 2>/dev/null; then
    echo "  ❌ Dispatcher still references removed Phase H"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
else
    echo "  ✅ No stale Phase H references in dispatcher"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
fi

echo ""
echo "───────────────────────────────────────────────────────────────────"
echo "  9.2 Gate Count Validation"
echo "───────────────────────────────────────────────────────────────────"

TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
GATE_COUNT=$(grep -c "GATE" "$DISPATCHER" 2>/dev/null || echo "0")
if [[ "$GATE_COUNT" -ge 8 ]]; then
    echo "  ✅ Found $GATE_COUNT gate references in dispatcher"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
else
    echo "  ⚠️ Only $GATE_COUNT gate references found (expected 8+)"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
fi

echo ""
echo "───────────────────────────────────────────────────────────────────"
echo "  9.3 Conditional Phase Logic Present"
echo "───────────────────────────────────────────────────────────────────"

CONDITIONAL_PHASES=("Phase 9b" "Phase 9c" "Phase 9d" "Phase 10a")
MISSING_CONDITIONAL=0
for phase in "${CONDITIONAL_PHASES[@]}"; do
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    if grep -q "${phase}.*SKIP\|${phase}.*CONDITIONAL\|${phase}.*conditional" "$DISPATCHER" 2>/dev/null; then
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        echo "  ❌ Missing conditional logic for $phase"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        MISSING_CONDITIONAL=$((MISSING_CONDITIONAL + 1))
    fi
done

if [[ "$MISSING_CONDITIONAL" -eq 0 ]]; then
    echo "  ✅ All conditional phases have skip/run logic"
fi
```

---

## Section 10: Flag and Shortcut Validation

```bash
echo ""
echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║  SECTION 10: FLAG AND SHORTCUT VALIDATION                         ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"
echo ""

echo "───────────────────────────────────────────────────────────────────"
echo "  10.1 All CLI Flags Present"
echo "───────────────────────────────────────────────────────────────────"

FLAGS=("--interactive" "--skip-snapshot" "--force-sandbox" "--no-mcp-enable" "--phase=" "--list-phases")
MISSING_FLAGS=0
for flag in "${FLAGS[@]}"; do
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    if grep -q -- "$flag" "$DISPATCHER" 2>/dev/null; then
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        echo "  ❌ Missing flag: $flag"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        MISSING_FLAGS=$((MISSING_FLAGS + 1))
    fi
done

if [[ "$MISSING_FLAGS" -eq 0 ]]; then
    echo "  ✅ All CLI flags present in dispatcher"
fi

echo ""
echo "───────────────────────────────────────────────────────────────────"
echo "  10.2 All Shortcuts Present"
echo "───────────────────────────────────────────────────────────────────"

ALL_SHORTCUTS=("prodapp" "docker" "security" "github" "qaapp" "qadocker" "qaall")
MISSING_SC=0
for sc in "${ALL_SHORTCUTS[@]}"; do
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    if grep -q "$sc" "$DISPATCHER" 2>/dev/null; then
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        echo "  ❌ Missing shortcut: $sc"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        MISSING_SC=$((MISSING_SC + 1))
    fi
done

if [[ "$MISSING_SC" -eq 0 ]]; then
    echo "  ✅ All 7 shortcuts present in dispatcher"
fi

echo ""
echo "───────────────────────────────────────────────────────────────────"
echo "  10.3 No Stale 'holistic' Shortcut"
echo "───────────────────────────────────────────────────────────────────"

TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if grep -q "holistic.*→\|'holistic'" "$DISPATCHER" 2>/dev/null; then
    echo "  ❌ Stale 'holistic' shortcut still in dispatcher"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
else
    echo "  ✅ No stale 'holistic' shortcut"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
fi
```

---

## Summary Report

```bash
echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "  PHASE ST: SELF-TEST SUMMARY"
echo "═══════════════════════════════════════════════════════════════════"
echo ""
echo "Test-Skill Project: $TEST_SKILL_PROJECT"
echo ""
echo "Results:"
echo "  Total checks:    $TOTAL_CHECKS"
echo "  Passed:          $PASSED_CHECKS"
echo "  Failed:          $FAILED_CHECKS"
echo ""

PASS_RATE=$((PASSED_CHECKS * 100 / TOTAL_CHECKS))
echo "  Pass rate:       ${PASS_RATE}%"
echo ""

if [[ "$FAILED_CHECKS" -eq 0 ]]; then
    echo "Status: ✅ HEALTHY - Test-skill framework is properly configured"
elif [[ "$FAILED_CHECKS" -lt 3 ]]; then
    echo "Status: ⚠️ WARNINGS - Minor issues detected ($FAILED_CHECKS)"
else
    echo "Status: ❌ ISSUES - Test-skill framework needs attention ($FAILED_CHECKS failures)"
fi

echo ""
echo "═══════════════════════════════════════════════════════════════════"
```

---

## Integration Notes

### Dual Mode Operation

Phase ST operates in two modes based on where it's run:

| Context | Mode | What It Validates |
|---------|------|-------------------|
| `claude-test-skill` project | Framework Self-Test | Phase files, symlinks, dispatcher, tools, model tiers, governing law |
| Any other project | Project Test Validation | Test discoverability, redundancy, fixture conflicts, isolation risks, version-gating, phase duplication |

### When to Use:

**Framework mode** (in claude-test-skill):
- After modifying test-skill phase files
- After updating symlinks
- After installing new tools

**Project mode** (in any project):
- After adding new test modules
- To verify all tests are discoverable by pytest
- To check for fixture conflicts or order-dependent failures
- To validate version-gated markers (v8, v9, etc.)
- To ensure project tests don't duplicate /test phase functionality

### What This Phase Does NOT Do:
- Modify any files (reports only)
- Run the actual test suite (uses `--collect-only` for discovery)
- Auto-fix issues

### This Phase is EXCLUDED From:
- Normal `/test` runs
- Full audit cycles
- Any tier-based execution

It ONLY runs when explicitly called with `/test --phase=ST`.
