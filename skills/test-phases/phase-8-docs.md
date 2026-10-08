# Phase 8: Documentation

> **Model**: `sonnet` | **Phase**: 8 | **Modifies Files**: YES (fixes docs)
> **Task Tracking**: Call `TaskUpdate(taskId, status="in_progress")` at start, `TaskUpdate(taskId, status="completed")` when done.
> **Key Tools**: `Read`, `Edit`, `Write` for doc fixes. Use `NotebookEdit` for Jupyter notebook documentation. Use `WebSearch` to verify external URLs still resolve. In `--interactive` mode, use `AskUserQuestion` for doc style decisions.

## Execution Mode

| Mode | Behavior |
|------|----------|
| **Autonomous** (default) | Fix ALL doc issues, always runs, no recommendations |
| **Interactive** (`--interactive`) | May output recommendations, may skip if prior phases failed |

---

## Autonomous Mode (Default)

**CRITICAL: MUST fix ALL documentation issues, not just report them.**

Wrong: fix. Missing: add. Obsolete: remove.

ALWAYS runs, even if prior phases failed.

---

## Interactive Mode (`--interactive`)

- May skip if prior phases failed
- May output "recommendations" instead of fixing
- May leave complex decisions to user

---

## Core Directive

Docs MUST stay synchronized with:
- Codebase state
- VERSION file (single source of truth for version)
- Docker image versions
- install-manifest.json
- Actual file paths and directories
- Current API endpoints and behavior

## Mandatory Checks and Fixes

### 1. Version Synchronization

```bash
# Get canonical version
VERSION=$(cat VERSION 2>/dev/null || echo "unknown")

# Find and fix all version references
grep -rn "version.*[0-9]\+\.[0-9]\+\.[0-9]\+" --include="*.md" --include="*.json" | \
  while read match; do
    # If version doesn't match VERSION file, fix it
  done
```

**Fix all version mismatches in:**
- README.md changelog section
- CLAUDE.md project instructions
- package.json / pyproject.toml
- Dockerfile labels
- docker-compose.yml comments
- Any other documentation

### 2. Path References

```bash
# Find hardcoded development paths
grep -rn "/hddRaid1/ClaudeCodeProjects" --include="*.md" --include="*.sh"

# Find obsolete paths (old repo names, deleted directories)
# Compare documented paths against actual filesystem
```

**Fix by:**
- Replacing dev paths with placeholders (`<project-root>`, `<install-dir>`)
- Using production paths where appropriate (install manifest or project config)
- Removing references to deleted files/directories

### 3. README Completeness

ADD missing sections:
- Installation instructions
- Usage examples with current syntax
- Configuration options (matching actual config)
- API reference (matching actual endpoints)
- Changelog with ALL recent versions

### 4. CHANGELOG Currency

```bash
# Check if CHANGELOG matches VERSION
CHANGELOG_VERSION=$(grep -m1 "## \[" CHANGELOG.md | grep -oP '\d+\.\d+\.\d+')
if [ "$CHANGELOG_VERSION" != "$VERSION" ]; then
  # Add missing version entry to CHANGELOG
fi
```

### 4a. Git Commit Synchronization

**CRITICAL: Docs MUST reflect recent commits.**

```bash
# Get commits since last documented version
LAST_DOCUMENTED_VERSION=$(grep -m1 "## \[" CHANGELOG.md | grep -oP '\d+\.\d+\.\d+')
LAST_TAG="v$LAST_DOCUMENTED_VERSION"

# Check if tag exists
if git rev-parse "$LAST_TAG" >/dev/null 2>&1; then
    # Get all commits since the last documented version
    RECENT_COMMITS=$(git log --oneline "$LAST_TAG"..HEAD)

    # Get files changed in those commits
    CHANGED_FILES=$(git diff --name-only "$LAST_TAG"..HEAD)
else
    # No tag, check last 10 commits
    RECENT_COMMITS=$(git log --oneline -10)
    CHANGED_FILES=$(git diff --name-only HEAD~10..HEAD 2>/dev/null || git diff --name-only)
fi

# For each significant commit, verify documentation reflects the change
# Categories to check:
# - feat: commits → should be documented in CHANGELOG and README features
# - fix: commits → should be in CHANGELOG
# - BREAKING: → should have migration notes
# - API changes → should update API docs
# - Config changes → should update configuration docs
```

**Verification Steps:**

1. **Analyze recent commits**:
   ```bash
   # Extract commit types and their scope
   git log --oneline "$LAST_TAG"..HEAD | while read hash msg; do
       if [[ "$msg" =~ ^feat ]]; then
           echo "FEATURE: $msg - verify documented"
       elif [[ "$msg" =~ ^fix ]]; then
           echo "FIX: $msg - verify in CHANGELOG"
       elif [[ "$msg" =~ BREAKING ]]; then
           echo "BREAKING: $msg - verify migration notes"
       fi
   done
   ```

2. **Cross-reference changed files with docs**:
   - `src/api/` changed → API docs
   - `install.sh` changed → installation docs
   - `config/` changed → configuration docs
   - phase files changed → dispatcher and README

