# Release Decision — 2026-09-17

## NOT READY FOR v1.0.0

Source version: `1.0.0-rc.1`. The missing documentation and test modules have been restored locally. The full hosted baseline now passes; follow-up correctness fixes have only local validation. Neither is a hardware release gate.

## Repository repair evidence

- Observed public `main`: `d2331a1c586907a6a6a16ada1179eb9d54484314`.
- Local union repair: `2bb7bff68a5ba63c24eb2dbfce5246c851f051a3`.
- Exactly nine files restored from `43e9e4ef10b45cc0367fea57a76789c21c1b9850`; no existing files deleted or replaced.
- All four Python test modules discovered: docs, GitHub, installer, release metadata.
- Installer bytes unchanged from public `main` (Git blob `66687ea9d3a41ea68beb8aa1887c9df859181139`).
- The original repair and CI completeness commits did not change installer behavior. Subsequent correctness changes are listed below; use `git rev-parse HEAD` for their containing commit. No hosted result is claimed for them yet.

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

The owner imported and pushed the prepared commits. [Run 35172143080](https://github.com/5897151/arch-skittles-installer/actions/runs/35172143080) tested `580532268d2e0e39f4671dd0b035b75ed3170e6f`:

- Complete documentation/test tree check: PASS.
- Bash syntax: PASS.
- ShellCheck **0.9.0**: PASS.
- Python: **46 tests PASS**, all four modules discovered.
- Whitespace: PASS.

This is the first verified complete hosted baseline. It does not cover subsequent fixes.

## Follow-up fixes awaiting publication

The follow-up source passes **50 local tests**. The four added regressions cover resolver replacement ordering and chroot failure, identity change between wipe and partitioning, failed-service query errors, and console-session handling. Bash syntax and whitespace checks pass locally. ShellCheck is unavailable locally; the baseline result cannot be carried over to changed installer code.

Installer behavior changed only in those areas. No release version/tag/license was changed. The accidentally tracked transfer bundle is removed from the follow-up source tree.

GitHub publication remains blocked by credentials: shell Git has no authenticated push credentials and the GitHub integration rejected tree creation with HTTP 403. Owner authorization is already explicit; no further authorization is required, but working write access is needed. The broader audit and exact-SHA hosted verification remain incomplete. See [RELEASE-AUDIT.md](RELEASE-AUDIT.md).

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
