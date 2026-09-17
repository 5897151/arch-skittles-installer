# GitHub Repository Metadata

Public metadata for `5897151/arch-skittles-installer`.

Current stable version: `1.0.0`.

## Repository name

`arch-skittles-installer`

## Description

Safety-first encrypted Arch Linux installer for i7-8700K + RTX 3060 Ti, KDE/Wayland, privacy defaults, dual kernels, and an optional gaming stack.

## Website


## Topics

```text
arch-linux
archlinux
installer
bash
kde
plasma
wayland
nvidia
luks2
encryption
privacy
security
gaming
steam
nftables
```

## About / social preview text

**One-sentence tagline:** A conservative, hardware-scoped fresh-install path for an encrypted Arch gaming desktop.

**Two-sentence project description:** SKITTLES is a destructive fresh installer for an Intel Core i7-8700K + RTX 3060 Ti desktop running Arch Linux, KDE Plasma Wayland, LUKS2/ext4, nftables, and privacy-conscious network defaults. It prioritizes explicit disk authorization, dual-kernel recovery options, reproducible CI, local diagnostics, and measured changes over broad hardware support or aggressive tuning.

**GitHub Release description:** Hardware-scoped Arch installer with encrypted root, `linux` + `linux-lts`, Plasma Wayland, NVIDIA open modules, default-drop inbound nftables, local diagnostics, and an optional Steam/Proton/GameMode/NTSync profile. Verify checksums and GitHub provenance before running the destructive installer.

## Current target-hardware evidence

Physical validation on the supported i7-8700K + RTX 3060 Ti system demonstrated successful boot on both `linux` and `linux-lts`, KDE Plasma/Wayland, NVIDIA/Vulkan, networking/DNS, PipeWire, nftables policy, zram, suspend/resume on both kernels, and the Steam/Proton runtime with GameMode active and NTSync loaded. A full `pacman -Syu` transaction was followed by successful reboot validation on both kernels; no package upgrades were available, so this does not claim survival across an actual kernel/NVIDIA version change.

Recovery-ISO execution and formal performance benchmarking are deferred and must not be represented as PASS.
