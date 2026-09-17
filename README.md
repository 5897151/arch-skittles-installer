# SKITTLES 🌈

[![CI](https://github.com/5897151/arch-skittles-installer/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/5897151/arch-skittles-installer/actions/workflows/ci.yml)
[![License: Apache-2.0](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)
![Status: v1.0.0 stable](https://img.shields.io/badge/status-v1.0.0_stable-brightgreen)

> A safety-first, encrypted Arch Linux fresh installer for one deliberately narrow gaming desktop: Intel Core i7-8700K + NVIDIA RTX 3060 Ti, KDE Plasma/Wayland, LUKS2/ext4, dual kernels, privacy-conscious networking, and an optional Steam/Proton stack.

| Validation gate | Current status |
| --- | --- |
| **HOSTED CI** | **PASS** — run `35285336084` on validated remediation commit `cc62cd73467701bd1c15a1be5b99af68551647ad` |
| **CURRENT-ARCH PACMAN 7 PREFLIGHT** | **PASS** with `DownloadUser` and sandbox policy preserved |
| **TARGET-HARDWARE FRESH INSTALL** | **PASS** — i7-8700K + RTX 3060 Ti, gaming profile |
| **`linux` + `linux-lts` BOOT** | **PASS** — `7.2.6-arch2-1` + `6.18.52-1-lts` during physical validation |
| **NVIDIA / WAYLAND / VULKAN** | **PASS** on both supported kernels |
| **SUSPEND / RESUME** | **PASS** on both supported kernels; NVIDIA/DNS remained healthy after resume |
| **NETWORK / DNS / NFTABLES / AUDIO** | **PASS** on the target machine |
| **STEAM / PROTON / GAMEMODE / NTSYNC** | **PASS — technical runtime path** (Half-Life process on NVIDIA, GameMode active, NTSync loaded) |
| **`pacman -Syu` + BOTH-KERNEL REBOOT** | **PASS** for the transaction/reboot path; no package upgrades were available |
| **ARCH-ISO RECOVERY DRILL** | **DEFERRED / NOT CLAIMED** |
| **FORMAL PERFORMANCE MATRIX** | **DEFERRED / NOT CLAIMED** — no benchmark gain claims are made |
| **STABLE v1.0.0** | **APPROVED** — first stable release |

Current source version: **`1.0.0`** — the first stable release. Hosted CI includes Ubuntu validation plus a current-Arch pacman integration path. Real target-hardware validation covers the normal boot, graphics, suspend, network/firewall/audio, update-transaction, and gaming-runtime paths listed above; deferred recovery/performance gates remain explicitly unclaimed.

> [!WARNING]
> **SKITTLES is destructive. Selected disks are erased.** It is a fresh-install tool—not an updater, repair utility, migration tool, or generic Arch installer. Never rerun it to update or repair an installed system.

## What SKITTLES builds

SKITTLES installs a deliberately narrow Arch Linux desktop:

- Intel Core **i7-8700K**
- NVIDIA **RTX 3060 Ti** with Arch's `nvidia-open` + `nvidia-open-lts` packages
- x86-64 **UEFI**, with **Secure Boot disabled**
- **KDE Plasma / Wayland** desktop
- **LUKS2 + Argon2id** encrypted root on **ext4**
- **GRUB** with both `linux` and `linux-lts`
- NetworkManager + `systemd-resolved`
- nftables default-drop inbound/forward firewall
- PipeWire audio
- bounded zram swap
- local read-only `skittles-doctor` diagnostics

The optional `gaming` profile adds Steam, 32-bit NVIDIA/Vulkan support, GameMode, MangoHud, and NTSync support.

| Capability | Minimal | Gaming |
| --- | :---: | :---: |
| KDE Plasma / Wayland | ✓ | ✓ |
| `linux` + `linux-lts` | ✓ | ✓ |
| NVIDIA open kernel modules | ✓ | ✓ |
| LUKS2 + ext4 | ✓ | ✓ |
| nftables | ✓ | ✓ |
| Steam | — | ✓ |
| 32-bit NVIDIA/Vulkan | — | ✓ |
| GameMode | — | ✓ |
| MangoHud | — | ✓ |
| NTSync autoload | — | ✓ |

SKITTLES intentionally does not install an SSH server, AUR helper, browser, office suite, hibernation setup, overclocking tools, alternate gaming kernel, or a second firewall manager.

## Supported hardware and prerequisites

This release is intentionally hardware-scoped. Use it only with:

- Intel Core **i7-8700K**
- NVIDIA GeForce **RTX 3060 Ti**
- x86-64 firmware booted in **UEFI** mode with writable EFI variables
- **Secure Boot disabled**; SKITTLES does not sign its boot chain
- a current official Arch Linux installation ISO
- working Internet access, DNS, and synchronized time
- an unused internal **SATA/SCSI-style or NVMe** target disk of at least 32 GiB
- a local interactive console; installation over SSH is refused

Other hardware is unsupported even if the script could be adapted. USB/removable media is protected from installation selection by design.

## Disk-safety model

There is no default target disk. SKITTLES inventories whole disks and shows device path, size, model, serial, transport, and any protection reason before a target can be chosen.

Destructive controls include:

- no preselected target;
- mounted, read-only, removable, USB, active-swap, and LUKS/LVM/RAID-in-use disks are protected;
- every selected disk must expose a persistent serial or WWN and requires its own exact **`ERASE /dev/...`** confirmation;
- all confirmations finish before the first destructive write;
- the confirmed plan is SHA-256-bound to the selected paths, identities, sizes, wipe mode, profile, and related choices;
- device identity and idle state are revalidated before destructive writes and again at critical target transitions;
- partition parents are verified before formatting/encryption;
- extra wipe-only disks are erased only **after** the target Arch installation succeeds;
- cleanup only releases mounts/mappings created by SKITTLES.

Do not hot-plug storage while installation is running. See [the security model](docs/SECURITY-MODEL.md) for the threat model and limits.

## Security and privacy defaults

SKITTLES favors conservative, auditable defaults rather than aggressive hardening claims:

- LUKS2/Argon2id encrypted root; `/home` lives inside it;
- created user home mode `0700`;
- password-authenticated `sudo`, no passwordless wheel rule;
- nftables input/forward **drop**, output **accept**, with reload ownership limited to `table inet skittles`;
- no SSH server;
- coredump storage/processing disabled;
- conservative dmesg, pointer, ptrace, ASLR, unprivileged-BPF/kexec, redirect, and protected-link sysctls;
- `/boot` FAT32 ESP mounted with `nosuid,nodev,noexec` and restrictive masks;
- DHCP hostname sending disabled;
- stable pseudonymous DHCP identifiers where supported;
- randomized Wi-Fi scan MAC and stable-per-SSID association MAC;
- IPv6 privacy addressing enabled;
- LLMNR/mDNS and NetworkManager connectivity probing disabled;
- bounded persistent journal retention and Baloo indexing disabled;
- LUKS discard/TRIM opt-in only.

These settings improve privacy; they do **not** provide anonymity. DNS uses `systemd-resolved` with network-provided resolvers, DNS-over-TLS disabled, and no configured public fallback resolver. SKITTLES is not Tor or a VPN. See [Privacy](docs/PRIVACY.md).

Encryption also does not provide boot integrity: GRUB, kernels, and initramfs on the ESP are unsigned in this release. Secure Boot must remain disabled.

## Performance policy

SKITTLES does not disable CPU vulnerability mitigations, overclock CPU/GPU hardware, force permanent maximum clocks, install a special gaming kernel, or claim unmeasured FPS/latency gains.

Normal desktop use leaves CPU policy adaptive. The gaming profile lets GameMode request the `performance` governor only for participating game sessions and restore the original policy afterward. GameMode is explicitly configured **not** to disable the kernel split-lock mitigation. Zram is bounded at half RAM up to 4 GiB; ext4 keeps normal relatime behavior.

Formal performance benchmarking is deferred for v1.0.0. SKITTLES makes no unmeasured FPS, latency, power, or throughput improvement claims. The measurement matrix remains documented in [Performance validation](docs/PERFORMANCE.md) for anyone who wants to execute it later.

## Safe inspection

Preview the UI using fictional drives only:

```bash
bash skittles-installer.sh --demo
```

Inspect the explicit package sets without root or network access:

```bash
bash skittles-installer.sh --packages
bash skittles-installer.sh --profile=gaming --packages
```

Run the non-destructive preflight from the official Arch ISO on supported hardware:

```bash
bash skittles-installer.sh --check
```

`--check` is storage-independent: it performs environment/hardware/firmware checks, DNS/time validation, a real pacman database synchronization, and complete package resolution using temporary package metadata, then exits **before enumerating or selecting disks**. It does not collect credentials, request erase confirmations, partition, format, mount the target, or install Arch.

For the next official-ISO regression check, use the gaming profile that originally exposed the failure:

```bash
bash skittles-installer.sh --check --profile=gaming
```

A successful run must synchronize repositories and resolve every gaming-profile package without `core.db.part` permission errors and without any disk writes.

## Installation

1. Download a current official Arch Linux ISO and verify its signature using the current Arch instructions.
2. Boot the ISO in UEFI mode with Secure Boot disabled; establish networking and correct time.
3. Transfer a reviewed SKITTLES source tree or verified GitHub release asset. **Do not use `curl ... | bash`.**
4. For a published release, verify `SHA256SUMS` and GitHub artifact provenance as documented in [Release process](docs/RELEASE.md).
5. Review `skittles-installer.sh`, especially drive selection, `clear_disk`, partitioning, encryption, and chroot configuration.
6. Run `bash skittles-installer.sh --check --profile=gaming`; it must finish package synchronization/resolution before any disk interaction.
7. Only after that preflight passes, run `bash skittles-installer.sh`, choose a profile and disks, enter credentials, and type every exact erase confirmation.
8. After installation completes, remove the ISO and reboot manually.

## Command-line options

Tests keep this table aligned with `bash skittles-installer.sh --help`.

| Option | Meaning |
| --- | --- |
| `--profile=minimal` | KDE/Wayland profile with both supported kernels. |
| `--profile=gaming` | Adds Steam, 32-bit NVIDIA/Vulkan, GameMode, MangoHud, and NTSync. |
| `--packages` | Print the explicit package list and exit. |
| `--check` | Non-destructive preflight/package-resolution path. |
| `--wipe=zero` | Default logical zero overwrite of selected drives' addressable bytes. |
| `--wipe=signatures` | Faster signature/table cleanup; not secure erasure. |
| `--allow-discards` | Opt in to LUKS discard plus weekly `fstrim.timer`. |
| `--demo` | Fictional-drive UI preview; no probing or writes. |
| `--version` | Print installer version. |
| `--help`, `-h` | Show help. |

### SSD wiping limits

`--wipe=zero` is deterministic logical overwrite, not certified SSD/NVMe sanitization. Remapped blocks, spare/over-provisioned NAND, and controller behavior can preserve data outside the host-addressable range. `--wipe=signatures` removes known signatures and partition metadata only.

For disposal-grade sanitization, use the exact drive vendor's documented secure-erase/sanitize process. SKITTLES deliberately does not guess ATA Secure Erase or NVMe Sanitize commands.

## First boot and updates

Run the read-only diagnostics first:

```bash
skittles-doctor
sudo skittles-doctor
```

`skittles-doctor` does not upload telemetry, change settings, repair the machine, or invoke `sudo` automatically.

Update normally with complete Arch transactions:

```bash
sudo pacman -Syu
```

Read [Arch Linux news](https://archlinux.org/news/) before upgrades. Never use SKITTLES as an updater. If the primary kernel fails after an update, boot `linux-lts` from GRUB and use the documented [recovery procedure](docs/RECOVERY.md).

## Automated validation versus release validation

Validated remediation commit `cc62cd73467701bd1c15a1be5b99af68551647ad` passed hosted CI run `35285336084`, including **92/92 Python tests**, the Ubuntu job, and the current-Arch integration job. The Arch job exercises the real pacman 7 `DownloadUser` preflight with the live sandbox policy preserved, plus minimal/gaming package resolution and generated-script ShellCheck. The stable promotion adds four narrowly scoped release-policy/version tests, bringing local discovery to **96/96 PASS**; exact-source hosted CI is required again before tagging.

The automated suite covers CLI/profile behavior, generated configuration, destructive-operation mocks, plan/identity guards, signal/failure-phase behavior, credential transport, release prerequisites, fail-closed stable gating, deterministic release assets, repository hygiene, documentation consistency, recovery guidance, and current-Arch package integration. The physical-validation fixes add regression coverage for GRUB recovery command lines, current Arch's `nftables.service` oneshot semantics, and root-only mmap-ASLR diagnostics.

Real target-hardware evidence now exists for a clean gaming-profile install, both kernels, Plasma Wayland, NVIDIA/Vulkan, suspend/resume on both kernels, Ethernet/DNS/nftables, PipeWire, zram, GameMode/NTSync, the Steam/Proton runtime path, and a complete `pacman -Syu` transaction followed by successful boots on both kernels. The observed `pacman -Syu` had no package upgrades available, so it does **not** prove migration across an actual kernel/NVIDIA version change.

`release-signoff.json` remains fail-closed. Executed mandatory gates are `PASS`; only the explicit Arch-ISO recovery and formal performance allowlist may be `DEFERRED`. Neither deferred area is represented as PASS. See [Testing and release sign-off](docs/TESTING.md) and [Release decision](docs/RELEASE-DECISION.md).

## Recovery model

Both `linux` and `linux-lts` are installed. The recovery guide covers Arch-ISO device identification, LUKS unlock, mounting/chroot, kernel/NVIDIA reinstall, initramfs rebuild, GRUB repair, logs, LUKS-header backup, clean teardown, and LTS recovery boot.

The procedure is documented, but the owner deferred the physical Arch-ISO recovery drill for v1.0.0. No recovery-execution PASS is claimed. See [Recovery](docs/RECOVERY.md).

## Known limitations

- Only the i7-8700K + RTX 3060 Ti target is supported.
- Secure Boot is unsupported for this release and must be disabled.
- Hibernation is not configured.
- Clean install, both-kernel boot, NVIDIA/Wayland/Vulkan, suspend/resume, networking/DNS/firewall/audio, update-transaction/reboot, and the technical Steam/Proton/GameMode/NTSync runtime path have been exercised on the supported hardware.
- The Arch-ISO recovery drill and formal performance benchmark matrix are deferred and are not claimed as PASS.
- The observed `pacman -Syu` had no package upgrades available, so survival across an actual kernel/NVIDIA package-version transition remains unproven.
- DNS is not encrypted by SKITTLES.
- Logical SSD wiping is not certified NAND sanitization.
- Arch is rolling release software; future package behavior can invalidate assumptions and requires revalidation.

## Documentation

- [Architecture](docs/ARCHITECTURE.md)
- [Security model](docs/SECURITY-MODEL.md)
- [Privacy](docs/PRIVACY.md)
- [Recovery](docs/RECOVERY.md)
- [Testing and physical sign-off](docs/TESTING.md)
- [Performance validation](docs/PERFORMANCE.md)
- [Release process](docs/RELEASE.md)
- [Release audit](docs/RELEASE-AUDIT.md)
- [Current release decision](docs/RELEASE-DECISION.md)
- [License decision](docs/LICENSE-OPTIONS.md)

## Security reports and contributions

Read [CONTRIBUTING.md](CONTRIBUTING.md) before changing destructive, cryptographic, boot, sudo, firewall, privacy, or performance behavior. Report security-sensitive issues according to [SECURITY.md](SECURITY.md); do not publish exploit details that could enable destructive-target bypasses.

## License

SKITTLES is licensed under the **Apache License 2.0**. See [LICENSE](LICENSE) and the project-specific [license decision record](docs/LICENSE-OPTIONS.md).
