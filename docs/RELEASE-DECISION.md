# Release Decision — 2026-09-17

## NOT READY FOR v1.0.0

The repository is in release-candidate state at `1.0.0-rc.1`. Automated local checks are healthy, but stable release gates that require owner action, GitHub execution, and the target physical machine remain open.

## Completed locally

- `bash -n skittles-installer.sh`: PASS.
- Python/unit/config/documentation/workflow suite: PASS, 46 tests.
- `git diff --check`: PASS.
- GitHub workflow/issue/dependabot YAML parse: PASS.
- Current tracked-tree secret-pattern scan: PASS for private-key headers, common GitHub/AWS token forms, credentialed URLs, and Wi-Fi PSK assignments.
- Local Git history secret-pattern scan: PASS for the same patterns.
- Tracked binary/NUL-byte scan: PASS; no binary blobs found.
- Literal personal-home-path scan: PASS.
- Generated-junk scan: PASS.
- Destructive tests use mocks; the exact-byte overwrite regression writes only to an ordinary temporary file.

The imported repository does not include the project's complete pre-audit history, so the local history scan cannot prove older upstream history is clean.

## Tooling / CI blockers

- ShellCheck is not installed in this local runner and local network retrieval was unavailable, so local ShellCheck execution remains blocked. The committed GitHub CI workflow runs ShellCheck on `ubuntu-24.04` without root, but that workflow has not executed because this workspace has no configured Git remote.
- No GitHub CI run has therefore been observed as PASS for this commit.

## Publication blocker

- `LICENSE` is missing. The owner must select and add an authorized license, then update README/release material to name it accurately. The release workflow intentionally refuses to publish any release without a non-empty `LICENSE`.

## Hardware validation still required

Every item below remains `NOT TESTED` on the supported i7-8700K + RTX 3060 Ti machine from the exact RC artifact:

- clean install from a current verified Arch ISO;
- cold boot, warm reboot, and repeated LUKS unlock;
- `linux` boot and `linux-lts` boot/recovery selection;
- Plasma Wayland login/logout and lock/unlock;
- NVIDIA modules, `nvidia-smi`, Vulkan, sustained GPU load, and multi-hour idle;
- CPU-load stability and recorded benchmark/power/thermal measurements for shipped performance policy;
- Ethernet, DHCP renewal, DNS through `systemd-resolved`, IPv6 when available, and nftables ordinary connectivity;
- audio and representative USB devices;
- repeated suspend/resume;
- gaming profile: Steam, Proton, 32-bit NVIDIA/Vulkan, GameMode, MangoHud, and NTSync;
- full package upgrade, kernel update, NVIDIA update, then both-kernel boots;
- `skittles-doctor` as user and root before/after updates;
- the full current-Arch-ISO recovery procedure in `docs/RECOVERY.md`;
- if practical, a second clean install from the exact RC release artifact.

## Release-asset validation still required

Because the license gate is unresolved and no tag/remote release exists, no official release assets or final hashes have been produced. Before stable release, the actual tagged workflow must create and publish:

- `skittles-1.0.0.tar.gz`;
- `skittles-installer-1.0.0.sh`;
- `SHA256SUMS` containing the real SHA-256 hashes;
- GitHub artifact provenance for the published assets.

The downloaded assets must then be checked with `sha256sum -c SHA256SUMS` and `gh attestation verify ... -R OWNER/skittles`. The stable workflow also blocks publication while hardware sign-off tables contain `NOT TESTED`, performance measurements are unrecorded, or stable release notes retain their `DRAFT` marker.

## Promotion rule

Do not change the installer/tag/release notes to `1.0.0` until the license is resolved, GitHub CI passes, every required real-hardware/recovery test is recorded PASS, measurements are documented, and release assets/provenance have been verified from the actual tag.
