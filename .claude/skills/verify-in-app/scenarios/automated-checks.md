# Automated checks before native verification

Use an isolated checkout and record the exact source commit or patch hashes.
Keep backend compatibility checks advisory and use the existing contracts.

## Reproduce the boundary

Write a failing regression before changing behavior when practical. Drive the
actual controller or transport when the failure depends on ownership or dispatch.
Check the number of RPCs and the resulting record state rather than only an error
message. A request denied before bytes leave may restore queued state; a failure
after dispatch remains uncertain. Include an authoritative late-acceptance control.

Exercise synchronous listeners and telemetry callbacks as well as delayed futures.
They can retire activity, replace the physical binding, or change a snapshot before
an awaited result is applied or a request sends. Capture Flutter notifier errors;
ordinary unit tests can otherwise log a disposal assertion without failing.
Private details must clear immediately on retirement. If notifier delivery is
active, defer only its base disposal until the outer delivery finishes.

Create socket-backed widget fixtures, deliver events, and close or drain their
sockets inside `tester.runAsync`. Construct held completers in the same real
async zone. Settle a held main reply before waiting for all UI animations to stop.
Use a bounded timeout and inspect a stalled fixture independently before changing
production behavior.

## Check the exact files

Run scoped tests serially, then analyze the checkout. Use the same SDK command
that other workers agreed to serialize. Inspect failures before widening coverage;
do not rerun passed suites without a new change or unresolved concern.

Validate both delta and main specs after editing them. Use a fail-fast script so
a failed validation cannot fall through to a commit:

```bash
set -e
openspec validate <change-name> --strict
openspec validate --specs --strict
```

Stage only the exact change paths, including new files, before the final whitespace
check. `git diff --check` alone omits untracked files and does not check the index.
Run both `git diff --check` and `git diff --cached --check`; trim blank lines at EOF
and rerun spec validation if a spec file changes. Check that each exact staged or
new nonempty text file ends in a newline too; the diff checks do not detect a
missing final newline.

Run normal commit hooks. Record passed commands, counts, source revisions, and any
unobserved native cases. Source-identical rebases may reuse the matching evidence;
conflict resolutions or new parent behavior need relevant integration checks.

## Prepare the native run

Check free disk space on the checkout and build volume before building or
rebuilding. Remove only recorded disposable outputs from this verification task;
retain source snapshots and evidence, and leave shared SDK and user caches alone.
If enough space is unavailable, preserve the fixture and report the blocked build.

Before spawning the client, confirm the recorded backend PID and exact command
own the approved loopback listener. Verify the canonical task home against the
guarded launch environment and process record, and confirm `/api/status` reports
the required auth mode. Compare its home path when exposed; gated status omits
host paths, so do not require or add them. Abort before client launch if any
check fails. An earlier readiness log or process record is insufficient.

Before minting credentials for an authenticated fixture, prevent WebSocket tokens
or tickets and native-auth query credentials from entering captured logs. Check
`uvicorn.error` as well as access logging; disabling access logs alone is
insufficient. Verify suppression with non-secret canaries. Retain fixed outcomes
and counters, and leave production auditing unchanged.

Record actual native window dimensions for each layout check and note any OS
minimum size. Label fixture-forced dimensions separately and restore size overrides
with the other fixture substitutions.

For sandboxed macOS fixtures, validate the disposable bundle's container path
before creating a fresh task directory. Runtime `HOME` may be normalized to the
container's `Data` directory; accept only recorded task paths. Overriding `HOME`
does not grant access outside the sandbox.

If app binding stalls beyond the bounded attempt, stop and record unobserved
checks. Do not change frameworks or app identities to work around an automation
bridge failure.
