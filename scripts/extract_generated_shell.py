#!/usr/bin/env python3
"""Extract one literal shell heredoc embedded in skittles-installer.sh."""
from pathlib import Path
import argparse
import sys

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "skittles-installer.sh"


def extract(tag: str) -> str:
    if not tag or any(ch not in "ABCDEFGHIJKLMNOPQRSTUVWXYZ_0123456789" for ch in tag):
        raise ValueError("invalid heredoc tag")
    lines = SCRIPT.read_text(encoding="utf-8").splitlines(keepends=True)
    marker = f"<<'{tag}'"
    start = None
    for i, line in enumerate(lines):
        if marker in line:
            if start is not None:
                raise ValueError(f"multiple heredocs found for {tag}")
            start = i + 1
    if start is None:
        raise ValueError(f"heredoc not found: {tag}")
    for i in range(start, len(lines)):
        if lines[i].rstrip("\r\n") == tag:
            return "".join(lines[start:i])
    raise ValueError(f"unterminated heredoc: {tag}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("tag", choices=("CHROOT_SCRIPT", "DOCTOR_SCRIPT"))
    args = parser.parse_args()
    try:
        sys.stdout.write(extract(args.tag))
    except ValueError as exc:
        print(exc, file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
