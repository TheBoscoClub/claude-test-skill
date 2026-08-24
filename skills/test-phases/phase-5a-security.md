# Phase 5a: Comprehensive Security Testing & Mitigation

> **Model**: `opus` | **Phase**: 5a | **Modifies Files**: No (read-only)
> **Task Tracking**: Call `TaskUpdate(taskId, status="in_progress")` at start, `TaskUpdate(taskId, status="completed")` when done.
> **Key Tools**: `Bash` for security scanners, `WebSearch` to look up CVE details and check for known exploits for flagged vulnerabilities. Use `AskUserQuestion` in `--interactive` mode for security remediation decisions (e.g., breaking change vs. patching). Parallelize with other phase 5 phases. Includes cross-component data flow tracing and unvalidated input detection.
> **Rate Limiting**: GitHub API calls are subject to rate limits. Use `gh api --cache 60s` where possible. Check `gh api rate_limit` before bulk API operations.

**THE security phase** - tests and mitigates all security issues across:
- **GitHub** - Repository security settings, alerts, workflows
- **Local Project** - Code vulnerabilities, secrets, dependencies, SAST
- **Installed App** - Production security verification (when applicable)

For targeted deep-dive security audits beyond the automated checks below, the dispatcher may invoke the `security-scanner` agent (see `agents/security-scanner.md`), which provides OWASP Top 10 coverage and detailed remediation guidance.

**Optional companion for skill supply-chain exposure**: when the project contains `.claude/skills/` or uses host-global skills, `/gstack-cso --skills` covers a blind spot of this phase — it scans skill files for curl-pipe-to-shell, unjustified credential access, writes outside the skill's own directory, and MCP server endpoints pointing at non-public domains. Run it out-of-phase when the skill inventory changes or before a release. It does not replace Phase 5a; it adds a layer Phase 5a does not cover.

## Invocation

```bash
# Run as part of full audit
/test                        # Phase 5a runs in the analysis group

# Run standalone (comprehensive security only)
/test --phase=5
/test --phase=SEC            # Alias for Phase 5 (supported in dispatcher)

# Run with auto-fix disabled (audit only)
/test --phase=5 --audit-only

# Run specific section
/test --phase=5 --target=github
/test --phase=5 --target=local
/test --phase=5 --target=installed
```

---

## Phase Configuration

