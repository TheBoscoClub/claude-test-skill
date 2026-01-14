# Phase SEC: Comprehensive Security Testing & Mitigation

**Standalone security phase** that tests and mitigates security issues across:
- **GitHub** - Repository security settings, alerts, workflows
- **Local Project** - Code vulnerabilities, secrets, dependencies
- **Installed App** - Production security verification (when applicable)

## Invocation

```bash
# Run as standalone phase
/test --phase SEC

# Run with auto-fix disabled (audit only)
/test --phase SEC --audit-only

# Run specific sub-phase
/test --phase SEC --target github
/test --phase SEC --target local
/test --phase SEC --target installed
```

---

## Phase Configuration

```bash
# Initialize phase
echo "═══════════════════════════════════════════════════════════════════"
echo "  PHASE SEC: COMPREHENSIVE SECURITY TESTING & MITIGATION"
echo "═══════════════════════════════════════════════════════════════════"
echo ""

# Determine what to test
HAS_GITHUB_REMOTE=false
HAS_INSTALLED_APP=false
PROJECT_ROOT="${PROJECT_DIR:-$(pwd)}"

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
    "/opt/${PROJECT_NAME:-$(basename "$PROJECT_ROOT")}"
    "/usr/local/${PROJECT_NAME:-$(basename "$PROJECT_ROOT")}"
    "/srv/${PROJECT_NAME:-$(basename "$PROJECT_ROOT")}"
)

for path in "${INSTALLED_PATHS[@]}"; do
    if [[ -d "$path" ]]; then
        HAS_INSTALLED_APP=true
        INSTALLED_APP_PATH="$path"
        break
    fi
done

# Also check project-specific install path variable
if [[ -n "$PRODUCTION_PATH" ]] && [[ -d "$PRODUCTION_PATH" ]]; then
    HAS_INSTALLED_APP=true
    INSTALLED_APP_PATH="$PRODUCTION_PATH"
fi

echo "Testing targets:"
echo "  Local project: $PROJECT_ROOT"
echo "  GitHub repo: ${GITHUB_REPO:-none}"
echo "  Installed app: ${INSTALLED_APP_PATH:-none}"
echo ""

# Initialize counters
TOTAL_ISSUES=0
FIXED_ISSUES=0
CRITICAL_ISSUES=0
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
    # Verify gh CLI
    if ! command -v gh &>/dev/null; then
        echo "⚠️ GitHub CLI (gh) not installed - install with: sudo pacman -S github-cli"
    elif ! gh auth status &>/dev/null 2>&1; then
        echo "⚠️ GitHub CLI not authenticated - run: gh auth login"
    else
        echo "Repository: https://github.com/$GITHUB_REPO"
        echo ""

        # ═══════════════════════════════════════════════════════════════
        # 1.1 Security Features
        # ═══════════════════════════════════════════════════════════════
        echo "───────────────────────────────────────────────────────────────"
        echo "  1.1 Security Features"
        echo "───────────────────────────────────────────────────────────────"

        # Dependabot vulnerability alerts
        echo ""
        echo "Checking Dependabot alerts..."
        if gh api "repos/$GITHUB_REPO/vulnerability-alerts" &>/dev/null 2>&1; then
            echo "  ✅ Dependabot alerts: Enabled"
        else
            echo "  ❌ Dependabot alerts: Not enabled"
            TOTAL_ISSUES=$((TOTAL_ISSUES + 1))

            echo "  → MITIGATING: Enabling Dependabot alerts..."
            if gh api -X PUT "repos/$GITHUB_REPO/vulnerability-alerts" &>/dev/null 2>&1; then
                echo "  ✅ Dependabot alerts: Now enabled"
                FIXED_ISSUES=$((FIXED_ISSUES + 1))
            else
                echo "  ⚠️ Failed to enable (requires admin access)"
            fi
        fi

        # Dependabot security updates
        echo ""
        echo "Checking Dependabot security updates..."
        if gh api "repos/$GITHUB_REPO/automated-security-fixes" &>/dev/null 2>&1; then
            echo "  ✅ Dependabot security updates: Enabled"
        else
            echo "  ❌ Dependabot security updates: Not enabled"
            TOTAL_ISSUES=$((TOTAL_ISSUES + 1))

            echo "  → MITIGATING: Enabling Dependabot security updates..."
            if gh api -X PUT "repos/$GITHUB_REPO/automated-security-fixes" &>/dev/null 2>&1; then
                echo "  ✅ Dependabot security updates: Now enabled"
                FIXED_ISSUES=$((FIXED_ISSUES + 1))
            else
                echo "  ⚠️ Failed to enable (requires admin access)"
            fi
        fi

        # ═══════════════════════════════════════════════════════════════
        # 1.2 Open Alerts
        # ═══════════════════════════════════════════════════════════════
        echo ""
        echo "───────────────────────────────────────────────────────────────"
        echo "  1.2 Open Alerts"
        echo "───────────────────────────────────────────────────────────────"

        # Dependabot alerts
        DEPENDABOT_ALERTS=$(gh api "repos/$GITHUB_REPO/dependabot/alerts?state=open" 2>/dev/null)
        DEPENDABOT_COUNT=$(echo "$DEPENDABOT_ALERTS" | jq 'length' 2>/dev/null || echo "0")

        if [[ "$DEPENDABOT_COUNT" -eq 0 ]]; then
            echo "  ✅ Dependabot: No open alerts"
        else
            echo "  ❌ Dependabot: $DEPENDABOT_COUNT open alert(s)"
            TOTAL_ISSUES=$((TOTAL_ISSUES + DEPENDABOT_COUNT))

            # Count by severity
            CRITICAL=$(echo "$DEPENDABOT_ALERTS" | jq '[.[] | select(.security_advisory.severity == "critical")] | length' 2>/dev/null || echo "0")
            HIGH=$(echo "$DEPENDABOT_ALERTS" | jq '[.[] | select(.security_advisory.severity == "high")] | length' 2>/dev/null || echo "0")
            CRITICAL_ISSUES=$((CRITICAL_ISSUES + CRITICAL + HIGH))

            echo "$DEPENDABOT_ALERTS" | jq -r '.[] | "    [\(.security_advisory.severity | ascii_upcase)] \(.dependency.package.name): \(.security_advisory.summary | .[0:60])"' 2>/dev/null | head -10

            # Check for auto-merge PRs
            echo ""
            echo "  → MITIGATING: Checking for Dependabot PRs to merge..."
            DEPENDABOT_PRS=$(gh pr list --repo "$GITHUB_REPO" --author "app/dependabot" --state open --json number,title 2>/dev/null)
            PR_COUNT=$(echo "$DEPENDABOT_PRS" | jq 'length' 2>/dev/null || echo "0")

            if [[ "$PR_COUNT" -gt 0 ]]; then
                echo "    Found $PR_COUNT Dependabot PR(s):"
                echo "$DEPENDABOT_PRS" | jq -r '.[] | "    → #\(.number): \(.title | .[0:50])"' | head -5

                # Attempt to merge (if enabled)
                if [[ "$AUDIT_ONLY" != "true" ]]; then
                    echo "    Attempting auto-merge..."
                    for pr_num in $(echo "$DEPENDABOT_PRS" | jq -r '.[].number'); do
                        if gh pr merge "$pr_num" --repo "$GITHUB_REPO" --squash --auto 2>/dev/null; then
                            echo "    ✅ PR #$pr_num queued for merge"
                            FIXED_ISSUES=$((FIXED_ISSUES + 1))
                        fi
                    done
                fi
            fi
        fi

        # Code scanning alerts
        CODE_ALERTS=$(gh api "repos/$GITHUB_REPO/code-scanning/alerts?state=open" 2>/dev/null)
        CODE_COUNT=$(echo "$CODE_ALERTS" | jq 'length' 2>/dev/null || echo "0")

        echo ""
        if [[ "$CODE_COUNT" -eq 0 ]]; then
            echo "  ✅ Code scanning: No open alerts"
        else
            echo "  ❌ Code scanning: $CODE_COUNT open alert(s)"
            TOTAL_ISSUES=$((TOTAL_ISSUES + CODE_COUNT))
            echo "$CODE_ALERTS" | jq -r '.[] | "    [\(.rule.severity // "unknown")] \(.rule.description | .[0:50]) (\(.most_recent_instance.location.path):\(.most_recent_instance.location.start_line))"' 2>/dev/null | head -10
        fi

        # Secret scanning alerts (CRITICAL)
        SECRET_ALERTS=$(gh api "repos/$GITHUB_REPO/secret-scanning/alerts?state=open" 2>/dev/null)
        SECRET_COUNT=$(echo "$SECRET_ALERTS" | jq 'length' 2>/dev/null || echo "0")

        echo ""
        if [[ "$SECRET_COUNT" -eq 0 ]]; then
            echo "  ✅ Secret scanning: No open alerts"
        else
            echo "  🚨 SECRET SCANNING: $SECRET_COUNT OPEN ALERT(S) - CRITICAL!"
            TOTAL_ISSUES=$((TOTAL_ISSUES + SECRET_COUNT))
            CRITICAL_ISSUES=$((CRITICAL_ISSUES + SECRET_COUNT))
            echo "$SECRET_ALERTS" | jq -r '.[] | "    [CRITICAL] \(.secret_type_display_name)"' 2>/dev/null | head -10
            echo ""
            echo "  ⚠️ IMMEDIATE ACTION REQUIRED: https://github.com/$GITHUB_REPO/security/secret-scanning"
        fi

        # ═══════════════════════════════════════════════════════════════
        # 1.3 Security Workflows
        # ═══════════════════════════════════════════════════════════════
        echo ""
        echo "───────────────────────────────────────────────────────────────"
        echo "  1.3 Security Workflows"
        echo "───────────────────────────────────────────────────────────────"

        WORKFLOWS=$(gh api "repos/$GITHUB_REPO/contents/.github/workflows" 2>/dev/null | jq -r '.[].name' 2>/dev/null || echo "")
        REPO_INFO=$(gh api "repos/$GITHUB_REPO" 2>/dev/null)
        PRIMARY_LANG=$(echo "$REPO_INFO" | jq -r '.language // "Unknown"')

        echo "  Primary language: $PRIMARY_LANG"

        # Check for CodeQL (required for Python/JS/TS/Go)
        if [[ "$PRIMARY_LANG" =~ ^(Python|JavaScript|TypeScript|Go)$ ]]; then
            if echo "$WORKFLOWS" | grep -qi "codeql"; then
                echo "  ✅ CodeQL workflow: Present"
            else
                echo "  ❌ CodeQL workflow: Missing (required for $PRIMARY_LANG)"
                TOTAL_ISSUES=$((TOTAL_ISSUES + 1))
                echo "  → MITIGATION: Create .github/workflows/codeql.yml"
            fi
        fi

        # Check for language-specific security
        case "$PRIMARY_LANG" in
            Python)
                if echo "$WORKFLOWS" | grep -qiE "bandit|security|safety"; then
                    echo "  ✅ Python security workflow: Present"
                else
                    echo "  ⚠️ Python security workflow: Missing (bandit/safety)"
                fi
                ;;
            Shell)
                if echo "$WORKFLOWS" | grep -qi "shellcheck"; then
                    echo "  ✅ ShellCheck workflow: Present"
                else
                    echo "  ⚠️ ShellCheck workflow: Missing"
                fi
                ;;
        esac
    fi
fi
```

