"""Tests for .claude/hooks/guard_bash.py (the agent Bash guard)."""

import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

HOOK = Path(__file__).resolve().parent.parent / ".claude" / "hooks" / "guard_bash.py"
spec = importlib.util.spec_from_file_location("guard_bash", HOOK)
guard = importlib.util.module_from_spec(spec)
spec.loader.exec_module(guard)

REVIEW_BLOCK = [
    'git push origin HEAD --force',
    'git push --force-with-lease=main origin x',
    'git -c alias.p=push p -f',
    'env -i git stash',
    'sudo git stash',
    'git commit --no-ver -m x',
    'git commit -anm x',
    'git config --global core.hooksPath /dev/null',
    'rm -rf ~/.hermes',
    'cd ~ && ls .hermes',
    'git push origin :refs/heads/x',
    'git push --mirror',
    'git push origin +main',
    'git -C . push -f',
    "bash -c 'git stash'",
    '/usr/bin/git stash pop',
    'git stash list',
    'git add -A',
    'git add .',
    'git add -- .',
    'git commit -a -m x',
    'git -c core.hooksPath=/dev/null commit -m x',
    'git push -d origin x',
    'git push origin --delete x',
    'pkill -f dart',
    'killall flutter',
    'hermes dashboard --stop',
    'HERMES_HOME=~/.hermes hermes dashboard',
    'git rebase origin/main',
    'x=1; git rebase -i HEAD~2',
    'git commit -S -n -m x',
    'git commit --gpg-sign --no-verify -m x',
    'git commit -u -n -m x',
    'git commit --untracked-files --no-verify -m x',
    "bash -o pipefail -c 'git stash'",
    "bash -euo pipefail -c 'git push -f'",
    "echo 'git stash' | bash",
    "bash <<< 'git stash'",
    'sudo -u root git stash',
    'nice -n5 git stash',
    'watch -n1 git stash',
    'echo x > ~/.hermes/config.yaml',
    "printf 'k: v' >> $HOME/.hermes/.env",
    'rm -rf ~/.hermes*',
    'git pull --rebase',
    'git -c pull.rebase=true pull',
    'git commit . -m x',
    'GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.hooksPath GIT_CONFIG_VALUE_0=/dev/null git commit -m x',
    'rm .git/hooks/pre-commit',
    'gh pr merge 1 --delete-branch',
    'gh api -X DELETE repos/o/r/git/refs/heads/x',
    'git push origin HEAD:refs/heads/x --force-if-includes --force-with-lease',
    'git add *',
    'git add -u',
    'hermes dashboard',
    'git commit --al -m x',
    "bash -c -- 'git stash'",
    'git push --all --prune',
    'command git stash',
    'exec git stash',
    'time git stash',
    '{ git stash; }',
    '(cd /tmp && git stash)',
    'for f in a; do git stash; done',
    'eval git stash',
    '\\git stash',
    "g'i't stash",
    'git config --unset core.hooksPath',
    "git commit --no-verify -m 'x'",
    'git commit -nm x',
]

