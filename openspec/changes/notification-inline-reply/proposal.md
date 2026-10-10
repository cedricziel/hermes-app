# Proposal

## Why

A "Reply ready" notification often calls for a short answer: "yes, book it", "try the other branch". Today that means opening Hermes, waiting for the chat to load and typing there. iOS lets a notification take a typed reply in place; Hermes should send it into the chat in the background and announce the answer later as a normal notification.

## What Changes

- "Reply ready" notifications on iOS and macOS get a "Reply" action with a text field. What the user types is sent as a new prompt into that chat (`prompt.submit`, queued behind a turn that may still run) without opening the app.
- The answer arrives later as the usual "Reply ready" (or request) notification: posted by the background work while iOS keeps it running, otherwise by the background check for finished replies (`background-refresh`).
- The action requires the device to be unlocked.
- When the prompt cannot be sent (signed out, device not yet unlocked since restart, server unreachable, the chat gone), a "Reply not sent" notification for that chat says so; tapping it opens the chat with the unsent text in the composer (`hermes://chat?...&prompt=`), not sent.
- The reply action is added to the "Reply ready" category through the peer session's reusable category builder (actionable-notifications PR, not merged yet), and its response is handled in the same background notification handler the peer adds for its buttons. **It starts after that PR merges**, and after `notification-presentation` if both touch the builder at once.

Non-goals:

- No inline reply on Android in this change: Android runs the background handler in its own isolate, and the headless runtime (`headless-runtime`) only promises iOS background engines. A later change can add it.
- No reply to request notifications (approvals and questions have the peer's buttons and text answers).
- No attachments, model choice or slash commands from a notification.
- No "Reply failed" or scheduled-task notifications with a reply action.
- No answering of requests here: that is #587's `answerOpenRequest`; no coordinate-based answer methods.

Security and privacy impact:

- The action needs the device unlocked (`authenticationRequired`), so a locked phone cannot send prompts from a notification. (Ask Hermes by Siri is allowed while locked by the user's choice; a typed reply on the Lock Screen was not part of that choice, and a reply can steer a chat that runs tools.)
- The typed text crosses into Dart in memory and goes to Hermes like any prompt; it is never logged or traced and never shown in the failure notification's text; it is kept only in that notification's payload (for the prefill link) until the notification is tapped or cleared.
- Tokens are read by the headless runtime only (Contract 3).

Observability:

- Span `background.task` (from `headless-runtime`) with `task: notification.reply` and `outcome` (`sent`, `failed`, `unavailable`, `answered`, `not_answered`), plus `engine`; it crosses the gateway.
- Log event `notification.reply` with `outcome`, to count how often replies fail to send.
- Breadcrumb `notification.reply` with `outcome` when the running app's engine handles it.
- None carries the text, a title, a profile name or an id.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `notifications`: adds the inline reply on "Reply ready" notifications and the "Reply not sent" notification.

## Impact

- Dart: `lib/src/notifications/inline_reply.dart` (send through `withHeadlessHermes` and the same turn runner "Ask Hermes" uses), the reply action in the peer's "Reply ready" category, a branch in the peer's background response handler and in the foreground response handler.
- iOS and macOS: no native code; `flutter_local_notifications` 22.3.1 supports text-input actions and background responses.
- Dependencies: PR #587 (actionable notifications), `headless-runtime`, `deep-links`, `ask-hermes-intent` (shared turn runner), and for late answers `background-refresh`.
- Backend: no new routes; `session.resume`, `prompt.submit` and the reply events.
