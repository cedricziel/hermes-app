#!/usr/bin/env python3
"""PreToolUse guard for the Bash tool (agent sessions only, never CI).

Reads the hook JSON on stdin. Exit 2 blocks the call and the stderr text goes
to the model. Any internal error fails open (exit 0 with a warning), because a
hook that crashes with another exit code would not block anyway.

`check(command, cwd)` is pure apart from read-only git lookups: it returns None
to allow, or the message to show. Rules live in `_check_git`, `_check_program`
and `_check_hermes_home`; see .claude/skills/agent-guard/SKILL.md.

Run with `--post` as a PostToolUse hook: after a git pull/merge that changed
lib/l10n/arb/*.arb it runs `flutter gen-l10n` (fail open).
"""

import json
import os
import re
import subprocess
import sys

SHELLS = {"bash", "sh", "zsh", "dash", "ksh"}
KEYWORDS = {"if", "then", "else", "elif", "do", "while", "until", "{", "}", "!", "time"}
REMOTE_WORK_FLAGS = (
    "--abort",
    "--continue",
    "--skip",
    "--quit",
    "--edit-todo",
    "--show-current-patch",
)

MSG_NO_VERIFY = (
    "Blocked: --no-verify / -n skips the pre-commit hook. Fix what the hook reports "
    "(dart format, flutter analyze, outdated dependencies) and commit again."
)
MSG_HOOKS_PATH = (
    "Blocked: changing core.hooksPath disables the shared git hooks. Fix what the hook "
    "reports; install the hook with `dart run tool/setup_git_hooks.dart`."
)
MSG_STASH = (
    "Blocked: git stash. The stash stack is shared by every worktree and session. "
    "Commit work in progress on your own branch instead."
)
MSG_ADD_ALL = (
    "Blocked: staging everything (`git add -A/--all/./:/`, `git add -u` without paths, "
    "`git commit -a`). Building the apps rewrites tracked ios/ and macos/ files. "
    "Stage files by name: `git add path/a.dart path/b.dart`."
)
MSG_FORCE = (
    "Blocked: force push. Never rewrite a pushed branch: merge main in "
    "(`git merge origin/main`) and push normally. If a merged branch must restart, "
    "push under a new branch name."
)
MSG_DELETE = "Blocked: deleting a remote branch (--delete, -d, :branch, --prune). Never delete remote branches."
MSG_REBASE = (
    "Blocked: git rebase on a branch that exists on origin rewrites pushed history. "
    "Merge main in instead: `git merge origin/main`."
)
MSG_NO_HOOK = (
    "Blocked: git commit without the pre-commit hook installed in this clone. "
    "Run `dart run tool/setup_git_hooks.dart` first, then commit."
)
MSG_HERMES_HOME = (
    "Blocked: this touches the real Hermes home (~/.hermes) or stops the real dashboard. "
    "Use scripts/dev-backend.sh, which runs a throwaway Hermes with its own HERMES_HOME."
)
MSG_KILL = (
    "Blocked: pkill -f / killall can kill unrelated processes. Stop processes by their "
    "recorded PID (see the verify skill)."
)


# ---------------------------------------------------------------- lexer


class Cmd:
    def __init__(self):
        self.words = []
        self.redirs = []
        self.heredocs = []


