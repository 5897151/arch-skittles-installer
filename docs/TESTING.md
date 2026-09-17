# Testing and Release Sign-off

Automated validation is necessary but cannot substitute for the physical i7-8700K + RTX 3060 Ti release test. All destructive automated tests use mocks or ordinary temporary files; they must never target real block devices.

## Automated gates

From the repository root:

```bash
bash -n skittles-installer.sh
shellcheck skittles-installer.sh
python3 -m unittest discover -s tests -v
python3 scripts/audit_repository.py
python3 -m json.tool release-signoff.json >/dev/null
git diff --check
```

The exact public baseline before the current-Arch remediation is commit `5b5453bcbc9d6e6ca175adf5c9fa737f050971a1`: hosted repository completeness PASS, Bash PASS, ShellCheck 0.9.0 PASS, **74/74 Python PASS**, repository hygiene PASS, and whitespace PASS.

The current remediation tree expands local Python discovery to **90/90 PASS**. It additionally:

- extracts `CHROOT_SCRIPT` and `DOCTOR_SCRIPT` with `scripts/extract_generated_shell.py`, then runs `bash -n` and ShellCheck against them in Ubuntu CI;
- tests pre-write/post-write/post-install failure reporting, SIGINT/SIGTERM states, persistent disk identity, disappearing/replaced/busy disks, cleanup failures and second-instance locking;
- runs `tests/test_arch_pacman_preflight.sh` in a separate `archlinux:latest` container; the integration script first performs a full `pacman -Syu` while installing current Arch `python` and `shellcheck`;
- executes the real pacman 7 `DownloadUser` database synchronization with the SKITTLES temporary `DBPath`/`CacheDir` and intact downloader sandbox;
- resolves every explicit package in both minimal and gaming profiles with `pacman -Sp`.
- runs current Arch `shellcheck` against the installer, Arch integration script, extracted chroot script, and extracted doctor script in addition to Ubuntu CI's ShellCheck.

Do not call the current-Arch integration PASS until the hosted Arch job on the published remediation SHA succeeds. If the runner blocks pacman's Landlock/seccomp sandbox, record `PACMAN SANDBOX IN HOSTED CONTAINER: BLOCKED`; do not weaken the production pacman configuration to make CI green.

## Current official-ISO P0 regression

The next human test is intentionally storage-independent:

```bash
bash skittles-installer.sh --check --profile=gaming
```

Run it on the same current official Arch ISO class that reproduced the original `core.db.part: Permission denied` failure. A passing result must:

1. retain the live ISO's active pacman `DownloadUser` and sandbox settings;
2. synchronize official repository databases successfully;
3. resolve every gaming-profile package successfully;
4. exit before disk enumeration/selection, password entry, or erase confirmation;
5. report a preflight failure as occurring before disk writes if any external prerequisite fails.

Only after this command passes should another destructive installation be attempted.

## One physical validation sequence

Use the actual RC downloaded from GitHub after checksum and attestation verification. Record the RC tag, `SOURCE_COMMIT`, Arch ISO date, motherboard/firmware version, disk model without serial number, monitor arrangement, and network type.

1. Verify the current official Arch ISO and boot it in UEFI mode with Secure Boot disabled.
2. Run `bash skittles-installer.sh --check --profile=gaming`; confirm package synchronization/resolution completes and exits before storage interaction.
3. Review disk inventory and exact destructive plan during the real installer. Confirm only intended unused internal disks with a persistent serial or WWN are selectable.
4. Perform a clean install and verify repeated LUKS unlock, cold boot, and warm reboot.
5. Boot `linux`; verify Plasma Wayland, `nvidia-smi`, `vulkaninfo --summary`, audio, representative USB, Ethernet, Wi-Fi if applicable, DNS through `systemd-resolved`, IPv6 when available, and nftables.
6. Run `skittles-doctor` as the normal user and with `sudo`.
7. Perform multiple suspend/resume cycles; after each, verify NVIDIA/Wayland responsiveness and inspect warning/error logs.
8. Boot `linux-lts` and repeat kernel-dependent NVIDIA/Vulkan/network/firewall/doctor/suspend checks.
9. For gaming, run `gamemoded -t`, then test Steam login manually, a representative Proton title, `gamemoderun`, MangoHud, 32-bit NVIDIA/Vulkan, and NTSync. Confirm normal CPU policy returns and split-lock mitigation remains enabled after GameMode use.
10. Run a normal `pacman -Syu`; if kernel/NVIDIA/initramfs/GRUB components update, complete the update and reboot. Re-verify both kernels and NVIDIA/Wayland.
11. Boot a current Arch ISO and execute `docs/RECOVERY.md` as written: unlock/mount/chroot, package/kernel/NVIDIA repair where appropriate, initramfs rebuild, GRUB repair/configuration, log inspection, clean teardown, and a Linux LTS recovery boot.
12. Validate Plasma Adaptive Sync/VRR against the actual display when supported; the installer does not force this setting.
13. Complete every applicable A/B case and repeated measurement procedure in `docs/PERFORMANCE.md`.

Do not rerun the installer to test updates or recovery.

## Read-only evidence capture

Redact drive serials, MAC addresses, personal hostnames, usernames where unnecessary, and any identifying data. Never post passwords, Wi-Fi PSKs, private keys, or `/etc/NetworkManager/system-connections/*`.

Useful checks include:

```bash
cat /etc/skittles-release
uname -r
printf '%s\n' "${XDG_SESSION_TYPE:-unknown}"
nvidia-smi
vulkaninfo --summary
systemctl --failed
resolvectl status
findmnt -no TARGET,SOURCE,FSTYPE,OPTIONS /
findmnt -no TARGET,SOURCE,FSTYPE,OPTIONS /boot
swapon --show
skittles-doctor
sudo skittles-doctor
sudo nft list ruleset
```

For suspend/resume evidence:

```bash
journalctl -b -p warning..alert
journalctl -b | grep -Ei 'NVRM|nvidia|suspend|resume|PM:'
```

## Machine-readable sign-off

`release-signoff.json` is the source consumed by the stable release gate. Update a key to `PASS` only after that exact physical test has passed on the downloaded RC. `FAIL`, `BLOCKED`, `WARN`, `NOT TESTED`, missing keys, malformed data, and empty values all block stable publication.

The mandatory keys cover install/boot/LUKS, both kernels, Wayland/NVIDIA/Vulkan, networking/firewall/audio/USB, suspend/resume, update/post-update boots, doctor, Steam/Proton/32-bit graphics/GameMode/MangoHud/NTSync, recovery, and performance.

When performance testing is complete, set `performance_measurements` to `PASS` and record the SHA-256 of the completed `docs/PERFORMANCE.md` in `evidence.performance_sha256`:

```bash
sha256sum docs/PERFORMANCE.md
```

If that document changes afterward, stable gating fails until the evidence hash is deliberately updated after review.

## Current physical status

All mandatory `release-signoff.json` entries remain `NOT TESTED`. Automated or container validation never changes those physical statuses.
