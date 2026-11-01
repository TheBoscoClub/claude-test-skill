# vm-testing — reference (NOT auto-loaded)

Holds the detail behind `.claude/rules/vm-testing.md`, under the same headings.

## VM Management

```bash
sudo virsh list --all
virt-viewer "$VM"
sudo virsh snapshot-create-as "$VM" clean-install --description "Fresh install"   # VM shut off (see below)
sudo virsh snapshot-revert "$VM" clean-install
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

## Superseded 2026-11-01 (destructive reset paths; bd `claude-test-skill-zy9`)

*Superseded 2026-11-01: reset is revert-only and the only snapshot delete is `delete_pretest_snapshot` (pre-test names only); see bd `claude-test-skill-zy9`.*

- Revert ALWAYS discards the overlay (never `qemu-img commit` — bakes test changes into the base)
- Overlay files are deleted only under directories listed in `paths.vm_storage_dirs`; with that key absent the overlay steps are skipped and only snapshot reverts run

## Superseded 2026-11-01 (VM selection and lifecycle table; bd `claude-test-skill-zy9`)

*Superseded 2026-11-01: VM selection is configured-only (`resolve_test_vm`, phase-10b-vm-lifecycle.md § Test VM Selection) and the startup row reverts a `post_test_restore=true` VM in either state; see bd `claude-test-skill-zy9`.*

- Phase 10a auto-detects VMs with "test" or "dev" in the name.
- | **Before /test** | Shut down + pristine | — |
- | **Startup (Phase 2/3)** | Check state | Running → dirty from interrupted test → force revert to pristine, then start. Shut down → start normally. |
- | **Next /test start** | Shut down (dirty) | Revert to pristine at startup (Phase 2/3/10b), preserving post-test state until then |
