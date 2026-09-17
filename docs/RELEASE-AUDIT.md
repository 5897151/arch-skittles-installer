# SKITTLES release audit

Status: the exact public baseline is automated/static **PASS**, while the current-Arch remediation candidate is locally **PASS** for every gate available in this workspace and still requires hosted Ubuntu/current-Arch CI plus the real-ISO preflight. Stable release remains **NOT READY FOR v1.0.0**. Physical results are never inferred from static checks.

## Hosted evidence

Public baseline commit `5b5453bcbc9d6e6ca175adf5c9fa737f050971a1` passed GitHub Actions run `35219299394`: repository completeness, Bash syntax, ShellCheck 0.9.0, **74/74 Python tests**, repository hygiene, and whitespace all PASS. The hosted token was read-only (`contents: read`, `metadata: read`).

The installer blob on that public SHA is `09ec6f7c310c77e3dd800b9f59c85aeea13ea7cc`. A real current official Arch ISO subsequently exposed the pre-destructive pacman 7 failure described below, so that green baseline is not sufficient release evidence.

The current remediation candidate expands local Python discovery to **90/90 PASS**. Hosted validation of the modified installer and the new current-Arch pacman job is pending publication; this environment cannot honestly substitute for those results because it has neither a current Arch userspace/container runtime nor a local ShellCheck binary.

## Current-Arch pacman P0

The official-ISO failure was caused by pacman 7 download privilege separation, not package availability. Current Arch configures `DownloadUser = alpm`. SKITTLES created its custom `DBPath`/`CacheDir` below a `mktemp -d` parent, which defaults to mode `0700`; pacman's low-privilege downloader therefore could not traverse `/run/skittles.*` to open `db/sync/download-*/core.db.part`.

Current libalpm creates the per-sync `download-XXXXXX` directory itself under the sync DB path and changes that directory to the configured sandbox/download user. The remediation therefore grants only ancestor traversal on SKITTLES's random parent (`0711`) while leaving `db`, `db/local`, and `cache` root-owned `0755`. It preserves the live ISO's `DownloadUser` and sandbox directives, does not recursively `chown` the workspace, does not use `DisableSandbox*`, does not mutate `/etc/pacman.conf`, and deletes temporary preflight state through the existing cleanup path.

The new `tests/test_arch_pacman_preflight.sh` is intended to prove this with current Arch rather than source-string assertions. In a disposable `archlinux:latest` job it performs a full `pacman -Syu` first, discovers the configured `DownloadUser`, executes the exact SKITTLES `pacman -Sy` against the custom DB/cache tree, then performs full `pacman -Sp` transaction resolution for both minimal and gaming profiles and an independent `pacman -Si` availability check for every explicit package. A hosted sandbox restriction must be reported distinctly and must not be worked around by weakening production pacman security.

Primary sources: <https://pacman.archlinux.page/pacman.conf.5.html>, <https://gitlab.archlinux.org/archlinux/packaging/packages/pacman/-/raw/main/pacman.conf>, <https://gitlab.archlinux.org/pacman/pacman/-/raw/master/lib/libalpm/util.c>, and <https://gitlab.archlinux.org/pacman/pacman/-/raw/master/lib/libalpm/be_sync.c>.

## License and release-gate state

SKITTLES is licensed under Apache License 2.0 using the canonical `LICENSE` text. Stable publication still fails closed through `release-signoff.json` and `scripts/check_release_signoff.py`: every mandatory physical/recovery/performance key must be present and exactly `PASS`, performance evidence must be SHA-bound to `docs/PERFORMANCE.md`, and stable notes must not contain the `DRAFT:` marker.

## Static source audit

### Destructive disk paths

Every raw destructive entry point remains bound to explicit authorization:

- `clear_disk` requires the approved plan, verifies the drive is one of the confirmed path/identity/size tuples, calls `assert_same_disk` before the first write, and now marks `DESTRUCTIVE_WRITES_STARTED=1` only immediately before the first destructive command.
- eligible destructive targets must expose at least one persistent identifier (SERIAL or WWN); both absent is fail-closed. `disk_identity` still binds major/minor, size, model, serial, and WWN.
- the plan digest binds version, wipe mode, profile, discard choice, target index, selected paths, identities, sizes, and extra-drive order.
- `wipe_and_partition` revalidates the target after clearing and immediately before partition creation.
- `format_and_mount` rechecks plan/target binding and disk identity/idle state, then verifies both generated partition devices report the expected parent before FAT formatting or `cryptsetup luksFormat`.
- extra-drive clearing is unreachable until `ARCH_INSTALLED=1` and still goes through `clear_disk` with the originally confirmed identity and size.

