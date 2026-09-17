# SKITTLES

> A safety-first, encrypted Arch Linux fresh installer for one specific i7-8700K + RTX 3060 Ti KDE/Wayland desktop.

**Release status: `1.0.0-rc.1` — release candidate, not stable.** Real-hardware sign-off and an owner-selected software license are still required before `v1.0.0`.

> [!WARNING]
> **SKITTLES is a destructive fresh-install tool. Selected disks are erased.** It is not an upgrade tool, repair tool, migration tool, or generic Arch installer. Never rerun it to update or repair an existing installation.

## Supported hardware

This release is deliberately scoped to the following system; real-hardware RC sign-off is still pending:

- Intel Core **i7-8700K**
- NVIDIA **RTX 3060 Ti** using Arch's open NVIDIA kernel modules
- x86-64
- UEFI firmware with writable EFI variables
- **Secure Boot disabled**; SKITTLES does not sign its boot chain
- an unused internal **SATA or NVMe** installation disk of at least 32 GiB

Other hardware is unsupported, even if the script can technically be adapted. USB/removable storage is protected from selection by design.

## What it installs

SKITTLES builds a small Arch desktop with GRUB, LUKS2-encrypted ext4 root, `linux` and `linux-lts`, Plasma Wayland, NVIDIA graphics, NetworkManager, `systemd-resolved`, PipeWire, nftables, zram, and local diagnostics. The optional gaming profile adds Steam, the required 32-bit NVIDIA/Vulkan stack, GameMode, MangoHud, and NTSync.

| Capability | Minimal | Gaming |
| --- | :---: | :---: |
| KDE Plasma | ✓ | ✓ |
| Wayland session | ✓ | ✓ |
| `linux` + `linux-lts` | ✓ | ✓ |
| NVIDIA open modules | ✓ | ✓ |
| nftables | ✓ | ✓ |
| Steam | — | ✓ |
| 32-bit NVIDIA/Vulkan | — | ✓ |
| GameMode | — | ✓ |
| MangoHud | — | ✓ |
| NTSync autoload | — | ✓ |

It deliberately does **not** install an SSH server, AUR helper, browser, office suite, hibernation setup, overclocking tools, alternate gaming kernel, or a second firewall manager.

## What it erases

There is no default target disk. The installer inventories whole disks and shows device path, size, model, serial, transport, and protection reason. You select exactly one installation disk and may explicitly select additional disks to erase.

Safety controls include:

- no preselected target;
- mounted, read-only, removable, USB, swap-backed, and LUKS/LVM/RAID-in-use disks are protected;
- every selected disk needs its own exact `ERASE /dev/...` confirmation;
- all confirmations complete before the first disk write;
- disk identity, size, and busy state are revalidated before destructive operations;
- the confirmed plan is bound to a SHA-256 digest and writes are refused if it changes;
- extra wipe-only disks are erased only **after** Arch installs successfully and are then left blank;
- cleanup only unmounts/closes resources created by this installer.

Do not hot-plug storage while installation is in progress.

## Encryption and security defaults

- LUKS2 with Argon2id protects the root filesystem at rest.
- `/home` lives inside encrypted root and the created user's home is mode `0700`.
- `sudo` requires authentication; no passwordless wheel rule is installed.
- nftables defaults to inbound and forward **drop**, outbound **accept**, with the protocol allowances needed for ordinary client networking.
- No SSH server is installed.
- Core-dump processing/storage is disabled; dmesg, kernel pointers, ptrace, ASLR, and protected link settings receive conservative hardening.
- `/boot` is a 2 GiB FAT32 ESP mounted with `nosuid,nodev,noexec` and restrictive masks.

Encryption is not boot integrity. GRUB, the kernel, and initramfs on the ESP are unencrypted and unsigned. With Secure Boot disabled, an attacker with physical access can tamper with the boot chain. See [docs/SECURITY-MODEL.md](docs/SECURITY-MODEL.md).

## Privacy defaults

SKITTLES aims to reduce avoidable local/network identity leakage without pretending to provide anonymity:

