#!/usr/bin/env bash
# SKITTLES: UEFI Arch installer for an i7-8700K / RTX 3060 Ti desktop.
# Run from a current official Arch ISO. DESTRUCTIVE on explicitly selected drives.
# Sourcing this file defines functions only; it never runs the installer.

DISK="" EFI_PART="" ROOT_PART=""
readonly CRYPT_NAME=skittles-root MNT=/mnt EFI_MNT=/mnt/boot
readonly VERSION=1.0.0-rc.1
readonly TIMEZONE=Europe/Luxembourg LOCALE=en_US.UTF-8 KEYMAP=us HOSTNAME=arch

WIPE_MODE=zero
ALLOW_DISCARDS=0
CHECK_ONLY=0
DEMO=0
APPROVED=0
APPROVED_PLAN_DIGEST=""
ARCH_INSTALLED=0
DESTRUCTIVE_WRITES_STARTED=0
PROFILE=""
LIST_PACKAGES=0
TARGET_INDEX=-1
DRIVES=() DRIVE_IDS=() DRIVE_BYTES=() DRIVE_DETAILS=() DRIVE_REASONS=()
EXTRA_INDICES=()
WORKDIR=""
DISK_IDENTITY=""
DISK_SIZE_BYTES=0
OWN_CRYPT=0
OWN_ROOT=0
OWN_EFI=0
USERNAME=""
USER_PASSWORD=""
ROOT_PASSWORD=""
LUKS_PASSWORD=""

# Explicit desktop components; dependencies are resolved by pacman.
# The gaming profile adds only explicit gaming components.
BASE_PACKAGES=(
    base linux linux-lts linux-firmware intel-ucode
    sudo networkmanager wpa_supplicant grub efibootmgr cryptsetup mkinitcpio dosfstools e2fsprogs
    plasma-desktop plasma-workspace plasma-nm plasma-pa kscreen powerdevil
    polkit-kde-agent xdg-desktop-portal-kde sddm xorg-server xorg-xwayland
    konsole dolphin nano noto-fonts noto-fonts-emoji
    pipewire pipewire-audio pipewire-pulse pipewire-alsa wireplumber
    nvidia-open nvidia-open-lts nvidia-utils mesa vulkan-icd-loader vulkan-tools
    nftables zram-generator
)
GAMING_PACKAGES=(
    steam lib32-nvidia-utils lib32-vulkan-icd-loader
    gamemode lib32-gamemode mangohud lib32-mangohud ntsync-autoload
)
PACKAGES=()

color_enabled() { [[ -t 1 && -z ${NO_COLOR+x} && ${TERM:-dumb} != dumb ]]; }

rainbow() {
    local text=$1 i
    local colors=(196 202 214 226 118 48 51 39 99 141 201)
    if ! color_enabled; then printf '%s' "$text"; return; fi
    for ((i=0; i<${#text}; i++)); do
        if [[ ${TERM:-} == linux ]]; then
            printf '\033[1;%sm%s' "$((31 + i % 6))" "${text:i:1}"
        else
            printf '\033[38;5;%sm%s' "${colors[i % ${#colors[@]}]}" "${text:i:1}"
        fi
    done
    printf '\033[0m'
}

log() { rainbow '  SKITTLES'; printf '  %s\n' "$*"; }

banner() {
    printf '\n'
    rainbow '  .  *  .  *  .  *  .  *  .  *  .  *  .  *  .  *  .  *  .  *'; printf '\n\n'
    rainbow '  S K I T T L E S   /   A R C H   I N S T A L L E R'; printf '\n'
    rainbow '  ------------------------------------------------------------'; printf '\n'
    printf '  taste the rainbow. choose your disks. build your desktop.\n\n'
}

section() {
    printf '\n'
    rainbow "  $1"; printf '\n'
    rainbow '  ------------------------------------------------------------'; printf '\n'
}

ask() {
    local output=$1 label=$2
    rainbow "  $label" >/dev/tty
    IFS= read -r "${output?}" </dev/tty || die "Input closed; cancelled."
}
warn() { log "WARNING: $*" >&2; }
die() { log "ERROR: $*" >&2; exit 1; }

usage() {
    cat <<'HELP'
Usage: bash skittles-installer.sh [--profile=minimal|gaming] [--packages] [--check]
       [--wipe=zero|signatures] [--allow-discards] [--demo] [--version] [--help]

  --profile=minimal   Lean KDE desktop with privacy defaults and an LTS recovery kernel.
  --profile=gaming    Add Steam, 32-bit NVIDIA/Vulkan, GameMode, MangoHud and NTSync.
                      Without this option, the installer asks; minimal is the default.
  --packages          Print the chosen profile's explicit packages without root/network.
                      Uses minimal unless --profile=gaming is also provided.
  --check             Run preflight and package resolution only; never wipe/install.
                      Refreshes temporary package metadata and enables live ISO NTP.
  --wipe=zero         Default: overwrite EVERY addressable byte of selected drives.
                      Slow; destroys all data. Not certified SSD sanitization.
  --wipe=signatures   Fast clean reinstall; old data is NOT securely erased.
  --allow-discards    Opt in to TRIM through LUKS + weekly fstrim. Reveals which
                      encrypted sectors are unused; off by default.
  --help              Show this help without requiring root or touching disks.
  --version           Print the release version.
  --demo              Preview the rainbow picker with FICTIONAL drives. No probing,
                      prompts, root access, or disk changes.

Choose one installation drive, then optional additional drives to erase.
All other drives are left alone. Every erase needs its own exact typed confirmation.
Additional drives are wiped only after Arch installs successfully; they stay blank.
No unattended confirmation bypass. Requires local TTY,
UEFI, Secure Boot disabled, an unused internal SATA/NVMe disk, i7-8700K and RTX 3060 Ti.
Defaults: encrypted ext4, 2 GiB ESP, US keyboard, en_US.UTF-8, Europe/Luxembourg.
HELP
}

parse_args() {
    local arg
    for arg in "$@"; do
        case "$arg" in
            --check) CHECK_ONLY=1 ;;
            --wipe=zero) WIPE_MODE=zero ;;
            --wipe=signatures) WIPE_MODE=signatures ;;
            --allow-discards) ALLOW_DISCARDS=1 ;;
            --demo) DEMO=1 ;;
            --profile=minimal) PROFILE=minimal ;;
            --profile=gaming) PROFILE=gaming ;;
            --packages) LIST_PACKAGES=1 ;;
            --version) printf '%s\n' "$VERSION"; return 10 ;;
            --help|-h) usage; return 10 ;;
            *) die "Unknown argument: $arg (use --help)." ;;
        esac
    done
}

configure_packages() {
    case ${PROFILE:-minimal} in
        minimal) PACKAGES=("${BASE_PACKAGES[@]}") ;;
        gaming) PACKAGES=("${BASE_PACKAGES[@]}" "${GAMING_PACKAGES[@]}") ;;
        *) die 'Unknown installation profile.' ;;
    esac
}

choose_profile() {
    local answer
    if [[ -z $PROFILE ]]; then
        section 'YOUR DESKTOP / CHOOSE A PROFILE'
        log '1  Minimal: KDE + privacy defaults + main and LTS recovery kernels.'
        log '2  Gaming: add Steam, 32-bit graphics, GameMode, MangoHud and NTSync.'
        while :; do
            ask answer 'Profile [1] (q to quit): '
            case "$answer" in
                ''|1) PROFILE=minimal; break ;;
                2) PROFILE=gaming; break ;;
                q) die 'Cancelled.' ;;
                *) warn 'Enter 1 or 2.' ;;
            esac
        done
    fi
    configure_packages
    log "Selected profile: $PROFILE. No package is installed before confirmation."
}

prepare_pacman_config() {
    local source=$1 destination=$2
    cp "$source" "$destination"
    if [[ $PROFILE == gaming ]] && ! grep -Eq '^[[:space:]]*\[multilib\][[:space:]]*$' "$destination"; then
        printf '\n[multilib]\nInclude = /etc/pacman.d/mirrorlist\n' >> "$destination"
    fi
}

prepare_preflight_pacman_workspace() {
    WORKDIR=$(mktemp -d /run/skittles.XXXXXXXX)
    # pacman 7.x may download as DownloadUser (Arch currently configures alpm).
    # mktemp creates the parent as 0700, which blocks that user from traversing
    # into pacman's own db/sync/download-* directory. Grant traverse only: no
    # directory listing or parent writes, no recursive chown, and no sandbox
    # disable. pacman itself owns/manages the per-download temporary directory.
    chmod 0711 "$WORKDIR"
    mkdir -p "$WORKDIR/db/local" "$WORKDIR/cache"
    chmod 0755 "$WORKDIR/db" "$WORKDIR/db/local" "$WORKDIR/cache"
    prepare_pacman_config /etc/pacman.conf "$WORKDIR/pacman.conf"
}

