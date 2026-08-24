#!/bin/bash
# Regression guard for phase-9d's gh_json / json_count / audit_unknown.
#
# WHY (claude-test-skill-dqi, phase-9d half)
# The GitHub audit used to read:
#     ALERTS=$(gh api ... 2>/dev/null)
#     COUNT=$(echo "$ALERTS" | jq 'length' 2>/dev/null || echo "0")
# The gh failure is swallowed at capture, jq then fails on the empty string,
# and `|| echo "0"` reports ZERO OPEN ALERTS -- for the three queries that
# enforce the mandatory baseline in security.md, plus the CI-failure check.
#
# Helpers are extracted from the skill document, so this exercises shipping
# code rather than a copy that can drift.
#
# Run: tests/test-gh-json.sh

set -uo pipefail
cd "$(dirname "$0")/.." || exit 2
SKILL=skills/test-phases/phase-9d-github.md
[[ -r $SKILL ]] || {
    echo "FAIL: cannot read $SKILL" >&2
    exit 2
}

HELPER="$(mktemp)"
trap 'rm -f "$HELPER"' EXIT
python3 - "$SKILL" "$HELPER" <<'PY' || exit 2
import sys
s = open(sys.argv[1]).read()
try:
    a = s.index('gh_json() {')
    b = s.index('# ' + '-' * 75, a)
except ValueError:
    sys.exit("FAIL: helper functions not found in the skill document")
open(sys.argv[2], 'w').write("ISSUES_FOUND=0\n" + s[a:b])
PY
# shellcheck source=/dev/null
source "$HELPER"

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

gh_json echo '[{"a":1},{"a":2}]'
chk "command succeeds -> ok" "$GH_STATUS" "ok"
json_count "$GH_OUT" 'length' && chk "count parses" "$JSON_COUNT" "2"

# An empty array is a REAL answer: zero alerts, not a failure.
gh_json echo '[]'
json_count "$GH_OUT" 'length' && chk "empty array is a real zero" "$JSON_COUNT" "0"

# THE DEFECT: the API call fails. Must NOT look like zero alerts.
gh_json /nonexistent-gh-xyz api whatever
chk "missing binary -> failed" "$GH_STATUS" "failed"

# gh exits 0 but prints nothing (the swallowed-error shape).
gh_json true
chk "empty output -> failed" "$GH_STATUS" "failed"

# gh returns an error body rather than JSON.
gh_json echo 'gh: Not Found (HTTP 404)'
if json_count "$GH_OUT" 'length'; then
    chk "non-JSON body rejected" "accepted" "rejected"
else
    chk "non-JSON body rejected" "rejected" "rejected"
fi

ISSUES_FOUND=0
audit_unknown "TestQuery" "boom" >/dev/null
chk "audit_unknown counts an issue" "$ISSUES_FOUND" "1"

out="$(audit_unknown "TestQuery" "boom")"
case "$out" in *UNKNOWN*) chk "reports UNKNOWN" yes yes ;; *) chk "reports UNKNOWN" no yes ;; esac
case "$out" in *"✅"*) chk "never prints a checkmark" no yes ;; *) chk "never prints a checkmark" yes yes ;; esac

echo
echo "passed=$pass failed=$fail"
[[ $fail -eq 0 ]]
