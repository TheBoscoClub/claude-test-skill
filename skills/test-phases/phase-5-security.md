# Phase 5: Security Audit

Scan for security vulnerabilities, exposed secrets, common attack vectors, and **GitHub security alerts**.

## Step 1: Secret Detection

```bash
echo "═══════════════════════════════════════════════════════════════════"
echo "  PHASE 5: SECURITY AUDIT"
echo "═══════════════════════════════════════════════════════════════════"

echo "Scanning for hardcoded secrets..."

# API keys and passwords
grep -rE "(api[_-]?key|apikey|secret[_-]?key|password|passwd|pwd)\s*[=:]\s*['\"][^'\"]+['\"]" \
    --include="*.py" --include="*.js" --include="*.ts" --include="*.go" . 2>/dev/null | head -10

# AWS keys
grep -rE "AKIA[0-9A-Z]{16}" . 2>/dev/null | head -5

# Private keys
grep -rE "-----BEGIN (RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----" . 2>/dev/null | head -5

# JWT tokens
grep -rE "eyJ[A-Za-z0-9_-]*\.eyJ[A-Za-z0-9_-]*\.[A-Za-z0-9_-]*" . 2>/dev/null | head -5
```

## Step 2: Dependency Vulnerability Scan (Local)

```bash
echo ""
echo "Checking local dependency vulnerabilities..."

# Python
if command -v pip-audit &>/dev/null; then
    pip-audit 2>&1 | head -20
elif command -v safety &>/dev/null; then
    safety check 2>&1 | head -20
fi

# Node.js
if [[ -f package.json ]]; then
    npm audit --json 2>/dev/null | jq '.vulnerabilities | to_entries[] | {name: .key, severity: .value.severity}' 2>/dev/null | head -20
fi

# Go
if command -v govulncheck &>/dev/null && [[ -f go.mod ]]; then
    govulncheck ./... 2>&1 | head -20
fi

# Rust
if command -v cargo-audit &>/dev/null && [[ -f Cargo.toml ]]; then
    cargo audit 2>&1 | head -20
fi
```

## Step 3: GitHub Security Alerts

**Check GitHub's automated security features for the project's repository.**

