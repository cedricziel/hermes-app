"""Tests for scripts/premerge_check.sh (the trial-merge check before a merge).

Every test builds real throwaway git repos: a bare "origin" holding
refs/heads/main and refs/pull/N/head, plus a "caller" clone the script runs
in. `flutter` is a stub on PATH whose behaviour comes from environment
variables. Set PREMERGE_SCRIPT to run another copy of the script (the
mutation proof does this).
"""

import hashlib
import os
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

SCRIPT = Path(
    os.environ.get("PREMERGE_SCRIPT")
    or Path(__file__).resolve().parent / "premerge_check.sh"
)

STUB_FLUTTER = """#!/bin/bash
# Stub flutter: logs "<cwd> <args>" and obeys STUB_* variables.
echo "$PWD $*" >> "$STUB_LOG"
case "$1" in
  pub) exit "${STUB_PUB_EXIT:-0}" ;;
  analyze)
    [ -n "${STUB_MARKER:-}" ] && : > "$STUB_MARKER"
    [ -n "${STUB_SLEEP:-}" ] && sleep "$STUB_SLEEP"
    [ "${STUB_ANALYZE_EXIT:-0}" != 0 ] && echo "error - lib/x.dart:1:1 - boom - bad"
    exit "${STUB_ANALYZE_EXIT:-0}" ;;
  test)
    files=0
    for a in "$@"; do
      case "$a" in *_test.dart) printf '%s\\0' "$a" >> "$STUB_TESTS_LOG"; files=1 ;; esac
    done
    if [ "$files" = 1 ]; then
      bad=0
      [ -n "${STUB_SLEEP_ALL:-}" ] && sleep "$STUB_SLEEP_ALL"
      for a in "$@"; do
        if [ "$a" = "${STUB_SLEEP_FILE:-}" ]; then
          [ -n "${STUB_IGNORE_TERM:-}" ] && trap '' TERM
          [ -n "${STUB_GRANDCHILD:-}" ] && { sleep 300 & echo $! > "$STUB_GRANDCHILD"; }
          sleep "${STUB_TEST_SLEEP:-60}"
        fi
        case ",${STUB_FAIL_FILES:-}," in *",$a,"*) echo "00:01 +0 -1: $a name [E]"; bad=1 ;; esac
      done
      [ "$bad" = 1 ] && exit 1
      exit "${STUB_FILES_EXIT:-0}"
    fi
    exit "${STUB_TEST_EXIT:-0}" ;;
esac
exit 0
"""


def git(cwd, *args, check=True, env=None):
    full = {
        **os.environ,
        "GIT_AUTHOR_NAME": "t",
        "GIT_AUTHOR_EMAIL": "t@t",
        "GIT_COMMITTER_NAME": "t",
        "GIT_COMMITTER_EMAIL": "t@t",
        "GIT_CONFIG_GLOBAL": "/dev/null",
        "GIT_CONFIG_SYSTEM": "/dev/null",
    }
    full.update(env or {})
    return subprocess.run(
        ["git", *args],
        cwd=cwd,
        env=full,
        check=check,
        capture_output=True,
        text=True,
    ).stdout


