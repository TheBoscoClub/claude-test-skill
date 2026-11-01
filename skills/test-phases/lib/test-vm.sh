#!/bin/bash
# Test-VM helpers shared by /test Phases 1, 10a, 10b and 11 (bd claude-test-skill-zy9), and by the
# installation's ~/.claude/scripts/vm-pretest-sweep.sh, which sources this file rather than copying it.
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
#   is_test_vm_name NAME                   return 0 if NAME is a well-formed VM name (see below)
#   test_vm_state_get FILE KEY             print KEY's value from a .test-vm-state file, exactly as stored
#   is_pretest_snapshot NAME               return 0 if NAME is a /test pre-test snapshot name
#   delete_pretest_snapshot VM NAME [DIR]  the only snapshot-delete the skill issues; refuses any other name
#
# A VM is usable only when the installation lists it: it must be a key of `vms` in
# ~/.claude/config/project-vm-map.json. A project's tracked vm-test-manifest.json can choose among the
# listed VMs but can never introduce one. `exclusive_to` (a project name, or a list of them) is a
# bidirectional lock: only the named project(s) use that VM, and such a project uses only its own
# exclusive VM(s); an exclusive_to that is neither null, a non-empty string nor a non-empty list of
# non-empty strings makes every lookup refuse. A VM whose `role` is "qa" is never used by /test (QA VMs
# receive only released versions). There is no built-in default VM.
#
# VM names are taken exactly as given — never trimmed or otherwise rewritten — and must match
# ^[A-Za-z0-9][A-Za-z0-9._-]*$ (no whitespace, no shell or path metacharacters, no leading dash), so
# the name that was checked is the name every caller then hands to virsh.

# _test_vm_select MODE PROJECT_DIR [VM] — MODE resolve: print the chosen VM; MODE check: validate VM.
_test_vm_select() {
    python3 - "$1" "$2" "${3:-}" "$HOME/.claude/config/project-vm-map.json" <<'PYEOF'
import json, os, re, sys

mode, proj_dir, want, map_path = sys.argv[1:5]
project = os.path.basename(proj_dir.rstrip("/"))
NAME = re.compile(r"[A-Za-z0-9][A-Za-z0-9._-]*")


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


def vm_name(v, where):
    """A configured VM name, exactly as written: "" when unset; refuse anything malformed."""
    if v is None or v == "":
        return ""
    if not isinstance(v, str) or not NAME.fullmatch(v):
        die(f"{where} is not a usable VM name ({v!r}); a VM name matches [A-Za-z0-9][A-Za-z0-9._-]*")
    return v


def owners(name, entry):
    """The set of projects a VM is exclusive to; empty for no lock. Refuse a lock that cannot be read."""
    lock = entry.get("exclusive_to") if isinstance(entry, dict) else None
    if lock is None:
        return set()
    if isinstance(lock, str) and lock.strip():
        return {lock.strip()}
    if (isinstance(lock, list) and lock
            and all(isinstance(o, str) and o.strip() for o in lock)):
        return {o.strip() for o in lock}
    die(f"exclusive_to of {name} in {map_path} is not null, a project name or a list of project names; "
        f"fix the map")


vm_map = load(map_path, required=True)
if mode == "resolve":
    manifest = load(os.path.join(proj_dir, "vm-test-manifest.json"), required=False)
    vm = (vm_name(sub(sub(vm_map, "projects"), project).get("vm"), f"projects.{project}.vm in {map_path}")
          or vm_name(sub(manifest, "vm_testing").get("default_vm"), "vm_testing.default_vm in vm-test-manifest.json")
          or vm_name(sub(vm_map, "default").get("vm"), f"default.vm in {map_path}"))
    if not vm:
        die(f"no test VM configured for {project} — set projects.<project>.vm or default.vm in "
            f"{map_path}, or vm_testing.default_vm in vm-test-manifest.json")
elif mode == "check":
    if want == "":
        die("check_test_vm: no VM name given")
    vm = vm_name(want, "check_test_vm: the VM name")
else:
    die(f"unknown mode {mode}")

vms = sub(vm_map, "vms")
# Every lock is read first: an exclusivity lock that cannot be read must not read as "no lock".
locks = {n: owners(n, vms[n]) for n in vms}
if vm not in vms:
    die(f"{vm} is not listed under vms in {map_path}; only VMs the installation lists may be used")
entry = vms[vm] if isinstance(vms[vm], dict) else {}
role = entry.get("role")
if role is not None and not isinstance(role, str):
    die(f"role of {vm} in {map_path} is not a string; fix the map")
if isinstance(role, str) and role.strip().lower() == "qa":
    die(f"{vm} is a QA VM (role qa in {map_path}); /test never runs against a QA VM")
if locks[vm] and project not in locks[vm]:
    die(f"{vm} is exclusive_to {', '.join(sorted(locks[vm]))}; {project} may not use it")
own = sorted(n for n in vms if project in locks[n])
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
    is_test_vm_name "$2" || {
        echo "check_test_vm: refused — '$2' is not a usable VM name ([A-Za-z0-9][A-Za-z0-9._-]*, taken exactly as given)" >&2
        return 1
    }
    _test_vm_select check "$1" "$2"
}

