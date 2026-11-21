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
waiting; describe pending checks as pending, never as green. The orchestrator
arms auto-merge once the PR is READY, and GitHub merges when the required
checks are green on the head (`fleet-rules`). Never push to a PR with
auto-merge armed.

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

`Analyze & test` runs before the builds and cannot wait for them, so the `Builds`
job (`needs` all five, `if: always()`) aggregates them. It fails when `Analyze &
test` did not succeed. Only an explicit `false` in `code` or `builds` from
`Changes` makes it expect every build `skipped`; any other value, empty
included, expects `success` from every build, so it fails closed. A
failed, cancelled or unexpectedly skipped build fails it, and the log names the
job and what was expected. `Test native audio (Linux)` is left out on purpose
(advisory). `Builds` is a required check only once the owner adds it to the
ruleset; until then a red `Builds` does not block a merge, so read it before
merging a PR that touches native code or `pubspec.yaml`.

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
- the PR's branch is the release-please branch and its head repository is this
  one (a fork using the name gets no shortcut; unknown repositories fail
  closed);
- the gate cannot decide: the label lookup failed, data is missing or
  malformed, or the head branch of a PR to `main` without the label is unknown.
  This fails closed, so such a PR runs FULL even without `ci:full`.

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
failure and never as green. Exception: a docs-only PR (only `docs/`, `openspec/`
and Markdown changed) needs no tests, so it passes deferred and needs no label.
`Builds` fails the same way on a deferred run that wants builds (a pull request
that needs none, such as a Dart-only one, fails on `Analyze & test` already).

**How to add the label.** `gh pr edit <number> --add-label ci:full`, or on the
PR page. Add it when the PR is ready, not before, unless a CI-only failure
needs a full run to debug. The label must exist in the repo: the owner creates
it once (`gh label create ci:full --description "Run the full CI test suite"`);
until then the first session to label a PR creates it, since adding a label
through the API creates it when missing. Do not use "Re-run jobs" to get a full
run after labelling: the label event starts a new run by itself. "Re-run all
jobs" re-reads the labels in `Changes`; "Re-run failed jobs" keeps the
successful `Changes` job's old `full` output, so `Analyze & test` reads the
current labels again itself (a failed lookup there counts as full, so a full
run that passed is not turned red by a flaky API call).

| Event | Labels after it | Run | `Analyze & test` |
| --- | --- | --- | --- |
| opened / reopened / synchronize | none of ours | deferred | fails (tests deferred) |
| opened / reopened / synchronize | `ci:full` | full | tests' result |
| labeled `ci:full` | `ci:full` | full, cancels a run in progress | tests' result |
| unlabeled `ci:full` | none of ours | deferred, cancels a run in progress | fails (tests deferred) |
| labeled or unlabeled, other label, `ci:full` absent | none of ours | deferred | fails (tests deferred) |
| labeled or unlabeled, other label, `ci:full` present | `ci:full` | full, queued behind a run in progress | tests' result |
| base not `main` | any | full | tests' result |
| release-please branch | any | full | tests' result |
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
same result. A re-run (run attempt above 1) never cancels a run in progress
either: the group is per pull request, so re-running a run on a replaced head
must not cancel the current head's run (a queued run is still replaced by a
newer queued one). After `ci:full` is removed there is a short window: until the
new run's `Analyze & test` appears (after Analyze finishes), the previous green
check is still the latest, so the PR stays mergeable. The tests did run on that
head. The cost is one repeated full run per unrelated label added to a
PR that has `ci:full` and has finished or is running; the workflow cannot
filter by label name, and a skipped aggregate would count as passing. Labels
other than `ci:full` that a bot adds belong on the PR before `ci:full` is
added, so the labelling does not repeat a full run.

**Release and bot PRs.** The release-please PR is classified like any pull
request (there is no docs-only special case: its `CHANGELOG.md` is Markdown,
but the `pubspec.yaml` and manifest changes make it a code PR) and runs FULL by
itself, without the label, because the gate recognises its branch name; the
fleet rules arm it only after its builds are green. Dependabot and other bots are treated like
any PR: deferred until someone adds `ci:full`.

**Costs.** A PR needs one label action before it can merge. A deferred head has
a red required check. Reading the label through the API needs
`pull-requests: read` on `Changes` and `Analyze & test`; a failed lookup runs
everything, and a failed gate step in `Changes` falls back to full. Push and
dispatch never depend on that step. `merge_group`
is classified as full but `ci.yml` does not trigger on it today.

**A cancelled `Analyze & test` on an old head.** When a newer push replaces a
run, the cancelled run still reaches `Analyze & test` (its `if:` is `always()`)
and used to post a red check on the old head. Its first step now compares the
run's head with the pull request's current head (`GET /pulls/{n}`). If the head
moved on and the pull request is open, the run cancels itself
(`POST /actions/runs/{id}/cancel`), waits about 60 seconds and fails if it is
still running; it never passes after deciding "superseded", and no later step
runs. So a cancelled aggregate on a superseded head is not a failure: look at
the current head instead. A red or cancelled aggregate on the CURRENT head is
real and stays red (a manual cancel, a timeout, a closed or merged pull
request and a failed lookup all fall through to the normal checks; a refused
cancel goes straight to `exit 1` and stays red). Push and dispatch runs skip
the step. The jobs `Analyze & test` and `Builds`
need `actions: write` for the cancel, on top of `contents: read` and
`pull-requests: read`: a permission increase, scoped to those two jobs. The
step has its own `timeout-minutes`, like every job.