---

## Section 2: Local Project Security

Tests and mitigates security issues in the local project code.

```bash
echo ""
echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║  SECTION 2: LOCAL PROJECT SECURITY                                ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"

# ═══════════════════════════════════════════════════════════════
# 2.1 Secret Detection
# ═══════════════════════════════════════════════════════════════
echo ""
echo "───────────────────────────────────────────────────────────────────"
echo "  2.1 Secret Detection"
echo "───────────────────────────────────────────────────────────────────"

SECRETS_FOUND=0

# API Keys and passwords
echo "Scanning for hardcoded secrets..."
API_KEYS=$(grep -rE "(api[_-]?key|apikey|secret[_-]?key|password|passwd)\s*[=:]\s*['\"][^'\"]{8,}['\"]" \
    --include="*.py" --include="*.js" --include="*.ts" --include="*.go" --include="*.env" \
    "$PROJECT_ROOT" 2>/dev/null | grep -v "test" | grep -v "example" | head -10)

if [[ -n "$API_KEYS" ]]; then
    echo "  ❌ Potential secrets found:"
    echo "$API_KEYS" | sed 's/^/    /'
    SECRETS_FOUND=$((SECRETS_FOUND + $(echo "$API_KEYS" | wc -l)))
fi

# AWS keys
AWS_KEYS=$(grep -rE "AKIA[0-9A-Z]{16}" "$PROJECT_ROOT" 2>/dev/null | head -5)
if [[ -n "$AWS_KEYS" ]]; then
    echo "  🚨 AWS Access Key(s) found:"
    echo "$AWS_KEYS" | sed 's/^/    /'
    SECRETS_FOUND=$((SECRETS_FOUND + $(echo "$AWS_KEYS" | wc -l)))
    CRITICAL_ISSUES=$((CRITICAL_ISSUES + 1))
fi

# Private keys
PRIVATE_KEYS=$(grep -rE "-----BEGIN (RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----" "$PROJECT_ROOT" 2>/dev/null | head -5)
if [[ -n "$PRIVATE_KEYS" ]]; then
    echo "  🚨 Private key(s) found:"
    echo "$PRIVATE_KEYS" | sed 's/^/    /' | head -5
    SECRETS_FOUND=$((SECRETS_FOUND + 1))
    CRITICAL_ISSUES=$((CRITICAL_ISSUES + 1))
fi

if [[ "$SECRETS_FOUND" -eq 0 ]]; then
    echo "  ✅ No hardcoded secrets detected"
else
    TOTAL_ISSUES=$((TOTAL_ISSUES + SECRETS_FOUND))
    echo ""
    echo "  → MITIGATION: Move secrets to environment variables or credential manager"
fi

# ═══════════════════════════════════════════════════════════════
# 2.2 Static Analysis (SAST)
# ═══════════════════════════════════════════════════════════════
echo ""
echo "───────────────────────────────────────────────────────────────────"
echo "  2.2 Static Application Security Testing (SAST)"
echo "───────────────────────────────────────────────────────────────────"

# Bandit (Python)
if command -v bandit &>/dev/null; then
    PYTHON_FILES=$(find "$PROJECT_ROOT" -name "*.py" -not -path "*/.venv/*" -not -path "*/venv/*" -not -path "*/.snapshots/*" 2>/dev/null | head -1)
    if [[ -n "$PYTHON_FILES" ]]; then
        echo ""
        echo "Running Bandit (Python security scanner)..."
        BANDIT_OUTPUT=$(bandit -r "$PROJECT_ROOT" -x ./.venv,./.snapshots,./venv --format json 2>/dev/null)

        HIGH_COUNT=$(echo "$BANDIT_OUTPUT" | jq '[.results[] | select(.severity == "HIGH")] | length' 2>/dev/null || echo "0")
        MED_COUNT=$(echo "$BANDIT_OUTPUT" | jq '[.results[] | select(.severity == "MEDIUM")] | length' 2>/dev/null || echo "0")

        if [[ "$HIGH_COUNT" -gt 0 ]]; then
            echo "  ❌ HIGH severity: $HIGH_COUNT issue(s)"
            echo "$BANDIT_OUTPUT" | jq -r '.results[] | select(.severity == "HIGH") | "    \(.issue_text) (\(.filename | split("/") | last):\(.line_number))"' 2>/dev/null | head -5
            TOTAL_ISSUES=$((TOTAL_ISSUES + HIGH_COUNT))
            CRITICAL_ISSUES=$((CRITICAL_ISSUES + HIGH_COUNT))
        fi

        if [[ "$MED_COUNT" -gt 0 ]]; then
            echo "  ⚠️ MEDIUM severity: $MED_COUNT issue(s)"
            TOTAL_ISSUES=$((TOTAL_ISSUES + MED_COUNT))
        fi

        if [[ "$HIGH_COUNT" -eq 0 ]] && [[ "$MED_COUNT" -eq 0 ]]; then
            echo "  ✅ Bandit: No high/medium issues"
        fi
    fi
fi

# ShellCheck
if command -v shellcheck &>/dev/null; then
    SHELL_FILES=$(find "$PROJECT_ROOT" -name "*.sh" -not -path "*/.snapshots/*" 2>/dev/null | head -1)
    if [[ -n "$SHELL_FILES" ]]; then
        echo ""
        echo "Running ShellCheck..."
        SHELLCHECK_ERRORS=$(find "$PROJECT_ROOT" -name "*.sh" -not -path "*/.snapshots/*" -exec shellcheck -S error {} \; 2>/dev/null | wc -l)

        if [[ "$SHELLCHECK_ERRORS" -gt 0 ]]; then
            echo "  ⚠️ ShellCheck errors: $SHELLCHECK_ERRORS"
            find "$PROJECT_ROOT" -name "*.sh" -not -path "*/.snapshots/*" -exec shellcheck -f gcc -S error {} \; 2>/dev/null | head -10
            TOTAL_ISSUES=$((TOTAL_ISSUES + 1))
        else
            echo "  ✅ ShellCheck: No errors"
        fi
    fi
fi

# ═══════════════════════════════════════════════════════════════
# 2.3 Dependency Vulnerabilities
# ═══════════════════════════════════════════════════════════════
echo ""
echo "───────────────────────────────────────────────────────────────────"
echo "  2.3 Dependency Vulnerabilities"
echo "───────────────────────────────────────────────────────────────────"

# Python pip-audit
if command -v pip-audit &>/dev/null; then
    if [[ -f "$PROJECT_ROOT/requirements.txt" ]] || [[ -f "$PROJECT_ROOT/pyproject.toml" ]]; then
        echo ""
        echo "Running pip-audit..."
        cd "$PROJECT_ROOT"
        PIP_AUDIT=$(pip-audit --progress-spinner=off 2>&1)
        VULN_COUNT=$(echo "$PIP_AUDIT" | grep -c "^Name" || echo "0")

        if echo "$PIP_AUDIT" | grep -q "No known vulnerabilities"; then
            echo "  ✅ pip-audit: No vulnerabilities"
        else
            echo "  ❌ pip-audit found vulnerabilities:"
            echo "$PIP_AUDIT" | head -20
            TOTAL_ISSUES=$((TOTAL_ISSUES + 1))

            # Auto-fix
            if [[ "$AUDIT_ONLY" != "true" ]]; then
                echo ""
                echo "  → MITIGATING: Running pip-audit --fix..."
                pip-audit --fix 2>&1 | head -10
                FIXED_ISSUES=$((FIXED_ISSUES + 1))
            fi
        fi
    fi
fi

# npm audit
if [[ -f "$PROJECT_ROOT/package.json" ]]; then
    echo ""
    echo "Running npm audit..."
    cd "$PROJECT_ROOT"
    NPM_AUDIT=$(npm audit --json 2>/dev/null)
    VULN_TOTAL=$(echo "$NPM_AUDIT" | jq '.metadata.vulnerabilities.total // 0' 2>/dev/null || echo "0")

    if [[ "$VULN_TOTAL" -eq 0 ]]; then
        echo "  ✅ npm audit: No vulnerabilities"
    else
        echo "  ❌ npm audit: $VULN_TOTAL vulnerabilities"
        echo "$NPM_AUDIT" | jq -r '.vulnerabilities | to_entries[] | "    [\(.value.severity)] \(.key)"' 2>/dev/null | head -10
        TOTAL_ISSUES=$((TOTAL_ISSUES + 1))

        # Auto-fix
        if [[ "$AUDIT_ONLY" != "true" ]]; then
            echo ""
            echo "  → MITIGATING: Running npm audit fix..."
            npm audit fix 2>&1 | tail -5
            FIXED_ISSUES=$((FIXED_ISSUES + 1))
        fi
    fi
fi

# ═══════════════════════════════════════════════════════════════
# 2.4 Hardcoded Paths Check
# ═══════════════════════════════════════════════════════════════
echo ""
echo "───────────────────────────────────────────────────────────────────"
echo "  2.4 Hardcoded Paths (Configuration)"
echo "───────────────────────────────────────────────────────────────────"

FORBIDDEN_PATHS=("/var/lib/" "/opt/" "/srv/" "/etc/")
ALLOWED_PATTERNS=("config.py" "test_" ".conf" "CLAUDE.md")

hardcoded_found=0
for forbidden in "${FORBIDDEN_PATHS[@]}"; do
    matches=$(grep -rn "$forbidden" --include="*.py" "$PROJECT_ROOT" 2>/dev/null | \
              grep -v "get_config\|environ.get" | \
              grep -vE "$(IFS=\|; echo "${ALLOWED_PATTERNS[*]}")" | head -5)
    if [[ -n "$matches" ]]; then
        if [[ "$hardcoded_found" -eq 0 ]]; then
            echo "  ⚠️ Hardcoded paths found (should use config module):"
        fi
        echo "$matches" | sed 's/^/    /'
        hardcoded_found=$((hardcoded_found + 1))
    fi
done

if [[ "$hardcoded_found" -eq 0 ]]; then
    echo "  ✅ No hardcoded paths in Python files"
else
    TOTAL_ISSUES=$((TOTAL_ISSUES + 1))
    echo ""
    echo "  → MITIGATION: Replace hardcoded paths with config module variables"
fi
```

