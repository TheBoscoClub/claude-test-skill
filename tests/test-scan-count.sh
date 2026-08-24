#!/bin/bash
# Regression guard for phase-5a's scan_count / scan_failed helpers.
#
# WHY THIS EXISTS (claude-test-skill-dqi)
# Every security scanner in phase 5a used to read:
#     COUNT=$(tool ... 2>/dev/null | jq '...' || echo "0")
# which reports a FAILING scanner as CLEAN. Ten sites, including all three
# GitHub alert queries that enforce the mandatory baseline in security.md.
# Demonstrated 2026-08-24: grype against a bad path printed
# "OK Grype: No vulnerabilities".
#
# The helpers are extracted from the skill document itself, so this test
# exercises the SHIPPING code rather than a copy that can drift.
#
# Run: tests/test-scan-count.sh

set -uo pipefail
cd "$(dirname "$0")/.." || exit 2
SKILL=skills/test-phases/phase-5a-security.md
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
    a = s.index('scan_count() {')
    b = s.index('# ' + '-' * 75, a)
except ValueError:
    sys.exit("FAIL: helper functions not found in the skill document")
open(sys.argv[2], 'w').write("TOTAL_ISSUES=0\nCRITICAL_ISSUES=0\n" + s[a:b])
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

scan_count '.matches | length' echo '{"matches":[]}'
chk "ran, zero findings" "$SCAN_STATUS/$SCAN_COUNT" "ok/0"

scan_count '.matches | length' echo '{"matches":[1,2,3]}'
chk "ran, three findings" "$SCAN_STATUS/$SCAN_COUNT" "ok/3"

# THE DEFECT: a tool killed mid-run emits nothing. Must NOT read as clean.
scan_count '.matches | length' true
chk "no output (timeout/kill)" "$SCAN_STATUS" "failed"

scan_count '.matches | length' /nonexistent-scanner-xyz
chk "missing binary" "$SCAN_STATUS" "failed"

scan_count '.matches | length' echo 'not json at all'
chk "unparseable output" "$SCAN_STATUS" "failed"

# REGRESSION GUARD: bandit, semgrep, checkov and npm audit all exit NON-ZERO
# when they FIND something. Gating on the exit code would report every real
# finding as a scanner failure.
scan_count '.results | length' bash -c 'echo "{\"results\":[1,2]}"; exit 1'
chk "nonzero exit WITH findings" "$SCAN_STATUS/$SCAN_COUNT" "ok/2"

TOTAL_ISSUES=0
SCAN_ERR="boom"
scan_failed "TestScanner" >/dev/null
chk "a failed scanner counts as an issue" "$TOTAL_ISSUES" "1"

# SCAN_ERR is consumed by scan_failed; shellcheck cannot see across the
# subshell boundary, hence the disable on the line below.
# shellcheck disable=SC2034
out="$(
    SCAN_ERR=boom
    scan_failed "TestScanner"
)"
case "$out" in *UNKNOWN*) chk "failure reported as UNKNOWN" yes yes ;; *) chk "failure reported as UNKNOWN" no yes ;; esac
case "$out" in *"✅"*) chk "failure never prints a checkmark" no yes ;; *) chk "failure never prints a checkmark" yes yes ;; esac

echo
echo "passed=$pass failed=$fail"
[[ $fail -eq 0 ]]