```bash
# Initialize phase
echo "═══════════════════════════════════════════════════════════════════"
echo "  PHASE 5: COMPREHENSIVE SECURITY TESTING & MITIGATION"
echo "═══════════════════════════════════════════════════════════════════"
echo ""

# Determine what to test
HAS_GITHUB_REMOTE=false
HAS_INSTALLED_APP=false
PROJECT_ROOT="${PROJECT_DIR:-$(pwd)}"
PROJECT_NAME="${PROJECT_NAME:-$(basename "$PROJECT_ROOT")}"

# Check for GitHub remote
if git remote get-url origin 2>/dev/null | grep -q "github.com"; then
    HAS_GITHUB_REMOTE=true
    REMOTE_URL=$(git remote get-url origin 2>/dev/null)
    if [[ "$REMOTE_URL" =~ github\.com[:/]([^/]+)/([^/.]+) ]]; then
        GITHUB_REPO="${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
    fi
fi

# Check for installed app (common locations)
INSTALLED_PATHS=(
    "/opt/${PROJECT_NAME}"
    "/opt/${PROJECT_NAME}s"
    "/usr/local/${PROJECT_NAME}"
    "/srv/${PROJECT_NAME}"
)

for path in "${INSTALLED_PATHS[@]}"; do
    if [[ -d "$path" ]]; then
        HAS_INSTALLED_APP=true
        INSTALLED_APP_PATH="$path"
        break
    fi
done

echo "Testing targets:"
echo "  Local project: $PROJECT_ROOT"
echo "  GitHub repo:   ${GITHUB_REPO:-none}"
echo "  Installed app: ${INSTALLED_APP_PATH:-none}"
echo ""

# Initialize counters
TOTAL_ISSUES=0
FIXED_ISSUES=0
CRITICAL_ISSUES=0

# ---------------------------------------------------------------------------
# scan_count — run a scanner and DISTINGUISH THREE OUTCOMES the old code
# collapsed into one: ran-and-found-nothing, ran-and-found-N, and DID NOT RUN.
#
# Every scanner in this phase used to read:
#     COUNT=$(tool ... 2>/dev/null | jq '...' || echo "0")
# which reports a failing scanner as CLEAN three different ways: 2>/dev/null
# throws away the reason, `|| echo "0"` invents a clean answer, and even
# without that the `||` binds to the PIPELINE — a dead tool leaves jq with
# empty input, COUNT becomes "", and bash evaluates [[ "" -gt 0 ]] as false.
# Demonstrated 2026-08-24: grype against a bad path printed
# "OK Grype: No vulnerabilities".
#
# Usage:  scan_count <jq-filter> <command...>
# Sets:   SCAN_STATUS  'ok' | 'failed'
#         SCAN_COUNT   the count, valid ONLY when SCAN_STATUS is 'ok'
#         SCAN_ERR     the real stderr, when it failed
# Returns 0 on success, 1 on failure. NEVER substitutes a number for a failure.
scan_count() {
    local filter="$1"
    shift
    local out rc errf n
    errf="$(mktemp)" || { SCAN_STATUS=failed; SCAN_ERR="mktemp failed"; SCAN_COUNT=0; return 1; }

    out="$("$@" 2>"$errf")"
    rc=$?

    # The exit code is deliberately NOT the test. bandit, semgrep, checkov and
    # npm audit all exit NON-ZERO when they FIND something, so gating on rc
    # would report every real finding as a scanner failure. The honest question
    # is whether the tool produced a parseable answer: a tool that exits 1 with
    # valid findings JSON ran fine, and a tool that exits 0 with no output (the
    # timeout case that started this) did not.
    n="$(printf '%s' "$out" | jq -r "$filter" 2>>"$errf")"
    if [[ -z $n ]] || ! [[ $n =~ ^[0-9]+$ ]]; then
        SCAN_STATUS=failed
        SCAN_ERR="exit $rc, no parseable count: $(tr -d '\0' <"$errf" | head -c 300 | tr '\n' ' ')"
        SCAN_COUNT=0
        rm -f "$errf"
        return 1
    fi

    SCAN_STATUS=ok
    SCAN_COUNT="$n"
    SCAN_ERR=""
    rm -f "$errf"
    return 0
}

# scan_failed — the uniform failure branch. A scanner that did not run is a
# FINDING, not a pass: it counts toward TOTAL_ISSUES so the audit total
# reflects that something is unverified, and it prints the real error so the
# operator can see why rather than reading a checkmark.
scan_failed() {
    local label="$1"
    echo "  ⚠️  ${label}: FAILED — result UNKNOWN, NOT clean"
    echo "      ${SCAN_ERR}"
    TOTAL_ISSUES=$((TOTAL_ISSUES + 1))
}
# ---------------------------------------------------------------------------

# Detect primary language
PRIMARY_LANG="Unknown"
if [[ -n "$(find "$PROJECT_ROOT" -maxdepth 3 -name '*.py' -not -path '*/.venv/*' -not -path '*/.snapshots/*' 2>/dev/null | head -1)" ]]; then
    PRIMARY_LANG="Python"
elif [[ -f "$PROJECT_ROOT/package.json" ]]; then
    PRIMARY_LANG="JavaScript"
elif [[ -f "$PROJECT_ROOT/go.mod" ]]; then
    PRIMARY_LANG="Go"
fi
echo "Primary language: $PRIMARY_LANG"
```

---

## Section 1: GitHub Security

Tests and mitigates GitHub repository security settings and alerts.

