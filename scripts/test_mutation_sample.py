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
open("calls.log", "a").write(repr(src) + "\n")
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
            ".gitignore": "calls.log\nbackup.log\nchild.pid\nbin/\nout/\n.dart_tool/\n",
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


if __name__ == "__main__":
    unittest.main()
