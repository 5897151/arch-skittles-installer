# Release Process

SKITTLES uses Semantic Versioning. The current source remains `1.0.0-rc.1`; there is no existing tag or GitHub release, so that RC number has not been consumed.

## Version and prerequisite agreement

For any release, all of these must agree: `VERSION` in `skittles-installer.sh`, the Git tag without its leading `v`, curated `docs/RELEASE-NOTES-vTAG.md`, and the release asset names. The workflow also requires a non-empty owner-selected `LICENSE` before either RC or stable publication.

The release job alone receives write/OIDC/attestation permissions. Repository-level workflow permissions remain `contents: read`, checkout does not persist credentials, and first-party Actions are pinned to full commit SHAs.

## Stable release sign-off

`release-signoff.json` is the machine-readable stable gate. It intentionally starts with every physical result as `NOT TESTED`.

For `v1.0.0`, `scripts/check_release_signoff.py` requires:

- schema and release identifiers exactly matching the expected stable format;
- the complete mandatory key set, with no missing, renamed, or extra key;
- every mandatory status exactly `PASS` (so `NOT TESTED`, `FAIL`, `BLOCKED`, `WARN`, and empty/unknown values all block);
- `performance_measurements=PASS` plus `evidence.performance_sha256` matching the actual `docs/PERFORMANCE.md` bytes;
- stable release notes with the `DRAFT:` marker removed.

Malformed or missing sign-off data fails closed. RC publication intentionally does not require hardware PASS, because an RC is the artifact used to obtain that hardware evidence; however, the license and tag/version prerequisites still apply.

When physical testing is completed, update the human-readable tables in `docs/TESTING.md`/`docs/PERFORMANCE.md` and the corresponding machine-readable status together. Do not mark a field PASS from static inspection alone.

## Safe pre-tag validation

From a clean checkout:

```bash
bash -n skittles-installer.sh
shellcheck skittles-installer.sh
python3 -m unittest discover -s tests -v
python3 scripts/audit_repository.py
git diff --check
```

CI additionally requires the critical documentation/test/release files to exist, preventing an accidentally reduced test tree from producing a misleading green run.

## Reproducible release assets

The tag workflow builds the end-user bundle with sorted paths, the source commit timestamp as archive mtime, numeric owner/group 0, and `gzip -n`. It writes deterministic `SOURCE_COMMIT`, makes the installer executable, generates `SHA256SUMS`, and immediately runs `sha256sum -c`.

Automated regression tests execute that exact build step twice from the same fixed source identity and require identical tarball SHA-256 values.

The tarball deliberately contains:

- `skittles-installer.sh`;
- `README.md`;
- `LICENSE`;
- `CHANGELOG.md`;
- `SECURITY.md`;
- `CONTRIBUTING.md`;
- `release-signoff.json`;
- `docs/`;
- `SOURCE_COMMIT`.

Development-only `.github/`, `tests/`, caches, and local build output are excluded from the public release archive. The repository test suite itself must remain present in GitHub.

## Release-candidate procedure

1. Resolve the owner license and commit the actual `LICENSE`.
2. Ensure the intended RC source is clean, reviewed, and green on hosted CI.
3. Confirm no immutable tag/release already uses the RC version.
4. Create the RC tag on the exact green commit; never move an existing public tag.
5. Let the tag-only workflow rerun validation, build assets, checksum them, attest them, and publish the prerelease.
6. Download the published assets as an ordinary user and run `sha256sum -c SHA256SUMS`.
7. Verify provenance against the expected repository/workflow, for example:

```bash
gh attestation verify skittles-VERSION.tar.gz \
  -R 5897151/arch-skittles-installer \
  --signer-workflow 5897151/arch-skittles-installer/.github/workflows/release.yml
```

8. Perform all physical validation from those downloaded RC bytes, not a newer workspace.
9. If code changes are needed after a published RC, increment the RC number instead of moving the tag.

## Stable promotion

Only create `v1.0.0` when every `release-signoff.json` key is PASS, performance evidence is SHA-bound, stable notes are no longer draft, exact-source hosted CI is green, and the owner accepts the release evidence. The stable workflow will independently re-run the fail-closed validator.

After publishing stable, independently download and re-verify checksums and attestation. Provenance proves build identity, not correctness; source review and hardware/recovery evidence remain distinct.

## Repository hygiene

Before tags, review the current tree and available history for credentials, Wi-Fi secrets, private keys, personal machine data, generated junk, unexpected binaries, or transfer artifacts. CI's hygiene scanner covers common current-tree patterns but cannot prove every possible secret or replace GitHub secret scanning/push protection.

## Upgrade policy

SKITTLES is a destructive fresh installer. Never rerun it as an upgrade or repair mechanism. Update an installed system with normal Arch full upgrades (`pacman -Syu`) and use `docs/RECOVERY.md` when recovery is required.