```bash
echo ""
echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║  SECTION 1: GITHUB SECURITY                                       ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"

if [[ "$HAS_GITHUB_REMOTE" != "true" ]]; then
    echo "ℹ️ No GitHub remote - skipping GitHub security checks"
else
    if ! command -v gh &>/dev/null; then
        echo "⚠️ GitHub CLI (gh) not installed - skipping GitHub security checks"
    elif ! gh auth status &>/dev/null 2>&1; then
        echo "⚠️ GitHub CLI not authenticated - run: gh auth login"
        echo "   Skipping all GitHub API checks (authentication required)"
    else
        echo "Repository: https://github.com/$GITHUB_REPO"
        echo ""

        # 1.1 Security Features (Auto-Enable)
        echo "───────────────────────────────────────────────────────────────"
        echo "  1.1 Security Features"
        echo "───────────────────────────────────────────────────────────────"

        # Dependabot alerts
        if gh api "repos/$GITHUB_REPO/vulnerability-alerts" &>/dev/null 2>&1; then
            echo "  ✅ Dependabot alerts: Enabled"
        else
            echo "  ❌ Dependabot alerts: Not enabled"
            TOTAL_ISSUES=$((TOTAL_ISSUES + 1))
            if [[ "$AUDIT_ONLY" != "true" ]]; then
                gh api -X PUT "repos/$GITHUB_REPO/vulnerability-alerts" &>/dev/null && echo "  ✅ Now enabled" && FIXED_ISSUES=$((FIXED_ISSUES + 1))
            fi
        fi

        # Dependabot security updates
        if gh api "repos/$GITHUB_REPO/automated-security-fixes" &>/dev/null 2>&1; then
            echo "  ✅ Dependabot security updates: Enabled"
        else
            echo "  ❌ Dependabot security updates: Not enabled"
            TOTAL_ISSUES=$((TOTAL_ISSUES + 1))
            if [[ "$AUDIT_ONLY" != "true" ]]; then
                gh api -X PUT "repos/$GITHUB_REPO/automated-security-fixes" &>/dev/null && echo "  ✅ Now enabled" && FIXED_ISSUES=$((FIXED_ISSUES + 1))
            fi
        fi

        # 1.2 Open Alerts
        echo ""
        echo "───────────────────────────────────────────────────────────────"
        echo "  1.2 Open Alerts"
        echo "───────────────────────────────────────────────────────────────"

        # Dependabot alerts
        if ! scan_count 'length' gh api "repos/$GITHUB_REPO/dependabot/alerts?state=open"; then
            scan_failed "Dependabot"
        elif [[ "$SCAN_COUNT" -eq 0 ]]; then
            echo "  ✅ Dependabot: No open alerts"
        else
            echo "  ❌ Dependabot: $SCAN_COUNT open alert(s)"
            TOTAL_ISSUES=$((TOTAL_ISSUES + SCAN_COUNT))
        fi

        # Code scanning alerts
        if ! scan_count 'length' gh api "repos/$GITHUB_REPO/code-scanning/alerts?state=open"; then
            scan_failed "Code scanning"
        elif [[ "$SCAN_COUNT" -eq 0 ]]; then
            echo "  ✅ Code scanning: No open alerts"
        else
            echo "  ❌ Code scanning: $SCAN_COUNT open alert(s)"
            TOTAL_ISSUES=$((TOTAL_ISSUES + SCAN_COUNT))
        fi

        # Secret scanning alerts
        if ! scan_count 'length' gh api "repos/$GITHUB_REPO/secret-scanning/alerts?state=open"; then
            # A secret-scanning query that did not run is CRITICAL-unknown, not
            # clean: this is the check enforcing the mandatory baseline in
            # security.md, and an expired token returns the same silence as a
            # clean repo.
            scan_failed "Secret scanning"
            CRITICAL_ISSUES=$((CRITICAL_ISSUES + 1))
        elif [[ "$SCAN_COUNT" -eq 0 ]]; then
            echo "  ✅ Secret scanning: No open alerts"
        else
            echo "  🚨 SECRET SCANNING: $SCAN_COUNT ALERT(S) - CRITICAL!"
            TOTAL_ISSUES=$((TOTAL_ISSUES + SCAN_COUNT))
            CRITICAL_ISSUES=$((CRITICAL_ISSUES + SCAN_COUNT))
        fi
    fi
fi
```

---

## Section 2: Local Project Security

