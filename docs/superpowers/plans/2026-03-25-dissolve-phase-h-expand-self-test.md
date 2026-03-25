# Dissolve Phase H & Expand Self-Test Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminate Phase H as a separate phase by merging its cross-component analysis into every Tier 3 analysis phase (5, 6, 7, I), then expand Phase ST to validate Governing Law compliance and structural correctness across the framework.

**Architecture:** Phase H's 460 lines of cross-component analysis get distributed by domain: security-related checks (data flow tracing, unvalidated inputs) go to Phase 5; dependency-related checks (import mapping, circular imports, unused exports) go to Phase 6; quality-related checks (dead code, hardcoded paths, version mismatches, config sprawl) go to Phase 7; infrastructure-related checks (API contract verification, script interface audit, shared file interface audit) go to Phase I. The phase count drops from 21 to 20. Phase ST gains new sections validating Governing Law presence, directive compliance in phase files, tier dependency correctness, and conditional execution coverage.

**Tech Stack:** Markdown (phase files), Bash (self-test scripts), grep/glob (validation)

---

## File Structure

### Files to Delete
- `skills/test-phases/phase-H-holistic.md` — dissolved; content distributed to 5, 6, 7, I

### Files to Modify
- `skills/test-phases/phase-5-security.md` — add Phase H Step 3 (data flow tracing) and Step 3d (unvalidated flows)
- `skills/test-phases/phase-6-dependencies.md` — add Phase H Step 1 (import/dependency mapping, circular imports, unused exports)
- `skills/test-phases/phase-7-quality.md` — add Phase H Step 2 (config sprawl), Step 4a (hardcoded paths), Step 4b (version mismatches), Step 4c (dead code cross-component)
- `skills/test-phases/phase-I-infrastructure.md` — add Phase H Step 5 (integration surface audit: API contracts, script interfaces, shared file interfaces)
- `skills/test-phases/phase-ST-self-test.md` — expand with Sections 7-10 (Governing Law, directives, tier dependencies, conditional execution)
- `commands/test.md` — remove all Phase H references; update phase count 21→20; update Tier 3 arrays; update model tiering table; update dependency graph; update help block; update execution algorithm
- `README.md` — remove Phase H row from tables; update phase count; update dependency diagrams; update architecture tree
- `SKILL.md` — remove Phase H; update phase count 21→20
- `INSTALL.md` — remove phase-H-holistic.md from file listing; update count 21→20
- `CHANGELOG.md` — add [Unreleased] entry documenting the dissolution
- `docs/ARCHITECTURE.md` — remove Phase H from all diagrams, tables, model tiering; update phase count
- `CLAUDE.md` — no changes needed (already concise/modular)
- `.claude/rules/design.md` — no changes needed
- `VERSION` — bump to 4.1.0 (minor: Phase H dissolved, no breaking change to user commands)

---

## Task 1: Merge Phase H Step 1 (Import/Dependency Mapping) into Phase 6

**Files:**
- Modify: `skills/test-phases/phase-6-dependencies.md` (append after existing content)
- Reference: `skills/test-phases/phase-H-holistic.md:12-88` (Step 1 content)

- [ ] **Step 1: Read Phase 6 and Phase H Step 1 fully**

Read the complete `phase-6-dependencies.md` and lines 12-88 of `phase-H-holistic.md`.

- [ ] **Step 2: Append cross-component dependency analysis to Phase 6**

After Phase 6's existing final section, add a new section titled `## Cross-Component Dependency Analysis` containing:

```markdown
## Cross-Component Dependency Analysis

Every phase must analyze dependencies holistically — not just within individual files but across the entire project. This section is mandatory for all /test audits.

### Import & Dependency Mapping

Build a concrete dependency graph showing which modules depend on which.
```

Then include Phase H's Step 1a (Collect All Imports), Step 1b (Detect Circular Imports), and Step 1c (Find Unused Exports) bash blocks verbatim from `phase-H-holistic.md:18-86`.

Update the temp file names from `/tmp/phase-h-*` to `/tmp/phase-6-crosscomp-*`.

- [ ] **Step 3: Update Phase 6 header**

Update the description line in the configuration header blockquote to mention cross-component dependency analysis:

```markdown
> **Key Tools**: `Bash` for audit commands. Use `WebSearch` to look up CVE details for flagged vulnerabilities. Parallelize with other Tier 3 phases. Includes cross-component import mapping, circular import detection, and unused export analysis.
```

