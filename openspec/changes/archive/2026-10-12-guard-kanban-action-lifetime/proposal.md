## Why

Kanban actions can finish after their panel closes. If a late action fails, the error handler tries to show a snackbar after the caller has left. The Quick Look widget tests also use a fixed real-time wait, so they can finish before the action records its result on a busy CI worker.

## What Changes

- Keep the existing action error message visible while its caller is mounted.
- Skip snackbar presentation when an action fails after its caller has been disposed.
- Replace the affected Quick Look test waits with an explicit preview-completion signal.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `kanban`: scope action failure notices to a live caller while preserving existing errors.

## Impact

The change affects Kanban action error handling and its widget tests. It uses existing API calls and adds no dependencies. It adds no telemetry. It does not change snackbar wording or successful action behavior. Security and privacy impact: None.

Non-goals: changing error messages, canceling in-flight requests, changing attachment storage, modifying other screens, or changing native/platform behavior.
