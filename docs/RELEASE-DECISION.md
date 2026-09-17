# Release Decision — 2026-09-17

## NOT READY FOR v1.0.0

The repository is in release-candidate state at `1.0.0-rc.1`. Automated local checks are healthy and GitHub-hosted Bash/ShellCheck have executed successfully, but the hosted test gate is not yet green because the public tree is missing release-infrastructure files. Owner license selection and target-hardware validation also remain open.

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

## Hosted GitHub CI status

GitHub Actions run `35165611372` tested commit `18fb447a098d99d3eb3a8255688f1fe0c72c46ad` on Ubuntu 24.04.

- Bash syntax: **PASS**.
- ShellCheck 0.9.0: **PASS**.
- Hosted token permissions: `contents: read`, `metadata: read`; no repository secrets were required.
- Unit/config/documentation stage: **FAIL**, with nine missing-file errors because the web-uploaded repository omitted `.github/workflows/release.yml`, `.github/ISSUE_TEMPLATE/bug_report.yml`, `.github/dependabot.yml`, and related hidden release files.
- Whitespace step: skipped because the prior test step failed.

This is a repository-reconciliation failure, not an installer test failure. The local intended tree contains the missing files and passes all 46 tests. A new hosted run against the reconciled tree must be green before tagging an RC. Local ShellCheck remains unavailable, so the successful hosted ShellCheck result is authoritative for the tested GitHub commit.

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

The downloaded assets must then be checked with `sha256sum -c SHA256SUMS` and `gh attestation verify ... -R 5897151/arch-skittles-installer --signer-workflow 5897151/arch-skittles-installer/.github/workflows/release.yml`. The stable workflow also blocks publication while hardware sign-off tables contain `NOT TESTED`, performance measurements are unrecorded, or stable release notes retain their `DRAFT` marker.

## Promotion rule

Do not change the installer/tag/release notes to `1.0.0` until the license is resolved, GitHub CI passes, every required real-hardware/recovery test is recorded PASS, measurements are documented, and release assets/provenance have been verified from the actual tag.