- [ ] **Step 4: Update Phase 6 checklist (if present)**

Add to any existing checklist:
```
[ ] Import/dependency map built for all source files
[ ] Circular imports checked and flagged
[ ] Unused exports identified
```

- [ ] **Step 5: Verify Phase 6 is syntactically correct**

Run: `grep -c '```bash' skills/test-phases/phase-6-dependencies.md`
Expected: count increases by 3 (from the 3 new bash blocks).

- [ ] **Step 6: Commit**

```bash
git add skills/test-phases/phase-6-dependencies.md
git commit -m "feat: merge Phase H import/dependency mapping into Phase 6"
```

---

## Task 2: Merge Phase H Step 3 (Data Flow Tracing) into Phase 5

**Files:**
- Modify: `skills/test-phases/phase-5-security.md` (append before Output Format)
- Reference: `skills/test-phases/phase-H-holistic.md:156-234` (Step 3 content)

- [ ] **Step 1: Read Phase 5 fully**

Read the complete `phase-5-security.md`.

- [ ] **Step 2: Append cross-component data flow analysis to Phase 5**

Before Phase 5's Output Format section, add a new section titled `## Cross-Component Data Flow Analysis` containing:

```markdown
## Cross-Component Data Flow Analysis

Every phase must analyze security holistically — not just within individual files but across the entire project's data flows. This section is mandatory for all /test audits.
```

Then include Phase H's Step 3a (Map Entry Points), Step 3b (Map Storage Points), Step 3c (Map Exit Points), and Step 3d (Flag Unvalidated Flows) bash blocks verbatim from `phase-H-holistic.md:160-234`.

Update temp file names from `/tmp/phase-h-*` to `/tmp/phase-5-dataflow-*`.

- [ ] **Step 3: Update Phase 5 header**

Add to the Key Tools line: `Includes cross-component data flow tracing and unvalidated input detection.`

- [ ] **Step 4: Update Phase 5 checklist (if present)**

Add:
```
[ ] Data entry points mapped (API, CLI, file reads)
[ ] Data storage points mapped (DB, file writes)
[ ] Data exit points mapped (API responses, logs, file writes)
[ ] Unvalidated data flows flagged
```

- [ ] **Step 5: Commit**

```bash
git add skills/test-phases/phase-5-security.md
git commit -m "feat: merge Phase H data flow tracing into Phase 5"
```

---

## Task 3: Merge Phase H Steps 2, 4a, 4b, 4c (Config/Quality) into Phase 7

**Files:**
- Modify: `skills/test-phases/phase-7-quality.md` (append after existing content)
- Reference: `skills/test-phases/phase-H-holistic.md:92-299` (Steps 2 and 4)

- [ ] **Step 1: Read Phase 7 fully**

Read the complete `phase-7-quality.md`.

- [ ] **Step 2: Append cross-component quality analysis to Phase 7**

After Phase 7's existing final section, add:

```markdown
## Cross-Component Quality Analysis

Every phase must analyze quality holistically — not just within individual files but across the entire project. This section is mandatory for all /test audits.

### Shared Config Detection

Find configuration files and detect sprawl (same setting defined in multiple places).
```

Then include Phase H's Step 2a (Locate All Config Sources), Step 2b (Detect Config Sprawl), Step 2c (Cross-Language Config Consistency) from `phase-H-holistic.md:98-150`.

Then add:

```markdown
### Cross-Component Issues
```

And include Step 4a (Hardcoded Paths), Step 4b (Version Mismatches), Step 4c (Dead Code and Unused Exports — the cross-component variant) from `phase-H-holistic.md:240-299`.

Update temp file names from `/tmp/phase-h-*` to `/tmp/phase-7-crosscomp-*`.

- [ ] **Step 3: Update Phase 7 header**

Add to the Key Tools line: `Includes cross-component config sprawl detection, version mismatch identification, and hardcoded path analysis.`

- [ ] **Step 4: Update Phase 7 checklist (if present)**

Add:
```
[ ] Config files enumerated and cross-referenced
[ ] Config sprawl (duplicate settings) detected
[ ] Cross-language config consistency verified (ports, paths, DB)
[ ] Hardcoded paths detected
[ ] Version string consistency verified
[ ] Cross-component dead code identified
```

- [ ] **Step 5: Commit**

```bash
git add skills/test-phases/phase-7-quality.md
git commit -m "feat: merge Phase H config sprawl and quality checks into Phase 7"
```

