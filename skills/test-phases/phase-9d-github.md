# Phase 9d: GitHub Audit

> **Model**: `opus` | **Phase**: 9d | **Modifies Files**: No (audits GitHub)
> **Task Tracking**: Call `TaskUpdate(taskId, status="in_progress")` at start, `TaskUpdate(taskId, status="completed")` when done.
> **Key Tools**: `Bash` for `gh` CLI commands. Use `WebSearch` to look up GitHub API changes or new security features. Use `AskUserQuestion` in `--interactive` mode for security remediation decisions (e.g., enabling features that may affect CI).

Comprehensive audit of the project's GitHub repository, including security features, alerts, workflows, and compliance.

**Prerequisite**: Phase 3 (Discovery) must have detected a GitHub repository with authenticated access.

## Execution Mode

| Mode | Behavior |
|------|----------|
| **Autonomous** (default) | Enable missing security features, fix alerts where possible |
| **Interactive** (`--interactive`) | Report issues, prompt before making changes |

---

## Step 1: Verify GitHub Access

```bash
echo "═══════════════════════════════════════════════════════════════════"
echo "  PHASE G: GITHUB REPOSITORY AUDIT"
echo "═══════════════════════════════════════════════════════════════════"

# Use GITHUB_REPO from Phase 1 Discovery, or detect it
if [[ -z "$GITHUB_REPO" ]]; then
    REMOTE_URL=$(git remote get-url origin 2>/dev/null)
    if [[ "$REMOTE_URL" =~ github\.com[:/]([^/]+)/([^/.]+) ]]; then
        GITHUB_REPO="${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
    fi
fi

if [[ -z "$GITHUB_REPO" ]]; then
    echo "❌ No GitHub repository detected"
    echo "Status: ⚠️ SKIPPED - No GitHub repo"
    exit 0
fi

echo "Repository: $GITHUB_REPO"
echo "URL: https://github.com/$GITHUB_REPO"
echo ""

# Verify gh CLI access
if ! command -v gh &>/dev/null; then
    echo "❌ GitHub CLI (gh) not installed"
    echo "Install with: sudo pacman -S github-cli"
    echo "Status: ⚠️ SKIPPED - gh not installed"
    exit 0
fi

if ! gh auth status &>/dev/null 2>&1; then
    echo "❌ GitHub CLI not authenticated"
    echo "Run: gh auth login"
    echo "Status: ⚠️ SKIPPED - Not authenticated"
    exit 0
fi

echo "✅ GitHub CLI authenticated"
echo ""
```

## Step 2: Security Features Audit

