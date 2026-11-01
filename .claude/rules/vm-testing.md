# Phase 10a: VM Testing Configuration

Detail, incidents and reasoning per section: `.claude/docs/rules-reference/vm-testing.md` (same headings).

## Default Test VM

The default test VM is the one named by `default.vm` in `~/.claude/config/project-vm-map.json`; its disk image and the install ISOs live where the installation says (`vms.<vm>.active_disk`, `paths.iso_dir`; real values only on the host, e.g. the gitignored `.claude/rules/local-vm-paths.md`). The skill has no built-in VM name. Phases 1, 10a and 10b choose the VM with `resolve_test_vm` (`phase-10b-vm-lifecycle.md` § Test VM Selection) and never pick a VM by matching names in `virsh list`.

## Manifest Template

`templates/vm-test-manifest.json` — copy to project root to customize VM testing.

## VM Management

Basics: `sudo virsh list --all|start|snapshot-create-as|snapshot-revert`, `virt-viewer <vm>`. Project pristine snapshots: each project's `vm-test-manifest.json` (`"snapshot"`, `"post_test_restore"`).

## VM Exclusivity Rules

Assignments live in `~/.claude/config/project-vm-map.json`. `exclusive_to` is a **bidirectional lock**: only the named project may use that VM, and that project must not test on other VMs. `resolve_test_vm` refuses either crossing.

| VM (generic pattern) | Exclusive To | Purpose | Snapshot |
| ---- | ------------- | --------- | ---------- |
| `test-<project>` | `<your-project>` | Integration/API/UI testing | the manifest's `pristine_snapshot` |
| `qa-<project>` | `<your-project>` | QA only — released versions, no test runs | the QA baseline snapshot |
| `<default-vm>` (`default.vm`) | *(none)* | Default for all other projects | — |

- QA VMs receive only promoted releases — `/test` phases never run against them.
- All other projects use the `default.vm` VM (or any non-exclusive VM for cross-distro testing).
- Nothing configured, or the chosen VM exclusive to another project → the VM phases abort; there is no fallback VM.

## When Phase 10a Runs

- `vm-test-manifest.json` has `"enabled": true`
- Project has dangerous operations (PAM, systemd, kernel)
- User requests `--phase=10a`
- Phase 2/3 detects install scripts modifying system-level configs

## VM Lifecycle for `post_test_restore=true` VMs

| Phase | VM State | Action |
| ------- | ---------- | -------- |
| **Before /test** | Shut down (dirty from last run, or pristine) | — |
| **Startup (Phase 10b)** | Check state | VM = `resolve_test_vm` (abort if none configured or exclusive to another project). Running → interrupted test → force stop. Then, in either state, revert to pristine (Phase 10b), then start. |
| **During testing** | Running | Install, deploy, test |
| **Cleanup (Phase 11)** | Running (dirty) | Shut down, leave shut down (`post_test_restore=true` VMs: no revert here) |

- Revert ALWAYS discards the overlay (never `qemu-img commit` — bakes test changes into the base)
- Overlay files are deleted only under directories listed in `paths.vm_storage_dirs`; with that key absent the overlay steps are skipped and only snapshot reverts run
- Phase 11 shuts down `post_test_restore=true` VMs regardless of who started them (it does not revert; the revert happens at the next start); shared VMs are shut down only if `/test` started them

## VM Snapshot Workflow (Shared VMs)

Shared VMs (no `post_test_restore`) use pre-test snapshots:

**Internal snapshots need the VM SHUT OFF** (a live `snapshot-create-as` fails with `require QCOW2 nvram format`). Snapshot first, then start.

```bash
# 1. BEFORE tests — VM must be shut off
sudo virsh domstate "$VM" | grep -q 'shut off' || sudo virsh shutdown "$VM"
sudo virsh snapshot-create-as "$VM" pre-test-$(date +%Y%m%d-%H%M%S) \
    --description "Pre-test state before /test run"
sudo virsh start "$VM"
# 2. RUN tests
# 3. AFTER tests
sudo virsh snapshot-revert "$VM" <snapshot-name>
# 4. CLEANUP
sudo virsh snapshot-delete "$VM" <snapshot-name>
```

### Snapshot Types

| Snapshot | Purpose | Lifetime |
| ---------- | --------- | ---------- |
| the manifest's `pristine_snapshot` (e.g. `pristine`) | Pristine OS + deps, no app (project-specific) | Permanent, authoritative |
| QA baseline (the QA VM's own snapshot) | QA baseline: app installed + data populated | Permanent (QA VMs only) |
| `clean-install` | Legacy baseline (fresh OS + SSH) | Permanent (fallback) |
| `pre-test-YYYYMMDD-HHMMSS` | State before a specific test run | Deleted after test by Phase 10b; leftovers swept by `/test` Phase 1 (`sweep_pretest_snapshots`) |