---

## Task 4: Merge Phase H Step 5 (Integration Surface Audit) into Phase I

**Files:**
- Modify: `skills/test-phases/phase-I-infrastructure.md` (append after existing content)
- Reference: `skills/test-phases/phase-H-holistic.md:302-369` (Step 5)

- [ ] **Step 1: Read Phase I fully**

Read the complete `phase-I-infrastructure.md`.

- [ ] **Step 2: Append integration surface audit to Phase I**

After Phase I's existing final section, add:

```markdown
## Cross-Component Integration Surface Audit

Every phase must analyze infrastructure holistically — not just within individual files but across the entire project's integration boundaries. This section is mandatory for all /test audits.

### API Contract Verification
```

Then include Phase H's Step 5a (API Contract Verification), Step 5b (Shell Script Interface Audit), Step 5c (Shared File Interface Audit) from `phase-H-holistic.md:308-369`.

Update temp file names from `/tmp/phase-h-*` to `/tmp/phase-I-integration-*`.

- [ ] **Step 3: Update Phase I header**

Add to the Key Tools line: `Includes cross-component integration surface audit: API contracts, script interfaces, shared file interfaces.`

- [ ] **Step 4: Update Phase I checklist (if present)**

Add:
```
[ ] API contracts verified (backend routes vs frontend calls)
[ ] Script dependencies verified (called scripts exist)
[ ] Shared file interfaces audited
```

- [ ] **Step 5: Commit**

```bash
git add skills/test-phases/phase-I-infrastructure.md
git commit -m "feat: merge Phase H integration surface audit into Phase I"
```

---

## Task 5: Delete Phase H File

**Files:**
- Delete: `skills/test-phases/phase-H-holistic.md`

- [ ] **Step 1: Verify all Phase H content has been distributed**

Run these checks to confirm nothing was missed:

```bash
# Phase H had 5 major steps. Verify each is now in a target phase:
# Step 1 (imports) → Phase 6
grep -c "Cross-Component Dependency Analysis" skills/test-phases/phase-6-dependencies.md
# Expected: 1

# Step 2 (config) + Step 4 (quality) → Phase 7
grep -c "Cross-Component Quality Analysis" skills/test-phases/phase-7-quality.md
# Expected: 1

# Step 3 (data flow) → Phase 5
grep -c "Cross-Component Data Flow Analysis" skills/test-phases/phase-5-security.md
# Expected: 1

# Step 5 (integration) → Phase I
grep -c "Cross-Component Integration Surface Audit" skills/test-phases/phase-I-infrastructure.md
# Expected: 1
```

- [ ] **Step 2: Delete Phase H**

```bash
git rm skills/test-phases/phase-H-holistic.md
```

- [ ] **Step 3: Verify file is gone**

```bash
ls skills/test-phases/phase-H-holistic.md 2>&1
# Expected: No such file or directory
```

- [ ] **Step 4: Commit**

```bash
git commit -m "refactor: delete Phase H — content fully distributed to phases 5, 6, 7, I"
```

---

## Task 6: Update Dispatcher (commands/test.md)

**Files:**
- Modify: `commands/test.md`

This is the largest and most critical task. Every reference to Phase H must be removed or updated.

- [ ] **Step 1: Read dispatcher fully**

Read `commands/test.md` completely (all 1333 lines).

- [ ] **Step 2: Update "All Audits Are Holistic" section (lines ~51-53)**

Replace:
```markdown
### All Audits Are Holistic

Every /test audit includes full-stack cross-component analysis (Phase H). There is no separate "holistic" mode — holistic analysis is mandatory and automatic in every audit. Phase H runs as part of Tier 3 in all audit types.
```

With:
```markdown
### All Audits Are Holistic

Every /test analysis phase (5, 6, 7, I) includes mandatory cross-component analysis. There is no separate "holistic" mode or phase — holistic analysis is a structural property of every analysis phase, not an optional add-on. Cross-component checks cannot be excluded from any audit.

**One-way ratchet:** Project-specific test modules, rules, configurations, and definitions may strengthen cross-component requirements for their respective project (e.g., require additional contract checks, stricter config consistency), but nothing at the project level may weaken, dilute, supersede, skip, or be interpreted in a way whose outcome would weaken the global law. The Governing Law is always the sole and final authority.
```

- [ ] **Step 2b: Add one-way ratchet principle to Governing Law preamble (lines ~30-41)**

