#!/bin/bash
# Regression guard for the test-VM helpers (skills/test-phases/lib/test-vm.sh) and the phase functions
# that act on VMs: Phase 1 sweep, Phase 10a create/reset/snapshot/cross-distro/run_phase_V, Phase 10b
# start/shutdown (bd claude-test-skill-zy9).
#
# WHY THIS EXISTS
# - Each phase runs in its own subagent and reads only its own phase file. When resolve_test_vm lived
#   only in phase-10b, the Phase 1 sweep reported "No usable test VM configured — nothing swept" (exit 0)
#   and Phase 10a aborted: a silent pre-test snapshot leak.
# - A tracked vm-test-manifest.json could name any libvirt VM (even one the installation never lists, or,
#   with no map, another project's exclusive VM) and /test would force-stop, revert and snapshot it.
# - Several branches could delete a pristine snapshot or a whole VM once paths.vm_storage_dirs was set.
#
# No VM is touched: virsh, sudo and every other host tool are PATH stubs that only log. The stubs never
# call their own name (sudo runs the stubbed tool it is given; anything else is logged, never executed).
# Functions are extracted from the SHIPPING phase documents, so this exercises the real code.
#
# Run: tests/test-vm-lib.sh            (REPO_DIR=<tree> to run it against another checkout)

# SC2015: ok/bad always return 0, so `check && ok || bad` cannot run both.
# SC2016: the single-quoted code is run by the case's own shell, where it must expand.
# shellcheck disable=SC2015,SC2016
set -uo pipefail
REPO_DIR="${REPO_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
PHASES="$REPO_DIR/skills/test-phases"
for f in phase-1-snapshot.md phase-10a-vm-testing.md phase-10b-vm-lifecycle.md; do
    [[ -r "$PHASES/$f" ]] || {
        echo "FAIL: cannot read $PHASES/$f" >&2
        exit 2
    }
done

T="$(mktemp -d)"
[[ -n "${KEEP:-}" ]] || trap 'rm -rf "${T:?}"' EXIT

# ── functions extracted from the phase documents (definitions only, no top-level commands) ──────────
# One file per phase: each phase's subagent reads only its own phase file, so a case loads only the
# phase it exercises (a function defined in another phase is NOT available, exactly as in a real run).
python3 - "$PHASES" "$T" <<'PY' || exit 2
import re, sys, os
src, out = sys.argv[1], sys.argv[2]
need = {"1": {"sweep_pretest_snapshots"},
        "10a": {"create_test_vm", "manage_vm_snapshot", "reset_vm_to_pristine", "reset_vm_to_clean",
                "run_cross_distro_tests", "run_phase_V"},
        "10b": {"start_test_vm", "shutdown_test_vm"}}
files = {"1": "phase-1-snapshot.md", "10a": "phase-10a-vm-testing.md", "10b": "phase-10b-vm-lifecycle.md"}
for ph, f in files.items():
    code = []
    for block in re.findall(r"```bash\n(.*?)```", open(os.path.join(src, f)).read(), re.S):
        code += re.findall(r"^[A-Za-z_][A-Za-z0-9_]*\(\) \{\n.*?^\}\n", block, re.S | re.M)
        code += [l + "\n" for l in re.findall(r"^[A-Za-z_][A-Za-z0-9_]*\(\) \{ .*; \}$", block, re.M)]
    have = {c.split("(", 1)[0] for c in code}
    if need[ph] - have:
        sys.exit(f"FAIL: not found in {f}: {sorted(need[ph] - have)}")
    open(os.path.join(out, f"funcs-{ph}.sh"), "w").write("\n".join(code))
PY

# ── stubs ─────────────────────────────────────────────────────────────────────────────────────────────
S="$T/stubs"
mkdir -p "$S"
cat >"$S/virsh" <<'EOF'
#!/bin/bash
echo "virsh $*" >>"${LOG:?}"
case "$1" in
    list) cat "${FIX:?}/virsh-list" ;;
    dominfo) grep -qxF -- "$2" "${FIX:?}/virsh-list" ;;
    domstate) if [[ -f "$FIX/state-$2" ]]; then cat "$FIX/state-$2"; else echo "shut off"; fi ;;
    snapshot-list) [[ -f "$FIX/snaps-$2" ]] && cat "$FIX/snaps-$2"; true ;;
    snapshot-revert) [[ -f "$FIX/revert-fail" ]] && exit 1; exit 0 ;;
    domifaddr) echo " vnet0  52:54:00:00:00:01  ipv4  10.0.0.10/24" ;;
    *) exit 0 ;;
