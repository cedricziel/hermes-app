---
name: flutter-ci
description: Use when diagnosing failed GitHub Actions checks, Flutter test shards, or CI-only timing failures in hermes-app.
---

# Flutter CI failures

Inspect `gh pr checks <number>` and the latest main CI run separately. A failed
`Analyze & test` aggregate usually reflects an earlier analyze or shard failure;
read that job's logs to find the actual failing test. `gh run view <run> --log-failed`
usually works. If its output is empty, fetch the individual job's logs with the
GitHub connector. Filter for failed test markers and Expected/Actual output;
telemetry tests deliberately print exceptions and are not necessarily failures.

On GitHub Actions `flutter test` uses the `github` reporter, which folds each
failure into a collapsed group and ends with only "N tests passed, 1 failed."
So a failed shard runs a `List failed tests` step (`scripts/summarize_test_failures.py`,
fed by `--file-reporter json:build/test-report.json`) that prints every failing
test with its file and error, adds an annotation per failure and writes them to
the job summary. Read that step first.

`scripts/test-shard.sh <index> 4` reproduces the file partition. CI's split and
a local one match only when run on the same tree, since adding or removing a
test file moves the rest. Shard 0 is the
catalog; the other files are sorted and distributed round-robin. Adding a test
file can move existing tests between shards. Start with the failing file before
running a full shard.

For timeout tests, use the existing `fake_async` dependency and advance the
simulated clock. Keep normal success tests on the production timeout. A global
30 ms timeout on a generated-client/fake-adapter test can fail during its first
response under CI load even though later tests and focused local runs pass.
Verify the deadline has not fired just before it, then advance to the deadline
and assert both the timeout result and subsequent checks. Do not increase the
production timeout or add retries to mask a test-only scheduling assumption.

After a fix, run the affected tests and analysis, push to the existing PR and
check that CI starts for the new commit. Preserve the user's preference about
waiting; describe pending checks as pending, never as green. Keep auto-merge
subject to the required checks.

