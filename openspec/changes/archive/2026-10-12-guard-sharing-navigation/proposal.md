## Why

Shared text, files, and selected-text quotes currently clear pushed routes and mutate the chat before dismissal guards run. Replacing a waiting navigation callback must not discard its shared payload.

## What Changes

- Keep shared items in the inbox until the shell reaches its root safely and App Lock allows delivery.
- Accumulate waiting text/files and retain the existing latest-quote policy.
- Let newer notification/link navigation win while retaining superseded shared content for the next explicit Chat section entry, as confirmed by the user.
- Preserve standalone Chat behavior and send no message automatically.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `navigation`: guarded shared-content dispatch and payload retention after navigation replacement.

## Impact

ChatScreen, AppShell, and existing share/navigation tests. ShareController remains the payload owner. No new backend calls, dependencies, native project changes, or entitlements. Dock, menu-bar, window handoffs, and authentication recovery remain separate changes.

Security and privacy impact: no new storage or telemetry. Existing sign-out handling for pending quotes remains intact. Observability: retain the existing fixed-name quote breadcrumb at actual delivery; add no content-bearing signals.
