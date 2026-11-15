---
name: agent-guard
description: Use when the Bash guard hook blocks a command (Blocked: ... message), when a banned-command rule needs adding, changing or loosening, or when the guard blocks something legitimate (a false positive).
---

# Agent guard (Bash PreToolUse hook)

`.claude/hooks/guard_bash.py` runs before every Bash call in an agent session,
subagents included (settings-level hooks apply to them). It blocks with exit
code 2 and its stderr message goes to the model. CI and the bot workflows never
run it: hooks exist only in Claude Code sessions, and nothing under
`.github/workflows` calls the script.

## When it blocks you

Do what the message says; do not look for another spelling of the same command.
The messages are the rules: no `--no-verify`/`-n`, no `core.hooksPath` change,
no `git stash`, no staging everything (`git add -A`, `.`, `commit -a`), no force
push or remote branch deletion, no rebase of a branch that exists on origin,
no commit before `dart run tool/setup_git_hooks.dart`, no touching the real
`~/.hermes`, no `pkill -f`/`killall`.

If a harmless command is blocked, that is a false positive: fix the parser and
add a test, do not work around it.

## How it works

- `check(command, cwd)` returns None (allow) or the message. It lexes the
  command into simple commands (quotes, `&&`, `||`, `;`, `|`, newlines,
  `$(...)`, backticks, heredocs), strips `VAR=x` and wrappers (`env`,
  `command`, `nohup`, `timeout`, `time`, `nice`), recurses into `bash -c`,
  `eval` and shell heredocs, skips git global options, and looks only at real
  argv tokens, so a commit message or heredoc mentioning `--force` is fine.
- It fails open: an internal error prints a warning and exits 0, because a hook
  that crashes with any code other than 2 does not block anyway.
- `permissions.deny` in `.claude/settings.json` is only a backstop. Deny rules
  match command text, so they miss `git -C . push -f`, `sh -c` and flags after
  the remote. The generated client has no deny rule on purpose: it could
  block the scripted regeneration in sandboxed sessions, and
  `verify-hermes-api-client.yml` already fails CI on a hand edit.
- With `--post` the same script is a PostToolUse hook that runs
  `flutter gen-l10n` after a pull or merge that changed `lib/l10n/arb/*.arb`.

- Beyond git it also blocks `gh pr merge --delete-branch`, `gh api -X DELETE`
  on `git/refs`, `-c alias.*` and `GIT_CONFIG_KEY_*` for `core.hooksPath` or
  aliases, removing or `chmod -x` of the pre-commit hook, `git pull --rebase`
  on a pushed branch, and a bare `hermes` command that would use the real home
  (set `HERMES_HOME=` or pass `--isolated`).
- The hook-integrity rules (core.hooksPath, the pre-commit file, commit without
  the hook) apply only to this project's own repo: the command's effective
  directory (`cd`, `git -C`) must share a git common dir with
  `$CLAUDE_PROJECT_DIR`; an unset variable means in-project. `--global` and
  `--system` config changes are always blocked. History rules (stash, force,
  delete, rebase, `add -A`, `--no-verify`) apply everywhere. The scope follows
  `--git-dir`, `--work-tree`, `GIT_DIR`, `GIT_WORK_TREE` and `GIT_COMMON_DIR`
  when given. With the variable set, a path that is not (yet) a repo is outside
  the project, so `git init X && git -C X config core.hooksPath h` is fine.
  `git config --file F` is scoped by the repo that holds F; a file outside any
  repo (`~/.gitconfig`) counts as shared config, and a path the hook cannot
  resolve (`$VAR`) is assumed to be shared and blocked.
- A bare `hermes` call is allowed only with `HERMES_HOME=` (non-empty) in front
  of that command, an earlier `export` or bare assignment, or `--isolated`.
- After a `git pull`/`merge` the PostToolUse hook runs only when the PreToolUse
  pass saw that command and the reflog grew. The pass records the reflog length
  in `<git-common-dir>/hermes-guard/<tool_use_id>` (per repo, mode 0600 in a
  0700 directory, created with `O_EXCL|O_NOFOLLOW`). Records older than an hour
  are deleted on the next run, and the `PostToolUseFailure` hook (same
  `--post` command) drops the record of a command that failed.
- The pre-commit check asks `git rev-parse --git-path hooks/pre-commit`, so it
  follows `core.hooksPath` like `tool/setup_git_hooks.dart` does, and wants the
  file executable.

Known gaps: a program named by substitution (`$(which git) stash`), a banned
command inside a script file or a git alias defined in a config file, `find
-exec` and similar runners, other ways to delete a remote branch through
`gh`, a hook path built from a variable (`$HOOKS/pre-commit`) or written with
`sed -i` or `python`, and hosts without `python3` (the hook then cannot run and
does not block).

## Add or change a rule

1. Add a message constant and a branch in `_check_git`, `_check_program` or
   `_check_hermes_home` in `.claude/hooks/guard_bash.py`.
2. Add positive cases, evasion forms (`git -C . ...`, `bash -c`, `VAR=1 ...`,
   `cd x && ...`, absolute path to git) and a false-positive trap (the banned
   word inside `-m`, a heredoc, `grep -- ...`) to `scripts/test_guard_bash.py`.
3. Run `python3 -m unittest discover -s scripts -p 'test_guard_bash.py'`; CI's
   `Test scripts` step discovers it.
4. Replay real commands through `check()` (every Bash tool_use in
   `~/.claude/projects/**/*.jsonl`, and the fenced bash blocks in `CLAUDE.md`
   and `.claude/skills/*/SKILL.md`) and confirm nothing legitimate is blocked.
