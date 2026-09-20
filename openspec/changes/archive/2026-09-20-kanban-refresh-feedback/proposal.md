## Why

When a refetch of the Kanban board fails, `KanbanBoardController` keeps the old board and stores the error, but the screen never shows it. The board can look current while it is stale, with only a grey "Reconnecting…" dot as a hint. Separately, pull-to-refresh exists only in the narrow list; the wide column layout has no manual refresh at all. Fixes #98.

## What Changes

- While a board is shown and the last refetch failed, the page shows a non-blocking notice above the board: "Could not refresh. Showing the last board." with a Retry action. The notice disappears when a later refetch succeeds, and Retry refetches the board.
- On a wide screen the toolbar gets a refresh icon button (tooltip "Refresh") that refetches the board.
- The controller exposes whether the last refresh failed while a board is held.

## Impact

- Code: `lib/src/kanban/kanban_board_controller.dart`, `lib/src/kanban/kanban_screen.dart`.
- Tests: `test/kanban_board_controller_test.dart`, `test/kanban_screen_test.dart`.
- Specs: `openspec/specs/kanban/spec.md` (two requirements modified).
- No new route, no change to the generated client, no dependency, no platform or native change.

## Non-goals

- Showing the server's error text or status code in the notice.
- Distinguishing a failed refresh from a plugin that was turned off after the board loaded; a 404 during a refresh shows the same notice.
- Retrying automatically or with backoff; the event stream reconnect logic is unchanged.
- A refresh button on the narrow layout, which keeps pull-to-refresh.
- Reporting failures of task actions (they already use snackbars) or of the board list.

## Security and privacy impact

None. The notice is a fixed string and carries no data from the error. No token, storage or network behaviour changes.

## Telemetry emitted

None. The existing HTTP telemetry already records the failed request; nothing new is added.