After the line `**No exception exists. No mode, flag, or option can override this law.**`, add:

```markdown
### One-Way Ratchet

Project-specific test modules, rules, configurations, and definitions may strengthen the Governing Law's requirements for their respective project (e.g., stricter coverage thresholds, additional security checks, tighter config consistency). However, nothing at the project level may weaken, dilute, supersede, skip, or be interpreted in a way whose outcome would weaken any provision of this law. If a project-level rule creates ambiguity or appears to conflict with the Governing Law, the Governing Law prevails unconditionally — the project-level rule must be amended or removed.
```

- [ ] **Step 3: Remove Phase H from Available Phases table (line ~139)**

Delete the row:
```
| **H** | **Cross-Component** | **Full-stack cross-component analysis (always included)** |
```

- [ ] **Step 4: Update Quick Dependency Reference table**

Remove the Phase H row:
```
| **H** | **3** | **1** | **No (read-only analysis)** | **7, 5, I (after Discovery)** |
```

Update Phase I's "Can Parallel With" column from `H, 7, 5 (after Discovery)` to `7, 5 (after Discovery)`.

Update the `5,6,7,H,I` row to `5,6,7,I`.

- [ ] **Step 5: Update the dependency graph ASCII art**

In the TIER 3 section, change:
```
│  │ [5, 6, 7, H, I]  ← Note: 13 moved to Tier 6                        │   │
```
To:
```
│  │ [5, 6, 7, I]  ← Note: 13 moved to Tier 6                           │   │
```

- [ ] **Step 6: Update Parallel Execution Rules table**

Change:
```
| 3 | 5,6,7,H,I | ✅ Yes | All analysis complete |
```
To:
```
| 3 | 5,6,7,I | ✅ Yes | All analysis complete |
```

- [ ] **Step 7: Update execution algorithm**

Change all `[5,6,7,H,I]` references to `[5,6,7,I]` in the `executeAudit()` pseudocode.

- [ ] **Step 8: Update "Why This Matters" examples**

Change `✅ 5, 6, 7, H, I run parallel (read-only) → safe` to `✅ 5, 6, 7, I run parallel (read-only) → safe`.

- [ ] **Step 9: Update Subagent Model Selection table**

Change:
```
| **opus** | 1, 5, 7, 10, A, P, D, G, H, ST | Complex analysis, multi-step fixes, security audit, cross-component reasoning |
```
To:
```
| **opus** | 1, 5, 7, 10, A, P, D, G, ST | Complex analysis, multi-step fixes, security audit, cross-component reasoning |
```

Update the opus count from 10 to 9. Update total phase count references from 21 to 20.

- [ ] **Step 10: Update canonical help block**

Remove the Phase H line from the `ALL PHASES` section:
```
│    H   Cross-Component   Full-stack cross-component analysis (always runs) │
```

Update the notes section. Change:
```
│  • All audits are holistic — Phase H always runs (no separate shortcut)    │
```
To:
```
│  • All audits are holistic — every analysis phase includes cross-component │
```

Update the header from "21 phases" to "20 phases".

- [ ] **Step 11: Update tier execution instructions**

Change:
```
   TIER 3: Analysis [5,6,7,H,I] - Run in PARALLEL
```
To:
```
   TIER 3: Analysis [5,6,7,I] - Run in PARALLEL
```

Update model selection references:
```
     - `opus`: Phases 1, 5, 7, 10, A, P, D, G, H, ST
```
To:
```
     - `opus`: Phases 1, 5, 7, 10, A, P, D, G, ST
```

- [ ] **Step 12: Update document version footer**

Change:
```
*Document Version: 4.0.0 — Phase consolidation (27→21), project-agnostic refactor, bloat reduction*
```
To:
```
*Document Version: 4.1.0 — Phase H dissolved into analysis phases, self-test expanded*
```

- [ ] **Step 13: Update description in frontmatter**

Change:
```
description: Modular project audit - testing, security, debugging, fixing (phase-based loading for context efficiency) (user)
```
To:
```
description: Modular project audit - testing, security, debugging, fixing (phase-based loading for context efficiency, holistic by design) (user)
```

- [ ] **Step 14: Verify no Phase H references remain**

```bash
grep -n "Phase H\|phase-H\|Phase.H\|\bH\b.*Cross" commands/test.md
# Expected: zero matches (or only changelog/version-history references)
```

- [ ] **Step 15: Commit**