esac
EOF
cat >"$S/sudo" <<'EOF'
#!/bin/bash
echo "sudo $*" >>"${LOG:?}"
[[ "$1" == "-n" ]] && shift
case "$1" in
    virsh | systemctl | virt-xml | qemu-img | virt-install) exec "$@" ;;   # the stub of that tool
    *) exit 0 ;;                                                            # rm, cp, ...: logged only
esac
EOF
for tool in systemctl sleep ssh scp rsync virt-install virt-xml qemu-img docker; do
    printf '#!/bin/bash\necho "%s $*" >>"${LOG:?}"\nexit 0\n' "$tool" >"$S/$tool"
done
chmod 755 "$S"/*

pass=0
fail=0
ok() {
    echo "  ok   $1"
    pass=$((pass + 1))
}
bad() {
    echo "  FAIL $1"
    fail=$((fail + 1))
}

# case_env NAME PROJECT MAP MANIFEST — fresh sandbox; MAP/MANIFEST are JSON, MISSING, or text
case_env() {
    C="$T/case-$1"
    mkdir -p "$C/home/.claude/config" "$C/fix" "$C/proj/$2"
    P="$C/proj/$2"
    printf '%s\n' shared-vm excl-vm excl-vm2 unlisted-vm >"$C/fix/virsh-list"
    : >"$C/log"
    [[ "$3" != MISSING ]] && printf '%s' "$3" >"$C/home/.claude/config/project-vm-map.json"
    [[ "$4" != MISSING ]] && printf '%s' "$4" >"$P/vm-test-manifest.json"
    return 0
}
# run PHASE CODE — run CODE in a fresh shell that has loaded only PHASE's functions (1, 10a, 10b);
# the helpers directory is overridable via LIBDIR
run() {
    (cd "$P" && HOME="$C/home" LOG="$C/log" FIX="$C/fix" PATH="$S:/usr/bin:/bin" \
        TEST_PHASES_DIR="${LIBDIR:-$PHASES}" PROJECT_DIR="$P" \
        bash -c "source '$T/funcs-$1.sh'; $2" 2>&1)
}
logged() { grep -qE -- "$1" "$C/log"; }

MAP='{"default":{"vm":"shared-vm"},"projects":{"Excl Proj":{"vm":"excl-vm"}},"vms":{"shared-vm":{"ssh_user":"u","ssh_key":"/k","ip":"10.0.0.10"},"excl-vm":{"exclusive_to":"Excl Proj","ssh_user":"u","ssh_key":"/k"},"excl-vm2":{"exclusive_to":"Excl Proj"}}}'
EMPTYLIB="$T/emptylib"
mkdir -p "$EMPTYLIB/lib"

echo "1. Every caller loads the helpers itself; 'not loaded' is an error, not 'not configured'"
case_env sweep-nolib P1 "$MAP" MISSING
printf '%s\n' pristine pre-test-20260101-000000 >"$C/fix/snaps-shared-vm"
out=$(LIBDIR=$EMPTYLIB run 1 'sweep_pretest_snapshots; echo "RC=$?"')
[[ "$out" == *"RC=2"* && "$out" == *"not loaded"* ]] && ok "sweep without the helpers: exit 2, 'not loaded'" || bad "sweep without the helpers: $out"
logged 'snapshot-delete' && bad "sweep without the helpers deleted a snapshot" || ok "sweep without the helpers deleted nothing"
case_env runv-nolib P1 "$MAP" MISSING
out=$(LIBDIR=$EMPTYLIB run 10a 'run_phase_V >/dev/null 2>&1; echo "RC=$?"')
[[ "$out" == *"RC=2"* ]] && ok "run_phase_V without the helpers: exit 2" || bad "run_phase_V without the helpers: $out"
case_env start-nolib P1 "$MAP" MISSING
out=$(LIBDIR=$EMPTYLIB run 10b 'ISOLATION_LEVEL=vm-required start_test_vm >/dev/null 2>&1; echo "RC=$?"')
[[ "$out" == *"RC=2"* ]] && ok "start_test_vm without the helpers: exit 2" || bad "start_test_vm without the helpers: $out"
logged 'virsh (start|snapshot-revert|snapshot-create-as|destroy)' && bad "start_test_vm without the helpers acted on a VM" || ok "start_test_vm without the helpers acted on no VM"

case_env sweep-ok P1 "$MAP" MISSING
printf '%s\n' pristine pre-test-20260101-000000 clean-install pre-test-2026 >"$C/fix/snaps-shared-vm"
out=$(run 1 'sweep_pretest_snapshots; echo "RC=$?"')
[[ "$out" == *"RC=0"* && "$out" == *"deleted pre-test-20260101-000000"* ]] && ok "sweep with the helpers deletes the leftover pre-test snapshot" || bad "sweep with the helpers: $out"
[[ "$(grep -c '^virsh snapshot-delete' "$C/log")" == 1 ]] && ! logged 'snapshot-delete shared-vm (pristine|clean-install|pre-test-2026$)' &&
    ok "sweep deletes only the pre-test-YYYYMMDD-HHMMSS name" || bad "sweep deleted another name: $(grep snapshot-delete "$C/log" | tr '\n' ' ')"
case_env runv-ok P1 "$MAP" MISSING
printf '%s\n' pristine >"$C/fix/snaps-shared-vm"
out=$(run 10a 'run_phase_V >/dev/null 2>&1; echo "RC=$?"')
[[ "$out" != *"RC=2"* ]] && logged 'virsh snapshot-revert shared-vm pristine' && ok "run_phase_V with the helpers resolves and resets the configured VM" || bad "run_phase_V with the helpers: $out"
logged "^ssh -i /k .* u@10\.0\.0\.10 echo 'SSH OK'" && ! logged 'vm_test_key|testuser@' &&
    ok "run_phase_V deploys with the configured SSH identity" || bad "run_phase_V deploy identity: $(grep -m1 "SSH OK" "$C/log")"

echo "2. Only VMs the installation lists under vms; the manifest can choose among them, never add one"
# resolve CASE PROJECT MAP MANIFEST EXPECT — EXPECT a VM name, or FAIL; start_test_vm must touch only it
resolve() {
    local name=$1 proj=$2 map=$3 man=$4 expect=$5 got touched t badvm=""
    case_env "$name" "$proj" "$map" "$man"
    got=$(run 10b 'resolve_test_vm_out=$(source "$TEST_PHASES_DIR/lib/test-vm.sh" 2>/dev/null; resolve_test_vm "$PROJECT_DIR" 2>/dev/null) && echo "VM=$resolve_test_vm_out"; ISOLATION_LEVEL=vm-required start_test_vm >/dev/null 2>&1' | sed -n 's/^VM=//p')
    got=${got:-FAIL}
    touched=$(grep -oE '^virsh (start|destroy|snapshot-revert|snapshot-delete|snapshot-create-as) [^ ]+' "$C/log" | awk '{print $3}' | sort -u)
    for t in $touched; do [[ "$t" == "$expect" ]] || badvm+="$t "; done
    if [[ "$got" == "$expect" && -z "$badvm" ]]; then ok "$name -> $got"; else bad "$name -> got $got, expected $expect, touched [${touched//$'\n'/ }]"; fi
}
resolve default-listed P1 "$MAP" MISSING shared-vm
resolve own-exclusive "Excl Proj" "$MAP" MISSING excl-vm
resolve manifest-unlisted P1 "$MAP" '{"vm_testing":{"default_vm":"unlisted-vm","post_test_restore":true,"pristine_snapshot":"pristine"}}' FAIL
resolve manifest-unlisted-no-vms P1 '{"default":{"vm":"shared-vm"}}' '{"vm_testing":{"default_vm":"unlisted-vm","post_test_restore":true}}' FAIL
resolve no-map-manifest-names-vm P1 MISSING '{"vm_testing":{"default_vm":"excl-vm"}}' FAIL
resolve map-is-a-list P1 '[1,2]' '{"vm_testing":{"default_vm":"shared-vm"}}' FAIL
resolve map-invalid-json P1 '{bad' MISSING FAIL
resolve manifest-is-a-list P1 "$MAP" '[]' FAIL
resolve manifest-names-other-exclusive P1 "$MAP" '{"vm_testing":{"default_vm":"excl-vm"}}' FAIL
resolve exclusive-project-other-vm "Excl Proj" '{"default":{"vm":"shared-vm"},"vms":{"shared-vm":{},"excl-vm":{"exclusive_to":"Excl Proj"}}}' '{"vm_testing":{"default_vm":"shared-vm"}}' FAIL
resolve manifest-names-listed P1 "$MAP" '{"vm_testing":{"default_vm":"shared-vm"}}' shared-vm
resolve nothing-configured P1 '{"vms":{"shared-vm":{}}}' MISSING FAIL

case_env cross-none P1 "$MAP" MISSING
out=$(run 10a 'run_cross_distro_tests')
[[ "$out" == *"no VMs configured"* ]] && ! logged '^virsh (start|snapshot-revert|destroy|dominfo)' && ok "cross-distro with nothing configured touches no VM (no built-in names)" || bad "cross-distro with nothing configured: $out"
case_env cross-manifest P1 "$MAP" '{"vm_testing":{"test_environments":[{"type":"existing","vm_name":"unlisted-vm"},{"type":"existing","vm_name":"excl-vm"},{"type":"existing","vm_name":"shared-vm"},{"type":"create","name":"x"}]}}'
printf '%s\n' pristine >"$C/fix/snaps-shared-vm"
out=$(run 10a 'run_cross_distro_tests')
[[ "$out" == *"unlisted-vm: REFUSED"* && "$out" == *"excl-vm: REFUSED"* ]] && ok "cross-distro refuses an unlisted VM and another project's exclusive VM" || bad "cross-distro refusal: $out"
logged '^virsh [a-z-]+ (unlisted-vm|excl-vm)( |$)' && bad "cross-distro touched a refused VM: $(grep -E 'unlisted-vm|excl-vm' "$C/log" | head -3 | tr '\n' ' ')" || ok "cross-distro never touched a refused VM"
logged '^virsh snapshot-revert shared-vm pristine' && ok "cross-distro resets the listed VM by revert" || bad "cross-distro did not reset the listed VM"

echo "3. No pristine snapshot, VM or disk is ever deleted"
case_env del-guard P1 "$MAP" '{"vm_testing":{"pristine_snapshot":"pre-test-20990101-000000"}}'
out=$(run 1 'source "$TEST_PHASES_DIR/lib/test-vm.sh"; for n in pristine pristine-x clean-install pre-test-2026 "pre-test-20260101-000000;x" pre-test-20990101-000000; do delete_pretest_snapshot shared-vm "$n" "$PROJECT_DIR" 2>/dev/null; echo "RC[$n]=$?"; done; delete_pretest_snapshot shared-vm pre-test-20260101-000000 "$PROJECT_DIR"; echo "RC[ok]=$?"')
[[ "$(grep -c '=2$' <<<"$out")" == 6 && "$out" == *"RC[ok]=0"* ]] && ok "delete_pretest_snapshot refuses pristine/other/the manifest's pristine_snapshot, allows a pre-test name" || bad "delete_pretest_snapshot: $out"
[[ "$(grep -c '^virsh snapshot-delete' "$C/log")" == 1 ]] && logged '^virsh snapshot-delete shared-vm pre-test-20260101-000000$' && ok "only the pre-test name reached virsh" || bad "virsh saw: $(grep snapshot-delete "$C/log" | tr '\n' ' ')"
case_env manage-del P1 "$MAP" MISSING
out=$(run 10a 'manage_vm_snapshot shared-vm delete pristine; echo "RC=$?"')
[[ "$out" == *"RC=2"* ]] && ! logged 'snapshot-delete' && ok "manage_vm_snapshot delete pristine is refused" || bad "manage_vm_snapshot delete pristine: $out"

STOREMAP='{"default":{"vm":"shared-vm"},"paths":{"iso_dir":"ISO","vm_storage_dirs":["STORE"]},"vms":{"shared-vm":{}}}'
case_env reset-store P1 "${STOREMAP//STORE/$T/case-reset-store/store}" '{"vm_testing":{"pristine_snapshot":"pristine"}}'
mkdir -p "$C/store" && : >"$C/store/shared-vm.pristine" && printf '%s\n' pristine >"$C/fix/snaps-shared-vm"
out=$(run 10a 'reset_vm_to_pristine shared-vm; echo "RC=$?"')
! logged 'snapshot-delete|sudo rm|virt-xml|snapshot-create-as' && logged 'virsh snapshot-revert shared-vm pristine' &&
    ok "reset with vm_storage_dirs set and an overlay present only reverts" || bad "reset destructive calls: $(grep -E 'snapshot-delete|rm|virt-xml|create-as' "$C/log" | tr '\n' ' ')"
case_env reset-unlisted P1 "$MAP" MISSING
out=$(run 10a 'reset_vm_to_pristine unlisted-vm; echo "RC=$?"')
[[ "$out" == *"RC=1"* ]] && ! logged 'virsh (destroy|snapshot-revert)' && ok "reset refuses a VM the map does not list" || bad "reset unlisted: $out"

case_env create-existing P1 "$STOREMAP" MISSING
sed -i "s#\"ISO\"#\"$C/iso\"#; s#\"STORE\"#\"$C/store\"#" "$C/home/.claude/config/project-vm-map.json"
mkdir -p "$C/iso" "$C/store" && : >"$C/iso/distro-1.iso"
out=$(run 10a 'create_test_vm shared-vm "distro-*.iso"; echo "RC=$?"')
[[ "$out" == *"RC=1"* && "$out" == *"already exists"* ]] && ! logged 'destroy|undefine|virt-install' && ok "create_test_vm refuses an existing VM name (no destroy/undefine)" || bad "create_test_vm existing: $out / $(tr '\n' ' ' <"$C/log")"
: >"$C/log"
out=$(run 10a 'create_test_vm "new vm;x" "distro-*.iso"; echo "RC=$?"')
[[ "$out" == *"RC=1"* ]] && ! logged 'virt-install' && ok "create_test_vm refuses an unsafe VM name" || bad "create_test_vm unsafe name: $out"
out=$(run 10a 'create_test_vm brand-new-vm "distro-*.iso"; echo "RC=$?"')
[[ "$out" == *"RC=0"* ]] && logged "virt-install --name brand-new-vm .*--disk path=$C/store/brand-new-vm.qcow2,size=40" && ok "create_test_vm creates a new VM (argument array, no eval)" || bad "create_test_vm new: $out"

case_env qcow2-fallback P1 '{"default":{"vm":"shared-vm"},"vms":{"shared-vm":{"pristine_type":"external_qcow2","pristine_path":"PP","active_disk":"/nonexistent/disk.qcow2"}}}' '{"vm_testing":{"post_test_restore":true,"pristine_snapshot":"pristine"}}'
truncate -s 2G "$C/pristine.qcow2" && sed -i "s#\"PP\"#\"$C/pristine.qcow2\"#" "$C/home/.claude/config/project-vm-map.json"
printf '%s\n' pristine pre-test-20260101-000000 >"$C/fix/snaps-shared-vm" && : >"$C/fix/revert-fail"
out=$(run 10b 'ISOLATION_LEVEL=vm-required start_test_vm; echo "RC=$?"')
[[ "$out" == *"RC=1"* && "$out" == *"manual recovery required"* ]] && ! logged 'snapshot-delete|sudo cp|virt-xml|virsh define|virsh start' &&
    ok "failed pristine revert stops for manual recovery (no disk overwrite, no metadata delete)" || bad "qcow2 fallback: $(grep -E 'delete|cp|virt-xml|define|start' "$C/log" | tr '\n' ' ') / ${out: -200}"

case_env shutdown-badname P1 "$MAP" MISSING
printf 'vm_name=shared-vm\nstarted_by_test=true\noriginal_state=shutoff\npre_test_snapshot=pristine\n' >"$P/.test-vm-state"
out=$(run 10b 'shutdown_test_vm; echo "RC=$?"')
! logged 'snapshot-(delete|revert)' && ok "shutdown never reverts to or deletes a state-file snapshot that is not pre-test" || bad "shutdown with pre_test_snapshot=pristine: $(grep snapshot "$C/log" | tr '\n' ' ')"
case_env shutdown-ok P1 "$MAP" MISSING
printf 'vm_name=shared-vm\nstarted_by_test=true\noriginal_state=shutoff\npre_test_snapshot=pre-test-20260101-000000\n' >"$P/.test-vm-state"
out=$(run 10b 'shutdown_test_vm; echo "RC=$?"')
logged 'snapshot-revert shared-vm pre-test-20260101-000000' && logged 'snapshot-delete shared-vm pre-test-20260101-000000' && ok "shutdown reverts to and deletes its own pre-test snapshot" || bad "shutdown with a pre-test name: $(tr '\n' ' ' <"$C/log")"

echo
echo "passed=$pass failed=$fail"
[[ $fail -eq 0 ]]