- DHCP hostname sending disabled;
- stable pseudonymous DHCP client identifiers instead of a permanent hardware-derived identity where NetworkManager supports it;
- randomized Wi-Fi scan MAC and a stable-per-SSID association MAC;
- IPv6 stable-private addressing with temporary addresses preferred;
- LLMNR and mDNS disabled in NetworkManager defaults and `systemd-resolved`;
- NetworkManager connectivity checking disabled;
- DNS is routed through `systemd-resolved`, but **DNS-over-TLS is disabled** and network-provided DNS is not made private from the resolver/network by SKITTLES;
- persistent journal is limited to 256 MiB / 14 days on encrypted root;
- Baloo content indexing is disabled for the created user;
- LUKS discard/TRIM is off by default because it can expose free-space patterns.

These are privacy improvements, not anonymity. SKITTLES is not Tor and is not a VPN. See [docs/PRIVACY.md](docs/PRIVACY.md).

## Performance philosophy

SKITTLES does not disable CPU vulnerability mitigations, overclock the CPU/GPU, force maximum clocks, install a special gaming kernel, dump unmeasured sysctls, inflate TCP buffers, or force a universal I/O scheduler.

Normal desktop use keeps the kernel/firmware's adaptive CPU policy. In the gaming profile, GameMode may request the `performance` governor only while a game uses `gamemoderun`. Zram is bounded at half RAM up to 4 GiB; ext4 uses its normal relatime behavior. No FPS or latency improvement is claimed until measured on the target hardware. See [docs/PERFORMANCE.md](docs/PERFORMANCE.md).

## Installed architecture

```text
UEFI firmware (Secure Boot disabled)
 │
 ├── 2 GiB EFI System Partition, FAT32, mounted /boot
 │    ├── GRUB
 │    ├── linux + initramfs
 │    └── linux-lts + initramfs
 │
 └── remaining disk: LUKS2 / Argon2id
      │
      └── ext4 root filesystem
           ├── /
           ├── /home
           └── zram swap (RAM-backed, not hibernation storage)
```

## Inspect it safely

The demo is safe on any machine because it uses only fictional drive data: it does not require root, probe hardware, access block devices, prompt for passwords, or write disks.

```bash
bash skittles-installer.sh --demo
```

To see the exact explicit package list without root/network access:

```bash
bash skittles-installer.sh --packages
bash skittles-installer.sh --profile=gaming --packages
```

## Preflight

From a current official Arch installation ISO on the supported hardware:

```bash
bash skittles-installer.sh --check
```

`--check` performs the real drive inventory/selection, hardware/firmware checks, DNS/time checks, and package resolution using temporary package metadata. It does **not** collect credentials, ask for erase confirmations, wipe, partition, format, mount the target, or install Arch. Selections are not saved for a later run.

## Installation

1. Download a current official Arch Linux ISO and its signature from `https://archlinux.org/download/`.
2. Verify the ISO/signature using the current instructions on the Arch download/installation pages. Do not skip provenance just because a checksum matches.
3. Boot the ISO in UEFI mode with Secure Boot disabled and establish networking.
4. Transfer the SKITTLES release bundle or reviewed source tree to the live environment. **Do not use `curl ... | bash`.**
5. Verify SKITTLES before execution. Published releases are designed to provide `skittles-VERSION.tar.gz`, `skittles-installer-VERSION.sh`, and `SHA256SUMS`; run `sha256sum -c SHA256SUMS`, then verify any GitHub artifact attestation as described in [docs/RELEASE.md](docs/RELEASE.md). A checksum fetched from the same compromised location is an integrity check, not independent authenticity.
6. Read `skittles-installer.sh`, especially drive selection, `clear_disk`, partitioning, encryption, and chroot configuration.
7. Run `bash skittles-installer.sh --check` and review the entire inventory.
8. Run `bash skittles-installer.sh`, select the profile/disks, enter credentials, and confirm each selected disk exactly.
9. When installation finishes, remove the ISO and reboot manually.

The official Arch installation guide recommends verifying the installation image/signature before use; SKITTLES follows the same conservative provenance principle.

## Command-line options

This list is kept in lockstep with `bash skittles-installer.sh --help` by tests.

