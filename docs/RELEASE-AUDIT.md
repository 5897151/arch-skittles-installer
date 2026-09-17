# SKITTLES release audit

Status: release candidate audit. This file records the state found before the ordered release-hardening checkpoints. It is not a stable-release sign-off.

## Confirmed issues

- The workspace currently has no owner-authorized software license. Public source without a license is not open-source software; `v1.0.0` is blocked until the owner selects a license.
- The repository is incomplete for a public release: there is no production `README.md`, test suite, CI/release workflow, security policy, contribution guide, recovery guide, or release documentation yet.
- The existing `README.upstream.md` predates current installer behavior. In particular, it describes older package/profile and NVIDIA/power-management behavior, so documentation drift is already present.
- No performance measurements are present. The current permanent `performance` CPU governor is therefore an unmeasured policy choice, not a demonstrated optimization.
- No automated regression suite currently exists in this workspace, so destructive-operation invariants are not yet covered by mocks/tests here.
- No repository-history secret scan can be meaningful beyond the new local baseline because the original project history was not supplied.

## Stale or provisional behavior

- NVIDIA handling is in transition: the script already contains partial 595+ suspend changes, but package choice, suspend services/notifiers, KMS/fbdev settings, both kernel builds, and doctor checks still require one coherent current-source pass before they can be treated as release-ready.
- Networking/privacy is also provisional: NetworkManager and `systemd-resolved` settings were partially added, but their generated configuration, DHCP identity policy, Wi-Fi MAC policy, resolver ownership, and doctor verification have not yet been validated together.
- The installer still forces the CPU `performance` governor persistently at boot and requires that governor during preflight. This must be replaced with a hardware-aware baseline; GameMode should remain the on-demand gaming optimization layer.
- Storage policy (ext4 `noatime`, zram sizing/compression, optional LUKS discards/fstrim) needs a focused review to separate justified defaults from unnecessary tuning.
- The doctor is incomplete as a release diagnostic: it needs a final coherent view of boot/security, NVIDIA, CPU, storage/zram, firewall, resolver, NetworkManager privacy settings, and failed services.

## Release blockers

- Owner-authorized license is missing.
- Current NVIDIA/Arch behavior has not completed the dedicated correctness checkpoint.
- Networking/privacy configuration has not completed generated-config validation.
- CPU/performance policy has not been replaced and measured.
- Destructive-operation, profile, version/config, and generated-config tests are missing.
- CI and release artifact/provenance workflows are missing.
- Production documentation and recovery instructions are missing or stale.
- Release artifacts/checksums have not been built and verified.
- Real-hardware release-candidate installation and recovery testing has not been performed or recorded.

## Hardware-only tests still required

The following must remain `NOT TESTED` until run on the supported Intel Core i7-8700K + RTX 3060 Ti machine from an RC artifact:

- clean install from a current official Arch ISO; repeated LUKS unlocks; cold boot and warm reboot;
- boot `linux` and `linux-lts`, including recovery selection through GRUB;
- Plasma Wayland login/logout, lock/unlock, NVIDIA acceleration, Vulkan, and multi-hour idle;
- CPU-load and GPU-load stability; measured comparison of any shipped performance policy;
- Ethernet/networking, DHCP renewal, DNS through the configured resolver, IPv6 when available, and nftables ordinary-connectivity behavior;
- suspend/resume with the current NVIDIA driver path;
- gaming profile: Steam, Proton, GameMode, MangoHud, NTSync, and 32-bit NVIDIA/Vulkan libraries;
- audio and representative USB devices;
- full package upgrade, kernel update, NVIDIA update, and subsequent boots of both kernels;
- `skittles-doctor` as user and with `sudo` after installation and after updates;
- documented Arch-ISO recovery procedure, including LUKS unlock, chroot, bootloader repair, initramfs rebuild, NVIDIA reinstall, LTS boot, clean unmount, and mapping close;
- if possible, a second clean install using the exact RC release bundle rather than the working tree.
