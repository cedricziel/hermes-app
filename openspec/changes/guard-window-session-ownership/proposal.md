## Why

Conversation and quick-panel windows close only after asynchronous auth cleanup, and saved conversation targets are scoped only by server address. A different account on the same server can therefore receive old window targets after sign-in; retained native requests also need a lifetime check.

## What Changes

- Close native auxiliary windows immediately when protected access is suspended, before credential cleanup finishes.
- Scope conversation restoration and native header handoffs to verified session ownership; reject legacy gated records without ownership proof.
- Keep expiry restoration only for the same verified owner. Explicit sign-out/server departure forgets targets, including races with pending native creation or saved-state writes.
- Serialize native close and creation so old teardown cannot close newly restored windows.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `chat`: owner-scoped macOS conversation-window restoration and header handoffs.
- `auth`: immediate auxiliary-window suspension during protected-access loss.

## Impact

ConversationWindows, saved/launch arguments, main-provider session wiring, a non-secret owner fingerprint, and window/auth tests. macOS auxiliary windows are affected; no backend route, dependency, entitlement, or native project change is required. iOS/Android/Windows/Linux keep existing window availability, and watchOS keeps the phone relay.

Non-goals: preserving native-window drafts, retaining the main navigator/composer, or suspending main chat sockets/dictation/polling. Those remain subsequent checklist layers.

Security and privacy: main-process verified identity establishes ownership, never token equality or display names. Saved window metadata gains a deterministic hash of server/user/organization/provider; no bearer/refresh token or draft is persisted or logged. Telemetry uses a fixed window-session outcome only, with no owner identifiers, addresses, titles, or content.