```bash
echo ""
echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║  SECTION 2: LOCAL PROJECT SECURITY                                ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"

# 2.1 Secret Detection
echo ""
echo "───────────────────────────────────────────────────────────────────"
echo "  2.1 Secret Detection"
echo "───────────────────────────────────────────────────────────────────"

SECRETS_FOUND=0

# Exclusion patterns: test fixtures, documentation, snapshots, vendored deps
SECRET_EXCLUDE="--exclude-dir=.snapshots --exclude-dir=test_fixtures --exclude-dir=tests/fixtures --exclude-dir=vendor --exclude-dir=node_modules --exclude-dir=.venv --exclude=*.md --exclude=*.rst --exclude=*.txt"

# AWS keys
AWS_KEYS=$(grep -rE $SECRET_EXCLUDE "AKIA[0-9A-Z]{16}" "$PROJECT_ROOT" 2>/dev/null | head -5)
if [[ -n "$AWS_KEYS" ]]; then
    echo "  🚨 AWS Access Key(s) found in source code!"
    echo "$AWS_KEYS" | head -3
    SECRETS_FOUND=$((SECRETS_FOUND + 1))
    CRITICAL_ISSUES=$((CRITICAL_ISSUES + 1))
fi

# Also check test/doc files separately (lower severity)
AWS_KEYS_TEST=$(grep -rE "AKIA[0-9A-Z]{16}" "$PROJECT_ROOT" --include="*.md" --include="*test*" 2>/dev/null | grep -v ".snapshots" | head -3)
if [[ -n "$AWS_KEYS_TEST" ]]; then
    echo "  ⚠️ AWS key pattern in tests/docs (verify these are fake/example keys)"
fi

# Private keys
PRIVATE_KEYS=$(grep -rE $SECRET_EXCLUDE "-----BEGIN.*PRIVATE KEY-----" "$PROJECT_ROOT" 2>/dev/null | head -5)
if [[ -n "$PRIVATE_KEYS" ]]; then
    echo "  🚨 Private key(s) found in source code!"
    echo "$PRIVATE_KEYS" | head -3
    SECRETS_FOUND=$((SECRETS_FOUND + 1))
    CRITICAL_ISSUES=$((CRITICAL_ISSUES + 1))
fi

[[ "$SECRETS_FOUND" -eq 0 ]] && echo "  ✅ No hardcoded secrets detected"
TOTAL_ISSUES=$((TOTAL_ISSUES + SECRETS_FOUND))

# 2.2 SAST
echo ""
echo "───────────────────────────────────────────────────────────────────"
echo "  2.2 Static Application Security Testing (SAST)"
echo "───────────────────────────────────────────────────────────────────"

# Bandit (Python)
if command -v bandit &>/dev/null && [[ "$PRIMARY_LANG" == "Python" ]]; then
    echo "Running Bandit..."
    if ! scan_count '[.results[] | select(.severity == "HIGH")] | length' \
        bandit -r "$PROJECT_ROOT" -x ./.venv,./.snapshots,./venv --format json; then
        scan_failed "Bandit"
    elif [[ "$SCAN_COUNT" -gt 0 ]]; then
        echo "  ❌ Bandit HIGH severity: $SCAN_COUNT"
        TOTAL_ISSUES=$((TOTAL_ISSUES + SCAN_COUNT))
        CRITICAL_ISSUES=$((CRITICAL_ISSUES + SCAN_COUNT))
    else
        echo "  ✅ Bandit: No high severity issues"
    fi
fi

# Semgrep
if command -v semgrep &>/dev/null; then
    echo "Running Semgrep (timeout: 300s)..."
    if ! scan_count '.results | length' \
        timeout 300 semgrep scan --config auto --json "$PROJECT_ROOT"; then
        scan_failed "Semgrep"
    elif [[ "$SCAN_COUNT" -gt 0 ]]; then
        echo "  ❌ Semgrep found $SCAN_COUNT issue(s)"
        TOTAL_ISSUES=$((TOTAL_ISSUES + SCAN_COUNT))
    else
        echo "  ✅ Semgrep: No issues"
    fi
fi

# CodeQL (Local) — timeout 600s to prevent hangs on large projects
if command -v codeql &>/dev/null && [[ "$PRIMARY_LANG" == "Python" ]]; then
    echo "Running CodeQL local analysis (timeout: 600s)..."
    CODEQL_DB="/tmp/codeql-audit-$$"
    if timeout 600 codeql database create "$CODEQL_DB" --language=python --source-root="$PROJECT_ROOT" 2>/dev/null; then
        timeout 600 codeql database analyze "$CODEQL_DB" --format=sarif-latest --output="/tmp/codeql-$$.sarif" \
            "codeql/python-queries:codeql-suites/python-security-extended.qls" 2>/dev/null
        if [[ $? -eq 124 ]]; then
            echo "  ⚠️ CodeQL analysis timed out (600s) — skipping results"
        else
            if ! scan_count '.runs[0].results | length' cat "/tmp/codeql-$$.sarif"; then
                scan_failed "CodeQL"
            elif [[ "$SCAN_COUNT" -gt 0 ]]; then
                echo "  ❌ CodeQL found $SCAN_COUNT issues"
                TOTAL_ISSUES=$((TOTAL_ISSUES + SCAN_COUNT))
            else
                echo "  ✅ CodeQL: No issues"
            fi
        fi
        rm -rf "$CODEQL_DB" "/tmp/codeql-$$.sarif"
    elif [[ $? -eq 124 ]]; then
        echo "  ⚠️ CodeQL database creation timed out (600s)"
        rm -rf "$CODEQL_DB"
    fi
elif [[ "$PRIMARY_LANG" == "Python" ]]; then
    echo "  ℹ️ CodeQL not installed — skipping local SAST (install: yay -S codeql)"
fi

# 2.3 Dependency Vulnerabilities
echo ""
echo "───────────────────────────────────────────────────────────────────"
echo "  2.3 Dependency Vulnerabilities"
echo "───────────────────────────────────────────────────────────────────"

# pip-audit
if command -v pip-audit &>/dev/null && [[ -f "$PROJECT_ROOT/requirements.txt" ]]; then
    echo "Running pip-audit..."
    if pip-audit --progress-spinner=off 2>&1 | grep -q "No known vulnerabilities"; then
        echo "  ✅ pip-audit: No vulnerabilities"
    else
        echo "  ❌ pip-audit found vulnerabilities"
        TOTAL_ISSUES=$((TOTAL_ISSUES + 1))
        [[ "$AUDIT_ONLY" != "true" ]] && pip-audit --fix 2>&1 | head -5 && FIXED_ISSUES=$((FIXED_ISSUES + 1))
    fi
fi

# Trivy
if command -v trivy &>/dev/null; then
    echo "Running Trivy filesystem scan..."
    if ! scan_count '[.Results[]?.Vulnerabilities // [] | .[]] | length' \
        trivy fs --security-checks vuln,secret --format json "$PROJECT_ROOT"; then
        scan_failed "Trivy"
    elif [[ "$SCAN_COUNT" -gt 0 ]]; then
        echo "  ❌ Trivy found $SCAN_COUNT vulnerabilities"
        TOTAL_ISSUES=$((TOTAL_ISSUES + SCAN_COUNT))
    else
        echo "  ✅ Trivy: No vulnerabilities"
    fi
fi

# Grype
if command -v grype &>/dev/null; then
    echo "Running Grype vulnerability scan..."
    if ! scan_count '.matches | length' grype dir:"$PROJECT_ROOT" --output json; then
        scan_failed "Grype"
    elif [[ "$SCAN_COUNT" -gt 0 ]]; then
        echo "  ❌ Grype found $SCAN_COUNT issues"
        TOTAL_ISSUES=$((TOTAL_ISSUES + SCAN_COUNT))
    else
        echo "  ✅ Grype: No vulnerabilities"
    fi
fi

# cargo audit (Rust)
if [[ -f "$PROJECT_ROOT/Cargo.toml" ]] || [[ -f "$PROJECT_ROOT/indexer/Cargo.toml" ]]; then
    CARGO_DIR="$PROJECT_ROOT"
    [[ -f "$PROJECT_ROOT/indexer/Cargo.toml" ]] && CARGO_DIR="$PROJECT_ROOT/indexer"
    echo "Running cargo audit..."
    pushd "$CARGO_DIR" > /dev/null
    if cargo audit 2>&1 | grep -q "0 vulnerabilities found"; then
        echo "  ✅ cargo audit: No vulnerabilities"
    else
        echo "  ⚠️  cargo audit found issues (check yanked crates and advisories)"
        TOTAL_ISSUES=$((TOTAL_ISSUES + 1))
        cargo audit 2>&1 | head -20
    fi

    # cargo deny (license + vulnerability database superset)
    if command -v cargo-deny &>/dev/null; then
        echo "Running cargo deny check..."
        if cargo deny check 2>&1 | grep -q "advisories ok, bans ok, licenses ok, sources ok"; then
            echo "  ✅ cargo deny: All checks passed"
        else
            echo "  ⚠️  cargo deny found issues"
            TOTAL_ISSUES=$((TOTAL_ISSUES + 1))
            cargo deny check 2>&1 | tail -20
        fi
    fi
    popd > /dev/null
fi

# npm audit
if [[ -f "$PROJECT_ROOT/package.json" ]]; then
    echo "Running npm audit..."
    if ! scan_count '.metadata.vulnerabilities.total' npm audit --json; then
        scan_failed "npm audit"
    elif [[ "$SCAN_COUNT" -eq 0 ]]; then
        echo "  ✅ npm audit: No vulnerabilities"
    else
        VULN_TOTAL=$SCAN_COUNT
        echo "  ❌ npm audit: $VULN_TOTAL vulnerabilities"
        TOTAL_ISSUES=$((TOTAL_ISSUES + 1))
        [[ "$AUDIT_ONLY" != "true" ]] && npm audit fix 2>&1 | tail -3 && FIXED_ISSUES=$((FIXED_ISSUES + 1))
    fi
fi

# 2.4 Code Vulnerability Patterns
echo ""
echo "───────────────────────────────────────────────────────────────────"
echo "  2.4 Code Vulnerability Patterns"
echo "───────────────────────────────────────────────────────────────────"

PATTERN_ISSUES=0

# SQL Injection
if grep -rqn "execute.*format\|execute.*f\"" --include="*.py" "$PROJECT_ROOT" 2>/dev/null; then
    echo "  ⚠️ Potential SQL injection patterns found"
    PATTERN_ISSUES=$((PATTERN_ISSUES + 1))
fi

# Command Injection
if grep -rqn "subprocess.*shell=True" --include="*.py" "$PROJECT_ROOT" 2>/dev/null | grep -v test; then
    echo "  ⚠️ Potential command injection (shell=True)"
    PATTERN_ISSUES=$((PATTERN_ISSUES + 1))
fi

# XSS (innerHTML/dangerouslySetInnerHTML)
if grep -rqn "innerHTML" --include="*.js" --include="*.jsx" --include="*.tsx" "$PROJECT_ROOT" 2>/dev/null; then
    echo "  ⚠️ Potential XSS (innerHTML usage)"
    PATTERN_ISSUES=$((PATTERN_ISSUES + 1))
fi

[[ "$PATTERN_ISSUES" -eq 0 ]] && echo "  ✅ No obvious vulnerability patterns"
TOTAL_ISSUES=$((TOTAL_ISSUES + PATTERN_ISSUES))

# 2.5 IaC Security (Checkov)
if command -v checkov &>/dev/null; then
    IAC_FILES=$(find "$PROJECT_ROOT" -name "*.tf" -o -name "Dockerfile" -o -name "docker-compose*.yml" 2>/dev/null | head -1)
    if [[ -n "$IAC_FILES" ]]; then
        echo ""
        echo "───────────────────────────────────────────────────────────────────"
        echo "  2.5 Infrastructure as Code Security (Checkov)"
        echo "───────────────────────────────────────────────────────────────────"
        if ! scan_count '[.results.failed_checks // []] | length' \
            checkov -d "$PROJECT_ROOT" --quiet --compact --output json; then
            scan_failed "Checkov"
        elif [[ "$SCAN_COUNT" -gt 0 ]]; then
            echo "  ❌ Checkov found $SCAN_COUNT IaC issues"
            TOTAL_ISSUES=$((TOTAL_ISSUES + SCAN_COUNT))
        else
            echo "  ✅ Checkov: No IaC security issues"
        fi
    fi
fi
```