```bash
echo "───────────────────────────────────────────────────────────────────"
echo "  Step 2: Security Features Audit"
echo "───────────────────────────────────────────────────────────────────"

ISSUES_FOUND=0

# ---------------------------------------------------------------------------
# gh_json / json_count / audit_unknown  (claude-test-skill-dqi)
#
# This phase used to read:
#     ALERTS=$(gh api ... 2>/dev/null)
#     COUNT=$(echo "$ALERTS" | jq 'length' 2>/dev/null || echo "0")
# The gh failure is swallowed at capture. It then goes wrong two DIFFERENT
# ways, both measured 2026-08-24:
#
#   empty stdout (network failure, gh crash, timeout, killed process)
#     jq emits nothing, COUNT becomes "", and [[ "" -eq 0 ]] is TRUE.
#     Result: "No open alerts" — a FALSE CLEAN.
#
#   HTTP error carrying a JSON body (401 Bad credentials, 404 Not Found)
#     gh writes {"message":...,"documentation_url":...,"status":...} to
#     STDOUT, so `jq length` counts the error object's KEYS. Result:
#     "3 open alert(s)" — PHANTOM ALERTS, and the detail render then
#     silently prints nothing because `.[]` does not apply to an object.
#
# Neither is an answer. Both now report UNKNOWN and count an issue — for the
# three queries that enforce the mandatory baseline in security.md, and for
# the CI-failure check.
#
# gh_json    runs a command and FAILS LOUDLY on error or empty output
# json_count counts from captured JSON, failing if it is not a number
# audit_unknown reports "result UNKNOWN, NOT clean" and counts an issue
gh_json() {
    local errf out rc
    errf="$(mktemp)" || { GH_STATUS=failed; GH_ERR="mktemp failed"; GH_OUT=""; return 1; }
    out="$("$@" 2>"$errf")"
    rc=$?
    if [[ $rc -ne 0 || -z $out ]]; then
        GH_STATUS=failed
        GH_ERR="exit $rc: $(tr -d '\0' <"$errf" | head -c 200 | tr '\n' ' ')"
        GH_OUT=""
        rm -f "$errf"
        return 1
    fi
    GH_STATUS=ok
    GH_OUT="$out"
    GH_ERR=""
    rm -f "$errf"
    return 0
}

json_count() {
    local text="$1" filter="$2" n
    n="$(printf '%s' "$text" | jq -r "$filter" 2>/dev/null)"
    if [[ -z $n ]] || ! [[ $n =~ ^[0-9]+$ ]]; then
        JSON_COUNT=0
        return 1
    fi
    JSON_COUNT="$n"
    return 0
}

audit_unknown() {
    echo "  ⚠️  $1: FAILED — result UNKNOWN, NOT clean"
    echo "      ${2:-no detail}"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
}
# ---------------------------------------------------------------------------
ISSUES_FIXED=0

# Check and enable Dependabot alerts
echo ""
echo "Checking Dependabot alerts..."
if gh api "repos/$GITHUB_REPO/vulnerability-alerts" &>/dev/null 2>&1; then
    echo "  ✅ Dependabot alerts: Enabled"
else
    echo "  ⚠️ Dependabot alerts: Not enabled"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))

    # Auto-fix in autonomous mode
    echo "  → Enabling Dependabot alerts..."
    if gh api -X PUT "repos/$GITHUB_REPO/vulnerability-alerts" &>/dev/null 2>&1; then
        echo "  ✅ Dependabot alerts: Now enabled"
        ISSUES_FIXED=$((ISSUES_FIXED + 1))
    else
        echo "  ❌ Failed to enable (may require admin access)"
    fi
fi

# Check and enable Dependabot security updates
echo ""
echo "Checking Dependabot security updates..."
if gh api "repos/$GITHUB_REPO/automated-security-fixes" &>/dev/null 2>&1; then
    echo "  ✅ Dependabot security updates: Enabled"
else
    echo "  ⚠️ Dependabot security updates: Not enabled"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))

    echo "  → Enabling Dependabot security updates..."
    if gh api -X PUT "repos/$GITHUB_REPO/automated-security-fixes" &>/dev/null 2>&1; then
        echo "  ✅ Dependabot security updates: Now enabled"
        ISSUES_FIXED=$((ISSUES_FIXED + 1))
    else
        echo "  ❌ Failed to enable (may require admin access)"
    fi
fi

# Check for security policy
echo ""
echo "Checking security policy..."
if gh api "repos/$GITHUB_REPO/contents/SECURITY.md" &>/dev/null 2>&1; then
    echo "  ✅ Security policy: Present"
else
    echo "  ⚠️ Security policy: Missing (SECURITY.md)"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
    echo "  ℹ️  Consider adding a SECURITY.md file"
fi
```

## Step 3: Security Workflows Audit