```bash
echo ""
echo "───────────────────────────────────────────────────────────────────"
echo "  Step 3: GitHub Security Alerts"
echo "───────────────────────────────────────────────────────────────────"

# Detect GitHub repo
get_github_repo() {
    local remote_url=$(git remote get-url origin 2>/dev/null)
    if [[ -z "$remote_url" ]]; then
        echo ""
        return 1
    fi

    # Extract owner/repo from various URL formats
    local repo=""
    if [[ "$remote_url" =~ github\.com[:/]([^/]+)/([^/.]+) ]]; then
        repo="${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
    fi
    echo "$repo"
}

GITHUB_REPO=$(get_github_repo)

if [[ -z "$GITHUB_REPO" ]]; then
    echo "ℹ️ No GitHub remote detected - skipping GitHub security checks"
else
    echo "Repository: $GITHUB_REPO"
    echo ""

    # Check if gh CLI is available and authenticated
    if ! command -v gh &>/dev/null; then
        echo "⚠️ GitHub CLI (gh) not installed - install with: sudo pacman -S github-cli"
    elif ! gh auth status &>/dev/null 2>&1; then
        echo "⚠️ GitHub CLI not authenticated - run: gh auth login"
    else
        echo "✅ GitHub CLI authenticated"
        echo ""

        # ═══════════════════════════════════════════════════════════════
        # DEPENDABOT ALERTS
        # ═══════════════════════════════════════════════════════════════
        echo "Checking Dependabot alerts..."
        DEPENDABOT_ALERTS=$(gh api repos/$GITHUB_REPO/dependabot/alerts --jq 'length' 2>/dev/null || echo "0")

        if [[ "$DEPENDABOT_ALERTS" == "0" ]]; then
            echo "  ✅ No Dependabot alerts"
        else
            echo "  ❌ $DEPENDABOT_ALERTS Dependabot alert(s) found!"
            echo ""

            # List alerts with details
            gh api repos/$GITHUB_REPO/dependabot/alerts \
                --jq '.[] | "  - [\(.security_advisory.severity | ascii_upcase)] \(.security_advisory.summary) (\(.dependency.package.name))"' \
                2>/dev/null | head -10

            echo ""
            echo "  View all: https://github.com/$GITHUB_REPO/security/dependabot"
        fi

        echo ""

        # ═══════════════════════════════════════════════════════════════
        # SECRET SCANNING ALERTS
        # ═══════════════════════════════════════════════════════════════
        echo "Checking secret scanning alerts..."
        SECRET_ALERTS=$(gh api repos/$GITHUB_REPO/secret-scanning/alerts --jq 'length' 2>/dev/null || echo "0")

        if [[ "$SECRET_ALERTS" == "0" ]]; then
            echo "  ✅ No secret scanning alerts"
        else
            echo "  ❌ $SECRET_ALERTS secret scanning alert(s) found!"
            echo ""

            gh api repos/$GITHUB_REPO/secret-scanning/alerts \
                --jq '.[] | "  - [\(.state)] \(.secret_type): \(.secret_type_display_name)"' \
                2>/dev/null | head -10

            echo ""
            echo "  View all: https://github.com/$GITHUB_REPO/security/secret-scanning"
        fi

        echo ""

        # ═══════════════════════════════════════════════════════════════
        # CODE SCANNING ALERTS (CodeQL, etc.)
        # ═══════════════════════════════════════════════════════════════
        echo "Checking code scanning alerts..."
        CODE_ALERTS=$(gh api repos/$GITHUB_REPO/code-scanning/alerts --jq 'length' 2>/dev/null || echo "0")

        if [[ "$CODE_ALERTS" == "0" ]]; then
            echo "  ✅ No code scanning alerts"
        else
            echo "  ❌ $CODE_ALERTS code scanning alert(s) found!"
            echo ""

            gh api repos/$GITHUB_REPO/code-scanning/alerts \
                --jq '.[] | "  - [\(.rule.severity // "unknown")] \(.rule.description) (\(.most_recent_instance.location.path):\(.most_recent_instance.location.start_line))"' \
                2>/dev/null | head -10

            echo ""
            echo "  View all: https://github.com/$GITHUB_REPO/security/code-scanning"
        fi

        echo ""

        # ═══════════════════════════════════════════════════════════════
        # CHECK SECURITY FEATURES ENABLED
        # ═══════════════════════════════════════════════════════════════
        echo "Checking security features status..."

        # Get repo security settings
        SECURITY_INFO=$(gh api repos/$GITHUB_REPO 2>/dev/null)

        if [[ -n "$SECURITY_INFO" ]]; then
            # Check Dependabot
            DEPENDABOT_ENABLED=$(gh api repos/$GITHUB_REPO/vulnerability-alerts 2>/dev/null && echo "true" || echo "false")
            if [[ "$DEPENDABOT_ENABLED" == "true" ]]; then
                echo "  ✅ Dependabot alerts: Enabled"
            else
                echo "  ⚠️ Dependabot alerts: Not enabled"
                echo "     Enable at: https://github.com/$GITHUB_REPO/settings/security_analysis"
            fi

            # Check for security policy
            if gh api repos/$GITHUB_REPO/contents/SECURITY.md &>/dev/null 2>&1; then
                echo "  ✅ Security policy: Present"
            else
                echo "  ⚠️ Security policy: Missing (consider adding SECURITY.md)"
            fi

            # Check for branch protection
            DEFAULT_BRANCH=$(echo "$SECURITY_INFO" | jq -r '.default_branch')
            if gh api repos/$GITHUB_REPO/branches/$DEFAULT_BRANCH/protection &>/dev/null 2>&1; then
                echo "  ✅ Branch protection: Enabled on $DEFAULT_BRANCH"
            else
                echo "  ⚠️ Branch protection: Not enabled on $DEFAULT_BRANCH"
            fi
        fi
    fi
fi
```