---

## Section 3: Installed App Security

```bash
echo ""
echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║  SECTION 3: INSTALLED APP SECURITY                                ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"

if [[ "$HAS_INSTALLED_APP" != "true" ]]; then
    echo "ℹ️ No installed app detected - skipping"
else
    echo "Installed app path: $INSTALLED_APP_PATH"

    # 3.1 File Permissions
    echo ""
    echo "───────────────────────────────────────────────────────────────────"
    echo "  3.1 File Permissions"
    echo "───────────────────────────────────────────────────────────────────"

    WORLD_WRITABLE=$(find "$INSTALLED_APP_PATH" -type f -perm -002 2>/dev/null | head -10)
    if [[ -n "$WORLD_WRITABLE" ]]; then
        echo "  ❌ World-writable files found"
        TOTAL_ISSUES=$((TOTAL_ISSUES + 1))
        CRITICAL_ISSUES=$((CRITICAL_ISSUES + 1))
        [[ "$AUDIT_ONLY" != "true" ]] && echo "$WORLD_WRITABLE" | xargs -I {} sudo chmod o-w {} 2>/dev/null && FIXED_ISSUES=$((FIXED_ISSUES + 1))
    else
        echo "  ✅ No world-writable files"
    fi

    # 3.2 Service Security
    echo ""
    echo "───────────────────────────────────────────────────────────────────"
    echo "  3.2 Service Security"
    echo "───────────────────────────────────────────────────────────────────"

    for svc in "${PROJECT_NAME}-api" "${PROJECT_NAME}s-api"; do
        if systemctl is-active --quiet "$svc" 2>/dev/null; then
            SVC_USER=$(systemctl show "$svc" --property=User --value 2>/dev/null)
            if [[ "$SVC_USER" == "root" ]] || [[ -z "$SVC_USER" ]]; then
                echo "  ⚠️ Service runs as root"
                TOTAL_ISSUES=$((TOTAL_ISSUES + 1))
            else
                echo "  ✅ Service runs as: $SVC_USER"
            fi
            break
        fi
    done

    # 3.3 Database Security
    echo ""
    echo "───────────────────────────────────────────────────────────────────"
    echo "  3.3 Database Security"
    echo "───────────────────────────────────────────────────────────────────"

    DB_FILES=$(find "$INSTALLED_APP_PATH" -name "*.db" -o -name "*.sqlite*" 2>/dev/null)
    if [[ -n "$DB_FILES" ]]; then
        for db in $DB_FILES; do
            DB_PERMS=$(stat -c "%a" "$db" 2>/dev/null)
            echo "  Database: $(basename "$db") - Permissions: $DB_PERMS"
        done
    else
        echo "  ℹ️ No SQLite databases found"
    fi
fi
```

