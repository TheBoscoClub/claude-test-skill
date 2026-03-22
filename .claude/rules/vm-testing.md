# Phase V: VM Testing Configuration

## Default Test VM

**example-test-vm**: CachyOS with KDE desktop, the VM's RAM, vCPUs and disk size
- Location: `/var/lib/libvirt/images/example-test-vm.qcow2`
- ISO Location: `/path/to/isos/`
- Auto-Detection: Phase V automatically finds VMs with "test" or "dev" in the name

## Manifest Template

`templates/vm-test-manifest.json` — copy to project root to customize VM testing.

## VM Management

```bash
sudo virsh list --all
sudo virsh start example-test-vm
virt-viewer example-test-vm
sudo virsh snapshot-create-as example-test-vm clean-install --description "Fresh install"
sudo virsh snapshot-revert example-test-vm clean-install
# Project-specific pristine snapshots are defined in each project's vm-test-manifest.json
# (see "snapshot" and "post_test_restore" fields)
```

## VM Exclusivity Rules

VM assignments are defined in `~/.claude/config/project-vm-map.json`. The `exclusive_to` field is a **bidirectional lock**: only the named project may use that VM, and no other project may.

**Example** (generic — actual assignments live in the JSON config):

| VM | Exclusive To | Purpose | Snapshot |
|----|-------------|---------|----------|
| `test-<project>-cachyos` | `<your-project>` | Integration/API/UI testing | `pristine-*` |
| `qa-<project>-cachyos` | `<your-project>` | QA only — released versions, no test runs | `qa-baseline-*` |
| `example-test-vm` | *(none)* | Default for all other projects | — |

**Rules:**
- VMs with `exclusive_to` set are reserved for the named project only. No other project may use them, and the named project must not use other VMs for testing.
- QA VMs (if configured) receive only promoted releases — `/test` phases never run against them.
- All other projects use `example-test-vm` (or any non-exclusive VM for cross-distro testing).

## When Phase V Runs

- Project has `vm-test-manifest.json` with `"enabled": true`
- Project has dangerous operations (PAM, systemd, kernel)
- User explicitly requests `--phase=V`
- Phase 0/1 detects install scripts modifying system-level configs

## VM Lifecycle for `post_test_restore=true` VMs

For exclusive VMs with `post_test_restore=true`, the expected lifecycle is:

| Phase | VM State | Action |
|-------|----------|--------|
| **Before /test** | Shut down + pristine | — |
| **Startup (Phase 0/1)** | Check state | If running → dirty from interrupted test → force revert to pristine, then start. If shut down → start normally. |
| **During testing** | Running | Install, deploy, test |
| **Cleanup (Phase C)** | Running (dirty) | ALWAYS: revert to pristine, shut down, leave shut down |

**Key rules:**
- Revert ALWAYS discards the overlay (never `qemu-img commit` — that bakes test changes into the base)
- Phase C shuts down and reverts regardless of who started the VM
- The VM is left shut down and pristine, ready for the next test run

## VM Snapshot Workflow (Shared VMs)

For shared VMs (no `post_test_restore`), use pre-test snapshots:

```bash
# 1. BEFORE tests: Create pre-test snapshot
sudo virsh snapshot-create-as example-test-vm pre-test-$(date +%Y%m%d-%H%M%S) \
    --description "Pre-test state before /test run"

# 2. RUN tests

# 3. AFTER tests: Revert to pre-test snapshot
sudo virsh snapshot-revert example-test-vm <snapshot-name>

# 4. CLEANUP: Delete the temporary pre-test snapshot
sudo virsh snapshot-delete example-test-vm <snapshot-name>
```

### Snapshot Types

| Snapshot | Purpose | Lifetime |
|----------|---------|----------|
| `pristine-*-YYYY-MM-DD` | Pristine OS + deps, no app installed (project-specific) | Permanent, authoritative |
| `qa-baseline-YYYY-MM-DD` | QA baseline with app installed + data populated | Permanent (QA VMs only) |
| `clean-install` | Legacy baseline (fresh OS + SSH) | Permanent (fallback) |
| `pre-test-YYYYMMDD-HHMMSS` | State before specific test run | Deleted after test |
