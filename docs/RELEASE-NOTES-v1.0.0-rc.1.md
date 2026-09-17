# SKITTLES v1.0.0-rc.1

This is a **release candidate**, not the stable `v1.0.0` release. Real-hardware sign-off is still required on the supported desktop.

## Highlights

SKITTLES is a destructive fresh-install Arch Linux installer scoped to one i7-8700K + RTX 3060 Ti KDE/Wayland desktop. This RC focuses on explicit destructive authorization, LUKS2 encrypted root, two-kernel recovery, conservative privacy/security defaults, current Arch NVIDIA handling, and a local read-only health check.

## Current RC remediation

A real current official Arch ISO exposed a pre-destructive pacman 7 failure because pacman downloads as its configured `DownloadUser` while SKITTLES had placed custom DB/cache state beneath a root-only `0700` temporary parent. The remediation grants traverse-only access to that random parent, preserves pacman `DownloadUser` and sandboxing, runs package sync/resolution before any disk interaction, and makes pre-write failure reporting explicit. No tagged RC exists yet, so the source version remains `1.0.0-rc.1`.

## Hardware target

Supported for release testing only on:

- Intel Core i7-8700K;
- NVIDIA GeForce RTX 3060 Ti;
- x86-64 UEFI;
- Secure Boot disabled;
- unused internal SATA or NVMe installation disk.

Other hardware is unsupported even if the script can be adapted.

## Safety

- No default target disk.
- Whole-disk inventory displays path, size, model, serial and transport.
- Mounted, removable, USB, read-only, swap-backed and LUKS/LVM/RAID-in-use disks are protected.
- Every selected disk requires its own exact `ERASE /dev/...` confirmation.
- Disk identity/size/busy state is revalidated before destructive work.
- A SHA-256 plan digest binds the confirmed version, profile, wipe mode, discard choice and selected disk identities.
- Optional extra-drive wipes begin only after the Arch target installs successfully.

## Security & privacy

- LUKS2 with Argon2id protects ext4 root at rest.
- `/home` resides inside encrypted root and the created home is private.
- Password-authenticated sudo; no SSH server.
- nftables defaults to inbound/forward drop and outbound accept; reload replaces only SKITTLES' table and preserves unrelated rulesets.
- Core-dump processing/storage is disabled and low-risk kernel/filesystem hardening is applied.
- NetworkManager uses `systemd-resolved`; DHCP hostname sending, LLMNR, mDNS, connectivity checking, and compiled-in fallback DNS are disabled by default.
- Wi-Fi scanning uses randomized MAC addresses and saved Wi-Fi connections default to a stable-per-SSID association MAC.
- DNS-over-TLS is **not** enabled; SKITTLES is not a VPN, Tor, or anonymity system.
- Secure Boot is not configured, so the unencrypted ESP/boot chain remains a physical-tampering gap.

## Gaming

The gaming profile adds Steam, 32-bit NVIDIA/Vulkan libraries, GameMode, MangoHud and NTSync. Normal desktop operation keeps adaptive CPU policy; GameMode may request the performance governor and best-effort I/O priority only for participating games. Split-lock mitigation remains enabled (`disable_splitlock=0`). No overclock, fixed GPU clocks, special gaming kernel, global mitigation disabling, or forced global overlay is installed.

## Recovery

Both Arch `linux` and `linux-lts` are installed with matching NVIDIA open kernel modules. GRUB includes the normal UEFI entry and removable fallback path, and its shared command line disables zswap so the configured zram swap is used directly. `docs/RECOVERY.md` documents current-Arch-ISO recovery, LUKS unlock, chroot, package/NVIDIA reinstall, initramfs rebuild, GRUB repair, LTS recovery boot and safe cleanup.

## Automated validation

Public baseline `5b5453bcbc9d6e6ca175adf5c9fa737f050971a1` passed hosted GitHub CI with repository completeness, Bash syntax, ShellCheck 0.9.0, 74/74 tests, repository hygiene, and whitespace checks. The current pacman-preflight remediation expands local coverage to 90/90 and adds a separate current-Arch pacman integration job; that new hosted result is pending publication. The suite includes fail-closed stable sign-off, deterministic-asset regression coverage, adversarial input tests, and recovery-documentation checks. Physical validation remains separate and `NOT TESTED`.

## Known limitations

- Real-hardware RC sign-off is still `NOT TESTED` for both kernels, Wayland/NVIDIA/Vulkan, suspend/resume, networking/firewall, gaming and recovery.
- Numeric performance improvements are not claimed; target-hardware measurements are still required.
- Secure Boot and hibernation are not implemented.
- DNS is not encrypted by SKITTLES.
- Logical zero wiping is not certified SSD/NVMe NAND sanitization.
- The source is licensed under Apache License 2.0; physical release-hardware, recovery, performance, and real-artifact/provenance validation remain pending.

## Verification

Expected release assets are:

```text
skittles-1.0.0-rc.1.tar.gz
skittles-installer-1.0.0-rc.1.sh
SHA256SUMS
```

Verify integrity from the downloaded release directory:

```bash
sha256sum -c SHA256SUMS
```

When GitHub artifact attestations are published, verify provenance against the publishing repository:

```bash
gh attestation verify skittles-1.0.0-rc.1.tar.gz -R 5897151/arch-skittles-installer --signer-workflow 5897151/arch-skittles-installer/.github/workflows/release.yml
gh attestation verify skittles-installer-1.0.0-rc.1.sh -R 5897151/arch-skittles-installer --signer-workflow 5897151/arch-skittles-installer/.github/workflows/release.yml
```

A matching checksum proves the bytes match `SHA256SUMS`; an attestation ties the artifact to the recorded repository/workflow/commit. Neither proves the installer is safe—review the source before running a root-level destructive installer.

## Upgrade note

**Do not run SKITTLES to upgrade an existing SKITTLES installation. It is a destructive fresh installer.** Use normal Arch full upgrades (`pacman -Syu`) and the documented recovery path instead.
