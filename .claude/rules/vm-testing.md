# Phase 10a: VM Testing Configuration

## Default Test VM

**test-vm-cachyos**: CachyOS + KDE, 4GB RAM, 4 vCPUs, 40GB disk. Image `/var/lib/libvirt/images/test-vm-cachyos.qcow2`; ISOs `/hddRaid1/ISOs/`. Phase 10a auto-detects VMs with "test" or "dev" in the name.

## Manifest Template

`templates/vm-test-manifest.json` — copy to project root to customize VM testing.

## VM Management

```bash
sudo virsh list --all
sudo virsh start test-vm-cachyos
virt-viewer test-vm-cachyos
sudo virsh snapshot-create-as test-vm-cachyos clean-install --description "Fresh install"   # VM shut off (see below)
sudo virsh snapshot-revert test-vm-cachyos clean-install
# Project pristine snapshots: each project's vm-test-manifest.json ("snapshot", "post_test_restore")
```

## VM Exclusivity Rules

Assignments live in `~/.claude/config/project-vm-map.json`. `exclusive_to` is a **bidirectional lock**: only the named project may use that VM, and that project must not test on other VMs.

| VM (generic pattern) | Exclusive To | Purpose | Snapshot |
| ---- | ------------- | --------- | ---------- |
| `test-<project>-cachyos` | `<your-project>` | Integration/API/UI testing | `pristine-*` |
| `qa-<project>-cachyos` | `<your-project>` | QA only — released versions, no test runs | `return-to-base-*` |
| `test-vm-cachyos` | *(none)* | Default for all other projects | — |

- QA VMs receive only promoted releases — `/test` phases never run against them.
- All other projects use `test-vm-cachyos` (or any non-exclusive VM for cross-distro testing).

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
sudo virsh domstate test-vm-cachyos | grep -q 'shut off' || sudo virsh shutdown test-vm-cachyos
sudo virsh snapshot-create-as test-vm-cachyos pre-test-$(date +%Y%m%d-%H%M%S) \
    --description "Pre-test state before /test run"
sudo virsh start test-vm-cachyos
# 2. RUN tests
# 3. AFTER tests
sudo virsh snapshot-revert test-vm-cachyos <snapshot-name>
# 4. CLEANUP
sudo virsh snapshot-delete test-vm-cachyos <snapshot-name>
```

### Snapshot Types

| Snapshot | Purpose | Lifetime |
| ---------- | --------- | ---------- |
| `pristine-*-YYYY-MM-DD` | Pristine OS + deps, no app (project-specific) | Permanent, authoritative |
| `return-to-base-YYYY-MM-DD` | QA baseline: app installed + data populated | Permanent (QA VMs only) |
| `clean-install` | Legacy baseline (fresh OS + SSH) | Permanent (fallback) |
| `pre-test-YYYYMMDD-HHMMSS` | State before a specific test run | Deleted after test |