---

## Cross-Component Data Flow Analysis

Every phase must analyze security holistically — not just within individual files but across the entire project's data flows. This section is mandatory for all /test audits.

### 3a. Map Entry Points

```bash
# API endpoints (Python Flask/FastAPI/Django)
grep -rn "@app\.route\|@router\.\|@api_view\|path(" --include="*.py" "$PROJECT_ROOT" \
  | grep -v ".venv\|.snapshots\|test" | sort

# API endpoints (Node.js Express/Fastify)
grep -rn "app\.\(get\|post\|put\|delete\|patch\)\|router\.\(get\|post\|put\|delete\|patch\)" \
  --include="*.js" --include="*.ts" "$PROJECT_ROOT" | grep -v "node_modules\|.snapshots\|test" | sort

# CLI entry points
grep -rn "argparse\|click\.command\|typer\.\|clap::Parser\|flag\.Parse\|cobra" \
  --include="*.py" --include="*.go" --include="*.rs" "$PROJECT_ROOT" \
  | grep -v ".venv\|.snapshots\|vendor" | sort

# File reads (data ingestion)
grep -rn "open(\|read_file\|readFileSync\|os\.ReadFile\|fs::read" \
  --include="*.py" --include="*.js" --include="*.ts" --include="*.go" --include="*.rs" \
  "$PROJECT_ROOT" | grep -v ".venv\|node_modules\|.snapshots\|test" | sort
```