is_test_vm_name() {
    [[ "${1:-}" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]
}

# test_vm_state_get FILE KEY — print KEY's value exactly as stored (everything after the first "=", nothing
# trimmed). Return 1 when the key is absent, 2 when it appears more than once or the file cannot be read:
# a state file that names two VMs names none.
test_vm_state_get() {
    local file="${1:-}" key="${2:-}" lines
    [[ -n "$key" && -r "$file" ]] || return 2
    lines=$(grep -c -- "^${key}=" "$file") || [[ "$lines" == 0 ]] || return 2
    [[ "$lines" == 0 ]] && return 1
    [[ "$lines" == 1 ]] || {
        echo "test_vm_state_get: $file names $key $lines times — refused" >&2
        return 2
    }
    lines=$(grep -- "^${key}=" "$file")
    printf '%s\n' "${lines#*=}"
}

is_pretest_snapshot() {
    [[ "${1:-}" =~ ^pre-test-[0-9]{8}-[0-9]{6}$ ]]
}

# delete_pretest_snapshot VM NAME [PROJECT_DIR] — return 0 deleted, 1 virsh failed, 2 refused.
# Pristine snapshots are never deleted (infrastructure rule). Each condition below refuses on its own,
# so none depends on another being right:
#   - NAME must be a pre-test-YYYYMMDD-HHMMSS name;
#   - NAME must not contain "pristine" (any case);
#   - NAME must not be a configured pristine snapshot: the project manifest's vm_testing.pristine_snapshot
#     or the map's vms.<VM>.pristine_snapshot. A manifest or map that exists but cannot be read refuses.
delete_pretest_snapshot() {
    local vm="${1:-}" name="${2:-}" proj="${3:-${PROJECT_DIR:-$(pwd)}}" pristine="" map_pristine=""
    local vm_map="$HOME/.claude/config/project-vm-map.json"
    if ! is_test_vm_name "$vm" || ! is_pretest_snapshot "$name"; then
        echo "delete_pretest_snapshot: refused — '$name' on '$vm' is not a pre-test-YYYYMMDD-HHMMSS snapshot of a well-formed VM name" >&2
        return 2
    fi
    if [[ "${name,,}" == *pristine* ]]; then
        echo "delete_pretest_snapshot: refused — '$name' names a pristine snapshot" >&2
        return 2
    fi
    if [[ -e "$proj/vm-test-manifest.json" ]]; then
        pristine=$(jq -r '.vm_testing.pristine_snapshot // empty | strings' "$proj/vm-test-manifest.json" 2>/dev/null) || {
            echo "delete_pretest_snapshot: refused — cannot read $proj/vm-test-manifest.json" >&2
            return 2
        }
    fi
    if [[ -e "$vm_map" ]]; then
        map_pristine=$(jq -r --arg vm "$vm" '.vms[$vm].pristine_snapshot? // empty | strings' "$vm_map" 2>/dev/null) || {
            echo "delete_pretest_snapshot: refused — cannot read $vm_map" >&2
            return 2
        }
    fi
    if [[ -n "$pristine" && "$name" == "$pristine" ]] || [[ -n "$map_pristine" && "$name" == "$map_pristine" ]]; then
        echo "delete_pretest_snapshot: refused — '$name' is a configured pristine_snapshot" >&2
        return 2
    fi
    sudo virsh snapshot-delete "$vm" "$name" >/dev/null 2>&1 || return 1
}