valid_username() {
    [[ $1 =~ ^[a-z_][a-z0-9_-]*$ && $1 != root && ${#1} -le 32 ]]
}

secret() {
    local output=$1 label=$2 a b
    while :; do
        IFS= read -r -s -p "$label: " a </dev/tty || die "Input closed."
        printf '\n' >/dev/tty
        IFS= read -r -s -p "Confirm $label: " b </dev/tty || die "Input closed."
        printf '\n' >/dev/tty
        if [[ -z $a || $a != "$b" ]]; then
            warn "Passwords must be nonempty and match."
            continue
        fi
        printf -v "$output" '%s' "$a"
        unset a b
        return
    done
}

disk_identity() {
    lsblk --bytes --nodeps --noheadings --output MAJ:MIN,SIZE,MODEL,SERIAL,WWN "${1:-$DISK}"
}

persistent_disk_id_present() {
    [[ $1 =~ [^[:space:]] ]]
}

set_target() {
    DISK=$1
    # NVMe names end in a digit; SATA/SCSI-style sdX names do not.
    local separator=""
    [[ $DISK =~ [0-9]$ ]] && separator=p
    EFI_PART="${DISK}${separator}1"
    ROOT_PART="${DISK}${separator}2"
}

disk_attribute_problem() {
    local type=$1 readonly_flag=$2 removable=$3 transport=$4 mounts=$5
    if [[ $type != disk ]]; then printf 'not a whole installable disk'
    elif [[ $readonly_flag != 0 ]]; then printf 'read-only or unreadable'
    elif [[ $removable != 0 ]]; then printf 'removable media protected'
    elif [[ $transport == usb ]]; then printf 'USB / installation media protected'
    elif [[ $mounts =~ [^[:space:]] ]]; then printf 'mounted filesystem or active swap'
    fi
    return 0
}

validate_disk_attributes() {
    local problem
    problem=$(disk_attribute_problem "$@")
    [[ -z $problem ]] || die "$DISK: $problem."
}

disk_problem() {
    local disk=$1 nodes mounts node holder swap_devices type readonly_flag removable transport persistent_id problem
    [[ -b $disk ]] || { printf 'device missing'; return; }
    [[ $disk =~ ^/dev/(sd[a-z]+|nvme[0-9]+n[0-9]+)$ ]] ||
        { printf 'unsupported device (only internal SATA/SCSI-style sdX or NVMe disks are eligible)'; return; }
    # Includes descendants: mounted filesystems, live media and active swap.
    type=$(lsblk -dnro TYPE "$disk") || { printf 'cannot read disk type'; return; }
    readonly_flag=$(blockdev --getro "$disk") || { printf 'cannot read disk flags'; return; }
    removable=$(lsblk -dnro RM "$disk") || { printf 'cannot read removable flag'; return; }
    transport=$(lsblk -dnro TRAN "$disk") || { printf 'cannot read transport'; return; }
    persistent_id=$(lsblk -dnro SERIAL,WWN "$disk") || { printf 'cannot read persistent identity'; return; }
    mounts=$(lsblk -nrpo MOUNTPOINTS "$disk") || { printf 'cannot read mount state'; return; }
    problem=$(disk_attribute_problem "$type" "$readonly_flag" "$removable" "$transport" "$mounts")
    [[ -z $problem ]] || { printf '%s' "$problem"; return; }
    persistent_disk_id_present "$persistent_id" || { printf 'missing persistent serial/WWN identity'; return; }
    nodes=$(lsblk -nrpo NAME "$disk") || { printf 'cannot read descendants'; return; }
    [[ -n $nodes ]] || { printf 'empty device inventory'; return; }
    swap_devices=$(swapon --noheadings --raw --show=NAME) || { printf 'cannot read swap state'; return; }
    while IFS= read -r node; do
        [[ -n $node ]] || continue
        if grep -Fxq -- "$node" <<<"$swap_devices"; then
            printf 'active swap on %s' "$node"; return
        fi
        for holder in /sys/class/block/"${node##*/}"/holders/*; do
            [[ ! -e $holder ]] || { printf 'in use by %s (LUKS/LVM/RAID)' "${holder##*/}"; return; }
        done
    done <<<"$nodes"
}

assert_disk_idle() {
    local disk=${1:-$DISK} problem
    problem=$(disk_problem "$disk") || die "Unable to inspect $disk."
    [[ -z $problem ]] || die "$disk: $problem."
}

assert_install_workspace() {
    [[ ! -e /dev/mapper/$CRYPT_NAME ]] || die "Mapping $CRYPT_NAME already exists."
    if [[ -d $MNT ]]; then
        [[ -z $(find "$MNT" -mindepth 1 -maxdepth 1 -print -quit) ]] || die "$MNT is not empty."
        if mountpoint -q "$MNT"; then die "$MNT is already mounted."; fi
    fi
}

assert_same_disk() {
    local disk=${1:-$DISK} expected=${2:-$DISK_IDENTITY} actual
    actual=$(disk_identity "$disk") || die "Cannot read identity of $disk."
    [[ -n $expected && $actual == "$expected" ]] || die "Disk identity changed since preflight: $disk."
    assert_disk_idle "$disk"
}

scan_drives() {
    local inventory disk type identity bytes details reason
    DRIVES=() DRIVE_IDS=() DRIVE_BYTES=() DRIVE_DETAILS=() DRIVE_REASONS=()
    udevadm settle --timeout=30
    inventory=$(lsblk -dnrpo NAME,TYPE) || die "Cannot list drives."
    while IFS=' ' read -r disk type; do
        [[ $type == disk || $type == rom ]] || continue
        [[ $disk =~ ^/dev/[a-zA-Z0-9_.-]+$ ]] || continue
        identity=$(disk_identity "$disk") || die "Cannot read $disk identity."
        bytes=$(lsblk -bdnro SIZE "$disk") || die "Cannot read $disk size."
        details=$(lsblk -dnro SIZE,MODEL,SERIAL,TRAN "$disk") || die "Cannot read $disk details."
        # Device metadata is untrusted terminal text; never evaluate escapes.
        details=$(printf '%s' "$details" | tr -cd '[:print:]')
        reason=$(disk_problem "$disk") || die "Cannot inspect $disk."
        if [[ ! $bytes =~ ^[0-9]+$ || $bytes == 0 ]]; then reason='empty or unreadable device'; bytes=0; fi
        DRIVES+=("$disk"); DRIVE_IDS+=("$identity"); DRIVE_BYTES+=("$bytes")
        DRIVE_DETAILS+=("$details"); DRIVE_REASONS+=("$reason")
    done <<<"$inventory"
    ((${#DRIVES[@]})) || die "No drives found."
}

is_extra() {
    local wanted=$1 index
    for index in "${EXTRA_INDICES[@]}"; do [[ $index == "$wanted" ]] && return 0; done
    return 1
}

show_drives() {
    local i role tone
    section "$1"
    for i in "${!DRIVES[@]}"; do
        if (( i == TARGET_INDEX )); then role='INSTALL ARCH + ERASE'; tone=95
        elif is_extra "$i"; then role='ERASE ONLY'; tone=91
        elif [[ -n ${DRIVE_REASONS[i]} ]]; then role='LEAVE ALONE / PROTECTED'; tone=90
        else role='LEAVE ALONE'; tone=96
        fi
        rainbow "  [$((i + 1))]  ${DRIVES[i]}"
        if color_enabled; then printf '   \033[1;%sm%s\033[0m\n' "$tone" "$role"
        else printf '   %s\n' "$role"; fi
        printf '       %s\n' "${DRIVE_DETAILS[i]}"
        if [[ -n ${DRIVE_REASONS[i]} ]]; then printf '       LOCKED: %s\n' "${DRIVE_REASONS[i]}"; fi
        printf '\n'
    done
}

menu_index() {
    # Validate before arithmetic: Bash arithmetic accepts expressions/subscripts.
    [[ $1 =~ ^[1-9][0-9]{0,2}$ ]] || return 1
    (( 10#$1 <= ${#DRIVES[@]} )) || return 1
    printf '%s' "$((10#$1 - 1))"
}

choose_target() {
    local index
    index=$(menu_index "$1") || { warn 'Enter one displayed drive number.'; return 1; }
    [[ -z ${DRIVE_REASONS[index]} ]] || { warn "Protected: ${DRIVE_REASONS[index]}."; return 1; }
    (( DRIVE_BYTES[index] >= 32 * 1024 * 1024 * 1024 )) || { warn 'Arch needs at least 32 GiB.'; return 1; }
    TARGET_INDEX=$index
    set_target "${DRIVES[index]}"
    DISK_IDENTITY=${DRIVE_IDS[index]}
    DISK_SIZE_BYTES=${DRIVE_BYTES[index]}
}

choose_extras() {
    local input=$1 token index prior
    local tokens=() chosen=()
    if [[ -z ${input//[[:space:]]/} || $input == none ]]; then EXTRA_INDICES=(); return 0; fi
    IFS=' ' read -r -a tokens <<<"$input"
    for token in "${tokens[@]}"; do
        index=$(menu_index "$token") || { warn 'Use displayed numbers separated by spaces, or none.'; return 1; }
        (( index != TARGET_INDEX )) || { warn 'The Arch drive is already selected for erasure.'; return 1; }
        [[ -z ${DRIVE_REASONS[index]} ]] || { warn "Protected: ${DRIVES[index]}."; return 1; }
        for prior in "${chosen[@]}"; do
            [[ $prior != "$index" ]] || { warn 'Each extra drive may be selected only once.'; return 1; }
        done
        chosen+=("$index")
    done
    EXTRA_INDICES=("${chosen[@]}")
}

select_drives() {
    local answer i available=0
    scan_drives
    show_drives '01 / YOUR DRIVES'
    log 'Size, model, serial and connection are shown above. Nothing is selected yet.'
    log 'USB/removable, mounted, read-only and in-use drives are protected.'
    for i in "${!DRIVES[@]}"; do
        if [[ -z ${DRIVE_REASONS[i]} ]] && (( DRIVE_BYTES[i] >= 32 * 1024 * 1024 * 1024 )); then available=1; fi
    done
    (( available )) || die 'No eligible installation drive of at least 32 GiB. Review the protection reasons above.'
    while :; do
        ask answer 'Install Arch on drive number (q to quit): '
        [[ $answer != q ]] || die 'Cancelled.'
        if choose_target "$answer"; then break; fi
    done
    show_drives '02 / OPTIONAL EXTRA WIPES'
    log 'Enter extra drive numbers to ERASE, separated by spaces.'
    log 'Press Enter to leave every other drive alone. Extra wipes happen after installation.'
    while :; do
        ask answer 'Extra drives to erase [none] (q to quit): '
        [[ $answer != q ]] || die 'Cancelled.'
        if choose_extras "$answer"; then break; fi
    done
    show_drives '03 / YOUR PLAN'
    assert_selected_drives
}

assert_selected_drives() {
    local i
    assert_same_disk
    for i in "${EXTRA_INDICES[@]}"; do assert_same_disk "${DRIVES[i]}" "${DRIVE_IDS[i]}"; done
}

plan_digest() {
    local digest i
    digest=$({
        printf '%s\0' "$VERSION" "$WIPE_MODE" "$PROFILE" "$ALLOW_DISCARDS" "$TARGET_INDEX"
        for i in "$TARGET_INDEX" "${EXTRA_INDICES[@]}"; do
            printf '%s\0' "${DRIVES[i]}" "${DRIVE_IDS[i]}" "${DRIVE_BYTES[i]}"
        done
    } | sha256sum) || return 1
    printf '%s' "${digest%% *}"
}

approve_plan() {
    APPROVED_PLAN_DIGEST=$(plan_digest) || die 'Cannot record the confirmed plan.'
    APPROVED=1
}

require_approved_plan() {
    (( APPROVED )) || die 'No approved erase plan.'
    [[ -n $APPROVED_PLAN_DIGEST && $(plan_digest) == "$APPROVED_PLAN_DIGEST" ]] ||
        die 'The plan changed after confirmation. No further writes are permitted.'
}

assert_authorized_drive() {
    local drive=$1 identity=$2 bytes=$3 i
    for i in "$TARGET_INDEX" "${EXTRA_INDICES[@]}"; do
        if [[ $drive == "${DRIVES[i]}" && $identity == "${DRIVE_IDS[i]}" && $bytes == "${DRIVE_BYTES[i]}" ]]; then return 0; fi
    done
    die "Write refused: $drive is not in the confirmed plan."
}

assert_target_binding() {
    local expected=${DRIVES[TARGET_INDEX]} separator=""
    [[ $expected =~ [0-9]$ ]] && separator=p
    [[ $DISK == "$expected" && $EFI_PART == "${expected}${separator}1" && $ROOT_PART == "${expected}${separator}2" ]] ||
        die 'The installation target no longer matches its confirmed partitions.'
}

demo() {
    banner
    log 'DEMO: fictional drives. No hardware is read or modified.'
    DRIVES=(/dev/nvme0n1 /dev/sda /dev/sdb /dev/sdc)
    DRIVE_DETAILS=('1T   NVMe SSD       DEMO-NVME   nvme' '2T   SATA SSD       DEMO-SATA   sata' '4T   Archive HDD    DEMO-DATA   sata' '32G  Arch ISO USB   DEMO-USB    usb')
    DRIVE_REASONS=('' '' '' 'USB / installation media protected')
    TARGET_INDEX=-1 EXTRA_INDICES=()
    show_drives '01 / YOUR DRIVES'
    TARGET_INDEX=0 EXTRA_INDICES=(1)
    show_drives '03 / EXAMPLE PLAN'
    log 'Install on NVMe. Erase the SATA SSD. Leave the archive and USB alone.'
    log 'The real installer asks for ERASE <device> for each selected drive.'
}

cleanup_owned() {
    # Never swapoff globally, force-unmount, or close other people's mappings.
    if (( OWN_ROOT )); then
        rm -f -- "$MNT/root/skittles-configure.sh" || true
    fi
    if (( OWN_EFI )); then
        if umount "$EFI_MNT"; then OWN_EFI=0; else warn "Could not unmount $EFI_MNT; inspect manually."; fi
    fi
    if (( OWN_ROOT && ! OWN_EFI )); then
        if umount "$MNT"; then OWN_ROOT=0; else warn "Could not unmount $MNT; inspect manually."; fi
    fi
    if (( OWN_CRYPT && ! OWN_ROOT )); then
        if cryptsetup close "$CRYPT_NAME"; then OWN_CRYPT=0; else warn "Could not close $CRYPT_NAME."; fi
    fi
    return 0
}

report_failure() {
    local rc=$1
    warn "Installation stopped (exit $rc). No automatic reboot. Review the last error."
    if (( ARCH_INSTALLED )); then
        warn 'Arch installed successfully, but the extra-drive wipe stage did not finish.'
        warn 'Inspect any selected extra drives before retrying an erase operation.'
    elif (( DESTRUCTIVE_WRITES_STARTED )); then
        warn 'Installation stopped after destructive disk operations began.'
        warn 'The selected installation cannot be rolled back automatically. Rerunning starts a NEW installation.'
    else
        warn 'Installation stopped before any disk writes. Your disks were not modified.'
    fi
}

on_exit() {
    local rc=$?
    trap - EXIT ERR
    set +e
    unset USER_PASSWORD ROOT_PASSWORD LUKS_PASSWORD
    cleanup_owned
    if [[ -n $WORKDIR ]]; then rm -rf -- "$WORKDIR"; fi
    if (( rc != 0 )); then report_failure "$rc"; fi
    exit "$rc"
}

preflight() {
    local cmd secure_boot sync_state attempt pci found=0
    [[ $EUID -eq 0 ]] || die "Run from the official Arch ISO as root."
    [[ -d /run/archiso && -e /etc/arch-release ]] || die "Run from a current official Arch installation ISO."
    [[ $(uname -m) == x86_64 ]] || die "Only x86_64 is supported."
    [[ -d /sys/firmware/efi/efivars ]] || die "Boot the ISO in UEFI mode with EFI variables available."
    [[ -t 0 && -t 1 ]] || die "Use an interactive local console; do not pipe this script into bash."
    [[ -z ${SSH_CONNECTION:-} ]] || die "Use the local console, not SSH."

    for cmd in lsblk blockdev swapon find mountpoint grep od tr lspci getent \
        timedatectl pacman pacstrap sgdisk partprobe udevadm wipefs dd \
        cryptsetup mkfs.fat mkfs.ext4 mount umount genfstab blkid arch-chroot \
        mktemp cp rm chmod mkdir sync uname sleep flock sha256sum; do
        command -v "$cmd" >/dev/null || die "Missing live ISO command: $cmd"
    done
    # Prevent a second copy of this installer racing the selected disks.
    exec 9>/run/lock/skittles-installer.lock
    flock -n 9 || die 'Another Skittles installer is already running.'
    assert_install_workspace
    # Prove predictable external prerequisites before asking the user to spend
    # time selecting disks or entering credentials/erase confirmations.
    choose_profile
    secure_boot=/sys/firmware/efi/efivars/SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c
    [[ -r $secure_boot ]] || die "Cannot verify Secure Boot state. Check firmware/efivarfs."
    [[ $(od -An -t u1 -j 4 -N 1 "$secure_boot" | tr -d '[:space:]') == 0 ]] ||
        die "Disable Secure Boot first; this installer does not sign the boot chain."
    [[ -w /sys/firmware/efi/efivars ]] || die "EFI variables are not writable."

    grep -q '^vendor_id[[:space:]]*:[[:space:]]*GenuineIntel$' /proc/cpuinfo || die "This configuration targets an Intel CPU."
    grep -m1 '^model name[[:space:]]*:' /proc/cpuinfo | grep -Fq 'Intel(R) Core(TM) i7-8700K CPU' ||
        die "This release supports the Intel Core i7-8700K only."
    # Scope support honestly: do not assume every NVIDIA card supports nvidia-open.
    for pci in /sys/bus/pci/devices/*; do
        [[ -r $pci/vendor && -r $pci/class && -r $pci/device ]] || continue
        [[ $(<"$pci/vendor") == 0x10de && $(<"$pci/class") == 0x03* ]] || continue
        case $(<"$pci/device") in
            0x2414|0x2486|0x2489|0x24c9) found=1 ;;
            *) die "Unexpected NVIDIA GPU: $(lspci -nn -s "${pci##*/}"). Review driver support before adapting this installer." ;;
        esac
    done
    (( found )) || die "RTX 3060 Ti not detected. This installer targets that GPU."
    [[ -r /sys/devices/system/cpu/cpufreq/policy0/scaling_driver &&
       -r /sys/devices/system/cpu/cpufreq/policy0/scaling_governor ]] ||
        die "CPU frequency policy is unavailable. Check firmware CPU power-management settings."
    if [[ $PROFILE == gaming ]]; then
        grep -qw performance /sys/devices/system/cpu/cpufreq/policy0/scaling_available_governors ||
            die "Gaming profile requires the performance governor for GameMode."
    fi
    getent passwd >/dev/null # Verify account database tools before gathering credentials.
    getent hosts archlinux.org >/dev/null || die "No working DNS. Connect the ISO to the Internet."
    timedatectl set-ntp true
    for ((attempt=0; attempt<30; attempt++)); do
        sync_state=$(timedatectl show -p NTPSynchronized --value)
        [[ $sync_state == yes ]] && break
        sleep 1
    done
    [[ $sync_state == yes ]] || die "Clock has not synchronized. Fix ISO networking/time before installing."

    prepare_preflight_pacman_workspace
    log "Checking repositories and resolving ALL packages before the wipe..."
    # Temporary sync databases only; never partial-upgrade or resize the live ISO.
    pacman --config "$WORKDIR/pacman.conf" --dbpath "$WORKDIR/db" \
        --cachedir "$WORKDIR/cache" -Sy --noconfirm
    pacman --config "$WORKDIR/pacman.conf" --dbpath "$WORKDIR/db" \
        --cachedir "$WORKDIR/cache" -Sp --noconfirm --print-format '%n' -- "${PACKAGES[@]}" > "$WORKDIR/packages.txt"
    log "Preflight passed. Package downloads can still fail if mirrors/network change."
    # --check is a storage-independent release gate: prove external prerequisites
    # and package resolution without enumerating or asking the user to select disks.
    (( CHECK_ONLY )) && return 0
    select_drives
}

collect_credentials() {
    section '04 / YOUR ACCOUNT'
    while :; do
        IFS= read -r -p 'Normal username: ' USERNAME </dev/tty || die "Input closed."
        if valid_username "$USERNAME" && ! getent passwd "$USERNAME" >/dev/null; then break; fi
        warn "Choose a new, non-root username: lowercase letters/digits/_/-, max 32 characters."
    done
    secret USER_PASSWORD 'Normal user password'
    secret ROOT_PASSWORD 'Root password (local recovery)'
    secret LUKS_PASSWORD 'Disk encryption passphrase (US keyboard at boot)'
}

confirm_erase() {
    local answer i drive
    APPROVED=0
    assert_selected_drives
    show_drives '05 / FINAL REVIEW'
    warn "ALL partitions and data on the INSTALL / ERASE ONLY drives will be destroyed. Mode: $WIPE_MODE."
    if [[ $WIPE_MODE == zero ]]; then
        warn "One full logical overwrite; may take hours. SSD remapped/spare cells are not guaranteed erased."
    else
        warn "Signature removal is NOT secure erasure of old data."
    fi
    log "Encrypted ext4 + Plasma Wayland; adaptive CPU policy (no permanent max-performance governor)."
    log "Profile: ${PROFILE:-minimal}; standard + LTS recovery kernels."
    log "Timezone: $TIMEZONE; locale: $LOCALE; keyboard: $KEYMAP; LUKS TRIM: $ALLOW_DISCARDS."
    log 'No disk writes begin until EVERY selected drive has been confirmed.'
    for i in "$TARGET_INDEX" "${EXTRA_INDICES[@]}"; do
        drive=${DRIVES[i]}
        printf '\n  %s  %s\n' "$drive" "${DRIVE_DETAILS[i]}"
        ask answer "Type exactly ERASE $drive (anything else cancels): "
        [[ $answer == "ERASE $drive" ]] || die 'Erase cancelled; no disks were changed.'
    done
    assert_selected_drives
    approve_plan
}

clear_disk() {
    require_approved_plan
    assert_authorized_drive "$@"
    # Bash's local scope keeps extra-drive wipes from changing the Arch target.
    local DISK=$1 DISK_IDENTITY=$2 DISK_SIZE_BYTES=$3
    local nodes node
    assert_same_disk
    if [[ $WIPE_MODE == zero ]]; then
        log "Overwriting $DISK ($DISK_SIZE_BYTES bytes)..."
        # Exact byte count avoids both a short tail and an expected ENOSPC error.
        DESTRUCTIVE_WRITES_STARTED=1
        dd if=/dev/zero of="$DISK" bs=16M iflag=count_bytes count="$DISK_SIZE_BYTES" conv=fsync status=progress
    else
        nodes=$(lsblk -nrpo NAME "$DISK")
        DESTRUCTIVE_WRITES_STARTED=1
        while IFS= read -r node; do
            [[ $node == "$DISK" ]] && continue
            wipefs --all "$node"
        done <<<"$nodes"
        wipefs --all "$DISK"
        sgdisk --zap-all "$DISK"
    fi
    partprobe "$DISK"
    udevadm settle --timeout=30
}

wipe_and_partition() {
    require_approved_plan
    assert_target_binding
    assert_install_workspace
    assert_selected_drives
    section '06 / INSTALLING ARCH'
    clear_disk "$DISK" "$DISK_IDENTITY" "$DISK_SIZE_BYTES"
    # No ignored disk I/O errors. The disk has already been cleared above.
    assert_same_disk
    sgdisk --clear --new=1:0:+2GiB --typecode=1:ef00 --change-name=1:EFI \
        --new=2:0:0 --typecode=2:8309 --change-name=2:Linux-LUKS "$DISK"
    sgdisk --verify "$DISK"
    partprobe "$DISK"
    udevadm settle --timeout=30
    [[ -b $EFI_PART && -b $ROOT_PART ]] || die "New partition devices did not appear."
}

wipe_extra_drives() {
    require_approved_plan
    (( ARCH_INSTALLED )) || die 'Extra drives may only be wiped after a successful installation.'
    local i
    ((${#EXTRA_INDICES[@]})) || return 0
    section '07 / EXTRA DRIVE WIPES'
    log 'Arch installation completed. Clearing only the extra drives you confirmed.'
    for i in "${EXTRA_INDICES[@]}"; do
        clear_disk "${DRIVES[i]}" "${DRIVE_IDS[i]}" "${DRIVE_BYTES[i]}"
        log "${DRIVES[i]} erased and left blank."
    done
}

format_and_mount() {
    require_approved_plan
    assert_target_binding
    assert_same_disk
    [[ $(lsblk -dnro PKNAME "$EFI_PART") == "${DISK##*/}" && $(lsblk -dnro PKNAME "$ROOT_PART") == "${DISK##*/}" ]] ||
        die 'Partition parents do not match the installation drive.'
    local open_options=()
    mkfs.fat -F32 -n EFI "$EFI_PART"
    printf '%s' "$LUKS_PASSWORD" | cryptsetup luksFormat --type luks2 \
        --pbkdf argon2id --batch-mode --key-file=- "$ROOT_PART"
    if (( ALLOW_DISCARDS )); then open_options+=(--allow-discards); fi
    printf '%s' "$LUKS_PASSWORD" | cryptsetup open "${open_options[@]}" \
        --key-file=- "$ROOT_PART" "$CRYPT_NAME"
    OWN_CRYPT=1
    unset LUKS_PASSWORD
    mkfs.ext4 -m 1 -L archroot "/dev/mapper/$CRYPT_NAME"
    mkdir -p "$MNT"
    mount "/dev/mapper/$CRYPT_NAME" "$MNT"
    OWN_ROOT=1
    mkdir -p "$EFI_MNT"
    mount -o nosuid,nodev,noexec,fmask=0077,dmask=0077 "$EFI_PART" "$EFI_MNT"
    OWN_EFI=1
}

write_chroot_script() {
    cat > "$MNT/root/skittles-configure.sh" <<'CHROOT_SCRIPT'
#!/usr/bin/env bash
set +x
set -Eeuo pipefail
umask 022
export LC_ALL=C HISTFILE=/dev/null
ulimit -c 0
LUKS_UUID=$1 ROOT_UUID=$2 USERNAME=$3 TIMEZONE=$4 LOCALE=$5 KEYMAP=$6 HOSTNAME=$7 ALLOW_DISCARDS=$8 PROFILE=$9 VERSION=${10}
IFS= read -r -d '' USER_PASSWORD
IFS= read -r -d '' ROOT_PASSWORD
trap 'unset USER_PASSWORD ROOT_PASSWORD' EXIT

ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
hwclock --systohc
printf '%s UTF-8\n' "$LOCALE" > /etc/locale.gen
locale-gen
printf 'LANG=%s\n' "$LOCALE" > /etc/locale.conf
printf 'KEYMAP=%s\n' "$KEYMAP" > /etc/vconsole.conf
printf '%s\n' "$HOSTNAME" > /etc/hostname
cat > /etc/hosts <<EOF
127.0.0.1 localhost
::1 localhost
127.0.1.1 ${HOSTNAME}.localdomain ${HOSTNAME}
EOF

useradd --create-home --groups wheel --shell /bin/bash "$USERNAME"
chmod 0700 "/home/$USERNAME"
printf 'root:%s\n%s:%s\n' "$ROOT_PASSWORD" "$USERNAME" "$USER_PASSWORD" | chpasswd
unset USER_PASSWORD ROOT_PASSWORD
install -d -m 0755 /etc/sudoers.d
printf '%%wheel ALL=(ALL:ALL) ALL\n' > /etc/sudoers.d/10-wheel
chmod 0440 /etc/sudoers.d/10-wheel
visudo -cf /etc/sudoers

# No baloo content indexing by default. Keep the required KDE dependency itself.
install -d -m 0700 -o "$USERNAME" -g "$USERNAME" "/home/$USERNAME/.config"
cat > "/home/$USERNAME/.config/baloofilerc" <<'BALOO'
[Basic Settings]
Indexing-Enabled=false
BALOO
chown "$USERNAME:$USERNAME" "/home/$USERNAME/.config/baloofilerc"
chmod 0600 "/home/$USERNAME/.config/baloofilerc"

# X11 greeter for compatibility; the logged-in Plasma desktop is Wayland.
# No autologin. Plasma X11 desktop session is deliberately not installed.
install -d -m 0755 /etc/sddm.conf.d
cat > /etc/sddm.conf.d/10-skittles.conf <<'SDDM'
[General]
DisplayServer=x11
[Theme]
Current=breeze
SDDM

# Apply rules on the installed system's first boot, NEVER to the live ISO.
cat > /etc/nftables.conf <<'NFT'
#!/usr/bin/nft -f
# Replace only the table owned by SKITTLES. `destroy` is deliberately
# idempotent and leaves VPN, container, virtualization and user tables intact.
destroy table inet skittles
table inet skittles {
    chain input {
        type filter hook input priority filter; policy drop;
        iifname "lo" accept
        ip saddr 127.0.0.0/8 drop
        ip6 saddr ::1 drop
        ct state invalid drop
        ct state established,related accept
        # ICMP includes path MTU discovery and IPv6 neighbour discovery.
        meta l4proto { icmp, ipv6-icmp } accept
        meta nfproto ipv4 udp sport 67 udp dport 68 accept
        meta nfproto ipv6 ip6 saddr fe80::/10 udp sport 547 udp dport 546 accept
        counter drop
    }
    chain forward {
        type filter hook forward priority filter; policy drop;
    }
    chain output {
        type filter hook output priority filter; policy accept;
    }
}
NFT
chmod 0600 /etc/nftables.conf
nft -c -f /etc/nftables.conf
install -d -m 0755 /etc/systemd/system/NetworkManager.service.d
cat > /etc/systemd/system/NetworkManager.service.d/10-firewall.conf <<'FIREWALL'
[Unit]
Requires=nftables.service systemd-resolved.service
After=nftables.service systemd-resolved.service
FIREWALL

# Reduce unnecessary LAN identification and background connectivity requests.
# Connection profiles can explicitly override these defaults where needed.
install -d -m 0755 /etc/NetworkManager/conf.d /etc/systemd/resolved.conf.d /etc/systemd/journald.conf.d
cat > /etc/NetworkManager/conf.d/20-skittles-privacy.conf <<'NETWORK_PRIVACY'
[main]
hostname-mode=none
dns=systemd-resolved
[connectivity]
enabled=false
[connection]
ipv4.dhcp-send-hostname=false
ipv6.dhcp-send-hostname=false
ipv4.dhcp-client-id=stable
ipv4.dhcp-iaid=stable
ipv6.dhcp-duid=stable-uuid
ipv6.dhcp-iaid=stable
ipv6.addr-gen-mode=stable-privacy
ipv6.ip6-privacy=2
connection.llmnr=0
connection.mdns=0
wifi.cloned-mac-address=stable-ssid
[device]
wifi.scan-rand-mac-address=yes
NETWORK_PRIVACY
cat > /etc/systemd/resolved.conf.d/20-skittles-privacy.conf <<'RESOLVER_PRIVACY'
[Resolve]
LLMNR=no
MulticastDNS=no
DNSOverTLS=no
FallbackDNS=
RESOLVER_PRIVACY
# install_system establishes the resolver symlink after arch-chroot releases
# its temporary /etc/resolv.conf bind mount. Keep live-ISO DNS available here.
# Parse NetworkManager's merged configuration now rather than discovering a typo after reboot.
NetworkManager --print-config >/dev/null
cat > /etc/systemd/journald.conf.d/20-skittles-retention.conf <<'JOURNAL'
[Journal]
Storage=persistent
SystemMaxUse=256M
MaxRetentionSec=14day
JOURNAL

if [[ $PROFILE == gaming ]]; then
    # GameMode may request performance policy only while a game is running.
    # The normal desktop keeps the kernel/driver-selected adaptive policy.
    getent group gamemode >/dev/null || groupadd --system gamemode
    usermod -aG gamemode "$USERNAME"
    cat > /etc/gamemode.ini <<'GAMEMODE'
[general]
desiredgov=performance
renice=0
softrealtime=off
inhibit_screensaver=1
ioprio=0
disable_splitlock=0
GAMEMODE
fi

# Do not force a permanent CPU governor. On the supported i7-8700K, the
# kernel/intel_pstate policy remains adaptive; the gaming profile uses GameMode
# for explicit, session-scoped performance requests.
cat > /etc/systemd/zram-generator.conf <<'ZRAM'
[zram0]
# Match zram-generator's conservative sizing model explicitly. Leave the
# compression algorithm and swap priority at kernel/generator defaults.
zram-size = min(ram / 2, 4096)
ZRAM
install -d -m 0755 /etc/sysctl.d /etc/systemd/coredump.conf.d
cat > /etc/sysctl.d/60-skittles.conf <<'SYSCTL'
kernel.dmesg_restrict = 1
kernel.kptr_restrict = 2
kernel.yama.ptrace_scope = 1
kernel.randomize_va_space = 2
kernel.unprivileged_bpf_disabled = 1
kernel.kexec_load_disabled = 1
fs.suid_dumpable = 0
fs.protected_hardlinks = 1
fs.protected_symlinks = 1
vm.mmap_rnd_bits = 32
vm.mmap_rnd_compat_bits = 16
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
SYSCTL
cat > /etc/systemd/coredump.conf.d/10-skittles.conf <<'COREDUMP'
[Coredump]
Storage=none
ProcessSizeMax=0
COREDUMP

# Use Arch's prebuilt open NVIDIA modules for both supported kernels.
# nvidia-utils >= 560 enables DRM KMS by default; 595+ uses kernel suspend
# notifiers for full VRAM preservation. Keep modules out of the initramfs so
# /var/tmp is available to the packaged suspend-preservation path.
sed -i 's/^MODULES=.*/MODULES=()/' /etc/mkinitcpio.conf
sed -i 's/^HOOKS=.*/HOOKS=(base systemd autodetect microcode modconf keyboard sd-vconsole block sd-encrypt filesystems fsck)/' /etc/mkinitcpio.conf
grep -q '^MODULES=()$' /etc/mkinitcpio.conf
grep -q '^HOOKS=.*sd-encrypt' /etc/mkinitcpio.conf

# Verify both official kernel packages received a loadable NVIDIA module.
kernels=0
for kernel_dir in /usr/lib/modules/*; do
    [[ -f $kernel_dir/pkgbase ]] || continue
    case $(<"$kernel_dir/pkgbase") in linux|linux-lts) ;; *) continue ;; esac
    kernel=${kernel_dir##*/}
    modinfo -k "$kernel" nvidia >/dev/null
    modinfo -k "$kernel" nvidia_drm >/dev/null
    kernels=$((kernels + 1))
done
(( kernels == 2 ))
mkinitcpio -P

cmdline="rd.luks.name=${LUKS_UUID}=skittles-root root=UUID=${ROOT_UUID} rw zswap.enabled=0"
if (( ALLOW_DISCARDS )); then
    cmdline+=" rd.luks.options=${LUKS_UUID}=discard"
    systemctl enable fstrim.timer
else
    systemctl disable fstrim.timer
fi
cat > /etc/default/grub <<EOF
GRUB_DEFAULT=0
GRUB_TIMEOUT=5
GRUB_TIMEOUT_STYLE=menu
GRUB_DISTRIBUTOR="Arch"
GRUB_CMDLINE_LINUX_DEFAULT="$cmdline"
GRUB_CMDLINE_LINUX=""
GRUB_DISABLE_OS_PROBER=true
EOF
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=SKITTLES --recheck
# Fallback EFI path on THIS disk, for firmware that loses/ignores its NVRAM entry.
grub-install --target=x86_64-efi --efi-directory=/boot --removable --no-nvram --recheck
grub-mkconfig -o /boot/grub/grub.cfg
grub-script-check /boot/grub/grub.cfg
test -s /boot/vmlinuz-linux
test -s /boot/initramfs-linux.img
test -s /boot/vmlinuz-linux-lts
test -s /boot/initramfs-linux-lts.img
test -s /boot/EFI/SKITTLES/grubx64.efi
test -s /boot/EFI/BOOT/BOOTX64.EFI
test -s /usr/share/wayland-sessions/plasma.desktop

systemctl enable NetworkManager.service systemd-resolved.service sddm.service nftables.service systemd-timesyncd.service
systemctl disable nvidia-suspend.service nvidia-suspend-then-hibernate.service nvidia-hibernate.service nvidia-resume.service
systemctl set-default graphical.target
pacman -Q > /root/skittles-packages.txt
chmod 0600 /root/skittles-packages.txt
printf 'VERSION=%s\nPROFILE=%s\nDISCARDS=%s\nBOOTLOADER=grub\nKERNELS=linux,linux-lts\nSECURE_BOOT=unsupported\nRESOLVER=systemd-resolved\n' \
    "$VERSION" "$PROFILE" "$ALLOW_DISCARDS" > /etc/skittles-release

install -d -m 0755 /usr/local/bin /usr/share/doc/skittles
cat > /usr/local/bin/skittles-doctor <<'DOCTOR_SCRIPT'
#!/usr/bin/env bash
# Local, read-only checks. No telemetry, uploads, repairs or automatic sudo.
set -uo pipefail
export LC_ALL=C
failures=0
pass() { printf 'PASS  %s\n' "$*"; }
fail() { printf 'FAIL  %s\n' "$*"; failures=$((failures + 1)); }
info() { printf 'INFO  %s\n' "$*"; }
section() { printf '\n== %s ==\n' "$1"; }
check() {
    local label=$1
    shift
    if "$@" >/dev/null 2>&1; then pass "$label"; else fail "$label"; fi
}
check_line() {
    local label=$1 file=$2 line=$3
    check "$label" grep -Fqx -- "$line" "$file"
}
check_mount_option() {
    local label=$1 target=$2 option=$3 options
    options=$(findmnt -n -o OPTIONS "$target" 2>/dev/null || true)
    if [[ ,$options, == *,$option,* ]]; then pass "$label"; else fail "$label"; fi
}
user_in_group() {
    local user=$1 group=$2
    id -nG "$user" | tr ' ' '\n' | grep -Fxq -- "$group"
}

printf 'SKITTLES / local health check\n'
if [[ -r /etc/skittles-release ]]; then cat /etc/skittles-release; else fail '/etc/skittles-release readable'; fi
printf 'Running kernel: %s\n' "$(uname -r)"
printf 'Session: %s\n' "${XDG_SESSION_TYPE:-not a graphical session}"
if [[ ${XDG_SESSION_TYPE:-} == wayland ]]; then pass 'Plasma session is Wayland'
elif [[ ${XDG_SESSION_TYPE:-} == x11 ]]; then fail "graphical session is Wayland (found ${XDG_SESSION_TYPE})"
else info 'Wayland check skipped outside a graphical session'; fi

section 'BOOT / SECURITY'
for unit in NetworkManager systemd-resolved nftables systemd-timesyncd sddm; do
    check "$unit service active" systemctl is-active --quiet "$unit"
done
secure_boot_var=/sys/firmware/efi/efivars/SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c
if [[ -r $secure_boot_var ]]; then
    secure_boot=$(od -An -t u1 -j 4 -N 1 "$secure_boot_var" 2>/dev/null | tr -d '[:space:]')
    if [[ $secure_boot == 0 ]]; then pass 'Secure Boot disabled (required by this release)'
    elif [[ $secure_boot == 1 ]]; then fail 'Secure Boot disabled (this release does not sign the boot chain)'
    else fail 'Secure Boot state readable'; fi
else
    fail 'Secure Boot EFI variable readable'
fi
check 'encrypted-root mapping active' test -b /dev/mapper/skittles-root
check 'root filesystem is ext4' test "$(findmnt -n -o FSTYPE / 2>/dev/null)" = ext4
check 'root mounted from skittles-root mapping' test "$(findmnt -n -o SOURCE / 2>/dev/null)" = /dev/mapper/skittles-root
check 'boot filesystem mounted' mountpoint -q /boot
check 'boot filesystem is FAT' test "$(findmnt -n -o FSTYPE /boot 2>/dev/null)" = vfat
check_mount_option 'boot mount has nosuid' /boot nosuid
check_mount_option 'boot mount has nodev' /boot nodev
check_mount_option 'boot mount has noexec' /boot noexec
check_line 'core-dump storage disabled' /etc/systemd/coredump.conf.d/10-skittles.conf 'Storage=none'
check_line 'core-dump processing disabled' /etc/systemd/coredump.conf.d/10-skittles.conf 'ProcessSizeMax=0'
check_line 'dmesg restricted' /proc/sys/kernel/dmesg_restrict '1'
check_line 'kernel pointers restricted' /proc/sys/kernel/kptr_restrict '2'
check_line 'ptrace restricted' /proc/sys/kernel/yama/ptrace_scope '1'
check_line 'full ASLR enabled' /proc/sys/kernel/randomize_va_space '2'
check_line 'unprivileged BPF disabled' /proc/sys/kernel/unprivileged_bpf_disabled '1'
check_line 'kexec image loading disabled' /proc/sys/kernel/kexec_load_disabled '1'
check_line 'setuid core dumps disabled' /proc/sys/fs/suid_dumpable '0'
check_line 'protected hardlinks enabled' /proc/sys/fs/protected_hardlinks '1'
check_line 'protected symlinks enabled' /proc/sys/fs/protected_symlinks '1'
check_line '64-bit mmap ASLR entropy pinned' /proc/sys/vm/mmap_rnd_bits '32'
check_line '32-bit mmap ASLR entropy pinned' /proc/sys/vm/mmap_rnd_compat_bits '16'
check_line 'IPv4 redirects disabled (all)' /proc/sys/net/ipv4/conf/all/accept_redirects '0'
check_line 'IPv4 redirects disabled (default)' /proc/sys/net/ipv4/conf/default/accept_redirects '0'
check_line 'IPv6 redirects disabled (all)' /proc/sys/net/ipv6/conf/all/accept_redirects '0'
check_line 'IPv6 redirects disabled (default)' /proc/sys/net/ipv6/conf/default/accept_redirects '0'
check_line 'IPv4 redirect sending disabled (all)' /proc/sys/net/ipv4/conf/all/send_redirects '0'
check_line 'IPv4 redirect sending disabled (default)' /proc/sys/net/ipv4/conf/default/send_redirects '0'
if (( EUID != 0 )); then
    check 'private user home permissions' test "$(stat -c %a "$HOME" 2>/dev/null)" = 700
    if [[ -r $HOME/.config/baloofilerc ]]; then
        check_line 'Baloo indexing disabled' "$HOME/.config/baloofilerc" 'Indexing-Enabled=false'
    else
        info "Baloo check skipped: $HOME/.config/baloofilerc is not readable"
    fi
else
    info 'User-home/Baloo checks are performed by non-root skittles-doctor'
fi

section 'NVIDIA'
if nvidia_report=$(nvidia-smi --query-gpu=name,driver_version --format=csv,noheader 2>/dev/null); then
    pass 'NVIDIA GPU responds'
    info "NVIDIA GPU / driver: $nvidia_report"
else
    fail 'NVIDIA GPU responds'
fi
check 'NVIDIA packages for linux + linux-lts' pacman -Q nvidia-open nvidia-open-lts nvidia-utils
nvidia_kernel_count=0
for kernel_dir in /usr/lib/modules/*; do
    [[ -f $kernel_dir/pkgbase ]] || continue
    kernel_pkg=$(<"$kernel_dir/pkgbase")
    case $kernel_pkg in linux|linux-lts) ;; *) continue ;; esac
    kernel=${kernel_dir##*/}
    check "$kernel_pkg has NVIDIA module" modinfo -k "$kernel" nvidia
    check "$kernel_pkg has NVIDIA DRM module" modinfo -k "$kernel" nvidia_drm
    nvidia_kernel_count=$((nvidia_kernel_count + 1))
done
if (( nvidia_kernel_count == 2 )); then pass 'NVIDIA modules present for both supported kernels'; else fail 'NVIDIA modules present for both supported kernels'; fi
check 'running kernel has NVIDIA module' modinfo -k "$(uname -r)" nvidia
check 'running kernel has NVIDIA DRM module' modinfo -k "$(uname -r)" nvidia_drm
for unit in nvidia-suspend nvidia-suspend-then-hibernate nvidia-hibernate nvidia-resume; do
    if systemctl is-enabled --quiet "$unit.service"; then fail "legacy $unit service disabled"; else pass "legacy $unit service disabled"; fi
done
if [[ -r /sys/module/nvidia_drm/parameters/modeset ]]; then check 'NVIDIA DRM KMS enabled' grep -qx 'Y' /sys/module/nvidia_drm/parameters/modeset; else fail 'NVIDIA DRM KMS parameter available'; fi
if [[ -r /sys/module/nvidia_drm/parameters/fbdev ]]; then check 'NVIDIA DRM fbdev enabled' grep -qx 'Y' /sys/module/nvidia_drm/parameters/fbdev; else fail 'NVIDIA DRM fbdev parameter available'; fi
if [[ -r /proc/driver/nvidia/params ]]; then
    check 'NVIDIA kernel suspend notifiers enabled' grep -Eq '^UseKernelSuspendNotifiers:[[:space:]]+1$' /proc/driver/nvidia/params
    check 'NVIDIA temporary backing path is /var/tmp' grep -Eq '^TemporaryFilePath:[[:space:]]+"?/var/tmp"?$' /proc/driver/nvidia/params
    preserve=$(sed -n 's/^PreserveVideoMemoryAllocations:[[:space:]]*//p' /proc/driver/nvidia/params | head -n1)
    [[ -n $preserve ]] && info "NVIDIA PreserveVideoMemoryAllocations=$preserve"
    pat=$(sed -n 's/^UsePageAttributeTable:[[:space:]]*//p' /proc/driver/nvidia/params | head -n1)
    [[ -n $pat ]] && info "NVIDIA UsePageAttributeTable=$pat (reported only; not forced)"
else
    fail 'NVIDIA runtime parameter file available'
fi

section 'CPU'
check 'CPU is Intel Core i7-8700K' bash -c "grep -m1 '^model name[[:space:]]*:' /proc/cpuinfo | grep -Fq 'Intel(R) Core(TM) i7-8700K CPU'"
cpu_policy_count=0
for policy_dir in /sys/devices/system/cpu/cpufreq/policy*; do
    [[ -d $policy_dir ]] || continue
    cpu_policy_count=$((cpu_policy_count + 1))
    if [[ -r $policy_dir/scaling_driver ]]; then driver=$(<"$policy_dir/scaling_driver"); else driver=unknown; fi
    if [[ -r $policy_dir/scaling_governor ]]; then governor=$(<"$policy_dir/scaling_governor"); else governor=unknown; fi
    printf 'INFO  %s driver=%s governor=%s' "${policy_dir##*/}" "$driver" "$governor"
    if [[ -r $policy_dir/scaling_available_governors ]]; then printf ' available=%s' "$(<"$policy_dir/scaling_available_governors")"; fi
    if [[ -r $policy_dir/energy_performance_preference ]]; then printf ' epp=%s' "$(<"$policy_dir/energy_performance_preference")"; fi
    printf '\n'
done
if (( cpu_policy_count > 0 )); then pass 'CPU frequency policy available'; else fail 'CPU frequency policy available'; fi
if [[ -r /sys/devices/system/cpu/intel_pstate/no_turbo ]]; then
    if [[ $(</sys/devices/system/cpu/intel_pstate/no_turbo) == 0 ]]; then pass 'Intel Turbo Boost available to kernel policy'; else info 'Intel Turbo Boost disabled by firmware/kernel policy'; fi
fi
if [[ -r /sys/devices/system/clocksource/clocksource0/current_clocksource ]]; then
    info "current clocksource: $(</sys/devices/system/clocksource/clocksource0/current_clocksource)"
else
    fail 'current clocksource readable'
fi
if [[ -r /sys/devices/system/clocksource/clocksource0/available_clocksource ]]; then
    info "available clocksources: $(</sys/devices/system/clocksource/clocksource0/available_clocksource)"
else
    fail 'available clocksources readable'
fi

section 'STORAGE / ZRAM / TRIM'
check_line 'zram sizing configured' /etc/systemd/zram-generator.conf 'zram-size = min(ram / 2, 4096)'
check 'zram swap active' bash -c 'swapon --noheadings --show=NAME | grep -Fxq /dev/zram0'
if [[ -r /sys/module/zswap/parameters/enabled ]]; then
    zswap_state=$(</sys/module/zswap/parameters/enabled)
    if [[ $zswap_state == N || $zswap_state == 0 ]]; then pass 'zswap disabled while zram is active'; else fail "zswap disabled while zram is active (found $zswap_state)"; fi
else
    fail 'zswap runtime state readable'
fi
check 'running kernel command line disables zswap' grep -qw -- 'zswap.enabled=0' /proc/cmdline
if command -v zramctl >/dev/null 2>&1; then
    if zram_report=$(zramctl /dev/zram0 2>/dev/null); then printf 'zram state:\n%s\n' "$zram_report"; else fail 'zram0 state readable'; fi
fi
if [[ -r /sys/block/zram0/comp_algorithm ]]; then info "zram algorithms: $(</sys/block/zram0/comp_algorithm)"; fi
printf 'Swap devices:\n'
swapon --show || true
for vm_key in swappiness page-cluster watermark_boost_factor watermark_scale_factor; do
    if [[ -r /proc/sys/vm/$vm_key ]]; then info "vm.$vm_key=$(</proc/sys/vm/$vm_key) (reported only)"; fi
done
info "root filesystem: $(findmnt -n -o SOURCE,FSTYPE,OPTIONS / 2>/dev/null || printf unavailable)"
info "boot filesystem: $(findmnt -n -o SOURCE,FSTYPE,OPTIONS /boot 2>/dev/null || printf unavailable)"
root_block=$(readlink -f /dev/mapper/skittles-root 2>/dev/null)
root_block=${root_block##*/}
root_slave=$(find "/sys/class/block/$root_block/slaves" -mindepth 1 -maxdepth 1 -printf '%f\n' 2>/dev/null | head -n1)
if [[ -n $root_slave ]]; then
    parent_disk=$(lsblk -ndo PKNAME "/dev/$root_slave" 2>/dev/null | head -n1)
    [[ -n $parent_disk ]] || parent_disk=$root_slave
    for attribute in rotational logical_block_size physical_block_size; do
        queue_path=/sys/class/block/$parent_disk/queue/$attribute
        if [[ -r $queue_path ]]; then info "$parent_disk $attribute=$(<"$queue_path")"; fi
    done
fi
if [[ -r /etc/skittles-release ]]; then
    discard_setting=$(sed -n 's/^DISCARDS=//p' /etc/skittles-release | head -n1)
    if [[ $discard_setting == 1 ]]; then
        check 'weekly fstrim enabled' systemctl is-enabled --quiet fstrim.timer
    elif [[ $discard_setting == 0 ]]; then
        if systemctl is-enabled --quiet fstrim.timer; then fail 'fstrim disabled when LUKS discards were not selected'; else pass 'fstrim disabled when LUKS discards were not selected'; fi
    else
        fail 'recorded discard policy is 0 or 1'
    fi
fi
if (( EUID == 0 )); then
    luks_status=$(cryptsetup status skittles-root 2>/dev/null || true)
    luks_sector_size=$(sed -n 's/^[[:space:]]*sector size:[[:space:]]*//p' <<<"$luks_status" | head -n1)
    [[ -n $luks_sector_size ]] && info "LUKS sector size=$luks_sector_size"
    if [[ ${discard_setting:-} == 1 ]]; then
        if grep -q 'discards' <<<"$luks_status"; then pass 'LUKS discard policy matches install choice'; else fail 'LUKS discard policy matches install choice'; fi
    elif [[ ${discard_setting:-} == 0 ]]; then
        if grep -q 'discards' <<<"$luks_status"; then fail 'LUKS discard policy matches install choice'; else pass 'LUKS discard policy matches install choice'; fi
    fi
else
    info 'Run sudo skittles-doctor for live LUKS discard inspection'
fi

section 'NETWORK / PRIVACY'
check 'NetworkManager configuration parses' NetworkManager --print-config
check 'resolver points at systemd-resolved stub' test "$(readlink -f /etc/resolv.conf 2>/dev/null)" = /run/systemd/resolve/stub-resolv.conf
check 'systemd-resolved status available' resolvectl status
check_line 'NetworkManager uses systemd-resolved' /etc/NetworkManager/conf.d/20-skittles-privacy.conf 'dns=systemd-resolved'
check_line 'NetworkManager does not manage hostname' /etc/NetworkManager/conf.d/20-skittles-privacy.conf 'hostname-mode=none'
check_line 'NetworkManager connectivity checks disabled' /etc/NetworkManager/conf.d/20-skittles-privacy.conf 'enabled=false'
check_line 'DHCP hostname disabled (IPv4)' /etc/NetworkManager/conf.d/20-skittles-privacy.conf 'ipv4.dhcp-send-hostname=false'
check_line 'DHCP hostname disabled (IPv6)' /etc/NetworkManager/conf.d/20-skittles-privacy.conf 'ipv6.dhcp-send-hostname=false'
check_line 'stable DHCPv4 client ID' /etc/NetworkManager/conf.d/20-skittles-privacy.conf 'ipv4.dhcp-client-id=stable'
check_line 'stable DHCPv4 IAID' /etc/NetworkManager/conf.d/20-skittles-privacy.conf 'ipv4.dhcp-iaid=stable'
check_line 'stable DHCPv6 DUID' /etc/NetworkManager/conf.d/20-skittles-privacy.conf 'ipv6.dhcp-duid=stable-uuid'
check_line 'stable DHCPv6 IAID' /etc/NetworkManager/conf.d/20-skittles-privacy.conf 'ipv6.dhcp-iaid=stable'
check_line 'Wi-Fi association MAC stable per SSID' /etc/NetworkManager/conf.d/20-skittles-privacy.conf 'wifi.cloned-mac-address=stable-ssid'
check_line 'Wi-Fi scan MAC randomization enabled' /etc/NetworkManager/conf.d/20-skittles-privacy.conf 'wifi.scan-rand-mac-address=yes'
check_line 'IPv6 stable address generation configured' /etc/NetworkManager/conf.d/20-skittles-privacy.conf 'ipv6.addr-gen-mode=stable-privacy'
check_line 'IPv6 temporary addresses preferred' /etc/NetworkManager/conf.d/20-skittles-privacy.conf 'ipv6.ip6-privacy=2'
check_line 'LLMNR disabled in NetworkManager defaults' /etc/NetworkManager/conf.d/20-skittles-privacy.conf 'connection.llmnr=0'
check_line 'mDNS disabled in NetworkManager defaults' /etc/NetworkManager/conf.d/20-skittles-privacy.conf 'connection.mdns=0'
check_line 'LLMNR disabled in resolved' /etc/systemd/resolved.conf.d/20-skittles-privacy.conf 'LLMNR=no'
check_line 'mDNS disabled in resolved' /etc/systemd/resolved.conf.d/20-skittles-privacy.conf 'MulticastDNS=no'
check_line 'DNS-over-TLS explicitly disabled' /etc/systemd/resolved.conf.d/20-skittles-privacy.conf 'DNSOverTLS=no'
check_line 'public fallback DNS disabled' /etc/systemd/resolved.conf.d/20-skittles-privacy.conf 'FallbackDNS='
check_line 'journal size cap configured' /etc/systemd/journald.conf.d/20-skittles-retention.conf 'SystemMaxUse=256M'
check_line 'journal retention cap configured' /etc/systemd/journald.conf.d/20-skittles-retention.conf 'MaxRetentionSec=14day'
if command -v nmcli >/dev/null 2>&1; then
    active_connections=$(nmcli -t -f NAME,TYPE connection show --active 2>/dev/null || true)
    if [[ -n $active_connections ]]; then printf 'Active NetworkManager connections:\n%s\n' "$active_connections"; else info 'No active NetworkManager connection'; fi
fi

section 'FIREWALL'
if (( EUID == 0 )); then
    check 'Skittles firewall table loaded' nft list table inet skittles
    check 'firewall configuration parses' nft -c -f /etc/nftables.conf
    check_line 'firewall reload replaces only the SKITTLES table' /etc/nftables.conf 'destroy table inet skittles'
    if grep -Eq '^[[:space:]]*flush[[:space:]]+ruleset([[:space:]]|$)' /etc/nftables.conf; then fail 'firewall config avoids global ruleset flush'; else pass 'firewall config avoids global ruleset flush'; fi
    check 'firewall input policy is drop' bash -c "nft list chain inet skittles input | grep -q 'policy drop'"
    check 'firewall forward policy is drop' bash -c "nft list chain inet skittles forward | grep -q 'policy drop'"
    check 'firewall output policy is accept' bash -c "nft list chain inet skittles output | grep -q 'policy accept'"
    check_line 'sudo requires authentication for wheel' /etc/sudoers.d/10-wheel '%wheel ALL=(ALL:ALL) ALL'
    check 'standard kernel boot image' test -s /boot/vmlinuz-linux
    check 'LTS recovery kernel boot image' test -s /boot/vmlinuz-linux-lts
    check 'GRUB contains linux-lts entry' grep -q 'linux-lts' /boot/grub/grub.cfg
    # awk's $0 and end-of-line $ are intentionally literal here.
    # shellcheck disable=SC2016
    check 'every GRUB Linux entry disables zswap' awk '/^[[:space:]]*linux(efi)?[[:space:]]/ { seen=1; if ($0 !~ /(^|[[:space:]])zswap.enabled=0([[:space:]]|$)/) bad=1 } END { exit !(seen && !bad) }' /boot/grub/grub.cfg
    check 'NVIDIA modules are late-loaded' grep -Fqx 'MODULES=()' /etc/mkinitcpio.conf
else
    info 'Run sudo skittles-doctor for firewall, sudo and boot-file inspection'
fi

section 'DISPLAY / GAMING'
if [[ ${XDG_SESSION_TYPE:-} == wayland || ${XDG_SESSION_TYPE:-} == x11 ]]; then
    if command -v vulkaninfo >/dev/null 2>&1; then check 'Vulkan device enumeration' vulkaninfo --summary; else fail 'Vulkan diagnostic tool available'; fi
else
    info 'Vulkan enumeration skipped outside a graphical session'
fi
if pacman -Q steam >/dev/null 2>&1; then
    check '32-bit NVIDIA and Vulkan libraries' pacman -Q lib32-nvidia-utils lib32-vulkan-icd-loader
    check 'gaming tools' pacman -Q gamemode lib32-gamemode mangohud lib32-mangohud ntsync-autoload
    check_line 'GameMode performance governor explicit' /etc/gamemode.ini 'desiredgov=performance'
    check_line 'GameMode I/O priority explicit' /etc/gamemode.ini 'ioprio=0'
    check_line 'GameMode keeps split-lock mitigation enabled' /etc/gamemode.ini 'disable_splitlock=0'
    check 'GameMode group exists' getent group gamemode
    if (( EUID == 0 )); then
        gamemode_members=$(getent group gamemode | cut -d: -f4)
        if [[ -n $gamemode_members ]]; then pass 'installed user belongs to GameMode group'; else fail 'installed user belongs to GameMode group'; fi
    else
        check 'current user belongs to GameMode group' user_in_group "$USER" gamemode
    fi
    check 'NTSync module is available' modprobe -n ntsync
    if [[ -e /dev/ntsync ]]; then pass 'NTSync device active'; else info 'NTSync device not active (load/use may be session dependent)'; fi
    info 'Physical GameMode validation remains: gamemoded -t'
else
    info 'Minimal profile: Steam/GameMode stack not installed'
fi

section 'FAILED SERVICES'
if failed_units=$(systemctl --failed --no-legend --plain 2>/dev/null); then
    if [[ -z $failed_units ]]; then pass 'no failed system services'; else fail 'no failed system services'; printf '%s\n' "$failed_units"; fi
else
    fail 'could not query failed system services'
fi
printf '\n%s check(s) failed. No settings changed.\n' "$failures"
(( failures == 0 ))

DOCTOR_SCRIPT
chmod 0755 /usr/local/bin/skittles-doctor
cat > /usr/share/doc/skittles/START-HERE.txt <<'START_HERE'
SKITTLES / FIRST BOOT

Run skittles-doctor in Konsole. Run sudo skittles-doctor for firewall/boot checks.
Review systemctl --failed. The checks are local and do not upload anything.
Current nvidia-open uses kernel suspend notifiers; skittles-doctor reports the
active NVIDIA power-management parameters. Suspend/resume still requires a real
hardware test before you rely on it.

GAMING PROFILE
Open Steam as your normal user. Sign in yourself; the installer never signs in.
Use Steam's Compatibility settings to choose its supplied Proton versions.
Validate GameMode from a terminal with: gamemoded -t
Optional per-game launch option: gamemoderun mangohud %command%
If a game fails, first retry without these wrappers. Anti-cheat compatibility
depends on the game/publisher; neither Proton nor this installer guarantees it.
No global FPS cap, GPU overclock, injected overlay, or Proton download is forced.

PRIVACY
Root is encrypted, but the EFI partition/kernel/initramfs are unsigned and visible.
The firewall is not a VPN, browser sandbox, or anonymity tool. Network-provided DNS
is routed through systemd-resolved without public fallback or encryption by SKITTLES.
Captive-portal auto-detection and DHCP hostname announcements are disabled. Wi-Fi
association MACs are stable per SSID. Your network still sees connection metadata.
Journal retention is capped at 14 days/256 MiB on the encrypted root.

RECOVERY
If a kernel update fails, use GRUB's Advanced options to select linux-lts.
Keep backups and a current Arch ISO. Read Arch news before full pacman -Syu updates.
Never rerun the installer as an upgrade/repair: it erases the selected drives.
The installed package/version list is /root/skittles-packages.txt.
For detailed ISO recovery, see docs/RECOVERY.md in the release bundle.
START_HERE
# Package cache is retained for recovery; never delete all rollback packages.
rm -f /root/skittles-configure.sh
CHROOT_SCRIPT
    chmod 0700 "$MNT/root/skittles-configure.sh"
}

install_system() {
    local luks_uuid root_uuid
    require_approved_plan
    assert_target_binding
    log "Installing all packages directly onto the target filesystem..."
    pacstrap -K -C "$WORKDIR/pacman.conf" "$MNT" "${PACKAGES[@]}"
    # Persist multilib for gaming upgrades, not only the initial transaction.
    cp "$WORKDIR/pacman.conf" "$MNT/etc/pacman.conf"
    chmod 0644 "$MNT/etc/pacman.conf"
    genfstab -U "$MNT" > "$MNT/etc/fstab"
    chmod 0644 "$MNT/etc/fstab"
    luks_uuid=$(cryptsetup luksUUID "$ROOT_PART")
    root_uuid=$(blkid -s UUID -o value "/dev/mapper/$CRYPT_NAME")
    [[ $luks_uuid =~ ^[[:xdigit:]-]{36}$ && $root_uuid =~ ^[[:xdigit:]-]{36}$ ]] || die "Invalid filesystem/LUKS UUID."
    write_chroot_script
    printf '%s\0%s\0' "$USER_PASSWORD" "$ROOT_PASSWORD" |
        arch-chroot "$MNT" /root/skittles-configure.sh "$luks_uuid" "$root_uuid" \
            "$USERNAME" "$TIMEZONE" "$LOCALE" "$KEYMAP" "$HOSTNAME" "$ALLOW_DISCARDS" "$PROFILE" "$VERSION"
    unset USER_PASSWORD ROOT_PASSWORD
    # arch-chroot temporarily bind-mounts the live resolver. Replace the target
    # only after that mount is released, without changing the live ISO resolver.
    ln -sfn ../run/systemd/resolve/stub-resolv.conf "$MNT/etc/resolv.conf"
    sync
    umount "$EFI_MNT"
    OWN_EFI=0
    umount "$MNT"
    OWN_ROOT=0
    cryptsetup close "$CRYPT_NAME"
    OWN_CRYPT=0
}

main() {
    # Never use xtrace/verbose mode around credentials, even with bash -x/-v.
    set +xv
    set -Eeuo pipefail
    umask 022
    export LC_ALL=C HISTFILE=/dev/null
    export -n USER_PASSWORD ROOT_PASSWORD LUKS_PASSWORD
    ulimit -c 0
    local rc=0
    parse_args "$@" || rc=$?
    (( rc == 10 )) && return 0
    (( rc == 0 )) || return "$rc"
    if (( DEMO )); then demo; return 0; fi
    if (( LIST_PACKAGES )); then configure_packages; printf '%s\n' "${PACKAGES[@]}"; return 0; fi
    trap on_exit EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
    # Keep the error trap to a builtin: avoid re-entering themed functions while
    # Bash unwinds a failed function under errexit/errtrace.
    trap 'printf "  SKITTLES  Command failed at line %s.\n" "$LINENO" >&2' ERR
    banner
    log "Installer $VERSION; no drive selected."
    preflight
    if (( CHECK_ONLY )); then
        log "Check complete; no disk changes or installation performed."
        return 0
    fi
    collect_credentials
    confirm_erase
    wipe_and_partition
    format_and_mount
    install_system
    ARCH_INSTALLED=1
    wipe_extra_drives
    section '08 / ALL DONE'
    log "Installation complete. Remove the ISO and run reboot when ready."
    log "After login: skittles-doctor; then sudo skittles-doctor for privileged checks."
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
    main "$@"
fi
