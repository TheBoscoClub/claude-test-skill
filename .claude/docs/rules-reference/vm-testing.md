# vm-testing — reference (NOT auto-loaded)

Holds the detail behind `.claude/rules/vm-testing.md`, under the same headings.

## VM Management

```bash
sudo virsh list --all
virt-viewer example-test-vm
sudo virsh snapshot-create-as example-test-vm clean-install --description "Fresh install"   # VM shut off (see below)
sudo virsh snapshot-revert example-test-vm clean-install
# Project pristine snapshots: each project's vm-test-manifest.json ("snapshot", "post_test_restore")
```

## VM Snapshot Workflow (Shared VMs)

**Internal snapshots need the VM SHUT OFF** (pflash firmware + raw NVRAM: a live
`snapshot-create-as` fails with `require QCOW2 nvram format`; verified libvirt
12.8.0, 2026-10-08, claude-test-skill-ijg). Snapshot first, then start.

## Superseded 2026-11-01 (trim review)

Lines removed from the loaded rule because they disagreed with `~/.claude/skills/test-phases/phase-10b-vm-lifecycle.md` (Phase 11 shuts `post_test_restore` VMs down only; revert happens at the next run's start) and carried host paths (now in the gitignored `.claude/rules/local-vm-paths.md`):

- | **Cleanup (Phase 11)** | Running (dirty) | ALWAYS: revert to pristine, shut down, leave shut down |
- Phase 11 reverts and shuts down regardless of who started the VM

## Superseded 2026-11-01 (Phase 11 only shuts post_test_restore VMs down; the revert happens at the next run's start — phase-10b-vm-lifecycle.md:14)

| **Cleanup (Phase 11)** | Running (dirty) | ALWAYS: revert to pristine, shut down, leave shut down |
