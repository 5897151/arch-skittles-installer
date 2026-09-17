# Testing and Release Sign-off

Automated tests are necessary but insufficient for SKITTLES because the release target includes destructive storage behavior, UEFI firmware, a specific NVIDIA GPU, suspend/resume, and real network hardware.

## Safe automated tests

Run from the repository root as an ordinary user:

```bash
bash -n skittles-installer.sh
shellcheck skittles-installer.sh
python3 -m unittest discover -s tests -v
git diff --check
```

The Python suite currently covers CLI/help/version behavior, profile package decisions, username/partition helper logic, disk-protection reasons, numeric menu parsing, plan-digest binding, unauthorized-drive refusal, extra-wipe gating, generated config decisions, and doctor/config coverage.

Destructive tools are mocked. The zero-wipe byte-count regression uses real `dd` only against an ordinary temporary file and verifies the exact resulting byte length. Tests must never discover, format, mount, partition, wipe, or overwrite a real block device.

### Current local status

- `bash -n`: PASS
- Python/unit consistency suite: PASS (46 tests after release-metadata and stable-gate checks)
- `git diff --check`: PASS
- ShellCheck: **BLOCKED in the current build container** because the executable is not installed and the container cannot retrieve it. `.github/workflows/ci.yml` runs ShellCheck on GitHub's Ubuntu 24.04 hosted runner; that remote CI run is still required before release.

## Virtual-machine tests

A VM can validate generic control flow without claiming target hardware support. Appropriate VM checks include:

- UEFI boot of the installed GRUB layout;
- LUKS unlock and ext4 root mounting;
- main/LTS kernel menu entries;
- generated services/config files;
- failure cleanup and reboot behavior;
- recovery-document procedure mechanics using disposable virtual disks.

A VM does **not** prove RTX 3060 Ti NVIDIA acceleration, current NVIDIA suspend behavior, i7-8700K power policy, physical firmware NVRAM behavior, or real SATA/NVMe wipe/sanitize properties.

## Required real-hardware tests

Use the exact RC release artifact on the supported i7-8700K + RTX 3060 Ti system. Record Arch ISO date, firmware version/state, disk model, profile, SKITTLES version/tag/commit, and package versions.

At minimum test:

- clean install from current verified Arch ISO;
- cold boot and warm reboot;
- repeated LUKS unlocks;
- `linux` and `linux-lts` boots;
- Plasma Wayland login/logout and screen lock/unlock;
- NVIDIA module load, `nvidia-smi`, Vulkan, and sustained GPU load;
- multi-hour idle and sustained CPU load;
- Ethernet, DHCP renewal, DNS via `systemd-resolved`, IPv6 if available, and ordinary connectivity through nftables;
- audio and representative USB devices;
- suspend and resume, including repeated cycles;
- gaming profile: Steam, Proton game, GameMode, MangoHud, NTSync, 32-bit Vulkan/NVIDIA;
- package full upgrade, kernel update, NVIDIA update, then both-kernel boots;
- `skittles-doctor` as user and root before/after updates;
- complete Arch-ISO recovery path from [RECOVERY.md](RECOVERY.md);
- if possible, a second clean install from the exact release artifact rather than a working-tree copy.

## Release sign-off table

Do not change `NOT TESTED` to `PASS` without a recorded run on the target hardware.

| Test | `linux` | `linux-lts` |
| --- | --- | --- |
| Boot | NOT TESTED | NOT TESTED |
| LUKS unlock | NOT TESTED | NOT TESTED |
| Plasma Wayland | NOT TESTED | NOT TESTED |
| NVIDIA module / `nvidia-smi` | NOT TESTED | NOT TESTED |
| Vulkan | NOT TESTED | NOT TESTED |
| Ethernet / DHCP / DNS | NOT TESTED | NOT TESTED |
| nftables ordinary connectivity | NOT TESTED | NOT TESTED |
| Audio / USB | NOT TESTED | NOT TESTED |
| Suspend / resume | NOT TESTED | NOT TESTED |
| Post-update boot | NOT TESTED | NOT TESTED |
| `skittles-doctor` | NOT TESTED | NOT TESTED |

Gaming profile additional sign-off:

| Test | Status |
| --- | --- |
| Steam starts/signs in | NOT TESTED |
| Proton game launches | NOT TESTED |
| 32-bit NVIDIA/Vulkan | NOT TESTED |
| GameMode active for launched game | NOT TESTED |
| MangoHud | NOT TESTED |
| NTSync | NOT TESTED |

Recovery sign-off:

| Test | Status |
| --- | --- |
| Unlock/mount/chroot from current Arch ISO | NOT TESTED |
| Reinstall both kernels/NVIDIA packages | NOT TESTED |
| Rebuild initramfs | NOT TESTED |
| Repair GRUB normal + fallback paths | NOT TESTED |
| Boot `linux-lts` recovery entry | NOT TESTED |
| Clean unmount + close mapping | NOT TESTED |
