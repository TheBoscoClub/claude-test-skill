#!/bin/bash
# Interactive launcher for /test skill
# Install: ln -s /hddRaid1/ClaudeCodeProjects/test-skill/test-menu.sh ~/.local/bin/tm

# High-contrast dark theme for whiptail
export NEWT_COLORS='
root=white,black
window=white,black
border=cyan,black
shadow=black,black
title=cyan,black
button=black,cyan
actbutton=black,green
compactbutton=white,black
checkbox=white,black
actcheckbox=black,cyan
entry=white,black
disentry=gray,black
label=white,black
listbox=white,black
actlistbox=black,cyan
sellistbox=cyan,black
actsellistbox=black,green
textbox=white,black
acttextbox=black,cyan
helpline=cyan,black
roottext=cyan,black
emptyscale=black
fullscale=cyan
'

SELECTED=$(whiptail --title "/test Phase Selection" \
    --checklist "↑↓ navigate  |  SPACE toggle  |  TAB to buttons  |  ENTER confirm" \
    28 76 20 \
    "S"  "BTRFS Snapshot - Safety backup before modifications" OFF \
    "M"  "Safe Mocking - Sandbox dangerous commands" OFF \
    "0"  "Pre-Flight - Environment validation" ON \
    "1"  "Discovery - Find testable components" ON \
    "2"  "Execute - Run tests" ON \
    "2a" "Runtime - Service health checks" OFF \
    "3"  "Report - Test results" ON \
    "A"  "App Testing - Deployable application testing" OFF \
    "4"  "Cleanup - Deprecation, dead code" OFF \
    "5"  "Security - Vulnerability scan" OFF \
    "6"  "Dependencies - Package health" OFF \
    "7"  "Quality - Linting, complexity" OFF \
    "8"  "Coverage - 85% minimum enforcement" OFF \
    "9"  "Debug - Failure analysis" OFF \
    "10" "Fix - Auto-fixing" OFF \
    "11" "Config - Configuration audit" OFF \
    "12" "Verify - Final verification" OFF \
    "13" "Docs - Documentation review" OFF \
    "C"  "Cleanup - Restore environment" OFF \
    3>&1 1>&2 2>&3)

EXIT_STATUS=$?

if [ $EXIT_STATUS -ne 0 ] || [ -z "$SELECTED" ]; then
    echo "Cancelled."
    exit 0
fi

# Clean up quotes from whiptail output: "0" "1" "2" -> 0 1 2
PHASES=$(echo "$SELECTED" | tr -d '"')

echo ""
echo "Launching: claude \"/test $PHASES\""
echo ""

claude "/test $PHASES"