def _lex(s, i=0, nested=False):
    """Split shell text into simple commands.

    Returns (commands, index). Commands from $(...), backticks and subshells are
    appended to the same flat list. When `nested`, stops at the closing ')'.
    """
    cmds = []
    cur = Cmd()
    buf = []
    has_word = False
    skip_next = None  # None | "redir" | "heredoc:<strip>"
    pending_heredocs = []  # (delimiter, strip_tabs)
    n = len(s)

    def end_word():
        nonlocal buf, has_word, skip_next
        if not has_word:
            return
        w = "".join(buf)
        buf, has_word = [], False
        if skip_next == "redir":
            cur.redirs.append(w)
        elif skip_next and skip_next.startswith("heredoc:"):
            pending_heredocs.append((w, skip_next == "heredoc:-"))
        else:
            cur.words.append(w)
        skip_next = None

    def end_cmd():
        nonlocal cur
        end_word()
        if cur.words or cur.redirs:
            cmds.append(cur)
        cur = Cmd()

    def read_heredocs(j):
        # j is just after a newline; consume bodies of pending heredocs.
        nonlocal pending_heredocs
        for delim, strip in pending_heredocs:
            body = []
            while j < n:
                k = s.find("\n", j)
                line = s[j:] if k < 0 else s[j:k]
                j = n if k < 0 else k + 1
                if (line.lstrip("\t") if strip else line) == delim:
                    break
                body.append(line)
            cur.heredocs.append("\n".join(body))
        pending_heredocs = []
        return j

    def dollar_paren(j):
        # s[j] == '(' just after '$'; lex inner, return index after ')'.
        inner, k = _lex(s, j + 1, nested=True)
        cmds.extend(inner)
        return k

    def backtick(j):
        k = j + 1
        out = []
        while k < n and s[k] != "`":
            if s[k] == "\\" and k + 1 < n:
                out.append(s[k + 1])
                k += 2
                continue
            out.append(s[k])
            k += 1
        inner, _ = _lex("".join(out))
        cmds.extend(inner)
        return k + 1

    while i < n:
        c = s[i]
        if c in " \t":
            end_word()
            i += 1
        elif c == "\n":
            end_cmd()
            i += 1
            if pending_heredocs:
                # attach bodies to the command just closed
                last = cmds[-1] if cmds else cur
                saved = cur
                cur = last
                i = read_heredocs(i)
                cur = saved
        elif c == "\\":
            if i + 1 < n and s[i + 1] == "\n":
                i += 2
            else:
                if i + 1 < n:
                    buf.append(s[i + 1])
                    has_word = True
                i += 2
        elif c == "'":
            k = s.find("'", i + 1)
            if k < 0:
                k = n
            buf.append(s[i + 1 : k])
            has_word = True
            i = k + 1
        elif c == '"':
            has_word = True
            i += 1
            while i < n and s[i] != '"':
                if s[i] == "\\" and i + 1 < n:
                    if s[i + 1] in '"\\$`':
                        buf.append(s[i + 1])
                    elif s[i + 1] == "\n":
                        pass
                    else:
                        buf.append(s[i : i + 2])
                    i += 2
                elif s[i] == "$" and i + 1 < n and s[i + 1] == "(":
                    buf.append("$(...)")
                    i = dollar_paren(i + 1)
                elif s[i] == "`":
                    buf.append("`...`")
                    i = backtick(i)
                else:
                    buf.append(s[i])
                    i += 1
            i += 1
        elif c == "$" and i + 1 < n and s[i + 1] == "(":
            if i + 2 < n and s[i + 2] == "(":  # arithmetic $((...))
                depth, k = 0, i + 1
                while k < n:
                    if s[k] == "(":
                        depth += 1
                    elif s[k] == ")":
                        depth -= 1
                        if depth == 0:
                            break
                    k += 1
                buf.append("$((...))")
                i = k + 1
            else:
                buf.append("$(...)")
                i = dollar_paren(i + 1)
            has_word = True
        elif c == "`":
            buf.append("`...`")
            has_word = True
            i = backtick(i)
        elif c == "#" and not has_word:
            k = s.find("\n", i)
            i = n if k < 0 else k
        elif c in "<>" or (c == "&" and i + 1 < n and s[i + 1] == ">"):
            if has_word and "".join(buf).isdigit():
                buf, has_word = [], False
            else:
                end_word()
            j = i
            while j < n and s[j] in "<>&|-":
                if s[j] == "-" and not (j > i and s[j - 1] == "<"):
                    break
                j += 1
            op = s[i:j]
            if op == "<<-" or (op.startswith("<<") and not op.startswith("<<<")):
                skip_next = "heredoc:-" if op == "<<-" else "heredoc:"
            else:
                skip_next = "redir"
            i = j
            if op.endswith("&") and i < n and (s[i].isdigit() or s[i] == "-"):
                # >&2 / <&- : the fd is the target, nothing to skip
                while i < n and (s[i].isdigit() or s[i] == "-"):
                    i += 1
                skip_next = None
        elif c in ";&|":
            end_cmd()
            i += 1
            while i < n and s[i] in ";&|":
                i += 1
        elif c == "(":
            end_cmd()
            i += 1
        elif c == ")":
            end_cmd()
            if nested:
                return cmds, i + 1
            i += 1
        else:
            buf.append(c)
            has_word = True
            i += 1
    end_cmd()
    return cmds, i


# ---------------------------------------------------------------- helpers


