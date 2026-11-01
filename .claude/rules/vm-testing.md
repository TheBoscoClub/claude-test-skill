# Phase 10a: VM Testing Configuration

Detail, incidents and reasoning per section: `.claude/docs/rules-reference/vm-testing.md` (same headings).

## Default Test VM

**example-test-vm**: an existing libvirt VM. Disk image and install ISOs: the host's libvirt image and ISO directories (real paths in the gitignored `.claude/rules/local-vm-paths.md`). Phase 10a auto-detects VMs with "test" or "dev" in the name.

## Manifest Template

`templates/vm-test-manifest.json` — copy to project root to customize VM testing.

## VM Management

Basics: `sudo virsh list --all|start|snapshot-create-as|snapshot-revert`, `virt-viewer example-test-vm`. Project pristine snapshots: each project's `vm-test-manifest.json` (`"snapshot"`, `"post_test_restore"`).

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
| **Cleanup (Phase 11)** | Running (dirty) | Shut down, leave shut down (`post_test_restore=true` VMs: no revert here) |
| **Next /test start** | Shut down (dirty) | Revert to pristine at startup (Phase 2/3/10b), preserving post-test state until then |

- Revert ALWAYS discards the overlay (never `qemu-img commit` — bakes test changes into the base)
- Phase 11 shuts down `post_test_restore=true` VMs regardless of who started them (it does not revert; the revert happens at the next start); shared VMs are shut down only if `/test` started them

## VM Snapshot Workflow (Shared VMs)

Shared VMs (no `post_test_restore`) use pre-test snapshots:

**Internal snapshots need the VM SHUT OFF** (a live `snapshot-create-as` fails with `require QCOW2 nvram format`). Snapshot first, then start.

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