VM catalog tests do not establish that the catalog compiles for the web. A
native plugin may export a browser stub without its native-only methods (for
example, media_kit's NativePlayer property API). Keep that implementation
behind a conditional import/export with a matching browser stub; a runtime
platform check alone cannot fix missing-method compilation errors. Validate
with `scripts/build-widgetbook.sh` locally or the catalog build in CI.

## Which jobs run

`ci.yml` starts with a `Changes` job. On a pull request it diffs the merge
commit against its base (`HEAD^1`) and outputs `code` (anything besides
`docs/**`, `openspec/**` and `*.md`) and `watch` (anything
under `ios/HermesWatch`, `ios/HermesSurfaceKit` or `ci.yml`). Push to main and
`workflow_dispatch` set both to true. The shards, coverage and all platform
builds need `code`; `Test watch core` needs `watch`. `Analyze & test` expects
`success` from a job that was needed and `skipped` from one that was not, so a
docs-only PR is green with the shards skipped, while a failed or cancelled job
still fails it. A skipped build or test on a PR is therefore normal, not a
missing check. If a test starts reading a file under a docs-only path, remove
that path from the `case` in the `Changes` job.

`Changes` also outputs `builds`, which the five platform builds need besides
`code`. On a pull request it is true when a changed file is under `android/`,
`ios/`, `macos/`, `linux/`, `windows/`, `web/`, `assets/`, `fastlane/`,
or `packages/` (except `packages/hermes_api/lib/`), is any
`pubspec.yaml` or `pubspec.lock`, `.fvmrc`, `scripts/package-linux.sh`,
`design/icon-512.png` (which that script copies) or `ci.yml`. Dart under `lib/`
and `test/`, ARB files, `analysis_options.yaml` and `l10n.yaml` do not trigger
builds. Analyze and the tests cover them, but release-mode problems a Dart-only
change can cause (icon tree shaking on a non-const `IconData`, AOT-only or
conditional-import problems, a platform-only plugin call) are caught on main's
run only, since push to main and `workflow_dispatch` build everything. The
native audio test (`test/voice/native_voice_player_test.dart`, real libmpv)
runs for every full code PR (see "Label gate") in its own job, `Test native audio (Linux)`, which
`Analyze & test` does not wait for. When a build starts to read a
new path (a script it calls, a new asset folder), add it to the `builds` case in
the `Changes` job, or PRs that touch only that path will skip the build.

A pull request from the branch `release-please--branches--main--components--hermes-app`
whose diff is exactly `CHANGELOG.md`, `.release-please-manifest.json` and a
`pubspec.yaml` change of the `version:` line alone (one removed and one added
line) gets `code`, `watch` and `builds` false, like docs-only. Any other file or
pubspec line falls through to the normal classification. The branch name comes
in through `HEAD_REF` (env), never interpolated into the script.

`verify-hermes-api-client.yml`'s job is a required check, so the workflow has no
`paths:` filter (a skipped required workflow stays pending). Its first step
diffs the merge commit like `Changes` does and sets `steps.scope.outputs.run`;
the setup and regeneration steps carry `if:` on it, so the job still reports
success when nothing under `openapi/`, `scripts/`, `packages/hermes_api/`,
`openapitools.json`, `.fvmrc`, `pubspec.yaml`, `pubspec.lock` or the workflow
changed. A non-merge HEAD or an empty diff runs the full check, and so does
push to main.

Every job in `ci.yml`, `widgetbook.yml` and `verify-hermes-api-client.yml` has
`timeout-minutes` at 2x or more of the longest successful run seen (shards 45,
platform builds 25 to 40, Analyze 15); raise it when a job legitimately grows.

Only pull-request runs are cancelled by a newer push (`cancel-in-progress` is
conditional in `ci.yml`, `messenger-plugin.yml`, `real-backend-contract.yml`
and `verify-hermes-api-client.yml`). On main a run in progress finishes and a
queued one is replaced by the newer one, so main's latest finished run is the
one to read. `widgetbook.yml` still cancels on main: a Pages deploy is
superseded by the next one.

The platform builds must not rely on the default `success()`: it is false when
any job upstream was skipped, and `Test watch core` is skipped on most pull
requests. Their `if` therefore names `needs.analyze-and-test.result ==
'success'` under `!cancelled()`. If builds show as skipped on a pull request that
changes code, look there first.

## Label gate: "Tests deferred"

The test shards are about 93% of runner time, so on a pull request they run
only when the PR is ready. `Changes` runs `scripts/ci_gate.py`, which outputs
`full` (a pure function of the event name, the base branch, the PR's current
labels read from the API, and the head branch). A run is FULL when any holds:

- the event is `push`, `workflow_dispatch` or `merge_group`;
- the PR's base is not `main` (a stacked PR);
- the PR has the label `ci:full`;
- the PR's branch is the release-please branch (see below);
- the gate cannot decide (label lookup failed, missing or malformed data):
  fail closed.

Otherwise it is DEFERRED. Always run, full or deferred: `Changes`, `Analyze`
(format, analyze, the script tests including `scripts/test_ci_gate.py`) and
`Analyze & test`. Run only when FULL, and still under their path conditions
(`code`, `watch`, `builds`): the shards, `Coverage`, `Test native audio
(Linux)`, `Test watch core` and the five platform builds. A full Dart-only PR
therefore still skips the builds. `PR policy` is a separate workflow and is not
gated.

**What "Tests deferred" means.** On a deferred run `Analyze & test` fails, as an
`::error::` annotation and in the step summary: "Tests deferred: add the
ci:full label when the PR is ready (fleet rules). Nothing merges until the
tests ran on this head." It fails instead of skipping because a skipped
required check counts as passing. It says the tests did not run on this head.
It says nothing about whether the code is good, so never read it as a test
failure and never as green. Exception: a docs-only PR (including the
release-please PR when it changes only the changelog, the manifest and the
version line) needs no tests, so it passes deferred and needs no label.

**How to add the label.** `gh pr edit <number> --add-label ci:full`, or on the
PR page. Add it when the PR is ready, not before, unless a CI-only failure
needs a full run to debug. The label must exist in the repo: the owner creates
it once (`gh label create ci:full --description "Run the full CI test suite"`);
until then the first session to label a PR creates it, since adding a label
through the API creates it when missing. Do not use "Re-run jobs" to get a full
run after labelling: the label event starts a new run by itself, and the gate
reads the current labels either way.

| Event | Labels after it | Run | `Analyze & test` |
| --- | --- | --- | --- |
| opened / reopened / synchronize | none of ours | deferred | fails (tests deferred) |
| opened / reopened / synchronize | `ci:full` | full | tests' result |
| labeled `ci:full` | `ci:full` | full, cancels a run in progress | tests' result |
| unlabeled `ci:full` | none of ours | deferred, cancels a run in progress | fails (tests deferred) |
| labeled or unlabeled, other label, `ci:full` absent | none of ours | deferred | fails (tests deferred) |
| labeled or unlabeled, other label, `ci:full` present | `ci:full` | full, queued behind a run in progress | tests' result |
| base not `main` | any | full | tests' result |
| release-please branch | any | full; docs-like runs nothing heavy | tests' result, or pass when docs-only |
| push to main, `workflow_dispatch`, `merge_group` | n/a | full | tests' result |
| gate error | n/a | full | tests' result |

Docs-only PRs pass in every row, because `code` is false and the shards are
skipped as they were before the gate.

**Why the label events behave this way.** GitHub reads the latest check run
named `Analyze & test` on the head, so a newer deferred run that fails turns an
armed PR red even if an earlier full run on the same head was green: removing
`ci:full` is enough, and no one has to push. Adding `ci:full` to a head that
had a deferred run starts a full run on that head whose aggregate replaces the
failed one. The workflow is triggered by every label event, so an unrelated
label could otherwise cancel a full run: only `ci:full` events cancel a run in
progress. Any other label event queues behind it (a queued run is replaced by a
newer one), recomputes the same decision from the label set, and so gives the
same result. The cost is one repeated full run per unrelated label added to a
PR that has `ci:full` and has finished or is running; the workflow cannot
filter by label name, and a skipped aggregate would count as passing. Labels
other than `ci:full` that a bot adds belong on the PR before `ci:full` is
added, so the labelling does not repeat a full run.

**Release and bot PRs.** The release-please PR runs FULL by itself, without the
label, when its diff is more than the changelog, the manifest and the version
line (the fleet rules arm it only after its builds are green). When it is
docs-like it passes without a label. Dependabot and other bots are treated like
any PR: deferred until someone adds `ci:full`.

**Costs.** A PR needs one label action before it can merge. A deferred head has
a red required check. Reading the label through the API needs
`pull-requests: read` on `Changes`; a failed lookup runs everything. `merge_group`
is classified as full but `ci.yml` does not trigger on it today.
