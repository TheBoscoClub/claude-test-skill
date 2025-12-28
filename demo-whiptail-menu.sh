#!/bin/bash
# Demo: whiptail checklist menu for /test phase selection

SELECTED=$(whiptail --title "/test Phase Selection" \
    --checklist "Use ARROW keys to navigate, SPACE to toggle, TAB to move to buttons" \
    22 70 14 \
    "S"  "BTRFS Snapshot - Safety backup" OFF \
    "M"  "Safe Mocking - Sandbox dangerous commands" OFF \
    "0"  "Pre-Flight - Environment validation" ON \
    "1"  "Discovery - Find testable components" ON \
    "2"  "Execute - Run tests" ON \
    "2a" "Runtime - Service health checks" OFF \
    "3"  "Report - Test results" ON \
    "A"  "App Testing - Deployable apps ★" OFF \
    "4"  "Cleanup - Deprecation, dead code" OFF \
    "5"  "Security - Vulnerability scan ★" OFF \
    "6"  "Dependencies - Package health" OFF \
    "7"  "Quality - Linting, complexity" OFF \
    "8"  "Coverage - 85% minimum" OFF \
    "9"  "Debug - Failure analysis" OFF \
    3>&1 1>&2 2>&3)

EXIT_STATUS=$?

if [ $EXIT_STATUS -eq 0 ]; then
    echo ""
    echo "Selected phases: $SELECTED"
else
    echo ""
    echo "Cancelled."
fi
