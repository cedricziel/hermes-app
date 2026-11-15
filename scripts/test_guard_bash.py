"""Tests for .claude/hooks/guard_bash.py (the agent Bash guard)."""

import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

HOOK = Path(__file__).resolve().parent.parent / ".claude" / "hooks" / "guard_bash.py"
spec = importlib.util.spec_from_file_location("guard_bash", HOOK)
guard = importlib.util.module_from_spec(spec)
spec.loader.exec_module(guard)


def git(cwd, *args):
    subprocess.run(["git", "-C", cwd, *args], check=True, capture_output=True)


class GuardTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        cls.repo = cls.tmp.name
        git(cls.repo, "init", "-q", "-b", "claude/pushed")
        git(
            cls.repo,
            "-c",
            "user.name=t",
            "-c",
            "user.email=t@t",
            "commit",
            "-q",
            "--allow-empty",
            "-m",
            "x",
        )
        git(cls.repo, "update-ref", "refs/remotes/origin/claude/pushed", "HEAD")
        hooks = Path(cls.repo, ".git", "hooks")
        hooks.mkdir(exist_ok=True)
        (hooks / "pre-commit").write_text("#!/bin/sh\n")
        cls.nohook = tempfile.TemporaryDirectory()
        git(cls.nohook.name, "init", "-q", "-b", "local-only")
        # git ships sample hooks only; make sure no pre-commit exists here
        pc = Path(cls.nohook.name, ".git", "hooks", "pre-commit")
        if pc.exists():
            pc.unlink()

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()
        cls.nohook.cleanup()

    def blocked(self, cmd, cwd=None, needle=None):
        msg = guard.check(cmd, cwd or self.repo)
        self.assertIsNotNone(msg, "should block: %s" % cmd)
        if needle:
            self.assertIn(needle, msg)

    def allowed(self, cmd, cwd=None):
        self.assertIsNone(guard.check(cmd, cwd or self.repo), "should allow: %s" % cmd)

    def test_no_verify(self):
        for c in [
            "git commit --no-verify -m x",
            "git push --no-verify",
            "git commit -n -m x",
            "git commit -nm x",
            "git commit -anm x",
            "git commit --amend -n",
            "git commit --no-verif -m x",
        ]:
            self.blocked(c)
        self.allowed("git commit -m 'use --no-verify never'")
        self.allowed("git commit -m -n")
        self.allowed("git commit -sm 'n'")

    def test_hooks_path(self):
        self.blocked("git config core.hooksPath /dev/null", needle="hooksPath")
        self.blocked("git config --global core.hookspath x")
        self.blocked("git -c core.hooksPath=x commit -m y")
        self.blocked("git config --unset core.hooksPath")
        self.allowed("git config core.hooksPath")
        self.allowed("git config --get core.hooksPath")
        self.allowed("git config user.name x")

    def test_stash(self):
        for c in [
            "git stash",
            "git stash pop",
            "git stash list",
            "git -C . stash push -u",
            "bash -c 'git stash'",
            'sh -c "cd x && git stash"',
            "echo a; git stash",
        ]:
            self.blocked(c, needle="branch")
        self.allowed("git log --grep stash")
        self.allowed("git commit -m 'drop the stash'")
        self.allowed("echo git stash")

    def test_add_all(self):
        for c in [
            "git add -A",
            "git add --all",
            "git add .",
            "git add :/",
            "git add -u",
            "FOO=1 git add -A",
            "git commit -a -m x",
            "git commit --all -m x",
            "git commit -am x",
            "git add -- .",
            "git add -Av",
            "git add ./",
        ]:
            self.blocked(c, needle="by name")
        self.allowed("git add lib/a.dart")
        self.allowed("git add -u lib")
        self.allowed("git add -p")
        self.allowed("git add lib/.hidden")
        self.allowed("git commit -m 'git add -A is banned'")
        self.allowed("git log --all")
        self.allowed("git commit --allow-empty -m x")

    def test_force_push(self):
        for c in [
            "git push --force",
            "git push -f",
            "git push --force-with-lease",
            "git push origin main --force",
            "git push --force-if-includes",
            "git push origin +main",
            "git -C . push --force",
            "cd x && git push origin +main",
            "/usr/bin/git push -f",
            "git push -uf origin x",
            "git push --forc",
            "git -c push.default=current push -f",
        ]:
            self.blocked(c, needle="merge")
        self.allowed("git push -u origin claude/x")
        self.allowed("git push")
        self.allowed("git push origin HEAD")
        self.allowed("git push --follow-tags")
        self.allowed("git push -o ci.skip origin x")

    def test_delete_push(self):
        for c in [
            "git push --delete origin x",
            "git push -d origin x",
            "git push origin :x",
            "git push origin --delete x",
            "git push --prune origin",
        ]:
            self.blocked(c, needle="remote branches")

    def test_rebase(self):
        self.blocked("git rebase origin/main", needle="merge")
        self.blocked("git rebase -i HEAD~3")
        self.allowed("git rebase --abort")
        self.allowed("git rebase --continue")
        self.allowed("git rebase origin/main", cwd=self.nohook.name)
        self.allowed("git merge origin/main")

    def test_missing_hook(self):
        self.blocked("git commit -m x", cwd=self.nohook.name, needle="setup_git_hooks")
        self.allowed("git commit -m x")
        self.allowed(
            "dart run tool/setup_git_hooks.dart && git commit -m x",
            cwd=self.nohook.name,
        )
        self.allowed("git status", cwd=self.nohook.name)
        self.allowed("git commit -m x", cwd="/nonexistent-dir-for-guard-test")

    def test_hermes_home(self):
        home = os.path.expanduser("~")
        for c in [
            "cat ~/.hermes/config.yaml",
            "ls $HOME/.hermes",
            "ls ${HOME}/.hermes/x",
            "rm -rf %s/.hermes" % home,
            "HERMES_HOME=~/.hermes hermes dashboard",
            "hermes dashboard --stop",
            "hermes dashboard --port 1 --stop",
            "bash -c 'ls ~/.hermes'",
            'cat "$HOME/.hermes/x"',
            "ls > ~/.hermes/x",
        ]:
            self.blocked(c, needle="dev-backend")
        self.allowed("hermes dashboard --port 9000")
        self.allowed("HERMES_HOME=/tmp/x/.hermes hermes dashboard")
        self.allowed("git commit -m 'never touch ~/.hermes'")
        self.allowed("echo ~/.hermes")
        self.allowed("ls ~/.hermes-other")
        self.allowed("gh pr create --body 'do not use ~/.hermes'")

    def test_kill(self):
        for c in [
            "pkill -f hermes",
            "killall hermes",
            "pkill -fl x",
            "sudo pkill -f x",
            "timeout 5 killall x",
        ]:
            self.blocked(c, needle="PID")
        self.allowed("pkill hermes")
        self.allowed("kill 123")
        self.allowed("echo killall")

    def test_evasion(self):
        self.blocked("git -c core.hooksPath=x commit -m y")
        self.blocked("env FOO=1 git stash")
        self.blocked("command git stash")
        self.blocked("nohup git push -f &")
        self.blocked("timeout 30 git push --force")
        self.blocked("time git add -A")
        self.blocked("echo $(git stash)")
        self.blocked("echo `git stash`")
        self.blocked("true | git push -f")
        self.blocked("a\ngit stash")
        self.blocked("false || git push -f")
        self.blocked("(git stash)")
        self.blocked("{ git stash; }")
        self.blocked("if true; then git stash; fi")
        self.blocked("eval 'git stash'")
        self.blocked("bash -lc 'git push -f'")
        self.blocked("bash <<EOF\ngit stash\nEOF")
        self.blocked("git --no-pager -C . stash")
        self.blocked("git 'stash'")
        self.blocked("git commit -m x 2>&1 --no-verify")

    def test_false_positive_traps(self):
        self.allowed(
            "git commit -m \"$(cat <<'EOF'\nfix: stash --force --no-verify git add -A ~/.hermes\nEOF\n)\""
        )
        self.allowed("cat <<'EOF' > notes.md\ngit stash\ngit push --force\nEOF")
        self.allowed("echo 'git push --force'")
        self.allowed("grep -- --force file")
        self.allowed("grep -rn 'git stash' docs")
        self.allowed("git log --oneline --grep='--force'")
        self.allowed("git diff 2>&1 | head")
        self.allowed("git status && git log --all")
        self.allowed("git merge origin/main")
        self.allowed("git fetch origin main")
        self.allowed("git checkout -b claude/x origin/main")
        self.allowed("flutter test 2>&1 | tail -5 # git stash")
        self.allowed("ls")
        self.allowed("")

    def test_main_exit_codes(self):
        def run(payload, raw=None):
            return subprocess.run(
                [sys.executable, "-I", str(HOOK)],
                input=raw if raw is not None else json.dumps(payload),
                capture_output=True,
                text=True,
            )

        r = run(
            {
                "tool_name": "Bash",
                "tool_input": {"command": "git stash"},
                "cwd": self.repo,
            }
        )
        self.assertEqual(r.returncode, 2)
        self.assertIn("Blocked", r.stderr)
        r = run(
            {"tool_name": "Bash", "tool_input": {"command": "ls"}, "cwd": self.repo}
        )
        self.assertEqual(r.returncode, 0)
        r = run({"tool_name": "Read", "tool_input": {}})
        self.assertEqual(r.returncode, 0)
        r = run(None, raw="not json")
        self.assertEqual(r.returncode, 0)
        self.assertIn("internal error", r.stderr)


if __name__ == "__main__":
    unittest.main()
