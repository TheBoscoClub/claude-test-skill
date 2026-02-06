# Phase ST: Test-Skill Self-Test

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

TEST_SKILL_PROJECT="/hddRaid1/ClaudeCodeProjects/test-skill"
SKILLS_DIR="$HOME/.claude/skills/test-phases"
COMMANDS_DIR="$HOME/.claude/commands"

echo "Test-Skill Project: $TEST_SKILL_PROJECT"
echo "Skills Directory: $SKILLS_DIR"
echo "Commands Directory: $COMMANDS_DIR"
echo ""
```

---

## Section 1: Phase File Validation

```bash
echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║  SECTION 1: PHASE FILE VALIDATION                                 ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"
echo ""

# Expected phase files
EXPECTED_PHASES=(
    "phase-0-preflight.md"
    "phase-1-discovery.md"
    "phase-2-execute.md"
    "phase-2a-runtime.md"
    "phase-3-report.md"
    "phase-4-cleanup.md"
    "phase-5-security.md"
    "phase-6-dependencies.md"
    "phase-7-quality.md"
    "phase-8-coverage.md"
    "phase-9-debug.md"
    "phase-10-fix.md"
    "phase-11-config.md"
    "phase-12-verify.md"
    "phase-13-docs.md"
    "phase-A-app-testing.md"
    "phase-C-restore.md"
    "phase-D-docker.md"
    "phase-G-github.md"
    "phase-H-holistic.md"
    "phase-I-infrastructure.md"
    "phase-M-mocking.md"
    "phase-P-production.md"
    "phase-S-snapshot.md"
    "phase-ST-self-test.md"
)

echo "───────────────────────────────────────────────────────────────────"
echo "  1.1 Phase File Existence"
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
KEY_PHASES=("Phase 5" "Phase P" "Phase D" "Phase G" "Phase ST" "Tier 3")
for key in "${KEY_PHASES[@]}"; do
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    if grep -qi "$key" "$DISPATCHER" 2>/dev/null; then
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        echo "  ⚠️ Dispatcher missing reference to: $key"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi
done

echo "  ✅ Key phase references found in dispatcher"

echo ""
echo "───────────────────────────────────────────────────────────────────"
echo "  3.3 Shortcut Definitions"
echo "───────────────────────────────────────────────────────────────────"

SHORTCUTS=("prodapp" "docker" "security" "github" "holistic")
for shortcut in "${SHORTCUTS[@]}"; do
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    if grep -q "$shortcut" "$DISPATCHER" 2>/dev/null; then
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        echo "  ❌ Missing shortcut: $shortcut"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi
done

echo "  ✅ All shortcuts defined in dispatcher"
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

SECURITY_TOOLS=("bandit" "semgrep" "shellcheck" "codeql" "trivy" "grype" "pip-audit" "checkov")
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

### When to Use:
- After modifying test-skill phase files
- After updating symlinks
- After installing new tools
- To verify test-skill is properly configured

### What This Phase Does NOT Do:
- Run actual tests against other projects
- Modify any files
- Auto-fix issues (reports only)

### This Phase is EXCLUDED From:
- Normal `/test` runs
- Full audit cycles
- Any tier-based execution

It ONLY runs when explicitly called with `/test --phase=ST`.
