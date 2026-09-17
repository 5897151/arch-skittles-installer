# Release Decision — 2026-09-17

## NOT READY FOR v1.0.0

Source version remains `1.0.0-rc.1`. Automated/static validation is green and the project license is resolved as Apache-2.0. Stable promotion is still blocked by physical target validation, recovery execution, performance measurements, and verification of a real tagged RC artifact/provenance.

## Exact hosted automated baseline

GitHub Actions run `35175926302` tested public `main` commit `8b3632938aaff6d6721a064b36b12b78b0ed0fbb` on Ubuntu 24.04.

| Check | Result |
| --- | --- |
| Repository completeness | PASS |
| Bash syntax | PASS |
| ShellCheck | PASS, 0.9.0 |
| Python discovery | PASS, 68/68 tests |
| Repository hygiene | PASS, 32 tracked files scanned |
| Whitespace | PASS |
| CI token permissions | `contents: read`, `metadata: read` |

The automated suite covers CLI/profile behavior, generated configuration, destructive-operation mocks, disk-plan/identity guards, credential transport, resolver handoff, release prerequisites, deterministic release assets, fail-closed stable sign-off, repository hygiene, recovery guidance, and documentation consistency.

## License decision

Apache License 2.0 is selected and the canonical `LICENSE` is part of the source tree. It preserves permissive reuse and commercial/fork freedom while adding an explicit contributor patent grant and defined notice/modification obligations. This resolves the former license blocker only; it does not affect physical release gates.

## Installer integrity

This public-facing polish pass does not modify `skittles-installer.sh`. The installer blob remains `0532da3e6c8733bf0b88afe861ba3469acd75af0`, the same installer bytes that passed hosted ShellCheck and the 68-test baseline.

## Hardware, recovery, and performance gates

Every mandatory entry in `release-signoff.json` remains `NOT TESTED`. Required physical evidence includes clean install, repeated LUKS unlock, cold/warm boots, both kernels, Plasma Wayland, NVIDIA/Vulkan, network/DNS/firewall, audio/USB, repeated suspend/resume, gaming stack, full update, post-update boots, doctor checks, complete Arch-ISO recovery, and performance measurements.

The stable release gate requires every mandatory key to equal `PASS`, requires `docs/PERFORMANCE.md` to match its recorded SHA-256 evidence, and requires stable release notes to have no `DRAFT:` marker. Missing, renamed, malformed, empty, `FAIL`, `BLOCKED`, `WARN`, or `NOT TESTED` sign-off data fails closed.

## Release artifact gate

No stable `v1.0.0` release may be created by this documentation/license pass. A real RC must be built by the GitHub release workflow, downloaded independently, checked with `sha256sum -c SHA256SUMS`, and verified with `gh attestation verify` against `5897151/arch-skittles-installer/.github/workflows/release.yml`. Only those downloaded RC bytes qualify for physical validation.

## Promotion rule

Do not promote to `v1.0.0` until the final public source SHA has green hosted CI, every mandatory machine-readable sign-off is PASS, performance evidence is recorded and SHA-bound, the recovery procedure has actually been executed, stable notes are no longer draft, and the real tagged assets/checksums/provenance have been verified.
