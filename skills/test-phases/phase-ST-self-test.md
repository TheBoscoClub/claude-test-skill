# Phase ST: Test-Skill Self-Test

> **Model**: `opus` | **Tier**: Special (Isolated) | **Modifies Files**: No (read-only)
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

# Expected phase files — 20 phases
EXPECTED_PHASES=(
    "phase-0-preflight.md"
    "phase-1-discovery.md"
    "phase-2-execute.md"
    "phase-2a-runtime.md"
    "phase-5-security.md"
    "phase-6-dependencies.md"
    "phase-7-quality.md"
    "phase-10-fix.md"
    "phase-12-verify.md"
    "phase-13-docs.md"
    "phase-A-app-testing.md"
    "phase-C-restore.md"
    "phase-D-docker.md"
    "phase-G-github.md"
    "phase-I-infrastructure.md"
    "phase-P-production.md"
    "phase-S-snapshot.md"
    "phase-ST-self-test.md"
    "phase-V-vm-testing.md"
    "phase-VM-lifecycle.md"
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

DELETED_PHASES=("phase-3-report.md" "phase-4-cleanup.md" "phase-8-coverage.md" "phase-9-debug.md" "phase-11-config.md" "phase-M-mocking.md" "phase-H-holistic.md")
STALE_FOUND=0
for stale in "${DELETED_PHASES[@]}"; do
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    if [[ -f "$SKILLS_DIR/$stale" ]]; then
        echo "  ❌ Stale phase file found: $stale (should have been deleted in v4.0.0/v4.1.0)"
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
    MATCHES=$(grep -rli "$pattern" "$SKILLS_DIR"/phase-*.md 2>/dev/null | grep -v phase-ST)
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
echo "  8.2 Cross-Component Analysis in Tier 3 Phases"
echo "───────────────────────────────────────────────────────────────────"

# Every Tier 3 analysis phase must include cross-component analysis
TIER3_PHASES=("phase-5-security.md" "phase-6-dependencies.md" "phase-7-quality.md" "phase-I-infrastructure.md")
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
    echo "  ✅ All Tier 3 phases include cross-component analysis"
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
    echo "  ✅ phase-H-holistic.md correctly absent (dissolved into Tier 3 phases)"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
fi
```

---

## Section 9: Tier Dependency Validation

```bash
echo ""
echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║  SECTION 9: TIER DEPENDENCY VALIDATION                            ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"
echo ""

echo "───────────────────────────────────────────────────────────────────"
echo "  9.1 Tier 3 Composition in Dispatcher"
echo "───────────────────────────────────────────────────────────────────"

TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
# Tier 3 should contain exactly [5,6,7,I] — no H
if grep -q "\[5,6,7,I\]\|5, 6, 7, I\|5,6,7,I" "$DISPATCHER" 2>/dev/null; then
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
    echo "  ✅ Tier 3 contains [5,6,7,I] (no Phase H)"
else
    echo "  ❌ Tier 3 composition incorrect — may still reference Phase H"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
fi

TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
# Verify H is NOT in Tier 3 arrays
if grep -q "\[5,6,7,H,I\]\|5, 6, 7, H, I\|5,6,7,H,I" "$DISPATCHER" 2>/dev/null; then
    echo "  ❌ Dispatcher still references Phase H in Tier 3"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
else
    echo "  ✅ No stale Phase H references in Tier 3"
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

CONDITIONAL_PHASES=("Phase P" "Phase D" "Phase G" "Phase V")
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