---

## Section 3: Installed App Security

Tests security of the production-installed application.

```bash
echo ""
echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║  SECTION 3: INSTALLED APP SECURITY                                ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"

if [[ "$HAS_INSTALLED_APP" != "true" ]]; then
    echo "ℹ️ No installed app detected - skipping installed app security checks"
else
    echo "Installed app path: $INSTALLED_APP_PATH"
    echo ""

    # ═══════════════════════════════════════════════════════════════
    # 3.1 File Permissions
    # ═══════════════════════════════════════════════════════════════
    echo "───────────────────────────────────────────────────────────────────"
    echo "  3.1 File Permissions"
    echo "───────────────────────────────────────────────────────────────────"

    # Check for world-writable files
    WORLD_WRITABLE=$(find "$INSTALLED_APP_PATH" -type f -perm -002 2>/dev/null | head -10)
    if [[ -n "$WORLD_WRITABLE" ]]; then
        echo "  ❌ World-writable files found:"
        echo "$WORLD_WRITABLE" | sed 's/^/    /'
        TOTAL_ISSUES=$((TOTAL_ISSUES + 1))
        CRITICAL_ISSUES=$((CRITICAL_ISSUES + 1))

        if [[ "$AUDIT_ONLY" != "true" ]]; then
            echo "  → MITIGATING: Removing world-write permission..."
            echo "$WORLD_WRITABLE" | xargs -I {} sudo chmod o-w {} 2>/dev/null
            FIXED_ISSUES=$((FIXED_ISSUES + 1))
        fi
    else
        echo "  ✅ No world-writable files"
    fi

    # Check for sensitive files with loose permissions
    LOOSE_CONFIG=$(find "$INSTALLED_APP_PATH" -name "*.conf" -o -name "*.env" -o -name "*credentials*" 2>/dev/null | \
                   xargs -I {} stat -c "%a %n" {} 2>/dev/null | grep -vE "^[46]00" | head -5)
    if [[ -n "$LOOSE_CONFIG" ]]; then
        echo "  ⚠️ Config files with loose permissions:"
        echo "$LOOSE_CONFIG" | sed 's/^/    /'
        TOTAL_ISSUES=$((TOTAL_ISSUES + 1))
    else
        echo "  ✅ Config file permissions OK"
    fi

    # ═══════════════════════════════════════════════════════════════
    # 3.2 Config Sync Verification
    # ═══════════════════════════════════════════════════════════════
    echo ""
    echo "───────────────────────────────────────────────────────────────────"
    echo "  3.2 Config Sync Verification"
    echo "───────────────────────────────────────────────────────────────────"

    # Verify installed app uses config module (not hardcoded paths)
    if [[ -f "$INSTALLED_APP_PATH/library/config.py" ]]; then
        echo "  ✅ Config module present in installed app"

        # Check key files use config imports
        MAINTENANCE_FILE="$INSTALLED_APP_PATH/library/backend/api_modular/utilities_ops/maintenance.py"
        if [[ -f "$MAINTENANCE_FILE" ]]; then
            if grep -q "from config import" "$MAINTENANCE_FILE"; then
                echo "  ✅ maintenance.py uses config module"
            else
                echo "  ❌ maintenance.py does not import config module"
                TOTAL_ISSUES=$((TOTAL_ISSUES + 1))
            fi
        fi

        # Check rnd scripts
        for script in "$INSTALLED_APP_PATH"/rnd/populate_asins*.py; do
            if [[ -f "$script" ]]; then
                if grep -q "from config import" "$script"; then
                    echo "  ✅ $(basename "$script") uses config module"
                else
                    echo "  ❌ $(basename "$script") does not import config module"
                    TOTAL_ISSUES=$((TOTAL_ISSUES + 1))
                fi
            fi
        done
    else
        echo "  ⚠️ Config module not found in installed app"
        TOTAL_ISSUES=$((TOTAL_ISSUES + 1))
    fi

    # ═══════════════════════════════════════════════════════════════
    # 3.3 Service Security
    # ═══════════════════════════════════════════════════════════════
    echo ""
    echo "───────────────────────────────────────────────────────────────────"
    echo "  3.3 Service Security"
    echo "───────────────────────────────────────────────────────────────────"

    # Check if service runs as non-root
    SERVICE_NAME="${PROJECT_NAME:-$(basename "$PROJECT_ROOT")}"
    if systemctl is-active --quiet "$SERVICE_NAME-api" 2>/dev/null || \
       systemctl is-active --quiet "${SERVICE_NAME}s-api" 2>/dev/null; then

        SVC=$(systemctl show "$SERVICE_NAME-api" 2>/dev/null || systemctl show "${SERVICE_NAME}s-api" 2>/dev/null)
        SVC_USER=$(echo "$SVC" | grep "^User=" | cut -d= -f2)

        if [[ "$SVC_USER" == "root" ]] || [[ -z "$SVC_USER" ]]; then
            echo "  ⚠️ Service runs as root (should use dedicated user)"
            TOTAL_ISSUES=$((TOTAL_ISSUES + 1))
        else
            echo "  ✅ Service runs as user: $SVC_USER"
        fi
    fi

    # ═══════════════════════════════════════════════════════════════
    # 3.4 Database Security
    # ═══════════════════════════════════════════════════════════════
    echo ""
    echo "───────────────────────────────────────────────────────────────────"
    echo "  3.4 Database Security"
    echo "───────────────────────────────────────────────────────────────────"

    # Find database files
    DB_FILES=$(find "$INSTALLED_APP_PATH" -name "*.db" -o -name "*.sqlite" -o -name "*.sqlite3" 2>/dev/null)

    for db in $DB_FILES; do
        DB_PERMS=$(stat -c "%a" "$db" 2>/dev/null)
        DB_OWNER=$(stat -c "%U:%G" "$db" 2>/dev/null)

        echo "  Database: $db"
        echo "    Permissions: $DB_PERMS, Owner: $DB_OWNER"

        # Check permissions aren't too loose
        if [[ "$DB_PERMS" =~ ^[67][0-7][0-7]$ ]]; then
            echo "    ✅ Permissions OK"
        else
            echo "    ⚠️ Permissions may be too restrictive or too loose"
        fi
    done

    if [[ -z "$DB_FILES" ]]; then
        echo "  ℹ️ No SQLite databases found in installed app"
    fi
fi
```