## Step 4: Code Vulnerability Patterns

```bash
echo ""
echo "───────────────────────────────────────────────────────────────────"
echo "  Step 4: Code Vulnerability Patterns"
echo "───────────────────────────────────────────────────────────────────"

echo "Scanning for common vulnerability patterns..."

# SQL Injection (Python)
grep -rn "execute.*%s\|execute.*format\|execute.*f\"" --include="*.py" . 2>/dev/null | head -5

# Command Injection
grep -rn "os\.system\|subprocess.*shell=True\|exec(\|eval(" --include="*.py" . 2>/dev/null | head -5

# XSS
grep -rn "innerHTML\|dangerouslySetInnerHTML" --include="*.js" --include="*.jsx" --include="*.tsx" . 2>/dev/null | head -5

# Insecure deserialization
grep -rn "pickle\.loads\|yaml\.load(" --include="*.py" . 2>/dev/null | head -5
```

## Step 5: Configuration Security

```bash
echo ""
echo "───────────────────────────────────────────────────────────────────"
echo "  Step 5: Configuration Security"
echo "───────────────────────────────────────────────────────────────────"

# Debug mode in production
grep -rE "(DEBUG|debug)\s*[=:]\s*(true|True|1)" --include="*.py" --include="*.json" . 2>/dev/null | head -5

# Insecure protocols
grep -rE "http://" --include="*.py" --include="*.js" . 2>/dev/null | grep -v "localhost\|127.0.0.1" | head -5

# Disabled SSL verification
grep -rE "(verify\s*=\s*False|SSL_VERIFY.*false|rejectUnauthorized.*false)" . 2>/dev/null | head -5
```

## Step 6: Collect Issues for Remediation

All security issues found should be collected for Phase 10 (Auto-Fixing).

```bash
# Create security issues file for Phase 10 to process
SECURITY_ISSUES_FILE="${PROJECT_DIR:-$(pwd)}/security-issues.json"

collect_security_issues() {
    local issues=()

    # Collect Dependabot alerts
    if [[ -n "$GITHUB_REPO" ]] && command -v gh &>/dev/null; then
        gh api repos/$GITHUB_REPO/dependabot/alerts \
            --jq '.[] | {type: "dependabot", severity: .security_advisory.severity, package: .dependency.package.name, ecosystem: .dependency.package.ecosystem, summary: .security_advisory.summary, fix_available: (.security_vulnerability.first_patched_version != null)}' \
            2>/dev/null >> "$SECURITY_ISSUES_FILE.tmp"
    fi

    # Collect npm audit issues
    if [[ -f package.json ]]; then
        npm audit --json 2>/dev/null | jq '.vulnerabilities | to_entries[] | {type: "npm", severity: .value.severity, package: .key, fix_available: (.value.fixAvailable != false)}' >> "$SECURITY_ISSUES_FILE.tmp" 2>/dev/null
    fi

    # Combine into final file
    if [[ -f "$SECURITY_ISSUES_FILE.tmp" ]]; then
        jq -s '.' "$SECURITY_ISSUES_FILE.tmp" > "$SECURITY_ISSUES_FILE" 2>/dev/null
        rm -f "$SECURITY_ISSUES_FILE.tmp"
        echo "Security issues collected to: $SECURITY_ISSUES_FILE"
    fi
}

collect_security_issues
```

---

## Remediation Instructions (for Phase 10)

When Phase 10 (Auto-Fixing) runs, it should process security issues:

### Dependabot Alerts Remediation

