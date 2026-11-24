"""Tests for .claude/hooks/check_guard_freshness.py (the session-start warning)."""

import hashlib
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

HELPER = (
    Path(__file__).resolve().parent.parent
    / ".claude"
    / "hooks"
    / "check_guard_freshness.py"
)
SESSION_START = HELPER.parent / "session-start.sh"
MAX_BEHIND = 20  # keep in step with MAX_COMMITS_BEHIND in the helper

GOOD_SETTINGS = {
    "hooks": {
        "PreToolUse": [
            {
                "matcher": "Bash",
                "hooks": [
                    {
                        "type": "command",
                        "command": 'python3 -I "$CLAUDE_PROJECT_DIR/.claude/hooks/guard_bash.py"',
                    }
                ],
            }
        ]
    }
}
FIX = (
    'git -C "$CLAUDE_PROJECT_DIR" fetch origin main && '
    'git -C "$CLAUDE_PROJECT_DIR" merge --ff-only origin/main'
)


def git(cwd, *args):
    env = dict(os.environ)
    env.update(
        GIT_AUTHOR_NAME="t",
        GIT_AUTHOR_EMAIL="t@example.com",
        GIT_COMMITTER_NAME="t",
        GIT_COMMITTER_EMAIL="t@example.com",
        GIT_CONFIG_GLOBAL="/dev/null",
        GIT_CONFIG_SYSTEM="/dev/null",
    )
    return subprocess.run(
        ["git", "-C", str(cwd), *args],
        check=True,
        capture_output=True,
        text=True,
        env=env,
    ).stdout.strip()


def make_repo(
    root,
    guard=True,
    settings=GOOD_SETTINGS,
    behind=0,
    detached=False,
    dirty=False,
    origin=True,
    ahead=0,
    real_origin=False,
):
    """A repo whose HEAD is `behind` commits behind a fake origin/main."""
    root = Path(root)
    subprocess.run(["git", "init", "-q", "-b", "main", str(root)], check=True)
    (root / ".claude" / "hooks").mkdir(parents=True)
    if guard:
        (root / ".claude" / "hooks" / "guard_bash.py").write_text("# guard\n")
    if settings is not None:
        text = settings if isinstance(settings, str) else json.dumps(settings)
        (root / ".claude" / "settings.json").write_text(text)
    (root / "n.txt").write_text("base")
    (root / "d.txt").write_text("base")
    git(root, "add", "-A")
    git(root, "commit", "-q", "-m", "base")
    for i in range(behind):
        (root / "n.txt").write_text(str(i))
        git(root, "add", "n.txt")
        git(root, "commit", "-q", "-m", f"c{i}")
    tip = git(root, "rev-parse", "HEAD")
    if origin:
        git(root, "update-ref", "refs/remotes/origin/main", tip)
    if real_origin:
        # a bare origin whose main is one commit ahead of the local origin/main
        bare = root.parent / "up.git"
        subprocess.run(["git", "init", "-q", "--bare", str(bare)], check=True)
        git(root, "checkout", "-q", "-b", "tmp")
        (root / "extra.txt").write_text("new upstream file")
        git(root, "add", "extra.txt")
        git(root, "commit", "-q", "-m", "upstream")
        git(root, "push", "-q", str(bare), "tmp:main")
        git(root, "checkout", "-q", "main")
        git(root, "branch", "-q", "-D", "tmp")
        git(root, "remote", "add", "origin", str(bare))
    if behind:
        git(root, "checkout", "-q", "--detach", f"HEAD~{behind}")
        if not detached:
            git(root, "checkout", "-q", "-B", "work")
    for i in range(ahead):
        (root / "a.txt").write_text(str(i))
        git(root, "add", "a.txt")
        git(root, "commit", "-q", "-m", f"a{i}")
    if detached and not behind:
        git(root, "checkout", "-q", "--detach")
    if dirty:
        (root / "d.txt").write_text("dirty")
    # stale stat info so a status that may write would refresh the index
    os.utime(root / "n.txt", (1_000_000_000, 1_000_000_000))
    return root