```bash
echo ""
echo "───────────────────────────────────────────────────────────────────"
echo "  Step 3: Security Workflows Audit"
echo "───────────────────────────────────────────────────────────────────"

# Get list of workflows
WORKFLOWS=$(gh api "repos/$GITHUB_REPO/contents/.github/workflows" 2>/dev/null | jq -r '.[].name' 2>/dev/null || echo "")

echo ""
echo "Existing workflows:"
if [[ -n "$WORKFLOWS" ]]; then
    echo "$WORKFLOWS" | sed 's/^/  - /'
else
    echo "  (none)"
fi

# Check for required security workflows based on project language
REPO_INFO=$(gh api "repos/$GITHUB_REPO" 2>/dev/null)
PRIMARY_LANG=$(echo "$REPO_INFO" | jq -r '.language // "Unknown"')

echo ""
echo "Primary language: $PRIMARY_LANG"
echo ""

# Check for appropriate security scanning
case "$PRIMARY_LANG" in
    Python)
        if echo "$WORKFLOWS" | grep -qi "codeql"; then
            echo "  ✅ CodeQL workflow: Found"
        else
            echo "  ⚠️ CodeQL workflow: Missing (recommended for Python)"
            ISSUES_FOUND=$((ISSUES_FOUND + 1))
        fi
        if echo "$WORKFLOWS" | grep -qiE "security|bandit|safety"; then
            echo "  ✅ Python security workflow: Found"
        else
            echo "  ⚠️ Python security workflow: Missing"
            ISSUES_FOUND=$((ISSUES_FOUND + 1))
        fi
        ;;
    JavaScript|TypeScript)
        if echo "$WORKFLOWS" | grep -qi "codeql"; then
            echo "  ✅ CodeQL workflow: Found"
        else
            echo "  ⚠️ CodeQL workflow: Missing (recommended for JS/TS)"
            ISSUES_FOUND=$((ISSUES_FOUND + 1))
        fi
        ;;
    Go)
        if echo "$WORKFLOWS" | grep -qiE "codeql|govulncheck"; then
            echo "  ✅ Go security workflow: Found"
        else
            echo "  ⚠️ Go security workflow: Missing"
            ISSUES_FOUND=$((ISSUES_FOUND + 1))
        fi
        ;;
    Rust)
        if echo "$WORKFLOWS" | grep -qiE "cargo-audit|security"; then
            echo "  ✅ Rust security workflow: Found"
        else
            echo "  ⚠️ Rust security workflow: Missing"
            ISSUES_FOUND=$((ISSUES_FOUND + 1))
        fi
        ;;
esac

# Check workflow schedule (should be daily)
echo ""
echo "Checking workflow schedules..."
for workflow in codeql security; do
    WF_FILE=$(echo "$WORKFLOWS" | grep -i "$workflow" | head -1)
    if [[ -n "$WF_FILE" ]]; then
        SCHEDULE=$(gh api "repos/$GITHUB_REPO/contents/.github/workflows/$WF_FILE" 2>/dev/null | \
                   jq -r '.content' | base64 -d 2>/dev/null | grep -A1 "schedule:" | grep "cron:")
        if [[ "$SCHEDULE" == *"* * *"* ]] || [[ "$SCHEDULE" == *"0 6 * * *"* ]]; then
            echo "  ✅ $WF_FILE: Daily schedule"
        elif [[ -n "$SCHEDULE" ]]; then
            echo "  ⚠️ $WF_FILE: Not daily ($SCHEDULE)"
        fi
    fi
done
```

## Step 4: Open Alerts Audit

