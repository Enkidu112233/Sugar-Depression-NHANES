"""Verify the distributed package; optionally verify manually downloaded XPT files.

Usage: python tools/verify_package.py [--raw]
Python 3.8 or later; standard library only. No network access or file modification.
"""
from pathlib import Path
import argparse
import csv
import hashlib

def digest(path):
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--raw", action="store_true", help="also check all 18 raw input files")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    errors = []
    checked = 0
    for line in (root / "SHA256SUMS.txt").read_text(encoding="utf-8").splitlines():
        expected, relative = line.split("  ", 1)
        target = root / relative
        if not target.is_file():
            errors.append("Missing: " + relative)
        elif digest(target) != expected:
            errors.append("Changed: " + relative)
        checked += 1
    if args.raw:
        with (root / "data/raw_manifest.csv").open(encoding="utf-8", newline="") as stream:
            for row in csv.DictReader(stream):
                target = root / row["destination"]
                if not target.is_file():
                    errors.append("Missing raw input: " + row["destination"])
                elif target.stat().st_size != int(row["reference_bytes"]) or digest(target) != row["reference_sha256"]:
                    errors.append("Raw version differs from author reference: " + row["destination"])
                checked += 1
    for error in errors:
        print(error)
    print(str(checked) + " files checked; " + str(len(errors)) + " differences.")
    return 1 if errors else 0

if __name__ == "__main__":
    raise SystemExit(main())
