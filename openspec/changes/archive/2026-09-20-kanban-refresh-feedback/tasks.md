## 1. Failed refresh notice

- [x] 1.1 Add a failing controller test: `refreshFailed` is true after a failed refresh with a board held, false after the next success, and false when no board was ever loaded
- [x] 1.2 Add a failing widget test: the notice and its Retry show after a failed refetch, the board stays visible, and Retry clears the notice once the server recovers
- [x] 1.3 Add `refreshFailed` to `KanbanBoardController` and show the notice above the board in `KanbanScreen`

## 2. Refresh on the wide layout

- [x] 2.1 Add a failing widget test: on a wide screen a "Refresh" button refetches the board; on a phone it is absent
- [x] 2.2 Add the refresh icon button to the toolbar on a wide screen

## 3. Telemetry and skills

- [x] 3.1 No telemetry: the existing HTTP telemetry already records the failed request
- [x] 3.2 No `.claude/skills` entry is affected

## 4. Verify

- [x] 4.1 `dart format .`, `flutter analyze` and `flutter test` pass
- [x] 4.2 verify-in-app was not run: `hermes` is not on PATH (widget tests cover the behaviour)
