# SKITTLES v1.0.0

## Highlights

SKITTLES `v1.0.0` is the first stable release of a hardware-scoped, destructive fresh-install Arch Linux installer for one Intel Core i7-8700K + NVIDIA RTX 3060 Ti KDE Plasma/Wayland desktop. It combines explicit disk authorization, LUKS2 encrypted ext4 root, `linux` plus `linux-lts`, conservative network/privacy defaults, Arch's NVIDIA open modules, local diagnostics, and an optional gaming stack.

The final remediation line fixed current pacman 7 `DownloadUser` access without disabling sandboxing, moved package synchronization/resolution before any storage interaction, tightened destructive failure reporting and disk identity handling, and corrected physical-validation regressions in GRUB recovery arguments, nftables diagnostics, and privileged mmap-ASLR checks.

Validated remediation commit `cc62cd73467701bd1c15a1be5b99af68551647ad` passed hosted CI run `35285336084` with 92/92 Python tests, Bash and ShellCheck validation of the installer and generated scripts, repository hygiene, current-Arch pacman integration, preserved downloader sandbox policy, and both-profile package resolution. Four focused stable-policy/version tests bring the promotion suite to 96 tests. The final stable-promotion commit is independently validated by CI before tagging.

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

SKITTLES is a destructive fresh installer. It is not an updater, repair tool, migration tool, or generic Arch installer.

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

The gaming profile adds Steam, 32-bit NVIDIA/Vulkan libraries, GameMode, MangoHud and NTSync. GameMode is an on-demand game-session layer; split-lock mitigation remains enabled (`disable_splitlock=0`). SKITTLES does not force a permanent maximum-performance governor, overclock CPU/GPU hardware, force fixed GPU clocks, install an alternate gaming kernel, or disable mitigations globally.

Target-hardware validation covered the technical Steam/Proton runtime path, 32-bit NVIDIA/Vulkan, GameMode, MangoHud and NTSync on the supported desktop. Formal performance benchmarking was deferred. No benchmark-based FPS, latency, throughput, power, or other performance gain is claimed.

## Recovery

`linux-lts` is installed alongside `linux`. The release includes detailed Arch-ISO recovery instructions covering safe device identification, LUKS unlock, mounts, chroot networking, package/NVIDIA reinstall, initramfs rebuild, GRUB repair, LTS selection, journal inspection, LUKS-header backup and clean teardown.

The documentation was audited, but the physical Arch-ISO recovery drill was explicitly deferred for v1.0.0. No recovery-execution PASS is claimed.

## Validation scope

Physical validation on the documented i7-8700K + RTX 3060 Ti target covered clean installation, both kernels, LUKS unlock, Plasma Wayland, NVIDIA/Vulkan, networking/DNS/nftables/audio/USB, suspend/resume, doctor checks, and the gaming runtime path. A complete `pacman -Syu` transaction followed by boots on both kernels passed; no package upgrades were available, so an actual kernel/NVIDIA package-version transition was not demonstrated.

The machine-readable sign-off records executed mandatory gates as `PASS`. Only the explicit recovery-drill and formal-performance allowlist is `DEFERRED`; no unperformed deferred gate is labeled PASS.

## License

SKITTLES is licensed under the Apache License 2.0.

## Known limitations

- Hardware-specific; no generic installer support is claimed.
- Secure Boot is not implemented for this release.
- Hibernation is not configured.
- DNS is not encrypted by SKITTLES.
- Logical zero wiping does not guarantee physical sanitization of SSD/NVMe spare/remapped NAND.
- Arch is a rolling distribution; future package changes can require manual intervention or a SKITTLES maintenance release.
- LUKS protects a locked powered-off volume, not an already unlocked compromised session.
- Recovery-ISO execution and formal performance benchmarking are deferred as described above.

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

Verify GitHub artifact provenance against the publishing repository and workflow:

```bash
gh attestation verify skittles-1.0.0.tar.gz -R 5897151/arch-skittles-installer --signer-workflow 5897151/arch-skittles-installer/.github/workflows/release.yml
gh attestation verify skittles-installer-1.0.0.sh -R 5897151/arch-skittles-installer --signer-workflow 5897151/arch-skittles-installer/.github/workflows/release.yml
```

Checksums detect mismatched bytes. GitHub provenance ties an artifact to the recorded repository/workflow/commit. Source review and release-test evidence remain separate requirements.

## Upgrade note

**Do not run SKITTLES to upgrade an existing SKITTLES installation. It is a destructive fresh installer.** Update installed systems with normal Arch full upgrades and use `docs/RECOVERY.md` for recovery.
