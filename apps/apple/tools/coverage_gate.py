"""Coverage gate for one Swift package, from `swift test`'s llvm-cov JSON.

Measures only the package's Sources/, minus excluded files, so the tests do
not cover themselves. Usage:

    python3 tools/coverage_gate.py --codecov PATH --package OmakaseStore --threshold 90 [--exclude View.swift]
"""

import argparse
import json
import sys
from pathlib import Path


def covered_lines(codecov: dict, package: str, excludes: list[str]) -> tuple[int, int]:
    """(covered, total) line counts over the package's Sources/ files."""
    covered = total = 0
    for record in codecov["data"][0]["files"]:
        name = record["filename"]
        if f"/{package}/Sources/" not in name or any(name.endswith(end) for end in excludes):
            continue
        covered += record["summary"]["lines"]["covered"]
        total += record["summary"]["lines"]["count"]
    return covered, total


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--codecov", type=Path, required=True)
    parser.add_argument("--package", required=True)
    parser.add_argument("--threshold", type=float, required=True)
    parser.add_argument("--exclude", action="append", default=[])
    args = parser.parse_args(argv)
    covered, total = covered_lines(json.loads(args.codecov.read_text()), args.package, args.exclude)
    percent = 100.0 * covered / total if total else 0.0
    print(f"{args.package}: {percent:.1f}% of {total} lines; gate {args.threshold:g}%, margin {percent - args.threshold:.1f}")
    return 0 if percent >= args.threshold else 1


if __name__ == "__main__":
    sys.exit(main())
