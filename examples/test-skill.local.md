---
# Test-skill project configuration
# Copy this file to your project's .claude/test-skill.local.md

# Coverage threshold (default: 85)
coverage_threshold: 85

# Phases to skip (e.g., S for non-BTRFS, M if no mocking needed)
skip_phases: []

# Custom test command (overrides auto-detection)
# test_command: "make test-unit"

# Security scan strictness: strict, normal, lenient
security_level: normal

# Auto-fix settings
auto_fix:
  formatting: true
  imports: true
  lint_errors: false  # Set true to auto-fix lint issues
---

# Project-Specific Test Configuration

Add any project-specific notes or overrides here.

## Custom Phase Instructions

If your project needs special handling for certain phases, document it here.

## Known Issues

List any known test failures or issues that should be ignored.
