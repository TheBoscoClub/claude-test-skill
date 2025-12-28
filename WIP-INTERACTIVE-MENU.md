# WIP: Interactive Menu for /test

**Status**: In progress - session paused 2025-12-27 18:15

## Where We Left Off

Demonstrating options for making `/test` a cursor-navigable interactive menu.

### Available Tools on System

| Tool | Status | Notes |
|------|--------|-------|
| fzf 0.67.0 | ✅ Installed | Multi-select, fuzzy search, fast |
| whiptail | ✅ Installed | Classic ncurses dialog boxes |
| gum | ❌ Not installed | Modern Charm-style TUI (optional) |

### Next Steps

1. **Demo fzf menu** in real terminal (Ghostty)
   - Cursor up/down navigation
   - TAB to toggle selection
   - ENTER to confirm
   - ESC to cancel

2. **Demo whiptail menu** (alternative)
   - Checklist-style selection
   - Arrow keys + SPACE to toggle
   - TAB to move between buttons

3. **Choose preferred style**

4. **Implement chosen style** into `/test` skill

### Proposed fzf Implementation

```bash
# In test.md, when run without arguments:
PHASES=$(cat << 'EOF'
S|BTRFS Snapshot|Safety backup before modifications
M|Safe Mocking|Sandbox dangerous commands
0|Pre-Flight|Environment validation
1|Discovery|Find testable components
2|Execute|Run tests
2a|Runtime|Service health checks
3|Report|Test results
A|App Testing|Deployable application testing ★
4|Cleanup|Deprecation, dead code
5|Security|Vulnerability scan ★
6|Dependencies|Package health
7|Quality|Linting, complexity
8|Coverage|85% minimum enforcement
9|Debug|Failure analysis
10|Fix|Auto-fixing
11|Config|Configuration audit
12|Verify|Final verification
13|Docs|Documentation review
C|Cleanup|Restore environment
EOF
)

SELECTED=$(echo "$PHASES" | column -t -s'|' | \
    fzf --multi \
        --header="Select phases (TAB=toggle, ENTER=run, ESC=cancel)" \
        --prompt="▶ " \
        --pointer="→" \
        --marker="✓" \
        --height=22 \
        --border=rounded \
        --color="header:bold,pointer:green,marker:green")
```

### Controls to Support

- ↑↓ Arrow keys: Navigate
- TAB: Toggle selection
- SPACE: Alternative toggle (if possible)
- ENTER: Confirm and run selected phases
- ESC: Cancel/exit
- Ctrl+A: Select all (if possible)

---

**Resume**: User switching to Ghostty terminal for live TUI demos.
