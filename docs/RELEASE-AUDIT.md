# SKITTLES release audit

Status: **NOT READY FOR v1.0.0**. Updated 2026-09-17 from the actual repository and hosted logs. Automated evidence and hardware evidence are separate.

## Automated/static evidence

| Area | Status | Evidence / limitation |
| --- | --- | --- |
| Local repository union | PASS | Nine exact historical files restored in `2bb7bff68a5ba63c24eb2dbfce5246c851f051a3`; no unrelated deletion |
| Full local suite | PASS | 46 tests, all four modules; mocks and one ordinary temporary-file overwrite |
| Bash / YAML / whitespace | PASS | See [RELEASE-DECISION.md](RELEASE-DECISION.md) |
| Local relative file links | PASS | All Markdown scanned; anchor checking not performed |
| Available history secret patterns | PASS | 42 unique blobs scanned, no pattern findings; not a comprehensive secret guarantee |
| Hosted full suite | BLOCKED | Push approval required; current hosted green ran only seven tests |
| Local ShellCheck | BLOCKED | Not installed; hosted 0.9.0 passed unchanged installer on public baseline |
| Final release assets / provenance | BLOCKED | License and tagged publication gates not satisfied |
| Hardware / recovery / performance | NOT TESTED | No target-machine execution or measurements |
| Secure Boot support | N/A | Explicitly unsupported for this release |

## Source-review findings requiring follow-up

1. **Chroot resolver replacement:** current upstream `arch-chroot` bind-mounts the live resolver onto the target `/etc/resolv.conf` unless `-r` is requested. SKITTLES invokes `arch-chroot` without `-r`, then its generated helper runs `ln -sf` on that path. Replacing a mounted file can fail with `EBUSY`, interrupting installation after destructive work. The correction must preserve DNS during configuration and establish the installed resolved symlink after the temporary mount is released. Add an ordinary-file/mock regression; do not test against real block devices. [Upstream implementation](https://gitlab.archlinux.org/archlinux/arch-install-scripts/-/blob/master/arch-chroot.in).
2. **Recovery resolver instructions:** review the manual `/mnt/run` stub-copy workaround against chroot API filesystem setup; verify resolver handling inside the actual current Arch ISO. The recovery guide has not been executed.
3. **Doctor accuracy:** failed-service lookup currently suppresses command errors and can report PASS for empty output on failure. Console sessions can be reported as failed Wayland sessions. Review status semantics and add safe tests before treating diagnostics as a sign-off gate.
4. **Stable publication gate:** the workflow checks particular `NOT TESTED` and draft markers, but does not positively validate every required sign-off row as PASS. A FAIL row or removed table must not permit stable publication. Strengthen with negative fixtures before any stable tag.
5. **Final safety review:** identity checks, plan authorization, ownership cleanup and extra-wipe ordering are present. Additional adversarial/failure coverage and a per-write identity review remain open; their presence is not proof against races with other privileged processes.

The mandate freezes installer changes until the complete hosted baseline is green. No installer behavior was changed during this blocked repair. These findings must be resolved or explicitly dispositioned before claiming automated completion.

## Upstream checks performed

Current pages were retrieved on 2026-09-17:

- [Arch NVIDIA](https://wiki.archlinux.org/title/NVIDIA) lists prebuilt open modules for both `linux` and `linux-lts` for Ampere. No reason found in that source to substitute DKMS for this two-kernel desktop.
- [Arch NVIDIA power management](https://wiki.archlinux.org/title/NVIDIA/Tips_and_tricks#Preserve_video_memory_after_suspend) describes the 595+ kernel suspend notifier strategy, disabled legacy services, and `/var/tmp` backing path. This supports the intended architecture; it is not runtime validation.
- [NetworkManager configuration](https://networkmanager.dev/docs/api/latest/NetworkManager.conf.html) documents forwarding DNS to systemd-resolved without replacing its stub symlink. Connection-specific effective privacy behavior remains a runtime gate.
- [actions/attest](https://github.com/actions/attest) documents artifact-metadata permissions as well as attestations and OIDC. Do not remove that permission solely on the basis of older action guidance.

The full current official package inventory, remaining upstream compatibility checks, release reproducibility and final security review are **not complete**. Do not infer completion from these targeted source checks.

## Hardware gate

All physical results remain **NOT TESTED**: clean install, repeated LUKS unlock, both kernels, Plasma Wayland, NVIDIA/Vulkan, repeated suspend/resume, networking/DNS/IPv6, firewall, audio/USB, gaming, normal Arch updates, recovery ISO, and performance measurements. Use [TESTING.md](TESTING.md) and [PERFORMANCE.md](PERFORMANCE.md) after the owner-authorized license, published RC verification and open code findings are resolved.

## Owner / access blockers

- Explicit approval in chat to push the prepared repair to public `main` and continue hosted validation.
- Owner license selection; no license has been selected or added.
- Physical i7-8700K + RTX 3060 Ti validation from the actual downloaded RC.

No stable release or RC tag was created.