```bash
echo ""
echo "───────────────────────────────────────────────────────────────────"
echo "  Step 4: Open Security Alerts"
echo "───────────────────────────────────────────────────────────────────"

# Dependabot alerts
echo ""
echo "Dependabot Alerts:"
if ! gh_json gh api "repos/$GITHUB_REPO/dependabot/alerts?state=open"; then
    audit_unknown "Dependabot alerts" "$GH_ERR"
    DEPENDABOT_ALERTS=""
    DEPENDABOT_COUNT=-1
elif ! json_count "$GH_OUT" 'length'; then
    audit_unknown "Dependabot alerts" "response was not a JSON array"
    DEPENDABOT_ALERTS=""
    DEPENDABOT_COUNT=-1
else
    DEPENDABOT_ALERTS="$GH_OUT"
    DEPENDABOT_COUNT="$JSON_COUNT"
fi

if [[ "$DEPENDABOT_COUNT" -lt 0 ]]; then
    :
elif [[ "$DEPENDABOT_COUNT" -eq 0 ]]; then
    echo "  ✅ No open Dependabot alerts"
else
    echo "  ❌ $DEPENDABOT_COUNT open alert(s):"
    echo "$DEPENDABOT_ALERTS" | jq -r '.[] | "    [\(.security_advisory.severity | ascii_upcase)] \(.security_advisory.summary) (\(.dependency.package.name))"' 2>/dev/null | head -10
    ISSUES_FOUND=$((ISSUES_FOUND + DEPENDABOT_COUNT))

    # Check for auto-fix PRs
    echo ""
    echo "  Checking for Dependabot PRs..."
    if gh_json gh pr list --repo "$GITHUB_REPO" --author "app/dependabot" --state open --json number,title &&
        json_count "$GH_OUT" 'length'; then
        DEPENDABOT_PRS="$GH_OUT"
        PR_COUNT="$JSON_COUNT"
    else
        audit_unknown "Dependabot PR list" "${GH_ERR:-unparseable response}"
        DEPENDABOT_PRS=""
        PR_COUNT=0
    fi

    if [[ "$PR_COUNT" -gt 0 ]]; then
        echo "  ℹ️  $PR_COUNT Dependabot PR(s) awaiting merge:"
        echo "$DEPENDABOT_PRS" | jq -r '.[] | "    #\(.number): \(.title)"' | head -5
    fi
fi

# Code scanning alerts
echo ""
echo "Code Scanning Alerts:"
if ! gh_json gh api "repos/$GITHUB_REPO/code-scanning/alerts?state=open"; then
    audit_unknown "Code scanning alerts" "$GH_ERR"
    CODE_ALERTS=""
    CODE_COUNT=-1
elif ! json_count "$GH_OUT" 'length'; then
    audit_unknown "Code scanning alerts" "response was not a JSON array"
    CODE_ALERTS=""
    CODE_COUNT=-1
else
    CODE_ALERTS="$GH_OUT"
    CODE_COUNT="$JSON_COUNT"
fi

if [[ "$CODE_COUNT" -lt 0 ]]; then
    :
elif [[ "$CODE_COUNT" -eq 0 ]]; then
    echo "  ✅ No open code scanning alerts"
else
    echo "  ❌ $CODE_COUNT open alert(s):"
    echo "$CODE_ALERTS" | jq -r '.[] | "    [\(.rule.severity // "unknown")] \(.rule.description) (\(.most_recent_instance.location.path):\(.most_recent_instance.location.start_line))"' 2>/dev/null | head -10
    ISSUES_FOUND=$((ISSUES_FOUND + CODE_COUNT))
fi

# Secret scanning alerts
echo ""
echo "Secret Scanning Alerts:"
if ! gh_json gh api "repos/$GITHUB_REPO/secret-scanning/alerts?state=open"; then
    # security.md makes secret scanning mandatory, so a query that did not run
    # is a finding, not a pass. A 404 here means the feature is off; a 401
    # means the token is dead. Both are reported, neither is "no alerts".
    audit_unknown "Secret scanning alerts" "$GH_ERR"
    SECRET_ALERTS=""
    SECRET_COUNT=-1
elif ! json_count "$GH_OUT" 'length'; then
    audit_unknown "Secret scanning alerts" "response was not a JSON array"
    SECRET_ALERTS=""
    SECRET_COUNT=-1
else
    SECRET_ALERTS="$GH_OUT"
    SECRET_COUNT="$JSON_COUNT"
fi

if [[ "$SECRET_COUNT" -lt 0 ]]; then
    :
elif [[ "$SECRET_COUNT" -eq 0 ]]; then
    echo "  ✅ No open secret scanning alerts"
else
    echo "  ❌ $SECRET_COUNT open alert(s):"
    echo "$SECRET_ALERTS" | jq -r '.[] | "    [\(.state)] \(.secret_type_display_name)"' 2>/dev/null | head -10
    ISSUES_FOUND=$((ISSUES_FOUND + SECRET_COUNT))
    echo ""
    echo "  ⚠️ SECRET ALERTS REQUIRE IMMEDIATE ATTENTION"
    echo "  View: https://github.com/$GITHUB_REPO/security/secret-scanning"
fi
```

## Step 5: Branch Protection Audit

```bash
echo ""
echo "───────────────────────────────────────────────────────────────────"
echo "  Step 5: Branch Protection"
echo "───────────────────────────────────────────────────────────────────"

DEFAULT_BRANCH=$(echo "$REPO_INFO" | jq -r '.default_branch')
echo "Default branch: $DEFAULT_BRANCH"
echo ""

PROTECTION=$(gh api "repos/$GITHUB_REPO/branches/$DEFAULT_BRANCH/protection" 2>/dev/null)

if [[ -n "$PROTECTION" ]] && [[ "$PROTECTION" != "null" ]]; then
    echo "  ✅ Branch protection: Enabled"

    # Check specific protections
    if echo "$PROTECTION" | jq -e '.required_pull_request_reviews' &>/dev/null; then
        echo "    ✅ Require PR reviews"
    else
        echo "    ⚪ PR reviews not required"
    fi

    if echo "$PROTECTION" | jq -e '.required_status_checks' &>/dev/null; then
        echo "    ✅ Status checks required"
    else
        echo "    ⚪ Status checks not required"
    fi

    if echo "$PROTECTION" | jq -e '.enforce_admins.enabled == true' &>/dev/null; then
        echo "    ✅ Enforce for admins"
    else
        echo "    ⚪ Admins can bypass"
    fi
else
    echo "  ⚠️ Branch protection: Not enabled"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
    echo "  ℹ️  Consider enabling branch protection for $DEFAULT_BRANCH"
fi
```

## Step 6: Local vs Remote Sync

