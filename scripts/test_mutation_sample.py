"""Tests for scripts/mutation_sample.py: a tiny repo, a fake `flutter` on PATH."""

import contextlib
import io
import json
import os
import stat
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import mutation_sample as ms  # noqa: E402

# Stands in for `flutter test`: reads lib/a.dart in the working directory and
# writes the JSON report the runner asks for. "MUT_FAIL" makes test/a_test.dart
# fail with a matcher mismatch, "MUT_FAIL_B" also fails test/b_test.dart,
# "MUT_BREAK" is a compile error, "BASE_RED" fails with no mutant at all. Every
# call appends the file's text to calls.log.
FAKE_FLUTTER = r"""#!/usr/bin/env python3
import json, sys
args = sys.argv[1:]
report = [a for a in args if a.startswith("json:")][0][5:]
tests = [a for a in args if a.endswith("_test.dart")]
src = open("lib/a.dart").read()
if any(a.startswith("--coverage-path=") for a in args):
    open("cov.log", "a").write(",".join(tests) + "\n")
else:
    open("calls.log", "a").write(repr(src) + "\n")
    open("runs.log", "a").write(",".join(tests) + "\n")
import os, subprocess, time
events = []
failing = []
code = None
open("backup.log", "a").write(str(os.path.exists(".dart_tool/mutation-sample/backup/lib/a.dart")) + "\n")
if "MUT_SLEEP" in src:
    child = subprocess.Popen(["sleep", "300"])
    open("child.pid", "w").write(str(child.pid))
    time.sleep(300)
if "MUT_NOTESTS" in src:
    print("No tests ran.")
    tests = []
    code = 79
if "MUT_ZERO" in src:
    tests = []
if "MUT_FEW" in src:
    tests = tests[:1]
if "MUT_LOADRUNTIME" in src:
    print("Failed to load test/a_test.dart")
    events.append({"suite": {"id": 0, "path": "test/a_test.dart"}})
    events.append({"type": "testStart", "test": {"id": 0, "name": "loading test/a_test.dart", "suiteID": 0}})
    events.append({"type": "error", "testID": 0, "error": "Bad state: boom while loading"})
    code = 1
    tests = []
if "MUT_BREAK" in src:
    print("lib/a.dart:1:1: Error: nope")
    events.append({"type": "error", "testID": 0, "error": "x"})
    events.insert(0, {"type": "testStart", "test": {"id": 0, "name": "loading test/a_test.dart", "suiteID": 0}})
    events.insert(0, {"suite": {"id": 0, "path": "test/a_test.dart"}})
else:
    if "MUT_FAIL" in src or "BASE_RED" in src:
        failing.append(tests[0])
    if "MUT_FAIL_B" in src:
        failing.append(tests[1])
    for i, t in enumerate(tests, start=1):
        events.append({"suite": {"id": i, "path": t}})
        events.append({"type": "testStart", "test": {"id": i, "name": "t", "suiteID": i}})
        if t in failing:
            events.append({"type": "error", "testID": i, "error": "Expected: 1\n  Actual: 2"})
        events.append({"type": "testDone", "testID": i, "result": "error" if t in failing else "success"})
with open(report, "w") as fh:
    for e in events:
        fh.write(json.dumps(e) + "\n")
for a in args:
    if a.startswith("--coverage-path="):
        default = {
            "test/a_test.dart": {"lib/a.dart": {"1": 1, "2": 0}},
            "test/b_test.dart": {"lib/a.dart": {"1": 0, "2": 1}},
        }
        cov = json.load(open("cov.json")) if os.path.exists("cov.json") else default
        with open(a.split("=", 1)[1], "w") as fh:
            for t in tests:
                for f, lines in cov.get(t, {}).items():
                    fh.write("SF:%s\n" % f)
                    for n, h in lines.items():
                        fh.write("DA:%s,%s\n" % (n, h))
                    fh.write("end_of_record\n")
sys.exit(code if code is not None else (1 if failing or "MUT_BREAK" in src else 0))
"""

ORIGINAL = "int f() => 1;\nint g() => 2;\n"


def sh(cwd, *cmd):
    subprocess.run(cmd, cwd=cwd, check=True, capture_output=True)


