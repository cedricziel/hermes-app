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
import time

SHELLS = {"bash", "sh", "zsh", "dash", "ksh"}
KEYWORDS = {"if", "then", "else", "elif", "do", "while", "until", "{", "}", "!"}
REBASE_CONTINUE = (
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
MSG_HOOK_FILE = (
    "Blocked: removing, emptying or making the pre-commit hook non-executable. Fix what "
    "the hook reports; reinstall it with `dart run tool/setup_git_hooks.dart`."
)
MSG_ALIAS = (
    "Blocked: defining a git alias on the command line (-c alias.*) can hide a banned "
    "command from this guard. Don't alias around the guard; run the git command itself."
)
MSG_STASH = (
    "Blocked: git stash. The stash stack is shared by every worktree and session. "
    "Commit work in progress on your own branch instead."
)
MSG_ADD_ALL = (
    "Blocked: staging everything (`git add -A/--all/./:/`, `git add -u` without paths, "
    "`git commit -a`, `git commit .`). Building the apps rewrites tracked ios/ and "
    "macos/ files. Stage files by name: `git add path/a.dart path/b.dart`."
)
MSG_FORCE = (
    "Blocked: force push. Never rewrite a pushed branch: merge main in "
    "(`git merge origin/main`) and push normally. If a merged branch must restart, "
    "push under a new branch name."
)
MSG_DELETE = (
    "Blocked: deleting a remote branch (--delete, -d, :branch, --prune, --delete-branch, "
    "DELETE on git/refs). Never delete remote branches."
)
MSG_REBASE = (
    "Blocked: rebasing (git rebase, git pull --rebase) a branch that exists on origin "
    "rewrites pushed history. Merge main in instead: `git merge origin/main`."
)
MSG_NO_HOOK = (
    "Blocked: git commit without an executable pre-commit hook in this clone. "
    "Run `dart run tool/setup_git_hooks.dart` first, then commit."
)
MSG_HERMES_HOME = (
    "Blocked: this touches the real Hermes home (~/.hermes) or runs hermes against it, "
    "or stops the real dashboard. Use scripts/dev-backend.sh, which runs a throwaway "
    "Hermes with its own HERMES_HOME."
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
        self.herestrings = []
        self.piped_from = None


def _lex(s, i=0, nested=False):
    """Split shell text into simple commands.

    Returns (commands, index). Commands from $(...), backticks and subshells are
    appended to the same flat list. When `nested`, stops at the closing ')'.
    """
    cmds = []
    cur = Cmd()
    buf = []
    has_word = False
    skip_next = None  # None | "redir" | "here" | "heredoc:" | "heredoc:-"
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
        elif skip_next == "here":
            cur.herestrings.append(w)
        elif skip_next and skip_next.startswith("heredoc:"):
            pending_heredocs.append((w, skip_next == "heredoc:-"))
        else:
            cur.words.append(w)
        skip_next = None

    def end_cmd():
        nonlocal cur
        end_word()
        if cur.words or cur.redirs or cur.herestrings:
            cmds.append(cur)
        cur = Cmd()

    def read_heredocs(j, target):
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
            target.heredocs.append("\n".join(body))
        pending_heredocs = []
        return j

    def dollar_paren(j):
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
                i = read_heredocs(i, cmds[-1] if cmds else cur)
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
                    elif s[i + 1] != "\n":
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
            if op == "<<<":
                skip_next = "here"
            elif op == "<<-" or op.startswith("<<"):
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
            single_pipe = c == "|" and not (i + 1 < n and s[i + 1] == "|")
            i += 1
            if c == "|" and i < n and s[i] == "&":
                i += 1
            elif not single_pipe:
                while i < n and s[i] in ";&|":
                    i += 1
            if single_pipe and cmds:
                cur.piped_from = cmds[-1]
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

ASSIGN = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*\+?=")


def _strip_prefix(words):
    """Drop assignments, keywords and wrappers; return remaining argv."""
    w = list(words)
    while w:
        t = w[0]
        if ASSIGN.match(t) or t in KEYWORDS:
            w.pop(0)
        elif t in ("nohup", "builtin"):
            w.pop(0)
        elif t == "exec":
            w.pop(0)
            while w and w[0].startswith("-"):
                if w.pop(0) == "-a" and w:
                    w.pop(0)
        elif t == "time":
            w.pop(0)
            if w and w[0] == "-p":
                w.pop(0)
        elif t == "sudo":
            w.pop(0)
            long_arg = {
                "--user",
                "--group",
                "--chdir",
                "--host",
                "--prompt",
                "--role",
                "--type",
                "--other-user",
                "--chroot",
                "--close-from",
                "--command-timeout",
            }
            while w and w[0].startswith("-") and w[0] != "--":
                opt = w.pop(0)
                if opt in long_arg:
                    if w:
                        w.pop(0)
                elif not opt.startswith("--") and opt[-1] in "ugCDhprtURT" and w:
                    w.pop(0)
            if w and w[0] == "--":
                w.pop(0)
        elif t == "command":
            if len(w) > 1 and w[1] in ("-v", "-V"):
                return []
            w.pop(0)
            while w and w[0] == "-p":
                w.pop(0)
        elif t == "env":
            w.pop(0)
            while w and (w[0].startswith("-") or ASSIGN.match(w[0])):
                opt = w.pop(0)
                if opt in ("-u", "-C", "-S", "--unset", "--chdir") and w:
                    w.pop(0)
        elif t == "nice":
            w.pop(0)
            while w and w[0].startswith("-"):
                opt = w.pop(0)
                if opt in ("-n", "--adjustment") and w:
                    w.pop(0)
        elif t == "watch":
            w.pop(0)
            while w and w[0].startswith("-"):
                opt = w.pop(0)
                if opt in ("-n", "--interval") and w:
                    w.pop(0)
            if len(w) == 1:
                return ["eval", w[0]]  # watch 'cmd' runs it through sh -c
        elif t == "timeout":
            w.pop(0)
            while w and w[0].startswith("-"):
                opt = w.pop(0)
                if opt in ("-s", "-k", "--signal", "--kill-after") and w:
                    w.pop(0)
            if w:
                w.pop(0)  # duration
        elif t == "uv" and len(w) > 1 and w[1] == "run":
            w = w[2:]
            while w and w[0].startswith("-"):
                opt = w.pop(0)
                if opt in ("--with", "--python", "-p", "--project", "--directory", "--env-file", "--extra", "--group", "--package") and w:
                    w.pop(0)
        elif t == "xargs":
            w.pop(0)
            while w and w[0].startswith("-"):
                opt = w.pop(0)
                if opt in ("-n", "-I", "-L", "-P", "-s", "-d", "-E", "-a") and w:
                    w.pop(0)
        else:
            break
    return _python_module(w)


def _python_module(w):
    """`python3 -m hermes_cli ...` is the hermes command."""
    if w and re.match(r"^python[0-9.]*$", os.path.basename(w[0])):
        i = 1
        while i < len(w) and w[i] in ("-I", "-u", "-B", "-E", "-s", "-S", "-O", "-q"):
            i += 1
        if i + 1 < len(w) and w[i] == "-m" and w[i + 1].split(".")[0] in ("hermes_cli", "hermes"):
            return ["hermes"] + w[i + 2 :]
    return w


def _matches_long(tok, full, minlen):
    """git accepts unambiguous prefixes of long options."""
    name = tok.split("=", 1)[0]
    return len(name) >= minlen and full.startswith(name)


def _git_effective(args, cwd):
    """Skip git global options.

    Returns (config_overrides, cwd, sub, rest, opts) where opts holds the
    `git_dir` and `work_tree` given on the command line (absolute), if any.
    """
    configs = []
    opts = {}
    i = 0

    def abspath(p):
        return os.path.normpath(os.path.join(cwd, os.path.expanduser(p)))

    while i < len(args):
        a = args[i]
        if a == "-C" and i + 1 < len(args):
            cwd = abspath(args[i + 1])
            i += 2
        elif a.startswith("-C") and len(a) > 2:
            cwd = abspath(a[2:])
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
        elif a in ("--git-dir", "--work-tree") and i + 1 < len(args):
            opts[a[2:].replace("-", "_")] = abspath(args[i + 1])
            i += 2
        elif a.startswith("--git-dir=") or a.startswith("--work-tree="):
            k, _, v = a.partition("=")
            opts[k[2:].replace("-", "_")] = abspath(v)
            i += 1
        elif a in (
            "--namespace",
            "--exec-path",
            "--super-prefix",
            "--attr-source",
        ) and i + 1 < len(args):
            i += 2
        elif a.startswith("-"):
            i += 1
        else:
            return configs, cwd, a, args[i + 1 :], opts
    return configs, cwd, None, [], opts


def _git(cwd, *args):
    try:
        r = subprocess.run(
            ["git", "-C", cwd, *args], capture_output=True, text=True, timeout=5
        )
        return r.returncode, r.stdout.strip()
    except Exception:
        return 1, ""


# ---------------------------------------------------------------- git rules

# Per subcommand: short letters that take a REQUIRED value (the rest of the
# cluster, else the next word), short letters whose value is OPTIONAL and only
# ever attached (never the next word), long options with a required value that
# may be given as the next word. Long options with an optional value
# (--gpg-sign, --untracked-files, --signed, --force-with-lease) are absent on
# purpose: they never take the next word.
COMMIT_SHORT_ARG = set("mFCct")
COMMIT_SHORT_OPT = set("Su")
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
}
PUSH_SHORT_ARG = set("o")
PUSH_LONG_ARG = {
    "--repo",
    "--receive-pack",
    "--exec",
    "--push-option",
    "--recurse-submodules",
}
ADD_LONG_ARG = {"--pathspec-from-file", "--chmod"}
PULL_SHORT_ARG = set("sXj")
PULL_SHORT_OPT = set("S")
PULL_LONG_ARG = {
    "--strategy",
    "--strategy-option",
    "--jobs",
    "--upload-pack",
    "--depth",
    "--shallow-since",
    "--shallow-exclude",
    "--deepen",
    "--negotiation-tip",
}


def _walk(args, short_arg, short_opt, long_arg):
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
            letters = []
            takes_next = False
            body = a[1:]
            for idx, ch in enumerate(body):
                if ch in short_arg:
                    takes_next = idx == len(body) - 1
                    break
                if ch in short_opt:
                    break
                letters.append(ch)
            yield "short", letters
            if takes_next:
                i += 1
        i += 1


def _is_hookspath(key):
    return key.lower() == "core.hookspath"


def _on_pushed_branch(cwd):
    rc, branch = _git(cwd, "symbolic-ref", "--short", "-q", "HEAD")
    if rc == 0 and branch:
        rc2, _ = _git(
            cwd, "rev-parse", "--verify", "--quiet", "refs/remotes/origin/" + branch
        )
        return rc2 == 0
    return False


def _hook_ok(cwd):
    rc, path = _git(cwd, "rev-parse", "--git-path", "hooks/pre-commit")
    if rc != 0 or not path:
        return True  # not a repo or git failed: fail open
    full = os.path.join(cwd, path)
    return os.path.isfile(full) and os.access(full, os.X_OK)


def _common_dir(path, git_dir=None):
    args = ["rev-parse", "--git-common-dir"]
    if git_dir:
        args = ["--git-dir", git_dir] + args
    rc, out = _git(path, *args)
    if rc != 0 or not out:
        return None
    return os.path.realpath(os.path.join(path, out))


def _project_common():
    """None: no project known (rules apply everywhere); else its git common dir."""
    proj = os.environ.get("CLAUDE_PROJECT_DIR")
    if not proj:
        return None
    return _common_dir(proj)


def _in_project(path, git_dir=None):
    """Is the repo at `path` (or at `git_dir`) this project's repo?

    The hook-integrity rules only protect the project's own hook. An unset
    CLAUDE_PROJECT_DIR counts as in-project. With it set, a path that is not
    (yet) a repo is out of the project.
    """
    if not os.environ.get("CLAUDE_PROJECT_DIR"):
        return True
    mine = _project_common()
    if mine is None:
        return True  # cannot tell what the project is: keep the rules on
    return _common_dir(path, git_dir) == mine


def _scope_is_project(cwd, opts, env_words):
    """Scope a git command by --git-dir/--work-tree, GIT_DIR, GIT_COMMON_DIR, else cwd."""
    git_dir = opts.get("git_dir")
    work_tree = opts.get("work_tree")
    for w in env_words:
        k, _, v = w.partition("=")
        if k == "GIT_DIR" and not git_dir:
            git_dir = os.path.normpath(os.path.join(cwd, os.path.expanduser(v)))
        elif k == "GIT_WORK_TREE" and not work_tree:
            work_tree = os.path.normpath(os.path.join(cwd, os.path.expanduser(v)))
        elif k == "GIT_COMMON_DIR":
            mine = _project_common()
            if not os.environ.get("CLAUDE_PROJECT_DIR") or mine is None:
                return True
            if os.path.realpath(os.path.join(cwd, os.path.expanduser(v))) == mine:
                return True
    if git_dir or work_tree:
        hits = []
        if git_dir:
            hits.append(_in_project(cwd, git_dir))
        if work_tree:
            hits.append(_in_project(work_tree))
        return any(hits)
    return _in_project(cwd)


def _path_in_project(word, cwd):
    """Is a hook-file path inside the project's repo? Unresolvable means yes."""
    if "$(" in word or word.startswith("$"):
        return True
    full = os.path.normpath(os.path.join(cwd, os.path.expanduser(word)))
    d = os.path.dirname(full)
    while d and not os.path.isdir(d) and d != os.path.dirname(d):
        d = os.path.dirname(d)
    return _in_project(d or cwd)


def _file_scope(path, cwd):
    """True when a `git config --file` target counts as shared or project config."""
    if "$(" in path or path.startswith("$"):
        return True  # unresolvable: assume the worst
    full = os.path.normpath(os.path.join(cwd, os.path.expanduser(path)))
    d = os.path.dirname(full)
    while d and not os.path.isdir(d) and d != os.path.dirname(d):
        d = os.path.dirname(d)
    if _common_dir(d) is None:
        return True  # not in any repo, e.g. ~/.gitconfig: shared by every repo
    return _in_project(d)


def _config_truthy(entry):
    key, eq, val = entry.partition("=")
    return not eq or val.lower() not in ("false", "0", "no", "off")


def _check_git(argv, cwd, installed_hook_in_same_command, env_words=()):
    configs, cwd, sub, rest, opts = _git_effective(argv[1:], cwd)
    local = _scope_is_project(cwd, opts, env_words)
    for c in configs:
        key = c.split("=", 1)[0]
        if _is_hookspath(key) and local:
            return MSG_HOOKS_PATH
        if key.lower().startswith("alias."):
            return MSG_ALIAS
    if sub is None:
        return None

    if sub == "stash":
        return MSG_STASH

    if sub == "config":
        pos = [a for a in rest if not a.startswith("-")]
        shared = any(a in ("--global", "--system") for a in rest)
        by_file = None
        for i, a in enumerate(rest):
            # --file names the config file: a file in a repo is scoped by that
            # repo; one outside any repo (~/.gitconfig, /tmp/x) is shared config
            f = None
            if a in ("--file", "-f") and i + 1 < len(rest):
                f = rest[i + 1]
            elif a.startswith("--file="):
                f = a.split("=", 1)[1]
            if f is not None:
                by_file = _file_scope(f, cwd)
                shared = shared or by_file
        # an explicit --file replaces the current repo as the scope
        scoped = local if by_file is None else False
        if any(_is_hookspath(a) for a in pos) and (shared or scoped):
            read = any(
                a.startswith("--get") or a in ("-l", "--list") for a in rest
            ) or (bool(pos) and pos[0] in ("get", "list"))
            write = any(
                a in ("--unset", "--unset-all", "--add", "--replace-all") for a in rest
            ) or (bool(pos) and pos[0] in ("set", "unset", "add", "replace-all"))
            if write or (not read and len(pos) >= 2):
                return MSG_HOOKS_PATH
        if any(a.lower().startswith("alias.") for a in pos):
            if len(pos) >= 2 and pos[0] not in ("get", "list"):
                return MSG_ALIAS
        return None

    if sub == "add":
        pos, flag_all, flag_u = [], False, False
        for kind, v in _walk(rest, set(), set(), ADD_LONG_ARG):
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
        if flag_all or any(p in (".", "./", ":/", ":(top)", "*") for p in pos):
            return MSG_ADD_ALL
        if flag_u and not pos:
            return MSG_ADD_ALL
        return None

    if sub == "commit":
        pos = []
        for kind, v in _walk(rest, COMMIT_SHORT_ARG, COMMIT_SHORT_OPT, COMMIT_LONG_ARG):
            if kind == "long":
                if _matches_long(v, "--no-verify", 6):
                    return MSG_NO_VERIFY
                if _matches_long(v, "--all", 4):
                    return MSG_ADD_ALL
            elif kind == "short":
                if "n" in v:
                    return MSG_NO_VERIFY
                if "a" in v:
                    return MSG_ADD_ALL
            else:
                pos.append(v)
        if any(p in (".", "./", ":/", ":(top)", "*") for p in pos):
            return MSG_ADD_ALL
        if not installed_hook_in_same_command and "--help" not in rest and local:
            if not _hook_ok(cwd):
                return MSG_NO_HOOK
        return None

    if sub == "push":
        for kind, v in _walk(rest, PUSH_SHORT_ARG, set(), PUSH_LONG_ARG):
            if kind == "long":
                if _matches_long(v, "--no-verify", 6):
                    return MSG_NO_VERIFY
                if _matches_long(v, "--force", 5) or v.startswith("--force-"):
                    return MSG_FORCE
                if _matches_long(v, "--delete", 4) or v.split("=")[0] in (
                    "--prune",
                    "--mirror",
                ):
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

    if sub == "pull":
        rebase = any(
            c.split("=", 1)[0].lower() == "pull.rebase" and _config_truthy(c) for c in configs
        )
        for kind, v in _walk(rest, PULL_SHORT_ARG, PULL_SHORT_OPT, PULL_LONG_ARG):
            if kind == "long":
                name, _, val = v.partition("=")
                if name == "--no-rebase":
                    rebase = False
                elif _matches_long(name, "--rebase", 5):
                    rebase = val.lower() not in ("false", "0", "no")
            elif kind == "short" and "r" in v:
                rebase = True
        if rebase and _on_pushed_branch(cwd):
            return MSG_REBASE
        return None

    if sub == "rebase":
        if any(a in REBASE_CONTINUE for a in rest):
            return None
        if _on_pushed_branch(cwd):
            return MSG_REBASE
        return None
    return None


# ---------------------------------------------------------------- hermes, kill, hooks


def _real_home():
    homes = set()
    for h in (os.environ.get("HOME"), os.path.expanduser("~")):
        if h and h != "/":
            homes.add(os.path.normpath(h))
    return homes


def _home_pattern():
    alts = {"~", "$HOME", "${HOME}"} | _real_home()
    alt = "|".join(re.escape(h) for h in sorted(alts, key=len, reverse=True))
    return re.compile(r"(?:^|[=:,])(?:" + alt + r")/\.hermes(?:/|$|[*?\[{])")


TEXT_ONLY = {"echo", "printf", "gh", "grep", "rg"}
HERMES_SAFE_ARGS = {
    "--help",
    "-h",
    "--version",
    "-V",
    "--print-runtime-command",
    "--isolated",
}


def _resolves_to_hermes_home(word, cwd):
    if not word or word.startswith("-") or word.startswith("$") or "$(" in word:
        return False
    if word.startswith("/") or word.startswith("~"):
        return False  # absolute forms are caught by the pattern
    full = os.path.normpath(os.path.join(cwd, word))
    for h in _real_home():
        base = os.path.join(h, ".hermes")
        if full == base or full.startswith(base + os.sep):
            return True
    return False


HOME_ASSIGN = re.compile(r"^HERMES_HOME=.+")


def _hermes_home_set(words):
    return any(HOME_ASSIGN.match(w) for w in words)


def _sets_home_for_later(words):
    """A bare assignment or export statement that sets HERMES_HOME for what follows."""
    if not words or not _hermes_home_set(words):
        return False
    return words[0] in ("export", "declare", "typeset") or all(ASSIGN.match(w) for w in words)


def _hook_env_is_isolated():
    hh = os.environ.get("HERMES_HOME")
    if not hh:
        return False
    hh = os.path.normpath(os.path.expanduser(hh))
    return all(hh != os.path.join(h, ".hermes") for h in _real_home())


def _check_hermes_home(argv, cmd, cwd, home_set):
    # only an assignment in front of this very command (or an earlier export or
    # bare assignment) points hermes elsewhere; `HERMES_HOME=x true; hermes` does not
    prefix = cmd.words[: max(0, len(cmd.words) - len(argv))] if argv else []
    prog = os.path.basename(argv[0]) if argv else ""
    pat = _home_pattern()
    for r in cmd.redirs:  # a redirection writes, whatever the program is
        if pat.search(r) or _resolves_to_hermes_home(r, cwd):
            return MSG_HERMES_HOME
    if prog == "hermes":
        args = argv[1:]
        if not (
            home_set
            or _hermes_home_set(prefix)
            or _hook_env_is_isolated()
            or any(a in HERMES_SAFE_ARGS for a in args)
        ):
            return MSG_HERMES_HOME
    if prog in TEXT_ONLY:
        return None
    if prog == "git":
        sub = _git_effective(argv[1:], "/")[2]
        if sub in ("commit", "tag", "notes", "log", "grep"):
            return None  # message and pattern text, not paths
    for w in list(cmd.words):
        if pat.search(w) or _resolves_to_hermes_home(w, cwd):
            return MSG_HERMES_HOME
    return None


HOOK_PATH = re.compile(
    r"(?:^|/)(?:hooks|\.?githooks)/pre-commit$|^\$\(\.\.\.\)(?:/hooks)?/pre-commit$"
)
SAFE_CHMOD = re.compile(r"^(?:[ugoa]*\+[rwXst]*x[rwXst]*|0?[0-7][1357][0-7]{1,2})$")


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


def _check_hook_file(argv, cmd, cwd):
    """Removing, overwriting or de-executing the project's pre-commit hook."""
    hit = [r for r in cmd.redirs if HOOK_PATH.search(r)]  # `: > hook`, `echo x > hook`
    if argv:
        prog = os.path.basename(argv[0])
        args = [a for a in argv[1:] if not a.startswith("-") or a == "-"]
        if prog in ("rm", "unlink", "mv", "truncate", "shred", "ln", "tee"):
            hit += [a for a in args if HOOK_PATH.search(a)]
        elif prog in ("cp", "install") and args and HOOK_PATH.search(args[-1]):
            hit.append(args[-1])
        elif prog == "chmod":
            files = [a for a in argv[1:] if HOOK_PATH.search(a)]
            rest = [a for a in argv[1:] if a not in files and a not in ("-R", "-v", "-f", "-c")]
            if files and not (rest and SAFE_CHMOD.match(rest[0])):
                hit += files
    if any(_path_in_project(h, cwd) for h in hit):
        return MSG_HOOK_FILE
    return None


GIT_ENV = re.compile(r"^GIT_CONFIG_KEY_\d+=(core\.hookspath|alias\.)", re.I)


def _check_env_words(words):
    for w in words:
        m = GIT_ENV.match(w)
        if m:
            return (
                MSG_HOOKS_PATH if m.group(1).lower().startswith("core") else MSG_ALIAS
            )
    return None


def _gh_check(argv):
    args = argv[1:]
    if not args:
        return None
    if args[:2] == ["pr", "merge"]:
        for a in args[2:]:
            if a.split("=", 1)[0] == "--delete-branch" and a.partition("=")[2].lower() != "false":
                return MSG_DELETE
            if (
                a.startswith("-") and not a.startswith("--") and "d" in a[1:]
            ):
                return MSG_DELETE
    if args[0] == "api":
        method = None
        for i, a in enumerate(args):
            if a in ("-X", "--method") and i + 1 < len(args):
                method = args[i + 1]
            elif a.startswith("--method="):
                method = a.split("=", 1)[1]
            elif a.startswith("-X") and len(a) > 2:
                method = a[2:]
        if method and method.upper() == "DELETE" and any("git/refs" in a for a in args):
            return MSG_DELETE
    return None


# ---------------------------------------------------------------- driver


def _shell_script(prog_args):
    """For a shell invocation return (script_or_None, reads_stdin)."""
    c_seen = False
    i = 0
    while i < len(prog_args):
        a = prog_args[i]
        if a == "--":
            i += 1
            break
        if a.startswith("--"):
            if a in ("--rcfile", "--init-file") and i + 1 < len(prog_args):
                i += 1
            i += 1
            continue
        if a[:1] in "-+" and len(a) > 1:
            letters = a[1:]
            if "c" in letters:
                c_seen = True
            if ("o" in letters or "O" in letters) and i + 1 < len(prog_args):
                i += 1
            i += 1
            continue
        break
    operands = prog_args[i:]
    if operands == ["-"]:
        return None, True
    if c_seen:
        return (operands[0] if operands else None), False
    return None, not operands


def _stdin_texts(cmd):
    texts = list(cmd.heredocs) + list(cmd.herestrings)
    src = cmd.piped_from
    hops = 0
    while src is not None and hops < 6:  # echo 'x' | tee f | bash
        texts.extend(src.heredocs)
        texts.extend(src.herestrings)
        sargv = _strip_prefix(src.words)
        p = os.path.basename(sargv[0]) if sargv else ""
        if p in ("echo", "printf"):
            texts.append(" ".join(a for a in sargv[1:] if not a.startswith("-")))
            break
        if p not in ("tee", "cat"):
            break
        src = src.piped_from
        hops += 1
    return texts


VAR_REF = re.compile(r"\$(?:\{([A-Za-z_][A-Za-z0-9_]*)\}|([A-Za-z_][A-Za-z0-9_]*))")


VAR_DEFAULT = re.compile(r"\$\{([A-Za-z_][A-Za-z0-9_]*):-([^}]*)\}")


def _expand(word, env):
    """Expand $NAME / ${NAME} / ${NAME:-default} from variables set earlier in
    the same command, plus CLAUDE_PROJECT_DIR."""
    if "$" not in word:
        return word
    word = VAR_DEFAULT.sub(lambda m: env.get(m.group(1)) or m.group(2), word)
    known = dict(env)
    proj = os.environ.get("CLAUDE_PROJECT_DIR")
    if proj:
        known.setdefault("CLAUDE_PROJECT_DIR", proj)
    return VAR_REF.sub(lambda m: known.get(m.group(1) or m.group(2), m.group(0)), word)


def _check_cmds(cmds, cwd, depth):
    saw_setup = False
    home_set = False
    env = {}
    for cmd in cmds:
        cmd.words = [_expand(w, env) for w in cmd.words]
        cmd.redirs = [_expand(w, env) for w in cmd.redirs]
        words = cmd.words
        decl = words[1:] if words and words[0] in ("export", "declare", "typeset") else words
        if decl and all(ASSIGN.match(w) for w in decl):
            for w in decl:
                k, _, v = w.partition("=")
                if "$(" not in v and "`" not in v:
                    env[k.rstrip("+")] = v
        if any("setup_git_hooks" in w for w in words):
            saw_setup = True
        m = _check_env_words(words)
        if m:
            return m
        argv = _strip_prefix(words)
        m = _check_hook_file(argv, cmd, cwd)
        if m:
            return m
        if not argv:
            m = _check_hermes_home([], cmd, cwd, home_set)
            if m:
                return m
            if _sets_home_for_later(words):
                home_set = True
            continue
        prog = os.path.basename(argv[0])
        m = _check_hermes_home(argv, cmd, cwd, home_set)
        if m:
            return m
        if _sets_home_for_later(words):
            home_set = True
        if prog == "cd":
            if len(argv) > 1 and argv[1] != "-":
                cwd = os.path.normpath(os.path.join(cwd, os.path.expanduser(argv[1])))
            elif len(argv) == 1:
                cwd = os.path.expanduser("~")
            continue
        if prog == "git":
            prefix = words[: max(0, len(words) - len(argv))]
            m = _check_git(argv, cwd, saw_setup, prefix)
        elif prog == "gh":
            m = _gh_check(argv)
        else:
            m = _check_program(argv)
        if m:
            return m
        if depth < 5:
            if prog in SHELLS:
                script, reads_stdin = _shell_script(argv[1:])
                if script is not None:
                    m = _check(script, cwd, depth + 1)
                elif reads_stdin:
                    for body in _stdin_texts(cmd):
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


# ---------------------------------------------------------------- post hook


def runs_pull_or_merge(command):
    """True when a simple command in `command` is `git pull` or `git merge`."""
    cmds, _ = _lex(command)
    for cmd in cmds:
        argv = _strip_prefix(cmd.words)
        if argv and os.path.basename(argv[0]) == "git":
            if _git_effective(argv[1:], "/")[2] in ("pull", "merge"):
                return True
    return False


MARKER_MAX_AGE = 3600


def _marker_dir(cwd):
    """Per repo and per user: <git-common-dir>/hermes-guard (mode 0700)."""
    common = _common_dir(cwd)
    if not common:
        return None
    d = os.path.join(common, "hermes-guard")
    os.makedirs(d, mode=0o700, exist_ok=True)
    return d


def _marker(data):
    tid = re.sub(r"[^A-Za-z0-9_-]", "", str(data.get("tool_use_id") or ""))
    if not tid:
        return None
    d = _marker_dir(data.get("cwd") or os.getcwd())
    if not d:
        return None
    try:  # a run an hour old never finished: forget it
        for name in os.listdir(d):
            path = os.path.join(d, name)
            if time.time() - os.lstat(path).st_mtime > MARKER_MAX_AGE:
                os.unlink(path)
    except OSError:
        pass
    return os.path.join(d, tid)


def _reflog_count(cwd):
    rc, out = _git(cwd, "rev-list", "--walk-reflogs", "--count", "HEAD")
    return int(out) if rc == 0 and out.isdigit() else 0


def _record_pre(data, command):
    """PreToolUse: remember how long HEAD's reflog is before a pull or merge runs."""
    if not runs_pull_or_merge(command):
        return
    marker = _marker(data)
    if not marker:
        return
    try:
        os.unlink(marker)
    except OSError:
        pass
    fd = os.open(marker, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, "w") as f:
        f.write(str(_reflog_count(data.get("cwd") or os.getcwd())))


def _read_marker(marker):
    fd = os.open(marker, os.O_RDONLY | os.O_NOFOLLOW)
    with os.fdopen(fd) as f:
        value = int(f.read())
    os.unlink(marker)
    return value


def _post(data):
    command = (data.get("tool_input") or {}).get("command", "")
    failed = data.get("hook_event_name") == "PostToolUseFailure"
    if not failed and not runs_pull_or_merge(command):
        return None  # cheap exit for every other command
    marker = _marker(data)  # also forgets records older than an hour
    if not marker or not os.path.lexists(marker):
        return None  # no PreToolUse record: this was not a pull or merge we saw
    try:
        before = _read_marker(marker)  # consumes the record
    except Exception:
        return None
    if failed or not runs_pull_or_merge(command):
        return None  # a failed command integrated nothing
    cwd = data.get("cwd") or os.getcwd()
    rc, top = _git(cwd, "rev-parse", "--show-toplevel")
    if rc != 0 or not top:
        return None
    if _reflog_count(top) <= before:
        return None  # nothing new: "Already up to date", or the command failed
    rc, subject = _git(top, "reflog", "-1", "--format=%gs")
    if rc != 0 or not (subject.startswith("pull") or subject.startswith("merge")):
        return None  # nothing was integrated by this command
    rc, names = _git(
        top, "diff", "--name-only", "HEAD@{1}", "HEAD", "--", "lib/l10n/arb"
    )
    if rc != 0 or not names:
        return None
    try:
        r = subprocess.run(
            ["flutter", "gen-l10n"], cwd=top, capture_output=True, text=True, timeout=90
        )
    except FileNotFoundError:
        return (
            "ARB files changed; run `flutter gen-l10n` (flutter is not on PATH here)."
        )
    except Exception:
        return "ARB files changed; run `flutter gen-l10n` (the automatic run failed)."
    if r.returncode != 0:
        tail = (r.stderr or r.stdout or "").strip().splitlines()[-3:]
        return (
            "ARB files changed but `flutter gen-l10n` failed; run it and fix: "
            + " | ".join(tail)
        )
    return "ARB files changed; ran `flutter gen-l10n`."


def main():
    try:
        data = json.load(sys.stdin)
        if data.get("tool_name") != "Bash":
            return 0
        if "--post" in sys.argv:
            note = _post(data)
            if note:
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
            return 0
        command = (data.get("tool_input") or {}).get("command") or ""
        msg = check(command, data.get("cwd") or os.getcwd())
        if not msg:
            try:
                _record_pre(data, command)
            except Exception:
                pass
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
