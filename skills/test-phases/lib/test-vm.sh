#!/bin/bash
# Test-VM helpers shared by /test Phases 1, 10a and 10b (bd claude-test-skill-zy9).
#
# Every phase runs in its own subagent and reads only its own phase file, so each caller sources this
# file itself and checks that the functions arrived — "helpers not loaded" (exit 2) must never look
# like "no VM configured":
#
#   source "${TEST_PHASES_DIR:-$HOME/.claude/skills/test-phases}/lib/test-vm.sh" &&
#       declare -F resolve_test_vm >/dev/null ||
#       { echo "ERROR: test-VM helpers not loaded (lib/test-vm.sh)"; return 2; }
#
# Defines functions only; sourcing it runs nothing.
#
#   resolve_test_vm [PROJECT_DIR]          print the project's test VM, or return 1 (reason on stderr)
#   check_test_vm PROJECT_DIR VM           return 0 if PROJECT_DIR may use VM, else 1 (reason on stderr)
#   is_pretest_snapshot NAME               return 0 if NAME is a /test pre-test snapshot name
#   delete_pretest_snapshot VM NAME [DIR]  the only snapshot-delete the skill issues; refuses any other name
#
# A VM is usable only when the installation lists it: it must be a key of `vms` in
# ~/.claude/config/project-vm-map.json. A project's tracked vm-test-manifest.json can choose among the
# listed VMs but can never introduce one. `exclusive_to` is a bidirectional lock: only the named project
# uses that VM, and that project uses only its own exclusive VM(s). There is no built-in default VM.

# _test_vm_select MODE PROJECT_DIR [VM] — MODE resolve: print the chosen VM; MODE check: validate VM.
_test_vm_select() {
    python3 - "$1" "$2" "${3:-}" "$HOME/.claude/config/project-vm-map.json" <<'PYEOF'
import json, os, sys

mode, proj_dir, want, map_path = sys.argv[1:5]
project = os.path.basename(proj_dir.rstrip("/"))


def die(msg):
    sys.exit(f"resolve_test_vm: {msg}")


def load(path, required):
    try:
        with open(path) as f:
            data = json.load(f)
    except FileNotFoundError:
        if required:
            die(f"{path} not found — a test VM must be listed there under vms")
        return {}
    except (OSError, ValueError) as e:
        die(f"cannot read {path}: {e}")
    if not isinstance(data, dict):
        die(f"{path} is not a JSON object")
    return data


def sub(d, key):
    v = d.get(key) if isinstance(d, dict) else None
    return v if isinstance(v, dict) else {}


def text(v):
    return v.strip() if isinstance(v, str) else ""


vm_map = load(map_path, required=True)
if mode == "resolve":
    manifest = load(os.path.join(proj_dir, "vm-test-manifest.json"), required=False)
    vm = (text(sub(sub(vm_map, "projects"), project).get("vm"))
          or text(sub(manifest, "vm_testing").get("default_vm"))
          or text(sub(vm_map, "default").get("vm")))
    if not vm:
        die(f"no test VM configured for {project} — set projects.<project>.vm or default.vm in "
            f"{map_path}, or vm_testing.default_vm in vm-test-manifest.json")
elif mode == "check":
    vm = text(want)
    if not vm:
        die("check_test_vm: no VM name given")
else:
    die(f"unknown mode {mode}")

vms = sub(vm_map, "vms")
if vm not in vms:
    die(f"{vm} is not listed under vms in {map_path}; only VMs the installation lists may be used")
owner = text(sub(vms, vm).get("exclusive_to"))
if owner and owner != project:
    die(f"{vm} is exclusive_to {owner}; {project} may not use it")
own = sorted(n for n in vms if text(sub(vms, n).get("exclusive_to")) == project)
if own and vm not in own:
    die(f"{project} has exclusive VM(s) {', '.join(own)}; it may not use {vm}")
if mode == "resolve":
    print(vm)
PYEOF
}

resolve_test_vm() {
    _test_vm_select resolve "${1:-${PROJECT_DIR:-$(pwd)}}"
}

check_test_vm() {
    [[ $# -eq 2 && -n "$1" && -n "$2" ]] || {
        echo "check_test_vm: usage: check_test_vm PROJECT_DIR VM" >&2
        return 2
    }
    _test_vm_select check "$1" "$2"
}

is_pretest_snapshot() {
    [[ "${1:-}" =~ ^pre-test-[0-9]{8}-[0-9]{6}$ ]]
}

# delete_pretest_snapshot VM NAME [PROJECT_DIR] — return 0 deleted, 1 virsh failed, 2 refused.
# Pristine snapshots are never deleted (infrastructure rule): only a pre-test name passes, and never
# the project's own pristine_snapshot, whatever it is called.
delete_pretest_snapshot() {
    local vm="${1:-}" name="${2:-}" proj="${3:-${PROJECT_DIR:-$(pwd)}}" pristine=""
    if [[ -z "$vm" ]] || ! is_pretest_snapshot "$name"; then
        echo "delete_pretest_snapshot: refused — '$name' is not a pre-test-YYYYMMDD-HHMMSS snapshot" >&2
        return 2
    fi
    if [[ -f "$proj/vm-test-manifest.json" ]]; then
        pristine=$(jq -r '.vm_testing.pristine_snapshot // empty | strings' "$proj/vm-test-manifest.json" 2>/dev/null) || {
            echo "delete_pretest_snapshot: refused — cannot read $proj/vm-test-manifest.json" >&2
            return 2
        }
    fi
    if [[ -n "$pristine" && "$name" == "$pristine" ]]; then
        echo "delete_pretest_snapshot: refused — '$name' is this project's pristine_snapshot" >&2
        return 2
    fi
    sudo virsh snapshot-delete "$vm" "$name" >/dev/null 2>&1
}
