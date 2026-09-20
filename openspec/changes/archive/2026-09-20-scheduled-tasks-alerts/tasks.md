## 1. Detection

- [x] 1.1 Add `runsSince` and its tests: first sight, moved-on time, backwards clock, deleted job, outcomes (ok, error, delivery failed)
- [x] 1.2 Add `ScheduleWatcher`: lifecycle-aware timer, one `profile=all` request, baseline shared with the list, silence while Schedules is in front, summary above five
- [x] 1.3 Add watcher tests against `FakeHermesServer` and a fake notification service

## 2. Settings and mutes

- [x] 2.1 Add the scheduled task switch and the muted set to `NotificationSettings`, with load, change notification and dropping mutes of jobs that are gone
- [x] 2.2 Add the switch to the notifications dialog and the mute toggle to the job detail
- [x] 2.3 Add settings tests

## 3. Notifications and taps

- [x] 3.1 Add the scheduled task notification (title, fixed bodies, one per job) and the `jobId` on `NotificationTarget` and its payload, keeping old payloads valid
- [x] 3.2 Route a job target to Schedules' detail in the shell, and show the gone message for a deleted job
- [x] 3.3 Add notification and tap tests, including a launch-from-notification case

## 4. Finish

- [x] 4.1 Run `dart format`, `flutter analyze` and `flutter test`
- [x] 4.2 Check the run notification end to end: a run that changes `last_run_at` needs a model call, so it was not made against a live backend. The watcher, the notification wording, the mute and the tap were checked against the fake server and the fake notification service, and the field names come from the server's source
- [x] 4.3 Validate the change with `openspec validate`
