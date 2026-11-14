#!/usr/bin/env python3
"""Lists the failed tests of a `flutter test --file-reporter json:<path>` run.

Usage: scripts/summarize_test_failures.py <report.json>

Prints each failing test with its file and error to the log, adds a GitHub
annotation per failure and appends a section to $GITHUB_STEP_SUMMARY. The
`github` reporter CI uses by default folds these details into a collapsed
group. Always exits 0, whatever the report holds (missing, truncated, odd
shapes), so the test step alone decides whether a job fails.
"""
import json
import os
import sys
from urllib.parse import unquote, urlparse

MAX_ERROR_LINES = 40
MAX_MESSAGE_CHARS = 4000
MAX_LISTED = 50
MAX_ANNOTATIONS = 10


def relative(path):
    try:
        return os.path.relpath(path) if os.path.isabs(path) else path
    except ValueError:
        return path


def escape_message(text):
    return text.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")


def escape_property(text):
    return escape_message(text).replace(":", "%3A").replace(",", "%2C")


def text_of(value):
    return value if isinstance(value, str) else ("" if value is None else str(value))


def key_of(value):
    return value if isinstance(value, (int, str)) else None


def dict_of(value):
    return value if isinstance(value, dict) else {}


def shorten(error):
    lines = error.rstrip().splitlines()
    shown = "\n".join(lines[:MAX_ERROR_LINES])
    if len(lines) > MAX_ERROR_LINES:
        shown += "\n... (%d more lines)" % (len(lines) - MAX_ERROR_LINES)
    if len(shown) > MAX_MESSAGE_CHARS:
        shown = shown[:MAX_MESSAGE_CHARS] + "\n... (truncated)"
    return shown


def read_events(path):
    suites, tests, failures = {}, {}, []
    with open(path, encoding="utf-8", errors="replace") as report:
        for line in report:
            try:
                event = json.loads(line)
            except ValueError:
                continue
            if not isinstance(event, dict):
                continue
            kind = event.get("type")
            if kind == "suite":
                suite = dict_of(event.get("suite"))
                suites[key_of(suite.get("id"))] = text_of(suite.get("path"))
            elif kind == "testStart":
                test = dict_of(event.get("test"))
                url = text_of(test.get("url"))
                path = unquote(urlparse(url).path) if url else suites.get(key_of(test.get("suiteID")), "")
                if key_of(test.get("id")) is None:
                    continue
                tests[test["id"]] = (text_of(test.get("name")), relative(path), test.get("line"))
            elif kind == "error":
                failures.append((key_of(event.get("testID")), text_of(event.get("error"))))
    return tests, failures


def run(argv):
    if len(argv) != 2 or not os.path.isfile(argv[1]):
        return
    tests, failures = read_events(argv[1])
    if not failures:
        return

    summary = ["### Failed tests", ""]
    print("\n==== %d failing test error(s) ====" % len(failures))
    for index, (test_id, error) in enumerate(failures):
        if index >= MAX_LISTED:
            break
        name, path, line = tests.get(test_id, ("(unknown test)", "", None))
        if name.startswith("loading "):
            name = "loading " + relative(name[len("loading "):])
        shown = shorten(error)
        print("\nFAILED %s: %s" % (path, name))
        print("  " + shown.replace("\n", "\n  "))
        if index < MAX_ANNOTATIONS:
            location = "file=%s," % escape_property(path) if path else ""
            if isinstance(line, int) and line > 0:
                location += "line=%d," % line
            print("::error %stitle=%s::%s" % (location, escape_property(name), escape_message(shown)))
        summary += ["**`%s`** `%s`" % (path, name.replace("\n", " ")), "```", shown, "```", ""]
    if len(failures) > MAX_LISTED:
        more = "%d more" % (len(failures) - MAX_LISTED)
        print("\n... %s" % more)
        summary += ["... %s" % more, ""]

    target = os.environ.get("GITHUB_STEP_SUMMARY")
    if target:
        with open(target, "a", encoding="utf-8", errors="replace") as out:
            out.write("\n".join(summary) + "\n")


def main(argv):
    try:
        sys.stdout.reconfigure(errors="backslashreplace")
        run(argv)
    except BaseException as error:
        try:
            print("could not summarize the test report: %s" % type(error).__name__)
        except BaseException:
            pass
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
