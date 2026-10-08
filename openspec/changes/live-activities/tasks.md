# Tasks

One PR, `feat(ios): show a running reply as a Live Activity`. No API routes change, so no OpenAPI regeneration.

## 1. Dependency and platform interface

- [ ] 1.1 Add `live_activities: ^2.6.0` to `pubspec.yaml`, run `flutter pub get`, and confirm from the plugin source whether `updateActivity` accepts a stale date; record the answer in design.md (Risks) and verify `flutter analyze` passes.
- [ ] 1.2 Add `lib/src/live_activities/live_activity_service.dart`: the `LiveActivityService` interface (`allowed`, `start`, `update`, `end`, `endAll`, `taps`, `launchTap`), the plugin implementation (iOS only, every call wrapped so a plugin error is swallowed) and a no-op for other platforms, plus `test/support/fake_live_activity_service.dart`; verify with `flutter analyze`.

## 2. State and controller (TDD)

- [ ] 2.1 Write failing tests in `test/live_activities/live_activity_state_test.dart` for each spec state transition (approval, question, secret/sudo, answered/expired/cancelled back to working, completed, failed, broke, stopped ends, deltas and tools leave the state alone), then implement `live_activity_state.dart` reusing the label constants from `attention_policy.dart`; verify the tests pass.
- [ ] 2.2 Write failing tests in `test/live_activities/live_activity_controller_test.dart` for: one activity per chat (reuse on second send), no start while the setting is off/loading or not allowed, refused start swallowed, stale date set only while unfocused and cleared on resume, final state ended with a 15-minute dismissal, stopped/deleted/sign-out/setting-off ended at once, `endAll` on startup, title updates, and coalescing of repeated identical updates; implement `live_activity_controller.dart`; verify the tests pass.
- [ ] 2.3 Write failing tests that a tap URL (`hermes-activity://open?thread=…&profile=…`) and a cold-start tap reach `onOpen` as a `NotificationTarget`, and that a malformed URL is ignored; implement and verify.

## 3. Wiring

- [ ] 3.1 Add `liveActivities` to `NotificationSettings` (key `hermes.live_activities`, default true, edit counter) with failing tests in the existing settings test first; verify the tests pass.
- [ ] 3.2 Write failing `ChatController` tests (with `FakeChatTransport` and the fake service) that a send starts an activity, a canned reply starts none, a folded prompt keeps the chat's one activity, and `_onReplyEvent` drives the state including the synthesized completion for a settled turn; wire the controller into `ChatController` and `ChatScreen` (the conversation window passes none); verify the tests pass.
- [ ] 3.3 End all activities on sign-out from `AuthController`'s sign-out path and on chat deletion, with a failing test first for each; verify.
- [ ] 3.4 Route activity taps into the same open path as notification taps in `ChatScreen`/`ChatController`, with a test that a tap for another profile shows "Could not open that chat."; verify.

## 4. Settings UI

- [ ] 4.1 Add Widgetbook use cases for `NotificationsDialog` with the Live Activities switch (on, off, disallowed hint) on iOS and its absence on Android/macOS, both themes, phone and desktop width; verify `flutter test test/widgetbook_test.dart`.
- [ ] 4.2 Add the switch and the "Turn on Live Activities for Hermes in system settings." hint to `NotificationsDialog` (iOS only); turning it off calls `endAll`; verify with a widget test.

## 5. iOS widget extension

- [ ] 5.1 Add the `HermesLiveActivity` widget extension target in Xcode (embedded in Runner, App Group `$(CUSTOM_GROUP_ID)`, bundle IDs `com.cedricziel.hermesApp.LiveActivity` / Debug `com.cedricziel.hermesApp.dev.LiveActivity`, iOS 26), add `NSSupportsLiveActivities` and the `hermes-activity` URL scheme to `ios/Runner/Info.plist`; verify `flutter build ios --simulator -d <udid>` succeeds.
- [ ] 5.2 Implement the SwiftUI Lock Screen and Dynamic Island views (title, label, timer, stale note, `widgetURL`) reading the plugin's shared `UserDefaults` keys; verify with Xcode previews for every state and in the simulator.
- [ ] 5.3 Add signing for the new bundle ID to `fastlane/Fastfile` (match/provisioning alongside ShareExtension and HermesWatch) and confirm the release lane's export options list it.

## 6. Telemetry, docs and skills

- [ ] 6.1 Record the `live_activity.started`, `live_activity.ended` (`outcome`) and `live_activity.unavailable` crumbs through `Breadcrumbs`, with a test using a recording trail that no text or id is added; verify.
- [ ] 6.2 Update CLAUDE.md (Notifications and Native pieces sections) and the `verify-in-app` skill with how to check Live Activities in the iOS simulator (macOS dev loop does not cover them).

## 7. Verify

- [ ] 7.1 Run `dart format --output=none --set-exit-if-changed .`, `flutter analyze` and `flutter test`; all pass.
- [ ] 7.2 In the iOS simulator against `scripts/dev-backend.sh`: send a prompt, lock the screen, see the working state; trigger an approval and see "Waiting for your approval"; let the app suspend and see the stale note; reopen and see "Reply ready"; tap the activity and land on the chat; sign out and see all activities gone. Restore the `ios/`/`macos/` Xcode files the build rewrites, staging files by name.
