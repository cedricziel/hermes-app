## 1. Categories, payload and bodies

- [x] 1.1 Start with failing tests for the category builder (approval subsets in order, destructive Always and Deny, every action needing authentication, up to four choices, three plus Other… above four, Reply always, multi-select and open-ended with Reply and Open, no category for batches and secret requests) and the payload round trip; implement `request_notifications.dart`.
- [x] 1.2 Start with failing attention policy tests for the command and question bodies, the placeholders and the 1000-character cut; change `attentionFor` and its doc comment.
- [x] 1.3 Start with failing tests that map an action and its text input to an approval choice or a clarify answer, and a foreground action to a tap.

## 2. Sending the answer

- [x] 2.1 Start with a failing gateway transport test against `FakeGateway` for `answerOpenRequest` (`request.answer` params and `ok`/`expired`); add it to `ChatTransport` and the fakes.
- [x] 2.2 Start with failing tests for the answer sender: success, `expired`, a throwing transport and a signed-out app post the follow-up notification; log `notification.answer` and the `notification.answered` breadcrumb with kind, outcome and route only.
- [x] 2.3 Start with failing tests for routing a background action through the main isolate's port, and the fallback when no port is registered; add the background entry point.

## 3. Platform wiring

- [x] 3.1 Register the categories at initialize, apply placeholders and register question categories through `hermes_app/notification_categories` (iOS AppDelegate, macOS MainFlutterWindow); post with the category; keep Android bodies generic.
- [x] 3.2 Register the plugins and `hermes_app/background_task` in the iOS background engine.
- [x] 3.3 Wire the answer handling in `main.dart`; update the Notifications dialog text.

## 4. Watch

- [x] 4.1 Start with failing `WatchRequestHandler` tests: an approval or question answers `waiting` and keeps the send, a retry returns the final reply, a retry returns the waiting state again after the hold, the longer silence timeout while waiting, secret and sudo still end the send.
- [x] 4.2 Start with failing watch core tests for `waiting` in the relay reply and the conversation looping on it; show the waiting text in the conversation.

## 5. Review fixes

- [x] 5.1 A rejected refresh adopts a newer stored pair; background answers share one sign-in, go one at a time, look for the app's port for 3 s, hand over in two steps and work to one 25 s deadline.
- [x] 5.2 Cold launch: the Runner owns the notification delegate, begins the background task and starts the headless engine with only the plugins it needs.
- [x] 5.3 App Lock, placeholder-only categories, Android bodies by kind, event-frame fallback, launch answer once, serialized category calls, forget on sign-out.
- [x] 5.4 Watch: `waits`, open request set, last reported state, wait only for an answerable notification, keep the message on a failed retry, Stop waiting.

## 6. Docs and verify

- [x] 6.1 Update CLAUDE.md (notifications, watch).
- [x] 6.2 Run `openspec validate actionable-request-notifications --strict`, `dart format`, `flutter analyze`, the touched tests, the watch core tests and a watch compile check. Background behaviour on a device is left for a manual check.
