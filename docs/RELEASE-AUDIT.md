# SKITTLES release audit

Status: automated/static release hardening is **PASS** on the public repository; stable release remains **NOT READY FOR v1.0.0**. Physical results are never inferred from static checks.

## Hosted evidence

Public commit `8b3632938aaff6d6721a064b36b12b78b0ed0fbb` passed GitHub Actions run `35175926302`: repository completeness, Bash syntax, ShellCheck 0.9.0, **68/68 Python tests**, repository hygiene, and whitespace all PASS. CI permissions observed in the log were read-only (`contents: read`, `metadata: read`).

The installer blob on that SHA is `0532da3e6c8733bf0b88afe861ba3469acd75af0`. This licensing/README/documentation pass leaves installer logic unchanged.

## License and release-gate state

SKITTLES is licensed under Apache License 2.0 using the canonical `LICENSE` text. The former license-selection blocker is resolved. Stable publication still fails closed through `release-signoff.json` and `scripts/check_release_signoff.py`: every mandatory physical/recovery/performance key must be present and exactly `PASS`, performance evidence must be SHA-bound to `docs/PERFORMANCE.md`, and stable notes must not contain the `DRAFT:` marker.


## Static source audit

### Destructive disk paths

Every raw destructive entry point remains bound to explicit authorization:

- `clear_disk` requires the approved plan, verifies the drive is one of the confirmed path/identity/size tuples, and calls `assert_same_disk` before `dd`, `wipefs`, or `sgdisk --zap-all`.
- `disk_identity` binds major/minor, size, model, serial, and WWN. The plan digest binds version, wipe mode, profile, discard choice, target index, selected paths, identities, sizes, and extra-drive order.
- `wipe_and_partition` revalidates the target after clearing and immediately before partition creation.
- `format_and_mount` rechecks plan/target binding and disk identity/idle state, then verifies both generated partition devices report the expected parent before FAT formatting or `cryptsetup luksFormat`.
- extra-drive clearing is unreachable until `ARCH_INSTALLED=1` and still goes through `clear_disk` with the originally confirmed identity and size.

This minimizes accidental wrong-device writes and ordinary TOCTOU exposure. It does not claim to defeat a malicious privileged process deliberately racing device state while the installer runs.

### Credential and shell handling

No `eval` is used. Passwords are read silently, deliberately unexported, excluded from xtrace/verbose mode, sent to the chroot through NUL-delimited stdin rather than command arguments, and unset after use. The LUKS passphrase is provided through `cryptsetup --key-file=-`. Core dumps are disabled. The temporary chroot helper lives on the freshly mounted target, is mode 0700, and is removed before completion. The installer-created work directory uses `mktemp -d` under `/run` and cleanup removes only that recorded path.

### Doctor

The generated doctor remains read-only and performs no auto-sudo, repair, upload, or telemetry. Wayland is PASS, X11 is a release-significant FAIL, and a non-graphical session is informational. A failed `systemctl --failed` query is a FAIL rather than a false empty PASS. Gaming-package checks are profile-aware; absent IPv6 runtime connectivity or inactive NTSync does not become a false mandatory failure.

## Live Arch package inventory — verified 2026-09-17

Every explicit package printed by both profiles was checked against the official Arch package database. No explicit AUR dependency is required.

- Core/base path: `base`, `linux`, `linux-lts`, `linux-firmware`, `sudo`, `wpa_supplicant`, `grub`, `efibootmgr`, `cryptsetup`, `mkinitcpio`, `dosfstools`, `e2fsprogs`, `nano`.
- Extra desktop/platform path: `intel-ucode`, `networkmanager`, Plasma components, `polkit-kde-agent`, `xdg-desktop-portal-kde`, `sddm`, `xorg-server`, `xorg-xwayland`, `konsole`, `dolphin`, Noto fonts, PipeWire components, `wireplumber`, `nftables`, and `zram-generator`.
- NVIDIA/Vulkan path: `nvidia-open`, `nvidia-open-lts`, `nvidia-utils`, `mesa`, `vulkan-icd-loader`, `vulkan-tools`.
- Gaming path: `steam`, `lib32-nvidia-utils`, `lib32-vulkan-icd-loader`, `gamemode`, `lib32-gamemode`, `mangohud`, `lib32-mangohud`, `ntsync-autoload`.

Current examples include `linux` 7.2.6.arch2-1, `linux-lts` 6.18.52-1, NVIDIA 615.71.09 packages, NetworkManager 1.58.1-1, Plasma 6.7.5, PipeWire 1.6.8, and zram-generator 1.2.1-1. `linux-headers` and `linux-lts-headers` also remain available, but SKITTLES intentionally does not install them because it uses Arch's prebuilt `nvidia-open` and `nvidia-open-lts` packages rather than DKMS. Install-time `pacman -Sp` preflight still resolves the complete selected package set before destructive work and is authoritative for the mirror state at that moment.

Authoritative source: <https://archlinux.org/packages/>.

## NVIDIA / Wayland static audit

NVIDIA's current open-kernel-module source states that open modules support Turing and later GPUs; RTX 3060 Ti is Ampere. Current Arch repositories provide matching `nvidia-open` and `nvidia-open-lts` packages plus 64-bit and multilib user-space/Vulkan components. The current design leaves DRM KMS/fbdev at packaged defaults and verifies them at runtime rather than forcing obsolete overrides.

The 595+ suspend architecture remains the kernel-suspend-notifier path used by this project: legacy `nvidia-suspend`, hibernate, resume, and suspend-then-hibernate services are disabled; modules are not forced into early initramfs loading; doctor verifies notifier state, `/var/tmp` backing path, and reports VRAM-preservation state. No static reason was found to resurrect old service handling. Actual suspend/resume remains a hardware gate.