class Repo:
    """A git repo with one subject: lib/a.dart, two tests and a list."""

    def __init__(self, mutants=None, quick=None):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = self.tmp.name
        self.bin = os.path.join(self.dir, "bin")
        os.makedirs(self.bin)
        flutter = os.path.join(self.bin, "flutter")
        with open(flutter, "w") as fh:
            fh.write(FAKE_FLUTTER)
        os.chmod(flutter, os.stat(flutter).st_mode | stat.S_IXUSR)
        for p, text in {
            "lib/a.dart": ORIGINAL,
            "test/a_test.dart": "// a\n",
            "test/b_test.dart": "// b\n",
            ".gitignore": "calls.log\nbackup.log\nchild.pid\nbin/\nout/\n.dart_tool/\n"
            "cov.log\nruns.log\ncov.json\n",
        }.items():
            self.write(p, text)
        spec = {
            "subject": "sub",
            "tests": ["test/a_test.dart", "test/b_test.dart"],
            "quick_tests": quick or ["test/a_test.dart"],
            "mutants": mutants
            if mutants is not None
            else [
                {
                    "id": "m1",
                    "file": "lib/a.dart",
                    "old": "=> 1;",
                    "new": "=> 3; // MUT_FAIL",
                    "note": "caught",
                },
                {
                    "id": "m2",
                    "file": "lib/a.dart",
                    "old": "=> 2;",
                    "new": "=> 4;",
                    "note": "missed",
                },
            ],
        }
        self.write("tool/mutants/sub.json", json.dumps(spec))
        sh(self.dir, "git", "init", "-q")
        sh(self.dir, "git", "-c", "user.name=t", "-c", "user.email=t@t", "add", "-A")
        sh(
            self.dir,
            "git",
            "-c",
            "user.name=t",
            "-c",
            "user.email=t@t",
            "commit",
            "-qm",
            "init",
        )
        self._path = os.environ["PATH"]
        os.environ["PATH"] = self.bin + os.pathsep + self._path

    def write(self, rel, text):
        path = os.path.join(self.dir, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w") as fh:
            fh.write(text)

    def read(self, rel):
        with open(os.path.join(self.dir, rel)) as fh:
            return fh.read()

    def calls(self):
        p = os.path.join(self.dir, "calls.log")
        return self.read("calls.log").splitlines() if os.path.exists(p) else []

    def log_lines(self, name):
        p = os.path.join(self.dir, name)
        return self.read(name).splitlines() if os.path.exists(p) else []

    def commit(self, rel, text):
        self.write(rel, text)
        ident = ["-c", "user.name=t", "-c", "user.email=t@t"]
        sh(self.dir, "git", *ident, "add", rel)
        sh(self.dir, "git", *ident, "commit", "-qm", "next")

    def run(self, *args):
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = ms.main(
                ["--repo", self.dir, "--out", os.path.join(self.dir, "out"), *args]
            )
        return code, out.getvalue(), err.getvalue()

    def results(self):
        return json.loads(self.read("out/sub.json"))

    def close(self):
        os.environ["PATH"] = self._path
        self.tmp.cleanup()


class RepoCase(unittest.TestCase):
    def make(self, **kw):
        repo = Repo(**kw)
        self.addCleanup(repo.close)
        return repo


class ApplyAndRestore(RepoCase):
    def test_mutant_is_applied_for_the_run_and_then_restored(self):
        repo = self.make()
        code, _, _ = repo.run()
        self.assertEqual(code, 0)
        calls = repo.calls()
        self.assertEqual(len(calls), 3)  # baseline and two mutants
        self.assertEqual(calls[0], repr(ORIGINAL))
        self.assertIn("MUT_FAIL", calls[1])
        self.assertIn("=> 4;", calls[2])
        self.assertEqual(repo.read("lib/a.dart"), ORIGINAL)
        status = subprocess.run(
            ["git", "status", "--porcelain"],
            cwd=repo.dir,
            capture_output=True,
            text=True,
        ).stdout
        self.assertEqual(status.strip(), "")

    def test_restored_when_the_test_run_raises(self):
        repo = self.make()
        spec = ms.load_spec(os.path.join(repo.dir, "tool/mutants/sub.json"))
        calls = []

        def runner(repo_dir, tests, timeout, concurrency):
            calls.append(repo.read("lib/a.dart"))
            if len(calls) == 2:
                raise RuntimeError("flutter blew up")
            return {
                "secs": 1,
                "timed_out": False,
                "failures": [],
                "passed": 1,
                "exit_code": 0,
                "compile_error": False,
                "exit_tail": "",
            }

        with self.assertRaises(RuntimeError):
            ms.run_subject(
                repo.dir,
                spec,
                os.path.join(repo.dir, "out/sub.json"),
                log=lambda *_: None,
                runner=runner,
            )
        self.assertNotEqual(calls[1], ORIGINAL)
        self.assertEqual(repo.read("lib/a.dart"), ORIGINAL)

    def test_restored_on_ctrl_c(self):
        repo = self.make()
        spec = ms.load_spec(os.path.join(repo.dir, "tool/mutants/sub.json"))
        n = []

        def runner(repo_dir, tests, timeout, concurrency):
            n.append(1)
            if len(n) == 2:
                raise KeyboardInterrupt()
            return {
                "secs": 1,
                "timed_out": False,
                "failures": [],
                "passed": 1,
                "exit_code": 0,
                "compile_error": False,
                "exit_tail": "",
            }

        with self.assertRaises(KeyboardInterrupt):
            ms.run_subject(
                repo.dir,
                spec,
                os.path.join(repo.dir, "out/sub.json"),
                log=lambda *_: None,
                runner=runner,
            )
        self.assertEqual(repo.read("lib/a.dart"), ORIGINAL)

    def test_atexit_hook_restores_a_leftover(self):
        repo = self.make()
        path = os.path.join(repo.dir, "lib/a.dart")
        ms._mutated[path] = (ORIGINAL, os.path.join(repo.dir, "nobackup"))
        repo.write("lib/a.dart", "broken")
        ms.restore_all()
        self.assertEqual(repo.read("lib/a.dart"), ORIGINAL)
        self.assertEqual(ms._mutated, {})


class Rejections(RepoCase):
    def check_rejected(self, mutants, needle):
        repo = self.make(mutants=mutants)
        code, out, err = repo.run()
        self.assertEqual(code, 2)
        self.assertIn(needle, err)
        self.assertEqual(repo.calls(), [])  # flutter never ran
        self.assertEqual(repo.read("lib/a.dart"), ORIGINAL)

    def test_missing_old_is_rejected(self):
        self.check_rejected(
            [
                {
                    "id": "m1",
                    "file": "lib/a.dart",
                    "old": "nowhere",
                    "new": "x",
                    "note": "",
                }
            ],
            "occurs 0x",
        )

    def test_not_unique_old_is_rejected(self):
        self.check_rejected(
            [
                {
                    "id": "m1",
                    "file": "lib/a.dart",
                    "old": "int ",
                    "new": "num ",
                    "note": "",
                }
            ],
            "occurs 2x",
        )

    def test_missing_file_is_rejected(self):
        self.check_rejected(
            [{"id": "m1", "file": "lib/none.dart", "old": "x", "new": "y", "note": ""}],
            "does not exist",
        )

    def test_check_mode_reports_and_exits_nonzero(self):
        repo = self.make(
            mutants=[
                {
                    "id": "m1",
                    "file": "lib/a.dart",
                    "old": "nowhere",
                    "new": "x",
                    "note": "",
                }
            ]
        )
        code, out, _ = repo.run("--check")
        self.assertEqual(code, 1)
        self.assertIn("NOT OK", out)

    def test_check_mode_passes_a_good_list(self):
        code, out, _ = self.make().run("--check")
        self.assertEqual(code, 0)
        self.assertIn("2 mutants, ok", out)

    def test_dirty_mutated_file_is_refused(self):
        repo = self.make()
        repo.write("lib/a.dart", ORIGINAL + "// edited\n")
        code, _, err = repo.run()
        self.assertEqual(code, 2)
        self.assertIn("uncommitted", err)
        self.assertEqual(repo.calls(), [])
        self.assertEqual(repo.read("lib/a.dart"), ORIGINAL + "// edited\n")

    def test_red_baseline_stops_before_any_mutant(self):
        repo = self.make()
        repo.write("lib/a.dart", ORIGINAL + "// BASE_RED\n")
        sh(
            repo.dir,
            "git",
            "-c",
            "user.name=t",
            "-c",
            "user.email=t@t",
            "commit",
            "-qam",
            "red",
        )
        code, _, err = repo.run()
        self.assertEqual(code, 2)
        self.assertIn("baseline is not green", err)
        self.assertEqual(len(repo.calls()), 1)

    def test_unknown_only_id_is_rejected(self):
        code, _, err = self.make().run("--only", "zz")
        self.assertEqual(code, 2)
        self.assertIn("unknown mutant ids", err)


class Classification(unittest.TestCase):
    def test_error_kinds(self):
        self.assertEqual(
            ms.classify_error("Expected: 1\n Actual: 2"), "expect_mismatch"
        )
        self.assertEqual(
            ms.classify_error("Unhandled request GET /x"), "unexpected_request"
        )
        self.assertEqual(ms.classify_error("TimeoutException after 0:00:30"), "timeout")
        self.assertEqual(
            ms.classify_error("Null check operator used on a null value"),
            "uncaught_exception",
        )
        self.assertEqual(ms.classify_error("boom"), "other")
        self.assertEqual(ms.classify_error(None), "other")

    def run_of(self, **kw):
        base = {
            "secs": 1.0,
            "timed_out": False,
            "failures": [],
            "passed": 3,
            "exit_code": 0,
            "compile_error": False,
            "exit_tail": "",
        }
        base.update(kw)
        return base

    def fail(self, file, kind="expect_mismatch"):
        return {"file": file, "test": "t", "kind": kind, "error": "e"}

    def test_survived_when_nothing_fails(self):
        rec = ms.classify_run({"id": "m", "file": "f"}, self.run_of(), "/r")
        self.assertEqual(rec["status"], ms.SURVIVED)

    def test_killed_with_sole_killer_and_kind(self):
        rec = ms.classify_run(
            {"id": "m", "file": "f"},
            self.run_of(
                failures=[self.fail("test/a_test.dart"), self.fail("test/a_test.dart")]
            ),
            "/r",
        )
        self.assertEqual(rec["status"], ms.KILLED)
        self.assertEqual(rec["sole_killer"], "test/a_test.dart")
        self.assertEqual(rec["first_failure"]["kind"], "expect_mismatch")
        self.assertEqual(rec["n_failing"], 2)

    def test_two_killer_files_have_no_sole_killer(self):
        rec = ms.classify_run(
            {"id": "m", "file": "f"},
            self.run_of(
                failures=[self.fail("test/a_test.dart"), self.fail("test/b_test.dart")]
            ),
            "/r",
        )
        self.assertIsNone(rec["sole_killer"])
        self.assertEqual(rec["killer_files"], ["test/a_test.dart", "test/b_test.dart"])

    def test_timeout_and_compile_error(self):
        self.assertEqual(
            ms.classify_run(
                {"id": "m", "file": "f"}, self.run_of(timed_out=True), "/r"
            )["status"],
            ms.TIMEOUT,
        )
        self.assertEqual(
            ms.classify_run(
                {"id": "m", "file": "f"}, self.run_of(compile_error=True), "/r"
            )["status"],
            ms.INVALID,
        )

    def test_summary_counts_a_timeout_as_a_kill_and_leaves_out_invalid(self):
        result = {
            "subject": "s",
            "mode": "full",
            "mutants": [
                {
                    "id": "a",
                    "status": ms.KILLED,
                    "sole_killer": "t1",
                    "first_failure": {"kind": "timeout"},
                    "note": "",
                },
                {"id": "b", "status": ms.TIMEOUT, "note": ""},
                {"id": "c", "status": ms.SURVIVED, "line": 7, "note": "gap"},
                {
                    "id": "d",
                    "status": ms.INVALID,
                    "reason": "compile error",
                    "note": "",
                },
            ],
        }
        lines = ms.summarize(result)
        self.assertIn("kill rate 67% (2/3 valid)", lines[0])
        self.assertTrue(any("SURVIVED c line 7: gap" in line for line in lines))


class EndToEnd(RepoCase):
    def test_results_hold_kill_survive_and_sole_killer(self):
        repo = self.make()
        code, out, _ = repo.run()
        self.assertEqual(code, 0)
        r = repo.results()
        by = {m["id"]: m for m in r["mutants"]}
        self.assertEqual(by["m1"]["status"], ms.KILLED)
        self.assertEqual(by["m1"]["sole_killer"], "test/a_test.dart")
        self.assertEqual(by["m1"]["first_failure"]["kind"], "expect_mismatch")
        self.assertEqual(by["m1"]["line"], 1)
        self.assertEqual(by["m2"]["status"], ms.SURVIVED)
        self.assertIn("kill rate 50%", out)

    def test_a_mutant_that_does_not_compile_is_invalid(self):
        repo = self.make(
            mutants=[
                {
                    "id": "m1",
                    "file": "lib/a.dart",
                    "old": "=> 1;",
                    "new": "=> 1; MUT_BREAK",
                    "note": "",
                }
            ]
        )
        self.assertEqual(repo.run()[0], 0)
        self.assertEqual(repo.results()["mutants"][0]["status"], ms.INVALID)

    def test_only_runs_the_named_mutants(self):
        repo = self.make()
        repo.run("--only", "m2")
        self.assertEqual([m["id"] for m in repo.results()["mutants"]], ["m2"])

    def test_rerun_resumes_and_does_not_repeat_baseline_or_done_mutants(self):
        repo = self.make()
        repo.run("--only", "m1")
        before = len(repo.calls())
        repo.run()
        self.assertEqual(len(repo.calls()) - before, 1)  # only m2 ran
        self.assertEqual([m["id"] for m in repo.results()["mutants"]], ["m1", "m2"])

    def test_results_of_another_commit_are_not_reused(self):
        repo = self.make()
        repo.run()
        repo.write("lib/b.dart", "x\n")
        sh(
            repo.dir,
            "git",
            "-c",
            "user.name=t",
            "-c",
            "user.email=t@t",
            "add",
            "lib/b.dart",
        )
        sh(
            repo.dir,
            "git",
            "-c",
            "user.name=t",
            "-c",
            "user.email=t@t",
            "commit",
            "-qm",
            "next",
        )
        before = len(repo.calls())
        repo.run()
        self.assertEqual(len(repo.calls()) - before, 3)

    def test_quick_runs_only_the_quick_tests(self):
        repo = self.make()
        repo.run("--quick")
        r = repo.results()
        self.assertEqual(r["mode"], "quick")
        self.assertEqual(r["tests"], ["test/a_test.dart"])

    def test_summary_mode_prints_saved_results(self):
        repo = self.make()
        repo.run()
        code, out, _ = repo.run("--summary")
        self.assertEqual(code, 0)
        self.assertIn("== sub: kill rate 50%", out)


def alive(pid):
    try:
        with open(f"/proc/{pid}/stat") as fh:
            return fh.read().rsplit(")", 1)[1].split()[0] != "Z"
    except OSError:
        return False


class Verdicts(RepoCase):
    """A run that proves nothing is never a survivor."""

    def one(self, marker, **kw):
        repo = self.make(
            mutants=[
                {
                    "id": "m1",
                    "file": "lib/a.dart",
                    "old": "=> 1;",
                    "new": "=> 1; // " + marker,
                    "note": "",
                }
            ]
        )
        self.assertEqual(repo.run(**kw)[0] if kw else repo.run()[0], 0)
        return repo.results()["mutants"][0]

    def test_no_tests_ran_and_exit_79_is_inconclusive_not_survived(self):
        rec = self.one("MUT_NOTESTS")
        self.assertEqual(rec["status"], ms.INCONCLUSIVE)
        self.assertIn("exited 79", rec["reason"])

    def test_exit_0_with_no_test_passing_is_inconclusive(self):
        rec = self.one("MUT_ZERO")
        self.assertEqual(rec["status"], ms.INCONCLUSIVE)
        self.assertEqual(rec["reason"], "no test ran")

    def test_far_fewer_tests_than_the_baseline_is_inconclusive(self):
        rec = self.one("MUT_FEW")
        self.assertEqual(rec["status"], ms.INCONCLUSIVE)
        self.assertIn("1 tests ran, the baseline had 2", rec["reason"])

    def test_inconclusive_is_neither_killed_nor_survived_in_the_summary(self):
        repo = self.make(
            mutants=[
                {
                    "id": "m1",
                    "file": "lib/a.dart",
                    "old": "=> 1;",
                    "new": "=> 1; // MUT_NOTESTS",
                    "note": "",
                },
                {
                    "id": "m2",
                    "file": "lib/a.dart",
                    "old": "=> 2;",
                    "new": "=> 4;",
                    "note": "",
                },
            ]
        )
        _, out, _ = repo.run()
        self.assertIn("kill rate 0% (0/1 decided)", out)
        self.assertIn("INCONCLUSIVE 1", out)
        self.assertIn("SURVIVED 1", out)

    def test_baseline_with_nonzero_exit_and_no_failure_aborts(self):
        repo = self.make()
        repo.write("lib/a.dart", ORIGINAL + "// MUT_NOTESTS\n")
        sh(
            repo.dir,
            "git",
            "-c",
            "user.name=t",
            "-c",
            "user.email=t@t",
            "commit",
            "-qam",
            "x",
        )
        code, _, err = repo.run()
        self.assertEqual(code, 2)
        self.assertIn("exited 79", err)
        self.assertEqual(len(repo.calls()), 1)

    def test_baseline_with_no_test_passing_aborts(self):
        repo = self.make()
        repo.write("lib/a.dart", ORIGINAL + "// MUT_ZERO\n")
        sh(
            repo.dir,
            "git",
            "-c",
            "user.name=t",
            "-c",
            "user.email=t@t",
            "commit",
            "-qam",
            "x",
        )
        code, _, err = repo.run()
        self.assertEqual(code, 2)
        self.assertIn("no test ran", err)

    def test_runtime_throw_while_loading_is_a_kill(self):
        rec = self.one("MUT_LOADRUNTIME")
        self.assertEqual(rec["status"], ms.KILLED)
        self.assertEqual(rec["first_failure"]["kind"], "uncaught_exception")

    def test_compile_error_while_loading_is_invalid(self):
        self.assertEqual(self.one("MUT_BREAK")["status"], ms.INVALID)

    def test_classify_run_rules(self):
        base = {
            "secs": 1,
            "timed_out": False,
            "failures": [],
            "passed": 10,
            "exit_code": 0,
            "compile_error": False,
            "exit_tail": "",
        }
        m = {"id": "m", "file": "f"}
        self.assertEqual(ms.classify_run(m, base, "/r", 10)["status"], ms.SURVIVED)
        self.assertEqual(
            ms.classify_run(m, {**base, "exit_code": 79, "passed": 0}, "/r", 10)[
                "status"
            ],
            ms.INCONCLUSIVE,
        )
        self.assertEqual(
            ms.classify_run(m, {**base, "passed": 8}, "/r", 10)["status"],
            ms.INCONCLUSIVE,
        )
        self.assertEqual(
            ms.classify_run(m, {**base, "passed": 9}, "/r", 10)["status"], ms.SURVIVED
        )
        self.assertIsNotNone(ms.baseline_problem({**base, "exit_code": 1}))
        self.assertIsNone(ms.baseline_problem(base))

    def test_error_kind_needs_an_exception_marker(self):
        self.assertEqual(
            ms.classify_error("Some Error happened in the harness"), "other"
        )
        self.assertEqual(
            ms.classify_error("Bad state: no element"), "uncaught_exception"
        )
        self.assertEqual(
            ms.classify_error("FormatException: bad"), "uncaught_exception"
        )


class TimeoutAndCleanup(RepoCase):
    def test_timeout_kills_the_whole_process_group(self):
        repo = self.make()
        repo.write("lib/a.dart", ORIGINAL + "// MUT_SLEEP\n")
        t0 = ms.time.time()
        r = ms.run_tests(repo.dir, ["test/a_test.dart"], 2)
        self.assertLess(ms.time.time() - t0, 30)
        self.assertTrue(r["timed_out"])
        pid = int(repo.read("child.pid"))
        for _ in range(50):
            if not alive(pid):
                break
            ms.time.sleep(0.1)
        self.assertFalse(alive(pid))

    def test_timed_out_run_without_failures_is_a_timeout_kill(self):
        rec = ms.classify_run(
            {"id": "m", "file": "f"},
            {
                "secs": 1,
                "timed_out": True,
                "failures": [],
                "passed": 0,
                "exit_code": -9,
                "compile_error": False,
                "exit_tail": "",
            },
            "/r",
            10,
        )
        self.assertEqual(rec["status"], ms.TIMEOUT)

    def test_report_file_is_removed_when_interrupted(self):
        from unittest import mock

        tmp = tempfile.mkdtemp()
        self.addCleanup(lambda: os.rmdir(tmp))
        old = tempfile.tempdir
        tempfile.tempdir = tmp
        self.addCleanup(lambda: setattr(tempfile, "tempdir", old))
        with mock.patch.object(ms.subprocess, "Popen", side_effect=KeyboardInterrupt):
            with self.assertRaises(KeyboardInterrupt):
                ms.run_tests("/", ["t"], 1)
        self.assertEqual(os.listdir(tmp), [])

    def test_original_is_backed_up_during_a_run_and_removed_after(self):
        repo = self.make()
        repo.run()
        self.assertEqual(repo.read("backup.log").split(), ["False", "True", "True"])
        self.assertFalse(
            os.path.exists(
                os.path.join(repo.dir, ".dart_tool/mutation-sample/backup/lib/a.dart")
            )
        )

    def test_dirty_refusal_names_the_recovery_command(self):
        repo = self.make()
        repo.write("lib/a.dart", ORIGINAL + "// left behind\n")
        _, _, err = repo.run()
        self.assertIn("git restore lib/a.dart", err)

    def test_hangup_and_terminate_raise_an_interrupt(self):
        self.make().run("--check")
        self.make().run()
        for name in ("SIGTERM", "SIGHUP"):
            self.assertIs(
                ms.signal.getsignal(getattr(ms.signal, name)), ms._raise_interrupt
            )

    def test_a_file_outside_the_repo_is_rejected(self):
        repo = self.make(
            mutants=[
                {
                    "id": "m1",
                    "file": "../outside.dart",
                    "old": "x",
                    "new": "y",
                    "note": "",
                }
            ]
        )
        code, _, err = repo.run()
        self.assertEqual(code, 2)
        self.assertIn("outside the repo", err)


class Resume(RepoCase):
    def test_only_reruns_a_done_id_and_merges_into_the_saved_results(self):
        repo = self.make()
        repo.run()
        before = len(repo.calls())
        repo.run("--only", "m2")
        self.assertEqual(len(repo.calls()) - before, 1)  # no baseline, one mutant
        self.assertEqual([m["id"] for m in repo.results()["mutants"]], ["m1", "m2"])

    def test_editing_a_test_file_invalidates_the_saved_results(self):
        repo = self.make()
        repo.run()
        before = len(repo.calls())
        repo.write("test/a_test.dart", "// a, now with an assertion\n")
        code, out, _ = repo.run("--only", "m1")
        self.assertEqual(code, 0)
        self.assertEqual(len(repo.calls()) - before, 2)  # baseline again, then m1
        by = {m["id"]: m for m in repo.results()["mutants"]}
        self.assertNotIn("stale", by["m1"])
        self.assertTrue(by["m2"]["stale"])
        self.assertIn("1 stale", out)

    def test_editing_a_test_file_reruns_everything_on_a_full_run(self):
        repo = self.make()
        repo.run()
        before = len(repo.calls())
        repo.write("test/b_test.dart", "// b changed\n")
        repo.run()
        self.assertEqual(len(repo.calls()) - before, 3)

    def test_a_changed_list_entry_is_rerun_alone(self):
        repo = self.make()
        repo.run()
        before = len(repo.calls())
        path = os.path.join(repo.dir, "tool/mutants/sub.json")
        spec = json.loads(repo.read("tool/mutants/sub.json"))
        spec["mutants"][1]["new"] = "=> 5;"
        repo.write("tool/mutants/sub.json", json.dumps(spec))
        repo.run()
        self.assertEqual(len(repo.calls()) - before, 1)
        self.assertTrue(os.path.exists(path))


LCOV = """TN:
SF:lib/a.dart
DA:1,3
DA:2,0
DA:2,0
DA:5,1,abc
LF:3
end_of_record
SF:lib/other.dart
DA:1,9
end_of_record
SF:/repo/lib/b.dart
end_of_record
"""


class CoverageParsing(unittest.TestCase):
    def test_lcov_gives_hits_per_line_of_the_wanted_files_only(self):
        got = ms.parse_lcov(LCOV, "/repo", {"lib/a.dart", "lib/b.dart"})
        self.assertEqual(got["lib/a.dart"], {1: 3, 2: 0, 5: 1})
        self.assertNotIn("lib/other.dart", got)
        # An absolute path is made relative; a file with no lines is present.
        self.assertEqual(got["lib/b.dart"], {})

    def test_a_malformed_line_is_skipped(self):
        text = "SF:lib/a.dart\nDA:x,1\nDA:4\nDA:3,2\n"
        got = ms.parse_lcov(text, "/r", {"lib/a.dart"})
        self.assertEqual(got["lib/a.dart"], {3: 2})

    def test_anchor_lines(self):
        src = "a\nb c\nd\ne\n"
        self.assertEqual(ms.anchor_lines(src, "a"), (1, 1))
        self.assertEqual(ms.anchor_lines(src, "c"), (2, 2))
        self.assertEqual(ms.anchor_lines(src, "c\nd"), (2, 3))
        self.assertEqual(ms.anchor_lines(src, "e"), (4, 4))


def cov_of(lines, order=("t1", "t2", "t3"), loaded=("lib/a.dart",)):
    return {
        "order": list(order),
        "loaded": list(loaded),
        "lines": {"lib/a.dart": {str(n): hit for n, hit in lines.items()}},
    }


class SubsetSelection(unittest.TestCase):
    tests = ["t3", "t1", "t2"]

    def pick(self, cov, start, end):
        return ms.select_subset(cov, "lib/a.dart", start, end, self.tests)

    def test_the_covering_files_come_back_in_list_order(self):
        self.assertEqual(
            self.pick(cov_of({4: [0, 2], 5: []}), 4, 4), (None, ["t3", "t1"])
        )

    def test_a_multi_line_anchor_takes_every_file_of_any_of_its_lines(self):
        cov = cov_of({4: [0], 5: [], 6: [1]})
        self.assertEqual(self.pick(cov, 4, 6), (None, ["t1", "t2"]))

    def test_a_line_no_test_hits_is_uncovered(self):
        self.assertEqual(self.pick(cov_of({4: [], 5: []}), 4, 5), (ms.UNCOVERED, []))

    def test_a_file_no_test_loaded_is_uncovered(self):
        self.assertEqual(
            self.pick(cov_of({4: [0]}, loaded=()), 4, 4), (ms.UNCOVERED, [])
        )

    def test_lines_without_coverage_data_are_not_uncovered(self):
        self.assertEqual(self.pick(cov_of({4: [0]}), 7, 8), (ms.NO_LINE_DATA, []))

    def test_a_hit_beside_an_uninstrumented_line_still_counts(self):
        self.assertEqual(self.pick(cov_of({5: [1]}), 4, 5), (None, ["t2"]))


class Subset(RepoCase):
    def subset_results(self, repo):
        data = json.loads(repo.read("out/sub.subset.json"))
        return data, {m["id"]: m for m in data["mutants"]}

    def test_each_mutant_runs_only_the_files_that_cover_its_line(self):
        repo = self.make()
        self.assertEqual(repo.run("--subset")[0], 0)
        self.assertEqual(
            repo.log_lines("cov.log"), ["test/a_test.dart", "test/b_test.dart"]
        )
        self.assertEqual(
            repo.log_lines("runs.log"), ["test/a_test.dart", "test/b_test.dart"]
        )
        data, by = self.subset_results(repo)
        self.assertEqual(by["m1"]["status"], ms.KILLED)
        self.assertEqual(by["m1"]["subset_tests"], ["test/a_test.dart"])
        self.assertEqual((by["m1"]["subset_size"], by["m1"]["full_size"]), (1, 2))
        self.assertEqual(data["mode"], "subset")
        self.assertEqual(data["baseline"]["source"], "coverage map")

    def test_a_subset_survivor_is_labelled_subset_survived_never_survived(self):
        repo = self.make()
        code, out, _ = repo.run("--subset")
        _, by = self.subset_results(repo)
        self.assertEqual(by["m2"]["status"], ms.SUBSET_SURVIVED)
        self.assertIn("SUBSET-SURVIVED m2", out)
        self.assertNotIn(" SURVIVED m2", out)
        self.assertFalse(os.path.exists(os.path.join(repo.dir, "out/sub.json")))

    def test_a_subset_run_never_touches_the_lists_or_the_tree(self):
        repo = self.make()
        before = repo.read("tool/mutants/sub.json")
        repo.run("--subset")
        self.assertEqual(repo.read("tool/mutants/sub.json"), before)
        status = subprocess.run(
            ["git", "status", "--porcelain"],
            cwd=repo.dir,
            capture_output=True,
            text=True,
        )
        self.assertEqual(status.stdout.strip(), "")

    def test_a_line_no_test_covers_is_uncovered_and_not_run(self):
        repo = self.make()
        both = {"lib/a.dart": {"1": 1, "2": 0}}
        repo.write(
            "cov.json",
            json.dumps({"test/a_test.dart": both, "test/b_test.dart": both}),
        )
        code, out, _ = repo.run("--subset")
        self.assertEqual(code, 0)
        _, by = self.subset_results(repo)
        self.assertEqual(by["m2"]["status"], ms.UNCOVERED)
        self.assertEqual(by["m2"]["subset_size"], 0)
        self.assertEqual(
            repo.log_lines("runs.log"), ["test/a_test.dart,test/b_test.dart"]
        )  # m1 only
        self.assertIn("UNCOVERED m2", out)

    def test_the_map_is_reused_on_the_same_commit_and_tree(self):
        repo = self.make()
        repo.run("--subset")
        runs = len(repo.log_lines("runs.log"))
        code, out, _ = repo.run("--subset", "--only", "m2")
        self.assertEqual(len(repo.log_lines("cov.log")), 2)  # not built again
        self.assertEqual(len(repo.log_lines("runs.log")), runs + 1)
        self.assertIn("coverage map reused", out)

    def test_a_new_commit_invalidates_the_map(self):
        repo = self.make()
        repo.run("--coverage-map")
        repo.commit("lib/b.dart", "x\n")
        repo.run("--coverage-map")
        self.assertEqual(len(repo.log_lines("cov.log")), 4)

    def test_an_uncommitted_change_under_lib_invalidates_the_map(self):
        repo = self.make()
        repo.run("--coverage-map")
        repo.write("lib/untracked.dart", "x\n")
        repo.run("--coverage-map")
        self.assertEqual(len(repo.log_lines("cov.log")), 4)

    def test_editing_a_test_or_a_mutated_file_invalidates_the_map(self):
        repo = self.make()
        repo.run("--coverage-map")
        repo.write("test/b_test.dart", "// b changed\n")
        repo.run("--coverage-map")
        self.assertEqual(len(repo.log_lines("cov.log")), 4)
        repo.write("lib/a.dart", repo.read("lib/a.dart") + "// x\n")
        repo.run("--coverage-map")
        self.assertEqual(len(repo.log_lines("cov.log")), 6)

    def test_an_uncommitted_change_of_the_test_list_invalidates_the_map(self):
        repo = self.make()
        repo.run("--coverage-map")
        spec = json.loads(repo.read("tool/mutants/sub.json"))
        spec["tests"].reverse()
        repo.write("tool/mutants/sub.json", json.dumps(spec))
        repo.run("--coverage-map")
        self.assertEqual(len(repo.log_lines("cov.log")), 4)

    def test_a_second_edit_of_an_already_dirty_file_invalidates_the_map(self):
        repo = self.make()
        for rel in ("test/b_test.dart", "lib/a.dart"):
            before = len(repo.log_lines("cov.log"))
            repo.write(rel, repo.read(rel) + "// v1\n")
            repo.run("--coverage-map")
            repo.write(rel, repo.read(rel) + "// v2\n")
            repo.run("--coverage-map")
            self.assertEqual(len(repo.log_lines("cov.log")) - before, 4, rel)

    def test_a_subset_result_is_not_reused_after_another_lib_file_changed(self):
        repo = self.make()
        repo.run("--subset")
        runs = len(repo.log_lines("runs.log"))
        repo.write("lib/untracked.dart", "x\n")
        repo.run("--subset")
        self.assertEqual(len(repo.log_lines("runs.log")), runs + 2)

    def test_run_subject_refuses_subset_with_quick(self):
        repo = self.make()
        spec = json.loads(repo.read("tool/mutants/sub.json"))
        with self.assertRaises(ms.MutationError):
            ms.run_subject(
                repo.dir,
                spec,
                os.path.join(repo.dir, "out/x.json"),
                quick=True,
                subset=True,
            )
        self.assertEqual(repo.log_lines("cov.log"), [])

    def test_fresh_rebuilds_the_map(self):
        repo = self.make()
        repo.run("--coverage-map")
        repo.run("--coverage-map", "--fresh")
        self.assertEqual(len(repo.log_lines("cov.log")), 4)

    def test_a_partial_map_of_the_same_key_is_resumed(self):
        repo = self.make()
        repo.run("--coverage-map")
        path = os.path.join(repo.dir, "out/coverage/sub.json")
        cov = json.loads(ms.read_text(path))
        cov["complete"] = False
        del cov["tests"]["test/b_test.dart"]
        ms.save(cov, path)
        repo.run("--coverage-map")
        self.assertEqual(repo.log_lines("cov.log")[2:], ["test/b_test.dart"])

    def test_a_subset_result_of_another_map_is_not_reused(self):
        repo = self.make()
        repo.run("--subset")
        runs = len(repo.log_lines("runs.log"))
        repo.write("test/b_test.dart", "// b changed\n")
        repo.run("--subset")
        self.assertEqual(len(repo.log_lines("runs.log")), runs + 2)

    def test_a_subset_result_of_the_same_map_is_reused(self):
        repo = self.make()
        repo.run("--subset")
        runs = len(repo.log_lines("runs.log"))
        repo.run("--subset")
        self.assertEqual(len(repo.log_lines("runs.log")), runs)

    def test_a_file_that_is_red_alone_is_left_out_of_every_subset(self):
        repo = self.make()
        spec = json.loads(repo.read("tool/mutants/sub.json"))

        def runner(repo_dir, test, timeout, concurrency):
            red = test == "test/b_test.dart"
            failure = {"file": test, "test": "t", "kind": "other", "error": ""}
            return {
                "secs": 1.0,
                "timed_out": False,
                "compile_error": False,
                "exit_code": 1 if red else 0,
                "failures": [failure] if red else [],
                "passed": 0 if red else 1,
                "lcov": "SF:lib/a.dart\nDA:1,1\nDA:2,1\nend_of_record\n",
            }

        cov = ms.ensure_coverage_map(
            repo.dir,
            spec,
            os.path.join(repo.dir, "out/c.json"),
            runner=runner,
            log=lambda *_: None,
        )
        self.assertFalse(cov["tests"]["test/b_test.dart"]["ok"])
        self.assertEqual(
            ms.select_subset(cov, "lib/a.dart", 2, 2, spec["tests"]),
            (None, ["test/a_test.dart"]),
        )

    def test_subset_and_quick_cannot_be_combined(self):
        repo = self.make()
        code, _, err = repo.run("--subset", "--quick")
        self.assertEqual(code, 2)
        self.assertIn("cannot be combined", err)
        self.assertEqual(repo.log_lines("runs.log"), [])

    def test_summary_shows_the_subset_results(self):
        repo = self.make()
        repo.run("--subset")
        code, out, _ = repo.run("--summary")
        self.assertIn("[subset]", out)
        self.assertIn("SUBSET-SURVIVED m2", out)

    def test_the_summary_does_not_count_a_subset_survivor_as_decided(self):
        result = {
            "subject": "s",
            "mode": "subset",
            "mutants": [
                {"id": "a", "status": ms.SUBSET_SURVIVED, "note": "n"},
                {"id": "b", "status": ms.UNCOVERED, "note": "n"},
            ],
        }
        self.assertIn("kill rate 0% (0/0 decided)", ms.summarize(result)[0])


class RecordSurvivors(RepoCase):
    def test_a_subset_run_is_refused_before_anything_runs(self):
        repo = self.make()
        before = repo.read("tool/mutants/sub.json")
        code, _, err = repo.run("--subset", "--record-survivors")
        self.assertEqual(code, 2)
        self.assertIn("only a full-list run confirms a survivor", err)
        self.assertEqual(repo.log_lines("runs.log"), [])
        self.assertEqual(repo.read("tool/mutants/sub.json"), before)

    def test_a_quick_run_is_refused_too(self):
        repo = self.make()
        code, _, err = repo.run("--quick", "--record-survivors")
        self.assertEqual(code, 2)
        self.assertEqual(repo.log_lines("runs.log"), [])

    def test_the_function_refuses_a_result_of_a_subset_or_quick_run(self):
        repo = self.make()
        before = repo.read("tool/mutants/sub.json")
        for mode in ("subset", "quick", None):
            result = {
                "commit": "0123456789abcdef",
                "mutants": [{"id": "m2", "status": ms.SURVIVED}],
            }
            if mode:
                result["mode"] = mode
            with self.assertRaises(ms.MutationError) as raised:
                ms.record_survivors(repo.dir, "sub", result)
            self.assertIn("only a full-list run", str(raised.exception))
        self.assertEqual(repo.read("tool/mutants/sub.json"), before)

    def test_a_saved_subset_result_is_refused(self):
        repo = self.make()
        repo.run("--subset")
        result = json.loads(repo.read("out/sub.subset.json"))
        with self.assertRaises(ms.MutationError):
            ms.record_survivors(repo.dir, "sub", result)

    def test_a_full_run_notes_only_its_survivors(self):
        repo = self.make()
        code, out, _ = repo.run("--record-survivors")
        self.assertEqual(code, 0)
        spec = json.loads(repo.read("tool/mutants/sub.json"))
        by = {m["id"]: m for m in spec["mutants"]}
        self.assertEqual(by["m1"]["note"], "caught")
        self.assertTrue(
            by["m2"]["note"].startswith("missed; known survivor (full list, main ")
        )
        self.assertIn("['m2']", out)

    def test_noting_twice_does_not_repeat_the_note(self):
        repo = self.make()
        repo.run("--record-survivors")
        once = repo.read("tool/mutants/sub.json")
        repo.run("--record-survivors", "--fresh")
        self.assertEqual(repo.read("tool/mutants/sub.json"), once)


if __name__ == "__main__":
    unittest.main()