```bash
echo ""
echo "───────────────────────────────────────────────────────────────────"
echo "  Step 6: Local/Remote Sync"
echo "───────────────────────────────────────────────────────────────────"

# Fetch latest
git fetch origin &>/dev/null

LOCAL_BRANCH=$(git rev-parse --abbrev-ref HEAD)
REMOTE_BRANCH="origin/$DEFAULT_BRANCH"

echo "Local branch: $LOCAL_BRANCH"
echo "Remote branch: $REMOTE_BRANCH"
echo ""

# Check sync status
# NOT `|| echo "0"`. git rev-list fails when the remote ref is not fetched,
# and two zeros render as "In sync with remote" — a false clean about push
# state, which is exactly what this step exists to check.
if ! LOCAL_AHEAD=$(git rev-list --count "$REMOTE_BRANCH..HEAD" 2>/dev/null) ||
    ! REMOTE_AHEAD=$(git rev-list --count "HEAD..$REMOTE_BRANCH" 2>/dev/null); then
    audit_unknown "Branch sync" "git rev-list failed — is $REMOTE_BRANCH fetched?"
    LOCAL_AHEAD=-1
    REMOTE_AHEAD=-1
fi

if [[ "$LOCAL_AHEAD" -lt 0 ]]; then
    :
elif [[ "$LOCAL_AHEAD" -eq 0 ]] && [[ "$REMOTE_AHEAD" -eq 0 ]]; then
    echo "  ✅ In sync with remote"
else
    if [[ "$LOCAL_AHEAD" -gt 0 ]]; then
        echo "  ⚠️ $LOCAL_AHEAD local commit(s) not pushed"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    fi
    if [[ "$REMOTE_AHEAD" -gt 0 ]]; then
        echo "  ⚠️ $REMOTE_AHEAD remote commit(s) not pulled"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    fi
fi

# Check for uncommitted changes
UNCOMMITTED=$(git status --porcelain | wc -l)
if [[ "$UNCOMMITTED" -gt 0 ]]; then
    echo "  ⚠️ $UNCOMMITTED uncommitted change(s)"
fi
```

## Step 7: CI/CD Status

```bash
echo ""
echo "───────────────────────────────────────────────────────────────────"
echo "  Step 7: CI/CD Status"
echo "───────────────────────────────────────────────────────────────────"

# Get recent workflow runs
echo ""
echo "Recent workflow runs:"
gh run list --repo "$GITHUB_REPO" --limit 5 --json name,status,conclusion,createdAt \
    --jq '.[] | "  \(.status) \(.conclusion // "running") - \(.name) (\(.createdAt | split("T")[0]))"' 2>/dev/null || echo "  (none)"

# Check for failed runs
# FAILED_RUNS is how this audit learns CI is red. A gh failure reporting
# "0 failed runs" is the 95-red-commits incident class, made invisible by the
# check meant to catch it.
if gh_json gh run list --repo "$GITHUB_REPO" --status failure --limit 5 --json name,conclusion &&
    json_count "$GH_OUT" 'length'; then
    FAILED_RUNS="$JSON_COUNT"
else
    audit_unknown "CI failure check" "${GH_ERR:-unparseable response}"
    FAILED_RUNS=0
fi

if [[ "$FAILED_RUNS" -gt 0 ]]; then
    echo ""
    echo "  ⚠️ $FAILED_RUNS recent failed workflow(s)"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi
```

## Step 8: bd Health Check (enrolled projects only)

Per `~/.claude/rules/beads.md`, projects enrolled in bd should be checked for issue-graph health alongside the GitHub audit. Findings are **informational** — they do NOT block release. (Note: `bd doctor` does not function in embedded mode and is intentionally skipped; `bd preflight` is the canonical health check.)

