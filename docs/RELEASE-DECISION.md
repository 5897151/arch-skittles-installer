# Release Decision — 2026-09-17

## APPROVED FOR v1.0.0

The owner has approved SKITTLES `1.0.0` as the first stable release. The promotion is release-only: installer runtime behavior remains the validated behavior from public remediation commit `cc62cd73467701bd1c15a1be5b99af68551647ad`, apart from changing the reported source version from `1.0.0-rc.1` to `1.0.0`.

## Automated evidence

Hosted GitHub Actions CI run `35285336084` passed on exact commit `cc62cd73467701bd1c15a1be5b99af68551647ad`. It covered 92/92 Python tests, Bash syntax, ShellCheck for the installer and extracted chroot/doctor scripts, repository hygiene, whitespace validation, current-Arch pacman 7 integration, preserved `DownloadUser` sandbox behavior, and both-profile package resolution.

The stable promotion adds four focused release-policy/version-consistency tests, bringing local discovery to 96/96 PASS. Exact-source CI must pass again on the stable-promotion commit before the tag is created.

## Target-hardware evidence

Physical validation on the supported Intel Core i7-8700K + NVIDIA RTX 3060 Ti gaming-profile system covers clean installation, normal and LTS kernel boots, LUKS unlock, Plasma Wayland, NVIDIA/Vulkan, networking/DNS/nftables/audio/USB, suspend/resume on both kernels, doctor checks, and the documented Steam/Proton/32-bit graphics/GameMode/MangoHud/NTSync runtime path.

A complete `pacman -Syu` transaction and subsequent boots on both kernels passed. No package upgrades were available during that transaction, so this does not demonstrate survival across an actual kernel or NVIDIA package-version transition.

## Explicitly deferred gates

The owner intentionally deferred the physical Arch-ISO recovery drill and formal performance benchmark matrix for v1.0.0. They are recorded as `DEFERRED`, never `PASS`.

- Recovery documentation was audited, but unlock/mount/chroot, repair, initramfs, GRUB, LTS recovery boot, and clean teardown were not executed as a formal release drill.
- No controlled benchmark matrix was executed. No FPS, latency, throughput, power, or other performance gain is claimed, and no benchmark SHA is fabricated.

## Fail-closed policy

`scripts/check_release_signoff.py` requires the exact key set. Executed mandatory gates must be `PASS`. Only the explicit recovery/performance allowlist may be `DEFERRED`; `NOT TESTED`, `FAIL`, `BLOCKED`, `WARN`, unknown, empty, missing, extra, and malformed values block the release. Performance SHA-256 evidence is mandatory only when performance measurements are `PASS`.

The tag may be created only after the stable-promotion commit passes exact-SHA hosted CI. The release workflow must then rerun validation, build and checksum the expected assets, attest them, pass the stable sign-off checker, and publish the GitHub Release.