def run(project_dir, script=HELPER, extra_env=None):
    env = {k: v for k, v in os.environ.items() if k != "CLAUDE_PROJECT_DIR"}
    if project_dir is not None:
        env["CLAUDE_PROJECT_DIR"] = str(project_dir)
    env.update(extra_env or {})
    if script == HELPER:
        cmd = [sys.executable, "-I", str(script)]
    else:
        cmd = ["bash", str(script)]
    return subprocess.run(cmd, capture_output=True, text=True, env=env, timeout=60)


class FreshnessTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.tmp = Path(self._tmp.name)

    def repo(self, **kw):
        return make_repo(self.tmp / "repo", **kw)

    def assertSilent(self, p):
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual(p.stdout, "")

    def assertWarns(self, p, *needles):
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertTrue(
            p.stdout.startswith("WARNING: the Bash guard is not active in this session:")
            or p.stdout.startswith("WARNING: the Bash guard in this checkout is ")
        )
        self.assertIn(FIX, p.stdout)
        self.assertIn("new session", p.stdout)
        self.assertLessEqual(len(p.stdout.splitlines()), 8)
        low = p.stdout.lower()
        self.assertNotIn("stash", low)
        self.assertNotIn("reset", low)
        for n in needles:
            self.assertIn(n, p.stdout)

    def test_current_tree_is_silent(self):
        self.assertSilent(run(self.repo()))

    def test_missing_guard_file_warns(self):
        self.assertWarns(run(self.repo(guard=False)), "guard_bash.py")

    def test_missing_wiring_warns(self):
        self.assertWarns(run(self.repo(settings={"hooks": {}})), "PreToolUse")

    def test_missing_settings_file_warns(self):
        self.assertWarns(run(self.repo(settings=None)), "PreToolUse")

    def test_wiring_for_other_script_warns(self):
        s = json.loads(json.dumps(GOOD_SETTINGS))
        s["hooks"]["PreToolUse"][0]["hooks"][0]["command"] = "echo hi"
        self.assertWarns(run(self.repo(settings=s)), "PreToolUse")

    def test_wiring_in_wrong_event_warns(self):
        s = {"hooks": {"PostToolUse": GOOD_SETTINGS["hooks"]["PreToolUse"]}}
        self.assertWarns(run(self.repo(settings=s)), "PreToolUse")

    def test_malformed_settings_warns(self):
        self.assertWarns(run(self.repo(settings="{ not json")), "PreToolUse")

    def test_behind_more_than_limit_warns_with_lag_header(self):
        p = run(self.repo(behind=MAX_BEHIND + 1))
        self.assertWarns(p, str(MAX_BEHIND + 1))
        self.assertTrue(
            p.stdout.startswith(
                "WARNING: the Bash guard in this checkout is 21 commits behind origin/main:"
            )
        )
        self.assertNotIn("not active", p.stdout)

    def test_behind_and_unwired_uses_not_active_header(self):
        p = run(self.repo(guard=False, behind=MAX_BEHIND + 1))
        self.assertTrue(p.stdout.startswith("WARNING: the Bash guard is not active"))
        self.assertIn("commits behind", p.stdout)

    def _settings(self, matcher, command, event="PreToolUse"):
        group = {"hooks": [{"type": "command", "command": command}]}
        if matcher is not None:
            group["matcher"] = matcher
        return {"hooks": {event: [group]}}

    def test_wiring_matchers(self):
        cmd = 'python3 -I "$CLAUDE_PROJECT_DIR/.claude/hooks/guard_bash.py"'
        for m, ok in [
            ("Bash", True),
            ("*", True),
            ("", True),
            (None, True),
            ("Bash|Edit", True),
            (".*", True),
            ("Edit", False),
            ("Write|Edit", False),
        ]:
            with self.subTest(matcher=m):
                with tempfile.TemporaryDirectory() as d:
                    r = make_repo(Path(d) / "r", settings=self._settings(m, cmd))
                    p = run(r)
                    if ok:
                        self.assertSilent(p)
                    else:
                        self.assertWarns(p, "PreToolUse")

    def test_post_only_command_warns(self):
        cmd = 'python3 -I "$CLAUDE_PROJECT_DIR/.claude/hooks/guard_bash.py" --post'
        s = self._settings("Bash", cmd)
        self.assertWarns(run(self.repo(settings=s)), "PreToolUse")

    def test_echo_naming_the_file_warns(self):
        s = self._settings("Bash", "echo guard_bash.py")
        self.assertWarns(run(self.repo(settings=s)), "PreToolUse")

    def test_non_running_commands_warn(self):
        g = '"$CLAUDE_PROJECT_DIR/.claude/hooks/guard_bash.py"'
        for cmd in (
            "echo " + g,
            "cat .claude/hooks/guard_bash.py",
            "true || python3 x/.claude/hooks/guard_bash.py",
            "true; python3 x/.claude/hooks/guard_bash.py",
            "python3 x/.claude/hooks/guard_bash.py && true",
            "echo $(python3 x/.claude/hooks/guard_bash.py)",
            "python3 -c x/.claude/hooks/guard_bash.py",
            "python3 -I " + g + " --post",
            "python3 -V " + g,
            "python3 --version " + g,
            "python3 -h " + g,
            "python3 -I " + g + " < /dev/null",
            "python3 -I " + g + " <<< x",
            "python3 -I /tmp/evil/.claude/hooks/guard_bash.py",
            "python3 -I\n" + g,
            "python3\n-I " + g,
            "python3 -I\r\n" + g,
            "FOO=1 python3 -I " + g,
            "env python3 -I " + g,
            g,
        ):
            with self.subTest(cmd=cmd):
                with tempfile.TemporaryDirectory() as d:
                    r = make_repo(
                        Path(d) / "r", settings=self._settings("Bash", cmd)
                    )
                    self.assertWarns(run(r), "PreToolUse")

    def test_canonical_command_is_accepted(self):
        g = '"$CLAUDE_PROJECT_DIR/.claude/hooks/guard_bash.py"'
        for cmd in ("python3 -I " + g, "  python3   -I\t" + g + " "):
            with self.subTest(cmd=cmd):
                with tempfile.TemporaryDirectory() as d:
                    r = make_repo(
                        Path(d) / "r", settings=self._settings("Bash", cmd)
                    )
                    self.assertSilent(run(r))

    def test_real_repo_settings_are_recognised(self):
        # If the committed PreToolUse command changes, update GUARD_COMMANDS in
        # check_guard_freshness.py in the same PR.
        root = HELPER.parent.parent.parent
        settings = (root / ".claude" / "settings.json").read_text()
        with tempfile.TemporaryDirectory() as d:
            r = make_repo(Path(d) / "r", settings=settings)
            self.assertSilent(run(r))

    def test_committed_wiring_form_is_accepted(self):
        self.assertSilent(run(self.repo(settings=GOOD_SETTINGS)))

    def test_behind_exactly_limit_is_silent(self):
        self.assertSilent(run(self.repo(behind=MAX_BEHIND)))

    def test_detached_current_is_silent(self):
        self.assertSilent(run(self.repo(detached=True)))

    def test_detached_stale_warns(self):
        self.assertWarns(run(self.repo(detached=True, behind=MAX_BEHIND + 5)))

    def test_ahead_of_main_is_silent(self):
        self.assertSilent(run(self.repo(ahead=MAX_BEHIND + 5)))

    def test_diverged_and_stale_warns_and_says_so(self):
        p = run(self.repo(behind=MAX_BEHIND + 1, ahead=2))
        self.assertWarns(p, "diverged", 'merge origin/main')

    def test_dirty_stale_mentions_clean_tree(self):
        p = run(self.repo(behind=MAX_BEHIND + 1, dirty=True))
        self.assertWarns(p, "Local changes", "touch files the update changes")
        self.assertNotIn("clean tree", p.stdout)

    def test_clean_stale_does_not_mention_local_changes(self):
        p = run(self.repo(behind=MAX_BEHIND + 1))
        self.assertNotIn("Local changes", p.stdout)

    def test_dirty_missing_guard_mentions_clean_tree(self):
        self.assertWarns(run(self.repo(guard=False, dirty=True)), "Local changes")

    def test_no_origin_ref_skips_lag_check(self):
        self.assertSilent(run(self.repo(origin=False)))

    def test_no_origin_ref_still_checks_guard(self):
        self.assertWarns(run(self.repo(origin=False, guard=False)), "guard_bash.py")

    def _plain(self, guard, settings):
        d = self.tmp / "plain"
        (d / ".claude" / "hooks").mkdir(parents=True)
        if guard:
            (d / ".claude" / "hooks" / "guard_bash.py").write_text("# guard\n")
        if settings is not None:
            (d / ".claude" / "settings.json").write_text(json.dumps(settings))
        return d

    def test_non_git_dir_without_guard_warns(self):
        p = run(self._plain(False, None))
        self.assertWarns(p, "guard_bash.py", "PreToolUse")

    def test_non_git_dir_with_guard_is_silent(self):
        self.assertSilent(run(self._plain(True, GOOD_SETTINGS)))

    def test_git_missing_from_path_still_checks_files(self):
        empty = self.tmp / "emptybin"
        empty.mkdir()
        env = {"PATH": str(empty)}
        self.assertWarns(run(self.repo(guard=False), extra_env=env), "guard_bash.py")
        self.assertSilent(run(self._plain(True, GOOD_SETTINGS), extra_env=env))

    def test_unset_and_missing_dir(self):
        for d in (None, self.tmp / "nope", ""):
            p = run(d)
            self.assertEqual(p.returncode, 0)
            self.assertNotIn("Traceback", p.stderr)

    def snapshot(self, r):
        index = Path(r) / ".git" / "index"
        st = index.stat()
        env = dict(os.environ, GIT_OPTIONAL_LOCKS="0")
        status = subprocess.run(
            ["git", "-C", str(r), "status", "--porcelain"],
            capture_output=True,
            text=True,
            env=env,
        ).stdout
        return {
            "refs": git(r, "for-each-ref"),
            "head": git(r, "rev-parse", "HEAD"),
            "reflog": git(r, "reflog", "show", "--all"),
            "fetch_head": (Path(r) / ".git" / "FETCH_HEAD").exists(),
            "index_mtime": st.st_mtime_ns,
            "index_sha": hashlib.sha256(index.read_bytes()).hexdigest(),
            "status": status,
        }

    def test_checkout_is_untouched(self):
        r = self.repo(behind=MAX_BEHIND + 1, dirty=True, real_origin=True)
        before = self.snapshot(r)
        p = run(r)
        self.assertIn("commits behind", p.stdout)  # the warning path ran
        self.assertEqual(before, self.snapshot(r))


