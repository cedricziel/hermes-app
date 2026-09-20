## 1. Backend access

- [x] 1.1 Add `schedule_models.dart`: `CronJob`, `CronJobState`, `CronRun`, `DeliveryTarget`, lenient parsers, and the pure sort and filter functions
- [x] 1.2 Add `HermesCronRepository` over `DefaultApi`: availability probe, list (with `profile`), get, pause, resume, trigger, delete, runs; errors mapped to one exception type
- [x] 1.3 Add the cron shapes to `test/real_backend_contract_test.dart`
- [x] 1.4 Add repository and model tests against `FakeHermesServer` (lenient rows, unknown state, bad times, 404 handling)

## 2. State

- [x] 2.1 Add `SchedulesController`: profile scope, filters, generation-guarded refresh, one-minute timer while active, optimistic pause and resume, run now, delete, selection
- [x] 2.2 Add controller tests: default scope, all profiles, active-profile failure not listed unscoped, overlapping refresh, revert on refusal, vanished job

## 3. Screens

- [x] 3.1 Add the list screen: rows, filter chips, empty and error states, refresh gesture, "New" left out until the editor change
- [x] 3.2 Add the job detail: status, actions, schedule, prompt, settings, run history with load more
- [x] 3.3 Add the wide two-pane layout and the pushed detail below 900 px
- [x] 3.4 Add screen tests for the list, detail and both layouts

## 4. Shell and chat

- [x] 4.1 Rework `AppShell` to build its destinations from the Kanban check and the cron check, keeping selection by id and dropping a page when its destination goes off
- [x] 4.2 Add `ChatOpenRequests` and teach `ChatScreen` to open a session on any profile, fetching it by id when it is not in the loaded page
- [x] 4.3 Add shell tests: no cron and no Kanban shows the bare chat, cron without Kanban, both, resume re-check, cron turning off while selected
- [x] 4.4 Add a chat test for opening a run outside the first page

## 5. Finish

- [x] 5.1 Run `dart format`, `flutter analyze` and `flutter test`
- [x] 5.2 Try it against the dev backend (`verify-in-app`): the Schedules tab shows in the running app and the cron contract test passes against it; the screens themselves were checked as rendered images, because the tab could not be clicked in the running app
- [x] 5.3 Update CLAUDE.md's architecture notes and validate the change with `openspec validate`
