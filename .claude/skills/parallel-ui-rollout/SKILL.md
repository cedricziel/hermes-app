---
name: parallel-ui-rollout
description: Use when one hermes-app change (a restyle, a shared widget migration, a design port) is being split, or should be split, across several agents that each open their own PR: planning the waves, writing the agent brief, and getting every PR merged without breaking main. The merge and review rules also apply to any other multi-agent fan-out.
---

# Rolling out a UI change with parallel agents

Learned from the clean settings restyle and its design port: about two dozen
PRs in #511–#542, over one night. These are the rules that would have saved
the rework.

## Before launching

- **Install the pre-commit hook in every clone.** Each agent runs
  `dart run tool/setup_git_hooks.dart` before its first commit, cloud sessions
  included, and fixes a failing hook instead of bypassing it (no `--no-verify`,
  no `core.hooksPath`, no config edit). Its `outdated` check makes dependency
  updates part of normal work.
- **Shared pieces first, alone.** Build the shared widgets (or their React
  copies in `design/web`) in one PR, merge it, and only then launch the screen
  agents with that PR's API notes. Parallel agents that each invent a group row
  produce five versions.
- **One owner per shared file.** Name, in each brief, which agent may change
  which shared file (`lib/src/widgets/*`, `widgetbook/frame.dart`,
  `design/web/src/index.ts`, `.design-sync/config.json`). Everyone else only
  adds to it after that owner's PR merges, or reports what they need. Main
  broke twice when PR pairs that each passed CI landed together (#523): two
  agents made the same helper public, and a shared-widget fix changed what
  another screen's test found.
- **Write the design and the brief down as files.** Agents can't open Claude
  Design or the orchestrator's conversation. Run the design pass first
  (`design-pass` skill), which records its decisions in the change's
  `design.md` and in `docs/design-briefs/<change>.md`. Put the brief and the
  shared API notes in the repo too, so cloud sessions can read them. Local
  worktree agents may also read the orchestrator's scratchpad by absolute
  path; a cloud session cannot.
- **Say what "visual only" means.** Restyle agents changed tap targets (a
  switch row that no longer flips on a row tap), flows (a picker sheet became
  an Add button) and added buttons (Done). Either forbid behaviour changes
  outright or require them under a "Behaviour changes" heading in the PR body.
- **Size the load, not just the count.** Every agent runs only the tests for
  the files it touched (`flutter test <files>`) and leaves the full suite to
  CI. Keep about four agents at once and launch more as earlier ones finish.
  Check `df -h /` before each wave; seven agents at once drove the load average
  to ~200 and the free disk under 500 MB.
- **Known collisions to put in the brief:** only one Hermes dashboard runs per
  machine (`verify-in-app` skill: use its isolated variant), and the worktree
  shell guard rejects compound commands that mention `git` (`.design-sync/NOTES.md`):
  run git as plain single commands (`git -C <path> ...`, no `cd x && git ...`).

## Every PR

- **Screenshots (desktop sessions with a browser).** Agents write combined before/after PNGs plus a `READY` file
  (`<file name> | <caption>` per line, file names relative to that folder) to
  `<orchestrator scratchpad>/shots/<PR number>/`. The orchestrator uploads them
  through Chrome: attach the files to the PR's new-comment box, read the
  `user-attachments` URLs out of the textarea, clear it with
  `textarea.select(); document.execCommand('delete')` (setting `.value`
  desyncs GitHub's editor), save them as `<file name> <URL>` lines in
  `uploaded.txt` next to `READY`, and put the images in a `## Screenshots`
  section of the PR body (update the PR with the GitHub MCP tools). GitHub returns 429
  silently after roughly 60–90 uploads an hour; upload in batches of up to
  about eight per call.
- **The PR body is shared.** The agent owns the text it opened the PR with, the
  orchestrator owns `## Screenshots` and the reviewer owns `## Review`. Whoever
  edits it re-reads the current body right before writing, changes only their
  own section and writes it back; an agent that regenerates the whole body from
  its own notes deletes the screenshots. If that happens, rebuild
  `## Screenshots` from `uploaded.txt`.
- **Review before merge.** CodeRabbit when it reviews. It often skips stacked
  PRs and it rate-limits. Then an isolated reviewer agent with fresh context is
  the review of record: it reads the PR diff (GitHub MCP tools) for correctness,
  accessibility and unintended behaviour or API changes, and its findings go
  in as `## Review`. Fix what it confirms. Never merge unreviewed.
- **Never rebase or force-push a pushed branch.** To pick up main or a lower
  branch, merge it in with a plain merge commit and push normally.

## While they run

- Keep watching every PR after its agent hands back: the harness can end an
  agent while CI is still running, and a later merge can turn its PR into a
  conflict nobody sees. A watcher that polls the open PRs (GitHub MCP
  `list_pull_requests`) and the screenshot folder, and remembers what it
  already reported, keeps the noise down.
- Check main's CI after each merge, not only the PR's. Each merge regenerates
  the release-please PR; that is expected.
- Visual Flutter changes leave the React copies in `design/web` stale (see
  `.design-sync/NOTES.md`). Find the PRs that need a port with
  `gh api -X GET search/issues -f q='repo:cedricziel/hermes-app is:pr is:merged "needs a design port" in:body'`
  and plan the port as part of the rollout.

## When lead agents cannot spawn agents

In a cloud session a lead agent may have no Agent tool. The hierarchy is then two
levels and the orchestrator does the reviewing:

- A lead's own read of its diff is not the review. After the lead hands back, the
  orchestrator starts the isolated reviewer described under "Every PR", for every
  PR, whether or not CodeRabbit also reviewed. Give it the branch name and what
  the PR claims, nothing else, and use a stronger model when a wrong merge would
  sign users out, lose a message or leak control of something (auth, the send
  path, leases, App Lock). Why: reviewers started this way found a defect the
  lead had missed in most PRs of the run that added this section.
- The orchestrator sends the findings back to the same lead, which keeps its
  context, and the lead writes the `## Review` section when it pushes the fixes.
- Merge only after that follow-up push, and only once `Analyze & test` has
  passed on the PR's current head (see "Child cloud sessions").
- A follow-up push cancels the previous commit's CI run, and `Analyze & test`
  then reports failure for the old commit. Compare a failure event's `head_sha`
  with the PR's current head before acting on it.
- Give every lead the same common brief file plus its own stream brief, each
  naming the files it must not touch. One stream owns `CLAUDE.md` and
  `docs/architecture/`; a fix that needs a sentence there waits for that
  stream's PR merges, then merges main into its branch.

## Child cloud sessions

Work is fanned out to child cloud sessions. Each child owns one feature and
reports to the orchestrator, who merges.

- **Stacked PRs.** Build them with plain merge commits of the lower branch into
  the upper one. Merge bottom-up: after the lower PR merges, retarget the next
  PR's base to main, then merge it. Retargeting does not rerun CI, so check the
  required check on the current head before merging.
- **No rebases, no force-pushes** on a pushed branch.
- **No `git stash`.** Agents sharing one clone share one stash list, so one
  worker's pop can take another's work. Workers use commits or patch files.
- **GitHub goes through the GitHub MCP tools.** Use `gh` only for
  `gh api -X GET search/...`.
- **Review.** CodeRabbit often skips stacked PRs and rate-limits. Then an
  isolated reviewer agent is the review of record.
- **Merging is by hand.** Auto-merge armed through the API often does not fire.
  The orchestrator merges once the required check `Analyze & test` has passed
  on the PR's current head. A superseded commit's cancelled run shows as a
  failure: compare the run's head sha with the PR's head before acting.
- **Release PR.** Each merge regenerates the release-please PR. Do not touch it
  until the rollout is done.

## Afterwards

- Remove the finished agents' worktrees with `git worktree remove` without
  `--force`, so git refuses any worktree that still has uncommitted work.
- Delete their branches: the repo squash-merges, so `git branch -d` calls them
  "not fully merged". Confirm each PR merged (GitHub MCP `pull_request_read`),
  then use `git branch -D`.
- If any PR merged without a review, review the whole range afterwards, for
  example with the `toolkit:deep-review` skill (a user plugin, so it may be
  missing elsewhere) or the `code-review` skill at high effort over
  `git diff <first>^..<last>`.
