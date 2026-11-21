---
name: premerge-check
description: Use before arming auto-merge on a hermes-app PR, before merging one by hand, or when two PRs that were each green may break main together (duplicate declaration, conflicting edits in one library directory, a PR changing a screen whose workflow test another PR rewrote). Runs scripts/premerge_check.sh, a trial merge of the PR (and any stacked PRs) into the current origin/main with analyze, the architecture tests and the affected tests.
---

# Pre-merge trial check

Each PR is tested against the main it branched from or last merged. Two PRs
merged minutes apart can each be green and still break main together: #1123 and
#1186 both declared `AppIcons.wifiOff`. Another pair: #1196 rewrote
`test/workflows/kanban_extras_workflow_test.dart` and #1213 changed
`lib/src/kanban/kanban_screen.dart`; #1213's check ran on a base that already
had #1196 but only analyzed, so main failed in that workflow test. That is why
the check also runs the tests that touch what changed. Until a merge queue
exists, every arm or hand merge first runs this check against the main that
exists right now.

```bash
scripts/premerge_check.sh <pr> [--stack <n> <n> ...] [--others <n> <n> ...] [--base main] [--keep]
```

`--others` lists the other PRs that are armed or about to be (overlap report
only). `--stack` lists PRs that will merge before this one: their heads are
trial-merged onto main first, in the given order, then this PR, and the affected
tests cover all of their changes. A conflict while stacking exits 2 and names
the PR (`CONFLICT: stacked #N ...`). The default uses
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
5. Selects and runs the affected tests (below), with `python3`. The selection
   script (`scripts/premerge_affected_tests.py`) is the one beside the script
   you run, not the PR's copy. Run `scripts/premerge_check.sh` from a checkout
   of origin/main, not from the PR branch: that is what keeps both scripts out
   of the PR's control.

### Affected tests

The deduplicated union, in this priority order, of:

- (a) test files (`test/**/*_test.dart`) changed by the PR, merge base to head;
- (b) test files changed on main since the merge base;
- (c1) test files that import (directly) any `lib/` file the PR changes, or any
  changed test helper (a non-`_test.dart` Dart file under `test/`, such as
  `test/support/`); with an ARB or `l10n.yaml` change, also every test under
  `test/l10n*`;
  (c1) is never capped, so a change to a widely imported helper or lib file
  selects hundreds of files (`test/support/fake_hermes_server.dart` alone has
  about 386 importers). At about 3 s per file that exceeds the default budget
  and the run exits 6; raise `PREMERGE_TEST_BUDGET` for such a PR.
- (c2) for each `lib/src/<dir>/` the PR touches, every test file that imports
  any file under it, or imports a test helper that does (one level); an ARB or
  `l10n.yaml` change adds `lib/l10n/` as such a directory (importers of the
  localizations entry; it can be broad, so it is cut by the cap, and the
  `test/l10n*` tests in (c1) always run).

With `--stack`, each stacked PR contributes to all four (its own merge base).
Imports match as `package:<pubspec name>/...` and as relative imports. One level
of re-export is followed: a lib file that `export`s a changed file counts as
changed for (c1), for lib files and test helpers alike. A change to a `part`
file counts as a change to its library. Deleted test files are never run;
renames count both sides (`--no-renames`); file names travel NUL-safely. Test
files live at any depth (`test/**/*_test.dart`), so selection is by import,
never by directory name.

It does NOT follow: imports beyond one level (a test reaching a changed `lib/`
file through a test helper in (c1), a helper that imports another helper that
imports a touched directory, a re-export of a re-export), conditional imports
(only the first URI counts), tests that reach code only through `widgetbook/` or
generated code (an ARB change selects by the generated entry's path, not by which
strings a test reads), and changes outside `lib/`, `test/` and `l10n.yaml`
(`packages/`, `ios/`, assets). A green run is not a
full test run; CI's shards remain the full check.

Environment (positive integers; a bad value exits 1):

| Variable                     | Default | Meaning                                                         |
| ---------------------------- | ------- | --------------------------------------------------------------- |
| `PREMERGE_TEST_BUDGET`       | 600     | Seconds for the whole affected-test run; the process tree is killed at expiry |
| `PREMERGE_TEST_CAP`          | 150     | Files; (a), (b), (c1) are kept whole, (c2) is dropped beyond it |
| `PREMERGE_TEST_CONCURRENCY`  | 4       | `flutter test --concurrency`                                    |
| `PREMERGE_TEST_BATCH`        | 20      | Files per `flutter test` call (the budget is checked per batch) |

