# SKITTLES v1.0.0 release audit

Status: approved for the first stable release, subject to exact-SHA CI and the tag-triggered release workflow.

## Hosted evidence

Validated remediation commit `cc62cd73467701bd1c15a1be5b99af68551647ad` passed GitHub Actions CI run `35285336084`. The run included 92/92 Python tests, Bash syntax, ShellCheck for the installer and generated chroot/doctor programs, repository hygiene, whitespace validation, current-Arch pacman 7 integration, preserved `DownloadUser` sandbox behavior, package availability, and minimal/gaming transaction resolution.

The stable promotion changes the installer only at its version constant and updates release metadata, sign-off policy and four focused tests, bringing local discovery to 96/96 PASS. It requires a new successful CI run on the exact promotion SHA before tagging.

## Current-Arch pacman remediation

The official-ISO failure was caused by pacman 7 download privilege separation. Current Arch configures a low-privilege `DownloadUser`; the earlier SKITTLES preflight placed its custom DB/cache paths beneath a root-only temporary parent. The validated remediation grants ancestor traverse-only access while retaining root ownership of the controlled directories. It does not disable sandboxing, recursively change ownership, or modify the live ISO's pacman configuration.

Package synchronization/resolution and `--check` complete before disk enumeration, credentials or erase confirmation. Failure reporting distinguishes pre-write, post-write and post-install/extra-wipe states.

## Safety and runtime audit

- Destructive targets have no default and require persistent identity plus exact per-disk confirmation.
- The immutable plan binds version, disks, identities, sizes, wipe mode, profile and relevant choices.
- Identity and idle state are revalidated before destructive transitions.
- Passwords stay out of arguments and exported environment state; core dumps are disabled.
- The generated doctor is read-only and does not auto-sudo, repair, upload or collect telemetry.
- The installed system uses encrypted ext4 root, dual kernels, Plasma Wayland, Arch NVIDIA open modules, nftables, NetworkManager/systemd-resolved, PipeWire and bounded zram.
- The gaming profile keeps split-lock mitigation enabled and does not force a permanent performance governor, overclock, fixed GPU clocks or alternate kernel.

No installer behavioral redesign is part of the stable promotion.

## Target-hardware evidence

The supported Intel Core i7-8700K + NVIDIA RTX 3060 Ti system passed the documented clean-install, both-kernel, LUKS, Plasma/Wayland, NVIDIA/Vulkan, network/DNS/firewall/audio/USB, suspend/resume, doctor and gaming runtime checks. A complete `pacman -Syu` transaction and both-kernel reboot path passed.

No package upgrades were available during that `pacman -Syu`, so an actual kernel/NVIDIA package-version transition was not demonstrated.

## Deferred evidence

The owner deferred the formal Arch-ISO recovery drill and performance benchmark matrix for v1.0.0. Recovery procedures remain documented in [Recovery](RECOVERY.md), but their physical execution is not claimed. The benchmark plan remains in [Performance policy](PERFORMANCE.md), but no numeric performance gain or SHA-bound benchmark result is claimed.

## Release engineering policy

The stable workflow consumes `release-signoff.json` through `scripts/check_release_signoff.py`. Executed mandatory gates require `PASS`; only the explicit recovery/performance allowlist may use `DEFERRED`. `NOT TESTED`, `FAIL`, `BLOCKED`, `WARN`, unknown, empty, missing, extra and malformed data remain blocking. Performance SHA evidence is required only when performance measurements are `PASS`, and final release notes must not contain `DRAFT:`.

The release workflow independently checks tag/version agreement, reruns validation, builds deterministic assets, generates and verifies `SHA256SUMS`, creates GitHub artifact attestations, runs the stable sign-off checker, and publishes the release. Public assets and provenance must be verified after publication.

## Limitations

- SKITTLES supports only the documented i7-8700K + RTX 3060 Ti target.
- Secure Boot and hibernation are unsupported.
- DNS is not encrypted by SKITTLES.
- Logical SSD wiping is not certified physical NAND sanitization.
- Arch is rolling release software; future package behavior requires revalidation.
- SKITTLES is destructive and is not an updater or repair tool.