class SessionStartScriptTest(unittest.TestCase):
    def test_warns_without_remote_flag_and_exits_zero(self):
        with tempfile.TemporaryDirectory() as d:
            r = make_repo(Path(d) / "repo", guard=False)
            p = run(r, script=SESSION_START, extra_env={"CLAUDE_CODE_REMOTE": ""})
            self.assertEqual(p.returncode, 0, p.stderr)
            self.assertIn("WARNING: the Bash guard is not active", p.stdout)

    def test_remote_mode_warns_and_keeps_setup_steps(self):
        with tempfile.TemporaryDirectory() as d:
            d = Path(d)
            r = make_repo(d / "repo", guard=False)
            stubs = d / "stubs"
            stubs.mkdir()
            log = d / "calls.log"
            for name in ("claude", "flutter", "dart"):
                f = stubs / name
                f.write_text(f'#!/bin/sh\necho "{name} $*" >> "{log}"\nexit 0\n')
                f.chmod(0o755)
            path = str(stubs) + os.pathsep + os.environ["PATH"]
            p = run(
                r,
                script=SESSION_START,
                extra_env={"CLAUDE_CODE_REMOTE": "true", "PATH": path},
            )
            self.assertEqual(p.returncode, 0, p.stderr)
            self.assertIn("WARNING: the Bash guard is not active", p.stdout)
            calls = log.read_text()
            self.assertIn("claude plugin marketplace add", calls)
            self.assertIn("claude plugin install", calls)
            self.assertIn("flutter pub get", calls)
            self.assertIn("dart run tool/setup_git_hooks.dart", calls)

    def test_current_tree_silent_locally(self):
        with tempfile.TemporaryDirectory() as d:
            r = make_repo(Path(d) / "repo")
            p = run(r, script=SESSION_START, extra_env={"CLAUDE_CODE_REMOTE": ""})
            self.assertEqual(p.returncode, 0)
            self.assertEqual(p.stdout, "")


if __name__ == "__main__":
    unittest.main()
