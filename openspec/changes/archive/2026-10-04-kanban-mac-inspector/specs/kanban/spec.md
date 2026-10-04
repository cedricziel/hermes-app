## MODIFIED Requirements

### Requirement: Tasks open in a detail view

Tapping a task card (outside selection mode) SHALL open the task's detail, loaded with `GET /api/plugins/kanban/tasks/{id}` for the selected board. On Android, Windows and Linux the detail SHALL be a bottom sheet when the screen is narrower than 720 logical pixels and a dialog otherwise. On iPhone and iPad it SHALL be a sheet with medium and large detents when narrower than 720 logical pixels and a form sheet otherwise. On macOS it SHALL be the inspector beside the board (see "The Mac board shows the open task in an inspector"). It SHALL show the id and status, the title, the assignee, the priority and tenant, the description, the latest result, the parent dependencies, the results of child tasks, the comments with their authors and age, the attachments with their size, the plugin's warnings for the task, the runs, and the task history. A task that cannot be loaded SHALL show "Could not load the task" with a Retry button.

#### Scenario: Open a task

- **WHEN** the user taps a card on a phone-width screen
- **THEN** a sheet shows that task's title, description, dependencies and comments

#### Scenario: Open a task on a Mac

- **WHEN** the user clicks a card on macOS
- **THEN** the task opens in the inspector beside the board, and no sheet or dialog opens

## ADDED Requirements

### Requirement: The Mac board has a unified toolbar

On macOS the Kanban page SHALL show the 52-point Mac toolbar instead of the app bar: the title "Kanban" and a subtitle with the board's name, the profile filter ("all profiles" when none) and the number of tasks shown, then New Task (tooltip "New Task ⌘N"), a "Filter by profile" menu of the board's assignees, a "Switch board" menu, a separator, the inspector toggle (tooltip "Hide Inspector ⌥⌘I" or "Show Inspector ⌥⌘I", filled while the inspector is shown) and a "More" menu with the board's other actions. The floating New task button SHALL NOT be shown on macOS. While the Kanban page is in front, Command-N SHALL open the new task form. Selection mode keeps its own bar.

#### Scenario: Toolbar on a Mac

- **WHEN** the board "Default" with two tasks is shown on macOS with no profile filter
- **THEN** the toolbar reads "Kanban" and "Default · all profiles · 2 tasks", and there is no floating New task button

#### Scenario: New task from the keyboard

- **WHEN** the user presses Command-N on the Mac board
- **THEN** the new task form opens

### Requirement: The Mac board shows the open task in an inspector

On macOS the open task SHALL be shown in a 380-point inspector on the right of the board, holding the same detail and actions as the sheet. The card of the open task SHALL show as selected. The inspector toggle and Option-Command-I SHALL hide and show the inspector, and the app SHALL remember whether it is shown. Clicking a card while the inspector is hidden SHALL show it. A shown inspector with no open task SHALL say "No task selected". When the page is narrower than 760 points the inspector SHALL lie over the board from the right, with a shadow, and only while a task is open. Archiving or deleting the task SHALL close it in the inspector. On macOS the board SHALL always show columns, 232 points wide and 12 points apart, with 16 points of padding.

#### Scenario: Docked inspector

- **WHEN** the user clicks a card in a Mac window wider than 760 points
- **THEN** the task's detail is shown in a 380-point panel at the right edge and the card shows as selected

#### Scenario: Hide and show

- **WHEN** the user presses Option-Command-I, or clicks the inspector toggle, with the inspector shown
- **THEN** the inspector is hidden, it stays hidden after the app restarts, and clicking a card shows it again

#### Scenario: Compact window

- **WHEN** the user clicks a card while the Kanban page is 680 points wide
- **THEN** the inspector covers the right of the board below the toolbar, and the board keeps its width