**Aggregate tests.** `scripts/test_ci_aggregates.py` (PyYAML is installed in
the `Test scripts` step; a missing module fails the test) runs the real `run:`
scripts of `Analyze & test` in the default shell of a step without `shell:`
(`bash -e {0}`, no pipefail; a script that needs it sets it), with the step
conditions modelled
too: a step's `if:` with the implicit `success()`, later steps skipped after a
failure unless `always()` or `failure()`, `continue-on-error`, and the job
failing only when a step failed without it. It does so for every outcome of the
job's needs (success, failure, cancelled, skipped, empty), so the aggregate can
be the only required test context. It also evaluates each job's `if:` over
every combination of the Changes outputs (a small evaluator that fails on any
syntax it does not know), runs the real aggregate with the resulting results,
and asserts that a pass never hides a skip the outputs did not allow. Changes'
`full` output expression is evaluated over event and gate output as well. The
aggregate rejects a `code` or `watch` output that is not exactly `true` or
`false`, so an empty output never reads as "not needed". Its `if:` must stay
`always()`: a job skipped by its `if:` reports success to required checks, and
for the same reason no step of an aggregate job may carry an `if:` (an
allowlist in the test, empty today). A process substitution (`<(...)`,
`>(...)`) in a workflow `run:` script fails the test unless the command ends in
a trailing shell comment `# process-substitution-ok: <reason>` outside quotes,
because `pipefail` does not see a failure inside it. The scanner skips heredoc
bodies, reads `$'...'` as quoted text, ends a comment inside `$(...)` at its
line, and fails closed on a script that ends inside a quote, a substitution or
a heredoc.
`scripts/*.sh` is out of scope. One known case: `scripts/test-shard.sh` reads
its file list via `< <(find ...)`, so a failing `find` gives a smaller shard
instead of an error (an empty list still exits 1). The scripts run in the
default shell of a step without `shell:` (`bash -e {0}`, no pipefail), and no
aggregate step may set `shell:` or `working-directory:` nor the workflow `defaults.run`.
`Builds` gets the same matrix and the same simulation, and the same
self-cancel first step (with `actions: write`).

## PR policy and Review recorded

`pr-policy.yml` runs `scripts/pr_policy.py` (`policy` and `review`) on every
pull request. It triggers on `pull_request_target` and checks out the default
branch only, so the gate is main's copy and a PR cannot edit its own checks (a
PR that changes the workflow or the script is checked by main's version; the
first live run of a change is the next PR after it merges). The script reads
the event JSON and the changed files from the REST API and never touches the
PR's code. Editing the PR body reruns it; a manual "Re-run jobs" reuses the old
payload, so edit the body to re-check. Each failure names its fix:

- Title: Conventional Commit, type from `release-please-config.json`.
- Body sections: copy `.github/pull_request_template.md`; an HTML comment is not content, write "Nothing" where that is the answer.
- `fix:` PRs: answer `What would have caught this earlier?` in `## Proof`, outside any comment.
- Model names: drop them from title and body. Only `Co-Authored-By:` and `Claude-Session:` lines, the Claude Code footer and the session URL are skipped.
- `pubspec.yaml` version: revert; release-please bumps it.
- `docs/roadmap.md`: revert it and send the orchestrator the row. The check is by branch prefix (`claude/quirky-einstein-`), so it is loud, not tight.
- "looks corrupted by a Markdown formatter": the hook turned `x86_64` into `x86*64` or unbalanced a backtick in CLAUDE.md or the roadmap. Restore the line from main and re-apply only your change, with a script instead of Edit/Write.
- Review recorded: run the isolated-reviewer on the current head and paste its block into `## Review`. It needs exactly one line outside code fences, `Reviewer: <name> Head: <full sha> Verdict: clean`; Head and Verdict are read from that line only. Any push makes it stale, so paste the new block after the last push. A block pasted with leading indentation is not recognised: paste it flush left.
- "The PR head moved (<old> → <new>)": a push landed while the job ran, or the API lagged. The run on the newer head decides; re-run the job if that run is missing.
- Known gap: model names inside inline code or fenced code are not checked.
- TODO, TBD, n/a, `-` and `...` count as empty; "Nothing" is a valid answer for `## Not verified on a device`.

Automation PRs from the same repository skip the title, body and review
rules: the exact branches `chore/update-flutter`,
`chore/update-hermes-contracts`, `chore/readme-screenshots-<run id>` and
`release-please--branches--main--components--hermes-app`, and `dependabot/*`
only with the author `dependabot[bot]`. A fork is never exempt.
update-claude-plugins is not listed because its branch name lives in an
external action; add it once a PR from it shows the name.
