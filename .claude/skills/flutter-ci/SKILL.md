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

`scripts/test-shard.sh <index> 4` reproduces the file partition
(`TEST_SHARD_LIST=1` prints the files without running them). Files are assigned
by duration: `tool/shard_weights.dart` sorts them by the seconds in
`test/shard_weights.json` (longest first, ties by path) and gives each to the
lightest shard. A file missing from the weights counts as the median, so a new
test file needs no edit, but it can move others between shards. The Widgetbook
catalog is pinned to shard 0 and runs alone first (it runs out of memory beside
others); shard 0's other files run in a second `flutter test`, which writes
`build/test-report-extra.json` and whose coverage is appended to
`coverage/lcov.info`. Start with the failing file before running a full shard.

To refresh the weights when shards drift apart: download the `test-report-<shard>`
artifacts of a recent main run, then
`dart tool/shard_weights.dart update <reports...>` and commit
`test/shard_weights.json`.
Weights are per-file wall seconds, and a shard's files overlap about 1.6x, so a
shard's Test step is about 0.62 x its weight sum. The catalog runs alone, so its
weight is its wall time divided by that scale (400 s / 0.62 = 645). `update`
derives the scale as the wall of the non-catalog invocations (first to last
report event) over their summed weights, and the catalog weight from its own
report the same way; give it the catalog report too.

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
runs for every code PR in its own job, `Test native audio (Linux)`, which
`Analyze & test` does not wait for. When a build starts to read a
new path (a script it calls, a new asset folder), add it to the `builds` case in
the `Changes` job, or PRs that touch only that path will skip the build.

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
- Review recorded: run the isolated-reviewer on the current head and paste its block into `## Review`. It needs exactly one line outside code fences, `Reviewer: <name> Head: <full sha> Verdict: clean`; Head and Verdict are read from that line only. Any push makes it stale, so paste the new block after the last push.
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
