# Contributing to SKITTLES

SKITTLES values small, auditable changes over broad tuning. Contributions must preserve the installer's central safety property: only an explicitly inspected and confirmed disk plan can reach destructive commands.

## Development style

- Bash must remain compatible with the current official Arch installation ISO.
- Use `set -Eeuo pipefail` semantics deliberately; do not hide expected failures with broad `|| true` unless the behavior is explicitly diagnostic/cleanup.
- Quote variable expansions unless shell semantics specifically require otherwise.
- Keep package lists explicit and profiles easy to compare.
- Prefer generated configuration files that can be parsed/validated before reboot.
- Do not add background network calls or telemetry.
- Keep comments focused on why a safety/security decision exists.

## Safety requirements

Changes to disk discovery, selection, identity, confirmation, wiping, partitioning, mounting, cryptsetup, or cleanup require regression tests. Do not submit a confirmation bypass, unattended force flag, default target disk, automatic unmount of unrelated storage, or fallback that silently selects a different disk.

Any contribution touching disk selection/wiping, cryptsetup, GRUB/Secure Boot, sudo, firewall, resolver identity, or root-owned generated scripts receives extra scrutiny.

## Performance changes

A performance tweak needs a hypothesis, measurement method, target workload, baseline, repeated result, and downside. A forum post or benchmark from unrelated hardware is not sufficient evidence for a default change.

Do not add `mitigations=off`, constant overclocking, forced maximum GPU clocks, giant TCP buffers, random sysctls, universal I/O schedulers, or a gaming kernel merely because it is advertised as faster.

## Security/privacy changes

Use primary documentation where possible: Arch package metadata/manuals, upstream project documentation, kernel/systemd/NetworkManager/NVIDIA documentation, or clearly applicable ArchWiki guidance. State privacy tradeoffs rather than assigning a score.

## Running tests

```bash
bash -n skittles-installer.sh
shellcheck skittles-installer.sh
python3 -m unittest discover -s tests -v
git diff --check
```

Automated tests must not require root and must not access real block devices. Destructive tools are mocked; the one byte-count overwrite regression test writes only to an ordinary temporary file.

Before requesting stable-release inclusion, follow the real-hardware matrix in [docs/TESTING.md](docs/TESTING.md).