def _strip_prefix(words):
    """Drop assignments, keywords and wrappers; return remaining argv."""
    w = list(words)
    while w:
        t = w[0]
        if re.match(r"^[A-Za-z_][A-Za-z0-9_]*\+?=", t):
            w.pop(0)
        elif t in KEYWORDS:
            w.pop(0)
        elif t in ("nohup", "builtin", "exec", "sudo"):
            w.pop(0)
            while t in ("exec", "sudo") and w and w[0].startswith("-"):
                w.pop(0)
        elif t == "command":
            if len(w) > 1 and w[1] in ("-v", "-V"):
                return []
            w.pop(0)
            while w and w[0] == "-p":
                w.pop(0)
        elif t == "env":
            w.pop(0)
            while w and (
                w[0].startswith("-") or re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", w[0])
            ):
                opt = w.pop(0)
                if opt in ("-u", "-C", "-S", "--unset", "--chdir") and w:
                    w.pop(0)
        elif t == "nice":
            w.pop(0)
            if w and w[0] == "-n" and len(w) > 1:
                w = w[2:]
            elif w and re.match(r"^-\d+$", w[0]):
                w.pop(0)
        elif t == "timeout":
            w.pop(0)
            while w and w[0].startswith("-"):
                opt = w.pop(0)
                if opt in ("-s", "-k", "--signal", "--kill-after") and w:
                    w.pop(0)
            if w:
                w.pop(0)  # duration
        elif t == "xargs":
            w.pop(0)
            while w and w[0].startswith("-"):
                opt = w.pop(0)
                if opt in ("-n", "-I", "-L", "-P", "-s", "-d", "-E", "-a") and w:
                    w.pop(0)
        else:
            break
    return w


def _matches_long(tok, full, minlen):
    """git accepts unambiguous prefixes of long options."""
    name = tok.split("=", 1)[0]
    return len(name) >= minlen and full.startswith(name)


def _short_cluster(tok, arg_flags):
    """Letters of a short-option cluster up to (excluding) the first arg-taking one.

    Returns (letters, takes_next_arg).
    """
    letters = []
    body = tok[1:]
    for idx, ch in enumerate(body):
        if ch in arg_flags:
            return letters, idx == len(body) - 1
        letters.append(ch)
    return letters, False


def _git_effective(args, cwd):
    """Skip git global options. Returns (config_overrides, cwd, sub, rest)."""
    configs = []
    i = 0
    while i < len(args):
        a = args[i]
        if a == "-C" and i + 1 < len(args):
            cwd = os.path.normpath(os.path.join(cwd, os.path.expanduser(args[i + 1])))
            i += 2
        elif a.startswith("-C") and len(a) > 2:
            cwd = os.path.normpath(os.path.join(cwd, os.path.expanduser(a[2:])))
            i += 1
        elif a == "-c" and i + 1 < len(args):
            configs.append(args[i + 1])
            i += 2
        elif a.startswith("-c") and len(a) > 2 and "=" in a:
            configs.append(a[2:])
            i += 1
        elif a == "--config-env" and i + 1 < len(args):
            configs.append(args[i + 1])
            i += 2
        elif a.startswith("--config-env="):
            configs.append(a.split("=", 1)[1])
            i += 1
        elif a in (
            "--git-dir",
            "--work-tree",
            "--namespace",
            "--exec-path",
            "--super-prefix",
            "--attr-source",
        ) and i + 1 < len(args):
            i += 2
        elif a.startswith("-"):
            i += 1
        else:
            return configs, cwd, a, args[i + 1 :]
    return configs, cwd, None, []


def _git(cwd, *args):
    try:
        r = subprocess.run(
            ["git", "-C", cwd, *args],
            capture_output=True,
            text=True,
            timeout=5,
        )
        return r.returncode, r.stdout.strip()
    except Exception:
        return 1, ""


# ---------------------------------------------------------------- rules

COMMIT_ARG_FLAGS = set("mFCctSu")  # S and u take optional attached values
COMMIT_LONG_ARG = {
    "--message",
    "--file",
    "--author",
    "--date",
    "--cleanup",
    "--template",
    "--reuse-message",
    "--reedit-message",
    "--fixup",
    "--squash",
    "--trailer",
    "--pathspec-from-file",
    "--gpg-sign",
    "--untracked-files",
}
PUSH_ARG_FLAGS = set("o")
PUSH_LONG_ARG = {
    "--repo",
    "--receive-pack",
    "--exec",
    "--push-option",
    "--recurse-submodules",
    "--signed",
}
PUSH_LONG_ARG = {"--repo", "--receive-pack", "--exec", "--push-option"}
ADD_LONG_ARG = {"--pathspec-from-file", "--chmod"}


