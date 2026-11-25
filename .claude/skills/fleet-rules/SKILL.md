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
- Run every test that names what you change. Before pushing, search `test/`,
  `widgetbook/` and `integration_test/` for each user-visible string, ARB key,
  public symbol or file name the change alters, and run every test file that
  names one, not only the files the change touches. Say which in `## Proof`.
- Fast local feedback. Prefer checks that run in the pre-commit hook or in
  `flutter test test/architecture` (the ratchet from #1144; see the
  `architecture-guards` skill; under a second) over CI-only checks.

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
- No `git worktree prune` (it deletes records of trees other sessions use). Remove one
  tree with `git worktree remove <path>` once it is clean and merged.
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

Authors may add fix notes to `## Review`, but never write or change a
`Reviewer: ... Head: ... Verdict:` line or its `Range:` line (once the
reviewer emits one): those are pasted from the isolated reviewer's output,
unchanged. Paste the block as plain lines,
not inside a code fence (`pr-policy` ignores review lines inside fences). Order:
push, review the pushed head, paste.

Catalog first (`PR policy`): a PR that adds a public widget class under
`lib/src/**/widgets/` fails unless a line it adds names one of the new
classes, in a widgetbook `.dart` file. Fix: add the use case
(`component-catalog`). Only when none applies (no state or layout to show, or
"shown through the `<Parent>` use case"), the isolated reviewer emits
`Catalog-first: not applicable, <reason>` in its block, pasted unchanged with
the rest of the block. Only a line inside that pasted block counts, which
relies on the block being pasted unchanged, like the `Reviewer:` line; details in
`flutter-ci`.

Design line (advisory): a PR that changes a file under `lib/src/**/widgets/`,
a `lib/**/*_screen.dart` or `lib/src/theme/` names its design record in the PR
body with `Design: <canvas link or design record path>` or `Design: not needed,
<reason>`. The isolated reviewer confirms it and emits `Design: confirmed ...`
or a finding. It is a reviewer finding, not a `PR policy` failure, for now.

## READY and merging

A session reports READY to the orchestrator when all of these hold:

- The isolated review is clean and recorded in the PR body as the
  `Reviewer: ... Head: <full sha> Verdict: clean` line for the PR's current
  head. The reviewer gets the diff (or PR number) and the rules, never the
  author's conclusions (`isolated-reviewer` agent).
- For a UI PR, the design canvas is linked.
- Main is merged in wherever main changed the PR's files. Exception: after one
  merge of main with a clean merge-only review, a PR is READY even if main moves
  again in a shared file, provided (1) `git merge-tree` against current
  origin/main is clean, (2) the later main commits do not change the same
  functions, classes or doc section the PR changes, (3) `Analyze & test` is
  green on the reviewed head. The READY report names the later main commits
  checked for (2). If
  (2) fails, re-merge and get a scoped merge-only review.

A "Dart PR" is one that touches any `.dart` file, `pubspec.*`,
`analysis_options.yaml` or `l10n.yaml`.

The trial merge (`scripts/premerge_check.sh`) is not a merge gate. Decision of
the owner, 2026-11-24 21:55 UTC, asked what to stop: "Drop trial merges". READY
is the list above, with the required checks green on the head; the trial is not
part of it. After a merge,
the orchestrator reads main's push run, and a break is fixed forward at once (or
the merge reverted). The script stays as an optional tool for a risky pair of
PRs, such as two PRs touching the same files, or a stack (`premerge-check`
skill).

A READY report names the directories the PR touches under `lib/`, `test/`,
`widgetbook/` and `packages/` (or "none").

The orchestrator then arms squash auto-merge when READY, and GitHub waits for
the required checks on the head. Read check state with `status-reader`
or `pull_request_read`; pending, queued and in-progress are not green.

The orchestrator has at most one armed or hand-merged Dart PR at a time, until
it has merged.

Every hand merge but the release-please PR's (below) needs a READY report, a
clean recorded review for the exact head, and every required check green on
that head, except the per-shard checks in the docs-only case. It is a squash
merge, and the orchestrator does it. A Dart PR (the release-please PR aside) is
hand-merged only when auto-merge cannot merge it (the one-armed-Dart-PR limit).

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
  The orchestrator arms it at its discretion, an interim cut as well as one
  that closes a wave, once main's tip has a full green run (the five builds
  included) and the release PR's current head has its five builds green; it
  disarms it when a new head arrives, and arms it last (see the `release`
  skill). When every one of those conditions holds, no other PR is armed or
  about to merge, and GitHub refuses to arm auto-merge because the PR is
  already clean (every required check green, nothing pending), the orchestrator
  squash-merges it directly with the head SHA pinned (`expectedHeadSha`, or the
  merge API's `sha`). Otherwise, once those conditions hold, it is armed (and
  disarmed when a new head arrives).
- Docs-only PRs cannot auto-merge while the ruleset requires the individual
  test shards (they never report on a docs-only PR). Docs-only means the
  `Changes` job output `code=false` on the exact head, so the shards show
  skipped. Such a PR is hand-merged under the rule above, with `PR policy`,
  `Review recorded` and `Analyze & test` green on that exact head. The exception
  ends when the owner drops the per-shard required checks.

Stacked PRs: merge bottom-up. After the lower PR merges, retarget the next one
to main, merge main into its branch, get a review of the new head (a clean
merge-only review is enough, as for any main merge), then report READY as
usual. A retarget alone does not rerun CI, so the checks are read on the new
head. See `parallel-ui-rollout` for the rest of the stack and fan-out practice.

## Device-only checks

Anything not verified on a device (watch, widgets, notifications, native
audio, App Lock on hardware) is listed under `## Not verified on a device`.
Do not describe it as checked because a test or simulator passed.

## See also

`parallel-ui-rollout` (fan-out, waves, shared files), `flutter-ci` (failed
checks, path filters), `verify` (real-backend certification), `verify-in-app`
(running the app), `release` (cutting and shipping).
