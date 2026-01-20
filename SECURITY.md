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

## Security Measures

This project has the following security measures enabled:

- **Dependabot vulnerability alerts** - Monitors dependencies for known vulnerabilities
- **Dependabot security updates** - Automatically creates PRs to fix vulnerable dependencies
- **Secret scanning** - Detects accidentally committed secrets

## Scope

This project contains Claude Code skill definitions (Markdown files) and shell scripts. The security scope includes:

- Shell script injection vulnerabilities
- Exposed secrets or credentials in configuration
- Unsafe file operations in scripts
