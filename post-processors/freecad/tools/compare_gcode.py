#!/usr/bin/env python3
"""Semantically compare two G-code files from the MillenniumOS posts.

Textual diff is useless here: header timestamps, comment placement and
whitespace differ by design. This normalises those away and compares the
motion/command stream, so a clean run means the two posts are behaviourally
equivalent on that job.

Usage:
    python3 compare_gcode.py legacy.gcode machine.gcode
    python3 compare_gcode.py legacy.gcode machine.gcode --keep-comments
"""

import argparse
import re
import sys
from itertools import zip_longest

# Parameters whose value we compare numerically rather than textually.
NUMERIC = set("XYZABCFIJKPQRSTHL")

TOKEN = re.compile(r"([A-Z])(-?\d*\.?\d+)")


def load(path, keep_comments=False):
    """Read a file into a list of normalised command records."""
    out = []
    for raw in open(path, encoding="utf-8"):
        line = raw.strip()
        if not line:
            continue
        if line.startswith("(") or line.startswith(";"):
            if keep_comments:
                out.append(("comment", line, raw.rstrip("\n")))
            continue
        # Strip trailing comments
        line = re.sub(r"\(.*?\)", "", line)
        line = line.split(";", 1)[0].strip()
        if not line:
            continue
        # Drop line numbers
        line = re.sub(r"^N\d+\s*", "", line)
        out.append(("cmd", normalise(line), raw.rstrip("\n")))
    return out


def normalise(line):
    """Return a canonical, order-independent representation of one command."""
    parts = line.split()
    if not parts:
        return ""

    word = parts[0]
    params = {}

    for token in parts[1:]:
        m = TOKEN.fullmatch(token)
        if m:
            letter, value = m.group(1), m.group(2)
            if letter in NUMERIC:
                # Round to a common precision so 141.5 == 141.500
                params[letter] = f"{float(value):.4f}"
            else:
                params[letter] = value
        else:
            # Strings such as S"tool name" -- keep verbatim
            params[token[0]] = token[1:]

    body = " ".join(f"{k}{params[k]}" for k in sorted(params))
    return f"{word} {body}".strip()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("legacy")
    ap.add_argument("machine")
    ap.add_argument("--keep-comments", action="store_true")
    ap.add_argument("--context", type=int, default=2)
    args = ap.parse_args()

    a = load(args.legacy, args.keep_comments)
    b = load(args.machine, args.keep_comments)

    print(f"legacy : {len(a)} commands  ({args.legacy})")
    print(f"machine: {len(b)} commands  ({args.machine})")
    print()

    mismatches = 0
    for i, (x, y) in enumerate(zip_longest(a, b)):
        xn = x[1] if x else "<end of file>"
        yn = y[1] if y else "<end of file>"
        if xn == yn:
            continue

        mismatches += 1
        if mismatches > 40:
            print("... further differences suppressed")
            break

        print(f"line {i}:")
        print(f"  legacy : {x[2] if x else '<none>'}")
        print(f"  machine: {y[2] if y else '<none>'}")
        print()

    if mismatches == 0:
        print("No semantic differences.")
        return 0

    print(f"{mismatches} differing command(s).")
    return 1


if __name__ == "__main__":
    sys.exit(main())