Mocked red-team coverage now includes pre-write failures, first-wipe failures, post-write signals, post-install extra-wipe failures, disappearing/replaced devices, mount/swap/holder races, absent persistent IDs, terminal-control metadata, cleanup failures, and second-instance locking. This minimizes accidental wrong-device writes and ordinary TOCTOU exposure; it does not claim to defeat a malicious privileged process deliberately racing device state while the installer runs.

Failure reporting now has three truthful states: before any disk writes, after destructive operations begin, and after target installation succeeds but an extra-drive wipe fails. Package synchronization/resolution and `--check` complete before disk enumeration, credential collection, or erase confirmation.

### Credential and shell handling

No `eval` is used. Passwords are read silently, deliberately unexported, excluded from xtrace/verbose mode, sent to the chroot through NUL-delimited stdin rather than command arguments, and unset after use. The LUKS passphrase is provided through `cryptsetup --key-file=-`. Core dumps are disabled. The temporary chroot helper lives on the freshly mounted target, is mode 0700, and is removed before completion. SKITTLES temporary files use random `mktemp` paths and cleanup removes only recorded/owned resources.

The generated chroot and doctor heredocs are extracted by `scripts/extract_generated_shell.py` and are independently `bash -n` checked locally. Ubuntu CI runs ShellCheck 0.9.0 over them; the new current-Arch job also installs Arch's current ShellCheck and lints the installer, integration script, chroot script, and doctor script.

### Doctor

The generated doctor remains read-only and performs no auto-sudo, repair, upload, or telemetry. Wayland is PASS, X11 is a release-significant FAIL, and a non-graphical session is informational. A failed `systemctl --failed` query is a FAIL rather than a false empty PASS. Gaming-package checks are profile-aware. The gaming check now verifies that GameMode leaves split-lock mitigation enabled.

## Live Arch package inventory — reviewed 2026-09-17

The explicitly supported package families remain present in official repositories, including both kernels, firmware/microcode, prebuilt NVIDIA open modules for both kernels, 64/32-bit NVIDIA/Vulkan userspace, Steam, GameMode, MangoHud and `ntsync-autoload`. `linux-headers` and `linux-lts-headers` remain unnecessary for SKITTLES because it deliberately uses Arch's prebuilt `nvidia-open`/`nvidia-open-lts` rather than DKMS.

Representative repository versions observed during this audit included regular `linux` 7.2.4.arch1-2, `linux-lts` 6.18.52-1, NVIDIA 615.71.09 family packages, NetworkManager 1.58.1-1 and zram-generator 1.2.1-1. These are observations, not pins. The authoritative compatibility gate is the new current-Arch job's real `pacman -Sp` resolution of both complete profiles and the subsequent real-ISO `--check --profile=gaming` run.

Authoritative source: <https://archlinux.org/packages/>.

## NVIDIA / Wayland static audit

NVIDIA's current open-kernel-module source supports Turing and later GPUs; RTX 3060 Ti is Ampere. Current Arch provides `nvidia-open` for `linux`, `nvidia-open-lts` for `linux-lts`, and matching userspace/Vulkan packages. Current Arch NVIDIA guidance says DRM KMS and fbdev are enabled by packaged defaults, so SKITTLES does not force obsolete kernel parameters.

For 595+ drivers, current Arch guidance uses `NVreg_UseKernelSuspendNotifiers=1` for full video-memory preservation and leaves legacy `nvidia-suspend`, hibernate and resume services disabled by default. Arch also uses `/var/tmp` as the backing path. Early NVIDIA module loading in the initramfs can conflict with that backing path/hibernation model, so SKITTLES continues to avoid forced early NVIDIA KMS loading. Actual Wayland, Vulkan, suspend/resume and VRAM preservation remain physical gates.

Plasma's Adaptive Sync default remains `Never`; SKITTLES does not force VRR. Current Arch guidance also notes that an X11 display-manager greeter can affect Wayland VRR detection on some systems. That is a physical/optional setting to validate, not evidence for changing the installer default.

Sources: <https://wiki.archlinux.org/title/NVIDIA>, <https://wiki.archlinux.org/title/NVIDIA/Tips_and_tricks>, <https://wiki.archlinux.org/title/Variable_refresh_rate>, and <https://github.com/NVIDIA/open-gpu-kernel-modules>.

## Gaming / performance static audit