---

## Summary Report

```bash
echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "  SECURITY AUDIT SUMMARY"
echo "═══════════════════════════════════════════════════════════════════"
echo ""
echo "Targets Tested:"
echo "  Local project: $PROJECT_ROOT"
echo "  GitHub repo:   ${GITHUB_REPO:-N/A}"
echo "  Installed app: ${INSTALLED_APP_PATH:-N/A}"
echo ""
echo "Results:"
echo "  Total issues found:    $TOTAL_ISSUES"
echo "  Critical issues:       $CRITICAL_ISSUES"
echo "  Issues auto-fixed:     $FIXED_ISSUES"
echo "  Issues remaining:      $((TOTAL_ISSUES - FIXED_ISSUES))"
echo ""

if [[ "$CRITICAL_ISSUES" -gt 0 ]]; then
    echo "Status: 🚨 CRITICAL - $CRITICAL_ISSUES critical issue(s) require immediate attention"
elif [[ "$TOTAL_ISSUES" -gt "$FIXED_ISSUES" ]]; then
    echo "Status: ⚠️ ISSUES - $((TOTAL_ISSUES - FIXED_ISSUES)) issue(s) require attention"
elif [[ "$TOTAL_ISSUES" -gt 0 ]]; then
    echo "Status: ✅ MITIGATED - All $TOTAL_ISSUES issue(s) auto-fixed"
else
    echo "Status: ✅ SECURE - No security issues found"
fi

echo ""
echo "═══════════════════════════════════════════════════════════════════"
```

---

## Integration Notes

This phase can be invoked:

1. **Standalone**: `/test --phase SEC`
2. **As part of full audit**: Automatically included in full `/test` run
3. **With specific targets**: `/test --phase SEC --target github`

The phase automatically:
- Enables missing GitHub security features
- Merges pending Dependabot PRs
- Runs `pip-audit --fix` and `npm audit fix`
- Fixes file permissions on installed app

Set `AUDIT_ONLY=true` to disable auto-fixing.
