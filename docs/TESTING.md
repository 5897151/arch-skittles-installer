# Testing and Release Sign-off

Automated validation is necessary but cannot substitute for the physical i7-8700K + RTX 3060 Ti release test. All destructive automated tests use mocks or ordinary temporary files; they must never target real block devices.

## Automated gate

From the repository root:

```bash
bash -n skittles-installer.sh
shellcheck skittles-installer.sh
python3 -m unittest discover -s tests -v
python3 scripts/audit_repository.py
git diff --check
```

GitHub run `35172528577` on commit `5fc333d5ee45c8c07787802c4605483f6d717b17` is the current hosted installer baseline: completeness PASS, Bash PASS, ShellCheck 0.9.0 PASS, 50/50 Python PASS, whitespace PASS. It includes the four resolver/identity/doctor audit regressions. Follow-up release-gate, reproducibility, hygiene, recovery-doc, and adversarial tests must receive their own exact-SHA hosted run after publication; local success is not substituted for that run.

The final follow-up tree passes **68/68 tests locally** in a clean Git simulation, plus Bash syntax, YAML/JSON, Markdown relative links, repository hygiene, whitespace, release reproducibility, and fail-closed stable-gate fixtures. The installer bytes are unchanged from the hosted baseline. Local ShellCheck is unavailable, so the final published SHA still needs a hosted ShellCheck/CI run before this batch becomes authoritative.

## One physical validation sequence

Use the actual RC downloaded from GitHub after checksum and attestation verification. Record the RC tag, `SOURCE_COMMIT`, Arch ISO date, motherboard/firmware version, disk model without serial number, monitor arrangement, and network type.

1. Verify the current official Arch ISO and boot it in UEFI mode with Secure Boot disabled.
2. Run the RC installer with `--check`; confirm package resolution, target hardware detection, DNS/time, and that no disks are written.
3. Review disk inventory and exact destructive plan. Confirm only the intended unused internal target is selected.
4. Perform a clean install and verify repeated LUKS unlock, cold boot, and warm reboot.
5. Boot `linux`; verify Plasma Wayland, `nvidia-smi`, `vulkaninfo --summary`, audio, representative USB, Ethernet, Wi-Fi if applicable, DNS through `systemd-resolved`, IPv6 when available, and nftables.
6. Run `skittles-doctor` as the normal user and with `sudo`.
7. Perform multiple suspend/resume cycles; after each, verify NVIDIA/Wayland responsiveness and inspect warning/error logs.
8. Boot `linux-lts` and repeat the kernel-dependent NVIDIA/Vulkan/network/firewall/doctor/suspend checks.
9. For the gaming profile, test Steam login manually, a representative Proton title, `gamemoderun`, MangoHud, 32-bit NVIDIA/Vulkan, and NTSync behavior.
10. Run a normal `pacman -Syu`; if kernel/NVIDIA/initramfs/GRUB components update, complete the update and reboot. Re-verify both kernels and NVIDIA/Wayland.
11. Boot a current Arch ISO and execute `docs/RECOVERY.md` as written: unlock/mount/chroot, kernel/NVIDIA reinstall where appropriate, initramfs rebuild, GRUB repair/configuration, log inspection, clean exit/unmount, mapping close, and a Linux LTS recovery boot.
12. Complete the repeated performance procedure in `docs/PERFORMANCE.md`.

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

If the performance document changes afterward, the stable gate fails until the evidence hash is deliberately updated after review.

## Current physical status

All mandatory `release-signoff.json` entries are currently `NOT TESTED`. Automated/static PASS results must not be copied into physical sign-off fields.