Current Arch guidance continues to present GameMode as an opt-in per-game optimization layer, MangoHud as an overlay/measurement tool, and Gamescope as an optional gaming microcompositor. NTSync is the preferred modern Wine synchronization path where supported; Proton/vkd3d relies on a working Vulkan stack. None of this justifies forcing Gamescope, VRR, a custom kernel, overclocking, GPU power changes or global overlays.

GameMode upstream defaults can disable x86 split-lock mitigation, but current kernel documentation states that disabling the mitigation can increase system-wide denial-of-service exposure. SKITTLES has no i7-8700K benchmark evidence justifying that tradeoff, so `/etc/gamemode.ini` explicitly uses `disable_splitlock=0`. This is a security/reliability default, not a performance claim. GameMode may still request the performance governor only while participating games run and the original policy is restored afterward.

Sources: <https://wiki.archlinux.org/title/Gaming>, <https://wiki.archlinux.org/title/GameMode>, <https://wiki.archlinux.org/title/MangoHud>, <https://wiki.archlinux.org/title/Gamescope>, <https://wiki.archlinux.org/title/Wine>, <https://github.com/ValveSoftware/Proton>, <https://github.com/FeralInteractive/gamemode>, and <https://docs.kernel.org/admin-guide/sysctl/kernel.html#split-lock-mitigate-x86-only>.

## Resolver / networking static audit

The installed lifecycle remains coherent: the Arch ISO resolver remains usable while `arch-chroot` performs configuration; the outer installer creates `/etc/resolv.conf -> ../run/systemd/resolve/stub-resolv.conf` only after `arch-chroot` exits and releases its temporary resolver mount. NetworkManager is configured for `dns=systemd-resolved`; both NetworkManager and `systemd-resolved` are enabled.

Configured defaults remain deliberate: hostname sending disabled, stable pseudonymous DHCP identifiers, randomized Wi-Fi scanning, stable-per-SSID association MAC, IPv6 stable privacy/temporary addresses, LLMNR/mDNS disabled, and connectivity probing disabled. Current NetworkManager references still document the configured stable client IDs, stable-UUID DUID, stable-privacy IPv6, temporary IPv6 addresses and `stable-ssid` cloned MAC. An empty `FallbackDNS=` disables systemd-resolved's built-in public fallback servers. `DNSOverTLS=no` means SKITTLES makes no encrypted-DNS claim.

Sources: <https://networkmanager.dev/docs/api/latest/NetworkManager.conf.html>, <https://networkmanager.dev/docs/api/latest/nm-settings-nmcli.html>, <https://www.freedesktop.org/software/systemd/man/latest/resolved.conf.html>, <https://wiki.archlinux.org/title/NetworkManager>, and <https://wiki.archlinux.org/title/Systemd-resolved>.

## Firewall static audit

Generated nftables policy remains input drop / forward drop / output accept. It permits loopback, established/related traffic, ICMP/IPv6-ICMP control traffic, DHCPv4 client traffic, and link-local DHCPv6 client traffic. Reload uses the upstream idempotent `destroy table inet skittles` operation before recreating only that table; it does not use global `flush ruleset`, so unrelated tables survive. The target chroot runs `nft -c -f /etc/nftables.conf`; NetworkManager has explicit ordering on nftables and systemd-resolved.

Source: <https://netfilter.org/projects/nftables/manpage.html>.

## Low-risk sysctl audit

The existing dmesg, kernel-pointer, ptrace, ASLR, setuid-coredump, protected-link, unprivileged-BPF, kexec and redirect settings remain valid current kernel controls. `ptrace_scope` remains 1 for debugger/game compatibility. No speculative-execution mitigation, SMT, global split-lock mitigation or network-throughput tuning is disabled.

Sources: <https://docs.kernel.org/admin-guide/sysctl/kernel.html>, <https://docs.kernel.org/admin-guide/sysctl/vm.html>, <https://docs.kernel.org/networking/ip-sysctl.html>, and <https://wiki.archlinux.org/title/Security>.

## Storage / boot / recovery static audit

The current source remains internally coherent: GPT with 2 GiB FAT32 ESP; LUKS2/Argon2id root; ext4 including `/home`; systemd-based mkinitcpio with `sd-encrypt`; UUID-bound kernel command line; both `linux` and `linux-lts`; GRUB normal UEFI plus removable fallback installation; LUKS discard and weekly `fstrim` only when explicitly opted in.

