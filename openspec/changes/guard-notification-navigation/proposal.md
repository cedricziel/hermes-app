## Why

Notification taps still bypass editor guards and can change the underlying chat before the current screen closes. Launch notifications use a separate path during thread loading, so protecting only warm taps would leave a bypass.

## What Changes

- Defer warm and launch notification delivery through the guarded root navigation queue.
- Preserve existing session/profile matching and no-fetch behavior for ordinary notification taps.
- Deliver only the latest pending external navigation intent; a newer warm tap supersedes an older launch notification.
- Queue scheduled-job notifications before changing destinations and ignore destinations known to be unavailable.
- Resume notification delivery after App Lock unlocks, even without a deep-link provider.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `navigation`: Guarded notification delivery and latest-intent ordering.

## Impact

AppShell, ChatScreen, launch handling in ChatController, and notification/navigation tests. No new backend routes, dependencies, generated client changes, or native configuration.

## Non-goals

Sharing, Dock/menu-bar/Handoff/window entry points, authentication teardown, section history, and presentation changes follow separately.

## Security and privacy impact

Do not apply queued notification payloads while App Lock covers the app or after the shell is disposed. No token/storage changes. Session/profile validation remains unchanged.

## Observability

Retain chat-open and destination breadcrumbs, emitted after guards allow delivery. Add `nav.notification.ignored` with fixed `kind: job` and `reason: unavailable` for unavailable schedule targets. No ids, profile names, text, spans, or new log events.
