# Release Decision — 2026-09-17

## NOT READY FOR v1.0.0

Source version: `1.0.0-rc.1`. The missing documentation and test modules have been restored locally. The full hosted baseline is still blocked; local success is not a hosted or hardware release gate.

## Repository repair evidence

- Observed public `main`: `d2331a1c586907a6a6a16ada1179eb9d54484314`.
- Local union repair: `2bb7bff68a5ba63c24eb2dbfce5246c851f051a3`.
- Exactly nine files restored from `43e9e4ef10b45cc0367fea57a76789c21c1b9850`; no existing files deleted or replaced.
- All four Python test modules discovered: docs, GitHub, installer, release metadata.
- Installer bytes unchanged from public `main` (Git blob `66687ea9d3a41ea68beb8aa1887c9df859181139`).
- Follow-up documentation and CI completeness checks do not change installer behavior. Use `git rev-parse HEAD` for their containing commit; this document does not claim a hosted result for that commit.

## Local automated evidence

At the union repair commit:

| Check | Result |
| --- | --- |
| Bash syntax | PASS |
| Python discovery | PASS, 46 tests across all four modules |
| All five GitHub YAML files | PASS, PyYAML 6.0.3 |
| Staged whitespace | PASS |
| Relative Markdown file links | PASS, 13 links across all Markdown; anchors not validated |
| Tracked binary/NUL and junk scan | PASS, no findings |
| Secret-pattern scan | PASS, no findings across 42 unique blobs in available Git history |
| Local ShellCheck | BLOCKED, executable unavailable |

The secret scan covered private-key headers, common GitHub/AWS token forms, bearer tokens, credential-bearing URLs, literal Wi-Fi PSK assignments, and personal home paths. Pattern scanning is not proof that arbitrary credentials or identifying data are absent. History coverage is limited to Git objects available in the clone.

## Hosted GitHub CI evidence

[Run 35170020735](https://github.com/5897151/arch-skittles-installer/actions/runs/35170020735) tested **only** `d2331a1c586907a6a6a16ada1179eb9d54484314`:

- Bash syntax: PASS.
- ShellCheck **0.9.0**: PASS.
- Python: **7 tests PASS**, all from `test_github.py`; insufficient for the required release gate.
- Whitespace: PASS.
- Observed token permissions: contents read, metadata read.

The restored 46-test tree has **not** run on GitHub. Automatic approval review rejected the push to public `main`, because it did not accept the attached mandate as direct authorization for that remote mutation. Explicit owner approval in chat is needed to publish the prepared commits. No alternative remote mutation was attempted.

## Review still open

See [RELEASE-AUDIT.md](RELEASE-AUDIT.md). In particular, current `arch-chroot` resolver bind-mount behavior conflicts with the generated script replacing `/etc/resolv.conf`. This is a source-review finding, not a reproduced hardware failure. Installer changes remain frozen until the complete hosted baseline passes, then this requires a regression test and repair before hardware validation.

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

The license gate is unresolved. The GitHub releases endpoint returned no releases on 2026-09-17; no published release assets or provenance have been verified. Before stable release, the actual tagged workflow must create and publish:

- `skittles-1.0.0.tar.gz`;
- `skittles-installer-1.0.0.sh`;
- `SHA256SUMS` containing the real SHA-256 hashes;
- GitHub artifact provenance for the published assets.

The downloaded assets must then be checked with `sha256sum -c SHA256SUMS` and `gh attestation verify ... -R 5897151/arch-skittles-installer --signer-workflow 5897151/arch-skittles-installer/.github/workflows/release.yml`. The stable workflow also blocks publication while hardware sign-off tables contain `NOT TESTED`, performance measurements are unrecorded, or stable release notes retain their `DRAFT` marker.

## Promotion rule

Do not change the installer/tag/release notes to `1.0.0` until the license is resolved, GitHub CI passes, every required real-hardware/recovery test is recorded PASS, measurements are documented, and release assets/provenance have been verified from the actual tag.