Current mkinitcpio guidance supports the systemd-based `sd-encrypt` design and persistent LUKS UUID naming. Current SSD guidance continues to prefer periodic TRIM over continuous filesystem discard and treats dm-crypt discard as an explicit security/privacy tradeoff. SKITTLES therefore keeps discard opt-in. Official Arch kernels enable zswap by default; because SKITTLES intentionally provisions `/dev/zram0`, the GRUB command line keeps `zswap.enabled=0` to avoid stacking zswap in front of zram swap. No speculative VM tuning is added.

Recovery documentation uses a current Arch ISO, `cryptsetup open`, UUID/mount verification, `arch-chroot`, `pacman -Syu` rather than partial upgrades, `mkinitcpio -P`, GRUB reinstall/config generation where needed, and owned-resource teardown. This remains document/static validation only until the physical ISO recovery drill passes.

Sources: <https://wiki.archlinux.org/title/Mkinitcpio>, <https://wiki.archlinux.org/title/Dm-crypt/System_configuration>, <https://wiki.archlinux.org/title/Solid_state_drive>, <https://wiki.archlinux.org/title/GRUB>, <https://wiki.archlinux.org/title/Chroot>, <https://wiki.archlinux.org/title/Zram>, <https://wiki.archlinux.org/title/Zswap>, and <https://wiki.archlinux.org/title/System_maintenance>.

## Current documentation coverage map — reviewed 2026-09-17

This audit used current primary/upstream documentation as a compatibility map, not as a source of cargo-cult configuration. The table records the material conclusion for each requested area; physical/runtime-sensitive conclusions remain release gates rather than static PASS claims.

