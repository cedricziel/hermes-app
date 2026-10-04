## 1. Scope

- [x] 1.1 Failing tests in `test/schedules_controller_test.dart`: the scope is kept, the first request uses it, a widening for a saved job is not kept
- [x] 1.2 Persist the scope in `SchedulesController`; hand it preferences from `AppShell`

## 2. Widgets (catalog first)

- [x] 2.1 `SchedulesMacToolbar`, `MacJobList` and `MacScheduleDetail` with Widgetbook use cases (both scopes; list with and without profile chips, compact; detail ok, failed, delivery failed, paused, blocked, runs loading and failed)
- [x] 2.2 Let a job row's next run wrap under its status in a narrow column

## 3. Screen

- [x] 3.1 Failing widget tests in `test/schedules_mac_test.dart`, then wire the toolbar, the split and the detail on macOS
- [x] 3.2 macOS steps in `test/workflows/schedules_workflow_test.dart` at large, medium and compact sizes
- [x] 3.3 Check iOS and Android keep the app bar and filter chips
