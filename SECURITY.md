# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| latest  | :white_check_mark: |

## Reporting a Vulnerability

If you discover a security vulnerability in this project, please report it responsibly:

1. **Do not** open a public GitHub issue for security vulnerabilities
2. Email the maintainer directly or use GitHub's private vulnerability reporting feature
3. Include:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)

## GitHub Security Features

| Feature | Status |
|---------|--------|
| Dependabot vulnerability alerts | ✅ Enabled |
| Dependabot security updates | ✅ Enabled |
| Secret scanning | ✅ Enabled |

## Security Audit Tools

This project uses the following tools for security auditing:

### Shell Scripts (12 files)

| Tool | Purpose | Command |
|------|---------|---------|
| **shfmt** | Shell script formatting | `shfmt -d skills/test-phases/*.sh` |

### Markdown Documentation (157 files)

| Tool | Purpose | Command |
|------|---------|---------|
| **markdownlint** | Markdown linting | `markdownlint '**/*.md'` |
| **codespell** | Spell checking | `codespell --skip='.git'` |

### Running a Full Security Audit

```bash
# Markdown linting
markdownlint '**/*.md' --ignore node_modules

# Spell check
codespell --skip='.git,.snapshots'

# Check for secrets (manual review)
grep -rE "(password|secret|api[_-]?key|token)" --include="*.sh" --include="*.md" .
```

## Scope

This project contains Claude Code skill definitions (Markdown files) and shell scripts. Security concerns include:

- Shell script security vulnerabilities
- Exposed secrets or credentials in configuration
- Unsafe file operations in scripts
- Command injection in user-provided arguments
