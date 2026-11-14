# Tasks

One PR, `feat(notifications): answer agent requests from Android notifications`.

- [x] 1.1 Write failing tests for the Android action set: approvals in order with Always allow dropped when four are offered; a question with 1, 2, 3 and more than 3 choices; open-ended and multi-select as Reply and Open; several questions, an approval with no known choice and a secret request carry none.
- [x] 1.2 Write failing tests that an answerable request on Android has the command or question as body (cut at 1000 characters), secret visibility and the actions, and that App Lock on, a generic body (background refresh) and unanswerable requests keep the generic body, default visibility and no actions.
- [x] 1.3 Implement the Android request notification and its actions (`RemoteInput` for Reply), sharing the action ids and `answerFor` with iOS.
- [x] 1.4 Register `answerRequestInBackground` as the Android background callback (tested) and the hand-off port in the app on Android; skip the wait for the app's port on Android (`routeAnswer` with no poll, tested). The hand-off, lone answer and failure follow-up are the existing, platform-independent tests in `request_answers_test.dart`. App Lock not yet loaded is covered by `appLockHidesRequests`, which treats it as on.
- [x] 1.5 Cancel the notification when an answering action is tapped (`cancelNotification`), and re-post the follow-up on failure.
- [x] 1.6 Write a failing test that turning App Lock on withdraws answerable request notifications on Android (by the `hermes.request` tag, since Android returns no payload); implement it, keeping one notification per chat.
- [x] 1.7 Declare `ActionBroadcastReceiver` (not exported) in `AndroidManifest.xml`.
- [x] 1.8 Update `docs/architecture/notifications-and-background.md` (Android shows the body and actions), which now holds the Notifications text that was in `CLAUDE.md`.
- [x] 1.9 Run `dart format`, `flutter analyze` and `flutter test`; CI builds the release APK.

## Not verified on a device

- 2.1 Try the actions on an Android emulator or phone: approve, deny, Reply, "Other…", lock screen hidden until unlock, App Lock withdrawal, a failed answer.