### 3b. Map Storage Points

```bash
# Database writes
grep -rn "\.execute\|\.commit\|\.insert\|\.update\|\.save\|\.create\|INSERT INTO\|UPDATE .* SET" \
  --include="*.py" --include="*.js" --include="*.ts" --include="*.go" "$PROJECT_ROOT" \
  | grep -v ".venv\|node_modules\|.snapshots\|test" | sort

# File writes
grep -rn "open(.*['\"]w\|write(\|writeFileSync\|os\.WriteFile\|fs::write" \
  --include="*.py" --include="*.js" --include="*.ts" --include="*.go" --include="*.rs" \
  "$PROJECT_ROOT" | grep -v ".venv\|node_modules\|.snapshots\|test" | sort

# Environment/state writes
grep -rn "os\.environ\[.*\]\s*=\|process\.env\.\S*\s*=\|os\.Setenv" \
  --include="*.py" --include="*.js" --include="*.ts" --include="*.go" "$PROJECT_ROOT" \
  | grep -v ".venv\|node_modules\|.snapshots" | sort
```

### 3c. Map Exit Points

```bash
# API responses
grep -rn "return.*jsonify\|return.*Response\|res\.json\|res\.send\|json\.NewEncoder\|HttpResponse" \
  --include="*.py" --include="*.js" --include="*.ts" --include="*.go" "$PROJECT_ROOT" \
  | grep -v ".venv\|node_modules\|.snapshots\|test" | sort

# Logging (potential data leakage)
grep -rn "logger\.\|logging\.\|console\.log\|log\.\(Print\|Info\|Warn\|Error\)" \
  --include="*.py" --include="*.js" --include="*.ts" --include="*.go" "$PROJECT_ROOT" \
  | grep -v ".venv\|node_modules\|.snapshots\|test" | wc -l
# Count only — read selectively if count is high
```

