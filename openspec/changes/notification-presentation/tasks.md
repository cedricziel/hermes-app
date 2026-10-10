# Tasks

One PR, `feat(notifications): show request details, group per chat, badge open requests`. **Starts after PR #587 (actionable notifications) merges** (its category builder and approval/question category ids). Needs `surface-snapshot` merged. No API routes change, so no OpenAPI regeneration.

## 1. Detail, grouping and level in Dart (TDD)

- [ ] 1.1 Read merged PR #587 and record in design.md the builder's name, the approval and question category ids, and where the payload is encoded; adjust the seams named in design.md, nothing else.
- [ ] 1.2 Write failing tests for `attentionFor` and the builder output: the approval detail (command, description), the question detail (first question, "and N more questions"), the 1000-character cut, no detail for secret/sudo/unsupported/reply/job notifications, bodies unchanged, the group key for chats and jobs (percent-encoded profile, same id in two profiles apart), `timeSensitive` for request notifications only, `groupKey` on Android, and that `targetFromResponse` still decodes a payload with `d`; implement in `attention_policy.dart` and the peer's builder; verify.

## 2. Badge (TDD)

- [ ] 2.1 Add `app_badge_plus: ^1.3.5` to `pubspec.yaml`, run `flutter pub get`, verify `flutter analyze`.
- [ ] 2.2 Write failing tests in `test/notifications/badge_controller_test.dart` with a fake badge service and a fake snapshot write stream: count of pending rows, unchanged count not re-sent, zero on signed-out snapshot, sign-out and notifications off, unsupported platform does nothing, plugin error swallowed; implement `badge_controller.dart` and wire it where the snapshot store and `NotificationSettings` are created (main isolate and the headless runtime's snapshot writes); verify.

## 3. Notification Content Extension

- [ ] 3.1 Create `ios/HermesNotificationContent/Core` with a `swift test` package and failing tests for payload decoding (`d` present, absent, malformed, unknown kind), the 12-line cut and the lock-gate decision (sentinel readable or not); implement; add the package to CI next to the watch core; verify.
- [ ] 3.2 Add the `HermesNotificationContent` extension target in Xcode (embedded in the Runner, App Group, bundle id and Debug prefix as design.md says, iOS 26), its Info.plist with the peer's approval and question category ids, the SwiftUI view, and the sentinel write in `AppDelegate`; verify `flutter build ios --simulator -d <udid>` succeeds.
- [ ] 3.3 Add `com.apple.developer.usernotifications.time-sensitive` to `ios/Runner/Runner.entitlements` and both macOS entitlements files, and signing for the new bundle id and capability to `fastlane/Fastfile`; verify the iOS and macOS builds.

## 4. Telemetry, docs and skills

- [ ] 4.1 Write a failing test with a recording breadcrumb trail that the badge records `notification.badge` with the bucket only when the bucket changes and nothing else; implement; verify.
- [ ] 4.2 Update CLAUDE.md (Notifications and Native pieces: the content extension, the payload detail and its lock gate, the badge) and the `verify-in-app` skill with how to check the expanded view in the simulator and that the lock gate needs a device with a passcode.

## 5. Verify

- [ ] 5.1 Run `dart format --output=none --set-exit-if-changed .`, `flutter analyze`, `flutter test` and the new `swift test`; all pass.
- [ ] 5.2 In the iOS simulator against `scripts/dev-backend.sh` with `HERMES_DEV_MODEL_CALLS=1`: trigger an approval and a question with the app in the background, long-press each and see the detail; check two chats group separately; check the badge count rises and falls as requests are raised and answered, and clears on sign-out. On a device with a passcode, expand an approval while locked and see the unlock note. On macOS, check the Dock badge. Restore the `ios/`/`macos/` Xcode files the build rewrites, staging files by name.