def _walk(args, arg_flags, long_arg):
    """Yield ('long', tok) / ('short', letters) / ('pos', tok) for git options."""
    i = 0
    only_pos = False
    while i < len(args):
        a = args[i]
        if only_pos or a == "-" or not a.startswith("-"):
            yield "pos", a
        elif a == "--":
            only_pos = True
        elif a.startswith("--"):
            yield "long", a
            if "=" not in a and a in long_arg:
                i += 1
        else:
            letters, takes = _short_cluster(a, arg_flags)
            yield "short", letters
            if takes:
                i += 1
        i += 1


def _check_git(argv, cwd, installed_hook_in_same_command):
    configs, cwd, sub, rest = _git_effective(argv[1:], cwd)
    for c in configs:
        if c.split("=", 1)[0].lower() == "core.hookspath":
            return MSG_HOOKS_PATH
    if sub is None:
        return None

    if sub == "stash":
        return MSG_STASH

    if sub == "config":
        if any(a.lower() == "core.hookspath" for a in rest):
            pos = [a for a in rest if not a.startswith("-")]
            mutating_flag = any(
                a in ("--unset", "--unset-all", "--add", "--replace-all") for a in rest
            )
            readonly = any(a.startswith("--get") or a in ("-l", "--list") for a in rest)
            if (len(pos) >= 2 or mutating_flag) and not readonly:
                return MSG_HOOKS_PATH
        return None

    if sub == "add":
        pos, flag_all, flag_u = [], False, False
        for kind, v in _walk(rest, set(), ADD_LONG_ARG):
            if kind == "pos":
                pos.append(v)
            elif kind == "long":
                if _matches_long(v, "--all", 4):
                    flag_all = True
                elif _matches_long(v, "--update", 4):
                    flag_u = True
            elif "A" in v:
                flag_all = True
            elif "u" in v:
                flag_u = True
        if flag_all or any(p in (".", "./", ":/", ":(top)") for p in pos):
            return MSG_ADD_ALL
        if flag_u and not pos:
            return MSG_ADD_ALL
        return None

    if sub == "commit":
        for kind, v in _walk(rest, COMMIT_ARG_FLAGS, COMMIT_LONG_ARG):
            if kind == "long":
                if _matches_long(v, "--no-verify", 6):
                    return MSG_NO_VERIFY
                if v == "--all":
                    return MSG_ADD_ALL
            elif kind == "short":
                if "n" in v:
                    return MSG_NO_VERIFY
                if "a" in v:
                    return MSG_ADD_ALL
        if not installed_hook_in_same_command and "--help" not in rest:
            rc, common = _git(cwd, "rev-parse", "--git-common-dir")
            if rc == 0 and common:
                hook = os.path.join(cwd, common, "hooks", "pre-commit")
                if not os.path.exists(hook):
                    return MSG_NO_HOOK
        return None

    if sub == "push":
        for kind, v in _walk(rest, PUSH_ARG_FLAGS, PUSH_LONG_ARG):
            if kind == "long":
                if _matches_long(v, "--no-verify", 6):
                    return MSG_NO_VERIFY
                if _matches_long(v, "--force", 5) or v.startswith("--force-"):
                    return MSG_FORCE
                if _matches_long(v, "--delete", 4) or v in ("--prune", "--mirror"):
                    return MSG_DELETE
            elif kind == "short":
                if "f" in v:
                    return MSG_FORCE
                if "d" in v:
                    return MSG_DELETE
            else:
                if v.startswith("+"):
                    return MSG_FORCE
                if v.startswith(":"):
                    return MSG_DELETE
        return None

    if sub == "rebase":
        if any(a in REMOTE_WORK_FLAGS for a in rest):
            return None
        rc, branch = _git(cwd, "symbolic-ref", "--short", "-q", "HEAD")
        if rc == 0 and branch:
            rc2, _ = _git(
                cwd, "rev-parse", "--verify", "--quiet", "refs/remotes/origin/" + branch
            )
            if rc2 == 0:
                return MSG_REBASE
        return None
    return None


def _home_pattern():
    homes = {"~", "$HOME", "${HOME}"}
    for h in (os.environ.get("HOME"), os.path.expanduser("~")):
        if h and h != "/":
            homes.add(h.rstrip("/"))
    alt = "|".join(re.escape(h) for h in sorted(homes, key=len, reverse=True))
    return re.compile(r"(?:^|[=:,])(?:" + alt + r")/\.hermes(?:/|$)")


TEXT_ONLY = {"echo", "printf", "gh", "grep", "rg"}


