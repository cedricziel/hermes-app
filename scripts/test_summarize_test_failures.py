import json
import os
import subprocess
import sys
import tempfile
import unittest

SCRIPT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "summarize_test_failures.py")


def suite(i=1, path="/repo/test/a_test.dart"):
    return {"type": "suite", "suite": {"id": i, "path": path}}


def start(i, name, line=3, url="file:///repo/test/a_test.dart"):
    return {"type": "testStart", "test": {"id": i, "name": name, "suiteID": 1, "line": line, "url": url}}


def error(i, text, stack=""):
    return {"type": "error", "testID": i, "error": text, "stackTrace": stack}


class SummarizeTest(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.addCleanup(self.dir.cleanup)
        self.summary = os.path.join(self.dir.name, "summary.md")

    def report(self, events, raw=None):
        path = os.path.join(self.dir.name, "report.json")
        data = raw if raw is not None else "".join(json.dumps(e) + "\n" for e in events).encode()
        with open(path, "wb") as f:
            f.write(data)
        return path

    def run_script(self, path):
        env = dict(os.environ, GITHUB_STEP_SUMMARY=self.summary)
        proc = subprocess.run(
            [sys.executable, "-I", SCRIPT, path], capture_output=True, env=env
        )
        self.assertEqual(proc.returncode, 0, proc.stderr)
        out = proc.stdout.decode("utf-8", "replace")
        try:
            with open(self.summary, encoding="utf-8", errors="replace") as f:
                summ = f.read()
        except OSError:
            summ = ""
        return out, summ

    def annotations(self, out):
        return [l for l in out.splitlines() if l.startswith("::error ")]

    def test_assertion_failure(self):
        out, summ = self.run_script(self.report([suite(), start(2, "adds up"), error(2, "Expected: <1>\n  Actual: <2>")]))
        self.assertIn("FAILED", out)
        self.assertIn("adds up", out)
        self.assertEqual(len(self.annotations(out)), 1)
        self.assertIn("title=adds up", out)
        self.assertIn("### Failed tests", summ)

    def test_error_with_stack(self):
        out, _ = self.run_script(self.report([suite(), start(2, "t"), error(2, "Bad state", "#0 main (a.dart:1)")]))
        self.assertIn("Bad state", out)

    def test_load_failure(self):
        out, _ = self.run_script(self.report([suite(), start(2, "loading /repo/test/a_test.dart", url=""), error(2, "Failed to load")]))
        self.assertIn("loading ", out)
        self.assertIn("Failed to load", out)

    def test_special_characters_in_test_name(self):
        out, _ = self.run_script(self.report([suite(), start(2, "a\nb 100% c:d,e"), error(2, "x\ny 5%")]))
        notes = self.annotations(out)
        self.assertEqual(len(notes), 1)
        self.assertIn("title=a%0Ab 100%25 c%3Ad%2Ce", notes[0])
        self.assertTrue(notes[0].endswith("::x%0Ay 5%25"))

    def test_lone_surrogate(self):
        raw = (json.dumps(error(2, "bad \ud800 text")) + "\n").encode("ascii")
        out, _ = self.run_script(self.report([], raw=json.dumps(start(2, "t")).encode() + b"\n" + raw))
        self.assertIn("bad", out)

    def test_oversized_message(self):
        out, summ = self.run_script(self.report([suite(), start(2, "t"), error(2, "x" * 100000)]))
        self.assertIn("... (truncated)", out)
        self.assertLess(len(out), 10000)
        self.assertLess(len(summ), 10000)

    def test_many_failures_are_bounded(self):
        events = [suite()]
        for i in range(2, 202):
            events += [start(i, "t%d" % i), error(i, "boom")]
        out, summ = self.run_script(self.report(events))
        self.assertEqual(len(self.annotations(out)), 10)
        self.assertEqual(out.count("FAILED "), 50)
        self.assertIn("150 more", out)
        self.assertIn("150 more", summ)
        self.assertEqual(summ.count("**`"), 50)

    def test_unexpected_event_shapes(self):
        events = [
            {"type": "suite", "suite": {}},
            {"type": "suite"},
            {"type": "testStart", "test": {}},
            {"type": "testStart", "test": "x"},
            {"type": "testStart"},
            {"type": "error"},
            {"type": "error", "testID": [1], "error": 5},
            [1, 2],
        ]
        out, _ = self.run_script(self.report(events))
        self.assertIn("(unknown test)", out)

    def test_truncated_last_line(self):
        good = json.dumps(error(2, "kept")).encode()
        out, _ = self.run_script(self.report([], raw=good + b'\n{"type":"er'))
        self.assertIn("kept", out)

    def test_empty_report(self):
        out, _ = self.run_script(self.report([], raw=b""))
        self.assertEqual(out, "")

    def test_zero_failures(self):
        out, summ = self.run_script(self.report([suite(), start(2, "ok")]))
        self.assertEqual(out, "")
        self.assertEqual(summ, "")

    def test_missing_file(self):
        out, _ = self.run_script(os.path.join(self.dir.name, "nope.json"))
        self.assertEqual(out, "")

    def test_directory_path(self):
        out, _ = self.run_script(self.dir.name)
        self.assertNotIn("Traceback", out)


if __name__ == "__main__":
    unittest.main()