| Area | Current sources | Material conclusion for SKITTLES |
| --- | --- | --- |
| Installation / mirrors / Archiso | <https://wiki.archlinux.org/title/Installation_guide>, <https://wiki.archlinux.org/title/Mirrors>, <https://wiki.archlinux.org/title/Archiso> | Official-media installation assumes working networking/time and current mirrors; pacstrap inherits relevant host configuration. SKITTLES therefore proves DNS/time and complete package resolution before disk interaction. |
| Pacman / `pacman.conf` / DownloadUser | <https://wiki.archlinux.org/title/Pacman>, <https://pacman.archlinux.page/pacman.conf.5.html>, <https://gitlab.archlinux.org/archlinux/packaging/packages/pacman/-/raw/main/pacman.conf>, <https://gitlab.archlinux.org/pacman/pacman/-/raw/master/lib/libalpm/util.c>, <https://gitlab.archlinux.org/pacman/pacman/-/raw/master/lib/libalpm/be_sync.c> | Current Arch uses a low-privilege download user. libalpm creates/chowns its own `download-XXXXXX` directory; SKITTLES grants only traversal through its random parent and preserves sandboxing. A real pacman operation remains the authoritative proof. |
| Partial upgrades / maintenance | <https://wiki.archlinux.org/title/Pacman>, <https://wiki.archlinux.org/title/System_maintenance> | Partial upgrades are unsupported on installed Arch. SKITTLES uses isolated metadata for preflight and documents `pacman -Syu` for maintenance rather than using the installer as an updater. |
| UEFI / GRUB / fallback | <https://wiki.archlinux.org/title/UEFI>, <https://wiki.archlinux.org/title/GRUB>, <https://wiki.archlinux.org/title/GRUB/Tips_and_tricks> | UEFI x86-64 and a normal GRUB install plus removable fallback remain valid. Secure Boot is deliberately unsupported in this RC. |
| mkinitcpio / systemd initramfs | <https://wiki.archlinux.org/title/Mkinitcpio>, <https://wiki.archlinux.org/title/Dm-crypt/Encrypting_an_entire_system> | A systemd-based initramfs with `sd-encrypt` after `systemd` is current. SKITTLES keeps `keyboard`, `sd-vconsole`, `block`, `sd-encrypt`, filesystems and fsck in the established ordering. |
| LUKS / persistent naming / fstab | <https://wiki.archlinux.org/title/Dm-crypt/System_configuration>, <https://wiki.archlinux.org/title/Persistent_block_device_naming>, <https://wiki.archlinux.org/title/Fstab> | UUID-bound `rd.luks.name=` is current, `rd.luks.options=<UUID>=discard` remains an explicit opt-in, and generated fstab entries use persistent UUIDs. |
| SSD / TRIM / ext4 | <https://wiki.archlinux.org/title/Solid_state_drive>, <https://wiki.archlinux.org/title/Ext4> | Periodic trim is preferred over forcing continuous discard for this policy; dm-crypt discard stays opt-in. ext4 remains a current supported root filesystem and no speculative mount tuning was added. |
| Microcode | <https://wiki.archlinux.org/title/Microcode> | Intel microcode remains appropriate for the i7-8700K and is included explicitly. |
| Intel frequency scaling / `intel_pstate` | <https://wiki.archlinux.org/title/CPU_frequency_scaling>, <https://docs.kernel.org/admin-guide/pm/intel_pstate.html> | `intel_pstate` is the normal driver for this CPU generation. SKITTLES does not force a permanent performance governor; GameMode may request performance only for participating sessions. |
| zram / zswap / generator | <https://wiki.archlinux.org/title/Zram>, <https://wiki.archlinux.org/title/Zswap>, <https://github.com/systemd/zram-generator> | The design intentionally uses bounded zram swap and disables zswap at boot to avoid stacking the two mechanisms. No benchmark-free VM tuning was added. |
| NetworkManager | <https://wiki.archlinux.org/title/NetworkManager>, <https://networkmanager.dev/docs/api/latest/NetworkManager.conf.html>, <https://networkmanager.dev/docs/api/latest/nm-settings-nmcli.html> | Current settings support `systemd-resolved`, disabled DHCP hostname sending, stable identifiers, Wi-Fi scan randomization/stable-per-SSID association MAC and IPv6 privacy. |
| systemd-resolved | <https://wiki.archlinux.org/title/Systemd-resolved>, <https://www.freedesktop.org/software/systemd/man/latest/resolved.conf.html> | Stub-resolver symlink mode remains recommended; empty `FallbackDNS=` clears fallback servers. LLMNR/mDNS can remain disabled and `DNSOverTLS=no` means no encrypted-DNS claim. |
| nftables | <https://netfilter.org/projects/nftables/manpage.html> | `destroy table inet skittles` is appropriate for idempotent ownership of one table without flushing unrelated rulesets. Input/forward drop and output accept remain the intended host policy. |
| Time sync | <https://wiki.archlinux.org/title/Systemd-timesyncd>, <https://www.freedesktop.org/software/systemd/man/latest/systemd-timesyncd.service.html> | `timedatectl set-ntp true` with synchronization verification remains a suitable installation preflight. |
| KDE Plasma / Wayland / SDDM | <https://wiki.archlinux.org/title/KDE>, <https://wiki.archlinux.org/title/Wayland>, <https://wiki.archlinux.org/title/SDDM> | Plasma Wayland is the intended session; keeping the SDDM greeter conservative does not prove runtime success. The release gate still requires a real Wayland session on target hardware. |
| NVIDIA open modules / Wayland | <https://wiki.archlinux.org/title/NVIDIA>, <https://github.com/NVIDIA/open-gpu-kernel-modules> | Ampere is supported by the open kernel module path. SKITTLES uses Arch's prebuilt `nvidia-open` and `nvidia-open-lts` rather than DKMS and does not pin an old driver. |
| NVIDIA suspend / video-memory preservation | <https://wiki.archlinux.org/title/NVIDIA/Tips_and_tricks>, <https://download.nvidia.com/XFree86/Linux-x86_64/latest/README/powermanagement.html> | On current 595+ guidance, kernel suspend notifiers supersede the legacy sleep services and Arch uses `/var/tmp` backing. SKITTLES keeps legacy services disabled and avoids forced early NVIDIA initramfs loading; suspend/resume still requires physical proof. |
| Vulkan | <https://wiki.archlinux.org/title/Vulkan> | NVIDIA Vulkan needs matching 64-bit and, for 32-bit games, lib32 userspace/loaders. The gaming profile includes them. |
| Steam / Proton / Wine / vkd3d | <https://wiki.archlinux.org/title/Steam>, <https://wiki.archlinux.org/title/Gaming>, <https://wiki.archlinux.org/title/Wine>, <https://github.com/ValveSoftware/Proton> | Steam/Proton depends on a working multilib/Vulkan stack. SKITTLES provides the prerequisites but does not make runtime compatibility claims before physical testing. |
| GameMode / MangoHud | <https://wiki.archlinux.org/title/GameMode>, <https://wiki.archlinux.org/title/MangoHud>, <https://github.com/FeralInteractive/gamemode> | Both remain optional per-game tooling. GameMode is explicitly prevented from disabling split-lock mitigation; MangoHud is installed for measurement/overlay use without being forced globally. |
| NTSync | <https://wiki.archlinux.org/title/Gaming>, <https://archlinux.org/packages/?name=ntsync-autoload> | The package remains an explicit gaming-profile dependency; actual Wine/Proton use is runtime-sensitive and stays a gaming validation gate. |
| Gamescope / VRR | <https://wiki.archlinux.org/title/Gamescope>, <https://wiki.archlinux.org/title/Variable_refresh_rate> | Both are optional user/runtime choices. SKITTLES does not force Gamescope or Adaptive Sync and does not convert either into an unbenchmarked default. |
| Security / sysctls | <https://wiki.archlinux.org/title/Security>, <https://docs.kernel.org/admin-guide/sysctl/kernel.html>, <https://docs.kernel.org/admin-guide/sysctl/vm.html>, <https://docs.kernel.org/networking/ip-sysctl.html> | Existing low-risk controls remain current kernel interfaces. No `mitigations=off`, global split-lock disable or throughput-tuning pack is introduced. |
| Secure Boot / UKI | <https://wiki.archlinux.org/title/Secure_Boot>, <https://wiki.archlinux.org/title/Unified_kernel_image> | Secure Boot/UKI are valid architectures but are outside this RC's explicit GRUB/unsigned-ESP design. They are documented limitations rather than silently half-configured features. |
| Recovery / chroot | <https://wiki.archlinux.org/title/Chroot>, <https://wiki.archlinux.org/title/General_troubleshooting>, <https://wiki.archlinux.org/title/System_maintenance> | The recovery guide's Arch-ISO + LUKS + mount + `arch-chroot` + full-upgrade/initramfs/GRUB flow is aligned with current recovery guidance, but remains `NOT TESTED` until the physical drill is executed. |

