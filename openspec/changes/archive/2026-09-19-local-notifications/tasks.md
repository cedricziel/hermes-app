The plan behind these tasks was `docs/superpowers/plans/2026-09-19-local-notifications.md`. All of it shipped in #56 except the manual check on a real OS.

## 1. The attention policy

- [x] 1.1 Tests, then `AttentionNotification`, `replyPreview` and `attentionFor` in `attention_policy.dart` (pure Dart): every combination of focused, same or different thread and switch on or off; preview trimming; "Reply ready" for an empty reply and "Reply failed" for a failed one
- [x] 1.2 `test/attention_policy_test.dart`

## 2. Notification settings

- [x] 2.1 Tests, then `NotificationSettings` in `notification_settings.dart`: the `enabled` switch (default on) and the permission state, persisted with `SharedPreferencesAsync`, in the style of `ThemeController`
- [x] 2.2 `test/notification_settings_test.dart`

## 3. The notification service

- [x] 3.1 Add `flutter_local_notifications` to `pubspec.yaml`
- [x] 3.2 Add the `NotificationService` interface (permission, `show`, tap stream)
- [x] 3.3 Add `LocalNotificationService` for macOS, iOS and Android (no-op elsewhere, exceptions caught), with pure helpers for payload to thread id and notification id per thread
- [x] 3.4 Add `FakeNotificationService` in `test/support/`
- [x] 3.5 `test/local_notification_service_test.dart` for the pure helpers only

## 4. Platform setup

- [x] 4.1 Android: `POST_NOTIFICATIONS` in the manifest, core library desugaring and an R8 keep rule for the icon, as the plugin requires
- [x] 4.2 iOS: the notification-center delegate. macOS needed no AppDelegate change because the plugin sets its own delegate
- [x] 4.3 Build macOS, iOS and Android. Android was not built locally for #56 (no SDK on that machine); the CI Android job was the check

## 5. Chat screen integration

- [x] 5.1 Let `pump_chat.dart` take extra providers
- [x] 5.2 Track app focus with a `WidgetsBindingObserver`; ask the policy about `ReplyCompleted`, `ApprovalRequested` and `ClarifyRequested` in `_onReplyEvent` and post the result
- [x] 5.3 Ask for permission once after the first send, only when the switch is on
- [x] 5.4 Select the thread on a notification tap, and on the launch tap once the thread list has loaded
- [x] 5.5 Provide the settings and the service in `lib/main.dart`
- [x] 5.6 `test/chat_notifications_test.dart`: finished reply while unfocused, request in another thread, nothing while focused on the same thread, permission asked once, tap selects the thread

## 6. The Notifications setting

- [x] 6.1 Notifications dialog with the switch, the "Alerts arrive while Hermes is running, including for a short time after you leave it." note, and the system-settings hint after a denial
- [x] 6.2 Menu entry next to Appearance in the thread sidebar
- [x] 6.3 Update `PRIVACY.md` about previews on a lock screen and the stored switch
- [x] 6.4 `test/notifications_setting_test.dart`

## 7. Verify

- [x] 7.1 Run `dart format`, `flutter analyze` and `flutter test`
- [ ] 7.2 Try it on macOS against a Hermes backend: permission asked once after the first send, a banner with the thread title and the start of the reply when switching away, a click that opens the thread, and nothing when the switch is off. #56 states that no notification had been seen on a real OS from that branch; nothing in the repository records that this pass was done later

## 8. Follow-ups outside this design

These shipped separately and are recorded here for orientation only.

- [x] 8.1 Announce a turn that broke mid-stream, report a tap that cannot open its chat, stop a tap from closing the current screen, and move the wiring into `AttentionNotifier` (#71)
- [x] 8.2 A generic notification for secret and sudo requests the app cannot answer (#127)
