---
name: premerge-check
description: Use before arming auto-merge on a hermes-app PR, before merging one by hand, or when two PRs that were each green may break main together (duplicate declaration, conflicting edits in one library directory). Runs scripts/premerge_check.sh, a trial merge of the PR into the current origin/main with analyze and the architecture tests.
---

# Pre-merge trial check

Each PR is tested against the main it branched from or last merged. Two PRs
merged minutes apart can each be green and still break main together: #1123 and
#1186 both declared `AppIcons.wifiOff`. Until a merge queue exists, every arm or
hand merge first runs this check against the main that exists right now.

```bash
scripts/premerge_check.sh <pr> [--others <n> <n> ...] [--base main] [--keep]
```

`--others` lists the other PRs that are armed or about to be. The default uses
git only, so it works in cloud sessions where `gh` is search-only.
`PREMERGE_LIST_OPEN=1` makes the script ask `gh` for the open PRs with
auto-merge armed; that is a GraphQL call, which cloud sessions cannot make, so
pass `--others` there.

What it does, in order:

1. Fetches `origin/<base>` and `refs/pull/N/head` for each PR into
   `refs/premerge/<pid>/...` (deleted on exit) and prints the base and head
   SHAs. It leaves your `refs/remotes/origin/*` and `FETCH_HEAD` alone, and
   drops any inherited `GIT_DIR`, `GIT_INDEX_FILE` and similar variables. It
   exits 1 if the PR head is already contained in the base.
2. Prints the Dart library directories (parents of changed `lib/` and `test/`
   `.dart` files, diffed against the explicit merge-base, renames counting both
   sides) that the PR shares with each `--others` PR:
   `overlap with #N: lib/src/theme/ (2 files here, 1 there)`, plus a `WARNING`.
   Without a merge base (shallow clone) it prints
   `overlap UNKNOWN for #N (...)` and a `WARNING`, never the all-clear. Overlap
   alone does not fail the run.
3. Merges the PR head into origin/<base> with `--no-ff` in a throwaway worktree
   under `mktemp -d`, outside the repo, with hooks, rerere and signing off.
   Your tree, index, branch, stash and other worktrees are never touched, and
   nothing is pushed.
4. Runs `flutter pub get`, `flutter analyze --no-pub`,
   `flutter test --no-pub test/architecture` there, timing each step.

The worktree, temp dir and refs are removed on every exit, including failure,
INT, TERM and HUP. `--keep` leaves the worktree and prints how to remove it.
A SIGKILL cannot be trapped: it leaves `refs/premerge/<pid>`, a `premerge.*`
temp dir and its worktree behind, and the next run sweeps those whose pid is
dead. A full run takes about two minutes.

## Exit codes and what to do

| Code | Meaning                                                       | Next step                                                                                                                                 |
| ---- | ------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| 0    | Merged tree analyzes and passes the architecture tests        | Arm at exactly the printed head SHA (below). Rerun after any push.                                                                        |
| 1    | Usage error, unknown PR number, fetch failure, already merged | Fix the arguments or the remote; check the PR is open.                                                                                    |
| 2    | Merge conflict (files listed)                                 | Merge origin/main into the PR branch, resolve, push, rerun.                                                                               |
| 3    | `pub get` or analyze failed (issues printed)                  | Rerun with `--keep`, run `flutter analyze` in the trial merge, fix the PR, or merge origin/main in if the clash comes from main.          |
| 4    | Architecture tests failed                                     | Rerun with `--keep`, run `flutter test test/architecture` in the trial merge, fix the PR, or merge origin/main in if the clash is main's. |

## Arming: tie it to the head

A pass is about one PR head and one main. On exit 0 the script prints the exact
head SHA: arm with a head-SHA match (`gh pr merge --auto --match-head-commit
<sha>` locally, or the auto-merge route with that sha), so a later push to the
PR cannot ride on this result. Rerun after ANY push to the PR or to main. On an
overlap `WARNING`, arm one of the overlapping PRs, wait for it to merge, then
rerun the check for the other.

The incident-catching path (exit 3 on a merged tree that does not compile) is
covered by the stub test only (`test_analyze_failure_exits_3`). Main had been
fixed before the first real run, so no real run has shown it.

## Tests

`scripts/test_premerge_check.py` builds real throwaway git repos (a bare origin
with `refs/pull/N/head`, a caller clone) and a stub `flutter` on PATH. Set
`PREMERGE_SCRIPT=<path>` to run the suite against a modified copy of the script;
that is how the mutation proof is done (remove a guard, see the tests fail).
Keep the script bash 3.2 compatible (macOS): no associative arrays, `mapfile`
or `${var,,}`.
