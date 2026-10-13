## ADDED Requirements

### Requirement: Guarded desktop detail history

Desktop Back SHALL use the current route's dismissal guard. A successful Back from an explicitly eligible workers page SHALL make that page available to Forward. Rejected Back SHALL retain the route and history. Editors, completed actions, transient dialogs, removals, replacements, and external navigation unwinds SHALL NOT become Forward targets. Forward SHALL be disabled while a transient modal covers the main route. The history SHALL retain at most 32 targets.

#### Scenario: Workers round trip
- **WHEN** the user opens workers for a board, goes Back, then Forward
- **THEN** the app opens a new workers page for that board after confirming the plugin and board are available
- **AND** reconstruction performs reads and never stops a worker

#### Scenario: Guard rejects Back
- **WHEN** the current page refuses Back
- **THEN** its route and Forward history remain intact

#### Scenario: Branch changes
- **WHEN** a new page or a different Chat, Kanban, or Schedules section is selected after Back
- **THEN** the old Forward branch is cleared and section selection adds no history

#### Scenario: External navigation commits
- **WHEN** a guarded external request unwinds pages and commits its newest target
- **THEN** the unwind creates no Forward entries and the old Forward branch is cleared

### Requirement: Desktop history availability and input

macOS SHALL offer View > Forward with Cmd+] alongside guarded Back. Desktop mouse Back/Forward buttons SHALL use the same actions. Ordinary pointer scrolling and trackpad scrolling SHALL remain scrolling. A key auxiliary conversation window or native windowless state SHALL disable main-window history commands. A focus transition SHALL cancel pending Forward resolution even if the main window becomes key again before validation completes. Auth, lock, and Handoff overlays SHALL block history commands. Explicit session departure or changed verified owner SHALL clear history; expiry for the same verified owner SHALL pause it.

#### Scenario: Covered session
- **WHEN** App Lock, login, or a Handoff gate covers the main app
- **THEN** neither history command changes the main route

#### Scenario: Cancel external navigation
- **WHEN** an external request waiting behind a protected eligible page is cancelled
- **THEN** history suppression ends even while a framework dismissal guard remains pending, later user Back can record Forward, and the cancelled request never commits. Cancellation SHALL NOT promise to undo dismissal effects already requested from the navigation framework

#### Scenario: Focus changes during validation
- **WHEN** the user moves focus to an auxiliary window while Forward validates its target
- **THEN** validation completion does not push a main-window page, even after focus returns

#### Scenario: Scroll
- **WHEN** a pointer emits a horizontal or vertical scroll event
- **THEN** history does not navigate

#### Scenario: Missing target
- **WHEN** Forward finds the Kanban plugin unavailable or the board deleted
- **THEN** the stale target is dropped and the current route stays intact

The backend contract remains GET /api/dashboard/plugins (enabled plugin list), GET /api/plugins/kanban/boards (`boards` rows with `slug`), and GET /api/plugins/kanban/workers/active (`workers` rows). No new routes, response shapes, RPC methods, or minimum Hermes version are required.
