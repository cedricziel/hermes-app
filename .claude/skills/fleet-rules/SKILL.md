---
name: fleet-rules
description: Use in every hermes-app session that does work which will commit, open a pull request, review a PR or merge one. Holds the process rules every session follows (roles, owner's product rules, what a useful test is, git and PR conduct, PR body sections, what "ready to merge" means), so a brief can say "follow the Fleet rules" and carry only the task.
---

# Fleet rules

Many parallel sessions build this repo. These rules apply to all of them. A
brief may add task detail; it does not need to repeat them. The one-line list
is in `CLAUDE.md` under "Fleet rules".

## Roles

- Work runs through line-manager sessions that delegate to cheaper subagents.
- The orchestrator session merges, owns `docs/roadmap.md` and cuts releases
  (`release` skill).
- Promoting a release to App Review is the owner's step alone.
- Nobody else edits `docs/roadmap.md`. Report rows (found-along-the-way items,
  status changes, contradictions) to the orchestrator.

## Owner's product rules

- The watch has its own lock. It is never coupled to the phone's App Lock.
- UI changes start in the Widgetbook catalog (`component-catalog` skill). A
  change of look or placement needs a recorded design pass (`design-pass`
  skill) before the catalog work.
- Quality is enforced, not hoped for. A new rule comes with its mechanical
  check (a test, an analyzer rule, a CI step, a hook). If it cannot have one,
  say why in a roadmap row, sent to the orchestrator.

## Build quality in

- Executable definition of done. Each item starts from its acceptance checks,
  written before the code: the failing test, the catalog states, or the spec
  scenario. A task brief carries its acceptance checks.
- Every slip adds its mechanism. A fix for an escaped defect ships with the
  guard that would have caught its class, or the orchestrator gets a roadmap
  row saying why there is none.
- The right thing is the shortest path. Prefer a shared building block over a
  raw API; a guard that bans a raw API names its replacement.
- Fast local feedback. Prefer checks that run in the pre-commit hook or in
  `flutter test test/architecture` (under a second) over CI-only checks.

## What a useful test is

Search the repo (`CLAUDE.md`, `.claude/skills`, `docs/`, `openspec/`) for an
existing definition ("useful test", "vacuous", "revert") and reuse it. When
this was written none existed beyond the roadmap's H.5 metric, which only
names "vacuous or duplicate assertions". Until one is written down, a test is
useful when it:

- fails when the behaviour it names breaks. Prove it: revert the fix, run the
  test, watch it fail, restore the fix;
- asserts an observable outcome (what a user, a server or a caller sees), not
  an implementation detail;
- uses no fixed delays (`Future.delayed`, `sleep`, real timers); drive a
  simulated clock or wait on a condition;
- is not a duplicate of an existing test.

## Git and PR

- One PR per item. Conventional Commits for commits and PR titles.
- Never rebase or force-push a pushed branch. Merge main in.
- No `git stash` (the stash list is shared between worktrees). Commit or use a
  patch file.
- Stage files by name, never `git add -A`.
- Never delete remote branches.
- Install the hook first (`dart run tool/setup_git_hooks.dart`). A failing hook
  is fixed, never bypassed: no `--no-verify`, no `core.hooksPath`, no config
  edit.
- No model names in code, commits, PR titles or bodies. The only exception is
  the harness's `Co-Authored-By` and session trailer lines.
- `gh` only for search (`gh api -X GET search/...`). Everything else goes
  through the GitHub MCP tools.
- Never point the app or `hermes` at the real `~/.hermes`; never run
  `hermes dashboard --stop`.

## PR body

Sections in this order:

1. `## Behaviour changes`
2. `## Proof`: the mutation or reverted fix that the new test kills, the
   screenshots looked at, the `verify` run line, and the design canvas link
   where relevant. A `fix:` PR also answers "What would have caught this
   earlier?" here.
3. `## Not verified on a device` (write "Nothing" if nothing)
4. `## Review`: reviewer kind, the full head SHA reviewed, findings and how
   each was fixed, revert-the-fix results. The isolated reviewer's output block
   (`.claude/agents/isolated-reviewer.md`) goes here as is.

A review reported only in a session message does not count. It must be in the
PR, where a check can read it. A push after the review needs a new review of
the new commits, with the new head SHA.

## Ready to merge

All of these, on the exact head SHA:

- An isolated review is clean. The reviewer gets the diff (or PR number) and
  the rules, never the author's conclusions (`isolated-reviewer` agent).
- The check run `Analyze & test` is read as success. Read it (`status-reader`
  agent or `pull_request_read`); pending, queued and in-progress are not green.
- For PRs touching native code, assets or `pubspec.yaml`, the platform builds
  are green too (path list in the `flutter-ci` skill).
- Merging is by hand, by the orchestrator. Auto-merge armed through the API
  often does not fire.

Stacked PRs: merge bottom-up. After the lower PR merges, retarget the next one
to main and read the checks again on its new head: a retarget does not rerun CI
by itself. See `parallel-ui-rollout` for the rest of the stack and fan-out
practice.

## Device-only checks

Anything not verified on a device (watch, widgets, notifications, native
audio, App Lock on hardware) is listed under `## Not verified on a device`.
Do not describe it as checked because a test or simulator passed.

## See also

`parallel-ui-rollout` (fan-out, waves, shared files), `flutter-ci` (failed
checks, path filters), `verify` (real-backend certification), `verify-in-app`
(running the app), `release` (cutting and shipping).