```bash
git add commands/test.md
git commit -m "refactor: remove all Phase H references from dispatcher — 21→20 phases"
```

---

## Task 7: Update Phase ST Self-Test

**Files:**
- Modify: `skills/test-phases/phase-ST-self-test.md`

Two changes: (a) update Phase H references to reflect its deletion, (b) add new validation sections.

- [ ] **Step 1: Read Phase ST fully**

Read the complete `phase-ST-self-test.md`.

- [ ] **Step 2: Update EXPECTED_PHASES array (remove phase-H-holistic.md)**

In Section 1.1, remove `"phase-H-holistic.md"` from the `EXPECTED_PHASES` array. Update the comment from `21 phases` to `20 phases`. Update the echo from `21 expected` to `20 expected`.

- [ ] **Step 3: Add phase-H-holistic.md to DELETED_PHASES array**

In Section 1.4, add `"phase-H-holistic.md"` to the `DELETED_PHASES` array (alongside the other deleted phases). Update the description to mention v4.1.0.

- [ ] **Step 4: Update EXPECTED_MODELS map (remove phase-H-holistic.md)**

In Section 6.2, remove the line:
```bash
    ["phase-H-holistic.md"]="opus"
```

Update the comment from `21 phases` to `20 phases`.

- [ ] **Step 5: Update Section 6.2 header**

Change `6.2 Model Tiering Validation (21 phases)` to `6.2 Model Tiering Validation (20 phases)`.

- [ ] **Step 6: Add Section 7 — Governing Law Validation**

After the existing Section 6, add:

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

- [ ] **Step 7: Add Section 8 — Phase Directive Compliance**

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

- [ ] **Step 8: Add Section 9 — Tier Dependency Validation**

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

- [ ] **Step 9: Add Section 10 — Flag and Shortcut Validation**

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

- [ ] **Step 10: Commit**

```bash
git add skills/test-phases/phase-ST-self-test.md
git commit -m "feat: expand Phase ST with Governing Law, directive compliance, tier, and flag validation"
```

---

## Task 8: Update Documentation Files

**Files:**
- Modify: `README.md`, `SKILL.md`, `INSTALL.md`, `docs/ARCHITECTURE.md`, `CHANGELOG.md`, `VERSION`

- [ ] **Step 1: Update VERSION**

Change `4.0.0` to `4.1.0`.

- [ ] **Step 2: Update README.md**

1. Change "21-phase" to "20-phase" in the header line
2. Remove Phase H row from the Phase Overview table (line ~81)
3. Update Tier 3 in the dependency diagram: `[5, 6, 7, H, I]` → `[5, 6, 7, I]`
4. Change line 65 "All Audits Are Holistic" description from Phase H reference to structural property
5. Update architecture tree: remove `phase-H-holistic.md` line (line ~324)
6. Update "21 phase files" references to "20 phase files"

- [ ] **Step 3: Update SKILL.md**

1. Change "21-phase" to "20-phase" in description and frontmatter
2. Remove Phase H row from Available Phases table (line ~50)
3. Update line 65: "All Audits Are Holistic" — change "Phase H (cross-component analysis) runs in every audit" to "Every analysis phase includes cross-component analysis"
4. Update "21 Phases" to "20 Phases" in Key Features
5. Update version from 4.0.0 to 4.1.0

- [ ] **Step 4: Update INSTALL.md**

1. Remove `phase-H-holistic.md` from the file listing (line ~212)
2. Change "21 files" to "20 files" in verification section (line ~113)
3. Update "All 21 phase files" to "All 20 phase files" in Phase ST checks description (line ~122)

- [ ] **Step 5: Update docs/ARCHITECTURE.md**

1. Remove Phase H from the architecture diagram (line ~28): `[Phase H]` and its model label
2. Remove `phase-H-holistic.md` from directory structure (line ~69)
3. Update OPUS count from "10 phases" to "9 phases" in model tiering (line ~198)
4. Remove Phase H line from OPUS tier list (line ~207)
5. Update Tier 3 in execution flow diagram: `[5][6][7][H][I]` → `[5][6][7][I]` (line ~250)
6. Update Tier 3 row in parallel execution table: `5,6,7,H,I` → `5,6,7,I` (line ~281)
7. Update "21 phase files" to "20 phase files" in description (line ~5) and directory comment (line ~52)
8. Update "Adding a New Phase" section step count if needed
9. Update version reference from 4.0.0 to 4.1.0
10. Update phase count in all remaining references

