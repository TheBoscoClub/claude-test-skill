# Phase 13: Documentation

## Execution Mode

This phase behaves differently based on execution mode:

| Mode | Behavior |
|------|----------|
| **Autonomous** (default) | Fix ALL doc issues, always runs, no recommendations |
| **Interactive** (`--interactive`) | May output recommendations, may skip if prior phases failed |

---

## Autonomous Mode (Default)

**CRITICAL: This phase MUST fix ALL documentation issues, not just report them.**

Documentation is code. If it's wrong, fix it. If it's missing, add it. If it's obsolete, remove it.

This phase ALWAYS runs in autonomous mode, even if prior phases had failures.
Documentation must stay synchronized regardless of code state.

---

## Interactive Mode (`--interactive`)

When running with `--interactive`, this phase:
- May skip if prior phases failed (success gate behavior)
- May output "recommendations" instead of fixing
- May leave complex documentation decisions to user

---

## Core Directive

Documentation MUST remain synchronized with:
- Current codebase state
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
- Replacing dev paths with generic placeholders (`<project-root>`, `<install-dir>`)
- Using production paths where appropriate (`/opt/audiobooks/`)
- Removing references to deleted files/directories

### 3. README Completeness

Check and ADD missing sections:
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

**CRITICAL: Documentation MUST reflect recent commits.**

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
   - If `src/api/` changed → check API documentation
   - If `install.sh` changed → check installation docs
   - If `config/` changed → check configuration docs
   - If phase files changed → check dispatcher and README

3. **Verify CHANGELOG completeness**:
   - Every `feat:` commit since last release → in Added section
   - Every `fix:` commit since last release → in Fixed section
   - Every `BREAKING` commit → in Changed section with migration notes

4. **Fix documentation gaps**:
   - Add missing features to CHANGELOG
   - Update README if major features added
   - Add migration notes for breaking changes
   - Update examples if API/CLI changed

### 5. API Documentation

For each endpoint in codebase:
- Verify it's documented
- Verify documentation matches implementation
- Fix any discrepancies

### 6. Docker Documentation

Verify and fix:
- Dockerfile version labels match VERSION
- docker-compose.yml examples are current
- Environment variables documented match actual
- Port mappings are accurate
- Volume mounts are accurate

### 7. Obsolete Content Removal

Remove references to:
- Deleted files/directories
- Deprecated features
- Old API endpoints
- Removed dependencies
- Previous repository names (unless historical context)

### 8. Docstring/Comment Updates

For code that changed in this audit:
- Update function docstrings
- Update inline comments
- Update type hints documentation

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
  PHASE 13: FIX ALL DOCUMENTATION
═══════════════════════════════════════════════════════════════════

Git Commit Analysis:
  Last documented version: v3.1.0
  Commits since last release: 12
  Features (feat:): 3 → all documented in CHANGELOG ✅
  Fixes (fix:): 7 → all documented in CHANGELOG ✅
  Breaking changes: 0

Version Sync:
  VERSION file: 3.2.0
  Fixed CLAUDE.md: 3.0.5 → 3.2.0
  Fixed README.md changelog: added v3.2.0, v3.1.x entries

Path Fixes:
  Fixed 4 dev path references in MIGRATION.md
  Fixed 2 obsolete paths in upgrade.sh

Content Updates:
  Updated API documentation for 3 new endpoints
  Removed reference to deleted web.legacy/ directory
  Added missing configuration options section
  Updated README for new features from commits

Obsolete Removal:
  Removed 2 references to audiobook-toolkit (old repo name)
  Removed deprecated --legacy flag documentation

Documentation Files Modified: 8
Issues Found: 15
Issues Fixed: 15

Status: ✅ PASS - All documentation synchronized with current commits
```

---

## Mode-Specific Rules

### Autonomous Mode (Default)

This phase does NOT output "recommendations" or "suggestions".

If documentation is wrong → FIX IT
If documentation is missing → ADD IT
If documentation is obsolete → REMOVE IT

The only output is a report of what was FIXED.

### Interactive Mode (`--interactive`)

In interactive mode, this phase MAY:
- Output recommendations for complex documentation decisions
- Skip if prior phases failed
- Leave ambiguous documentation for user review

Interactive mode output may include:

```
RECOMMENDATIONS:
1. Consider adding API versioning documentation
2. README could benefit from architecture diagram
3. CONTRIBUTING.md mentions deprecated workflow

SKIPPED (requires judgment):
- src/api/README.md - unclear if internal or public API
```