| Option | Meaning |
| --- | --- |
| `--profile=minimal` | Minimal KDE/Wayland profile with both supported kernels. |
| `--profile=gaming` | Adds Steam, 32-bit NVIDIA/Vulkan, GameMode, MangoHud, and NTSync. |
| `--packages` | Prints the explicit package list and exits. |
| `--check` | Nondestructive preflight/package resolution only. |
| `--wipe=zero` | Default: one logical zero overwrite of every addressable byte on each selected disk. |
| `--wipe=signatures` | Faster reinstall cleanup; removes signatures/tables but does not securely erase old contents. |
| `--allow-discards` | Opt in to LUKS discard plus weekly `fstrim.timer`. |
| `--demo` | Fictional-drive UI preview; no probing or writes. |
| `--version` | Print installer version. |
| `--help`, `-h` | Show help. |

## Disk wiping and SSD limits

`--wipe=zero` performs one logical overwrite across the selected device's addressable bytes and fails on I/O errors. That is useful for deterministic reinstall cleanup, but it is **not certified physical sanitization** of SSD/NVMe media: remapped blocks, over-provisioned NAND, controller spare areas, and firmware behavior may retain data.

`--wipe=signatures` only removes known filesystem signatures and partition metadata; old file contents can remain recoverable. SKITTLES does not issue guessed ATA Secure Erase or NVMe Sanitize commands. For disposal-grade sanitization, follow the drive manufacturer's documented secure-erase/sanitize procedure for that exact device.

TRIM/discard is separate from sanitization. When enabled, it may help SSD maintenance but leaks which encrypted blocks are unused.

## Privacy and security tradeoffs

- DNS uses network-provided resolvers through `systemd-resolved`; SKITTLES does not provide encrypted DNS.
- Enabling LUKS discard exposes free-space patterns to the storage layer.
- Logs still exist for diagnosis, although retention is bounded and stored inside encrypted root.
- Stable NetworkManager identities reduce hardware-address leakage across networks but can remain linkable within the same saved connection/SSID.
- nftables reduces unsolicited inbound exposure; it does not make outbound applications trustworthy or anonymous.
- LUKS protects a powered-off locked volume, not data after the user has unlocked and logged into the system.

## First boot

Run the local, read-only health check first:

```bash
skittles-doctor
sudo skittles-doctor
```

Then, when diagnosing graphics/session issues, the most useful quick checks are:

```bash
echo "$XDG_SESSION_TYPE"
nvidia-smi
systemctl --failed
```

`skittles-doctor` does not upload telemetry, repair settings, or invoke `sudo` automatically.

## Updating

Update Arch with complete transactions:

```bash
sudo pacman -Syu
```

Read `https://archlinux.org/news/` before upgrades because Arch occasionally publishes required manual intervention. Never perform a partial upgrade, and never rerun SKITTLES as an updater.

If a new `linux` kernel fails, use GRUB's advanced entries to boot `linux-lts`, then repair/update from there. Detailed offline recovery is in **[docs/RECOVERY.md](docs/RECOVERY.md)**.

## Known limitations

- Only the i7-8700K + RTX 3060 Ti target is supported.
- Secure Boot is not configured; boot integrity against physical tampering is out of scope for this RC.
- Hibernation is not configured.
- Suspend/resume, both kernels, NVIDIA/Wayland, networking, gaming, recovery, and upgrades still require recorded real-hardware RC validation.
- SKITTLES does not provide anonymity or encrypted DNS.
- Logical SSD wiping is not certified NAND sanitization.
- Arch is rolling release software; future package behavior can invalidate assumptions and must be re-tested.
- `1.0.0-rc.1` has not been approved for stable release.

## Contributing and security reports

See [CONTRIBUTING.md](CONTRIBUTING.md) before changing any destructive, cryptographic, boot, sudo, firewall, or performance behavior. Security-sensitive reports should follow [SECURITY.md](SECURITY.md) and should not be posted publicly when they could enable destructive-target bypasses.

## License

**No software license has been selected by the repository owner yet.** Publicly visible source without a license is not the same as open-source software and does not grant general permission to copy, modify, or redistribute it. Selecting an owner-authorized license is a blocker for `v1.0.0`; options and consequences are summarized in [docs/RELEASE.md](docs/RELEASE.md).
