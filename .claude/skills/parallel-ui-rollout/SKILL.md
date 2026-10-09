---
name: parallel-ui-rollout
description: Use when one hermes-app change (a restyle, a shared widget migration, a design port) is being split, or should be split, across several agents that each open their own PR — planning the waves, writing the agent brief, and getting every PR merged without breaking main. The merge and review rules also apply to any other multi-agent fan-out.
---

# Rolling out a UI change with parallel agents

Learned from the clean settings restyle and its design port: about two dozen
PRs in #511–#542, over one night. These are the rules that would have saved
the rework.

## Before launching

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
  Design or the orchestrator's conversation. Put the spec, the brief and the
  shared API notes in the orchestrator's scratchpad and pass their absolute
  paths in every brief (worktree-isolated agents can read them; they can't
  write outside their worktree with compound shell commands).
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
  run git as plain single commands.

## Every PR

- **Screenshots.** Agents write combined before/after PNGs plus a `READY` file
  (`<file name> | <caption>` per line, file names relative to that folder) to
  `<orchestrator scratchpad>/shots/<PR number>/`. The orchestrator uploads them
  through Chrome: attach the files to the PR's new-comment box, read the
  `user-attachments` URLs out of the textarea, clear it with
  `textarea.select(); document.execCommand('delete')` (setting `.value`
  desyncs GitHub's editor), and put the images in the PR body with
  `gh pr edit --body-file`. GitHub returns 429 silently after roughly 60–90
  uploads an hour; upload in batches of up to about eight per call.
- **The PR body is shared.** The agent, the orchestrator's screenshots and the
  reviewer each own a section. Whoever edits it reads the current body, changes
  only their own section and writes it back; an agent that regenerates the
  whole body from its own notes deletes the screenshots. Keep the uploaded URLs
  in the shots folder so a wiped section can be restored.
- **Review before merge.** CodeRabbit when it reviews. When it is rate-limited
  or capped, an isolated reviewer agent with fresh context reviews
  `gh pr diff <n>` for correctness, accessibility and unintended behaviour or
  API changes; fix what it confirms, then arm `gh pr merge --auto --squash`.
  Never merge unreviewed.
- **Rebase right before pushing**, and again after any merge that touched a
  shared file the branch uses; push the rewritten branch with
  `--force-with-lease`.

## While they run

- Keep watching every PR after its agent hands back: the harness can end an
  agent while CI is still running, and a later merge can turn its PR into a
  conflict nobody sees. A watcher that polls `gh pr list` and the screenshot
  folder, and remembers what it already reported, keeps the noise down.
- Check main's CI after each merge, not only the PR's.
- Visual Flutter changes leave the React copies in `design/web` stale (see
  `.design-sync/NOTES.md`). Find the PRs that need a port with
  `gh pr list --state merged --search '"needs a design port" in:body'` and plan
  the port as part of the rollout.

## Afterwards

- Remove the finished agents' worktrees with `git worktree remove` without
  `--force`, so git refuses any worktree that still has uncommitted work.
- Delete their branches: the repo squash-merges, so `git branch -d` calls them
  "not fully merged". Confirm each PR merged (`gh pr view <n> --json state`),
  then use `git branch -D`.
- If any PR merged without a review, review the whole range afterwards, for
  example with the `toolkit:deep-review` skill (a user plugin, so it may be
  missing elsewhere) or the `code-review` skill at high effort over
  `git diff <first>^..<last>`.
