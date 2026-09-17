# SKITTLES

[![CI](https://github.com/5897151/arch-skittles-installer/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/5897151/arch-skittles-installer/actions/workflows/ci.yml)

> Safety-first, encrypted Arch Linux fresh installer for one specific Intel Core i7-8700K + NVIDIA RTX 3060 Ti KDE Plasma/Wayland desktop.

| Release gate | Current status |
| --- | --- |
| **AUTOMATED VALIDATION** | **PASS** |
| **HOSTED TEST SUITE** | **68/68 PASS** |
| **PHYSICAL RELEASE-HARDWARE VALIDATION** | **PENDING / NOT TESTED** |
| **STABLE v1.0.0** | **NOT YET RELEASED** |

Current source version: **`1.0.0-rc.1`** — release candidate, not stable. Automated CI is green, but the release candidate still needs physical i7-8700K + RTX 3060 Ti installation, runtime, update, recovery, and performance validation before stable promotion.

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

This RC is intentionally hardware-scoped. Use it only with:

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
- every selected disk requires its own exact **`ERASE /dev/...`** confirmation;
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

Normal desktop use leaves CPU policy adaptive. The gaming profile lets GameMode request the `performance` governor only for participating game sessions and restore the original policy afterward. Zram is bounded at half RAM up to 4 GiB; ext4 keeps normal relatime behavior.

Performance claims remain blocked until the documented target-hardware measurements are completed. See [Performance validation](docs/PERFORMANCE.md).

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

`--check` performs drive inventory/selection, hardware and firmware checks, DNS/time checks, and package resolution using temporary package metadata. It does not collect credentials, request erase confirmations, partition, format, mount the target, or install Arch.

## Installation

1. Download a current official Arch Linux ISO and verify its signature using the current Arch instructions.
2. Boot the ISO in UEFI mode with Secure Boot disabled; establish networking and correct time.
3. Transfer a reviewed SKITTLES source tree or verified GitHub release asset. **Do not use `curl ... | bash`.**
4. For a published RC, verify `SHA256SUMS` and GitHub artifact provenance as documented in [Release process](docs/RELEASE.md).
5. Review `skittles-installer.sh`, especially drive selection, `clear_disk`, partitioning, encryption, and chroot configuration.
6. Run `bash skittles-installer.sh --check` and inspect the complete inventory.
7. Run `bash skittles-installer.sh`, choose a profile and disks, enter credentials, and type every exact erase confirmation.
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

The public `main` baseline has passed GitHub Actions with:

- complete required repository tree;
- Bash syntax;
- ShellCheck **0.9.0**;
- **68/68 Python tests**;
- repository hygiene scanning;
- whitespace validation.

The suite covers CLI/profile behavior, generated configuration, destructive-operation mocks, plan/identity guards, credential transport, release prerequisites, fail-closed stable gating, deterministic release assets, repository hygiene, documentation consistency, and recovery guidance.

That is **automated evidence only**. `release-signoff.json` intentionally remains `NOT TESTED` for the physical i7-8700K + RTX 3060 Ti gates. See [Testing and release sign-off](docs/TESTING.md) and [Release decision](docs/RELEASE-DECISION.md).

## Recovery model

Both `linux` and `linux-lts` are installed. The recovery guide covers Arch-ISO device identification, LUKS unlock, mounting/chroot, kernel/NVIDIA reinstall, initramfs rebuild, GRUB repair, logs, LUKS-header backup, clean teardown, and LTS recovery boot.

The procedure is documented but **has not yet completed its required physical release drill**. See [Recovery](docs/RECOVERY.md).

## Known limitations

- Only the i7-8700K + RTX 3060 Ti target is supported.
- Secure Boot is unsupported for this release and must be disabled.
- Hibernation is not configured.
- Physical clean-install, both-kernel, NVIDIA/Wayland, suspend/resume, networking/audio/gaming/update, recovery, and performance sign-offs remain pending.
- DNS is not encrypted by SKITTLES.
- Logical SSD wiping is not certified NAND sanitization.
- Arch is rolling release software; future package behavior can invalidate assumptions and requires revalidation.
- **`v1.0.0` has not been released.**

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
