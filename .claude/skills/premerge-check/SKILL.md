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

`--others` lists the other PRs that are armed or about to be. Add
`PREMERGE_LIST_OPEN=1` to have `gh` find the armed ones (optional; the default
uses git only, so it works in cloud sessions where `gh` is search-only).

What it does, in order:

1. Fetches `origin/<base>` and `refs/pull/N/head` for each PR into
   `refs/premerge/<pid>/...` (deleted on exit) and prints the base and head SHAs.
2. Prints the Dart library directories (parents of changed `lib/` and `test/`
   `.dart` files, diffed against the merge-base) that the PR shares with each
   `--others` PR: `overlap with #N: lib/src/theme/ (2 files here, 1 there)`,
   plus a `WARNING`. Overlap alone does not fail the run.
3. Merges the PR head into origin/<base> with `--no-ff` in a throwaway worktree
   under `mktemp -d`, outside the repo. Your tree, index, branch and stash are
   never touched, and nothing is pushed.
4. Runs `flutter pub get`, `flutter analyze --no-pub`,
   `flutter test --no-pub test/architecture` there, timing each step.

The worktree, temp dir and refs are removed on every exit, including failure,
INT and TERM. `--keep` leaves the worktree and prints how to remove it.
A full run takes about two minutes.

## Exit codes and what to do

| Code | Meaning                                                | Next step                                                                  |
| ---- | ------------------------------------------------------ | -------------------------------------------------------------------------- |
| 0    | Merged tree analyzes and passes the architecture tests | Arm now. Rerun if main moves before the merge.                             |
| 1    | Usage error, unknown PR number, fetch failure          | Fix the arguments or the remote.                                           |
| 2    | Merge conflict (files listed)                          | Merge origin/main into the PR branch, resolve, push, rerun.                |
| 3    | `pub get` or analyze failed (errors printed)           | Merge origin/main into the PR branch, fix what analyze names, push, rerun. |
| 4    | Architecture tests failed                              | Same: merge origin/main, fix the named rule, push, rerun.                  |

Arm only on exit 0. On an overlap `WARNING`, arm one of the overlapping PRs,
wait for it to merge, then rerun the check for the other.

## Tests

`scripts/test_premerge_check.py` builds real throwaway git repos (a bare origin
with `refs/pull/N/head`, a caller clone) and a stub `flutter` on PATH. Set
`PREMERGE_SCRIPT=<path>` to run the suite against a modified copy of the script;
that is how the mutation proof (no trap, run in the caller's tree, ignore
analyze's exit code) is done. Keep the script bash 3.2 compatible (macOS): no
associative arrays, `mapfile` or `${var,,}`.
