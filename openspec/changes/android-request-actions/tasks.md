# Tasks

One PR, `feat(notifications): answer agent requests from Android notifications`.

- [x] 1.1 Write failing tests for the Android action set: approvals in order with Always allow dropped when four are offered; a question with 1, 2, 3 and more than 3 choices; open-ended and multi-select as Reply and Open; several questions, an approval with no known choice and a secret request carry none.
- [x] 1.2 Write failing tests that an answerable request on Android has the command or question as body (cut at 1000 characters), secret visibility and the actions, and that App Lock on, App Lock not loaded and unanswerable requests keep the generic body, default visibility and no actions.
- [x] 1.3 Implement the Android request notification and its actions (`RemoteInput` for Reply), sharing the action ids and `answerFor` with iOS.
- [x] 1.4 Write failing tests that `answerRequestInBackground` calls `prepareBackgroundIsolate()` first, hands the answer to a registered port, answers alone otherwise, and posts "Couldn't send your answer. Open Hermes to answer." for the same chat on failure or expiry. Implement the background callback and register the hand-off port on Android in the app.
- [x] 1.5 Cancel the notification when an answering action is tapped (`cancelNotification`), and re-post the follow-up on failure.
- [x] 1.6 Write a failing test that turning App Lock on withdraws answerable request notifications on Android; implement it.
- [x] 1.7 Declare `ActionBroadcastReceiver` (not exported) in `AndroidManifest.xml`.
- [ ] 1.8 Update `CLAUDE.md` (Notifications paragraph: Android shows the body and actions). Left out of this PR, which may not edit `CLAUDE.md`; to be done by the maintainer.
- [x] 1.9 Run `dart format`, `flutter analyze` and `flutter test`; CI builds the release APK.

## Not verified on a device

- 2.1 Try the actions on an Android emulator or phone: approve, deny, Reply, "Other…", lock screen hidden until unlock, App Lock withdrawal, a failed answer.