Sources: <https://wiki.archlinux.org/title/NVIDIA>, <https://wiki.archlinux.org/title/NVIDIA/Tips_and_tricks>, and <https://github.com/NVIDIA/open-gpu-kernel-modules>.

## Resolver / networking static audit

The installed lifecycle is coherent: the Arch ISO resolver remains usable while `arch-chroot` performs configuration; the outer installer creates `/etc/resolv.conf -> ../run/systemd/resolve/stub-resolv.conf` only after `arch-chroot` exits and releases its temporary resolver mount. NetworkManager is configured for `dns=systemd-resolved`; both NetworkManager and `systemd-resolved` are enabled.

Configured defaults remain deliberate: hostname sending disabled, stable pseudonymous DHCP identifiers, randomized Wi-Fi scanning, stable-per-SSID association MAC, IPv6 stable privacy/temporary addresses, LLMNR/mDNS disabled, and connectivity probing disabled. DNSOverTLS remains explicitly off, so these are privacy-conscious defaults rather than encrypted DNS or anonymity.

Recovery documentation now relies on `arch-chroot`'s resolver/API-filesystem setup instead of copying a resolver stub into `/mnt/run`. Physical ISO recovery remains NOT TESTED.

Sources: <https://networkmanager.dev/docs/api/latest/NetworkManager.conf.html>, <https://networkmanager.dev/docs/api/latest/nm-settings-nmcli.html>, and current `arch-install-scripts` `arch-chroot` behavior.

## Firewall static audit

Generated nftables policy remains input drop / forward drop / output accept. It permits loopback, established/related traffic, ICMP/IPv6-ICMP control traffic, DHCPv4 client traffic, and link-local DHCPv6 client traffic. It has no blanket trusted-LAN rule and no SSH allowance. The target chroot runs `nft -c -f /etc/nftables.conf`; NetworkManager has explicit `Requires=`/`After=` ordering on nftables and systemd-resolved. No change was justified.

## CPU / GameMode static audit

The i7-8700K desktop uses normal kernel/firmware adaptive policy by default. Current GameMode upstream configuration still documents `desiredgov`, `softrealtime`, `renice`, and `inhibit_screensaver`; if `defaultgov` is omitted, the original policy is restored on exit. SKITTLES uses only those conservative options and no GPU clock, power-limit, realtime-abuse, mitigation-disable, or permanent max-frequency settings. Performance benefit remains unclaimed until measurement.

Source: <https://github.com/FeralInteractive/gamemode/blob/master/example/gamemode.ini>.

## Storage / boot static audit

The current source remains internally coherent: GPT with 2 GiB FAT32 ESP; LUKS2/Argon2id root; ext4 including `/home`; systemd-based mkinitcpio hooks with `sd-encrypt`; UUID-bound kernel command line; both `linux` and `linux-lts`; GRUB normal UEFI and removable fallback paths; LUKS discard and weekly fstrim only when explicitly opted in. Current Arch dm-crypt/mkinitcpio guidance still supports this architecture. No alternative boot architecture was introduced.

Sources: <https://wiki.archlinux.org/title/Dm-crypt/System_configuration>, <https://wiki.archlinux.org/title/Dm-crypt/Encrypting_an_entire_system>, and <https://wiki.archlinux.org/title/Mkinitcpio>.

## Release engineering audit

The stable workflow now consumes `release-signoff.json` through `scripts/check_release_signoff.py`. Stable publication fails closed if any required key is missing, extra, malformed, empty, or not exactly `PASS`; if performance evidence is missing or its SHA-256 does not match `docs/PERFORMANCE.md`; or if stable notes still contain `DRAFT:`. RC tags may retain NOT TESTED hardware state, but every release still requires the committed non-empty Apache-2.0 `LICENSE` and exact tag/version equality.

The exact workflow asset recipe is exercised twice by automated tests. Two builds from the same fixed source identity produce byte-identical tarball SHA-256 values; `SHA256SUMS` self-verifies; the bundled installer is mode 0755; `SOURCE_COMMIT` is deterministic; and `.github/` plus `tests/` are excluded from the end-user archive. Repository tests remain in GitHub.

Current Action pins were verified against official refs on 2026-09-17: `actions/checkout` v5.1.0 at `fbc6f3992d24b796d5a048ff273f7fcc4a7b6c09`, and `actions/attest` v4.2.1 at `508db95dd578ae2727ebd6217d5ba78e4fbda05d`.

## Repository hygiene and limitations

The current-tree audit found no private-key headers, common GitHub/AWS token patterns, credential-bearing URLs, NUL/binary-like tracked files, generated editor/cache junk, or oversized artifacts. CI now carries a read-only scanner for these current-tree classes. Pattern scans are not a mathematical proof that arbitrary secrets are absent, and this environment does not possess a native complete clone of every public historical Git object; historical secret review therefore remains bounded by available objects and GitHub evidence.

## Remaining external gates

- publish/download a real RC and verify its `SHA256SUMS` and GitHub attestation/provenance;
- complete physical i7-8700K + RTX 3060 Ti install/runtime validation on both kernels;
- complete NVIDIA/Wayland/Vulkan, suspend/resume, networking/audio/gaming/update validation;
- execute the Arch-ISO recovery drill as written;
- record the target-hardware performance measurements and bind their SHA-256 evidence;
- only after all mandatory sign-off entries are `PASS`, reconcile final stable notes and consider `v1.0.0`.

No stable tag is created by this pass. No hardware result is claimed.