```bash
remediate_dependabot() {
    local GITHUB_REPO="$1"

    # Get alerts with available fixes
    gh api repos/$GITHUB_REPO/dependabot/alerts \
        --jq '.[] | select(.security_vulnerability.first_patched_version != null) | {number: .number, package: .dependency.package.name, ecosystem: .dependency.package.ecosystem, current: .dependency.package.version, fixed: .security_vulnerability.first_patched_version.identifier}' \
        2>/dev/null | while read -r alert; do

        local pkg=$(echo "$alert" | jq -r '.package')
        local ecosystem=$(echo "$alert" | jq -r '.ecosystem')
        local fixed_version=$(echo "$alert" | jq -r '.fixed')

        echo "Updating $pkg to $fixed_version..."

        case "$ecosystem" in
            pip)
                pip install "$pkg>=$fixed_version" 2>&1
                # Update requirements.txt
                sed -i "s/^${pkg}==.*/${pkg}>=${fixed_version}/" requirements.txt 2>/dev/null
                ;;
            npm)
                npm install "${pkg}@${fixed_version}" 2>&1
                ;;
            go)
                go get "${pkg}@${fixed_version}" 2>&1
                ;;
            cargo)
                cargo update -p "$pkg" 2>&1
                ;;
        esac
    done
}
```

### npm Audit Auto-Fix

```bash
remediate_npm() {
    if [[ -f package.json ]]; then
        echo "Running npm audit fix..."
        npm audit fix 2>&1

        # For breaking changes, show what would need manual update
        echo ""
        echo "Checking for breaking changes requiring manual update..."
        npm audit fix --dry-run --force 2>&1 | head -20
    fi
}
```

### Python Safety/pip-audit Auto-Fix

```bash
remediate_python() {
    if [[ -f requirements.txt ]]; then
        echo "Updating vulnerable Python packages..."

        # Get vulnerable packages
        if command -v pip-audit &>/dev/null; then
            pip-audit --fix 2>&1
        fi

        # Regenerate requirements.txt
        pip freeze > requirements.txt.new
        echo "Updated requirements saved to requirements.txt.new"
        echo "Review and rename to requirements.txt when ready"
    fi
}
```

---

## Report Format

```markdown
## Security Audit Report

### GitHub Security Status
| Feature | Status |
|---------|--------|
| Repository | [owner/repo] |
| Dependabot Alerts | X open |
| Secret Scanning | X alerts |
| Code Scanning | X alerts |
| Branch Protection | ✅/⚠️ |
| Security Policy | ✅/⚠️ |

### Dependabot Alerts
| Severity | Package | Ecosystem | Fix Available |
|----------|---------|-----------|---------------|
| CRITICAL | [pkg] | pip | ✅ |
| HIGH | [pkg] | npm | ✅ |

### Secret Scanning Alerts
| Type | State | Location |
|------|-------|----------|
| [type] | open | [file] |

### Code Scanning Alerts
| Severity | Rule | Location |
|----------|------|----------|
| [sev] | [desc] | file:line |

### Local Vulnerabilities
| Source | Package | Severity |
|--------|---------|----------|
| pip-audit | [pkg] | HIGH |
| npm audit | [pkg] | MODERATE |

### Code Vulnerability Patterns
| Type | File | Line | Risk |
|------|------|------|------|
| SQL Injection | db.py | 45 | HIGH |

### Secrets Detected
| Type | File | Line | Severity |
|------|------|------|----------|
| API Key | config.py | 23 | CRITICAL |

### Security Score: [0-100]

### Remediation Summary
- Auto-fixable: X issues
- Manual required: Y issues
- See: security-issues.json

**Status**: ✅ SECURE / ⚠️ ISSUES / ❌ CRITICAL
```

---

## Integration with Phase 10

Phase 10 (Auto-Fixing) should:

1. Read `security-issues.json` if it exists
2. For each issue with `fix_available: true`:
   - Apply the appropriate remediation command
   - Verify the fix worked
   - Update the issues file
3. For issues requiring manual intervention:
   - Document clearly in the final report
   - Provide specific remediation steps

```bash
# Phase 10 should include:
if [[ -f security-issues.json ]]; then
    echo "Processing security issues from Phase 5..."

    # Count fixable vs manual
    FIXABLE=$(jq '[.[] | select(.fix_available == true)] | length' security-issues.json)
    MANUAL=$(jq '[.[] | select(.fix_available != true)] | length' security-issues.json)

    echo "Auto-fixable: $FIXABLE"
    echo "Manual required: $MANUAL"

    # Process fixable issues
    # ... remediation code ...
fi
```
