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
```

## When Phase V Runs

- Project has `vm-test-manifest.json` with `"enabled": true`
- Project has dangerous operations (PAM, systemd, kernel)
- User explicitly requests `--phase=V`
- Phase 0/1 detects install scripts modifying system-level configs

## VM Snapshot Workflow (MANDATORY)

All VM-isolated tests MUST follow this snapshot lifecycle:

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
| `clean-install` | Permanent baseline (fresh OS + SSH) | Permanent |
| `pre-test-YYYYMMDD-HHMMSS` | State before specific test run | Deleted after test |
