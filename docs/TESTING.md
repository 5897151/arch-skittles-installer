# Testing and Release Sign-off

Automated validation and physical validation provide different evidence. Automated destructive-path tests use mocks or ordinary temporary files and must never target real block devices.

## Automated gates

From the repository root:

```bash
bash -n skittles-installer.sh
shellcheck skittles-installer.sh
python3 scripts/extract_generated_shell.py CHROOT_SCRIPT > /tmp/skittles-chroot.sh
python3 scripts/extract_generated_shell.py DOCTOR_SCRIPT > /tmp/skittles-doctor.sh
bash -n /tmp/skittles-chroot.sh
bash -n /tmp/skittles-doctor.sh
shellcheck /tmp/skittles-chroot.sh /tmp/skittles-doctor.sh
python3 -m unittest discover -s tests -v
python3 scripts/audit_repository.py
python3 scripts/check_release_signoff.py release-signoff.json docs/PERFORMANCE.md docs/RELEASE-NOTES-v1.0.0.md
python3 -m json.tool release-signoff.json >/dev/null
git diff --check
```

Validated remediation commit `cc62cd73467701bd1c15a1be5b99af68551647ad` passed hosted CI run `35285336084` with **92/92 Python tests**. The Ubuntu job passed repository completeness, Bash syntax, ShellCheck for the installer and extracted chroot/doctor scripts, repository hygiene, and whitespace checks. The current-Arch job passed the real pacman 7 `DownloadUser` preflight with sandbox policy preserved, minimal/gaming transaction resolution, explicit package availability, and current-Arch ShellCheck.

The stable promotion adds four focused test methods for final version agreement, repository sign-off acceptance, the narrow `DEFERRED` allowlist, and conditional performance-SHA enforcement, bringing local discovery to **96/96 PASS**. Exact-source hosted CI must pass on the stable-promotion SHA before tagging.

## Target-hardware validation

Physical validation on the supported Intel Core i7-8700K + NVIDIA RTX 3060 Ti system covered:

- clean gaming-profile installation, repeated LUKS unlock, cold boot and warm reboot;
- `linux` and `linux-lts` boot;
- Plasma Wayland, NVIDIA and Vulkan on both kernels;
- Ethernet/DHCP/DNS, nftables, audio and representative USB behavior;
- suspend/resume on both kernels with NVIDIA and DNS healthy afterward;
- normal-user and root doctor checks;
- Steam/Proton, 32-bit NVIDIA/Vulkan, GameMode, MangoHud and NTSync technical runtime paths;
- a complete `pacman -Syu` transaction and subsequent boots on both kernels.

No package upgrades were available during the observed `pacman -Syu`, so the result does **not** demonstrate migration across an actual kernel or NVIDIA package-version transition.

Do not rerun the installer to test updates or recovery. SKITTLES is destructive and is not an updater or repair tool.

## Explicitly deferred validation

The owner deferred two non-mandatory areas for v1.0.0:

- the formal Arch-ISO recovery drill described in [Recovery](RECOVERY.md);
- the controlled benchmark matrix described in [Performance policy](PERFORMANCE.md).

These areas are `DEFERRED`, not `PASS`. Recovery execution is not claimed. No benchmark-based performance gain is claimed, and no SHA-bound benchmark result exists.

## Machine-readable sign-off

`release-signoff.json` is consumed by the stable release gate. `PASS` means the gate was executed and passed. `DEFERRED` is accepted only for the explicit recovery/performance allowlist. Every other mandatory gate requires `PASS`.

The validator fails closed on `FAIL`, `BLOCKED`, `WARN`, `NOT TESTED`, unknown or empty statuses; missing, extra or renamed keys; malformed JSON or structure; and draft stable notes. It cannot silently defer a mandatory runtime gate.

When `performance_measurements` is `PASS`, `evidence.performance_sha256` must match the exact bytes of `docs/PERFORMANCE.md`. When performance is explicitly `DEFERRED`, the SHA must remain `null` so the release cannot imply that an unperformed benchmark was recorded.

## Evidence capture guidance

Redact drive serials, MAC addresses, personal hostnames, usernames where unnecessary, and all secrets. Never publish passwords, Wi-Fi PSKs, private keys, or `/etc/NetworkManager/system-connections/*`.

Useful read-only checks include:

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
