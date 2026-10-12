## Why

Scheduled-task alerts can finish a job lookup after session activity has been suspended and still change notification state or post an alert. A retained session needs a pause that keeps its last-run baseline while rejecting stale work.

## What Changes

- Pause scheduled-task polling immediately without deleting the baseline.
- Reject stale job, baseline, and profile continuations before new state writes or notification delivery.
- Resume with a fresh check even when an earlier lookup is still pending.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `notifications`: Suspend scheduled-task polling and notification delivery while preserving the comparison baseline.

## Impact

ScheduleWatcher and focused tests change. Existing generated cron and profile API calls, response shapes, dependencies, and minimum server version stay unchanged. AppShell activity wiring and the guarded platform notification capability are coordinated integration work.

Non-goals: full main or auxiliary-window draft retention, background-worker suspension, and changes to scheduled-job execution.

Security and privacy: prevent suspended client work from publishing alerts or starting new notification-state writes. No token storage or telemetry payload changes. Already dispatched requests or writes cannot be recalled.

Observability: no new signal. Existing generated-client request spans describe backend lookups; deterministic tests verify skipped stale completions. This boundary adds no user action or backend operation to instrument.
