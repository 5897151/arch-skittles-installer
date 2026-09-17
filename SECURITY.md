# Security Policy

SKITTLES runs as root, creates an encrypted operating system, modifies firmware boot entries, and can irreversibly erase selected disks. Security reports therefore deserve a private path and conservative disclosure.

## Supported versions

| Version | Supported |
| --- | --- |
| `1.0.0-rc.1` | Yes, for release-candidate security review |
| older development snapshots | No guaranteed support |
| `1.0.0` | Not released |

## Reporting a vulnerability

The repository owner should enable **GitHub Private Vulnerability Reporting** before public release. No private security email address has been supplied, so this project does not invent one.

When Private Vulnerability Reporting is enabled, use that channel for issues that could expose data, bypass destructive-operation safeguards, undermine encryption/boot assumptions, or create a privilege boundary failure. If no private channel is available yet, do not publish destructive-drive-selection bypass details in a public issue; contact the repository owner through a private channel they explicitly provide.

Please include the SKITTLES version/commit, affected path, reproducible conditions, expected/actual behavior, and whether the issue can cause writes to an unconfirmed disk. Remove passwords, Wi-Fi secrets, drive serial numbers, host-specific identifiers, and other unrelated sensitive data from logs.

## Sensitive vulnerabilities

Examples include:

- selecting, rebinding, or writing to a disk that was not exactly confirmed;
- bypassing disk identity/busy-state revalidation or the approved plan digest;
- command injection through disk metadata, usernames, profile values, or generated configuration;
- credential/passphrase disclosure through arguments, files, logs, tracing, or crash dumps;
- LUKS, bootloader, sudo, firewall, or resolver changes that materially weaken the documented security model;
- privilege escalation in generated root-owned scripts or `skittles-doctor`;
- release workflow compromise that can replace published installer artifacts.

A destructive-target bypass should not be casually disclosed publicly before a fix and coordinated release are available.

## Expected response workflow

1. Privately acknowledge and reproduce the report.
2. Determine affected versions and whether destructive or credential exposure is possible.
3. Develop a minimal fix plus regression test without weakening existing confirmations.
4. Re-run syntax, ShellCheck, unit/config tests, and any required real-hardware regression tests.
5. Coordinate disclosure after a fixed release or clear mitigation exists.

No vulnerability bounty is offered unless the repository owner explicitly establishes one in the future.

## Repository security settings

For a public repository, enable GitHub secret scanning, push protection, Private Vulnerability Reporting, and code scanning where it provides useful signal. Keep GitHub Actions permissions minimal and treat Actions as supply-chain dependencies.
