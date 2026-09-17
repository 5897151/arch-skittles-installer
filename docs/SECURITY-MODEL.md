# Security Model

SKITTLES is a destructive installer with a modest desktop threat model. Its strongest goals are safe target authorization, encrypted data at rest, reduced default network exposure, and transparent recovery—not resistance to every attacker.

## In scope

SKITTLES attempts to reduce risk from:

- casual theft of a powered-off, correctly shut down machine by encrypting root with LUKS2;
- accidental installation/wiping of the wrong ordinary disk through explicit inventory, protection rules, per-drive confirmations, plan binding, and identity revalidation;
- unnecessary inbound/LAN service exposure through a default-drop nftables policy and no SSH server;
- avoidable DHCP/LLMNR/mDNS/Wi-Fi identity leakage through documented NetworkManager/resolved defaults;
- excessive local diagnostic retention through bounded journal storage and disabled coredump storage;
- routine user-to-root separation with password-authenticated sudo and private home permissions;
- a broken main kernel by installing `linux-lts` as a second recovery boot option.

## Partially addressed

### Malicious local software

A non-root process still sees data the logged-in user can access. Kernel hardening and firewall defaults reduce some attack surface but are not an application sandbox. Root compromise defeats the local policy.

### Physical tampering / evil-maid attacks

Root encryption protects data at rest, but the ESP, GRUB, kernel, and initramfs are unencrypted and unsigned. Secure Boot is disabled for this release. A physical attacker can potentially modify the boot chain and capture the LUKS passphrase on a later boot.

### DNS observers and malicious networks

LLMNR/mDNS are disabled and DNS has a coherent local resolver, but DNS-over-TLS is disabled. Resolver addresses come from the active network; the fallback list is empty so SKITTLES does not silently substitute public DNS. The configured DNS resolver, local network, VPN/provider path, and upstream observers can still learn DNS and traffic metadata. nftables blocks unsolicited inbound traffic and reloads only its own table, but cannot make a hostile network trustworthy.

### Storage sanitization

A logical zero overwrite covers the host-addressable block range but cannot guarantee erasure of SSD remapped/spare NAND. Manufacturer sanitize/secure-erase procedures are outside this installer.

## Out of scope

- compromised UEFI/firmware or option ROMs;
- malicious hardware implants;
- compromised Arch mirrors/signing infrastructure or malicious signed packages;
- compromised NVIDIA firmware/driver or other privileged vendor components;
- a malicious root user;
- protection after the LUKS volume is unlocked from software with sufficient privilege;
- anonymity against a global or capable network observer;
- certified forensic sanitization of SSD spare/remapped cells;
- protection from intentional user overrides of the documented baseline;
- server hardening or multi-tenant isolation.

## Destructive-operation trust boundary

The installer treats block-device metadata as untrusted display data and never uses model/serial strings as shell code. Eligible destructive targets must expose at least one persistent SERIAL or WWN identifier; a disk with neither is refused. Destructive helpers must receive an approved plan, a matching path/identity/size tuple, and an idle disk. The plan digest makes silent post-confirmation changes fail closed, and identity/idle checks are repeated at destructive transitions.

These controls reduce accidental or simple state-change risk; they are not a formal proof against a hostile kernel, root process, compromised `lsblk`/udev stack, or malicious firmware that lies about storage identity.

## Boot-chain gap

Secure Boot is explicitly unsupported in `1.0.0-rc.1`. GRUB is installed both as `EFI/SKITTLES/grubx64.efi` and the removable fallback path. Neither path is signed by SKITTLES. LUKS therefore protects confidentiality of locked root data, but it does not authenticate the code that asks for the passphrase.

## Update/supply-chain model

Arch package signatures and normal pacman trust are relied upon for installed packages. SKITTLES release artifacts should be reviewed against the source tag, checked with published hashes, and—when the release workflow is enabled—verified using GitHub artifact provenance. Provenance proves where an artifact came from; it does not prove the code is safe.
