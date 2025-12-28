#!/bin/bash
# Demo: fzf interactive phase selector for /test skill

PHASES="S|Snapshot|BTRFS safety backup before modifications
M|Mocking|Safe sandbox for dangerous commands
0|Pre-Flight|Environment validation
1|Discovery|Find testable components
2|Execute|Run tests
2a|Runtime|Service health checks
3|Report|Test results summary
A|App Testing|Deployable application testing ★
4|Cleanup|Deprecation, dead code removal
5|Security|Vulnerability scan ★
6|Dependencies|Package health check
7|Quality|Linting, complexity analysis
8|Coverage|85% minimum enforcement
9|Debug|Failure analysis
10|Fix|Auto-fixing issues
11|Config|Configuration audit
12|Verify|Final verification
13|Docs|Documentation review
C|Cleanup|Restore environment"

SELECTED=$(echo "$PHASES" | column -t -s'|' | fzf --multi \
    --layout=reverse \
    --header="Select phases (TAB=toggle, ENTER=confirm, ESC=cancel)" \
    --prompt="▶ " \
    --pointer="→" \
    --marker="✓" \
    --height=24 \
    --border=rounded \
    --color="fg:#ffffff,bg:#000000,hl:#00ffff:bold" \
    --color="fg+:#000000,bg+:#00ffff,hl+:#ff00ff:bold" \
    --color="info:#00ff00,prompt:#ffff00:bold,pointer:#ff00ff:bold" \
    --color="marker:#00ff00:bold,spinner:#ff00ff,header:#00ffff:bold" \
    --color="border:#00ffff" \
    --bind="ctrl-a:toggle-all")

if [[ -n "$SELECTED" ]]; then
    echo ""
    echo "Selected phases:"
    echo "$SELECTED"
else
    echo "Cancelled"
fi
