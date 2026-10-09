---
name: parallel-ui-rollout
description: Use when one change (a restyle, a shared widget migration, a design port) is split across several agents working on hermes-app in parallel, each opening its own PR — planning the waves, writing the agent brief, and getting every PR merged without breaking main.
---

# Rolling out a UI change with parallel agents

Learned from the clean settings restyle (#511–#542): about 30 PRs from a dozen
agents in two days. These are the rules that would have saved the rework.

## Before launching

- **Shared pieces first, alone.** Build the shared widgets (or their React
  copies in `design/web`) in one PR, merge it, and only then launch the screen
  agents with that PR's API notes. Parallel agents that each invent a group row
  produce five versions.
- **One owner per shared file.** Name, in each brief, which agent may change
  which shared file (`lib/src/widgets/*`, `widgetbook/frame.dart`,
  `design/web/src/index.ts`, `.design-sync/config.json`). Everyone else only
  adds to it after that owner's PR merges, or reports what they need. Twice,
  two PRs that each passed CI broke main together (#523): two agents made the
  same helper public, and a shared-widget fix changed what another screen's
  test found.
- **Write the design down as files.** Agents can't open Claude Design or the
  conversation. Put the spec, the brief and the shared API notes in files
  under the scratchpad and point every agent at them.
- **Say what "visual only" means.** Restyle agents changed tap targets (a
  switch row that no longer flips on a row tap), flows (a picker sheet became
  an Add button) and added buttons (Done). Either forbid behaviour changes
  outright or require them to be listed under a "Behaviour changes" heading in
  the PR body.
- **Size the waves to the machine.** About four agents at once, more only as
  earlier ones finish. Check `df -h /` before each wave; seven agents at once
  drove the load average to ~200 and the disk to under 500 MB.

## Every PR

- Screenshots: agents can't reliably upload. They write combined PNGs and a
  `READY` file (`<file> | <caption>` per line) to a shared folder; the
  orchestrator uploads them (see the PR screenshot memory note for the Chrome
  steps and GitHub's upload rate limit).
- Review before merge: CodeRabbit when it reviews; when it is rate-limited or
  capped, an isolated reviewer agent with fresh context reviews `gh pr diff`
  before auto-merge is armed. Never merge unreviewed.
- Agents rebase on `origin/main` right before pushing, and again after any
  merge that touched a shared file they use.

## While they run

- Keep watching every PR after its agent hands back: the harness can end an
  agent while CI is still running, and a later merge can turn its PR into a
  conflict nobody sees. A watcher that polls `gh pr list` and the screenshot
  folder, and remembers what it already reported, keeps the noise down.
- Check main's CI after each merge, not only the PR's.
- After a Flutter UI change, the React copies in `design/web` are stale until
  someone ports them (see `.design-sync/NOTES.md`). Plan the port as part of
  the rollout, not as an afterthought.

## Afterwards

- Remove the finished agents' worktrees with `git worktree remove` (no
  `--force`: it refuses a worktree with uncommitted work), then their branches.
- If any PR merged without a review, run a deep review over the whole range.
