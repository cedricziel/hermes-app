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

`scripts/test-shard.sh <index> 4` reproduces the file partition. Shard 0 is the
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

Only pull-request runs are cancelled by a newer push (`cancel-in-progress` is
conditional in `ci.yml`, `messenger-plugin.yml`, `real-backend-contract.yml`
and `verify-hermes-api-client.yml`). On main a run in progress finishes and a
queued one is replaced by the newer one, so main's latest finished run is the
one to read. `widgetbook.yml` still cancels on main: a Pages deploy is
superseded by the next one.
