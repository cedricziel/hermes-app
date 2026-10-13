## Why

An expired session can leave a scheduled-job form mounted while sign-in recovers. Its metadata reads and an in-flight save currently use route lifetime as their only guard, so they can start or commit outside the verified session activity window. The form should keep what the user entered during same-account recovery without sending another save.

## What Changes

- Suspend delivery-target and model-option reads while session activity is paused, discard stale replies, and reload metadata when the same activity resumes.
- Refuse saves while paused and report a typed cancellation if a save already in flight returns after its activity epoch ended.
- Keep the form open and preserve its values on activity cancellation; recovery never retries a save automatically.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `scheduled-task-editor`: specify job-form behavior while verified session activity is suspended and resumes.

## Impact

Affected code: `JobFormController`, `JobFormScreen`, and their tests. No backend routes, dependencies, token storage, or telemetry change. Security and privacy impact: none; this uses the existing session activity signal and stores no new account data. Observability: none; a cancelled UI result is expected lifecycle behavior and adds no operational signal.

Non-goals: wiring the activity owner through AppShell, changing blueprint forms, changing the schedule list or watcher, clearing state on owner retirement, and cancelling a request already accepted by the HTTP transport.
