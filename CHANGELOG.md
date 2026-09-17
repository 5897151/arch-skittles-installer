# Changelog

SKITTLES follows Semantic Versioning. This changelog is structured after Keep a Changelog and records release-relevant behavior rather than formatting churn.

## [Unreleased]

### Fixed (local regression coverage; hardware validation pending)

- Establish the installed resolver symlink after `arch-chroot` releases its temporary resolver bind mount, preserving live DNS throughout configuration.
- Recheck target identity and idle state between completion of the wipe and partition creation.
- Report failed-service query errors as failures instead of an empty successful result; skip the graphical-session check from a text console.


### Known Issues

- Stable release is blocked until an owner-authorized software license is selected.
- Real i7-8700K + RTX 3060 Ti release-candidate installation, suspend/resume, recovery, gaming, update, and both-kernel sign-off are not yet recorded.
- Performance changes have no target-hardware benchmark results yet.

## [1.0.0-rc.1] - 2026-09-17

### Added

- Hardware-scoped preflight for the Intel Core i7-8700K and known RTX 3060 Ti PCI IDs.
- Minimal and gaming profiles, both with `linux` plus `linux-lts` recovery coverage.
- `--demo`, `--check`, `--packages`, explicit wipe modes, and opt-in LUKS discard behavior.
- Whole-disk inventory with protection reasons, exact per-disk erase phrases, disk identity revalidation, and a confirmed-plan digest.
- LUKS2/Argon2id encrypted ext4 root and hardened ESP mount options.
- Plasma Wayland, NetworkManager + `systemd-resolved`, PipeWire, nftables, bounded zram, and `skittles-doctor`.
- Privacy defaults for DHCP identity, Wi-Fi MAC handling, IPv6 privacy, LLMNR/mDNS, connectivity checking, logs, Baloo, and crash dumps.
- Automated tests covering CLI/profile decisions, destructive-operation mocks, exact-byte wiping to an ordinary temporary file, generated configuration, and release-version invariants.
- SHA-pinned GitHub CI/release workflows with checksums, artifact provenance, release gating, issue/PR templates, and focused Dependabot updates.
- Curated RC/stable release notes plus copy/paste GitHub repository metadata.

### Changed

- NVIDIA packaging uses Arch's prebuilt `nvidia-open` and `nvidia-open-lts` packages instead of DKMS for the two supported kernels.
- NVIDIA 595+ suspend handling uses the packaged kernel suspend-notifier path; legacy NVIDIA suspend/hibernate/resume services are disabled.
- Explicit NVIDIA DRM KMS/fbdev overrides were removed; the doctor verifies the packaged runtime defaults instead.
- Permanent CPU `performance` governor forcing was removed. Normal use keeps adaptive kernel/firmware policy; the gaming profile retains on-demand GameMode behavior.
- Zram follows a conservative half-RAM size capped at 4 GiB and leaves compression/priority to generator/kernel defaults.
- Forced ext4 `noatime` was removed in favor of normal ext4 relatime behavior.
- NetworkManager and `systemd-resolved` are configured as one coherent resolver/privacy path.

### Security

- nftables configuration is syntax-checked before networking depends on it.
- Core-dump processing/storage is disabled and low-risk kernel/filesystem hardening is explicit.
- `/boot` is mounted with `nosuid,nodev,noexec` and restrictive FAT masks.
- Destructive write helpers require an approved immutable plan and refuse disks not bound to that plan.

### Fixed

- Removed stale text claiming a permanent performance governor after the policy was changed.
- Removed older NVIDIA power-management assumptions that no longer match current open-module 595+ behavior.

### Known Issues

- Secure Boot remains unsupported and must be disabled.
- Hibernation is not configured.
- Real-hardware release sign-off remains `NOT TESTED` until the RC artifact is installed and exercised on the supported desktop.