3. **Verify CHANGELOG completeness**:
   - Every `feat:` commit since last release → Added section
   - Every `fix:` commit since last release → Fixed section
   - Every `BREAKING` commit → Changed section with migration notes

4. **Fix gaps**:
   - Add missing features to CHANGELOG
   - Update README if major features added
   - Add migration notes for breaking changes
   - Update examples if API/CLI changed

### 5. API Documentation

For each endpoint in codebase: verify it's documented and matches implementation; fix discrepancies.

### 6. Docker Documentation

Verify and fix:
- Dockerfile version labels match VERSION
- docker-compose.yml examples current
- Environment variables match actual
- Port mappings accurate
- Volume mounts accurate

### 7. Obsolete Content Removal

Remove references to:
- Deleted files/directories
- Deprecated features
- Old API endpoints
- Removed dependencies
- Previous repository names (unless historical context)

### 7a. AI Self-Promotion Purge

**MANDATORY: Scan all docs for AI-generated self-promotion, advertising, branding, and attribution.** Remove everything found; do NOT replace with alternative attribution.

```bash
echo "=== AI Self-Promotion Purge (Documentation) ==="

# Scan all documentation files
grep -rn -i \
  -e "Co-Authored-By.*\(Claude\|Anthropic\|GPT\|OpenAI\|Copilot\|Gemini\)" \
  -e "Generated with.*\(Claude\|Anthropic\|GPT\|OpenAI\|Copilot\)" \
  -e "Built with Claude\|Powered by Anthropic\|Created by Claude" \
  -e "Made with.*\(Claude\|Anthropic\|GPT\|OpenAI\)" \
  -e "claude\.ai/claude-code\|claude\.ai" \
  -e "noreply@anthropic\.com" \
  -e "Generated with \[Claude Code\]" \
  -e "🤖 Generated" \
  -e "AI-assisted\|AI-generated" \
  --include="*.md" --include="*.txt" --include="*.rst" \
  --include="*.html" --include="*.xml" \
  . 2>/dev/null | grep -v ".venv\|node_modules\|.snapshots\|.git/" | head -30

# Check PR/issue templates
if [ -d ".github" ]; then
  grep -rn -i \
    -e "Claude Code\|Anthropic\|Generated with\|Co-Authored\|🤖" \
    .github/ 2>/dev/null | head -10
fi
```

**For each finding:**
1. Read the file for context
2. Remove the whole self-promotion line or block
3. Do NOT add replacement attribution
4. Emit an FVP proof block showing the removal

**Patterns to remove:**
- Footers like `🤖 Generated with [Claude Code](https://claude.ai/claude-code)`
- PR template blocks injecting AI branding
- README badges referencing AI tools
- CHANGELOG entries mentioning AI assistance
- Commit templates with `Co-Authored-By: Claude`

### 8. Docstring/Comment Updates

For code changed in this audit, update:
- Function docstrings
- Inline comments
- Type hints documentation

## Execution Flow

```
1. Read VERSION file as source of truth
2. Scan all documentation files
3. For each issue found:
   a. Identify the correct current value
   b. Edit the file to fix it
   c. Verify the fix is accurate
4. Run documentation validation
5. Report all fixes made
```

## Output Format

```
═══════════════════════════════════════════════════════════════════
  PHASE 8: FIX ALL DOCUMENTATION
═══════════════════════════════════════════════════════════════════

Git Commit Analysis:
  Last documented version: <from VERSION file>
  Commits since last release: 12
  Features (feat:): 3 → all documented in CHANGELOG ✅
  Fixes (fix:): 7 → all documented in CHANGELOG ✅
  Breaking changes: 0

Version Sync:
  VERSION file: 1.5.0
  Fixed CLAUDE.md: 1.4.2 → 1.5.0
  Fixed README.md changelog: added v1.5.0, v1.4.x entries

Path Fixes:
  Fixed 4 dev path references in MIGRATION.md
  Fixed 2 obsolete paths in upgrade.sh

Content Updates:
  Updated API documentation for 3 new endpoints
  Removed reference to deleted web.legacy/ directory
  Added missing configuration options section
  Updated README for new features from commits

Obsolete Removal:
  Removed 2 references to old-project-name (old repo name)
  Removed deprecated --legacy flag documentation

AI Self-Promotion Purge:
  Files scanned: N
  AI branding instances found: N
  Instances removed: N
  Git commits with AI attribution: N (flagged, not rewritable)

Documentation Files Modified: 8
Issues Found: 15
Issues Fixed: 15

Status: ✅ PASS - All documentation synchronized with current commits
```

---

## Mode-Specific Rules

### Autonomous Mode (Default)

NO "recommendations" or "suggestions". Wrong → FIX. Missing → ADD. Obsolete → REMOVE. Output only a report of what was FIXED.

### Interactive Mode (`--interactive`)

MAY output recommendations for complex decisions, skip if prior phases failed, and leave ambiguous docs for user review. Format:

```
RECOMMENDATIONS:
1. Consider adding API versioning documentation
2. README could benefit from architecture diagram
3. CONTRIBUTING.md mentions deprecated workflow

SKIPPED (requires judgment):
- src/api/README.md - unclear if internal or public API
```
