## 1. Announce watch turns

- [x] 1.1 Failing tests in `test/watch_request_handler_test.dart`: a completed watch turn calls `announce` with the preview body and the profile; a failed turn says "Reply failed"; a broken turn (stream error, send timeout, stream ending without a completion) says "Reply failed" once the thread is bound and announces nothing before; the title is the last `ThreadTitled`, else "Hermes"; an existing thread is announced under its session id; a phone with the chat open still announces
- [x] 1.2 Add `announce` to `WatchRequestHandler` and call `attentionFor` from the send loop
- [x] 1.3 Failing tests: `ApprovalRequested`, `ClarifyRequested` and `UnsupportedRequested` end the send at once with the fixed text, `failed: false`, the bound thread id, no announcement and a closed transport; the text carries nothing from the request
- [x] 1.4 Handle the three request events in the send loop

## 2. Wire it to the phone's notifications

- [x] 2.1 Failing tests in `test/watch_bridge_test.dart` for `WatchBridge.announcer`: it shows through the service when notifications are on and loaded; it does nothing while off, while loading, and without a service; a service that throws does not reach the caller
- [x] 2.2 Add `WatchBridge.announcer` and pass it from `forAuth`, which takes the `NotificationService` and `NotificationSettings`
- [x] 2.3 In `lib/main.dart` create the `WatchBridge` provider after `NotificationSettings` and `NotificationService`

## 3. Specs and docs

- [x] 3.1 Correct "an empty watchOS app" in `CLAUDE.md` (Native pieces) and in `openspec/config.yaml` (context)
- [x] 3.2 No API route change: `openapi/` and `packages/hermes_api` are untouched, so no client regeneration
- [x] 3.3 Telemetry: none. No skill under `.claude/skills` is made stale
- [x] 3.4 At archive time sync `specs/watch` into a new `openspec/specs/watch/spec.md` with a Purpose section, and `specs/notifications` into the existing notifications spec

## 4. Verify

- [x] 4.1 `dart format`, `flutter analyze` and `flutter test` pass
- [x] 4.2 verify-in-app does not apply: the relay runs on iOS with a paired watch, and the loop runs the macOS app. Say so in the PR and ask for a check on a paired device: send from the watch, lower the wrist and lock the phone, and see the notification on the watch; then trigger an approval and see the fixed text