REVIEW_ALLOW = [
    'git add lib/a.dart test/b_test.dart',
    'git commit -m "docs: never git stash or --force"',
    'git push -u origin claude/x',
    'git rebase --abort',
    'HERMES_HOME=$PWD/.dart_tool/x hermes dashboard',
    'scripts/dev-backend.sh stop',
    'flutter test',
    "python3 - <<'EOF'\nimport subprocess\nsubprocess.run(['git','stash'])\nEOF",
    'git merge origin/main',
    'git fetch origin main && git merge origin/main',
    'git push',
    'git push origin HEAD',
    'git push --set-upstream origin claude/y',
    'git push origin claude/x:claude/x',
    'git push --tags',
    'git push -o ci.skip origin x',
    'git push --dry-run origin x',
    'git status && git diff --stat',
    'git commit -m "$(cat <<\'EOF\'\nfix: don\'t --no-verify (or git stash) ~/.hermes; git push -f\n\nCo-Authored-By: x\nEOF\n)"',
    "git commit -F- <<'EOF'\nchore: git add -A is banned\nEOF",
    'git log --oneline -5 | grep stash',
    "grep -rn 'git stash' docs/",
    "rg -- '--no-verify' .claude",
    "gh pr create --title x --body 'never git push --force; pkill -f'",
    'git config core.hooksPath',
    'git config --get core.hooksPath',
    'pgrep -f flutter',
    'kill 1234',
    'pkill -x dart',
    'ls ~/.hermes-app',
    'cat .dart_tool/hermes-dev/pid',
    'git add -u lib/',
    'git commit --amend --no-edit',
    "git commit -m 'feat: x' -m 'body with -n and -a'",
    'git restore ios/Runner.xcodeproj/project.pbxproj',
    'git rebase --continue',
    'git branch -D local-only',
    'git fetch --prune',
    'git worktree add ../wt -b claude/z',
    'dart run tool/setup_git_hooks.dart && git commit -m x',
    "echo '~/.hermes is the real home'",
    'cat > /tmp/x.sh <<EOF\ngit stash\nrm -rf ~/.hermes\nEOF',
    "git log -S'~/.hermes'",
    "git tag -a v1 -m 'force push note'",
    'python3 -I scripts/hermes_contracts.py resolve',
    './scripts/generate_hermes_api_client.sh',
    'scripts/verify.sh all',
    'git push origin claude/x',
    'git config get core.hooksPath',
    'git show HEAD:CLAUDE.md | head',
    "bash -c 'flutter analyze && flutter test'",
    'env FOO=1 flutter test',
    'timeout 60 flutter test',
    'git -C ../other status',
    'git commit -v -m x',
    "git commit -q -m 'x'",
    "git commit --author='A <a@b>' -m x",
    'git commit -m x --no-edit',
    'git diff origin/main...HEAD -- .claude/',
    "sed -i 's/a/b/' lib/x.dart",
]

ROUND2_BLOCK = [
    'hermes chat',
    'hermes dashboard --port 9000',
    '/usr/local/bin/hermes gateway run',
    'HERMES_HOME=/tmp/x true; hermes dashboard',
    'HERMES_HOME= hermes dashboard',
    'HERMES_HOME=$HOME/.hermes hermes dashboard',
    'export HERMES_HOME=~/.hermes; hermes chat',
    'uv run hermes dashboard',
    'python3 -m hermes_cli dashboard',
    'git pull --rebase=merges',
    'git pull -r origin main',
    'git -c pull.rebase=interactive pull',
    'git pull --reb',
    'git -c pull.rebase pull',
    'GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=alias.s GIT_CONFIG_VALUE_0=stash git s',
    'env GIT_CONFIG_KEY_0=core.hooksPath GIT_CONFIG_VALUE_0=x GIT_CONFIG_COUNT=1 git commit -m x',
    'export GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.hooksPath GIT_CONFIG_VALUE_0=/dev/null',
    'chmod -x .git/hooks/pre-commit',
    'chmod 644 .git/hooks/pre-commit',
    'chmod a-x .git/hooks/pre-commit',
    'rm -f $(git rev-parse --git-path hooks)/pre-commit',
    'rm -f .git/hooks/pre-commit.sample .git/hooks/pre-commit',
    ': > .git/hooks/pre-commit',
    'echo exit 0 > .git/hooks/pre-commit',
    'cp /dev/null .git/hooks/pre-commit',
    'mv .git/hooks/pre-commit /tmp/',
    'git config --unset-all core.hookspath',
    'gh pr merge -d 12',
    'gh pr merge 12 --squash -d',
    'gh pr merge --delete-branch=true 12',
    'gh api --method DELETE repos/o/r/git/refs/heads/x',
    'gh api -XDELETE /repos/o/r/git/refs/heads/x',
    'gh api repos/o/r/git/refs/heads/x -X DELETE',
    "bash -O extglob -c 'git stash'",
    "bash +o posix -c 'git stash'",
    "sh -euxc 'git stash'",
    "bash -o errexit -o nounset -c 'git push -f'",
    "zsh -c 'git stash'",
    "watch 'git stash'",
    "watch -n 2 -d 'git push -f'",
    'watch -- git stash',
    'watch -n1 watch git stash',
    'watch -n1 \'bash -c "git stash"\'',
    'watch --interval=1 git stash',
    'git config set core.hooksPath x',
    "git config --local core.hooksPath ''",
    'git -c core.hooksPath= commit -m x',
]

