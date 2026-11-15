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
  the remote. `Edit(/packages/hermes_api/**)` keeps the generated client
  read-only for the file tools; the regeneration script via Bash stays allowed.
- With `--post` the same script is a PostToolUse hook that runs
  `flutter gen-l10n` after a pull or merge that changed `lib/l10n/arb/*.arb`.

Known gaps: aliases, variable program names, `find -exec`, scripts that run the
banned command inside a file.

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