## Release engineering audit

The stable workflow consumes `release-signoff.json` through `scripts/check_release_signoff.py`. Stable publication fails closed if any required key is missing, extra, malformed, empty, or not exactly `PASS`; if performance evidence is missing or its SHA-256 does not match `docs/PERFORMANCE.md`; or if stable notes still contain `DRAFT:`. RC tags may retain `NOT TESTED` hardware state, but every release still requires the committed non-empty Apache-2.0 `LICENSE` and exact tag/version equality.

The exact workflow asset recipe is exercised twice by automated tests. Two builds from the same fixed source identity produce byte-identical tarball SHA-256 values; `SHA256SUMS` self-verifies; the bundled installer is mode 0755; `SOURCE_COMMIT` is deterministic; and `.github/` plus `tests/` are excluded from the end-user archive. Repository tests remain in GitHub.

Current Action pins remain first-party full-SHA pins: `actions/checkout` v5.1.0 at `fbc6f3992d24b796d5a048ff273f7fcc4a7b6c09`, and `actions/attest` v4.2.1 at `508db95dd578ae2727ebd6217d5ba78e4fbda05d`.

## Repository hygiene and limitations

The current-tree audit checks private-key headers, common GitHub/AWS token patterns, credential-bearing URLs, NUL/binary-like tracked files, generated editor/cache junk, and oversized artifacts. Pattern scanning is not a mathematical proof that arbitrary secrets are absent.

The remaining software proof gap is environmental, not waived: the modified installer has not yet run hosted ShellCheck, and `tests/test_arch_pacman_preflight.sh` has not yet executed under current Arch/pacman 7 because this workspace has no Arch userspace/container engine and GitHub write access is currently rejected. Those must remain BLOCKED/PENDING until an exact-SHA hosted run or equivalent safe current-Arch execution exists.

## Remaining external gates

Before another destructive physical installation:

- publish the remediation commit and obtain exact-SHA green Ubuntu hosted CI;
- obtain the current-Arch job result for real pacman `-Sy`, both-profile `-Sp` transaction resolution, explicit-package `-Si` availability, and current Arch ShellCheck;
- on the same official Arch ISO class that reproduced the bug, run `bash skittles-installer.sh --check --profile=gaming` and require package synchronization/resolution to complete before disk interaction.

Before stable `v1.0.0`:

- publish/download a real RC and verify `SHA256SUMS` and GitHub attestation/provenance;
- complete physical i7-8700K + RTX 3060 Ti install/runtime validation on both kernels;
- complete NVIDIA/Wayland/Vulkan, suspend/resume, networking/audio/gaming/update validation;
- execute the Arch-ISO recovery drill as written;
- record target-hardware performance measurements and bind their SHA-256 evidence;
- only after every mandatory sign-off entry is `PASS`, reconcile final stable notes and consider `v1.0.0`.

No tag is created by this pass. No hardware result is claimed.
