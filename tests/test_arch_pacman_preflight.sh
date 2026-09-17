#!/usr/bin/env bash
# Non-destructive current-Arch integration for the pacman 7 DownloadUser path.
set -Eeuo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT"
# shellcheck source=../skittles-installer.sh
source ./skittles-installer.sh

[[ $EUID -eq 0 ]] || { echo 'Arch pacman integration must run as root in a disposable container.' >&2; exit 1; }
command -v pacman >/dev/null
pacman --version

INTEGRATION_TMP=$(mktemp -d /tmp/skittles-arch-pacman.XXXXXXXX)
cleanup_workspace() {
    [[ -z ${WORKDIR:-} ]] || rm -rf -- "$WORKDIR"
    WORKDIR=""
}
cleanup_integration() {
    cleanup_workspace
    [[ -z ${INTEGRATION_TMP:-} ]] || rm -rf -- "$INTEGRATION_TMP"
}
trap cleanup_integration EXIT

# Bring the disposable official Arch container fully current before testing the
# custom preflight path. If the hosted runtime itself blocks pacman's sandbox,
# report that distinctly instead of weakening production with DisableSandbox*.
base_update_log="$INTEGRATION_TMP/base-update.log"
if ! pacman -Syu --noconfirm --needed python shellcheck 2>&1 | tee "$base_update_log"; then
    echo 'PACKAGE-PERMISSION LOGIC: NOT PROVEN' >&2
    if grep -Eiq 'landlock|seccomp|sandbox|operation not permitted' "$base_update_log"; then
        echo 'PACMAN SANDBOX IN HOSTED CONTAINER: BLOCKED' >&2
    else
        echo 'PACMAN SANDBOX IN HOSTED CONTAINER: UNKNOWN' >&2
    fi
    exit 1
fi

download_user=$(sed -n 's/^[[:space:]]*DownloadUser[[:space:]]*=[[:space:]]*\([^#[:space:]]\+\).*/\1/p' /etc/pacman.conf | tail -n1)
[[ -n $download_user ]] || { echo 'Current Arch pacman.conf has no active DownloadUser; integration assumptions changed.' >&2; exit 1; }
getent passwd "$download_user" >/dev/null || { echo "Configured pacman DownloadUser does not exist: $download_user" >&2; exit 1; }

active_sandbox_policy() {
    grep -E '^[[:space:]]*(DisableSandbox|DisableSandboxFilesystem|DisableSandboxSyscalls)([[:space:]]|$)' "$1" || true
}

source_sandbox_policy=$(active_sandbox_policy /etc/pacman.conf)

for PROFILE in minimal gaming; do
    configure_packages
    prepare_preflight_pacman_workspace

    [[ $(stat -c '%a' "$WORKDIR") == 711 ]] || { echo "workspace mode is not 0711: $WORKDIR" >&2; exit 1; }
    [[ $(stat -c '%a' "$WORKDIR/db") == 755 ]] || { echo 'DBPath parent is not 0755.' >&2; exit 1; }
    [[ $(stat -c '%a' "$WORKDIR/cache") == 755 ]] || { echo 'CacheDir parent is not 0755.' >&2; exit 1; }
    copied_user=$(sed -n 's/^[[:space:]]*DownloadUser[[:space:]]*=[[:space:]]*\([^#[:space:]]\+\).*/\1/p' "$WORKDIR/pacman.conf" | tail -n1)
    [[ $copied_user == "$download_user" ]] || { echo 'Preflight config changed DownloadUser.' >&2; exit 1; }
    copied_sandbox_policy=$(active_sandbox_policy "$WORKDIR/pacman.conf")
    [[ $copied_sandbox_policy == "$source_sandbox_policy" ]] || {
        echo 'Preflight config changed the source pacman sandbox policy.' >&2
        printf 'SOURCE SANDBOX POLICY:\n%s\nCOPIED SANDBOX POLICY:\n%s\n' \
            "${source_sandbox_policy:-<none>}" "${copied_sandbox_policy:-<none>}" >&2
        exit 1
    }

    sync_log="$WORKDIR/pacman-sync.log"
    if ! pacman --config "$WORKDIR/pacman.conf" \
        --dbpath "$WORKDIR/db" --cachedir "$WORKDIR/cache" \
        -Sy --noconfirm 2> >(tee "$sync_log" >&2); then
        if grep -Eiq 'landlock|seccomp|sandbox|operation not permitted' "$sync_log"; then
            echo 'PACKAGE-PERMISSION LOGIC: NOT PROVEN' >&2
            echo 'PACMAN SANDBOX IN HOSTED CONTAINER: BLOCKED' >&2
        else
            echo 'PACKAGE-PERMISSION LOGIC: FAIL' >&2
            echo 'PACMAN SANDBOX IN HOSTED CONTAINER: UNKNOWN' >&2
        fi
        exit 1
    fi
    echo 'PACKAGE-PERMISSION LOGIC: PASS'
    echo 'PACMAN SANDBOX IN HOSTED CONTAINER: PASS'

    # Resolve the complete transaction.  Do not infer availability from the
    # printed target set: an Arch container may already have some explicit
    # targets installed, and pacman is allowed to omit them from output.
    pacman --config "$WORKDIR/pacman.conf" \
        --dbpath "$WORKDIR/db" --cachedir "$WORKDIR/cache" \
        -Sp --noconfirm --print-format '%n' -- "${PACKAGES[@]}" > "$WORKDIR/packages.txt"

    # Independently prove that every explicit support-contract package exists
    # in the just-synchronized repositories.
    for package in "${PACKAGES[@]}"; do
        pacman --config "$WORKDIR/pacman.conf" \
            --dbpath "$WORKDIR/db" --cachedir "$WORKDIR/cache" \
            -Si -- "$package" >/dev/null || {
            echo "Explicit $PROFILE package is unavailable: $package" >&2
            exit 1
        }
    done

    printf 'Arch pacman preflight: PASS (%s, DownloadUser=%s, %s explicit packages)\n' \
        "$PROFILE" "$download_user" "${#PACKAGES[@]}"
    cleanup_workspace
done