### 3d. Flag Unvalidated Flows

```bash
# API endpoints that read request data without validation
# Python: request.form/json/args without schema validation
grep -rn "request\.\(form\|json\|args\|data\)\[" --include="*.py" "$PROJECT_ROOT" \
  | grep -v ".venv\|.snapshots\|test" | while IFS=: read -r file line rest; do
    # Check if the same function has validation (marshmallow, pydantic, wtforms)
    func_start=$(grep -n "^def \|^async def " "$file" | awk -F: -v ln="$line" '$1 < ln {last=$1} END {print last}')
    has_validation=$(sed -n "${func_start},${line}p" "$file" | grep -c "validate\|schema\|Schema\|BaseModel\|Form")
    if [ "$has_validation" -eq 0 ]; then
      echo "UNVALIDATED: $file:$line $rest"
    fi
  done 2>/dev/null

# Node.js: req.body/params/query without validation
grep -rn "req\.\(body\|params\|query\)\." --include="*.js" --include="*.ts" "$PROJECT_ROOT" \
  | grep -v "node_modules\|.snapshots\|test" | head -30
```

Report: List each data flow (entry -> storage -> exit) and flag unvalidated paths.

### Data Flow Checklist

```
[ ] Data entry points mapped (API, CLI, file reads)
[ ] Data storage points mapped (DB, file writes)
[ ] Data exit points mapped (API responses, logs, file writes)
[ ] Unvalidated data flows flagged
```

---

## Summary Report

```bash
echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "  PHASE 5: SECURITY AUDIT SUMMARY"
echo "═══════════════════════════════════════════════════════════════════"
echo ""
echo "Tools Used:"
command -v bandit &>/dev/null && echo "  ✅ bandit"
command -v semgrep &>/dev/null && echo "  ✅ semgrep"
command -v codeql &>/dev/null && echo "  ✅ codeql"
command -v trivy &>/dev/null && echo "  ✅ trivy"
command -v grype &>/dev/null && echo "  ✅ grype"
command -v pip-audit &>/dev/null && echo "  ✅ pip-audit"
command -v checkov &>/dev/null && echo "  ✅ checkov"
echo ""
echo "Results:"
echo "  Total issues found:    $TOTAL_ISSUES"
echo "  Critical issues:       $CRITICAL_ISSUES"
echo "  Issues auto-fixed:     $FIXED_ISSUES"
echo "  Issues remaining:      $((TOTAL_ISSUES - FIXED_ISSUES))"
echo ""

if [[ "$CRITICAL_ISSUES" -gt 0 ]]; then
    echo "Status: 🚨 CRITICAL - $CRITICAL_ISSUES critical issue(s)"
elif [[ "$TOTAL_ISSUES" -gt "$FIXED_ISSUES" ]]; then
    echo "Status: ⚠️ ISSUES - $((TOTAL_ISSUES - FIXED_ISSUES)) issue(s) need attention"
elif [[ "$TOTAL_ISSUES" -gt 0 ]]; then
    echo "Status: ✅ MITIGATED - All issues auto-fixed"
else
    echo "Status: ✅ SECURE - No security issues found"
fi
echo ""
echo "═══════════════════════════════════════════════════════════════════"
```

---

## Integration Notes

### Invocation:
- `/test` - Phase 5a runs in the analysis group
- `/test --phase=5` or `/test --phase=SEC` - Standalone
- `/test --phase=5 --audit-only` - No auto-fixes

### Auto-Mitigation:
- Enables GitHub Dependabot/security features
- Runs `pip-audit --fix` and `npm audit fix`
- Fixes file permissions

### Tool Requirements:
| Tool | Install |
|------|---------|
| bandit | `pipx install bandit` |
| semgrep | `pipx install semgrep` |
| codeql | `yay -S codeql` |
| trivy | `pacman -S trivy` |
| grype | `yay -S grype-bin` |
| pip-audit | `pipx install pip-audit` |
| checkov | `pipx install checkov` |
