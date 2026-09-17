# Release Decision — 2026-09-17

## NOT READY FOR v1.0.0

Source version remains `1.0.0-rc.1`. No public RC tag or release exists, so the current P0 preflight repair does not require an RC-number increment yet. Do not create a tag until the repaired public SHA has green Ubuntu CI, green current-Arch pacman integration, and the official-ISO `--check --profile=gaming` regression succeeds.

## Verified public baseline

Before this remediation, public `main` was `5b5453bcbc9d6e6ca175adf5c9fa737f050971a1` with installer blob `09ec6f7c310c77e3dd800b9f59c85aeea13ea7cc`. Hosted CI for that baseline passed repository completeness, Bash syntax, ShellCheck 0.9.0, **74/74 Python tests**, repository hygiene, and whitespace.

A real current official Arch ISO then exposed a release-blocking preflight defect: pacman 7 downloaded as its configured low-privilege `DownloadUser` (`alpm` in current Arch packaging), but SKITTLES placed custom DB/cache state under a root-only `0700` `mktemp` parent. Pacman could not traverse into its own `db/sync/download-*` directory and failed opening `core.db.part` before any disk writes.

## Current remediation candidate

The remediation keeps pacman's normal downloader privilege separation and sandboxing. The random `/run/skittles.*` parent is `0711` (traverse only), while `db`, `db/local`, and `cache` remain root-owned `0755`. Pacman itself creates/owns its per-download directory. No recursive `chown`, `DisableSandbox*`, or live-ISO pacman configuration mutation is used.

Predictable external checks and package synchronization/resolution now complete before disk selection. `--check` exits immediately afterward, before disk enumeration, credentials, or erase confirmation. Failure reporting distinguishes pre-write failure, destructive work already started, and target-installed/extra-wipe failure. Destructive candidates now fail closed when both serial and WWN are absent. GameMode keeps kernel split-lock mitigation enabled (`disable_splitlock=0`).

Local Python discovery is **90/90 PASS**. The generated chroot and doctor programs are extracted for independent Bash/ShellCheck validation in CI. A separate current-Arch job runs the actual pacman `-Sy` operation plus minimal/gaming `-Sp` transaction resolution plus per-package `-Si` availability checks with `DownloadUser` and sandboxing intact.

## Gates still required before the first tagged RC

- Publish the remediation commit and obtain exact-SHA green Ubuntu hosted CI, including ShellCheck on the installer and both generated shell programs.
- Obtain exact-SHA green current-Arch integration or clearly establish a hosted-container sandbox block without changing production security.
- On the real current official Arch ISO, run `bash skittles-installer.sh --check --profile=gaming` and prove repository synchronization/package resolution succeeds without disk interaction.

After those software/preflight gates pass, an actual `v1.0.0-rc.1` tag may be considered because no earlier RC tag/release exists.

## Stable gates remain unchanged

Every mandatory entry in `release-signoff.json` remains `NOT TESTED`. Stable promotion still requires physical clean install, repeated LUKS unlock, both kernels, Plasma Wayland, NVIDIA/Vulkan, networking/firewall/audio/USB, suspend/resume, gaming stack, full update and post-update boots, doctor checks, complete Arch-ISO recovery, performance measurements, and real release artifact/checksum/provenance verification.

The stable release gate remains fail-closed. Missing, renamed, malformed, empty, `FAIL`, `BLOCKED`, `WARN`, or `NOT TESTED` data blocks `v1.0.0`.
