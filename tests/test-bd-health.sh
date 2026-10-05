#!/bin/bash
# Regression guard for phase-9d Step 8 (bd health check).
#
# WHY (claude-test-skill-pqy)
# Step 8 used to run `bd preflight` and grep its output for "orphan". On
# bd 1.0.3 that command prints a PR checklist for bd's OWN Go repository
# (go test, golangci-lint, Nix hash) and exits 0, so the grep counted zero
# orphans whatever the issue graph held. The step could never fire.
#
# The helpers and Step 8 are extracted from the skill document, so this
# exercises shipping code rather than a copy that can drift. Each case runs
# Step 8 inside a throwaway git + bd repository.
#
# Run: tests/test-bd-health.sh   (needs bd, git, jq)

set -uo pipefail
cd "$(dirname "$0")/.." || exit 2
SKILL="$PWD/skills/test-phases/phase-9d-github.md"
[[ -r $SKILL ]] || {
    echo "FAIL: cannot read $SKILL" >&2
    exit 2
}
for t in bd git jq; do
    command -v "$t" >/dev/null || {
        echo "FAIL: $t not on PATH" >&2
        exit 2
    }
done

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
STEP="$WORK/step8.sh"
python3 - "$SKILL" "$STEP" <<'PY' || exit 2
import sys
s = open(sys.argv[1]).read()
try:
    a = s.index('gh_json() {')
    b = s.index('# ' + '-' * 75, a)
    c = s.index('## Step 8: bd Health Check')
    c = s.index('```bash\n', c) + len('```bash\n')
    d = s.index('\n```', c)
except ValueError:
    sys.exit("FAIL: helpers or Step 8 not found in the skill document")
open(sys.argv[2], 'w').write("ISSUES_FOUND=0\n" + s[a:b] + s[c:d] +
                             '\necho "ISSUES_FOUND=$ISSUES_FOUND"\n')
PY

REPO="$WORK/repo"
mkdir -p "$REPO" && cd "$REPO" || exit 2
git init -q
git config user.email test@example.invalid
git config user.name test
git config commit.gpgsign false
bd init -p bdh --quiet --skip-hooks --skip-agents --non-interactive </dev/null >/dev/null 2>&1 || {
    echo "FAIL: bd init in throwaway repo" >&2
    exit 2
}
git add -A >/dev/null && git commit -q --no-verify --allow-empty -m init >/dev/null

pass=0
fail=0
chk() {
    if [[ "$2" == "$3" ]]; then
        echo "  ok   $1"
        pass=$((pass + 1))
    else
        echo "  FAIL $1: expected [$3] got [$2]"
        fail=$((fail + 1))
    fi
}
run_step() { bash "$STEP" 2>&1; }
found() { printf '%s\n' "$1" | sed -n 's/^ISSUES_FOUND=//p'; }

# 1. A clean graph is a REAL zero.
out=$(run_step)
chk "no orphans -> ISSUES_FOUND 0" "$(found "$out")" "0"
chk "no orphans -> says so" "$(grep -c 'No orphaned issues' <<<"$out")" "1"

# 2. THE DEFECT: an open issue referenced by a commit must be counted.
id=$(bd create --title "orphan probe" --type task --priority 3 --silent 2>/dev/null)
[[ -n $id ]] || {
    echo "FAIL: could not create probe issue" >&2
    exit 2
}
echo x >f && git add f && git commit -q --no-verify -m "fix: the thing ($id)"
out=$(run_step)
chk "injected orphan -> ISSUES_FOUND 1" "$(found "$out")" "1"
chk "injected orphan -> listed" "$(grep -cE "^    $id  orphan probe  \([0-9a-f]+\)$" <<<"$out")" "1"

# 3. bd fails: UNKNOWN, never clean. Two counts, both correct: the orphan
#    query and the `bd stats` query each report UNKNOWN.
FAKE="$WORK/fakebin"
mkdir -p "$FAKE"
printf '#!/bin/bash\necho "Error: database locked" >&2\nexit 1\n' >"$FAKE/bd"
chmod +x "$FAKE/bd"
out=$(PATH="$FAKE:$PATH" run_step)
chk "bd fails -> ISSUES_FOUND 2 (orphans + stats UNKNOWN)" "$(found "$out")" "2"
chk "bd fails -> UNKNOWN, NOT clean" "$(grep -c 'bd orphans: FAILED' <<<"$out")" "1"
chk "bd fails -> error surfaced" "$(grep -c '^      Error: database locked$' <<<"$out")" "1"

# 4. bd exits 0 but prints non-JSON (the preflight shape): UNKNOWN.
printf '#!/bin/bash\necho "PR Readiness Checklist:"\nexit 0\n' >"$FAKE/bd"
out=$(PATH="$FAKE:$PATH" run_step)
chk "non-JSON output -> ISSUES_FOUND 2 (orphans + stats UNKNOWN)" "$(found "$out")" "2"
chk "non-JSON output -> UNKNOWN" "$(grep -c 'bd orphans: FAILED' <<<"$out")" "1"

echo ""
echo "test-bd-health: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
