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
  test) exit "${STUB_TEST_EXIT:-0}" ;;
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

    def pr(self, n, files):
        """Publish refs/pull/<n>/head: main plus one commit changing files."""
        git(self.seed, "checkout", "-q", "-B", f"pr{n}", "main")
        for rel, text in files.items():
            self.write(self.seed, rel, text)
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
        self.assertNotIn("lib/src/chat/", r.stdout.split("overlap with")[1])

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

    def marker(self, pid, host=None, common=None):
        host = host or subprocess.run(["hostname"], capture_output=True,
                                      text=True).stdout.strip()
        common = common or os.path.realpath(self.caller / ".git")
        return f"premerge_check {pid} {host} {common}\n"

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


if __name__ == "__main__":
    unittest.main()
