## Why

On a Mac the board opens a task in a form sheet over the board, so the board is hidden while a task is read or edited, and the board's actions sit in a Material app bar and a floating button. The Mac native concept puts them in a unified toolbar and shows the open task in an inspector docked on the right, as Mac apps do.

## What Changes

- On macOS the Kanban page gets the 52 pt Mac toolbar: the title "Kanban", a subtitle with the board's name, the profile filter and the task count, and buttons for New Task (⌘N), Filter by profile, Switch board, Inspector (⌥⌘I) and a "More" menu. The floating New task button goes away on macOS.
- On macOS a card click opens the task in a 380 pt inspector on the right of the board, instead of a sheet. It holds the same task panel as the sheet (status, edits, model, comments, attachments, runs, archive and delete). The open task's card shows as selected.
- The inspector toggle (toolbar button or ⌥⌘I) hides and shows the panel, and the choice is remembered. Clicking a card while it is hidden shows it.
- Below 760 pt of page width the inspector lies over the board from the right, with a shadow, and only once a task is open.
- On macOS the board always shows columns, 232 pt wide, 12 pt apart, with 16 pt padding.
- The task panel can be shown outside a route: archiving or deleting the task closes the inspector instead of popping a route.

### Non-goals

- iPhone, iPad, Android, Windows and Linux are unchanged.
- No menu bar items; the native menu bar is a separate stream. ⌥⌘I and ⌘N are bound on the page until the menu bar's command registry exists.
- No resizable inspector.

### Security and privacy

None. The same requests go to the same routes; the remembered visibility is one local boolean.

### Telemetry

None.

## Capabilities

### Modified Capabilities

- `kanban`: "Tasks open in a detail view" covers the Apple sheets and the Mac inspector; new requirements for the Mac toolbar and the Mac inspector.

## Impact

`lib/src/kanban/kanban_screen.dart`, `kanban_inspector.dart`, `widgets/kanban_mac_toolbar.dart`, `widgets/kanban_inspector_layout.dart`, `widgets/kanban_task_panel.dart`, `widgets/kanban_board_menu.dart`. Builds on the shared Mac toolbar (`lib/src/macos/mac_toolbar.dart`, #389).