- [ ] **Step 6: Update CHANGELOG.md**

Add to the `[Unreleased]` section:

```markdown
## [Unreleased]

### Changed
- **Phase H dissolved** — Cross-component analysis distributed to every Tier 3 phase:
  - Phase H Step 1 (import/dependency mapping) → Phase 6 (Dependencies)
  - Phase H Step 2 (config sprawl) + Step 4 (quality issues) → Phase 7 (Quality)
  - Phase H Step 3 (data flow tracing) → Phase 5 (Security)
  - Phase H Step 5 (integration surface audit) → Phase I (Infrastructure)
- Phase count reduced from 21 to 20
- All audits now holistic by design — cross-component analysis is a structural property of every analysis phase, not a separate optional phase
- Opus phase count reduced from 10 to 9

### Added
- **Phase ST Section 7**: Governing Law validation (presence of all 5 governing rules)
- **Phase ST Section 8**: Phase directive compliance (prohibited language scan, cross-component verification, Phase H absence check)
- **Phase ST Section 9**: Tier dependency validation (Tier 3 composition, gate count, conditional logic)
- **Phase ST Section 10**: Flag and shortcut validation (all CLI flags, all 7 shortcuts, no stale holistic shortcut)

### Removed
- `phase-H-holistic.md` — dissolved into Phases 5, 6, 7, I (no functionality lost)
- `holistic` as a concept separate from normal analysis — all analysis is now inherently holistic
```

- [ ] **Step 7: Verify no stale Phase H references remain anywhere**

```bash
grep -rn "phase-H-holistic\|Phase H\b" --include="*.md" . | grep -v CHANGELOG.md | grep -v ".snapshots"
# Expected: zero matches (CHANGELOG is allowed to reference historical changes)
```

- [ ] **Step 8: Commit**

```bash
git add VERSION README.md SKILL.md INSTALL.md docs/ARCHITECTURE.md CHANGELOG.md
git commit -m "docs: update all documentation for Phase H dissolution — 21→20 phases"
```

---

## Task 9: Update Project Rules

**Files:**
- Modify: `.claude/rules/design.md` — if it references Phase H

- [ ] **Step 1: Check for Phase H references in rules**

```bash
grep -rn "Phase H\|holistic\|cross-component" .claude/rules/ 2>/dev/null
```

- [ ] **Step 2: Update any references found**

If `design.md` or `vm-testing.md` mentions Phase H, update to reflect dissolution.

- [ ] **Step 3: Commit (if changes)**

```bash
git add .claude/rules/
git commit -m "docs: update project rules for Phase H dissolution"
```

---

## Task 10: Run Phase ST to Verify Everything

**Files:**
- None (read-only verification)

- [ ] **Step 1: Run the updated self-test**

Execute the full Phase ST self-test script from `phase-ST-self-test.md` (all 10 sections).

- [ ] **Step 2: Verify 100% pass rate**

All checks must pass. If any fail, fix the issue and re-run.

Expected new checks:
- Section 7: 6 Governing Law checks (all pass, including One-Way Ratchet)
- Section 8: 9+ prohibited language checks (all pass), 4 cross-component checks (all pass), 1 Phase H absence check (pass)
- Section 9: 2 Tier 3 composition checks (pass), 1 gate count check (pass), 4 conditional logic checks (pass)
- Section 10: 6 flag checks (pass), 7 shortcut checks (pass), 1 stale holistic check (pass)

- [ ] **Step 3: Commit (if any final fixes needed)**

```bash
git add -A
git commit -m "fix: address Phase ST validation findings"
```

---

## Self-Review Checklist

- [x] **Spec coverage**: All three requirements covered — Phase H dissolution (Tasks 1-6), Governing Law compliance in ST (Task 7 Steps 6-7), remaining coverage gaps in ST (Task 7 Steps 8-9)
- [x] **Placeholder scan**: No TBD/TODO items. All steps have concrete content.
- [x] **Type consistency**: File paths, section names, and array contents consistent across tasks.
- [x] **Phase H content fully mapped**: Step 1→Phase 6, Step 2+4→Phase 7, Step 3→Phase 5, Step 5→Phase I. No content lost.
- [x] **All references tracked**: dispatcher, README, SKILL.md, INSTALL.md, ARCHITECTURE.md, CHANGELOG.md, VERSION, Phase ST, project rules.
