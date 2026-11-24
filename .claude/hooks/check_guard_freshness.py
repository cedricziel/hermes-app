"""Session-start check: is the Bash guard active in this checkout?

Claude Code loads hooks from $CLAUDE_PROJECT_DIR. A checkout from before the
guard existed runs every Bash call unguarded and nothing says so. This prints
a warning (stdout reaches the model as context) when:

  (a) .claude/hooks/guard_bash.py is missing,
  (b) .claude/settings.json has no PreToolUse hook running guard_bash.py,
  (c) HEAD is more than MAX_COMMITS_BEHIND commits behind the local origin/main.

It only reads: no fetch, merge, reset, checkout or stash. It never fails the
session: every error path ends in exit 0.
"""

import json
import os
import re
import shlex
import subprocess
import sys

MAX_COMMITS_BEHIND = 20
GUARD = ".claude/hooks/guard_bash.py"
SETTINGS = ".claude/settings.json"
FIX = (
    'git -C "$CLAUDE_PROJECT_DIR" fetch origin main && '
    'git -C "$CLAUDE_PROJECT_DIR" merge --ff-only origin/main'
)


def _git(project, *args):
    try:
        env = dict(os.environ, GIT_OPTIONAL_LOCKS="0")
        p = subprocess.run(
            ["git", "-C", project, *args],
            capture_output=True,
            text=True,
            timeout=10,
            env=env,
        )
    except Exception:
        return None
    return p.stdout.strip() if p.returncode == 0 else None


def _count(project, rng):
    out = _git(project, "rev-list", "--count", rng)
    return int(out) if out and out.isdigit() else None


def _matcher_covers_bash(matcher):
    if matcher is None or matcher in ("", "*"):
        return True
    try:
        return re.fullmatch(str(matcher), "Bash") is not None
    except re.error:
        return False


_PYTHON = re.compile(r"python(3(\.\d+)?)?")
_ENV_ASSIGN = re.compile(r"[A-Za-z_][A-Za-z0-9_]*=")


def _runs_guard(command):
    """True for one plain invocation of the guard: [VAR=x] [env] python3 [-flags]
    .../guard_bash.py, or the script itself as the program. No --post, no
    compound commands."""
    command = str(command)
    if re.search(r"[;&|`]|\$\(", command):
        return False
    try:
        words = shlex.split(command)
    except ValueError:
        return False
    if "--post" in words:
        return False
    while words and _ENV_ASSIGN.match(words[0]):
        words.pop(0)
    if words and os.path.basename(words[0]) == "env":
        words.pop(0)
        while words and _ENV_ASSIGN.match(words[0]):
            words.pop(0)
    if not words:
        return False
    if words[0].endswith(GUARD):
        return True
    if not _PYTHON.fullmatch(os.path.basename(words[0])):
        return False
    rest = words[1:]
    while rest and rest[0].startswith("-"):
        flag = rest.pop(0)
        if not flag.startswith("--") and set(flag) & set("cmWX"):
            return False  # -c/-m run code or a module; -W/-X take an argument
    return bool(rest) and rest[0].endswith(GUARD)


def has_pretooluse_wiring(settings_path):
    try:
        with open(settings_path, encoding="utf-8") as f:
            data = json.load(f)
        for group in data["hooks"]["PreToolUse"]:
            if not _matcher_covers_bash(group.get("matcher")):
                continue
            for hook in group.get("hooks", []):
                if _runs_guard(hook.get("command", "")):
                    return True
    except Exception:
        return False
    return False


def problems(project):
    """Return (file_reasons, behind, ahead); the file checks need no git."""
    reasons = []
    if not os.path.isfile(os.path.join(project, GUARD)):
        reasons.append("%s is missing from the checkout." % GUARD)
    if not has_pretooluse_wiring(os.path.join(project, SETTINGS)):
        reasons.append(
            "%s has no PreToolUse hook for Bash that runs guard_bash.py." % SETTINGS
        )
    behind = ahead = 0
    try:
        if _git(project, "rev-parse", "--verify", "-q", "refs/remotes/origin/main"):
            behind = _count(project, "HEAD..origin/main") or 0
            ahead = _count(project, "origin/main..HEAD") or 0
    except Exception:
        pass
    return reasons, behind, ahead


def build_message(project):
    reasons, behind, ahead = problems(project)
    lagging = behind > MAX_COMMITS_BEHIND
    if not reasons and not lagging:
        return ""
    if reasons:
        lines = ["WARNING: the Bash guard is not active in this session:"]
        lines += ["- " + r for r in reasons]
        if lagging:
            lines.append(
                "- HEAD is %d commits behind origin/main (limit %d)."
                % (behind, MAX_COMMITS_BEHIND)
            )
    else:
        lines = [
            "WARNING: the Bash guard in this checkout is %d commits behind origin/main:"
            % behind,
            "- newer guard rules may be missing (limit %d)." % MAX_COMMITS_BEHIND,
        ]
    lines.append("Fix: " + FIX)
    lines.append("Then start a new session: hooks are loaded at session start.")
    if ahead and behind:
        lines.append(
            "HEAD has diverged, so --ff-only will fail; merge instead: "
            'git -C "$CLAUDE_PROJECT_DIR" merge origin/main (a merge commit).'
        )
    if _git(project, "status", "--porcelain", "--untracked-files=no"):
        lines.append(
            "Local changes: the fast-forward stops only if they touch files "
            "the update changes."
        )
    return "\n".join(lines) + "\n"


def main():
    project = os.environ.get("CLAUDE_PROJECT_DIR", "")
    if not project or not os.path.isdir(project):
        return
    sys.stdout.write(build_message(project))


if __name__ == "__main__":
    try:
        main()
    except Exception:
        pass
    sys.exit(0)
