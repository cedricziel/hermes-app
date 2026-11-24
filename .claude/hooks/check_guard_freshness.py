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
    env = dict(os.environ, GIT_OPTIONAL_LOCKS="0")
    p = subprocess.run(
        ["git", "-C", project, *args],
        capture_output=True,
        text=True,
        timeout=10,
        env=env,
    )
    return p.stdout.strip() if p.returncode == 0 else None


def _count(project, rng):
    out = _git(project, "rev-list", "--count", rng)
    return int(out) if out and out.isdigit() else None


def has_pretooluse_wiring(settings_path):
    try:
        with open(settings_path, encoding="utf-8") as f:
            data = json.load(f)
        groups = data["hooks"]["PreToolUse"]
        for group in groups:
            for hook in group.get("hooks", []):
                if "guard_bash.py" in str(hook.get("command", "")):
                    return True
    except Exception:
        return False
    return False


def problems(project):
    """Return (reasons, behind, ahead) for the checkout."""
    reasons = []
    if not os.path.isfile(os.path.join(project, GUARD)):
        reasons.append("%s is missing from the checkout." % GUARD)
    if not has_pretooluse_wiring(os.path.join(project, SETTINGS)):
        reasons.append("%s has no PreToolUse hook that runs guard_bash.py." % SETTINGS)
    behind = ahead = 0
    try:
        if _git(project, "rev-parse", "--verify", "-q", "refs/remotes/origin/main"):
            behind = _count(project, "HEAD..origin/main") or 0
            ahead = _count(project, "origin/main..HEAD") or 0
            if behind > MAX_COMMITS_BEHIND:
                reasons.append(
                    "HEAD is %d commits behind origin/main (limit %d)."
                    % (behind, MAX_COMMITS_BEHIND)
                )
    except Exception:
        pass
    return reasons, behind, ahead


def build_message(project):
    reasons, behind, ahead = problems(project)
    if not reasons:
        return ""
    lines = ["WARNING: the Bash guard is not active in this session:"]
    lines += ["- " + r for r in reasons]
    lines.append("Fix: " + FIX)
    notes = ["Then start a new session: hooks are loaded at session start."]
    if ahead and behind:
        notes.append("HEAD has diverged from origin/main, so --ff-only will fail.")
    try:
        if _git(project, "status", "--porcelain", "--untracked-files=no"):
            notes.append(
                "The tree has uncommitted changes: the fast-forward needs a clean tree."
            )
    except Exception:
        pass
    lines += notes
    return "\n".join(lines) + "\n"


def main():
    project = os.environ.get("CLAUDE_PROJECT_DIR", "")
    if not project or not os.path.isdir(project):
        return
    if _git(project, "rev-parse", "--git-dir") is None:
        return
    sys.stdout.write(build_message(project))


if __name__ == "__main__":
    try:
        main()
    except Exception:
        pass
    sys.exit(0)
