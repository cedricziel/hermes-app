# Tasks

One PR, `fix(live-activity): end every turn it shows and ignore the turn ahead of a prompt`. No API routes change.

## 1. Turns that end unseen

- [x] 1.1 Write failing tests in `test/chat_live_activity_turn_ends_test.dart` for a stale stop, a folded prompt whose stream errors, a profile switch while a turn is followed, a reply of another profile and a chat closed mid-reply; verify they fail.
- [x] 1.2 Add `LiveActivities.abandon`, end the activity in the stale-stop branch, announce the folded failure, and abandon in `_stopFollowing` and `dispose` unless a send of the thread is in flight; verify the tests pass.

## 2. The turn ahead of a prompt

- [x] 2.1 Write failing tests that the completion of an `UnsolicitedEvent` turn, failed or not, leaves the prompt's activity working and that a request inside it shows waiting.
- [x] 2.2 Leave that completion out of `_announce` for the Live Activity, as for the watch status; verify the tests pass.

## 3. Verify

- [x] 3.1 `dart format --output=none --set-exit-if-changed .`, `flutter analyze`, `flutter test` on the touched files and `openspec validate live-activity-turn-ends --strict`.
