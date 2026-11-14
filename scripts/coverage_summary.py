#!/usr/bin/env python3
"""Merge the test shards' lcov files and summarize line coverage.

usage: [EXPECTED_SHARDS=n] coverage_summary.py <merged.lcov> <summary.md> <shard.lcov>...

Each shard compiles its own test files, so one source file can appear in
several shards: the hit counts of its lines are added. Generated code is
left out (packages/hermes_api/**, *.g.dart). The summary lists the total and
the line coverage per top-level directory under lib/src/, lowest first.
"""
import fnmatch
import os
import sys
from collections import defaultdict

EXCLUDED = ("packages/hermes_api/*", "*.g.dart")


def excluded(path):
    return any(fnmatch.fnmatch(path, pattern) for pattern in EXCLUDED)


def merge(texts):
    """Returns {source file: {line number: hits}} summed over the inputs."""
    files = defaultdict(lambda: defaultdict(int))
    for text in texts:
        current = None
        for raw in text.splitlines():
            line = raw.strip()
            if line.startswith("SF:"):
                path = line[3:].replace("\\", "/")
                current = None if excluded(path) else files[path]
            elif line == "end_of_record":
                current = None
            elif line.startswith("DA:") and current is not None:
                fields = line[3:].split(",")
                try:
                    number, hits = int(fields[0]), int(fields[1])
                except (IndexError, ValueError):
                    continue
                current[number] += hits
    return files


def write_lcov(files, out):
    for path in sorted(files):
        lines = files[path]
        out.write(f"SF:{path}\n")
        for number in sorted(lines):
            out.write(f"DA:{number},{lines[number]}\n")
        out.write(f"LF:{len(lines)}\n")
        out.write(f"LH:{sum(1 for h in lines.values() if h > 0)}\n")
        out.write("end_of_record\n")


def totals(lines_by_file):
    found = sum(len(lines) for lines in lines_by_file)
    hit = sum(1 for lines in lines_by_file for h in lines.values() if h > 0)
    return hit, found


def percent(hit, found):
    return "n/a" if found == 0 else f"{100 * hit / found:.1f}%"


def summarize(files, shards=None, expected=None):
    groups = defaultdict(list)
    for path, lines in files.items():
        parts = path.split("/")
        if len(parts) > 3 and parts[:2] == ["lib", "src"]:
            groups[parts[2]].append(lines)
        elif len(parts) == 3 and parts[:2] == ["lib", "src"]:
            groups["(files directly in lib/src)"].append(lines)
        elif len(parts) > 1 and parts[0] == "lib":
            groups["(lib/main.dart)"].append(lines)
    hit, found = totals(files.values())
    rows = []
    for name, group in groups.items():
        g_hit, g_found = totals(group)
        rows.append((g_hit / g_found if g_found else 1.0, name, g_hit, g_found))
    rows.sort()
    out = ["## Test coverage", ""]
    if shards is not None:
        of = f" of {expected}" if expected else ""
        note = "" if not expected or shards == expected else " (partial: some shards are missing)"
        out += [f"Built from {shards}{of} shard coverage files{note}.", ""]
    out.append(f"Total line coverage: **{percent(hit, found)}** ({hit} of {found} lines, {len(files)} files)")
    out += ["", "| Directory | Coverage | Lines hit | Lines |", "| --- | ---: | ---: | ---: |"]
    for _, name, g_hit, g_found in rows:
        out.append(f"| `{name}` | {percent(g_hit, g_found)} | {g_hit} | {g_found} |")
    return "\n".join(out) + "\n"


def main(argv):
    if len(argv) < 4:
        print(__doc__, file=sys.stderr)
        return 64
    texts = []
    for path in argv[3:]:
        with open(path, encoding="utf-8") as handle:
            texts.append(handle.read())
    files = merge(texts)
    with open(argv[1], "w", encoding="utf-8") as out:
        write_lcov(files, out)
    with open(argv[2], "w", encoding="utf-8") as out:
        expected = os.environ.get("EXPECTED_SHARDS", "")
        out.write(summarize(files, len(texts), int(expected) if expected.isdigit() else None))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
