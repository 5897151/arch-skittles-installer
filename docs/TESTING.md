# Testing and Release Sign-off

Automated tests are necessary but insufficient for SKITTLES because the release target includes destructive storage behavior, UEFI firmware, a specific NVIDIA GPU, suspend/resume, and real network hardware.

## Safe automated tests

Run from the repository root as an ordinary user:

```bash
bash -n skittles-installer.sh
shellcheck skittles-installer.sh
python3 -m unittest discover -s tests -v
git diff --check
```

The Python suite currently covers CLI/help/version behavior, profile package decisions, username/partition helper logic, disk-protection reasons, numeric menu parsing, plan-digest binding, unauthorized-drive refusal, extra-wipe gating, generated config decisions, and doctor/config coverage.

Destructive tools are mocked. The zero-wipe byte-count regression uses real `dd` only against an ordinary temporary file and verifies the exact resulting byte length. Tests must never discover, format, mount, partition, wipe, or overwrite a real block device.

### Current automated status

Hosted run [35172143080](https://github.com/5897151/arch-skittles-installer/actions/runs/35172143080) tested `580532268d2e0e39f4671dd0b035b75ed3170e6f`: complete tree, Bash, ShellCheck 0.9.0, **46 tests**, and whitespace all PASS.

Follow-up resolver, partition revalidation and doctor corrections pass **50 local tests**; their hosted result and ShellCheck remain pending publication. See [RELEASE-DECISION.md](RELEASE-DECISION.md) for evidence and [RELEASE-AUDIT.md](RELEASE-AUDIT.md) for open audit work. Do not begin release sign-off from an untagged local checkout.

## Read-only hardware evidence sequence

After installing the **downloaded RC artifact** on the target machine, capture a redacted evidence log. These commands are read-only; do not include drive serial numbers, Wi-Fi PSKs, or files from `/etc/NetworkManager/system-connections/`.

```bash
printf 'SKITTLES release: '; cat /etc/skittles-release
printf 'Kernel: '; uname -r
printf 'CPU: '; lscpu | sed -n 's/^Model name:[[:space:]]*//p'
printf 'Session: '; printf '%s\n' "${XDG_SESSION_TYPE:-unknown}"

for p in /sys/devices/system/cpu/cpufreq/policy*; do
  [ -r "$p/scaling_governor" ] || continue
  printf '%s driver=' "$p"
  cat "$p/scaling_driver" 2>/dev/null || printf 'unknown\n'
  printf '%s governor=' "$p"
  cat "$p/scaling_governor"
  [ -r "$p/energy_performance_preference" ] && { printf '%s epp=' "$p"; cat "$p/energy_performance_preference"; }
done

nvidia-smi
cat /sys/module/nvidia_drm/parameters/modeset
cat /sys/module/nvidia_drm/parameters/fbdev
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

For suspend/resume, perform multiple cycles rather than one success. After each cycle, verify `nvidia-smi`, Wayland responsiveness, video/game playback, and inspect relevant warnings:

```bash
journalctl -b -p warning..alert
journalctl -b | grep -Ei 'NVRM|nvidia|suspend|resume|PM:'
```

Record the RC tag, source commit, Arch ISO date, motherboard/firmware version, disk model **without serial**, monitor arrangement, network type, and package versions needed to reproduce the result.

## Virtual-machine tests

A VM can validate generic control flow without claiming target hardware support. Appropriate VM checks include:

- UEFI boot of the installed GRUB layout;
- LUKS unlock and ext4 root mounting;
- main/LTS kernel menu entries;
- generated services/config files;
- failure cleanup and reboot behavior;
- recovery-document procedure mechanics using disposable virtual disks.

A VM does **not** prove RTX 3060 Ti NVIDIA acceleration, current NVIDIA suspend behavior, i7-8700K power policy, physical firmware NVRAM behavior, or real SATA/NVMe wipe/sanitize properties.

## Required real-hardware tests

Use the exact RC release artifact on the supported i7-8700K + RTX 3060 Ti system. Record Arch ISO date, firmware version/state, disk model, profile, SKITTLES version/tag/commit, and package versions.

At minimum test:

- clean install from current verified Arch ISO;
- cold boot and warm reboot;
- repeated LUKS unlocks;
- `linux` and `linux-lts` boots;
- Plasma Wayland login/logout and screen lock/unlock;
- NVIDIA module load, `nvidia-smi`, Vulkan, and sustained GPU load;
- multi-hour idle and sustained CPU load;
- Ethernet, DHCP renewal, DNS via `systemd-resolved`, IPv6 if available, and ordinary connectivity through nftables;
- audio and representative USB devices;
- suspend and resume, including repeated cycles;
- gaming profile: Steam, Proton game, GameMode, MangoHud, NTSync, 32-bit Vulkan/NVIDIA;
- package full upgrade, kernel update, NVIDIA update, then both-kernel boots;
- `skittles-doctor` as user and root before/after updates;
- complete Arch-ISO recovery path from [RECOVERY.md](RECOVERY.md);
- if possible, a second clean install from the exact release artifact rather than a working-tree copy.

## Release sign-off table

Do not change `NOT TESTED` to `PASS` without a recorded run on the target hardware.

| Test | `linux` | `linux-lts` |
| --- | --- | --- |
| Boot | NOT TESTED | NOT TESTED |
| LUKS unlock | NOT TESTED | NOT TESTED |
| Plasma Wayland | NOT TESTED | NOT TESTED |
| NVIDIA module / `nvidia-smi` | NOT TESTED | NOT TESTED |
| Vulkan | NOT TESTED | NOT TESTED |
| Ethernet / DHCP / DNS | NOT TESTED | NOT TESTED |
| nftables ordinary connectivity | NOT TESTED | NOT TESTED |
| Audio / USB | NOT TESTED | NOT TESTED |
| Suspend / resume | NOT TESTED | NOT TESTED |
| Post-update boot | NOT TESTED | NOT TESTED |
| `skittles-doctor` | NOT TESTED | NOT TESTED |

Gaming profile additional sign-off:

| Test | Status |
| --- | --- |
| Steam starts/signs in | NOT TESTED |
| Proton game launches | NOT TESTED |
| 32-bit NVIDIA/Vulkan | NOT TESTED |
| GameMode active for launched game | NOT TESTED |
| MangoHud | NOT TESTED |
| NTSync | NOT TESTED |

Recovery sign-off:

| Test | Status |
| --- | --- |
| Unlock/mount/chroot from current Arch ISO | NOT TESTED |
| Reinstall both kernels/NVIDIA packages | NOT TESTED |
| Rebuild initramfs | NOT TESTED |
| Repair GRUB normal + fallback paths | NOT TESTED |
| Boot `linux-lts` recovery entry | NOT TESTED |
| Clean unmount + close mapping | NOT TESTED |
