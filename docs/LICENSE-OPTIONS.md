# License owner gate

SKITTLES does not currently have an owner-authorized software license. Do not publish a stable release until the repository owner chooses one and supplies the correct copyright holder/name information.

This is a practical comparison, not legal advice.

| License | Redistribution obligations | Derivative-work obligations | Patent provisions | Compatibility notes for SKITTLES |
| --- | --- | --- | --- | --- |
| **MIT** | Keep the copyright notice and MIT permission notice with copies or substantial portions. Source disclosure is not required. | Modified versions may be redistributed under MIT or another license, including proprietary terms, so long as the MIT notice is preserved for the MIT-covered material. | No explicit patent grant or patent-retaliation clause. | Very simple and permissive. Easy to combine with most Bash/Linux-oriented projects. Downstream users may make closed derivatives. |
| **Apache-2.0** | Include the license, preserve required notices, mark modified files, and preserve any applicable `NOTICE` content. Source disclosure is not required. | Modified versions may be redistributed under other terms, provided Apache-2.0 obligations for the covered material are preserved. | Explicit contributor patent license plus patent-termination language for certain patent litigation. | Permissive like MIT but more explicit about patents and notices. Apache-2.0 code is compatible with GPLv3, but not with GPLv2-only. |
| **GPL-3.0-or-later** | When conveying covered binaries/object code, provide Corresponding Source by a GPLv3-compliant method; preserve notices and provide the GPL terms. | Distributed modified/combined derivative works covered by the GPL must be licensed as a whole under GPLv3-or-later terms. Private modification without distribution does not trigger source-release obligations. | Includes an explicit contributor patent license and additional patent protections/conditions for downstream recipients. | Strong copyleft. Works well if the owner wants redistributed SKITTLES derivatives to remain GPL-covered. GPLv3 is compatible with Apache-2.0 material; combining with proprietary derivative code is generally not compatible with GPL distribution requirements. |

## Practical owner choice

- Choose **MIT** if the priority is the shortest permissive license and allowing proprietary derivatives.
- Choose **Apache-2.0** if the priority is permissive reuse plus an explicit patent grant and more detailed notice rules.
- Choose **GPL-3.0-or-later** if the priority is requiring distributed derivatives of the covered work to remain under GPL copyleft terms.

No `LICENSE` file should be added until the owner makes the choice and confirms the copyright holder/name that belongs in the repository.

## SKITTLES-specific compatibility context

The repository is primarily original Bash, tests, and documentation. It names Arch packages and invokes system utilities, but the release bundle does not incorporate Arch Linux package source, NVIDIA driver source, or those packages' binaries. Merely calling an installed command or listing a package dependency does not normally cause that external program's license to become the license of this installer.

That means the owner's choice is mainly about how **SKITTLES itself** may be copied and modified. If the project later copies third-party source/snippets into the repository, statically combines licensed code, or redistributes third-party binaries, those materials must be reviewed separately for notice, source, patent, or copyleft obligations.
