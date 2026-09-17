#!/usr/bin/env python3
"""Fail-closed validator for SKITTLES stable release sign-off."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
import re
import sys

EXPECTED_RELEASE = "1.0.0"
ALLOWED_STATUSES = {"PASS", "DEFERRED", "NOT TESTED", "FAIL", "BLOCKED", "WARN"}
REQUIRED_KEYS = {
    "clean_install",
    "cold_boot",
    "warm_reboot",
    "linux_boot",
    "linux_lts_boot",
    "luks_unlock_linux",
    "luks_unlock_linux_lts",
    "plasma_wayland_linux",
    "plasma_wayland_linux_lts",
    "nvidia_linux",
    "nvidia_linux_lts",
    "vulkan_linux",
    "vulkan_linux_lts",
    "ethernet_dhcp_dns_linux",
    "ethernet_dhcp_dns_linux_lts",
    "nftables_linux",
    "nftables_linux_lts",
    "audio_usb_linux",
    "audio_usb_linux_lts",
    "suspend_resume_linux",
    "suspend_resume_linux_lts",
    "full_system_update",
    "post_update_boot_linux",
    "post_update_boot_linux_lts",
    "doctor_linux",
    "doctor_linux_lts",
    "steam",
    "proton",
    "lib32_nvidia_vulkan",
    "gamemode",
    "mangohud",
    "ntsync",
    "recovery_unlock_mount_chroot",
    "recovery_reinstall_kernels_nvidia",
    "recovery_rebuild_initramfs",
    "recovery_repair_grub",
    "recovery_boot_linux_lts",
    "recovery_clean_unmount_close",
    "performance_measurements",
}
DEFERRED_KEYS = {
    "recovery_unlock_mount_chroot",
    "recovery_reinstall_kernels_nvidia",
    "recovery_rebuild_initramfs",
    "recovery_repair_grub",
    "recovery_boot_linux_lts",
    "recovery_clean_unmount_close",
    "performance_measurements",
}


def die(message: str) -> "NoReturn":
    print(f"Stable release blocked: {message}", file=sys.stderr)
    raise SystemExit(1)


def load_signoff(path: Path) -> dict:
    try:
        raw = path.read_text(encoding="utf-8")
    except OSError as exc:
        die(f"cannot read sign-off source {path}: {exc}")
    try:
        data = json.loads(raw)
    except json.JSONDecodeError as exc:
        die(f"malformed sign-off JSON: {exc}")
    if not isinstance(data, dict):
        die("sign-off root must be an object")
    return data


def validate(signoff_path: Path, performance_path: Path, notes_path: Path) -> None:
    data = load_signoff(signoff_path)
    if data.get("schema") != 1:
        die("sign-off schema must equal 1")
    if data.get("release") != EXPECTED_RELEASE:
        die(f"sign-off release must equal {EXPECTED_RELEASE}")

    required = data.get("required")
    if not isinstance(required, dict):
        die("required sign-off map is missing or malformed")
    keys = set(required)
    missing = sorted(REQUIRED_KEYS - keys)
    extra = sorted(keys - REQUIRED_KEYS)
    if missing:
        die("required sign-off key(s) missing: " + ", ".join(missing))
    if extra:
        die("unknown required sign-off key(s): " + ", ".join(extra))

    for key in sorted(REQUIRED_KEYS):
        status = required.get(key)
        if status not in ALLOWED_STATUSES:
            die(f"{key} has invalid or empty status: {status!r}")
        if status == "DEFERRED" and key in DEFERRED_KEYS:
            continue
        if status != "PASS":
            allowed = "PASS or DEFERRED" if key in DEFERRED_KEYS else "PASS"
            die(f"{key} must be {allowed}, found {status}")

    evidence = data.get("evidence")
    if not isinstance(evidence, dict):
        die("evidence map is missing or malformed")
    evidence_keys = set(evidence)
    expected_evidence_keys = {"performance_file", "performance_sha256"}
    if evidence_keys != expected_evidence_keys:
        missing_evidence = sorted(expected_evidence_keys - evidence_keys)
        extra_evidence = sorted(evidence_keys - expected_evidence_keys)
        details = []
        if missing_evidence:
            details.append("missing: " + ", ".join(missing_evidence))
        if extra_evidence:
            details.append("unknown: " + ", ".join(extra_evidence))
        die("evidence key mismatch (" + "; ".join(details) + ")")
    expected_perf = Path(str(evidence.get("performance_file", "")))
    if expected_perf.as_posix() != "docs/PERFORMANCE.md":
        die("performance evidence path must be docs/PERFORMANCE.md")
    if (signoff_path.parent / expected_perf).resolve() != performance_path.resolve():
        die("performance evidence path does not match the sign-off source")
    expected_sha = evidence.get("performance_sha256")
    if required["performance_measurements"] == "PASS":
        try:
            perf_bytes = performance_path.read_bytes()
        except OSError as exc:
            die(f"cannot read performance evidence {performance_path}: {exc}")
        if not isinstance(expected_sha, str) or not re.fullmatch(r"[0-9a-f]{64}", expected_sha):
            die("performance_sha256 is missing or malformed")
        actual_sha = hashlib.sha256(perf_bytes).hexdigest()
        if actual_sha != expected_sha:
            die("performance evidence SHA-256 does not match sign-off source")
    elif expected_sha is not None:
        die("performance_sha256 must be null when performance measurements are DEFERRED")

    try:
        notes = notes_path.read_text(encoding="utf-8")
    except OSError as exc:
        die(f"cannot read stable release notes {notes_path}: {exc}")
    if "DRAFT:" in notes:
        die("stable release notes still contain DRAFT marker")


def main(argv: list[str]) -> int:
    if len(argv) != 4:
        print(
            "usage: check_release_signoff.py SIGNOFF_JSON PERFORMANCE_MD STABLE_NOTES_MD",
            file=sys.stderr,
        )
        return 2
    validate(Path(argv[1]), Path(argv[2]), Path(argv[3]))
    print("Stable release sign-off: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
