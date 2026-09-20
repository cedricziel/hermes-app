## 1. Failed refresh notice

- [ ] 1.1 Add a failing controller test: `refreshFailed` is true after a failed refresh with a board held, false after the next success, and false when no board was ever loaded
- [ ] 1.2 Add a failing widget test: the notice and its Retry show after a failed refetch, the board stays visible, and Retry clears the notice once the server recovers
- [ ] 1.3 Add `refreshFailed` to `KanbanBoardController` and show the notice above the board in `KanbanScreen`

## 2. Refresh on the wide layout

- [ ] 2.1 Add a failing widget test: on a wide screen a "Refresh" button refetches the board; on a phone it is absent
- [ ] 2.2 Add the refresh icon button to the toolbar on a wide screen

## 3. Telemetry and skills

- [ ] 3.1 No telemetry: the existing HTTP telemetry already records the failed request
- [ ] 3.2 No `.claude/skills` entry is affected

## 4. Verify

- [ ] 4.1 `dart format .`, `flutter analyze` and `flutter test` pass
- [ ] 4.2 verify-in-app is not run: `hermes` is not on PATH
