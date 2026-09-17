# Release Process

SKITTLES uses Semantic Versioning. The current source identifies itself as `1.0.0-rc.1`; it must not be tagged or described as stable `1.0.0` until every stable gate is satisfied.

## Version agreement

For a release, these must agree exactly:

- `VERSION` in `skittles-installer.sh`;
- `/etc/skittles-release` produced by that installer;
- the Git tag without its leading `v`;
- release title/notes;
- release bundle directory/name.

Automated tests should fail on a mismatch that can be checked without hardware.

## Stable release gates

`v1.0.0` is blocked until all of the following are recorded as passing:

- CI, including Bash syntax, ShellCheck, full tests, and release consistency checks;
- clean install on the i7-8700K + RTX 3060 Ti target from the RC artifact;
- both `linux` and `linux-lts` boot;
- reliable LUKS unlock;
- NVIDIA and Plasma Wayland;
- networking, DHCP renewal, DNS, IPv6 where available, and nftables ordinary connectivity;
- gaming-profile Steam/Proton/GameMode/MangoHud/NTSync/32-bit Vulkan tests;
- suspend/resume;
- documented recovery procedure;
- full package/kernel/NVIDIA update and subsequent boots;
- no unresolved blocker or secret finding;
- owner-authorized license;
- verifiable release artifact/checksum/provenance path.

See [TESTING.md](TESTING.md) for the sign-off matrix.

## License blocker

No license is currently authorized by the repository owner. Do not invent a copyright holder or silently select a license. Common choices the owner can consider:

- **MIT** — short permissive license allowing reuse/modification with attribution/license notice.
- **Apache-2.0** — permissive license with explicit patent grant and more detailed terms.
- **GPL-3.0-or-later** — strong copyleft requiring distributed derivative works to remain under compatible GPL terms and provide corresponding source.

Until the owner chooses and adds the actual license text, the project should not call itself open source and stable `v1.0.0` remains blocked.


## GitHub Actions supply-chain choices

The repository uses only first-party GitHub Actions in the release path:

- `actions/checkout` reads the tagged source. It is pinned to a full commit SHA and `persist-credentials: false` prevents the checkout step from leaving write credentials in the local Git config.
- `actions/attest` creates provenance for the built release assets. It is pinned to a full commit SHA and receives `id-token`, `attestations`, and artifact-metadata write permissions only in the tag-only release job.

No third-party Marketplace Action is used for shell commands, checksum generation, archiving, or publishing. The GitHub CLI already present on the hosted runner publishes the release. Dependabot is configured to review GitHub Actions updates.

The release workflow intentionally refuses to publish anything until a non-empty `LICENSE` exists and the pushed tag exactly matches the installer's `VERSION`. It also requires tag-specific curated notes (`docs/RELEASE-NOTES-vTAG.md`); stable tags are blocked while hardware sign-off rows remain `NOT TESTED`, performance measurements remain unrecorded, or the stable notes retain their `DRAFT` marker.

## Release-candidate procedure

1. Ensure the working tree is clean and the intended RC version is committed.
2. Run all safe automated tests and CI.
3. Search the tree/history available to the maintainer for credentials, Wi-Fi secrets, test passwords, private paths, personal hostnames, API keys, generated junk, and unexplained binaries.
4. Build the release bundle from the committed tag, not from an uncommitted working tree.
5. Generate `SHA256SUMS` for release assets.
6. Generate GitHub artifact provenance when the repository/workflow supports it.
7. Verify the downloaded RC artifact independently on another machine/context.
8. Install the RC artifact on the real target and complete [TESTING.md](TESTING.md).
9. Use the machine normally, including suspend/resume and updates; do not promote immediately after unit tests.
10. If fixes are needed, increment the pre-release (`rc.2`, etc.) and repeat relevant gates.

## Release bundle contents

The published tarball is an end-user release bundle, not a mirror of the development checkout. It contains `skittles-installer.sh`, `README.md`, `LICENSE`, `CHANGELOG.md`, `SECURITY.md`, `CONTRIBUTING.md`, the `docs/` tree, and `SOURCE_COMMIT`. The installer inside the archive is executable. Development-only material such as `.github/`, `tests/`, caches, editor files, and local build output is excluded.

## Artifact verification concepts

### Integrity checksum

A published `SHA256SUMS` lets a user detect accidental or mismatched bytes:

```bash
sha256sum -c SHA256SUMS
```

If the checksum file and artifact are both replaced at the same compromised origin, the checksum alone does not prove authenticity.

### Git tag/signature

A Git tag identifies the source commit. If the maintainer signs tags and users validate the signing identity, that can add source authenticity. SKITTLES does not claim signed tags until the owner actually configures and publishes them.

### GitHub artifact provenance

When the release workflow generates a GitHub artifact attestation, users can verify that a specific artifact was produced by the expected repository/workflow/commit. For this repository:

```bash
gh attestation verify skittles-VERSION.tar.gz -R 5897151/arch-skittles-installer --signer-workflow 5897151/arch-skittles-installer/.github/workflows/release.yml
```

Provenance does **not** prove the installer is safe or bug-free. It proves the artifact is tied to the recorded build identity.

### Source review

For a root/destructive installer, source review remains important even when checksums and attestations verify perfectly. Pay special attention to drive selection/confirmation, `clear_disk`, partitioning, cryptsetup, chroot-generated configuration, bootloader commands, and release workflow.

## Git/repository hygiene

Before publishing a tag:

- working tree clean;
- no generated cache/junk files;
- no credentials, test passwords, Wi-Fi secrets, personal hostnames, API keys, or private paths;
- no unexplained binary blobs;
- no editor swap/backup files;
- review history for accidentally committed secrets when the complete history is available;
- enable secret scanning and push protection on the public repository;
- enable Private Vulnerability Reporting;
- enable code scanning when it provides actionable signal.

## Real GitHub validation record

Hosted GitHub Actions has now executed against the public repository. The first hosted run is evidence of the environment and static-analysis behavior, but it is **not a green release gate** because the web upload omitted release-infrastructure files required by the test suite.

Recorded run:

- repository: `5897151/arch-skittles-installer`;
- workflow: `CI`;
- run ID: `35165611372`;
- run URL: `https://github.com/5897151/arch-skittles-installer/actions/runs/35165611372`;
- tested commit: `18fb447a098d99d3eb3a8255688f1fe0c72c46ad`;
- Bash syntax: **PASS**;
- ShellCheck 0.9.0: **PASS**;
- unit/config/documentation tests: **FAIL**, because `.github/workflows/release.yml`, `.github/ISSUE_TEMPLATE/bug_report.yml`, and `.github/dependabot.yml` were absent from the uploaded GitHub tree; 40 tests were reached and nine errors were missing-file errors;
- whitespace step: skipped after the test-step failure;
- `GITHUB_TOKEN` permissions observed in the hosted log: `contents: read`, `metadata: read`; no repository secrets were required.

The intended local RC tree contains the missing files and passes all 46 tests. The next hosted run must test the reconciled tree and finish Bash syntax, ShellCheck, all tests, and whitespace checks successfully before an RC tag is created.

## Current status

`1.0.0-rc.1` remains a release candidate. Hardware sign-off and license selection are not complete, so `v1.0.0` is not authorized.
