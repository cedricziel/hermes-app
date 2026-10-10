# Tasks

One PR, `feat(background): announce finished replies and scheduled runs in the background`, about 350 changed lines with tests. No API routes change, so no OpenAPI regeneration. No UI. Requires `background-refresh` to be merged (which requires `headless-runtime`, `surface-snapshot` and peer PR #587).

## 1. Check the backend first

- [ ] 1.1 Against `scripts/dev-backend.sh`, add cases to `test/real_backend_contract_test.dart` and run them before building on these questions:
  - Is a `session.active_list` row's `session_key` the stored session id that `/api/sessions` and the chat use?
  - Does a finished turn report `idle`, or does its session drop out of the list?
  - Does `GET /api/sessions/{id}/messages?limit=5` return the newest messages?

  Record the answers in design.md and adjust the running-replies step if any answer differs.

## 2. Running replies (TDD)

- [ ] 2.1 Write failing `ChatController` tests:
  - on `paused`, each chat with a running reply is stored as `{profile, threadId, sessionKey, since}`;
  - on `resumed`, the list is cleared.

  Implement; verify.

- [ ] 2.2 Write failing tests for the running-replies step, with a fake gateway and `FakeHermesServer`:
  - a remembered chat whose session no longer runs a turn is announced with the preview of its last assistant message;
  - a failed reply is announced as "Reply failed";
  - when the read fails, the empty-reply text is used;
  - a `working` or `resuming` session stays remembered;
  - entries older than 24 hours are dropped;
  - when `session.active_list` fails, nothing changes;
  - nothing is posted while notifications are off;
  - for `HeadlessSignedOut`, `HeadlessLocked` and `HeadlessUnreachable` the step does not run and the remembered list is unchanged.

  Implement and add the step to the run; verify.

## 3. Scheduled tasks (TDD)

- [ ] 3.1 Write failing `ScheduleWatcher` tests:
  - the watcher loads `hermes.schedules.baseline.v1` before its first look and saves it after each look, so a run already announced in the background is not announced again in front;
  - the first look on a fresh install only sets the baseline;
  - turning the setting on still starts from a new baseline.

  Implement; verify.

- [ ] 3.2 Write failing tests for the schedule step:
  - it announces the runs since the stored baseline with `alertsFor`;
  - it follows the schedule setting and the mutes;
  - on the first run, it sets the baseline without announcing anything;
  - without the cron routes, it does nothing.

  Implement and add the step; verify.

## 4. Telemetry

- [ ] 4.1 Write failing tests that the run's `background.task` span carries `replies.finished` and `schedules.ran`, and no id, title or text. Implement; verify.

## 5. Docs, skills and verify

- [ ] 5.1 In CLAUDE.md, update the Notifications section: background runs now announce finished replies and scheduled runs, and the schedule baseline is shared with the watcher. Add a step to the `verify-in-app` section on background tasks.
- [ ] 5.2 Run `dart format --output=none --set-exit-if-changed .`, `flutter analyze` and `flutter test`; all must pass.
- [ ] 5.3 In the iOS simulator against `scripts/dev-backend.sh`:
  1. Send a prompt and send the app to the background before the reply finishes. Let the reply finish, simulate the task launch, and see the reply-ready notification with its preview.
  2. Trigger a failing cron job, simulate the launch again, and see one "Failed" notification.
  3. Open the app. No second "Failed" notification appears.

  Restore the Xcode files the build rewrites, staging files by name.
