# Release Decision — 2026-09-17

## NOT READY FOR v1.0.0

Source version remains `1.0.0-rc.1`. Repository repair and the four correctness fixes are now proven by hosted CI, but the owner-selected license, physical target validation, recovery execution, performance measurements, and a real tagged release remain open.

## Exact hosted baseline

GitHub Actions run `35172528577` tested public `main` commit `5fc333d5ee45c8c07787802c4605483f6d717b17` on Ubuntu 24.04.

| Check | Result |
| --- | --- |
| Repository completeness | PASS |
| Bash syntax | PASS |
| ShellCheck | PASS, 0.9.0 |
| Python discovery | PASS, 50/50 tests |
| Whitespace | PASS |
| CI token permissions | `contents: read`, `metadata: read` |

The hosted 50-test suite includes regressions for resolver handoff after `arch-chroot`, target identity revalidation between wipe and partitioning, failed-service doctor query errors, and console-session handling. This is the first legitimate hosted baseline for the corrected installer.

## Final automated hardening prepared after that baseline

The installer bytes remain identical to the hosted baseline (Git blob `0532da3e6c8733bf0b88afe861ba3469acd75af0`). The follow-up release-engineering batch changes workflows, tests, release metadata, and documentation only.

Local final validation currently includes:

- fail-closed machine-readable stable sign-off in `release-signoff.json`;
- stable-gate fixtures for PASS, FAIL, NOT TESTED, BLOCKED, WARN, empty/missing/malformed data, missing/changed performance evidence, and draft stable notes;
- executable tests for missing `LICENSE` and tag/version mismatch;
- two-build byte-for-byte release-archive reproducibility testing using the workflow's actual build step;
- CI current-tree hygiene scan for private-key/token patterns, credential-bearing URLs, NUL/binary-like tracked files, and generated junk;
- adversarial input and destructive-path guard tests;
- recovery resolver documentation corrected to use current `arch-chroot` behavior;
- current package/NVIDIA/network/CPU/storage/recovery/security static audits recorded in [RELEASE-AUDIT.md](RELEASE-AUDIT.md).

A clean final-tree simulation passes Bash syntax, **68/68 Python tests**, five GitHub YAML parses, `release-signoff.json` parsing, all local Markdown relative links, the repository hygiene scan, and `git diff --check`. The exact release build recipe produced the same tarball SHA-256 twice (`6ed72c587fce74a5e9268a3da4ce1b6bea3cebba0c6bdbd39cccaa1a910deb4c` with the fixed test source identity), and the untouched stable sign-off correctly fails closed because hardware entries remain `NOT TESTED`. Local ShellCheck is unavailable, but `skittles-installer.sh` is byte-identical to the hosted ShellCheck-green baseline.

This follow-up batch cannot become release evidence until it is committed to public `main` and its exact SHA receives a hosted green run. The GitHub integration currently returns HTTP 403 for repository writes, so publication is an external access blocker rather than an unresolved code defect.

## License blocker

`LICENSE` is intentionally absent. The owner must choose MIT, Apache-2.0, or GPL-3.0-or-later and provide the correct copyright-holder text. The release workflow refuses every tag, including RC tags, until a non-empty `LICENSE` exists.

## Hardware and recovery gates

Every entry in `release-signoff.json` remains `NOT TESTED`. Required physical evidence includes clean install, LUKS unlock, cold/warm boots, both kernels, Plasma Wayland, NVIDIA/Vulkan, network/DNS/firewall, audio/USB, repeated suspend/resume, gaming stack, full update, post-update boots, doctor checks, complete Arch-ISO recovery, and performance measurements.

The stable release gate requires every mandatory key to equal `PASS`, requires `docs/PERFORMANCE.md` to match its recorded SHA-256 evidence, and requires stable release notes to have no `DRAFT:` marker. Missing/renamed/malformed sign-off data fails closed.

## Release artifact gate

There are currently no Git tags and no GitHub releases. Retaining `1.0.0-rc.1` is therefore correct; no immutable RC tag is being moved or replaced.

After the owner license is selected and the final exact-SHA CI is green, an RC tag may be created. The real GitHub release assets must then be downloaded independently, checked with `sha256sum -c SHA256SUMS`, and verified with `gh attestation verify` against `5897151/arch-skittles-installer/.github/workflows/release.yml`. Only those downloaded RC bytes qualify for physical validation.

## Promotion rule

Do not promote to `v1.0.0` until the owner license exists, the final source SHA has green hosted CI, every mandatory machine-readable sign-off is PASS, performance evidence is recorded, stable notes are no longer draft, the recovery procedure has actually been executed, and the real tagged assets/provenance have been verified.