Over the cap it prints `affected tests: CAPPED` and names the `lib/src/<dir>/`
or `lib/l10n/` directories whose (c2) tests were skipped. The PASS line says
`affected tests: N files run` (N may be 0; nothing is run then) and `CAPPED` when
it applies. A budget cut prints `affected tests CUT SHORT after N/M files
(budget X s); not a pass` and lists the files not run: exit 6, never 0. A
failure in a batch that ran before the cut exits 5, not 6, and the cut notice is
printed too.

The worktree, temp dir and refs are removed on every exit, including failure,
INT, TERM and HUP. `--keep` leaves the worktree and prints how to remove it.
A SIGKILL cannot be trapped: it leaves `refs/premerge/<host>.<ns>.<pid>/...`, a
temp dir and its worktree behind, and the next run sweeps those whose pid is
dead (ps and `kill -0` both fail; another user's live run counts as alive). The
ref name carries the host and the pid-namespace id, so a run of another host or
container is not swept; refs of the older `refs/premerge/<pid>` form are never
swept. It only touches directories directly under `$TMPDIR` (or `/tmp`) named
`premerge.XXXXXX` that hold the script's own marker file `pid`: `premerge_check
<pid> <host> <pid-namespace> <git-common-dir>`, matching this host, repo and pid
namespace (`readlink /proc/self/ns/pid`; `-` where there is no `/proc`, which
matches any). A run from another pid namespace, such as another container
sharing the temp dir, counts as alive. An old 4-field marker (no namespace) is
swept when host and repo match and its pid is dead. A `premerge.*` folder
anywhere else, or without the marker, is never removed. A `TMPDIR` inside the repo is
replaced by `/tmp`. A full run takes about two minutes.

## Exit codes and what to do

| Code | Meaning                                                       | Next step                                                                                                                                 |
| ---- | ------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| 0    | Merged tree analyzes and passes the architecture and affected tests | Arm at exactly the printed head SHA, while main is still the printed base (below). Rerun after any push.                           |
| 1    | Usage error, bad `PREMERGE_TEST_*` value, unknown PR number, fetch failure, already merged, affected tests could not be selected | Fix the arguments or the remote; check the PR is open.                                                                                    |
| 2    | Merge conflict (files listed; names the stacked PR that conflicted) | Merge origin/main into the PR branch, resolve, push, rerun.                                                                         |
| 3    | `pub get` or analyze failed (issues printed)                  | Rerun with `--keep`, run `flutter analyze` in the trial merge, fix the PR, or merge origin/main in if the clash comes from main.          |
| 4    | Architecture tests failed                                     | Rerun with `--keep`, run `flutter test test/architecture` in the trial merge, fix the PR, or merge origin/main in if the clash is main's. |
| 5    | Affected tests failed (files named)                           | Rerun with `--keep`, run `flutter test <file>` in the trial merge, fix the PR, or merge origin/main in if the clash is main's.            |
| 6    | Affected tests cut short by the budget (files not run listed) | Not a pass. Rerun with a larger `PREMERGE_TEST_BUDGET`, or run the listed files, then rerun the check.                                    |

## Arming: tie it to the head and the base

A pass is about one PR head and one main. On exit 0 the script prints the head
SHA and the base (main) SHA it was checked against, and the rule: merge or arm
only while `origin/main` still equals that base SHA; rerun otherwise. It also
prints the exact head SHA: arm with a head-SHA match (`gh pr merge --auto --squash
--match-head-commit <sha>` locally, or the auto-merge route with that sha), so a later push to the
PR cannot ride on this result. Rerun after ANY push to the PR or to main. On an
overlap `WARNING`, arm one of the overlapping PRs, wait for it to merge, then
rerun the check for the other.

The incident-catching path (exit 3 on a merged tree that does not compile) is
covered by the stub test only (`test_analyze_failure_exits_3`). Main had been
fixed before the first real run, so no real run has shown it.

## Tests

`scripts/test_premerge_check.py` builds real throwaway git repos (a bare origin
with `refs/pull/N/head`, a caller clone) and a stub `flutter` on PATH that also
records, NUL-separated, every test file it was asked to run, so the selection is
asserted exactly. Set `PREMERGE_SCRIPT=<path>` to run the suite against a
modified copy of the script; that is how the mutation proof is done (remove a
guard, see the tests fail). Copy `premerge_affected_tests.py` next to the copy
(the script looks for it beside itself); mutate either file.
Keep the script bash 3.2 compatible (macOS): no associative arrays, `mapfile`
or `${var,,}`.
