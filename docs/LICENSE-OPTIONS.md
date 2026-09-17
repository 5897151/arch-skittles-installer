# License decision

SKITTLES is licensed under the **Apache License 2.0**. The canonical license text is in [`LICENSE`](../LICENSE).

## Decision

Apache-2.0 was selected for SKITTLES because it preserves the permissive reuse model that fits a public installer while adding clearer long-term legal mechanics than MIT for contributors and downstream users:

- source inspection, modification, forking, redistribution, and commercial use are allowed;
- downstream projects are not forced into a copyleft license;
- contributors provide an explicit patent license for their contributions, subject to Apache-2.0's terms;
- redistributed Apache-covered material retains the required license/notices and modified files must be identified as changed;
- no custom SKITTLES-specific restrictions were added.

No `NOTICE` file is currently required by project-specific notices. If future contributions introduce material that requires notices, third-party source, or redistributed binaries, those obligations must be reviewed independently.

## Alternatives considered

| License | Why it was not selected |
| --- | --- |
| **MIT** | Excellent simplicity and permissive reuse, but it has no explicit patent grant. Apache-2.0 provides a clearer contributor/downstream patent framework for modest additional complexity. |
| **GPL-3.0-or-later** | Strong copyleft would keep distributed derivatives GPL-covered, but SKITTLES intentionally permits proprietary and differently licensed downstream integrations as long as Apache-2.0 obligations are preserved. |

## Repository and dependency context

SKITTLES is primarily original Bash, Python tests, workflows, and documentation. It names Arch packages and invokes installed system utilities, but this repository and its release bundle do not incorporate Arch Linux package source, NVIDIA driver source, or those packages' binaries.

The Apache-2.0 license covers SKITTLES's own covered material. Third-party software installed or invoked by SKITTLES remains under its own license. If future changes copy third-party source, bundle binaries, or add other licensed assets, their compatibility and notice/source obligations must be reviewed separately.
