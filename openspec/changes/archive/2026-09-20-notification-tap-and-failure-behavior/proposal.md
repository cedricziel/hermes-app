## Why

PR #71 changed how notification taps and failed turns behave, but the specs still describe the earlier behavior: a tap for a chat that cannot be opened is silent, a broken stream produces no notification, and a tap can close screens it should leave alone. The specs and the app disagree.

## What Changes

- A reply whose stream breaks before it completes is announced like a failed reply, with the body "Reply failed".
- A notification's chat counts as the open one only while the app is still on the profile the turn was sent under.
- A tap no longer closes a screen the user has opened above the chat; it closes the thread drawer when that is open.
- A tap that cannot open its chat (another profile, or a chat not in the list) now says "Could not open that chat." instead of doing nothing.
- A tap made while the chat list is still loading is held and applied once the list has loaded, instead of being dropped.

Non-goals: no change to what a notification shows, to the permission flow, or to the settings dialog. No push notifications.

Security and privacy impact: None. The new "Reply failed" body carries no error text, like the existing one.

Telemetry: None.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `notifications`: notifiable events (a broken stream counts as a failed reply), the attention policy (open chat is judged under the turn's profile), and tapping a notification (no screen closed, message when it cannot open, held while loading).
- `chat`: opening a thread from a notification (same tap rules).

## Impact

Code only in `lib/src/chat/chat_screen.dart` and `lib/src/notifications/`, already merged in #71. This change brings the specs in line; it changes no code.
