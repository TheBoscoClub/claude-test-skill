# Phase 5: Comprehensive Security Testing & Mitigation

> **Model**: `opus` | **Tier**: 3 (Analysis) | **Modifies Files**: No (read-only)
> **Task Tracking**: Call `TaskUpdate(taskId, status="in_progress")` at start, `TaskUpdate(taskId, status="completed")` when done.
> **Key Tools**: `Bash` for security scanners, `WebSearch` to look up CVE details and check for known exploits for flagged vulnerabilities. Use `AskUserQuestion` in `--interactive` mode for security remediation decisions (e.g., breaking change vs. patching). Parallelize with other Tier 3 phases.

**THE security phase** - tests and mitigates all security issues across:
- **GitHub** - Repository security settings, alerts, workflows
- **Local Project** - Code vulnerabilities, secrets, dependencies, SAST
- **Installed App** - Production security verification (when applicable)

## Invocation

```bash
# Run as part of full audit
/test                        # Phase 5 runs in Tier 3

# Run standalone (comprehensive security only)
/test --phase=5
/test --phase=SEC            # Alias for Phase 5

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
PROJECT_ROOT="${PROJECT_DIR:-\$(pwd)}"
PROJECT_NAME="${PROJECT_NAME:-\$(basename "\$PROJECT_ROOT")}"

# Check for GitHub remote
if git remote get-url origin 2>/dev/null | grep -q "github.com"; then
    HAS_GITHUB_REMOTE=true
    REMOTE_URL=\$(git remote get-url origin 2>/dev/null)
    if [[ "\$REMOTE_URL" =~ github\.com[:/]([^/]+)/([^/.]+) ]]; then
        GITHUB_REPO="\${BASH_REMATCH[1]}/\${BASH_REMATCH[2]}"
    fi
fi

# Check for installed app (common locations)
INSTALLED_PATHS=(
    "/opt/\${PROJECT_NAME}"
    "/opt/\${PROJECT_NAME}s"
    "/usr/local/\${PROJECT_NAME}"
    "/srv/\${PROJECT_NAME}"
)

for path in "\${INSTALLED_PATHS[@]}"; do
    if [[ -d "\$path" ]]; then
        HAS_INSTALLED_APP=true
        INSTALLED_APP_PATH="\$path"
        break
    fi
done

echo "Testing targets:"
echo "  Local project: \$PROJECT_ROOT"
echo "  GitHub repo:   \${GITHUB_REPO:-none}"
echo "  Installed app: \${INSTALLED_APP_PATH:-none}"
echo ""

# Initialize counters
TOTAL_ISSUES=0
FIXED_ISSUES=0
CRITICAL_ISSUES=0

# Detect primary language
PRIMARY_LANG="Unknown"
if [[ -n "\$(find "\$PROJECT_ROOT" -maxdepth 3 -name '*.py' -not -path '*/.venv/*' -not -path '*/.snapshots/*' 2>/dev/null | head -1)" ]]; then
    PRIMARY_LANG="Python"
elif [[ -f "\$PROJECT_ROOT/package.json" ]]; then
    PRIMARY_LANG="JavaScript"
elif [[ -f "\$PROJECT_ROOT/go.mod" ]]; then
    PRIMARY_LANG="Go"
fi
echo "Primary language: \$PRIMARY_LANG"
```

---

## Section 1: GitHub Security

Tests and mitigates GitHub repository security settings and alerts.

