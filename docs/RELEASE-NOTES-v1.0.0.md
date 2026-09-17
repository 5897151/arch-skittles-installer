<!-- DRAFT: remove this marker only after every stable release gate is recorded PASS. -->
# SKITTLES v1.0.0

## Highlights

SKITTLES `v1.0.0` is the first stable release of a hardware-scoped, destructive fresh-install Arch Linux installer for one i7-8700K + RTX 3060 Ti KDE/Wayland desktop. It is designed around explicit disk authorization, LUKS2 encrypted root, Linux + Linux LTS recovery, conservative network/privacy defaults, current Arch NVIDIA open-module handling, and auditable local diagnostics.

## Hardware target

Supported hardware for this release:

- Intel Core i7-8700K;
- NVIDIA GeForce RTX 3060 Ti;
- x86-64 UEFI firmware;
- Secure Boot disabled;
- internal SATA or NVMe installation storage.

Other hardware is unsupported, even if the script can technically be adapted.

## Safety

- No default installation target.
- Whole-disk inventory with size, model, serial, transport and protection state.
- Mounted/removable/USB/read-only/in-use devices are protected from selection.
- Exact per-drive `ERASE /dev/...` confirmations complete before writes begin.
- Disk identity, size and busy state are revalidated before destructive operations.
- A SHA-256 plan digest refuses post-confirmation plan changes.
- Extra wipe-only disks are touched only after the target OS installs successfully.
- Cleanup only releases mounts/mappings owned by the installer.

## Security & privacy

- LUKS2 with Argon2id encrypted ext4 root.
- Private created user home and password-authenticated sudo.
- Default-drop inbound/forward nftables policy, table-scoped reload ownership, and no SSH server.
- Restricted kernel diagnostics, disabled coredump processing/storage, and conservative protected-link/ASLR/BPF/kexec/redirect settings.
- NetworkManager + `systemd-resolved` with DHCP hostname suppression, stable pseudonymous DHCP IDs, Wi-Fi scan randomization, stable-per-SSID association MAC, IPv6 privacy, LLMNR/mDNS off, connectivity checks off, and no public fallback resolver configured.
- Bounded journal retention and Baloo indexing disabled for the created user.
- LUKS discard is off by default and explicitly opt-in.

These choices improve privacy but do not provide anonymity. DNS-over-TLS, Tor and VPN functionality are not provided. Secure Boot is not configured, so root encryption does not authenticate the boot chain.

## Gaming

The gaming profile adds Steam, 32-bit NVIDIA/Vulkan libraries, GameMode, MangoHud and NTSync. GameMode is an on-demand game-session optimization layer with explicit I/O priority and session-scoped split-lock behavior; SKITTLES does not force a permanent maximum-performance governor, CPU/GPU overclock, fixed GPU clocks, alternate gaming kernel, or global mitigation disable.

## Recovery

`linux-lts` is installed alongside `linux`. The release ships detailed Arch-ISO recovery instructions covering safe device identification, LUKS unlock, mounts, chroot networking, package/NVIDIA reinstall, initramfs rebuild, GRUB repair, LTS selection, journal inspection, LUKS-header backup and clean teardown.

## License

SKITTLES is licensed under the Apache License 2.0.

## Release gating

Stable publication requires the complete machine-readable hardware/recovery/performance sign-off to be `PASS`, SHA-bound performance evidence, green exact-source CI, and removal of this document's `DRAFT:` marker. Automated/static validation alone is not a substitute for those physical gates.

## Known limitations

- Hardware-specific; no generic installer support is claimed.
- Secure Boot is not implemented for this release.
- Hibernation is not configured.
- DNS is not encrypted by SKITTLES.
- Logical zero wiping does not guarantee physical sanitization of SSD/NVMe spare/remapped NAND.
- Arch is a rolling distribution; future package changes can require manual intervention or a SKITTLES maintenance release.
- LUKS protects a locked powered-off volume, not an already unlocked compromised session.

## Verification

Expected release assets:

```text
skittles-1.0.0.tar.gz
skittles-installer-1.0.0.sh
SHA256SUMS
```

Verify integrity:

```bash
sha256sum -c SHA256SUMS
```

Verify GitHub artifact provenance against the publishing repository:

```bash
gh attestation verify skittles-1.0.0.tar.gz -R 5897151/arch-skittles-installer --signer-workflow 5897151/arch-skittles-installer/.github/workflows/release.yml
gh attestation verify skittles-installer-1.0.0.sh -R 5897151/arch-skittles-installer --signer-workflow 5897151/arch-skittles-installer/.github/workflows/release.yml
```

Checksums detect mismatched bytes. GitHub provenance ties an artifact to the recorded repository/workflow/commit. Source review and release-test evidence are separate requirements.

## Upgrade note

**Do not run SKITTLES to upgrade an existing SKITTLES installation. It is a destructive fresh installer.** Update installed systems with normal Arch full upgrades and use `docs/RECOVERY.md` for recovery.