class PremergeTest(unittest.TestCase):
    def setUp(self):
        self.root = Path(tempfile.mkdtemp(prefix="premerge-test-"))
        self.addCleanup(shutil.rmtree, self.root, ignore_errors=True)
        self.tmp = self.root / "tmp"  # TMPDIR for the script under test
        self.tmp.mkdir()
        self.bin = self.root / "bin"
        self.bin.mkdir()
        stub = self.bin / "flutter"
        stub.write_text(STUB_FLUTTER)
        stub.chmod(0o755)
        self.log = self.root / "flutter.log"
        self.tests_log = self.root / "tests.log"
        self.origin = self.root / "origin.git"
        git(self.root, "init", "-q", "--bare", "-b", "main", str(self.origin))
        seed = self.root / "seed"
        git(self.root, "clone", "-q", str(self.origin), str(seed))
        git(seed, "checkout", "-q", "-b", "main")
        self.write(seed, "lib/src/theme/a.dart", "a\n")
        self.write(seed, "lib/src/theme/b.dart", "b\n")
        self.write(seed, "lib/src/chat/c.dart", "c\n")
        self.write(seed, "test/architecture/x_test.dart", "x\n")
        self.write(seed, "README.md", "readme\n")
        self.write(seed, "pubspec.yaml", "name: hermes_app\n")
        git(seed, "add", "-A")
        git(seed, "commit", "-q", "-m", "init")
        git(seed, "push", "-q", "origin", "main")
        self.seed = seed
        self.caller = self.root / "caller"
        git(self.root, "clone", "-q", str(self.origin), str(self.caller))

    # helpers ---------------------------------------------------------

    @staticmethod
    def write(repo, rel, text):
        p = Path(repo) / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(text)

    def pr(self, n, files=None, parent="main", delete=(), rename=()):
        """Publish refs/pull/<n>/head: parent plus one commit."""
        git(self.seed, "checkout", "-q", "-B", f"pr{n}", parent)
        for rel, text in (files or {}).items():
            self.write(self.seed, rel, text)
        for rel in delete:
            git(self.seed, "rm", "-q", rel)
        for old, new in rename:
            (self.seed / new).parent.mkdir(parents=True, exist_ok=True)
            git(self.seed, "mv", old, new)
        git(self.seed, "add", "-A")
        git(self.seed, "commit", "-q", "-m", f"pr {n}")
        git(self.seed, "push", "-q", "origin", f"pr{n}:refs/pull/{n}/head")
        git(self.seed, "checkout", "-q", "main")

    def advance_main(self, files):
        git(self.seed, "checkout", "-q", "main")
        for rel, text in files.items():
            self.write(self.seed, rel, text)
        git(self.seed, "add", "-A")
        git(self.seed, "commit", "-q", "-m", "main moves")
        git(self.seed, "push", "-q", "origin", "main")

    def env(self, **extra):
        e = {
            **os.environ,
            "PATH": f"{self.bin}:{os.environ['PATH']}",
            "TMPDIR": str(self.tmp),
            "STUB_LOG": str(self.log),
            "STUB_TESTS_LOG": str(self.tests_log),
            "GIT_CONFIG_GLOBAL": "/dev/null",
            "GIT_CONFIG_SYSTEM": "/dev/null",
        }
        e.pop("PREMERGE_LIST_OPEN", None)
        e.update(extra)
        return e

    def run_check(self, *args, cwd=None, **extra):
        return subprocess.run(
            ["bash", str(SCRIPT), *map(str, args)],
            cwd=cwd or self.caller,
            env=self.env(**extra),
            capture_output=True,
            text=True,
            timeout=120,
        )

    def snapshot(self, repo=None):
        repo = repo or self.caller
        git(repo, "update-index", "-q", "--refresh", check=False)
        index = Path(git(repo, "rev-parse", "--absolute-git-dir").strip()) / "index"
        return {
            "status": git(repo, "status", "--porcelain=v1", "-uall"),
            "head": git(repo, "rev-parse", "HEAD"),
            "branch": git(repo, "symbolic-ref", "-q", "HEAD", check=False),
            "index": hashlib.sha256(index.read_bytes()).hexdigest(),
            "ls": git(repo, "ls-files", "-s"),
            "stash": git(repo, "stash", "list"),
            "diff": git(repo, "diff"),
            "branches": git(repo, "for-each-ref", "refs/heads"),
        }

    def worktrees(self):
        out = git(self.caller, "worktree", "list", "--porcelain")
        return [l for l in out.splitlines() if l.startswith("worktree ")]

    def assert_clean_up(self):
        self.assertEqual(len(self.worktrees()), 1, self.worktrees())
        self.assertEqual(list(self.tmp.iterdir()), [])
        self.assertEqual(git(self.caller, "for-each-ref", "refs/premerge"), "")

    # exit codes ------------------------------------------------------

    def test_clean_merge_passes(self):
        self.pr(10, {"lib/src/chat/new.dart": "n\n"})
        r = self.run_check(10)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        base = git(self.origin, "rev-parse", "main").strip()
        head = git(self.origin, "rev-parse", "refs/pull/10/head").strip()
        self.assertIn(base, r.stdout)
        self.assertIn(head, r.stdout)
        log = self.log.read_text()
        self.assertIn("pub get", log)
        self.assertIn("analyze", log)
        self.assertIn("test --no-pub test/architecture", log)
        self.assertRegex(r.stdout, r"pub get.*\d+s")
        self.assert_clean_up()

    def test_checks_run_in_trial_worktree_not_caller(self):
        self.pr(10, {"lib/src/chat/new.dart": "n\n"})
        self.run_check(10)
        for line in self.log.read_text().splitlines():
            cwd = line.split(" ", 1)[0]
            self.assertTrue(
                cwd.startswith(str(self.tmp.resolve()))
                or cwd.startswith(str(self.tmp)),
                line,
            )

    def test_trial_merge_sees_both_sides(self):
        # A file the PR adds is present where flutter runs; main's too.
        self.pr(10, {"lib/src/chat/new.dart": "n\n"})
        self.advance_main({"lib/src/chat/later.dart": "l\n"})
        stub = self.bin / "flutter"
        stub.write_text(
            STUB_FLUTTER.replace(
                'echo "$PWD $*" >> "$STUB_LOG"',
                'echo "$PWD $*" >> "$STUB_LOG"\n'
                '[ "$1" = analyze ] && ls lib/src/chat >> "$STUB_LOG"',
            )
        )
        r = self.run_check(10)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        log = self.log.read_text()
        self.assertIn("new.dart", log)
        self.assertIn("later.dart", log)

    def test_conflict_exits_2_and_names_files(self):
        self.pr(10, {"lib/src/theme/a.dart": "pr side\n"})
        self.advance_main({"lib/src/theme/a.dart": "main side\n"})
        r = self.run_check(10)
        self.assertEqual(r.returncode, 2, r.stdout + r.stderr)
        self.assertIn("lib/src/theme/a.dart", r.stdout + r.stderr)
        self.assertFalse(self.log.exists(), "no check may run after a conflict")
        self.assert_clean_up()

    def test_analyze_failure_exits_3(self):
        self.pr(10, {"lib/src/chat/new.dart": "n\n"})
        r = self.run_check(10, STUB_ANALYZE_EXIT="1")
        self.assertEqual(r.returncode, 3, r.stdout + r.stderr)
        self.assertIn("boom", r.stdout + r.stderr)
        self.assertNotIn("test --no-pub", self.log.read_text())
        self.assert_clean_up()

    def test_architecture_failure_exits_4(self):
        self.pr(10, {"lib/src/chat/new.dart": "n\n"})
        r = self.run_check(10, STUB_TEST_EXIT="1")
        self.assertEqual(r.returncode, 4, r.stdout + r.stderr)
        self.assert_clean_up()

    def test_unknown_pr_exits_1(self):
        r = self.run_check(999)
        self.assertEqual(r.returncode, 1, r.stdout + r.stderr)
        self.assertFalse(self.log.exists())
        self.assert_clean_up()

    def test_unknown_other_pr_exits_1(self):
        self.pr(10, {"lib/src/chat/new.dart": "n\n"})
        r = self.run_check(10, "--others", 999)
        self.assertEqual(r.returncode, 1, r.stdout + r.stderr)
        self.assert_clean_up()

    def test_usage_errors_exit_1(self):
        for args in (
            [],
            ["abc"],
            ["10", "--bogus"],
            ["10", "--others"],
            ["10", "--others", "x"],
            ["10", "--base"],
        ):
            r = self.run_check(*args)
            self.assertEqual(r.returncode, 1, (args, r.stdout, r.stderr))
            self.assertIn("Usage", r.stdout + r.stderr)

    def test_pub_get_failure_is_not_success(self):
        self.pr(10, {"lib/src/chat/new.dart": "n\n"})
        r = self.run_check(10, STUB_PUB_EXIT="1")
        self.assertNotEqual(r.returncode, 0)
        self.assert_clean_up()

    def test_base_option(self):
        git(self.seed, "checkout", "-q", "-b", "release", "main")
        self.write(self.seed, "lib/src/chat/rel.dart", "r\n")
        git(self.seed, "add", "-A")
        git(self.seed, "commit", "-q", "-m", "rel")
        git(self.seed, "push", "-q", "origin", "release")
        git(self.seed, "checkout", "-q", "main")
        self.pr(10, {"lib/src/chat/new.dart": "n\n"})
        r = self.run_check(10, "--base", "release")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn(git(self.origin, "rev-parse", "release").strip(), r.stdout)

    # overlap ---------------------------------------------------------

    def test_overlap_report_names_shared_directory(self):
        self.pr(
            10,
            {
                "lib/src/theme/a.dart": "pr10\n",
                "lib/src/theme/b.dart": "pr10\n",
                "lib/src/chat/c.dart": "pr10\n",
            },
        )
        self.pr(11, {"lib/src/theme/new.dart": "pr11\n"})
        self.pr(12, {"README.md": "docs only\n"})
        r = self.run_check(10, "--others", 11, 12)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn(
            "overlap with #11: lib/src/theme/ (2 files here, 1 there)", r.stdout
        )
        self.assertNotIn("overlap with #12", r.stdout)
        self.assertIn("WARNING", r.stdout)
        self.assertNotIn("lib/src/chat/", r.stdout.split("overlap with")[1].split("<== overlap")[0])

    def test_overlap_counts_test_dirs_and_uses_merge_base(self):
        # PR 11 branched before main moved; main's change must not count.
        self.pr(11, {"test/architecture/y_test.dart": "y\n"})
        self.advance_main({"test/architecture/x_test.dart": "moved\n"})
        self.pr(10, {"test/architecture/z_test.dart": "z\n"})
        r = self.run_check(10, "--others", 11)
        self.assertIn(
            "overlap with #11: test/architecture/ (1 files here, 1 there)", r.stdout
        )

    def test_no_overlap_no_warning(self):
        self.pr(10, {"lib/src/chat/new.dart": "n\n"})
        self.pr(11, {"lib/src/theme/new.dart": "n\n"})
        r = self.run_check(10, "--others", 11)
        self.assertEqual(r.returncode, 0)
        self.assertNotIn("WARNING", r.stdout)
        self.assertNotIn("overlap with", r.stdout)

    def test_overlap_alone_does_not_fail(self):
        self.pr(10, {"lib/src/theme/a.dart": "10\n"})
        self.pr(11, {"lib/src/theme/b.dart": "11\n"})
        self.assertEqual(self.run_check(10, "--others", 11).returncode, 0)

    # caller isolation ------------------------------------------------

    def dirty_caller(self):
        git(self.caller, "checkout", "-q", "-b", "feature/mine")
        self.write(self.caller, "lib/src/theme/a.dart", "wip stash me\n")
        git(self.caller, "stash", "push", "-q", "-m", "mine")
        self.write(self.caller, "lib/src/theme/a.dart", "dirty tracked\n")
        self.write(self.caller, "lib/src/theme/b.dart", "staged\n")
        git(self.caller, "add", "lib/src/theme/b.dart")
        self.write(self.caller, "untracked.txt", "u\n")
        self.write(self.caller, "lib/src/theme/c.dart", "committed on feature\n")
        git(self.caller, "add", "lib/src/theme/c.dart")
        git(self.caller, "commit", "-q", "-m", "feature work")

    def test_caller_tree_untouched_on_success(self):
        self.pr(10, {"lib/src/theme/new.dart": "n\n"})
        self.dirty_caller()
        before = self.snapshot()
        r = self.run_check(10)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertEqual(self.snapshot(), before)

    def test_caller_tree_untouched_on_conflict(self):
        self.pr(10, {"lib/src/theme/a.dart": "pr\n"})
        self.advance_main({"lib/src/theme/a.dart": "main\n"})
        self.dirty_caller()
        before = self.snapshot()
        r = self.run_check(10)
        self.assertEqual(r.returncode, 2)
        self.assertEqual(self.snapshot(), before)

    def test_caller_tree_untouched_on_failing_check(self):
        self.pr(10, {"lib/src/theme/new.dart": "n\n"})
        self.dirty_caller()
        before = self.snapshot()
        r = self.run_check(10, STUB_ANALYZE_EXIT="1")
        self.assertEqual(r.returncode, 3)
        self.assertEqual(self.snapshot(), before)

    def test_caller_tree_untouched_on_clean_main(self):
        self.pr(10, {"lib/src/theme/new.dart": "n\n"})
        before = self.snapshot()
        self.run_check(10)
        self.assertEqual(self.snapshot(), before)

    def test_runs_from_a_subdirectory_of_the_caller(self):
        self.pr(10, {"lib/src/chat/new.dart": "n\n"})
        r = self.run_check(10, cwd=self.caller / "lib" / "src")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assert_clean_up()

    # clean-up --------------------------------------------------------

    def test_sigterm_mid_run_cleans_up(self):
        self.pr(10, {"lib/src/chat/new.dart": "n\n"})
        marker = self.root / "marker"
        out = (self.root / "out.txt").open("w")
        self.addCleanup(out.close)
        p = subprocess.Popen(
            ["bash", str(SCRIPT), "10"],
            cwd=self.caller,
            env=self.env(STUB_SLEEP="60", STUB_MARKER=str(marker)),
            stdout=out,
            stderr=subprocess.STDOUT,
            start_new_session=True,
        )
        try:
            deadline = time.time() + 60
            while not marker.exists() and time.time() < deadline:
                time.sleep(0.1)
            self.assertTrue(marker.exists(), "stub analyze never started")
            self.assertEqual(len(self.worktrees()), 2)
            p.send_signal(signal.SIGTERM)
            p.wait(timeout=30)
        finally:
            if p.poll() is None:
                os.killpg(p.pid, signal.SIGKILL)
        self.assertNotEqual(p.returncode, 0)
        self.assert_clean_up()

    def test_sigint_mid_run_cleans_up(self):
        self.pr(10, {"lib/src/chat/new.dart": "n\n"})
        marker = self.root / "marker"
        out = (self.root / "out.txt").open("w")
        self.addCleanup(out.close)
        p = subprocess.Popen(
            ["bash", str(SCRIPT), "10"],
            cwd=self.caller,
            env=self.env(STUB_SLEEP="60", STUB_MARKER=str(marker)),
            stdout=out,
            stderr=subprocess.STDOUT,
            start_new_session=True,
        )
        try:
            deadline = time.time() + 60
            while not marker.exists() and time.time() < deadline:
                time.sleep(0.1)
            p.send_signal(signal.SIGINT)
            p.wait(timeout=30)
        finally:
            if p.poll() is None:
                os.killpg(p.pid, signal.SIGKILL)
        self.assert_clean_up()

    def test_keep_leaves_the_worktree(self):
        self.pr(10, {"lib/src/chat/new.dart": "n\n"})
        r = self.run_check(10, "--keep")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertEqual(len(self.worktrees()), 2)
        kept = [p for p in self.tmp.iterdir()]
        self.assertEqual(len(kept), 1)
        self.assertIn(str(kept[0]), r.stdout)
        self.assertEqual(git(self.caller, "for-each-ref", "refs/premerge"), "")
        # The documented way to remove it works.
        git(
            self.caller,
            "worktree",
            "remove",
            "--force",
            [w.split(" ", 1)[1] for w in self.worktrees() if str(self.caller) not in w][
                0
            ],
        )

    def test_private_refs_exist_during_run_and_are_gone_after(self):
        self.pr(10, {"lib/src/chat/new.dart": "n\n"})
        marker = self.root / "marker"
        out = (self.root / "out.txt").open("w")
        self.addCleanup(out.close)
        p = subprocess.Popen(
            ["bash", str(SCRIPT), "10"],
            cwd=self.caller,
            env=self.env(STUB_SLEEP="60", STUB_MARKER=str(marker)),
            stdout=out,
            stderr=subprocess.STDOUT,
            start_new_session=True,
        )
        try:
            deadline = time.time() + 60
            while not marker.exists() and time.time() < deadline:
                time.sleep(0.1)
            self.assertIn(
                "refs/premerge/", git(self.caller, "for-each-ref", "refs/premerge")
            )
            p.send_signal(signal.SIGTERM)
            p.wait(timeout=30)
        finally:
            if p.poll() is None:
                os.killpg(p.pid, signal.SIGKILL)
        self.assertEqual(git(self.caller, "for-each-ref", "refs/premerge"), "")

    def test_never_pushes(self):
        self.pr(10, {"lib/src/chat/new.dart": "n\n"})
        before = git(self.origin, "for-each-ref")
        self.run_check(10)
        self.assertEqual(git(self.origin, "for-each-ref"), before)

    def test_exit_hints_name_the_next_step(self):
        self.pr(10, {"lib/src/chat/new.dart": "n\n"})
        ok = self.run_check(10)
        self.assertIn("safe to arm", ok.stdout)
        bad = self.run_check(10, STUB_ANALYZE_EXIT="1")
        self.assertIn("Do not arm", bad.stdout + bad.stderr)
        self.assertIn("rerun", ok.stdout.lower())

    # review fixes -----------------------------------------------------

    def spawn_sleeping(self, pr=10):
        marker = self.root / "marker"
        out = (self.root / "out.txt").open("w")
        self.addCleanup(out.close)
        p = subprocess.Popen(
            ["bash", str(SCRIPT), str(pr)], cwd=self.caller,
            env=self.env(STUB_SLEEP="60", STUB_MARKER=str(marker)),
            stdout=out, stderr=subprocess.STDOUT, start_new_session=True,
        )
        self.addCleanup(lambda: p.poll() is None and os.killpg(p.pid, signal.SIGKILL))
        deadline = time.time() + 60
        while not marker.exists() and time.time() < deadline:
            time.sleep(0.1)
        self.assertTrue(marker.exists(), "stub analyze never started")
        return p

    def test_inherited_git_dir_is_ignored(self):
        self.pr(10, {"lib/src/theme/new.dart": "n\n"})
        self.dirty_caller()
        before = self.snapshot()
        gitdir = git(self.caller, "rev-parse", "--absolute-git-dir").strip()
        r = self.run_check(10, GIT_DIR=gitdir, GIT_WORK_TREE=str(self.caller))
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertEqual(self.snapshot(), before)
        self.assert_clean_up()

    def test_inherited_git_index_file_is_ignored(self):
        self.pr(10, {"lib/src/theme/new.dart": "n\n"})
        self.dirty_caller()
        before = self.snapshot()
        gitdir = git(self.caller, "rev-parse", "--absolute-git-dir").strip()
        r = self.run_check(10, GIT_INDEX_FILE=gitdir + "/index")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertEqual(self.snapshot(), before)

    def test_inherited_git_config_parameters_are_ignored(self):
        self.pr(10, {"lib/src/theme/new.dart": "n\n"})
        r = self.run_check(10, GIT_CONFIG_COUNT="1", GIT_CONFIG_KEY_0="core.bare",
                           GIT_CONFIG_VALUE_0="true")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)

    def test_hooks_do_not_run(self):
        self.pr(10, {"lib/src/theme/new.dart": "n\n"})
        marker = self.root / "hook-ran"
        for name in ("post-checkout", "post-merge", "pre-merge-commit",
                     "prepare-commit-msg", "commit-msg", "reference-transaction"):
            hook = self.caller / ".git" / "hooks" / name
            hook.write_text(f"#!/bin/sh\necho {name} >> '{marker}'\n")
            hook.chmod(0o755)
        r = self.run_check(10)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertFalse(marker.exists(), marker.read_text() if marker.exists() else "")

    def test_hook_on_worktree_add_does_not_run(self):
        # Only post-checkout: the one hook worktree add itself triggers.
        self.pr(10, {"lib/src/theme/new.dart": "n\n"})
        marker = self.root / "hook-ran"
        hook = self.caller / ".git" / "hooks" / "post-checkout"
        hook.write_text(f"#!/bin/sh\necho ran >> '{marker}'\n")
        hook.chmod(0o755)
        self.run_check(10)
        self.assertFalse(marker.exists())

    def test_hook_on_merge_does_not_run(self):
        self.pr(10, {"lib/src/theme/new.dart": "n\n"})
        self.advance_main({"lib/src/chat/later.dart": "l\n"})
        marker = self.root / "hook-ran"
        hook = self.caller / ".git" / "hooks" / "post-merge"
        hook.write_text(f"#!/bin/sh\necho ran >> '{marker}'\n")
        hook.chmod(0o755)
        self.run_check(10)
        self.assertFalse(marker.exists())

    def test_moved_worktree_of_caller_survives(self):
        self.pr(10, {"lib/src/theme/new.dart": "n\n"})
        other = self.root / "other-wt"
        git(self.caller, "worktree", "add", "-q", "--detach", str(other))
        moved = self.root / "other-wt.away"
        other.rename(moved)
        try:
            r = self.run_check(10)
            self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
            gitdir = git(self.caller, "rev-parse", "--absolute-git-dir").strip()
            self.assertTrue((Path(gitdir) / "worktrees" / "other-wt").is_dir(),
                            "the caller's worktree record was pruned")
        finally:
            if moved.exists():
                moved.rename(other)
        self.assertIn(str(other), git(self.caller, "worktree", "list"))

    def test_overlap_unknown_without_merge_base_is_not_all_clear(self):
        self.pr(10, {"lib/src/theme/new.dart": "n\n"})
        self.pr(11, {"lib/src/theme/other.dart": "o\n"})
        self.advance_main({"lib/src/chat/m1.dart": "1\n"})
        self.advance_main({"lib/src/chat/m2.dart": "2\n"})
        shallow = self.root / "shallow"
        git(self.root, "clone", "-q", "--depth", "1", "file://" + str(self.origin),
            str(shallow))
        r = self.run_check(10, "--others", 11, cwd=shallow)
        out = r.stdout + r.stderr
        self.assertIn("overlap UNKNOWN for #11 (no merge base; shallow clone? "
                      "git fetch --unshallow)", out)
        self.assertIn("WARNING", out)
        self.assertNotIn("no shared library directory with #11", out)

    def test_rename_counts_source_and_target_directory(self):
        git(self.seed, "checkout", "-q", "-B", "pr10", "main")
        (self.seed / "lib/src/chat").mkdir(parents=True, exist_ok=True)
        git(self.seed, "mv", "lib/src/theme/a.dart", "lib/src/chat/a.dart")
        git(self.seed, "commit", "-q", "-m", "rename")
        git(self.seed, "push", "-q", "origin", "pr10:refs/pull/10/head")
        git(self.seed, "checkout", "-q", "main")
        self.pr(11, {"lib/src/theme/b.dart": "11\n"})
        self.pr(12, {"lib/src/chat/zzz.dart": "12\n"})
        r = self.run_check(10, "--others", 11, 12)
        self.assertIn("overlap with #11: lib/src/theme/ (1 files here, 1 there)", r.stdout)
        self.assertIn("overlap with #12: lib/src/chat/ (1 files here, 1 there)", r.stdout)

    def test_already_merged_pr_exits_1(self):
        git(self.seed, "push", "-q", "origin", "main:refs/pull/10/head")
        r = self.run_check(10)
        self.assertEqual(r.returncode, 1, r.stdout + r.stderr)
        self.assertIn("already contained in base", r.stdout + r.stderr)
        self.assertFalse(self.log.exists())
        self.assert_clean_up()

    def test_pass_names_head_sha_and_how_to_arm(self):
        self.pr(10, {"lib/src/chat/new.dart": "n\n"})
        head = git(self.origin, "rev-parse", "refs/pull/10/head").strip()
        r = self.run_check(10)
        self.assertEqual(r.returncode, 0)
        self.assertIn(f"gh pr merge --auto --squash --match-head-commit {head}", r.stdout)
        self.assertIn("rerun after ANY push to the PR or to main", r.stdout)

    def test_sigkill_leftovers_are_swept_by_the_next_run(self):
        self.pr(10, {"lib/src/chat/new.dart": "n\n"})
        p = self.spawn_sleeping()
        os.killpg(p.pid, signal.SIGKILL)
        p.wait(timeout=30)
        self.assertEqual(len(self.worktrees()), 2)
        self.assertTrue(list(self.tmp.iterdir()))
        self.assertIn("refs/premerge/", git(self.caller, "for-each-ref", "refs/premerge"))
        r = self.run_check(10)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assert_clean_up()

    def test_sweep_leaves_a_live_runs_files_alone(self):
        self.pr(10, {"lib/src/chat/new.dart": "n\n"})
        p = self.spawn_sleeping()
        try:
            r = self.run_check(10)  # a second run while the first is alive
            self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
            self.assertEqual(len(self.worktrees()), 2)  # the live run's tree
            self.assertTrue(list(self.tmp.iterdir()))
        finally:
            os.killpg(p.pid, signal.SIGKILL)
            p.wait(timeout=30)

    def test_keep_survives_the_next_run(self):
        self.pr(10, {"lib/src/chat/new.dart": "n\n"})
        self.assertEqual(self.run_check(10, "--keep").returncode, 0)
        self.assertEqual(self.run_check(10).returncode, 0)
        self.assertEqual(len(self.worktrees()), 2)
        self.assertEqual(len(list(self.tmp.iterdir())), 1)

    def test_fetch_leaves_remote_tracking_ref_and_fetch_head_alone(self):
        self.pr(10, {"lib/src/chat/new.dart": "n\n"})
        self.advance_main({"lib/src/chat/later.dart": "l\n"})
        tracking = git(self.caller, "rev-parse", "refs/remotes/origin/main")
        gitdir = Path(git(self.caller, "rev-parse", "--absolute-git-dir").strip())
        self.assertFalse((gitdir / "FETCH_HEAD").exists())
        r = self.run_check(10)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertEqual(git(self.caller, "rev-parse", "refs/remotes/origin/main"),
                         tracking)
        self.assertFalse((gitdir / "FETCH_HEAD").exists())

    def test_rerere_does_not_hide_a_conflict(self):
        self.pr(10, {"lib/src/theme/a.dart": "pr side\n"})
        self.advance_main({"lib/src/theme/a.dart": "main side\n"})
        git(self.caller, "config", "rerere.enabled", "true")
        git(self.caller, "config", "rerere.autoUpdate", "true")
        git(self.caller, "fetch", "-q", "origin", "refs/pull/10/head:refs/heads/pr10")
        git(self.caller, "pull", "-q", "origin", "main")
        git(self.caller, "merge", "-q", "pr10", check=False)
        self.write(self.caller, "lib/src/theme/a.dart", "resolved\n")
        git(self.caller, "add", "lib/src/theme/a.dart")
        git(self.caller, "commit", "-q", "-m", "resolve")
        git(self.caller, "reset", "-q", "--hard", "origin/main")
        self.assertTrue(list((self.caller / ".git" / "rr-cache").iterdir()))
        r = self.run_check(10)
        self.assertEqual(r.returncode, 2, r.stdout + r.stderr)
        self.assertIn("lib/src/theme/a.dart", r.stdout)

    def test_conflict_list_keeps_names_with_spaces_whole(self):
        self.pr(10, {"lib/src/theme/my file.dart": "pr\n"})
        self.advance_main({"lib/src/theme/my file.dart": "main\n"})
        r = self.run_check(10)
        self.assertEqual(r.returncode, 2, r.stdout + r.stderr)
        self.assertIn("  lib/src/theme/my file.dart\n", r.stdout)

    def test_sighup_exits_129_and_cleans_up(self):
        self.pr(10, {"lib/src/chat/new.dart": "n\n"})
        p = self.spawn_sleeping()
        p.send_signal(signal.SIGHUP)
        p.wait(timeout=30)
        self.assertEqual(p.returncode, 129)
        self.assert_clean_up()

    def test_overlap_unknown_when_only_this_prs_merge_base_is_missing(self):
        self.pr(10, {"lib/src/theme/new.dart": "n\n"})
        self.advance_main({"lib/src/chat/m1.dart": "1\n"})
        self.advance_main({"lib/src/chat/m2.dart": "2\n"})
        self.pr(11, {"lib/src/theme/other.dart": "o\n"})  # branches from main's tip
        shallow = self.root / "shallow"
        git(self.root, "clone", "-q", "--depth", "1", "file://" + str(self.origin),
            str(shallow))
        r = self.run_check(10, "--others", 11, cwd=shallow)
        out = r.stdout + r.stderr
        self.assertIn("overlap UNKNOWN for #11", out)
        self.assertNotIn("no shared library directory with #11", out)
        self.assertIn("WARNING", out)

    def test_overlap_unknown_when_only_the_other_prs_merge_base_is_missing(self):
        self.pr(11, {"lib/src/theme/other.dart": "o\n"})
        self.advance_main({"lib/src/chat/m1.dart": "1\n"})
        self.advance_main({"lib/src/chat/m2.dart": "2\n"})
        self.pr(10, {"lib/src/theme/new.dart": "n\n"})  # branches from main's tip
        shallow = self.root / "shallow"
        git(self.root, "clone", "-q", "--depth", "1", "file://" + str(self.origin),
            str(shallow))
        r = self.run_check(10, "--others", 11, cwd=shallow)
        out = r.stdout + r.stderr
        self.assertIn("overlap UNKNOWN for #11 (no merge base", out)
        self.assertNotIn("no shared library directory with #11", out)
        self.assertIn("WARNING", out)

    # sweep safety and nits ----------------------------------------------

    @staticmethod
    def pidns():
        try:
            return os.readlink("/proc/self/ns/pid")
        except OSError:
            return "-"

    def marker(self, pid, host=None, common=None, ns=None, tag="premerge_check"):
        host = host or subprocess.run(["hostname"], capture_output=True,
                                      text=True).stdout.strip()
        common = common or os.path.realpath(self.caller / ".git")
        return f"{tag} {pid} {host} {ns or self.pidns()} {common}\n"

    def lookalike(self, base, name, pidfile_text, with_tree=True):
        d = Path(base) / name
        d.mkdir(parents=True)
        (d / "important.txt").write_text("keep me\n")
        (d / "pid").write_text(pidfile_text)
        if with_tree:
            git(self.caller, "worktree", "add", "-q", "--detach", str(d / "tree"))
        return d

    def test_lookalike_folder_elsewhere_survives_the_sweep(self):
        self.pr(10, {"lib/src/chat/new.dart": "n\n"})
        d = self.lookalike(self.root / "projects", "premerge.docs12", "99999999\n")
        r = self.run_check(10)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertTrue((d / "important.txt").exists())
        self.assertIn(str(d / "tree"), git(self.caller, "worktree", "list"))

    def test_lookalike_folder_with_a_forged_marker_elsewhere_survives(self):
        self.pr(10, {"lib/src/chat/new.dart": "n\n"})
        d = self.lookalike(self.root / "projects", "premerge.docs12",
                           self.marker(99999999))
        r = self.run_check(10)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertTrue((d / "important.txt").exists())

    def test_lookalike_folder_in_tmpdir_survives_the_sweep(self):
        self.pr(10, {"lib/src/chat/new.dart": "n\n"})
        d = self.lookalike(self.tmp, "premerge.docs12", "99999999\n")
        bare = self.tmp / "premerge.other1"
        bare.mkdir()
        (bare / "pid").write_text("99999999\n")
        (bare / "important.txt").write_text("keep me\n")
        r = self.run_check(10)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertTrue((d / "important.txt").exists())
        self.assertTrue((bare / "important.txt").exists())

    def test_sweep_removes_a_bare_dir_with_our_marker_and_a_dead_pid(self):
        self.pr(10, {"lib/src/chat/new.dart": "n\n"})
        bare = self.tmp / "premerge.dead12"
        bare.mkdir()
        (bare / "pid").write_text(self.marker(99999999))
        r = self.run_check(10)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertFalse(bare.exists())

    def test_sweep_skips_a_marker_from_another_host(self):
        self.pr(10, {"lib/src/chat/new.dart": "n\n"})
        bare = self.tmp / "premerge.host12"
        bare.mkdir()
        (bare / "pid").write_text(self.marker(99999999, host="some-other-host"))
        self.run_check(10)
        self.assertTrue(bare.exists())

    def test_sweep_skips_a_marker_from_another_repo(self):
        self.pr(10, {"lib/src/chat/new.dart": "n\n"})
        bare = self.tmp / "premerge.repo12"
        bare.mkdir()
        (bare / "pid").write_text(self.marker(99999999, common="/somewhere/else/.git"))
        self.run_check(10)
        self.assertTrue(bare.exists())

    def test_sweep_keeps_a_run_that_ps_still_sees(self):
        # kill -0 reports EPERM as failure; a pid that exists but belongs to
        # another user must count as alive. ps shows every user's processes.
        self.pr(10, {"lib/src/chat/new.dart": "n\n"})
        real_ps = shutil.which("ps")
        stub = self.bin / "ps"
        stub.write_text(
            '#!/bin/bash\n[ "$1" = -p ] && [ "$2" = 99999999 ] && exit 0\n'
            f'exec {real_ps} "$@"\n')
        stub.chmod(0o755)
        bare = self.tmp / "premerge.live12"
        bare.mkdir()
        (bare / "pid").write_text(self.marker(99999999))
        self.run_check(10)
        self.assertTrue(bare.exists())

    def test_cleanup_falls_back_when_worktree_remove_is_refused(self):
        # A locked worktree makes `worktree remove --force` fail; the script
        # must still leave no registration and no temp dir.
        self.pr(10, {"lib/src/chat/new.dart": "n\n"})
        stub = self.bin / "flutter"
        stub.write_text(STUB_FLUTTER.replace(
            'echo "$PWD $*" >> "$STUB_LOG"',
            'echo "$PWD $*" >> "$STUB_LOG"\n'
            '[ "$1" = analyze ] && git worktree lock "$PWD"'))
        r = self.run_check(10)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assert_clean_up()

    def test_others_equal_to_the_pr_are_dropped(self):
        self.pr(10, {"lib/src/theme/a.dart": "10\n"})
        self.pr(11, {"lib/src/theme/b.dart": "11\n"})
        r = self.run_check(10, "--others", 10, 11)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertNotIn("#10: ", r.stdout.replace("head  #10  ", ""))
        self.assertNotIn("overlap with #10", r.stdout)
        self.assertIn("overlap with #11", r.stdout)

    def test_tmpdir_inside_the_repo_falls_back_to_tmp(self):
        self.pr(10, {"lib/src/chat/new.dart": "n\n"})
        inside = self.caller / "scratch"
        inside.mkdir()
        before = self.snapshot()
        r = self.run_check(10, TMPDIR=str(inside))
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertEqual(list(inside.iterdir()), [])
        for line in self.log.read_text().splitlines():
            self.assertFalse(line.startswith(str(self.caller)), line)
        self.assertEqual(self.snapshot(), before)


    def test_lookalike_cache_dir_with_a_fully_valid_marker_survives(self):
        # Right tag, host, repo and a dead pid: only the name (premerge.XXXXXX,
        # six characters) keeps it out of the sweep.
        self.pr(10, {"lib/src/chat/new.dart": "n\n"})
        d = self.tmp / "premerge.cache"
        d.mkdir()
        (d / "pid").write_text(self.marker(99999999))
        (d / "important.txt").write_text("keep me\n")
        r = self.run_check(10)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertTrue((d / "important.txt").exists())

    def test_sweep_skips_a_marker_with_another_tag(self):
        self.pr(10, {"lib/src/chat/new.dart": "n\n"})
        bare = self.tmp / "premerge.tag123"
        bare.mkdir()
        (bare / "pid").write_text(self.marker(99999999, tag="other_tool"))
        r = self.run_check(10)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertTrue(bare.exists())

    @unittest.skipUnless(os.path.exists("/proc/self/ns/pid"), "needs /proc")
    def test_sweep_skips_a_marker_from_another_pid_namespace(self):
        # A pid from another namespace says nothing about this one: alive.
        self.pr(10, {"lib/src/chat/new.dart": "n\n"})
        bare = self.tmp / "premerge.ns1234"
        bare.mkdir()
        (bare / "pid").write_text(self.marker(99999999, ns="pid:[4026539999]"))
        r = self.run_check(10)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertTrue(bare.exists())

    @unittest.skipUnless(os.path.exists("/proc/self/ns/pid"), "needs /proc")
    def test_sweep_removes_a_dead_run_from_the_same_pid_namespace(self):
        self.pr(10, {"lib/src/chat/new.dart": "n\n"})
        bare = self.tmp / "premerge.ns5678"
        bare.mkdir()
        (bare / "pid").write_text(self.marker(99999999, ns=self.pidns()))
        r = self.run_check(10)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertFalse(bare.exists())

    @unittest.skipUnless(os.path.exists("/proc/self/ns/pid"), "needs /proc")
    def test_the_marker_records_the_pid_namespace(self):
        self.pr(10, {"lib/src/chat/new.dart": "n\n"})
        p = self.spawn_sleeping()
        try:
            (live,) = list(self.tmp.iterdir())
            fields = (live / "pid").read_text().split(" ", 4)
            self.assertEqual(fields[0], "premerge_check")
            self.assertEqual(fields[3], self.pidns())
        finally:
            os.killpg(p.pid, signal.SIGKILL)
            p.wait(timeout=30)

    # affected tests -----------------------------------------------------

    FIXTURE = {
        "lib/src/kanban/kanban_screen.dart":
            "import 'kanban_model.dart';\npart 'kanban_view.dart';\n",
        "lib/src/kanban/kanban_view.dart": "part of 'kanban_screen.dart';\n",
        "lib/src/kanban/kanban_model.dart": "// model\n",
        "lib/src/kanban/kanban.dart": "export 'kanban_model.dart';\n",
        "lib/src/kanban/widgets/card.dart": "// card\n",
        "lib/src/shared/barrel.dart":
            "export 'package:hermes_app/src/kanban/kanban_model.dart';\n",
        "lib/src/shared/outer.dart": "export 'barrel.dart';\n",
        "test/kanban_direct_test.dart":
            "import 'package:hermes_app/src/kanban/kanban_model.dart';\n",
        "test/kanban_barrel_test.dart":
            "import 'package:hermes_app/src/kanban/kanban.dart';\n",
        "test/kanban_screen_test.dart":
            "import 'package:hermes_app/src/kanban/kanban_screen.dart';\n",
        "test/workflows/kanban_extras_workflow_test.dart":
            "import '../../lib/src/kanban/kanban_screen.dart';\n",
        "test/kanban_card_test.dart":
            "import 'package:hermes_app/src/kanban/widgets/card.dart';\n",
        "test/shared_barrel_test.dart":
            "import 'package:hermes_app/src/shared/barrel.dart';\n",
        "test/shared_outer_test.dart":
            "import 'package:hermes_app/src/shared/outer.dart';\n",
        "test/chat_test.dart": "import 'package:hermes_app/src/chat/c.dart';\n",
        "test/unrelated_test.dart": "void main() {}\n",
        "test/transitive_test.dart": "import 'support/helper.dart';\n",
        "test/support/helper.dart":
            "import 'package:hermes_app/src/kanban/kanban_model.dart';\n",
        "test/support/outer_helper.dart": "import 'helper.dart';\n",
        "test/support/helper_barrel.dart": "export 'helper.dart';\n",
        "test/deep_test.dart": "import 'support/outer_helper.dart';\n",
        "test/helper_barrel_test.dart": "import 'support/helper_barrel.dart';\n",
        "lib/l10n/l10n.dart": "// entry\n",
        "lib/l10n/arb/app_en.arb": "{}\n",
        "test/l10n/l10n_test.dart":
            "import 'package:hermes_app/l10n/l10n.dart';\n",
        "test/l10n_extra_test.dart": "void main() {}\n",
        "test/uses_l10n_test.dart":
            "import 'package:hermes_app/l10n/l10n.dart';\n",
        "test/other_pkg_test.dart":
            "import 'package:other_pkg/src/kanban/kanban_model.dart';\n",
        "test/conditional_test.dart":
            "import 'stub.dart'\n"
            "    if (dart.library.io) 'package:hermes_app/src/kanban/kanban_model.dart';\n",
    }

    def fixture(self):
        self.advance_main(self.FIXTURE)

    def ran(self):
        if not self.tests_log.exists():
            return []
        return [x for x in self.tests_log.read_bytes().decode().split("\0") if x]

    def test_lib_change_selects_c1_then_c2_in_priority_order(self):
        self.fixture()
        self.pr(10, {"lib/src/kanban/kanban_model.dart": "// changed\n"})
        r = self.run_check(10)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertEqual(
            self.ran(),
            [
                # (c1): direct importer, importer of an in-directory re-export,
                # importer of a re-export from another directory (one level)
                "test/kanban_barrel_test.dart",
                "test/kanban_direct_test.dart",
                "test/shared_barrel_test.dart",
                # (c2): every other importer of anything under lib/src/kanban/,
                # relative imports and subdirectories included, and through one
                # test helper (transitive_test). Not selected: a re-export of a
                # re-export, a helper of a helper (deep_test), conditional,
                # another package, unrelated.
                "test/kanban_card_test.dart",
                "test/kanban_screen_test.dart",
                "test/transitive_test.dart",
                "test/workflows/kanban_extras_workflow_test.dart",
            ],
        )
        self.assertIn("affected tests: 7 files run", r.stdout)
        self.assertNotIn("CAPPED", r.stdout)

    def test_cap_drops_only_c2_and_names_the_directories(self):
        self.fixture()
        self.pr(
            10,
            {
                "lib/src/kanban/kanban_model.dart": "// changed\n",
                "lib/src/chat/c.dart": "changed\n",
            },
        )
        r = self.run_check(10, PREMERGE_TEST_CAP="1", PREMERGE_ALLOW_CAPPED="1")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        # (c1) stays whole although it exceeds the cap.
        self.assertEqual(
            self.ran(),
            [
                "test/chat_test.dart",
                "test/kanban_barrel_test.dart",
                "test/kanban_direct_test.dart",
                "test/shared_barrel_test.dart",
            ],
        )
        line = [l for l in r.stdout.splitlines() if l.startswith("affected tests: CAPPED")]
        self.assertEqual(len(line), 1, r.stdout)
        self.assertIn("lib/src/kanban/", line[0])
        self.assertNotIn("lib/src/chat/", line[0])
        self.assertRegex(r.stdout, r"affected tests: 4 files run.*CAPPED")

    def capped_pr(self):
        self.fixture()
        self.pr(10, {"lib/src/kanban/kanban_model.dart": "// changed\n"})

    def test_capped_run_exits_7_and_the_pass_line_says_capped(self):
        self.capped_pr()
        r = self.run_check(10, PREMERGE_TEST_CAP="1")
        self.assertNotEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertEqual(r.returncode, 7, r.stdout + r.stderr)
        line = [l for l in r.stdout.splitlines() if l.startswith("PASS")]
        self.assertEqual(len(line), 1, r.stdout)
        self.assertIn("PASS (CAPPED: directory-wide tests skipped for lib/src/kanban/)", line[0])
        self.assertIn("PREMERGE_ALLOW_CAPPED", r.stderr)
        self.assertNotIn("safe to arm", r.stdout)

    def test_allow_capped_exits_0_and_still_says_capped(self):
        self.capped_pr()
        r = self.run_check(10, PREMERGE_TEST_CAP="1", PREMERGE_ALLOW_CAPPED="1")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        line = [l for l in r.stdout.splitlines() if l.startswith("PASS")]
        self.assertIn("PASS (CAPPED: directory-wide tests skipped for lib/src/kanban/)", line[0])
        self.assertIn("affected tests: CAPPED", r.stdout)

    def test_uncapped_pass_line_has_no_capped_and_exits_0(self):
        self.capped_pr()
        r = self.run_check(10, PREMERGE_TEST_CAP="7")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertNotIn("CAPPED", r.stdout)

    def test_failure_beats_capped(self):
        self.capped_pr()
        r = self.run_check(
            10,
            PREMERGE_TEST_CAP="1",
            PREMERGE_ALLOW_CAPPED="1",
            STUB_FAIL_FILES="test/kanban_barrel_test.dart",
        )
        self.assertEqual(r.returncode, 5, r.stdout + r.stderr)
        self.assertNotIn("PASS", r.stdout)
        r = self.run_check(
            10, PREMERGE_TEST_CAP="1", STUB_FAIL_FILES="test/kanban_barrel_test.dart"
        )
        self.assertEqual(r.returncode, 5, r.stdout + r.stderr)

    def test_budget_cut_beats_capped(self):
        self.capped_pr()
        r = self.run_check(
            10,
            PREMERGE_TEST_CAP="1",
            PREMERGE_TEST_BUDGET="2",
            PREMERGE_TEST_BATCH="1",
            STUB_SLEEP_ALL="3",
        )
        self.assertEqual(r.returncode, 6, r.stdout + r.stderr)
        self.assertNotIn("PASS", r.stdout)

    def test_cap_fills_c2_up_to_the_cap_in_order(self):
        self.fixture()
        self.pr(10, {"lib/src/kanban/kanban_model.dart": "// changed\n"})
        r = self.run_check(10, PREMERGE_TEST_CAP="4", PREMERGE_ALLOW_CAPPED="1")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertEqual(len(self.ran()), 4)
        self.assertEqual(self.ran()[3], "test/kanban_card_test.dart")
        self.assertIn("affected tests: CAPPED", r.stdout)

    def test_cap_that_fits_everything_is_not_capped(self):
        self.fixture()
        self.pr(10, {"lib/src/kanban/kanban_model.dart": "// changed\n"})
        r = self.run_check(10, PREMERGE_TEST_CAP="7")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertEqual(len(self.ran()), 7)
        self.assertNotIn("CAPPED", r.stdout)

    def test_part_file_change_selects_the_library_importers(self):
        self.fixture()
        self.pr(10, {"lib/src/kanban/kanban_view.dart": "part of 'kanban_screen.dart';\n// x\n"})
        r = self.run_check(10, PREMERGE_TEST_CAP="1", PREMERGE_ALLOW_CAPPED="1")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertEqual(
            self.ran(),
            [
                "test/kanban_screen_test.dart",
                "test/workflows/kanban_extras_workflow_test.dart",
            ],
        )

    def test_pr_changed_tests_run_and_deleted_ones_never(self):
        self.fixture()
        self.pr(
            10,
            {"test/kanban_direct_test.dart": "// edited\n"},
            delete=["test/unrelated_test.dart"],
            rename=[("test/chat_test.dart", "test/chat_renamed_test.dart")],
        )
        r = self.run_check(10)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertEqual(
            self.ran(),
            ["test/chat_renamed_test.dart", "test/kanban_direct_test.dart"],
        )

    def test_main_changed_tests_run_after_the_pr_changed_ones(self):
        self.fixture()
        self.pr(10, {"test/unrelated_test.dart": "// pr\n"})
        self.advance_main({"test/chat_test.dart": "// main moved\n"})
        r = self.run_check(10)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        # (a) before (b), though (b) sorts first by name.
        self.assertEqual(
            self.ran(), ["test/unrelated_test.dart", "test/chat_test.dart"]
        )

    def test_main_changes_before_the_merge_base_do_not_count(self):
        self.fixture()
        self.advance_main({"test/chat_test.dart": "// before the branch\n"})
        self.pr(10, {"README.md": "docs\n"})
        r = self.run_check(10)
        self.assertEqual(self.ran(), [])
        self.assertIn("affected tests: 0 files run", r.stdout)

    def test_lib_rename_counts_the_old_path_as_changed(self):
        self.fixture()
        self.pr(10, rename=[("lib/src/chat/c.dart", "lib/src/theme/c.dart")])
        r = self.run_check(10, PREMERGE_TEST_CAP="1", PREMERGE_ALLOW_CAPPED="1")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn("test/chat_test.dart", self.ran())

    def test_changed_test_helper_selects_its_importers_one_level(self):
        self.fixture()
        self.pr(10, {"test/support/helper.dart": "// edited\n"})
        r = self.run_check(10)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        # direct importer and importer of a re-export of the helper; not
        # deep_test, which reaches it through another helper
        self.assertEqual(
            self.ran(), ["test/helper_barrel_test.dart", "test/transitive_test.dart"]
        )

    def test_arb_change_selects_l10n_tests_then_entry_importers(self):
        self.fixture()
        self.pr(10, {"lib/l10n/arb/app_en.arb": '{"a": "b"}\n'})
        r = self.run_check(10)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertEqual(
            self.ran(),
            [
                "test/l10n/l10n_test.dart",  # test/l10n* always (c1)
                "test/l10n_extra_test.dart",
                "test/uses_l10n_test.dart",  # (c2) importer of lib/l10n/
            ],
        )

    def test_arb_change_under_a_small_cap_keeps_l10n_tests_and_names_the_dir(self):
        self.fixture()
        self.pr(10, {"lib/l10n/arb/app_de.arb": '{"a": "b"}\n'})
        r = self.run_check(10, PREMERGE_TEST_CAP="1", PREMERGE_ALLOW_CAPPED="1")
        self.assertEqual(
            self.ran(), ["test/l10n/l10n_test.dart", "test/l10n_extra_test.dart"]
        )
        line = [l for l in r.stdout.splitlines() if l.startswith("affected tests: CAPPED")]
        self.assertIn("lib/l10n/", line[0])

    def test_l10n_yaml_change_selects_like_an_arb_change(self):
        self.fixture()
        self.pr(10, {"l10n.yaml": "arb-dir: lib/l10n/arb\n"})
        r = self.run_check(10)
        self.assertEqual(len(self.ran()), 3, r.stdout)

    def test_non_l10n_change_does_not_select_l10n_tests(self):
        self.fixture()
        self.pr(10, {"lib/src/chat/c.dart": "changed\n"})
        self.run_check(10)
        self.assertEqual(self.ran(), ["test/chat_test.dart"])

    def test_the_budget_covers_the_whole_affected_run(self):
        self.fixture()
        self.pr(10, {"lib/src/kanban/kanban_model.dart": "// changed\n"})
        r = self.run_check(10, PREMERGE_TEST_BUDGET="3", PREMERGE_TEST_BATCH="1",
                           STUB_SLEEP_ALL="2")
        self.assertEqual(r.returncode, 6, r.stdout + r.stderr)
        self.assertIn("CUT SHORT after 1/7 files", r.stderr)

    def test_the_incident_workflow_test_is_selected(self):
        # #1196 rewrote the workflow test on main; #1213 changed the screen.
        self.fixture()
        self.pr(1213, {"lib/src/kanban/kanban_screen.dart":
                       "import 'kanban_model.dart';\npart 'kanban_view.dart';\n// 1213\n"})
        self.advance_main({"test/workflows/kanban_extras_workflow_test.dart": "// 1196\n"})
        r = self.run_check(1213, PREMERGE_TEST_CAP="1", PREMERGE_ALLOW_CAPPED="1")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn("test/workflows/kanban_extras_workflow_test.dart", self.ran())

    def test_nothing_selected_runs_no_test_command_and_says_zero(self):
        self.fixture()
        self.pr(10, {"README.md": "docs\n"})
        r = self.run_check(10)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn("affected tests: 0 files run", r.stdout)
        tests = [l for l in self.log.read_text().splitlines() if " test " in l]
        self.assertEqual(len(tests), 1, tests)  # only test/architecture
        self.assertIn("test/architecture", tests[0])

    def test_deleted_test_alone_selects_nothing(self):
        self.fixture()
        self.pr(10, delete=["test/unrelated_test.dart"])
        r = self.run_check(10)
        self.assertEqual(self.ran(), [])
        self.assertIn("affected tests: 0 files run", r.stdout)

    def test_package_name_comes_from_pubspec(self):
        self.fixture()
        self.advance_main(
            {
                "pubspec.yaml": "name: other_app\n",
                "test/renamed_pkg_test.dart":
                    "import 'package:other_app/src/kanban/kanban_model.dart';\n",
            }
        )
        self.pr(10, {"lib/src/kanban/kanban_model.dart": "// changed\n"})
        r = self.run_check(10, PREMERGE_TEST_CAP="1", PREMERGE_ALLOW_CAPPED="1")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertEqual(self.ran(), ["test/renamed_pkg_test.dart"])

    def test_missing_pubspec_is_an_error_not_an_empty_selection(self):
        self.fixture()
        self.pr(10, delete=["pubspec.yaml"])
        r = self.run_check(10)
        self.assertEqual(r.returncode, 1, r.stdout + r.stderr)
        self.assertIn("pubspec", r.stdout + r.stderr)
        self.assertNotIn("PASS", r.stdout)
        self.assertEqual(self.ran(), [])
        self.assert_clean_up()

    def test_file_names_with_spaces_and_newlines_reach_flutter_whole(self):
        odd = ["test/my file_test.dart", "test/a\nb_test.dart", "test/it's $x_test.dart"]
        self.pr(10, {n: "void main() {}\n" for n in odd})
        r = self.run_check(10)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertEqual(self.ran(), sorted(odd))

    def test_concurrency_defaults_to_4_and_is_configurable(self):
        self.fixture()
        self.pr(10, {"test/unrelated_test.dart": "// pr\n"})
        self.run_check(10)
        self.assertIn("--concurrency=4 test/unrelated_test.dart", self.log.read_text())
        self.log.unlink()
        self.run_check(10, PREMERGE_TEST_CONCURRENCY="2")
        self.assertIn("--concurrency=2 test/unrelated_test.dart", self.log.read_text())

    def test_bad_numeric_settings_exit_1(self):
        self.pr(10, {"README.md": "docs\n"})
        for var in ("PREMERGE_TEST_BUDGET", "PREMERGE_TEST_CAP",
                    "PREMERGE_TEST_CONCURRENCY", "PREMERGE_TEST_BATCH"):
            for bad in ("abc", "0", "-1"):
                r = self.run_check(10, **{var: bad})
                self.assertEqual(r.returncode, 1, (var, bad, r.stdout, r.stderr))
                self.assertIn(var, r.stdout + r.stderr)

    def test_failing_affected_tests_exit_5_and_name_the_files(self):
        self.fixture()
        self.pr(10, {"lib/src/kanban/kanban_model.dart": "// changed\n"})
        r = self.run_check(
            10,
            PREMERGE_TEST_BATCH="2",
            STUB_FAIL_FILES="test/kanban_direct_test.dart,test/kanban_card_test.dart",
        )
        self.assertEqual(r.returncode, 5, r.stdout + r.stderr)
        block = r.stderr.split("affected tests failed")[1]
        self.assertIn("test/kanban_direct_test.dart", block)
        self.assertIn("test/kanban_card_test.dart", block)
        self.assertNotIn("test/kanban_barrel_test.dart", block)
        self.assertNotIn("test/kanban_screen_test.dart", block)
        self.assertNotIn("PASS", r.stdout)
        self.assertEqual(len(self.ran()), 7, "later batches still run after a failure")
        self.assert_clean_up()

    def test_failure_without_file_names_lists_the_whole_batch(self):
        self.fixture()
        self.pr(10, {"test/unrelated_test.dart": "// pr\n", "test/chat_test.dart": "// pr\n"})
        r = self.run_check(10, STUB_FILES_EXIT="1")
        self.assertEqual(r.returncode, 5, r.stdout + r.stderr)
        self.assertIn("test/unrelated_test.dart", r.stderr)
        self.assertIn("test/chat_test.dart", r.stderr)
        self.assertIn("could not tell", r.stderr)

    def test_architecture_failure_runs_no_affected_tests(self):
        self.fixture()
        self.pr(10, {"test/unrelated_test.dart": "// pr\n"})
        r = self.run_check(10, STUB_TEST_EXIT="1")
        self.assertEqual(r.returncode, 4, r.stdout + r.stderr)
        self.assertEqual(self.ran(), [])

    def test_analyze_failure_runs_no_affected_tests(self):
        self.fixture()
        self.pr(10, {"test/unrelated_test.dart": "// pr\n"})
        r = self.run_check(10, STUB_ANALYZE_EXIT="1")
        self.assertEqual(r.returncode, 3, r.stdout + r.stderr)
        self.assertEqual(self.ran(), [])

    def cut_run(self, **extra):
        self.fixture()
        self.pr(10, {"lib/src/kanban/kanban_model.dart": "// changed\n"})
        return self.run_check(
            10,
            PREMERGE_TEST_BUDGET="2",
            PREMERGE_TEST_BATCH="1",
            STUB_SLEEP_FILE="test/kanban_direct_test.dart",
            **extra,
        )

    @staticmethod
    def alive(pid):
        try:
            state = Path(f"/proc/{pid}/stat").read_text().rsplit(") ", 1)[1][0]
            return state != "Z"
        except OSError:
            return False

    def test_budget_cut_exits_6_lists_what_did_not_run_and_is_not_a_pass(self):
        t0 = time.time()
        r = self.cut_run()
        self.assertLess(time.time() - t0, 40)
        out = r.stdout + r.stderr
        self.assertEqual(r.returncode, 6, out)
        self.assertIn(
            "affected tests CUT SHORT after 1/7 files (budget 2 s); not a pass", out
        )
        self.assertNotIn("PASS", r.stdout)
        tail = out.split("CUT SHORT")[1]
        for f in ("test/kanban_direct_test.dart", "test/shared_barrel_test.dart",
                  "test/kanban_card_test.dart", "test/kanban_screen_test.dart",
                  "test/workflows/kanban_extras_workflow_test.dart"):
            self.assertIn(f, tail)
        self.assertNotIn("test/kanban_barrel_test.dart", tail)
        self.assertEqual(self.ran(), ["test/kanban_barrel_test.dart",
                                      "test/kanban_direct_test.dart"])
        self.assert_clean_up()

    # the catalog test -----------------------------------------------------

    CATALOG = "test/widgetbook_test.dart"

    def catalog_calls(self):
        """The flutter test lines that name the catalog file."""
        return [l.split(" ", 1)[1] for l in self.log.read_text().splitlines()
                if self.CATALOG in l and " test " in f" {l.split(' ', 1)[1]} "]

    def catalog_pr(self):
        self.fixture()
        self.pr(10, {self.CATALOG: "void main() {}\n",
                     "test/unrelated_test.dart": "// pr\n"})

    def test_the_catalog_file_runs_in_sequential_parts_never_in_a_batch(self):
        self.catalog_pr()
        r = self.run_check(10, CATALOG_PARTS="3")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        calls = self.catalog_calls()
        self.assertEqual(
            [c.split("test ", 1)[1] for c in calls],
            [f"--no-pub --total-shards 3 --shard-index {i} {self.CATALOG}"
             for i in range(3)],
        )
        # No call mixes it with another file, and no call lacks the split.
        for c in calls:
            self.assertEqual(c.count("_test.dart"), 1, c)
        self.assertIn("unrelated_test.dart", self.log.read_text())
        self.assertIn("affected tests: 2 files run", r.stdout)

    def test_the_catalog_defaults_to_six_parts_and_runs_after_the_batches(self):
        self.catalog_pr()
        r = self.run_check(10)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertEqual(len(self.catalog_calls()), 6)
        self.assertEqual(self.ran()[-1], self.CATALOG)
        self.assertEqual(self.ran().count(self.CATALOG), 6)

    def test_a_bad_catalog_parts_value_exits_1(self):
        self.catalog_pr()
        for bad in ("abc", "0", "-1", "100"):
            r = self.run_check(10, CATALOG_PARTS=bad)
            self.assertEqual(r.returncode, 1, (bad, r.stdout, r.stderr))
            self.assertIn("CATALOG_PARTS", r.stdout + r.stderr)

    def test_a_failing_catalog_part_exits_5_and_the_other_parts_still_run(self):
        self.catalog_pr()
        stub = self.bin / "flutter"
        stub.write_text(stub.read_text().replace(
            "  test)\n",
            "  test)\n    [ \"${STUB_FAIL_SHARD:-}\" != \"\" ] && "
            "case \"$*\" in *\"--shard-index $STUB_FAIL_SHARD \"*) "
            "echo \"00:01 +0 -1: loading x [E]\"; exit 1;; esac\n", 1))
        r = self.run_check(10, CATALOG_PARTS="3", STUB_FAIL_SHARD="1")
        self.assertEqual(r.returncode, 5, r.stdout + r.stderr)
        self.assertEqual(len(self.catalog_calls()), 3)
        block = r.stderr.split("affected tests failed")[1]
        self.assertIn(self.CATALOG, block)
        self.assertNotIn("unrelated_test.dart", block)
        self.assertNotIn("PASS", r.stdout)

    def test_a_cut_inside_the_catalog_parts_lists_it_as_not_run(self):
        self.catalog_pr()
        r = self.run_check(
            10, CATALOG_PARTS="3", PREMERGE_TEST_BUDGET="2",
            STUB_SLEEP_FILE=self.CATALOG)
        out = r.stdout + r.stderr
        self.assertEqual(r.returncode, 6, out)
        self.assertIn("CUT SHORT after 1/2 files", out)
        self.assertIn(self.CATALOG, out.split("files not run:")[1])
        self.assertNotIn("unrelated_test.dart", out.split("files not run:")[1])
        self.assertEqual(len(self.catalog_calls()), 1, "a cut stops the later parts")
        self.assertNotIn("PASS", r.stdout)
        self.assert_clean_up()

    def test_budget_cut_kills_the_whole_process_tree(self):
        pidfile = self.root / "grandchild.pid"
        self.cut_run(STUB_GRANDCHILD=str(pidfile))
        pid = int(pidfile.read_text())
        deadline = time.time() + 5
        while self.alive(pid) and time.time() < deadline:
            time.sleep(0.1)
        self.assertFalse(self.alive(pid), "a grandchild of flutter test survived the cut")

    def test_budget_cut_kills_processes_that_ignore_term(self):
        pidfile = self.root / "grandchild.pid"
        r = self.cut_run(STUB_GRANDCHILD=str(pidfile), STUB_IGNORE_TERM="1")
        self.assertEqual(r.returncode, 6, r.stdout + r.stderr)
        pid = int(pidfile.read_text())
        deadline = time.time() + 5
        while self.alive(pid) and time.time() < deadline:
            time.sleep(0.1)
        self.assertFalse(self.alive(pid), "a process that ignores TERM survived the cut")

    def test_a_failure_before_the_cut_still_exits_5(self):
        r = self.cut_run(STUB_FAIL_FILES="test/kanban_barrel_test.dart")
        self.assertEqual(r.returncode, 5, r.stdout + r.stderr)
        self.assertIn("CUT SHORT", r.stdout + r.stderr)

    def test_sigterm_during_affected_tests_cleans_up_and_kills_the_run(self):
        self.fixture()
        self.pr(10, {"test/unrelated_test.dart": "// pr\n"})
        pidfile = self.root / "grandchild.pid"
        out = (self.root / "out.txt").open("w")
        self.addCleanup(out.close)
        p = subprocess.Popen(
            ["bash", str(SCRIPT), "10"], cwd=self.caller,
            env=self.env(STUB_SLEEP_FILE="test/unrelated_test.dart",
                         STUB_GRANDCHILD=str(pidfile)),
            stdout=out, stderr=subprocess.STDOUT, start_new_session=True,
        )
        self.addCleanup(lambda: p.poll() is None and os.killpg(p.pid, signal.SIGKILL))
        deadline = time.time() + 60
        while not pidfile.exists() and time.time() < deadline:
            time.sleep(0.1)
        self.assertTrue(pidfile.exists(), "affected tests never started")
        pid = int(pidfile.read_text())
        p.send_signal(signal.SIGTERM)
        p.wait(timeout=30)
        self.assert_clean_up()
        deadline = time.time() + 5
        while self.alive(pid) and time.time() < deadline:
            time.sleep(0.1)
        self.assertFalse(self.alive(pid))

    # a pass is tied to a base -------------------------------------------

    def test_pass_names_head_and_base_and_the_rerun_rule(self):
        self.pr(10, {"lib/src/chat/new.dart": "n\n"})
        self.advance_main({"lib/src/chat/later.dart": "l\n"})
        base = git(self.origin, "rev-parse", "main").strip()
        head = git(self.origin, "rev-parse", "refs/pull/10/head").strip()
        r = self.run_check(10)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        passed = r.stdout.split("PASS")[1]
        self.assertIn(base, passed)
        self.assertIn(head, passed)
        self.assertIn(
            f"merge or arm only while origin/main still equals {base}; rerun otherwise",
            passed,
        )
        self.assertIn(f"--match-head-commit {head}", passed)

    # --stack ---------------------------------------------------------------

    def test_stack_prs_are_merged_before_this_one(self):
        self.pr(11, {"lib/src/chat/s11.dart": "11\n"})
        self.pr(12, {"lib/src/theme/s12.dart": "12\n"})
        self.pr(10, {"lib/src/theme/p10.dart": "10\n"})
        stub = self.bin / "flutter"
        stub.write_text(STUB_FLUTTER.replace(
            'echo "$PWD $*" >> "$STUB_LOG"',
            'echo "$PWD $*" >> "$STUB_LOG"\n'
            '[ "$1" = analyze ] && ls lib/src/chat lib/src/theme >> "$STUB_LOG"'))
        r = self.run_check(10, "--stack", 11, 12)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        log = self.log.read_text()
        for f in ("s11.dart", "s12.dart", "p10.dart"):
            self.assertIn(f, log)
        for n in (11, 12):
            head = git(self.origin, "rev-parse", f"refs/pull/{n}/head").strip()
            self.assertIn(head, r.stdout)
        self.assertIn("stacked: #11 #12", r.stdout.split("PASS")[1])
        self.assert_clean_up()

    def test_stack_where_only_the_stacked_pr_is_capped_exits_7(self):
        self.fixture()
        self.pr(11, {"lib/src/kanban/kanban_model.dart": "// changed\n"})
        self.pr(10, {"README.md": "docs\n"})
        r = self.run_check(10, "--stack", 11, PREMERGE_TEST_CAP="1")
        self.assertEqual(r.returncode, 7, r.stdout + r.stderr)
        line = [l for l in r.stdout.splitlines() if l.startswith("PASS")]
        self.assertEqual(len(line), 1, r.stdout)
        self.assertIn("PASS (CAPPED: directory-wide tests skipped for lib/src/kanban/)", line[0])

    def test_stack_selection_covers_the_union_of_all_prs(self):
        self.fixture()
        self.pr(11, {"lib/src/chat/c.dart": "changed\n"})
        self.pr(12, {"test/unrelated_test.dart": "// stacked\n"})
        self.pr(10, {"lib/src/kanban/kanban_model.dart": "// changed\n"})
        r = self.run_check(10, "--stack", 11, 12, PREMERGE_TEST_CAP="1", PREMERGE_ALLOW_CAPPED="1")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertEqual(
            self.ran(),
            [
                "test/unrelated_test.dart",  # (a) of #12
                "test/chat_test.dart",  # (c1) of #11
                "test/kanban_barrel_test.dart",  # (c1) of #10
                "test/kanban_direct_test.dart",
                "test/shared_barrel_test.dart",
            ],
        )
        self.assertIn("CAPPED", r.stdout)

    def test_stack_reproduces_the_incident(self):
        self.fixture()
        self.pr(1196, {"test/workflows/kanban_extras_workflow_test.dart": "// 1196\n"})
        self.pr(1213, {"lib/src/kanban/kanban_screen.dart":
                       "import 'kanban_model.dart';\npart 'kanban_view.dart';\n// 1213\n"})
        r = self.run_check(1213, "--stack", 1196, PREMERGE_TEST_CAP="1", PREMERGE_ALLOW_CAPPED="1")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertEqual(
            self.ran()[0], "test/workflows/kanban_extras_workflow_test.dart")

    def test_stack_conflict_exits_2_naming_the_stacked_pr(self):
        self.pr(11, {"lib/src/theme/a.dart": "eleven\n"})
        self.pr(12, {"lib/src/theme/a.dart": "twelve\n"})
        self.pr(13, {"README.md": "x\n"})
        r = self.run_check(13, "--stack", 11, 12)
        out = r.stdout + r.stderr
        self.assertEqual(r.returncode, 2, out)
        self.assertIn("CONFLICT: stacked #12 ", out)
        self.assertNotIn("stacked #11", out)
        self.assertIn("lib/src/theme/a.dart", out)
        r = self.run_check(13, "--stack", 12, 11)
        out = r.stdout + r.stderr
        self.assertEqual(r.returncode, 2, out)
        self.assertIn("CONFLICT: stacked #11 ", out)
        self.assertFalse(self.log.exists(), "no check may run after a conflict")
        self.assert_clean_up()

    def test_conflict_of_the_pr_itself_with_the_stack_names_the_pr(self):
        self.pr(11, {"lib/src/theme/a.dart": "eleven\n"})
        self.pr(10, {"lib/src/theme/a.dart": "ten\n"})
        r = self.run_check(10, "--stack", 11)
        out = r.stdout + r.stderr
        self.assertEqual(r.returncode, 2, out)
        self.assertIn("CONFLICT: #10 ", out)
        self.assertNotIn("stacked", out)

    def test_stack_usage_errors_exit_1(self):
        self.pr(10, {"README.md": "x\n"})
        for args in (["10", "--stack"], ["10", "--stack", "x"], ["10", "--stack", "999"]):
            r = self.run_check(*args)
            self.assertEqual(r.returncode, 1, (args, r.stdout, r.stderr))

    def test_stack_naming_the_pr_itself_is_dropped(self):
        self.pr(10, {"lib/src/theme/a.dart": "ten\n"})
        r = self.run_check(10, "--stack", 10)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertNotIn("stacked", r.stdout)

    def test_others_still_reports_overlap_with_a_stack(self):
        self.pr(10, {"lib/src/theme/a.dart": "10\n"})
        self.pr(11, {"lib/src/theme/b.dart": "11\n"})
        self.pr(12, {"lib/src/theme/new.dart": "12\n"})
        r = self.run_check(10, "--stack", 11, "--others", 12)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn("overlap with #12", r.stdout)
        self.assertNotIn("overlap with #11", r.stdout)


    # ref sweep and old markers ------------------------------------------------

    def tags(self):
        host = subprocess.run(["hostname"], capture_output=True, text=True).stdout.strip()
        import re as _re

        hosttag = _re.sub(r"[^A-Za-z0-9-]", "_", host)
        nstag = _re.sub(r"[^0-9]", "", self.pidns()) or "x"
        return hosttag, nstag

    def put_ref(self, name):
        git(self.caller, "update-ref", f"refs/premerge/{name}/base", "HEAD")

    def refs(self):
        return git(self.caller, "for-each-ref", "--format=%(refname)", "refs/premerge")

    def test_ref_sweep_removes_a_dead_run_of_this_host_and_namespace(self):
        self.pr(10, {"lib/src/chat/new.dart": "n\n"})
        host, ns = self.tags()
        self.put_ref(f"{host}.{ns}.99999999")
        self.assertEqual(self.run_check(10).returncode, 0)
        self.assertNotIn("99999999", self.refs())

    def test_ref_sweep_keeps_a_live_pid(self):
        self.pr(10, {"lib/src/chat/new.dart": "n\n"})
        host, ns = self.tags()
        self.put_ref(f"{host}.{ns}.{os.getpid()}")
        self.assertEqual(self.run_check(10).returncode, 0)
        self.assertIn(str(os.getpid()), self.refs())

    def test_ref_sweep_keeps_another_hosts_dead_pid(self):
        self.pr(10, {"lib/src/chat/new.dart": "n\n"})
        host, ns = self.tags()
        self.put_ref(f"other-host.{ns}.99999999")
        self.assertEqual(self.run_check(10).returncode, 0)
        self.assertIn("other-host", self.refs())

    @unittest.skipUnless(os.path.exists("/proc/self/ns/pid"), "needs /proc")
    def test_ref_sweep_keeps_another_pid_namespaces_dead_pid(self):
        self.pr(10, {"lib/src/chat/new.dart": "n\n"})
        host, ns = self.tags()
        self.put_ref(f"{host}.4026539999.99999999")
        self.assertEqual(self.run_check(10).returncode, 0)
        self.assertIn("4026539999", self.refs())

    def test_ref_sweep_keeps_legacy_pid_only_refs(self):
        self.pr(10, {"lib/src/chat/new.dart": "n\n"})
        self.put_ref("99999999")
        self.assertEqual(self.run_check(10).returncode, 0)
        self.assertIn("refs/premerge/99999999/base", self.refs())

    def old_marker(self, pid=99999999, host=None, common=None):
        host = host or subprocess.run(["hostname"], capture_output=True,
                                      text=True).stdout.strip()
        common = common or os.path.realpath(self.caller / ".git")
        return f"premerge_check {pid} {host} {common}\n"

    def test_sweep_removes_an_old_four_field_marker_of_this_host_and_repo(self):
        self.pr(10, {"lib/src/chat/new.dart": "n\n"})
        bare = self.tmp / "premerge.old123"
        bare.mkdir()
        (bare / "pid").write_text(self.old_marker())
        self.assertEqual(self.run_check(10).returncode, 0)
        self.assertFalse(bare.exists())

    def test_sweep_keeps_an_old_marker_of_another_host_or_repo_or_live_pid(self):
        self.pr(10, {"lib/src/chat/new.dart": "n\n"})
        cases = {
            "premerge.oldh12": self.old_marker(host="some-other-host"),
            "premerge.oldr12": self.old_marker(common="/somewhere/else/.git"),
            "premerge.oldl12": self.old_marker(pid=os.getpid()),
        }
        for name, text in cases.items():
            (self.tmp / name).mkdir()
            (self.tmp / name / "pid").write_text(text)
        self.assertEqual(self.run_check(10).returncode, 0)
        for name in cases:
            self.assertTrue((self.tmp / name).exists(), name)


if __name__ == "__main__":
    unittest.main()
