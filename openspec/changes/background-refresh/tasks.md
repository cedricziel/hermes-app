# Tasks

One PR, `feat(background): refresh requests and the snapshot in the background`, about 450 changed lines with tests. No API routes change, so no OpenAPI regeneration. No UI. Requires `headless-runtime`, `surface-snapshot` and peer PR #587 to be merged.

## 1. Check the backend first

- [ ] 1.1 Against `scripts/dev-backend.sh`, add cases to `test/real_backend_contract_test.dart` and run them before building on these questions:
  - Does `session.active_list` without `profile`, and with each profile, list the sessions of other profiles?
  - Does `approval.pending` expect the session's `id` or its `session_key` as `session_id`?
  - Does a session that waits for an approval report `status: waiting`?

  Record the answers in design.md and adjust the requests step if any answer differs.

## 2. Scheduling

- [ ] 2.1 Add `workmanager: ^0.10.10` to `pubspec.yaml`, run `flutter pub get`, verify with `flutter analyze`.
- [ ] 2.2 Write failing tests for `BackgroundScheduler` with a fake Workmanager:
  - once signed in, it registers the periodic task (15 min, network constraint, keep policy);
  - on sign-out, it cancels the task;
  - on macOS and desktop, it does nothing;
  - when registration fails, it logs `background.refresh.schedule_failed` and does not throw.

  Implement `background_scheduler.dart` and start it from `main.dart`; verify.

- [ ] 2.3 Add `BGTaskSchedulerPermittedIdentifiers` and `UIBackgroundModes: fetch` to `ios/Runner/Info.plist`. In `AppDelegate`, register the periodic task and call `WorkmanagerPlugin.setPluginRegistrantCallback` with `BackgroundPlugins`, adding `home_widget` and `workmanager_apple` to it. Verify that `flutter build ios --simulator -d <udid>` succeeds, then restore the Xcode files the build rewrites.

## 3. Open requests (TDD)

- [ ] 3.1 Write failing tests in `test/background/background_refresh_test.dart` with a fake gateway and `FakeHermesServer`:
  - `session.active_list` is called once per profile;
  - `approval.pending` is called only for `waiting` sessions;
  - each new approval gets one notification, "Waiting for your approval";
  - a waiting session without approvals gets "Waiting for you in Hermes";
  - an id announced in an earlier run is not announced again;
  - the announced list keeps the newest 200;
  - nothing is posted when notifications are off;
  - the approval's command never reaches the notification;
  - an approval is posted with #587's approval category, built by its category builder.

  Implement the step contract (`BackgroundStep`, `BackgroundContext`), the requests step and the announced-ids store; verify.

## 4. Snapshot and Spotlight

- [ ] 4.1 Write failing tests:
  - `HeadlessHermes.refreshSnapshot(pending:)` reads the remote sources and replaces every profile's pending entries;
  - a failed requests step keeps the previous pending list;
  - with App Lock on, titles and snippets are omitted (counts stay) and the Spotlight listener clears the index;
  - registered snapshot listeners (the Spotlight hook) run.

  Implement `refreshSnapshot` and the snapshot step; verify.

- [ ] 4.2 Write a failing test that `hermes://requests` opens the oldest pending request from the stored snapshot, including one in another profile, and falls back to the loaded chats. Implement in `ChatController`; verify.

## 5. The run and its telemetry

- [ ] 5.1 Write failing tests for `runBackgroundRefresh`:
  - the steps run concurrently, and one failing step does not stop the others;
  - the run ends within the budget;
  - the dispatcher returns `true` on every outcome;
  - `HeadlessSignedOut` cancels the periodic task and posts nothing; `HeadlessLocked` and `HeadlessUnreachable` change nothing;
  - the `background.task` span carries `requests.new` and `steps_failed`, and no id or text;
  - telemetry is flushed before the dispatcher returns.

  Implement the dispatcher in `entry_points.dart`; verify.

## 6. Docs, skills and verify

- [ ] 6.1 Update CLAUDE.md:
  - Notifications: what background refresh does and its limits;
  - Native pieces: the BGTask identifier.

  Add a `verify-in-app` section on triggering the task in the simulator from the Xcode debugger with `e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"<bundle id>.refresh"]`, and note that the task does not run on macOS.

- [ ] 6.2 Run `dart format --output=none --set-exit-if-changed .`, `flutter analyze` and `flutter test`; all must pass.
- [ ] 6.3 In the iOS simulator against `scripts/dev-backend.sh`:
  1. Start a prompt that needs an approval and send the app to the background.
  2. Simulate the task launch. One "Waiting for your approval" notification appears, and `hermes.surface.v1` holds the pending entry.
  3. Simulate the task launch again. No second notification appears.

  Restore the Xcode files the build rewrites, staging files by name.
