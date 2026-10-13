## Why

A chat announcement can wait for device permission or native notification preparation after its session has paused. Resuming the same session must not revive that old private announcement.

## What Changes

- Accept an optional session activity signal in AttentionNotifier, with active behavior when no signal is supplied.
- Reject new announcements and permission requests while paused or disposed.
- Invalidate delayed announcements on pause and dispose, including after native preparation.
- Preserve a device permission result already requested and continue handing notification taps and launch targets to the routing owner.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `notifications`: Suspend private chat announcements across asynchronous notification preparation.

## Impact

AttentionNotifier and focused tests change. Root integration owns the shared activity signal and platform notification guard. No backend API, dependency, or minimum server version changes are required.

Non-goals: retaining screens or drafts, routing queued intents, recalling delivered notifications, and suspending background workers.

Security and privacy: suspended sessions cannot start private chat announcements, and delayed work cannot publish after its authorization expires. No token storage or telemetry payload changes.

Observability: None. This local authorization gate adds no user action or backend operation. Controlled asynchronous tests expose skipped stale announcements without collecting user content.
