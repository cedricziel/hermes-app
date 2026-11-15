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
- Review recorded: run the isolated-reviewer on the current head and paste its block into `## Review`, verbatim (never write or edit it). The block is one plain pair of lines outside code fences, `Reviewer: <name> Head: <full sha> Verdict: clean` then `Range: <base sha>..<head sha>` (the base an ancestor of the head, the range ending at Head); Head and Verdict are read from the first line only. Any push makes it stale, so paste the new block after the last push. The check reads git as well as the body (it fetches the head's commit objects, never its files): a merge head is accepted only when it is the clean automatic merge of the base branch into a first parent that is itself accepted (`git merge-tree` reproduces its tree exactly), or when the body has a `Merge-review: <files>` line followed by the reviewer's own `Reviewer:` and `Range:` lines for that merge (its first parent must be accepted too, and the files must include every file that differs from the automatic merge). The body may hold several plain blocks, one per reviewed head: list the reviewed pre-merge head as well as later ones. So merging main needs no new review if the merge is clean and carries no edit; resolving a conflict or adding a change in the merge commit does. The failure names the commit and the files that differ, and prints the block to paste. Octopus merges, a second parent that is not on the base branch and more than 20 chained merges fail with their own messages. While `ACCEPT_LEGACY_REVIEW_BLOCK` in `scripts/pr_policy.py` is True, a one-line block without Range is accepted for a non-merge head, and for a merge head that passes the tree test (the first parent is then not checked: a known, temporary gap). It is set to False when the fleet rules require Range. The job's token is `contents: read` only.
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
