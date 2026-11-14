#!/usr/bin/env python3
"""Lists the failed tests of a `flutter test --file-reporter json:<path>` run.

Usage: scripts/summarize_test_failures.py <report.json>

Prints each failing test with its file and error to the log, adds a GitHub
annotation per failure and appends a section to $GITHUB_STEP_SUMMARY. The
`github` reporter CI uses by default folds these details into a collapsed
group. Always exits 0 (a missing or empty report is fine), so the test step
alone decides whether a job fails.
"""
import json
import os
import sys
from urllib.parse import unquote, urlparse

MAX_ERROR_LINES = 40


def relative(path):
    return os.path.relpath(path) if os.path.isabs(path) else path


def main(argv):
    if len(argv) != 2 or not os.path.exists(argv[1]):
        return 0
    suites, tests, failures = {}, {}, []
    with open(argv[1], encoding="utf-8", errors="replace") as report:
        for line in report:
            try:
                event = json.loads(line)
            except ValueError:
                continue
            if not isinstance(event, dict):
                continue
            kind = event.get("type")
            if kind == "suite":
                suites[event["suite"]["id"]] = event["suite"].get("path", "")
            elif kind == "testStart":
                test = event["test"]
                url = test.get("url") or ""
                path = unquote(urlparse(url).path) if url else suites.get(test.get("suiteID"), "")
                tests[test["id"]] = (test.get("name", ""), relative(path), test.get("line"))
            elif kind == "error":
                failures.append((event.get("testID"), event.get("error", ""), event.get("stackTrace", "")))
    if not failures:
        return 0

    summary = ["### Failed tests", ""]
    print("\n==== %d failing test error(s) ====" % len(failures))
    for test_id, error, _ in failures:
        name, path, line = tests.get(test_id, ("(unknown test)", "", None))
        if name.startswith("loading "):
            name = "loading " + relative(name[len("loading "):])
        error = error.rstrip()
        lines = error.splitlines()
        shown = "\n".join(lines[:MAX_ERROR_LINES])
        if len(lines) > MAX_ERROR_LINES:
            shown += "\n... (%d more lines)" % (len(lines) - MAX_ERROR_LINES)
        print("\nFAILED %s: %s" % (path, name))
        print("  " + shown.replace("\n", "\n  "))
        location = "file=%s," % path if path else ""
        if line:
            location += "line=%s," % line
        message = shown.replace("%", "%25").replace("\r", "").replace("\n", "%0A")
        title = name.replace("%", "%25").replace(",", "%2C").replace(":", "%3A")
        print("::error %stitle=%s::%s" % (location, title, message))
        summary += ["**`%s`** `%s`" % (path, name), "```", shown, "```", ""]

    target = os.environ.get("GITHUB_STEP_SUMMARY")
    if target:
        with open(target, "a", encoding="utf-8") as out:
            out.write("\n".join(summary) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
