# Tasks

One PR, `feat(notifications): group per chat, time-sensitive requests, badge open requests`. Builds on #587/#589 (on main). Needs `surface-snapshot` merged. No API routes change, so no OpenAPI regeneration.

## 1. Grouping and level (TDD)

- [x] 1.1 Write failing tests for `attentionFor` and `LocalNotificationService.show`'s details: the group key for chats and jobs (percent-encoded profile, same id in two profiles apart), `threadIdentifier` and Android `groupKey`, `timeSensitive` for every `hermes.request.*` category (placeholders included) and secret/sudo/unsupported notifications only, bodies and `categoryIdentifier` unchanged; implement in `attention_policy.dart` and `local_notification_service.dart`; verify.
- [x] 1.2 Add `com.apple.developer.usernotifications.time-sensitive` to `ios/Runner/Runner.entitlements` and both macOS entitlements files, and the capability to fastlane signing; verify the iOS and macOS builds. (macOS: Release only, see design.md Deviations; fastlane gets a portal reminder, since the public API cannot set the capability.)

## 2. Badge (TDD)

- [x] 2.1 Add `app_badge_plus: ^1.3.5` to `pubspec.yaml`, run `flutter pub get`, verify `flutter analyze`.
- [x] 2.2 Write failing tests in `test/notifications/badge_controller_test.dart` with a fake badge service and a fake snapshot write stream: count of pending rows, unchanged count not re-sent, zero on signed-out snapshot, sign-out and notifications off, unsupported platform does nothing, plugin error swallowed, and the `notification.badge` crumb with the bucket only when the bucket changes; implement `badge_controller.dart` and wire it where the snapshot store and `NotificationSettings` are created; verify.

## 3. Docs and verify

- [x] 3.1 Update CLAUDE.md (Notifications: grouping, time-sensitive, badge).
- [x] 3.2 Run `dart format --output=none --set-exit-if-changed .`, `flutter analyze`, `flutter test`; all pass.
- [ ] 3.3 In the iOS simulator against `scripts/dev-backend.sh` with `HERMES_DEV_MODEL_CALLS=1`: check two chats group separately and the badge rises and falls as requests are raised and answered, and clears on sign-out. On macOS, check the Dock badge. Restore the `ios/`/`macos/` Xcode files the build rewrites, staging files by name.
