#!/usr/bin/env python3
"""Read-only current-tree hygiene checks for SKITTLES CI."""

from __future__ import annotations

from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
PATTERNS = {
    "private-key header": re.compile(rb"-----BEGIN (?:RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----"),
    "GitHub token": re.compile(rb"gh[pousr]_[A-Za-z0-9]{20,}"),
    "AWS access key": re.compile(rb"AKIA[0-9A-Z]{16}"),
    "credential-bearing URL": re.compile(rb"https?://[^\s/:]+:[^\s/@]+@"),
}
JUNK_NAMES = {".DS_Store"}
JUNK_SUFFIXES = {".pyc", ".swp", ".swo"}


def tracked_files() -> list[Path]:
    proc = subprocess.run(
        ["git", "ls-files", "-z"], cwd=ROOT, capture_output=True, check=True
    )
    return [ROOT / item.decode("utf-8") for item in proc.stdout.split(b"\0") if item]


def main() -> int:
    failures: list[str] = []
    files = tracked_files()
    for path in files:
        rel = path.relative_to(ROOT).as_posix()
        name = path.name
        if name in JUNK_NAMES or path.suffix in JUNK_SUFFIXES or name.endswith("~"):
            failures.append(f"tracked junk file: {rel}")
            continue
        try:
            data = path.read_bytes()
        except OSError as exc:
            failures.append(f"cannot read tracked file {rel}: {exc}")
            continue
        if b"\0" in data:
            failures.append(f"tracked NUL/binary-like file: {rel}")
        for label, pattern in PATTERNS.items():
            if pattern.search(data):
                failures.append(f"{label} pattern in tracked file: {rel}")

    if failures:
        for failure in failures:
            print(f"Repository hygiene FAIL: {failure}", file=sys.stderr)
        return 1
    print(f"Repository hygiene: PASS ({len(files)} tracked files scanned)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
