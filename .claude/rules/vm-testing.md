# Phase 10a: VM Testing Configuration

## Default Test VM

**example-test-vm**: an existing libvirt VM. Image `/var/lib/libvirt/images/example-test-vm.qcow2`; ISOs `/path/to/isos/`. Phase 10a auto-detects VMs with "test" or "dev" in the name.

## Manifest Template

`templates/vm-test-manifest.json` — copy to project root to customize VM testing.

## VM Management

```bash
sudo virsh list --all
sudo virsh start example-test-vm
virt-viewer example-test-vm
sudo virsh snapshot-create-as example-test-vm clean-install --description "Fresh install"   # VM shut off (see below)
sudo virsh snapshot-revert example-test-vm clean-install
# Project pristine snapshots: each project's vm-test-manifest.json ("snapshot", "post_test_restore")
```

## VM Exclusivity Rules

Assignments live in `~/.claude/config/project-vm-map.json`. `exclusive_to` is a **bidirectional lock**: only the named project may use that VM, and that project must not test on other VMs.

| VM (generic pattern) | Exclusive To | Purpose | Snapshot |
| ---- | ------------- | --------- | ---------- |
| `test-<project>-cachyos` | `<your-project>` | Integration/API/UI testing | `pristine-*` |
| `qa-<project>-cachyos` | `<your-project>` | QA only — released versions, no test runs | `qa-baseline-*` |
| `example-test-vm` | *(none)* | Default for all other projects | — |

- QA VMs receive only promoted releases — `/test` phases never run against them.
- All other projects use `example-test-vm` (or any non-exclusive VM for cross-distro testing).

## When Phase 10a Runs

- `vm-test-manifest.json` has `"enabled": true`
- Project has dangerous operations (PAM, systemd, kernel)
- User requests `--phase=10a`
- Phase 2/3 detects install scripts modifying system-level configs

## VM Lifecycle for `post_test_restore=true` VMs

| Phase | VM State | Action |
| ------- | ---------- | -------- |
| **Before /test** | Shut down + pristine | — |
| **Startup (Phase 2/3)** | Check state | Running → dirty from interrupted test → force revert to pristine, then start. Shut down → start normally. |
| **During testing** | Running | Install, deploy, test |
| **Cleanup (Phase 11)** | Running (dirty) | ALWAYS: revert to pristine, shut down, leave shut down |

- Revert ALWAYS discards the overlay (never `qemu-img commit` — bakes test changes into the base)
- Phase 11 reverts and shuts down regardless of who started the VM

## VM Snapshot Workflow (Shared VMs)

Shared VMs (no `post_test_restore`) use pre-test snapshots:

**Internal snapshots need the VM SHUT OFF** (pflash firmware + raw NVRAM: a live
`snapshot-create-as` fails with `require QCOW2 nvram format`; verified libvirt
12.8.0, 2026-10-08, claude-test-skill-ijg). Snapshot first, then start.

```bash
# 1. BEFORE tests — VM must be shut off
sudo virsh domstate example-test-vm | grep -q 'shut off' || sudo virsh shutdown example-test-vm
sudo virsh snapshot-create-as example-test-vm pre-test-$(date +%Y%m%d-%H%M%S) \
    --description "Pre-test state before /test run"
sudo virsh start example-test-vm
# 2. RUN tests
# 3. AFTER tests
sudo virsh snapshot-revert example-test-vm <snapshot-name>
# 4. CLEANUP
sudo virsh snapshot-delete example-test-vm <snapshot-name>
```

### Snapshot Types

| Snapshot | Purpose | Lifetime |
| ---------- | --------- | ---------- |
| `pristine-*-YYYY-MM-DD` | Pristine OS + deps, no app (project-specific) | Permanent, authoritative |
| `qa-baseline-YYYY-MM-DD` | QA baseline: app installed + data populated | Permanent (QA VMs only) |
| `clean-install` | Legacy baseline (fresh OS + SSH) | Permanent (fallback) |
| `pre-test-YYYYMMDD-HHMMSS` | State before a specific test run | Deleted after test by Phase 10b; leftovers swept by `/test` Phase 1 (`~/.claude/scripts/vm-pretest-sweep.sh`) |
