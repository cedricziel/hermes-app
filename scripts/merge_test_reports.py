#!/usr/bin/env python3
"""Joins the JSON reports of several `flutter test --file-reporter json:` runs.

Usage: scripts/merge_test_reports.py <merged.json> <part.json>...

`scripts/test-shard.sh` runs the catalog test in several processes, each
writing its own report. Every run numbers its suites, groups and tests from
zero, so the ids of each part are moved into a range of their own; without
that `scripts/summarize_test_failures.py` would name a failure of one part
after a test of another. Lines that are not JSON objects are dropped. A
missing part is skipped. Always exits 0: the report is for reading a failure,
never the reason a job fails.
"""

import json
import os
import sys

STEP = 10_000_000


def moved(value, offset):
    return (
        value + offset
        if isinstance(value, int) and not isinstance(value, bool)
        else value
    )


def shift(event, offset):
    """Returns [event] with every suite, group and test id moved by [offset]."""
    for key in ("testID", "suiteID", "groupID", "parentID"):
        if key in event:
            event[key] = moved(event[key], offset)
    for key in ("suite", "group", "test"):
        inner = event.get(key)
        if not isinstance(inner, dict):
            continue
        for field in ("id", "suiteID", "parentID"):
            if field in inner:
                inner[field] = moved(inner[field], offset)
        if isinstance(inner.get("groupIDs"), list):
            inner["groupIDs"] = [moved(i, offset) for i in inner["groupIDs"]]
    return event


def merge(paths, out):
    for index, path in enumerate(paths):
        if not os.path.isfile(path):
            continue
        with open(path, encoding="utf-8", errors="replace") as part:
            for line in part:
                try:
                    event = json.loads(line)
                except ValueError:
                    continue
                if isinstance(event, dict):
                    out.write(json.dumps(shift(event, index * STEP)) + "\n")


def main(argv):
    if len(argv) < 3:
        print(__doc__, file=sys.stderr)
        return 0
    with open(argv[1], "w", encoding="utf-8") as out:
        merge(argv[2:], out)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