def _check_hermes_home(argv, cmd):
    prog = os.path.basename(argv[0]) if argv else ""
    pat = _home_pattern()
    if prog in TEXT_ONLY:
        return None
    words = list(cmd.words) + list(cmd.redirs)
    if prog == "git":
        sub = _git_effective(argv[1:], "/")[2]
        if sub in ("commit", "tag", "notes", "log", "show", "diff", "grep"):
            words = (
                [w for w in words if w.startswith("-") or w == sub or w == "git"]
                if False
                else []
            )
    for w in words:
        if pat.search(w):
            return MSG_HERMES_HOME
    return None


def _check_program(argv):
    prog = os.path.basename(argv[0])
    args = argv[1:]
    if prog == "hermes" and "dashboard" in args and "--stop" in args:
        return MSG_HERMES_HOME
    if prog == "killall":
        return MSG_KILL
    if prog == "pkill":
        for a in args:
            if a == "--full" or (
                a.startswith("-") and not a.startswith("--") and "f" in a[1:]
            ):
                return MSG_KILL
    return None


def _check_cmds(cmds, cwd, depth):
    saw_setup = False
    for cmd in cmds:
        words = cmd.words
        if any("setup_git_hooks" in w for w in words):
            saw_setup = True
        argv = _strip_prefix(words)
        if not argv:
            m = _check_hermes_home(words, cmd) if words else None
            if m:
                return m
            continue
        prog = os.path.basename(argv[0])
        m = _check_hermes_home(argv, cmd)
        if m:
            return m
        if prog == "cd" and len(argv) > 1:
            cwd = os.path.normpath(os.path.join(cwd, os.path.expanduser(argv[1])))
            continue
        if prog == "git":
            m = _check_git(argv, cwd, saw_setup)
        else:
            m = _check_program(argv)
        if m:
            return m
        if depth < 5:
            if prog in SHELLS:
                script = None
                rest = argv[1:]
                for idx, a in enumerate(rest):
                    if a.startswith("-") and not a.startswith("--") and "c" in a[1:]:
                        script = rest[idx + 1] if idx + 1 < len(rest) else None
                        break
                    if not a.startswith("-"):
                        break
                if script is not None:
                    m = _check(script, cwd, depth + 1)
                elif not any(not a.startswith("-") for a in rest):
                    for body in cmd.heredocs:
                        m = m or _check(body, cwd, depth + 1)
                if m:
                    return m
            elif prog == "eval":
                m = _check(" ".join(argv[1:]), cwd, depth + 1)
                if m:
                    return m
    return None


def _check(command, cwd, depth):
    cmds, _ = _lex(command)
    return _check_cmds(cmds, cwd, depth)


def check(command, cwd):
    """Return None to allow `command`, else the message to show the model."""
    return _check(command, cwd or os.getcwd(), 0)


# ---------------------------------------------------------------- entry


def _post(data):
    cmd = (data.get("tool_input") or {}).get("command", "")
    if not re.search(r"\bgit\b.*\b(pull|merge)\b", cmd):
        return
    cwd = data.get("cwd") or os.getcwd()
    rc, top = _git(cwd, "rev-parse", "--show-toplevel")
    if rc != 0 or not top:
        return
    rc, names = _git(
        top, "diff", "--name-only", "ORIG_HEAD", "HEAD", "--", "lib/l10n/arb"
    )
    if rc != 0 or not names:
        return
    try:
        subprocess.run(
            ["flutter", "gen-l10n"], cwd=top, capture_output=True, timeout=90
        )
        note = "ARB files changed; ran `flutter gen-l10n`."
    except FileNotFoundError:
        note = (
            "ARB files changed; run `flutter gen-l10n` (flutter is not on PATH here)."
        )
    except Exception:
        note = "ARB files changed; run `flutter gen-l10n` (the automatic run failed)."
    print(
        json.dumps(
            {
                "hookSpecificOutput": {
                    "hookEventName": "PostToolUse",
                    "additionalContext": note,
                }
            }
        )
    )


def main():
    try:
        data = json.load(sys.stdin)
        if data.get("tool_name") != "Bash":
            return 0
        if "--post" in sys.argv:
            _post(data)
            return 0
        command = (data.get("tool_input") or {}).get("command") or ""
        msg = check(command, data.get("cwd") or os.getcwd())
    except Exception as e:  # fail open: an internal error must not block work
        print(
            "guard_bash: internal error, allowing the command: %r" % (e,),
            file=sys.stderr,
        )
        return 0
    if msg:
        print(msg, file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
