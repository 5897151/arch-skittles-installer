# Release Process

SKITTLES uses Semantic Versioning. The current source is `1.0.0`, the first stable release.

## Version and prerequisite agreement

For any release, `VERSION` in `skittles-installer.sh`, the Git tag without its leading `v`, curated `docs/RELEASE-NOTES-vTAG.md`, and release asset names must agree. The workflow also requires the committed non-empty Apache-2.0 `LICENSE`.

The release job alone receives write, OIDC and attestation permissions. Repository-level workflow permissions remain `contents: read`, checkout does not persist credentials, and first-party Actions are pinned to full commit SHAs.

## Stable release sign-off

`release-signoff.json` is the machine-readable stable gate. For `v1.0.0`, `scripts/check_release_signoff.py` requires:

- schema and release identifiers exactly matching the expected stable format;
- the complete mandatory key set, with no missing, renamed or extra key;
- `PASS` for every mandatory executed gate;
- `DEFERRED` only for the explicit Arch-ISO recovery and formal-performance allowlist;
- rejection of `NOT TESTED`, `FAIL`, `BLOCKED`, `WARN`, unknown, empty or malformed values;
- a matching SHA-256 of `docs/PERFORMANCE.md` when performance measurements are `PASS`;
- a null performance SHA when performance is `DEFERRED`;
- final stable release notes with no `DRAFT:` marker.

Malformed or missing sign-off data fails closed. `DEFERRED` means the owner intentionally waived a non-mandatory gate for this release; it never means the gate passed. For v1.0.0, recovery execution and formal performance benchmarking are deferred, and no execution or benchmark-gain claim is made for either.

## Safe pre-tag validation

From a clean checkout:

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
git diff --check
```

CI requires the critical documentation/test/release files to exist. Its Ubuntu job validates the installer and generated chroot/doctor programs. Its current-Arch job upgrades the container userspace, executes the real pacman 7 `DownloadUser` preflight with sandboxing intact, resolves both package profiles, checks package availability, and runs current-Arch ShellCheck.

## Reproducible release assets

The tag workflow builds the end-user bundle with sorted paths, the source commit timestamp as archive mtime, numeric owner/group 0, and `gzip -n`. It writes deterministic `SOURCE_COMMIT`, makes the installer executable, generates `SHA256SUMS`, and immediately runs `sha256sum -c`.

The expected stable assets are:

```text
skittles-1.0.0.tar.gz
skittles-installer-1.0.0.sh
SHA256SUMS
```

The tarball contains the installer, README, license, changelog, security/contribution documents, sign-off JSON, documentation, and `SOURCE_COMMIT`. Development-only `.github/`, tests, caches and local build output are excluded.

## Stable publication

1. Start from a clean `main` containing the validated remediation commit.
2. Make one release-focused stable-promotion commit.
3. Push `main` and require both CI jobs to succeed on that exact SHA.
4. Confirm `v1.0.0` and its GitHub Release do not already exist.
5. Create annotated tag `v1.0.0` on the exact green commit and push it once. Never move a published release tag silently.
6. Let `.github/workflows/release.yml` rerun validation, enforce tag/version agreement, run the stable sign-off checker, build and checksum assets, create attestations, and publish the GitHub Release.
7. Download the three public assets, run `sha256sum -c SHA256SUMS`, and verify both binary artifacts against the expected repository/workflow:

```bash
gh attestation verify skittles-1.0.0.tar.gz \
  -R 5897151/arch-skittles-installer \
  --signer-workflow 5897151/arch-skittles-installer/.github/workflows/release.yml

gh attestation verify skittles-installer-1.0.0.sh \
  -R 5897151/arch-skittles-installer \
  --signer-workflow 5897151/arch-skittles-installer/.github/workflows/release.yml
```

Provenance proves build identity, not runtime correctness. It does not convert deferred recovery or performance work into PASS.

## Upgrade policy

SKITTLES is a destructive fresh installer. Never rerun it as an upgrade or repair mechanism. Update an installed system with normal Arch full upgrades (`pacman -Syu`) and use [Recovery](RECOVERY.md) when recovery is required.
