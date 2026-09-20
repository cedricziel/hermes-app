## Why

A message sent from the watch runs on the phone and can take a minute. If the user lowers their wrist meanwhile, the reply has nowhere to land, and nothing tells them it finished. The phone already has local notifications for replies, but they only fire from the phone's own chat screen, so a turn sent from the watch is silent.

A second gap sits in the same code path. When the agent asks for an approval or an answer during a watch-sent turn, `WatchRequestHandler.send` ignores the event and waits out its 60 second timeout. The request cannot be answered anywhere: a pending request lives only on the connection that raised it and is not replayed after a reconnect. The user waits a minute for a failure with no explanation.

## What Changes

- When a turn sent from the watch finishes, fails, or breaks (the stream drops, times out or ends without a completion), the phone posts the existing local notification through `NotificationService` and the `attentionFor` policy. iOS mirrors it to the paired watch while the phone is locked.
- A watch turn is announced whatever chat the phone has open, because the phone's chat screen does not follow a turn it did not send.
- The notification is titled with the thread's title when the gateway named it during the turn, and "Hermes" otherwise. The body follows the existing rules (one-line preview, "Reply failed").
- When the agent raises an approval, a question or an unsupported request during a watch turn, the send ends at once with `ok: true`, `failed: false` and a short text saying the watch cannot answer it and to ask again on the iPhone. No notification is posted, because nothing on the phone could answer the request.
- The relay takes the phone's `NotificationService` and `NotificationSettings`. `WatchBridge` is created after both in `lib/main.dart`.
- A new `watch` capability spec documents the companion behaviour that shipped without one: threads, messages, send, profile-scoped thread ids, limits, timeouts and error codes.
- `CLAUDE.md` and `openspec/config.yaml` still call the watch app empty; they are corrected.

## Impact

- `lib/src/watch/watch_request_handler.dart`, `lib/src/watch/watch_bridge.dart`, `lib/main.dart`.
- Tests: `test/watch_request_handler_test.dart`, `test/watch_bridge_test.dart`.
- Specs: new `watch`, and a new requirement in `notifications`.
- No change to `openapi/` or `packages/hermes_api`, to the Swift sources, or to any Xcode, entitlement or signing setting. The watch already renders the returned text as an assistant message.

## Non-goals

- Push notifications while the phone app is not running. Notifications stay local, so a watch turn is only announced while the phone process lives to see it finish.
- Asking the system for notification permission from a watch send. The prompt would appear on a phone the user is not holding. Until the user has answered it from a chat on the phone, a watch turn posts nothing.
- A notification tap that opens the thread on the watch. The tap opens the watch app at its thread list; on the phone it opens the chat, as today.
- Answering approvals or questions from the watch.
- The watch complication (a separate change).

## Security and privacy impact

None on tokens or storage. Reply previews reach the lock screen and the watch exactly as they do for a turn sent from the phone, under the same on and off setting. An unsupported request is never announced, and the watch text about it names neither the command nor the question.

## Telemetry

None.