```bash
echo ""
echo "───────────────────────────────────────────────────────────────────"
echo "  Step 8: bd Health Check (enrolled projects only)"
echo "───────────────────────────────────────────────────────────────────"

if [ ! -d ".beads" ]; then
    echo "  ○ Not enrolled in bd — skipping"
elif ! command -v bd >/dev/null 2>&1; then
    echo "  ⚠ bd not on PATH — skipping (install: ~/.local/bin/bd)"
else
    echo ""
    echo "Running bd preflight (lint, stale, orphans):"
    pf_out=$(bd preflight 2>&1 || true)
    if [ -z "$pf_out" ]; then
        echo "  ✅ bd preflight: clean"
    else
        echo "$pf_out" | head -30 | sed 's/^/  /'
        # Increment ISSUES_FOUND only for hard problems (orphans), not stale warnings.
        #
        # NOT `$(... || echo 0)`. `grep -c` PRINTS "0" and EXITS 1 when there
        # are no matches, so the `||` fires too and the variable becomes the
        # two-line string "0\n0" — after which `[ "$bd_orphans" -gt 0 ]` dies
        # with "integer expression expected". Measured, not theorised.
        bd_orphans=$(printf '%s\n' "$pf_out" | grep -ciE 'orphan') || bd_orphans=0
        if [ "$bd_orphans" -gt 0 ]; then
            ISSUES_FOUND=$((ISSUES_FOUND + bd_orphans))
        fi
    fi

    echo ""
    echo "Open issue counts:"
    # From `bd stats`, NOT `bd list | wc -l`. Two reasons, both in
    # ~/.claude/rules/beads.md: `bd list` TRUNCATES past a row cap, and its
    # output carries a total line and a status legend that `wc -l` counts as
    # issues. Measured on a 48-open graph: the wc method reported 52.
    bd_stats_out=$(bd stats 2>/dev/null)
    bd_field() { printf '%s\n' "$bd_stats_out" | awk -F: -v k="$1" '$0 ~ "^[[:space:]]*"k":" {gsub(/[^0-9]/,"",$2); print $2; exit}'; }
    bd_open=$(bd_field "Open")
    bd_in_prog=$(bd_field "In Progress")
    bd_blocked=$(bd_field "Blocked")
    if [ -z "$bd_open$bd_in_prog$bd_blocked" ]; then
        echo "  ⚠ bd stats produced no counts — issue-graph health UNKNOWN, not clean"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    else
        echo "  open=${bd_open:-?}  in_progress=${bd_in_prog:-?}  blocked=${bd_blocked:-?}"
    fi
fi
```

## Summary Report

```bash
echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "  GITHUB AUDIT SUMMARY"
echo "═══════════════════════════════════════════════════════════════════"
echo ""
echo "Repository: $GITHUB_REPO"
echo "URL: https://github.com/$GITHUB_REPO"
echo ""
echo "Issues Found: $ISSUES_FOUND"
echo "Issues Fixed: $ISSUES_FIXED"
echo ""

if [[ "$ISSUES_FOUND" -eq 0 ]]; then
    echo "Status: ✅ PASS - GitHub repository is secure"
elif [[ "$ISSUES_FIXED" -eq "$ISSUES_FOUND" ]]; then
    echo "Status: ✅ PASS - All issues auto-fixed"
else
    REMAINING=$((ISSUES_FOUND - ISSUES_FIXED))
    echo "Status: ⚠️ ISSUES - $REMAINING issue(s) require attention"
    echo ""
    echo "View security dashboard:"
    echo "  https://github.com/$GITHUB_REPO/security"
fi
```

---

## Remediation Instructions (for Phase 6)

When Phase 6 (Auto-Fixing) runs, it should process GitHub issues:

### Enable Missing Security Features

```bash
enable_github_security() {
    local GITHUB_REPO="$1"

    # Enable Dependabot alerts
    gh api -X PUT "repos/$GITHUB_REPO/vulnerability-alerts" 2>/dev/null

    # Enable Dependabot security updates
    gh api -X PUT "repos/$GITHUB_REPO/automated-security-fixes" 2>/dev/null

    echo "Security features enabled for $GITHUB_REPO"
}
```

### Merge Dependabot PRs

```bash
merge_dependabot_prs() {
    local GITHUB_REPO="$1"

    # Get open Dependabot PRs
    gh pr list --repo "$GITHUB_REPO" --author "app/dependabot" --state open --json number,title | \
        jq -r '.[].number' | while read -r pr_num; do
            echo "Merging Dependabot PR #$pr_num..."
            gh pr merge "$pr_num" --repo "$GITHUB_REPO" --squash --auto 2>&1
        done
}
```

### Create Missing Security Workflow

```bash
create_security_workflow() {
    local GITHUB_REPO="$1"
    local LANG="$2"

    case "$LANG" in
        Python)
            # Create CodeQL workflow for Python
            echo "Creating CodeQL workflow..."
            # ... workflow creation code
            ;;
    esac
}
```

---

## Phase 9d Gate Decision

| GitHub Status | Action |
|---------------|--------|
| `not-a-repo` | **SKIP** Phase 9d |
| `no-remote` | **SKIP** Phase 9d |
| `not-github` | **SKIP** Phase 9d |
| `gh-not-installed` | **SKIP** Phase 9d (warn) |
| `not-authenticated` | **SKIP** Phase 9d (warn) |
| `secure` | **RUN** Phase 9d (verify) |
| `alerts-open` | **RUN** Phase 9d (remediate) |
| `incomplete` | **RUN** Phase 9d (enable features) |
