"""Tests for .claude/hooks/check_guard_freshness.py (the session-start warning)."""

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
    git(root, "add", "-A")
    git(root, "commit", "-q", "-m", "base")
    for i in range(behind):
        (root / "n.txt").write_text(str(i))
        git(root, "add", "n.txt")
        git(root, "commit", "-q", "-m", f"c{i}")
    tip = git(root, "rev-parse", "HEAD")
    if origin:
        git(root, "update-ref", "refs/remotes/origin/main", tip)
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
        (root / "n.txt").write_text("dirty")
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
            p.stdout.startswith(
                "WARNING: the Bash guard is not active in this session:"
            )
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

    def test_behind_more_than_limit_warns(self):
        self.assertWarns(run(self.repo(behind=MAX_BEHIND + 1)), str(MAX_BEHIND + 1))

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
        self.assertWarns(p, "diverged")

    def test_dirty_stale_mentions_clean_tree(self):
        p = run(self.repo(behind=MAX_BEHIND + 1, dirty=True))
        self.assertWarns(p, "clean")

    def test_clean_stale_does_not_mention_clean_tree(self):
        p = run(self.repo(behind=MAX_BEHIND + 1))
        self.assertNotIn("clean tree", p.stdout)

    def test_dirty_missing_guard_mentions_clean_tree(self):
        self.assertWarns(run(self.repo(guard=False, dirty=True)), "clean")

    def test_no_origin_ref_skips_lag_check(self):
        self.assertSilent(run(self.repo(origin=False)))

    def test_no_origin_ref_still_checks_guard(self):
        self.assertWarns(run(self.repo(origin=False, guard=False)), "guard_bash.py")

    def test_not_a_git_repo_is_quiet(self):
        d = self.tmp / "plain"
        d.mkdir()
        p = run(d)
        self.assertEqual(p.returncode, 0)
        self.assertNotIn("Traceback", p.stderr)

    def test_unset_and_missing_dir(self):
        for d in (None, self.tmp / "nope", ""):
            p = run(d)
            self.assertEqual(p.returncode, 0)
            self.assertNotIn("Traceback", p.stderr)

    def test_checkout_is_untouched(self):
        r = self.repo(behind=MAX_BEHIND + 1, dirty=True)
        before = (git(r, "rev-parse", "HEAD"), git(r, "status", "--porcelain"))
        run(r)
        after = (git(r, "rev-parse", "HEAD"), git(r, "status", "--porcelain"))
        self.assertEqual(before, after)


class SessionStartScriptTest(unittest.TestCase):
    def test_warns_without_remote_flag_and_exits_zero(self):
        with tempfile.TemporaryDirectory() as d:
            r = make_repo(Path(d) / "repo", guard=False)
            p = run(r, script=SESSION_START, extra_env={"CLAUDE_CODE_REMOTE": ""})
            self.assertEqual(p.returncode, 0, p.stderr)
            self.assertIn("WARNING: the Bash guard is not active", p.stdout)

    def test_current_tree_silent_locally(self):
        with tempfile.TemporaryDirectory() as d:
            r = make_repo(Path(d) / "repo")
            p = run(r, script=SESSION_START, extra_env={"CLAUDE_CODE_REMOTE": ""})
            self.assertEqual(p.returncode, 0)
            self.assertEqual(p.stdout, "")


if __name__ == "__main__":
    unittest.main()