```bash
echo ""
echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║  SECTION 1: GITHUB SECURITY                                       ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"

if [[ "\$HAS_GITHUB_REMOTE" != "true" ]]; then
    echo "ℹ️ No GitHub remote - skipping GitHub security checks"
else
    if ! command -v gh &>/dev/null; then
        echo "⚠️ GitHub CLI (gh) not installed"
    elif ! gh auth status &>/dev/null 2>&1; then
        echo "⚠️ GitHub CLI not authenticated - run: gh auth login"
    else
        echo "Repository: https://github.com/\$GITHUB_REPO"
        echo ""

        # 1.1 Security Features (Auto-Enable)
        echo "───────────────────────────────────────────────────────────────"
        echo "  1.1 Security Features"
        echo "───────────────────────────────────────────────────────────────"

        # Dependabot alerts
        if gh api "repos/\$GITHUB_REPO/vulnerability-alerts" &>/dev/null 2>&1; then
            echo "  ✅ Dependabot alerts: Enabled"
        else
            echo "  ❌ Dependabot alerts: Not enabled"
            TOTAL_ISSUES=\$((TOTAL_ISSUES + 1))
            if [[ "\$AUDIT_ONLY" != "true" ]]; then
                gh api -X PUT "repos/\$GITHUB_REPO/vulnerability-alerts" &>/dev/null && echo "  ✅ Now enabled" && FIXED_ISSUES=\$((FIXED_ISSUES + 1))
            fi
        fi

        # Dependabot security updates
        if gh api "repos/\$GITHUB_REPO/automated-security-fixes" &>/dev/null 2>&1; then
            echo "  ✅ Dependabot security updates: Enabled"
        else
            echo "  ❌ Dependabot security updates: Not enabled"
            TOTAL_ISSUES=\$((TOTAL_ISSUES + 1))
            if [[ "\$AUDIT_ONLY" != "true" ]]; then
                gh api -X PUT "repos/\$GITHUB_REPO/automated-security-fixes" &>/dev/null && echo "  ✅ Now enabled" && FIXED_ISSUES=\$((FIXED_ISSUES + 1))
            fi
        fi

        # 1.2 Open Alerts
        echo ""
        echo "───────────────────────────────────────────────────────────────"
        echo "  1.2 Open Alerts"
        echo "───────────────────────────────────────────────────────────────"

        # Dependabot alerts
        DEPENDABOT_COUNT=\$(gh api "repos/\$GITHUB_REPO/dependabot/alerts?state=open" 2>/dev/null | jq 'length' || echo "0")
        if [[ "\$DEPENDABOT_COUNT" -eq 0 ]]; then
            echo "  ✅ Dependabot: No open alerts"
        else
            echo "  ❌ Dependabot: \$DEPENDABOT_COUNT open alert(s)"
            TOTAL_ISSUES=\$((TOTAL_ISSUES + DEPENDABOT_COUNT))
        fi

        # Code scanning alerts
        CODE_COUNT=\$(gh api "repos/\$GITHUB_REPO/code-scanning/alerts?state=open" 2>/dev/null | jq 'length' || echo "0")
        if [[ "\$CODE_COUNT" -eq 0 ]]; then
            echo "  ✅ Code scanning: No open alerts"
        else
            echo "  ❌ Code scanning: \$CODE_COUNT open alert(s)"
            TOTAL_ISSUES=\$((TOTAL_ISSUES + CODE_COUNT))
        fi

        # Secret scanning alerts
        SECRET_COUNT=\$(gh api "repos/\$GITHUB_REPO/secret-scanning/alerts?state=open" 2>/dev/null | jq 'length' || echo "0")
        if [[ "\$SECRET_COUNT" -eq 0 ]]; then
            echo "  ✅ Secret scanning: No open alerts"
        else
            echo "  🚨 SECRET SCANNING: \$SECRET_COUNT ALERT(S) - CRITICAL!"
            TOTAL_ISSUES=\$((TOTAL_ISSUES + SECRET_COUNT))
            CRITICAL_ISSUES=\$((CRITICAL_ISSUES + SECRET_COUNT))
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
# AWS keys
AWS_KEYS=\$(grep -rE "AKIA[0-9A-Z]{16}" "\$PROJECT_ROOT" 2>/dev/null | grep -v ".snapshots" | head -5)
if [[ -n "\$AWS_KEYS" ]]; then
    echo "  🚨 AWS Access Key(s) found!"
    SECRETS_FOUND=\$((SECRETS_FOUND + 1))
    CRITICAL_ISSUES=\$((CRITICAL_ISSUES + 1))
fi

# Private keys
PRIVATE_KEYS=\$(grep -rE "-----BEGIN.*PRIVATE KEY-----" "\$PROJECT_ROOT" 2>/dev/null | grep -v ".snapshots" | head -5)
if [[ -n "\$PRIVATE_KEYS" ]]; then
    echo "  🚨 Private key(s) found!"
    SECRETS_FOUND=\$((SECRETS_FOUND + 1))
    CRITICAL_ISSUES=\$((CRITICAL_ISSUES + 1))
fi

[[ "\$SECRETS_FOUND" -eq 0 ]] && echo "  ✅ No hardcoded secrets detected"
TOTAL_ISSUES=\$((TOTAL_ISSUES + SECRETS_FOUND))

# 2.2 SAST
echo ""
echo "───────────────────────────────────────────────────────────────────"
echo "  2.2 Static Application Security Testing (SAST)"
echo "───────────────────────────────────────────────────────────────────"

# Bandit (Python)
if command -v bandit &>/dev/null && [[ "\$PRIMARY_LANG" == "Python" ]]; then
    echo "Running Bandit..."
    BANDIT_HIGH=\$(bandit -r "\$PROJECT_ROOT" -x ./.venv,./.snapshots,./venv --format json 2>/dev/null | jq '[.results[] | select(.severity == "HIGH")] | length' || echo "0")
    if [[ "\$BANDIT_HIGH" -gt 0 ]]; then
        echo "  ❌ Bandit HIGH severity: \$BANDIT_HIGH"
        TOTAL_ISSUES=\$((TOTAL_ISSUES + BANDIT_HIGH))
        CRITICAL_ISSUES=\$((CRITICAL_ISSUES + BANDIT_HIGH))
    else
        echo "  ✅ Bandit: No high severity issues"
    fi
fi

# Semgrep
if command -v semgrep &>/dev/null; then
    echo "Running Semgrep..."
    SEMGREP_COUNT=\$(semgrep scan --config auto --json "\$PROJECT_ROOT" 2>/dev/null | jq '.results | length' || echo "0")
    if [[ "\$SEMGREP_COUNT" -gt 0 ]]; then
        echo "  ❌ Semgrep found \$SEMGREP_COUNT issue(s)"
        TOTAL_ISSUES=\$((TOTAL_ISSUES + SEMGREP_COUNT))
    else
        echo "  ✅ Semgrep: No issues"
    fi
fi

# ShellCheck
if command -v shellcheck &>/dev/null; then
    SHELL_FILES=\$(find "\$PROJECT_ROOT" -name "*.sh" -not -path "*/.snapshots/*" 2>/dev/null | head -1)
    if [[ -n "\$SHELL_FILES" ]]; then
        echo "Running ShellCheck..."
        SHELLCHECK_ERRORS=\$(find "\$PROJECT_ROOT" -name "*.sh" -not -path "*/.snapshots/*" -exec shellcheck -S error {} \; 2>/dev/null | wc -l)
        if [[ "\$SHELLCHECK_ERRORS" -gt 0 ]]; then
            echo "  ⚠️ ShellCheck errors: \$SHELLCHECK_ERRORS"
            TOTAL_ISSUES=\$((TOTAL_ISSUES + 1))
        else
            echo "  ✅ ShellCheck: No errors"
        fi
    fi
fi

# CodeQL (Local)
if command -v codeql &>/dev/null && [[ "\$PRIMARY_LANG" == "Python" ]]; then
    echo "Running CodeQL local analysis..."
    CODEQL_DB="/tmp/codeql-audit-\$\$"
    if codeql database create "\$CODEQL_DB" --language=python --source-root="\$PROJECT_ROOT" 2>/dev/null; then
        codeql database analyze "\$CODEQL_DB" --format=sarif-latest --output="/tmp/codeql-\$\$.sarif" \
            "codeql/python-queries:codeql-suites/python-security-extended.qls" 2>/dev/null
        CODEQL_ISSUES=\$(jq '.runs[0].results | length' "/tmp/codeql-\$\$.sarif" 2>/dev/null || echo "0")
        if [[ "\$CODEQL_ISSUES" -gt 0 ]]; then
            echo "  ❌ CodeQL found \$CODEQL_ISSUES issues"
            TOTAL_ISSUES=\$((TOTAL_ISSUES + CODEQL_ISSUES))
        else
            echo "  ✅ CodeQL: No issues"
        fi
        rm -rf "\$CODEQL_DB" "/tmp/codeql-\$\$.sarif"
    fi
fi

# 2.3 Dependency Vulnerabilities
echo ""
echo "───────────────────────────────────────────────────────────────────"
echo "  2.3 Dependency Vulnerabilities"
echo "───────────────────────────────────────────────────────────────────"

# pip-audit
if command -v pip-audit &>/dev/null && [[ -f "\$PROJECT_ROOT/requirements.txt" ]]; then
    echo "Running pip-audit..."
    if pip-audit --progress-spinner=off 2>&1 | grep -q "No known vulnerabilities"; then
        echo "  ✅ pip-audit: No vulnerabilities"
    else
        echo "  ❌ pip-audit found vulnerabilities"
        TOTAL_ISSUES=\$((TOTAL_ISSUES + 1))
        [[ "\$AUDIT_ONLY" != "true" ]] && pip-audit --fix 2>&1 | head -5 && FIXED_ISSUES=\$((FIXED_ISSUES + 1))
    fi
fi

# Trivy
if command -v trivy &>/dev/null; then
    echo "Running Trivy filesystem scan..."
    TRIVY_VULNS=\$(trivy fs --security-checks vuln,secret --format json "\$PROJECT_ROOT" 2>/dev/null | jq '[.Results[]?.Vulnerabilities // [] | .[]] | length' || echo "0")
    if [[ "\$TRIVY_VULNS" -gt 0 ]]; then
        echo "  ❌ Trivy found \$TRIVY_VULNS vulnerabilities"
        TOTAL_ISSUES=\$((TOTAL_ISSUES + TRIVY_VULNS))
    else
        echo "  ✅ Trivy: No vulnerabilities"
    fi
fi

# Grype
if command -v grype &>/dev/null; then
    echo "Running Grype vulnerability scan..."
    GRYPE_COUNT=\$(grype dir:"\$PROJECT_ROOT" --output json 2>/dev/null | jq '.matches | length' || echo "0")
    if [[ "\$GRYPE_COUNT" -gt 0 ]]; then
        echo "  ❌ Grype found \$GRYPE_COUNT issues"
        TOTAL_ISSUES=\$((TOTAL_ISSUES + GRYPE_COUNT))
    else
        echo "  ✅ Grype: No vulnerabilities"
    fi
fi

# npm audit
if [[ -f "\$PROJECT_ROOT/package.json" ]]; then
    echo "Running npm audit..."
    VULN_TOTAL=\$(npm audit --json 2>/dev/null | jq '.metadata.vulnerabilities.total // 0' || echo "0")
    if [[ "\$VULN_TOTAL" -eq 0 ]]; then
        echo "  ✅ npm audit: No vulnerabilities"
    else
        echo "  ❌ npm audit: \$VULN_TOTAL vulnerabilities"
        TOTAL_ISSUES=\$((TOTAL_ISSUES + 1))
        [[ "\$AUDIT_ONLY" != "true" ]] && npm audit fix 2>&1 | tail -3 && FIXED_ISSUES=\$((FIXED_ISSUES + 1))
    fi
fi

# 2.4 Code Vulnerability Patterns
echo ""
echo "───────────────────────────────────────────────────────────────────"
echo "  2.4 Code Vulnerability Patterns"
echo "───────────────────────────────────────────────────────────────────"

PATTERN_ISSUES=0

# SQL Injection
if grep -rqn "execute.*format\|execute.*f\"" --include="*.py" "\$PROJECT_ROOT" 2>/dev/null; then
    echo "  ⚠️ Potential SQL injection patterns found"
    PATTERN_ISSUES=\$((PATTERN_ISSUES + 1))
fi

# Command Injection
if grep -rqn "subprocess.*shell=True" --include="*.py" "\$PROJECT_ROOT" 2>/dev/null | grep -v test; then
    echo "  ⚠️ Potential command injection (shell=True)"
    PATTERN_ISSUES=\$((PATTERN_ISSUES + 1))
fi

# XSS (innerHTML/dangerouslySetInnerHTML)
if grep -rqn "innerHTML" --include="*.js" --include="*.jsx" --include="*.tsx" "\$PROJECT_ROOT" 2>/dev/null; then
    echo "  ⚠️ Potential XSS (innerHTML usage)"
    PATTERN_ISSUES=\$((PATTERN_ISSUES + 1))
fi

[[ "\$PATTERN_ISSUES" -eq 0 ]] && echo "  ✅ No obvious vulnerability patterns"
TOTAL_ISSUES=\$((TOTAL_ISSUES + PATTERN_ISSUES))

# 2.5 IaC Security (Checkov)
if command -v checkov &>/dev/null; then
    IAC_FILES=\$(find "\$PROJECT_ROOT" -name "*.tf" -o -name "Dockerfile" -o -name "docker-compose*.yml" 2>/dev/null | head -1)
    if [[ -n "\$IAC_FILES" ]]; then
        echo ""
        echo "───────────────────────────────────────────────────────────────────"
        echo "  2.5 Infrastructure as Code Security (Checkov)"
        echo "───────────────────────────────────────────────────────────────────"
        CHECKOV_FAILED=\$(checkov -d "\$PROJECT_ROOT" --quiet --compact --output json 2>/dev/null | jq '[.results.failed_checks // []] | length' || echo "0")
        if [[ "\$CHECKOV_FAILED" -gt 0 ]]; then
            echo "  ❌ Checkov found \$CHECKOV_FAILED IaC issues"
            TOTAL_ISSUES=\$((TOTAL_ISSUES + CHECKOV_FAILED))
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

if [[ "\$HAS_INSTALLED_APP" != "true" ]]; then
    echo "ℹ️ No installed app detected - skipping"
else
    echo "Installed app path: \$INSTALLED_APP_PATH"

    # 3.1 File Permissions
    echo ""
    echo "───────────────────────────────────────────────────────────────────"
    echo "  3.1 File Permissions"
    echo "───────────────────────────────────────────────────────────────────"

    WORLD_WRITABLE=\$(find "\$INSTALLED_APP_PATH" -type f -perm -002 2>/dev/null | head -10)
    if [[ -n "\$WORLD_WRITABLE" ]]; then
        echo "  ❌ World-writable files found"
        TOTAL_ISSUES=\$((TOTAL_ISSUES + 1))
        CRITICAL_ISSUES=\$((CRITICAL_ISSUES + 1))
        [[ "\$AUDIT_ONLY" != "true" ]] && echo "\$WORLD_WRITABLE" | xargs -I {} sudo chmod o-w {} 2>/dev/null && FIXED_ISSUES=\$((FIXED_ISSUES + 1))
    else
        echo "  ✅ No world-writable files"
    fi

    # 3.2 Service Security
    echo ""
    echo "───────────────────────────────────────────────────────────────────"
    echo "  3.2 Service Security"
    echo "───────────────────────────────────────────────────────────────────"

    for svc in "\${PROJECT_NAME}-api" "\${PROJECT_NAME}s-api"; do
        if systemctl is-active --quiet "\$svc" 2>/dev/null; then
            SVC_USER=\$(systemctl show "\$svc" --property=User --value 2>/dev/null)
            if [[ "\$SVC_USER" == "root" ]] || [[ -z "\$SVC_USER" ]]; then
                echo "  ⚠️ Service runs as root"
                TOTAL_ISSUES=\$((TOTAL_ISSUES + 1))
            else
                echo "  ✅ Service runs as: \$SVC_USER"
            fi
            break
        fi
    done

    # 3.3 Database Security
    echo ""
    echo "───────────────────────────────────────────────────────────────────"
    echo "  3.3 Database Security"
    echo "───────────────────────────────────────────────────────────────────"

    DB_FILES=\$(find "\$INSTALLED_APP_PATH" -name "*.db" -o -name "*.sqlite*" 2>/dev/null)
    if [[ -n "\$DB_FILES" ]]; then
        for db in \$DB_FILES; do
            DB_PERMS=\$(stat -c "%a" "\$db" 2>/dev/null)
            echo "  Database: \$(basename "\$db") - Permissions: \$DB_PERMS"
        done
    else
        echo "  ℹ️ No SQLite databases found"
    fi
fi
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
command -v shellcheck &>/dev/null && echo "  ✅ shellcheck"
command -v codeql &>/dev/null && echo "  ✅ codeql"
command -v trivy &>/dev/null && echo "  ✅ trivy"
command -v grype &>/dev/null && echo "  ✅ grype"
command -v pip-audit &>/dev/null && echo "  ✅ pip-audit"
command -v checkov &>/dev/null && echo "  ✅ checkov"
echo ""
echo "Results:"
echo "  Total issues found:    \$TOTAL_ISSUES"
echo "  Critical issues:       \$CRITICAL_ISSUES"
echo "  Issues auto-fixed:     \$FIXED_ISSUES"
echo "  Issues remaining:      \$((TOTAL_ISSUES - FIXED_ISSUES))"
echo ""

if [[ "\$CRITICAL_ISSUES" -gt 0 ]]; then
    echo "Status: 🚨 CRITICAL - \$CRITICAL_ISSUES critical issue(s)"
elif [[ "\$TOTAL_ISSUES" -gt "\$FIXED_ISSUES" ]]; then
    echo "Status: ⚠️ ISSUES - \$((TOTAL_ISSUES - FIXED_ISSUES)) issue(s) need attention"
elif [[ "\$TOTAL_ISSUES" -gt 0 ]]; then
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
- `/test` - Phase 5 runs in Tier 3
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
| shellcheck | `pacman -S shellcheck` |
| codeql | `yay -S codeql` |
| trivy | `pacman -S trivy` |
| grype | `yay -S grype-bin` |
| pip-audit | `pipx install pip-audit` |
| checkov | `pipx install checkov` |
