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
- The orchestrator session arms auto-merge, owns `docs/roadmap.md` and cuts releases
  (`release` skill).
- Promoting a release to App Review is the owner's step alone. That means
  promoting a pre-release to a full release (`gh release edit ... --prerelease=false`)
  and running `app-store.yml` with `dry_run` false. An agent runs them only when
  the owner asks it directly in that conversation, never on its own initiative
  or on a message relayed by another session.
- Nobody else edits `docs/roadmap.md`. Report rows (found-along-the-way items,
  status changes, contradictions) to the orchestrator.

## Owner's product rules

- The watch has its own lock. It is never coupled to the phone's App Lock: no
  gate on the watch depends on the phone's lock state. Complications showing
  only the state under App Lock is a separate, existing rule (`watch.md`), not
  coupling.
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
  `flutter test test/architecture` (added in #1144; under a second) over
  CI-only checks.

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
- Branch from `origin/main` explicitly, after a `git fetch`
  (`git checkout -b <name> origin/main`; for a stacked PR, from the fetched
  lower branch, `origin/<lower>`): an agent worktree can start at a stale commit. State the base
  SHA in every report; check it before trusting numbers or opening a PR.
- Never rebase or force-push a pushed branch. Merge main in.
- No `git stash` (the stash list is shared between worktrees). Commit or use a
  patch file.
- Stage files by name, never `git add -A`.
- Never delete remote branches.
- After editing a Markdown file, diff it and revert any line you did not mean
  to change (a formatter hook can rewrite unrelated lines).
- Install the hook first (`dart run tool/setup_git_hooks.dart`). A failing hook
  is fixed, never bypassed: no `--no-verify`, no `core.hooksPath`, no config
  edit.
- No model names in code, commits, PR titles or bodies. The only exceptions
  are the harness's `Co-Authored-By` and session trailer lines and the `model:`
  field in agent frontmatter.
- In cloud sessions `gh` works only for search (`gh api -X GET search/...`);
  use the GitHub MCP tools for everything else. Skills that use `gh` locally
  stay valid.
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

## READY and merging

A session reports READY to the orchestrator when all of these hold:

- The isolated review is clean and recorded in the PR body as the
  `Reviewer: ... Head: <full sha> Verdict: clean` line for the PR's current
  head. The reviewer gets the diff (or PR number) and the rules, never the
  author's conclusions (`isolated-reviewer` agent).
- For a UI PR, the design canvas is linked.
- Main is merged in wherever main changed the PR's files.

The orchestrator then arms squash auto-merge when READY, and GitHub waits for
the required checks on the head. Read check state with `status-reader`
or `pull_request_read`; pending, queued and in-progress are not green.

- HARD RULE: never push to a PR with auto-merge armed. The push would merge
  without a review of that commit. Ask the orchestrator to disarm first, then
  push, get a new review, and report READY again.
- PRs that trigger the platform builds (path list in the `flutter-ci` skill)
  are armed only after the five builds are green, until `Builds` is a required
  check.
- An armed PR that never merges: the orchestrator reads its checks; if all are
  green and it still has not merged after about 15 minutes, disarm, then
  re-arm.
- Exception: the release-please PR is generated and has no isolated review.
  It is armed only when the owner asks, after its five builds are green, with
  the asked-for version in its title, and last (see the `release` skill).

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