ROUND2_ALLOW = [
    'HERMES_HOME=$PWD/.dart_tool/x hermes dashboard',
    'hermes --version',
    'hermes --help',
    'hermes dashboard --help',
    'HERMES_HOME=/tmp/h hermes dashboard --port 9000 & echo $! > pid',
    'git pull --rebase=false',
    'git pull --no-rebase',
    'git -c pull.rebase=false pull',
    'git pull',
    'git pull origin main',
    'git pull --ff-only',
    'git -c pull.ff=only pull',
    'chmod +x .git/hooks/pre-commit',
    'chmod 755 .git/hooks/pre-commit',
    'chmod u+x .git/hooks/pre-commit',
    'ls -l .git/hooks/pre-commit',
    'cat .git/hooks/pre-commit',
    'gh pr merge 12 --squash',
    'gh pr merge 12 --auto --squash',
    'gh pr view 12 --json state',
    'gh api repos/o/r/git/refs/heads/x',
    'gh api -X DELETE repos/o/r/issues/comments/1',
    "gh pr merge 12 --merge --body 'delete branch later'",
    "bash -o pipefail -c 'flutter test'",
    'bash -e scripts/verify.sh all',
    'watch -n1 git status',
    "watch 'git log -1'",
    'GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=user.name GIT_CONFIG_VALUE_0=x git commit -m x',
    'git config core.hooksPath',
    'git config get core.hooksPath',
    'git config --list --show-origin',
    'rm -rf build/',
    'chmod +x scripts/dev-backend.sh',
]


def git(cwd, *args):
    subprocess.run(["git", "-C", cwd, *args], check=True, capture_output=True)


class GuardTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # an agent session exports it; the tests choose their own project
        cls.saved_project = os.environ.pop("CLAUDE_PROJECT_DIR", None)
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
        (hooks / "pre-commit").chmod(0o755)
        cls.nohook = tempfile.TemporaryDirectory()
        git(cls.nohook.name, "init", "-q", "-b", "local-only")
        # git ships sample hooks only; make sure no pre-commit exists here
        pc = Path(cls.nohook.name, ".git", "hooks", "pre-commit")
        if pc.exists():
            pc.unlink()

    @classmethod
    def tearDownClass(cls):
        if cls.saved_project is not None:
            os.environ["CLAUDE_PROJECT_DIR"] = cls.saved_project
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
        self.allowed("HERMES_HOME=/tmp/h hermes dashboard --port 9000")
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

    def test_review_battery(self):
        """Adversarial battery from the isolated review of the first version."""
        for c in REVIEW_BLOCK:
            self.blocked(c)
        for c in REVIEW_ALLOW:
            self.allowed(c)

    def test_hook_follows_hookspath_and_exec_bit(self):
        with tempfile.TemporaryDirectory() as d:
            git(d, "init", "-q", "-b", "local-only")
            self.blocked("git commit -m x", cwd=d, needle="setup_git_hooks")
            custom = Path(d, "myhooks")
            custom.mkdir()
            (custom / "pre-commit").write_text("#!/bin/sh\n")
            git(d, "config", "core.hooksPath", "myhooks")
            self.blocked("git commit -m x", cwd=d)  # present but not executable
            (custom / "pre-commit").chmod(0o755)
            self.allowed("git commit -m x", cwd=d)
            (custom / "pre-commit").unlink()
            self.blocked("git commit -m x", cwd=d)

    def test_optional_value_flags_do_not_eat_next_word(self):
        for c in ["git commit -S -n", "git commit -u -n", "git commit --gpg-sign --no-verify",
                  "git commit --untracked-files --no-verify",
                  "git push --signed -f", "git pull -S -r", "git push --force-with-lease -d origin x"]:
            self.blocked(c)
        self.allowed("git commit -S -m 'x'")
        self.allowed("git commit -m -n")
        self.allowed("git push -o -f origin x")

    def test_shell_forms(self):
        for c in ["bash -o pipefail -c 'git stash'", "bash -euo pipefail -c 'git stash'",
                  "bash -c -- 'git stash'", "bash -O extglob -c 'git stash'",
                  "bash <<< 'git stash'", "echo 'git stash' | bash", "printf 'git stash' | sh",
                  "cat <<EOF | sh\ngit stash\nEOF", "sh -c 'sh -c \"git stash\"'",
                  "watch -n1 'git stash'", "sudo -u root git stash", "sudo -E -g x git stash",
                  "nice -n5 git stash", "nice -n 5 git stash", "nice -5 git stash",
                  "watch -n1 git stash", "watch -n 1 git stash"]:
            self.blocked(c)
        self.allowed("bash script.sh")
        self.allowed("bash -c 'echo hi'")
        self.allowed("echo 'git stash' | grep stash")
        self.allowed("bash -o pipefail script.sh")

    def test_hermes_home_more(self):
        home = os.path.expanduser("~")
        for c in ["echo x > ~/.hermes/config.yaml", "printf k >> $HOME/.hermes/.env",
                  "rm -rf ~/.hermes*", "cd ~ && ls .hermes", "cd && cat .hermes/x",
                  "cd %s && rm -r .hermes" % home, "hermes dashboard", "hermes gateway run",
                  "hermes doctor", "echo hi > %s/.hermes/x" % home]:
            self.blocked(c, needle="dev-backend")
        self.allowed("HERMES_HOME=/tmp/h hermes dashboard")
        self.allowed("export HERMES_HOME=/tmp/h; hermes dashboard")
        self.allowed("hermes dashboard --isolated --no-open --port 0")
        self.allowed("hermes --version")
        self.allowed("hermes --print-runtime-command")
        self.allowed("docker exec c hermes computer-use screen start")
        self.allowed("cd /tmp && ls .hermes")
        old = os.environ.get("HERMES_HOME")
        try:
            os.environ["HERMES_HOME"] = "/tmp/isolated-home"
            self.allowed("hermes dashboard --no-open")
            os.environ["HERMES_HOME"] = os.path.join(home, ".hermes")
            self.blocked("hermes dashboard --no-open")
        finally:
            if old is None:
                os.environ.pop("HERMES_HOME", None)
            else:
                os.environ["HERMES_HOME"] = old

    def test_pull_rebase(self):
        for c in ["git pull --rebase", "git pull -r", "git pull --rebase=true", "git pull --rebase=interactive",
                  "git -c pull.rebase=true pull", "git pull --rebase origin main"]:
            self.blocked(c, needle="merge")
        self.allowed("git pull")
        self.allowed("git pull --no-rebase")
        self.allowed("git pull --rebase=false")
        self.allowed("git -c pull.rebase=false pull")
        self.allowed("git pull --ff-only")
        self.allowed("git pull --rebase", cwd=self.nohook.name)

    def test_alias_and_env_config(self):
        self.blocked("git -c alias.p=push p -f", needle="alias")
        self.blocked("git config alias.st stash", needle="alias")
        self.blocked("GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=alias.x GIT_CONFIG_VALUE_0=stash git x", needle="alias")
        self.blocked("env GIT_CONFIG_KEY_0=core.hooksPath git commit -m x")
        self.allowed("git config alias.st")
        self.allowed("git -c user.name=x log")

    def test_hook_file_tampering(self):
        for c in ["rm .git/hooks/pre-commit", "rm -f /x/.git/hooks/pre-commit", "chmod -x .git/hooks/pre-commit",
                  "chmod 644 .git/hooks/pre-commit", "mv .git/hooks/pre-commit /tmp/x"]:
            self.blocked(c, needle="pre-commit")
        self.allowed("chmod +x .git/hooks/pre-commit")
        self.allowed("chmod 755 .git/hooks/pre-commit")
        self.allowed("cat .git/hooks/pre-commit")
        for c in [": > .git/hooks/pre-commit", "echo exit 0 > .git/hooks/pre-commit",
                  "cp /dev/null .git/hooks/pre-commit", "echo x | tee .git/hooks/pre-commit",
                  "install -m 755 /dev/null .git/hooks/pre-commit", "> .git/hooks/pre-commit",
                  "chmod a-x .git/hooks/pre-commit", "rm -f $(git rev-parse --git-path hooks)/pre-commit",
                  "rm .githooks/pre-commit"]:
            self.blocked(c, needle="pre-commit")
        self.allowed("cp .git/hooks/pre-commit /tmp/backup")

    def test_commit_pathspec_and_prefixes(self):
        for c in ["git commit . -m x", "git commit --al -m x", "git add *", "git commit -m x :/"]:
            self.blocked(c, needle="by name")
        self.allowed("git commit lib/a.dart -m x")
        self.allowed("git commit --allow-empty -m x")

    def test_config_read_forms(self):
        for c in ["git config get core.hooksPath", "git config --get core.hooksPath",
                  "git config list", "git config --list", "git config --get-all core.hooksPath"]:
            self.allowed(c)
        for c in ["git config set core.hooksPath x", "git config unset core.hooksPath"]:
            self.blocked(c)

    def test_gh_deletes(self):
        for c in ["gh pr merge 1 --delete-branch", "gh pr merge 1 -d --squash",
                  "gh api -X DELETE repos/o/r/git/refs/heads/x", "gh api --method DELETE repos/o/r/git/refs/heads/x",
                  "gh api -XDELETE repos/o/r/git/refs/heads/x"]:
            self.blocked(c, needle="remote branches")
        self.allowed("gh pr merge 1 --squash")
        self.allowed("gh api repos/o/r/git/refs/heads/x")
        self.allowed("gh api -X DELETE repos/o/r/issues/comments/1")

    def test_post_hook_detection(self):
        for c in ["git pull", "git merge origin/main", "git -C . pull --ff-only", "cd x && git pull"]:
            self.assertTrue(guard.runs_pull_or_merge(c), c)
        for c in ["git merge-base a b", "git commit -m 'git pull'", "echo git merge", "git log --grep merge",
                  "grep -r 'git pull' ."]:
            self.assertFalse(guard.runs_pull_or_merge(c), c)

    def test_round2_battery(self):
        """Second adversarial battery (hermes, hook file, gh, watch, pull.rebase forms)."""
        for c in ROUND2_BLOCK:
            self.blocked(c)
        for c in ROUND2_ALLOW:
            self.allowed(c)

    def test_hook_rules_are_scoped_to_the_project(self):
        old = os.environ.get("CLAUDE_PROJECT_DIR")
        try:
            os.environ["CLAUDE_PROJECT_DIR"] = self.repo
            # a scratch repo outside the project: hook-integrity rules do not apply
            other = self.nohook.name
            self.allowed("git commit -m x", cwd=other)
            self.allowed("git -c core.hooksPath=x commit -m y", cwd=other)
            self.allowed("git config core.hooksPath hooks", cwd=other)
            self.allowed("git -C %s config core.hooksPath hooks" % other)
            self.allowed("D=%s; cd $D && git commit -m x" % other)
            self.allowed("rm %s/.git/hooks/pre-commit" % other)
            self.allowed(": > %s/.git/hooks/pre-commit" % other)
            # history rules stay global
            self.blocked("git stash", cwd=other)
            self.blocked("git push -f", cwd=other)
            self.blocked("git add -A", cwd=other)
            self.blocked("git commit -n -m x", cwd=other)
            # the shared git config reaches the project too
            self.blocked("git config --global core.hooksPath x", cwd=other)
            self.blocked("git config --system core.hooksPath x", cwd=other)
            # inside the project the rules apply
            self.blocked("git -c core.hooksPath=x commit -m y")
            self.blocked("git config core.hooksPath x")
            self.blocked("rm %s/.git/hooks/pre-commit" % self.repo)
            # when the other repo is the project and lacks the hook
            os.environ["CLAUDE_PROJECT_DIR"] = other
            self.blocked("git commit -m x", cwd=other, needle="setup_git_hooks")
            self.allowed("git commit -m x", cwd=self.repo)
        finally:
            if old is None:
                os.environ.pop("CLAUDE_PROJECT_DIR", None)
            else:
                os.environ["CLAUDE_PROJECT_DIR"] = old

    def test_hermes_home_assignment_scope(self):
        self.blocked("HERMES_HOME=/tmp/x true; hermes dashboard")
        self.blocked("HERMES_HOME= hermes dashboard")
        self.blocked("uv run hermes dashboard")
        self.blocked("python3 -m hermes_cli dashboard")
        self.blocked("python3 -I -m hermes_cli dashboard")
        self.allowed("HERMES_HOME=/tmp/x uv run hermes dashboard")
        self.allowed("HERMES_HOME=/tmp/x python3 -m hermes_cli dashboard")
        self.allowed("export HERMES_HOME=/tmp/x; hermes dashboard")
        self.allowed("HERMES_HOME=/tmp/x\nhermes dashboard")
        self.allowed("env HERMES_HOME=/tmp/x hermes dashboard")

    def test_stdin_shell_forms_round2(self):
        self.blocked("echo 'git stash' | sh -")
        self.blocked("echo 'git stash' | tee /tmp/x | bash")
        self.blocked("cat <<EOF | tee /tmp/x | sh\ngit stash\nEOF")
        self.blocked("gh pr merge 1 --delete-branch=true")
        self.allowed("gh pr merge 1 --delete-branch=false")
        self.blocked("git -c pull.rebase pull")
        self.allowed("echo 'ls' | tee /tmp/x | bash")

    def _post_env(self, d, flutter_exit):
        bindir = Path(d, "bin")
        bindir.mkdir()
        flutter = bindir / "flutter"
        flutter.write_text("#!/bin/sh\necho ran >> %s\nexit %d\n" % (Path(d, "flutter.log"), flutter_exit))
        flutter.chmod(0o755)
        env = dict(os.environ)
        env["PATH"] = str(bindir) + os.pathsep + env["PATH"]
        env.update(GIT_AUTHOR_NAME="t", GIT_AUTHOR_EMAIL="t@t", GIT_COMMITTER_NAME="t", GIT_COMMITTER_EMAIL="t@t")
        return env

    def _hook(self, mode, cmd, cwd, env, tool_use_id="toolu_1"):
        args = [sys.executable, "-I", str(HOOK)] + (["--post"] if mode == "post" else [])
        payload = {"tool_name": "Bash", "tool_input": {"command": cmd}, "cwd": cwd, "tool_use_id": tool_use_id}
        return subprocess.run(args, input=json.dumps(payload), capture_output=True, text=True, env=env)

    def _upstream_and_clone(self, d, env):
        up, cl = os.path.join(d, "up"), os.path.join(d, "cl")
        os.makedirs(os.path.join(up, "lib/l10n/arb"))
        git(up, "init", "-q", "-b", "main")
        arb = Path(up, "lib/l10n/arb/app_en.arb")
        arb.write_text("{}\n")
        git(up, "add", "lib")
        subprocess.run(["git", "-C", up, "commit", "-q", "-m", "a"], check=True, env=env)
        subprocess.run(["git", "clone", "-q", up, cl], check=True, env=env)
        arb.write_text('{"a": "b"}\n')
        subprocess.run(["git", "-C", up, "commit", "-qam", "b"], check=True, env=env)
        return cl

    def test_post_hook_runs_gen_l10n_only_after_a_new_pull(self):
        with tempfile.TemporaryDirectory() as d:
            env = self._post_env(d, 0)
            cl = self._upstream_and_clone(d, env)
            log = Path(d, "flutter.log")

            # a pull that integrates the ARB change
            self.assertEqual(self._hook("pre", "git pull", cl, env, "t1").returncode, 0)
            subprocess.run(["git", "-C", cl, "pull", "-q"], check=True, env=env)
            r = self._hook("post", "git pull", cl, env, "t1")
            self.assertEqual(r.returncode, 0)
            self.assertIn("ran `flutter gen-l10n`", r.stdout)
            self.assertTrue(log.exists())
            log.unlink()

            # the marker is consumed: a second pass for the same call does nothing
            self.assertEqual(self._hook("post", "git pull", cl, env, "t1").stdout, "")
            # a pull that changes nothing, and a post hook without a pre record
            self._hook("pre", "git pull", cl, env, "t2")
            subprocess.run(["git", "-C", cl, "pull", "-q"], check=True, env=env)
            self.assertEqual(self._hook("post", "git pull", cl, env, "t2").stdout, "")
            self.assertEqual(self._hook("post", "git pull", cl, env, "t3").stdout, "")
            # text that merely mentions a pull
            self._hook("pre", "git commit -m 'git pull'", cl, env, "t4")
            self.assertEqual(self._hook("post", "git commit -m 'git pull'", cl, env, "t4").stdout, "")
            self.assertFalse(log.exists())

    def test_post_hook_reports_gen_l10n_failure(self):
        with tempfile.TemporaryDirectory() as d:
            env = self._post_env(d, 1)
            cl = self._upstream_and_clone(d, env)
            self._hook("pre", "git pull", cl, env)
            subprocess.run(["git", "-C", cl, "pull", "-q"], check=True, env=env)
            r = self._hook("post", "git pull", cl, env)
            self.assertIn("failed", r.stdout)

    def _with_project(self, project):
        class Ctx:
            def __enter__(ctx):
                ctx.old = os.environ.get("CLAUDE_PROJECT_DIR")
                if project is None:
                    os.environ.pop("CLAUDE_PROJECT_DIR", None)
                else:
                    os.environ["CLAUDE_PROJECT_DIR"] = project

            def __exit__(ctx, *a):
                if ctx.old is None:
                    os.environ.pop("CLAUDE_PROJECT_DIR", None)
                else:
                    os.environ["CLAUDE_PROJECT_DIR"] = ctx.old

        return Ctx()

    def test_scope_follows_git_dir_work_tree_and_env(self):
        other = self.nohook.name
        gd = os.path.join(self.repo, ".git")
        with self._with_project(self.repo):
            self.blocked("git --git-dir=%s config core.hooksPath x" % gd, cwd=other)
            self.blocked("git --git-dir %s -c core.hooksPath=x log" % gd, cwd=other)
            self.blocked("GIT_DIR=%s git config core.hooksPath x" % gd, cwd=other)
            self.blocked("GIT_COMMON_DIR=%s git -c core.hooksPath=x log" % gd, cwd=other)
            self.blocked("git --work-tree=%s -c core.hooksPath=x status" % self.repo, cwd=other)
            self.blocked("GIT_WORK_TREE=%s git -c core.hooksPath=x status" % self.repo, cwd=other)
            # pointing at the other repo from inside the project stays out of scope
            ogd = os.path.join(other, ".git")
            self.allowed("git --git-dir=%s config core.hooksPath x" % ogd, cwd=self.repo)
            self.allowed("GIT_DIR=%s git config core.hooksPath x" % ogd, cwd=self.repo)
        with self._with_project(other):
            self.allowed("git --git-dir=%s config core.hooksPath x" % gd, cwd=other)

    def test_path_that_is_not_yet_a_repo_is_outside_the_project(self):
        with tempfile.TemporaryDirectory() as d:
            fresh = os.path.join(d, "fresh")
            with self._with_project(self.repo):
                self.allowed("git -C %s config core.hooksPath h" % fresh)
                self.allowed("git init -q %s && git -C %s config core.hooksPath h" % (fresh, fresh))
                self.allowed("mkdir %s && cd %s && git init -q && git config core.hooksPath h" % (fresh, fresh))
                self.allowed("git -C %s -c core.hooksPath=h commit -m x" % fresh)
            with self._with_project(None):
                self.blocked("git -C %s config core.hooksPath h" % fresh)

    def test_config_file_scope(self):
        other = self.nohook.name
        with tempfile.TemporaryDirectory() as d:
            with self._with_project(self.repo):
                self.blocked("git config --file %s/.git/config core.hooksPath x" % self.repo, cwd=other)
                self.blocked("git config -f %s/.git/config core.hooksPath x" % self.repo, cwd=other)
                self.blocked("git config --file=%s/.git/config core.hooksPath x" % self.repo, cwd=other)
                # a file outside any repo (~/.gitconfig, /tmp/x) is shared config
                self.blocked("git config --file %s/gitconfig core.hooksPath x" % d, cwd=other)
                self.blocked("git config --file ~/.gitconfig core.hooksPath x", cwd=other)
                # unresolvable path: assume the worst
                self.blocked("git config --file $SOMEWHERE core.hooksPath x", cwd=other)
                # another repo's own config file
                self.allowed("git config --file %s/.git/config core.hooksPath x" % other)
                self.allowed("git config --file %s/.git/config user.name x" % self.repo)

    def test_marker_files_are_private_and_per_repo(self):
        with tempfile.TemporaryDirectory() as d:
            env = self._post_env(d, 0)
            cl = self._upstream_and_clone(d, env)
            mdir = Path(cl, ".git", "hermes-guard")
            self.assertEqual(self._hook("pre", "git pull", cl, env, "toolu_a").returncode, 0)
            marker = mdir / "toolu_a"
            self.assertTrue(marker.exists())
            self.assertEqual(marker.stat().st_mode & 0o777, 0o600)
            self.assertEqual(mdir.stat().st_mode & 0o777, 0o700)
            self.assertFalse(Path(tempfile.gettempdir(), "hermes-guard-toolu_a").exists())

            # a planted symlink is replaced, never followed
            target = Path(d, "victim")
            target.write_text("keep")
            marker.unlink()
            marker.symlink_to(target)
            self._hook("pre", "git pull", cl, env, "toolu_a")
            self.assertEqual(target.read_text(), "keep")
            self.assertFalse(marker.is_symlink())

    def test_stale_markers_are_removed_and_failures_clean_up(self):
        with tempfile.TemporaryDirectory() as d:
            env = self._post_env(d, 0)
            cl = self._upstream_and_clone(d, env)
            mdir = Path(cl, ".git", "hermes-guard")
            mdir.mkdir(mode=0o700)
            old = mdir / "toolu_old"
            old.write_text("0")
            two_hours_ago = time.time() - 7200
            os.utime(old, (two_hours_ago, two_hours_ago))
            fresh = mdir / "toolu_fresh"
            fresh.write_text("0")
            self._hook("pre", "git pull", cl, env, "toolu_new")
            self.assertFalse(old.exists())
            self.assertTrue(fresh.exists())
            self.assertTrue((mdir / "toolu_new").exists())

            # PostToolUseFailure drops the record and prints nothing
            args = [sys.executable, "-I", str(HOOK), "--post"]
            payload = {
                "hook_event_name": "PostToolUseFailure",
                "tool_name": "Bash",
                "tool_input": {"command": "git pull"},
                "cwd": cl,
                "tool_use_id": "toolu_new",
                "error": "Exit code 1",
            }
            r = subprocess.run(args, input=json.dumps(payload), capture_output=True, text=True, env=env)
            self.assertEqual((r.returncode, r.stdout), (0, ""))
            self.assertFalse((mdir / "toolu_new").exists())

    def test_settings_wire_the_failure_event(self):
        settings = json.loads((Path(__file__).resolve().parent.parent / ".claude" / "settings.json").read_text())
        for event in ("PreToolUse", "PostToolUse", "PostToolUseFailure"):
            commands = [h["command"] for g in settings["hooks"][event] for h in g["hooks"]]
            self.assertTrue(any("guard_bash.py" in c for c in commands), event)

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
