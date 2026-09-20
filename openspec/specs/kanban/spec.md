# Kanban Specification

## Purpose

Describes how the app surfaces the Hermes dashboard's optional Kanban plugin: when the Kanban tab is offered, how the Chat and Kanban destinations are laid out on narrow and wide screens, how the board is displayed and filtered, how it stays current, and how tasks are opened, created, changed, commented on, triaged and dispatched, how several are changed at once, how boards, runs, logs and attachments are handled, and which backend routes it relies on.

## Requirements

### Requirement: Plugin detection gates the Kanban tab

The system SHALL offer the Kanban destination only while the server reports the Kanban plugin as on. It SHALL ask `GET /api/dashboard/plugins` and treat the plugin as on when the returned list contains an entry named `kanban`. Any failure to get a usable answer (network error, an error status, a body that is not a list, a server too old to have the route) SHALL count as off. While the plugin is off, the signed-in home screen SHALL be the chat alone, without any navigation bar or rail.

#### Scenario: Plugin is off

- **WHEN** the server lists no plugin named `kanban`
- **THEN** the app shows only the chat and no navigation bar or navigation rail

#### Scenario: Plugin is on

- **WHEN** the server lists a plugin named `kanban`
- **THEN** the app shows a navigation with a Chat and a Kanban destination

#### Scenario: Detection fails

- **WHEN** the plugin list request fails or returns something that is not a list
- **THEN** the app treats Kanban as off and offers no Kanban destination

### Requirement: Plugin state is re-checked on connect and on app resume

The system SHALL run the plugin check when the signed-in home screen is first shown and again every time the app returns to the foreground. When the result changes, the navigation SHALL update to match. When the plugin turns off while the Kanban destination is selected, the app SHALL return to Chat. When several checks overlap, only the answer of the most recently started check SHALL apply.

#### Scenario: Plugin is turned off while the app is in the background

- **WHEN** the plugin was on, is switched off on the server, and the app then resumes
- **THEN** the Kanban destination disappears and the chat is shown

#### Scenario: A slow older check finishes late

- **WHEN** an earlier check is still pending when a newer check completes, and the earlier check then reports the plugin as on
- **THEN** the earlier answer is ignored and the navigation follows the newer answer

### Requirement: Chat and Kanban navigation adapts to screen width

While the plugin is on, the system SHALL show the Chat and Kanban destinations in a bottom navigation bar when the available width is below 900 logical pixels and in a side navigation rail with labels when it is 900 logical pixels or wider. Switching to Kanban SHALL NOT discard the chat: the chat stays mounted, keeping its state, while the Kanban page is shown.

#### Scenario: Phone-width layout

- **WHEN** the plugin is on and the width is below 900 logical pixels
- **THEN** a bottom navigation bar with Chat and Kanban is shown and no rail

#### Scenario: Wide layout

- **WHEN** the plugin is on and the width is 900 logical pixels or more
- **THEN** a navigation rail with Chat and Kanban is shown and no bottom bar

### Requirement: The board loads only once its tab has been opened

The system SHALL NOT fetch the board or open the event stream until the user has selected the Kanban destination for the first time.

#### Scenario: Kanban tab never opened

- **WHEN** the plugin is on and the user stays on Chat
- **THEN** no board request and no event stream connection is made

### Requirement: Board data is read from the plugin's REST routes

The system SHALL load the board with `GET /api/plugins/kanban/board`, passing the selected `board` slug, the `tenant` filter and `include_archived` as query parameters. It SHALL load the list of boards with `GET /api/plugins/kanban/boards`. Response bodies SHALL be parsed leniently: missing or malformed fields fall back to defaults (empty text, zero counts, status `todo`) and non-object task or column entries are skipped. A board response carries columns (each a name and a list of tasks), the tenants and assignees seen on the board, and a `latest_event_id`. A task carries an id, a title, a status and optionally a body, assignee, priority, tenant, timestamps, latest summary, comment count, parent and child link counts, child progress (done and total) and warnings (count and highest severity).

#### Scenario: Initial load

- **WHEN** the Kanban page opens
- **THEN** the app requests the board list first, selects the remembered board (or, when there is none or it no longer exists, the board flagged as current), and then requests that board

#### Scenario: Board list request fails

- **WHEN** the board list cannot be loaded but the board itself can
- **THEN** the board is shown without a board switcher

#### Scenario: Sparse task row

- **WHEN** the server sends a task without optional fields
- **THEN** the task is shown with its id and title and without the optional details

### Requirement: The board is shown as status chips on a narrow screen

When the Kanban page is narrower than 720 logical pixels, the system SHALL show a horizontally scrolling row of status chips, each labelled with the capitalised status name and its task count, and below it the cards of the selected status only. The initially selected status SHALL be `running`; if the board has no such column the first column SHALL be shown instead. The chip row SHALL scroll so the selected chip is in view. A status with no tasks SHALL show "No tasks here". Pulling down on the list SHALL refetch the board.

#### Scenario: Switch status

- **WHEN** the user taps the "Todo 1" chip on a phone-width screen
- **THEN** the cards of the todo status are shown and those of the previously selected status are hidden

#### Scenario: Empty status

- **WHEN** the selected status has no tasks
- **THEN** the list shows "No tasks here"

### Requirement: The board is shown as columns on a wide screen

When the Kanban page is 720 logical pixels wide or more, the system SHALL show every column side by side in a horizontally scrolling row of 260-pixel columns, each headed by its capitalised status name and task count, in the order the server returns them. The toolbar SHALL also show a refresh button with the tooltip "Refresh" that refetches the board.

#### Scenario: Wide board

- **WHEN** the page is 720 logical pixels wide or more and the board has running and todo tasks
- **THEN** both the running and the todo cards are visible at once under headers such as "Running 1"

#### Scenario: Manual refresh on a wide screen

- **WHEN** the page is 720 logical pixels wide or more and the user taps the refresh button after a task was added on the server
- **THEN** the board is refetched and the new task appears

### Requirement: Task cards summarise a task

The system SHALL render each task as a card showing its id in a monospace font and its title, plus, when present, the assignee, a priority tag `P<n>` when the priority is above zero, the tenant, the comment count when above zero, the child progress as `done/total` when the task has children, and a warning icon with the warning count when above zero.

#### Scenario: Card with metadata

- **WHEN** a task has assignee "coder", priority 2, four comments and child progress 2 of 5
- **THEN** its card shows "coder", "P2", "4" and "2/5"

### Requirement: Search and assignee filters apply locally

The system SHALL provide a search field that keeps only tasks whose title, id or body contains the entered text, ignoring case and surrounding whitespace. The search field, the filters and the Archived toggle SHALL sit above the board, the filters in a single horizontally scrolling row. It SHALL provide an assignee filter, shown when the board lists assignees, that keeps only tasks of the chosen assignee. Neither filter SHALL trigger a network request.

#### Scenario: Search narrows the cards

- **WHEN** the user enters "docs" in the search field
- **THEN** only tasks whose title, id or body contain "docs" remain visible and no new board request is made

### Requirement: Tenant, archived and board selection reload the board from the server

The system SHALL offer a tenant filter when the board lists tenants, an Archived toggle, and a board switcher. Changing any of them SHALL discard the current board, reset the event cursor, refetch the board with the new parameters and reopen the event stream for the selected board.

#### Scenario: Include archived tasks

- **WHEN** the user turns on the Archived toggle
- **THEN** the board is fetched again with `include_archived=true`

#### Scenario: Switch board

- **WHEN** the user selects another board in the switcher
- **THEN** the board is fetched with that board's slug and the event stream is reopened for it

### Requirement: The board is kept live through an event stream

After the first successful board load the system SHALL open a WebSocket to `/api/plugins/kanban/events`, passing `since` (the newest event id known) and the `board` slug as query parameters, authenticated like the chat socket: with a single-use ticket when the dashboard requires sign-in, otherwise with the dashboard's session token. Each text frame is a JSON object with a `cursor` and a list of `events`. The system SHALL advance its cursor from every frame and SHALL refetch the whole board once, after a 300 millisecond pause, for each burst of frames that carry at least one event. A frame without events, or one that is not a JSON object, SHALL NOT cause a refetch. The initial cursor SHALL be the `latest_event_id` of the loaded board.

#### Scenario: Events arrive

- **WHEN** two frames with events arrive in quick succession
- **THEN** the board is refetched once and the new state is shown

#### Scenario: Frame without events

- **WHEN** a frame with an empty event list arrives
- **THEN** the cursor advances but the board is not refetched

### Requirement: The event stream reconnects with backoff

When the event stream ends or fails, the system SHALL reconnect, resuming from the last cursor. The delay before the first retry SHALL be one second and SHALL double per consecutive failed attempt up to a maximum of 30 seconds; receiving a frame resets the delay. The app bar SHALL show a status dot whose tooltip reads "Live" while the stream is connected (green) and "Reconnecting…" otherwise (grey).

#### Scenario: Stream drops

- **WHEN** the socket closes after the cursor reached 9
- **THEN** the app reconnects with `since=9` and the indicator shows "Live" again once connected

### Requirement: Board failures are reported without losing the shown board

While no board has been loaded the system SHALL show a progress indicator during loading. If the first load fails the system SHALL show "Could not load the board" with a Retry button. If the plugin answers 404 the system SHALL instead show "Kanban isn’t available" with the detail "The plugin was turned off on this server." and no Retry button, and SHALL NOT open the event stream. If a refresh fails while a board is already displayed, the system SHALL keep showing that board and SHALL show a notice above it reading "Could not refresh. Showing the last board." with a Retry button that refetches the board. The notice SHALL NOT block the board, and SHALL disappear once a later refetch succeeds.

#### Scenario: Load fails, then succeeds

- **WHEN** the first board request fails with a server error and the user taps Retry after the server recovers
- **THEN** the board is loaded and the error message disappears

#### Scenario: Plugin removed after detection

- **WHEN** the board request answers 404
- **THEN** the page says the plugin was turned off on this server

#### Scenario: Refresh fails

- **WHEN** a refetch fails while the board is displayed
- **THEN** the previously loaded board stays visible
- **AND** the notice "Could not refresh. Showing the last board." is shown with a Retry button

#### Scenario: Refresh recovers

- **WHEN** the notice is shown and the user taps Retry after the server recovers
- **THEN** the board is updated and the notice disappears

### Requirement: Tasks open in a detail view

Tapping a task card (outside selection mode) SHALL open the task's detail, loaded with `GET /api/plugins/kanban/tasks/{id}` for the selected board. The detail SHALL be a bottom sheet when the screen is narrower than 720 logical pixels and a dialog otherwise. It SHALL show the id and status, the title, the assignee, the priority and tenant, the description, the latest result, the parent dependencies, the results of child tasks, the comments with their authors and age, the attachments with their size, the plugin's warnings for the task, the runs, and the task history. A task that cannot be loaded SHALL show "Could not load the task" with a Retry button.

#### Scenario: Open a task

- **WHEN** the user taps a card on a phone-width screen
- **THEN** a sheet shows that task's title, description, dependencies and comments

### Requirement: Tasks are created from a form

The system SHALL offer a "New task" action on the board that opens a form with a title, a description, an assignee (defaulting to "Auto (triage picks)", with the profiles and assignees the board knows as options), a priority of Normal or P1 to P3, and a start of Triage (the default) or Todo. Creating SHALL call `POST /api/plugins/kanban/tasks` with the selected board and, when a tenant filter is active, that tenant. A task without a title SHALL NOT be sent. When the plugin answers with a dispatcher warning, the system SHALL show it. When the plugin refuses the task, the form SHALL stay open and show the plugin's reason.

#### Scenario: Create a triage task

- **WHEN** the user enters a title, chooses P2 and creates the task
- **THEN** the request carries the title, priority 2 and `triage: true`, the form closes and the board refreshes

#### Scenario: Missing title

- **WHEN** the user creates a task with an empty title
- **THEN** no request is sent and the form stays open

### Requirement: Tasks can be changed from their detail

The system SHALL let the user edit a task's title and description, change its assignee (from the assignees the board knows, or nobody) and its priority (Normal or P1 to P3), and move it to a status of Triage, Todo, Scheduled, Ready, Blocked, Review or Done, all through `PATCH /api/plugins/kanban/tasks/{id}`, sending only the fields that changed. `running` SHALL NOT be offered, since the plugin reserves it for the dispatcher. Moving to Blocked SHALL first ask for an optional reason, and moving to Done SHALL first ask for an optional result. Cancelling either question SHALL NOT change the task. Complete and Block SHALL also be offered as direct actions on tasks that are not done or not blocked. A title that is empty after trimming SHALL NOT be saved. When the plugin refuses a change, the system SHALL show the plugin's `detail` text and SHALL NOT report the change to the board.

#### Scenario: Block with a reason

- **WHEN** the user taps Block and enters "Waiting on design"
- **THEN** the task is patched with status `blocked` and that reason, and the board refreshes

#### Scenario: Plugin refuses a move

- **WHEN** the plugin answers a move to Ready with a conflict whose detail says a parent is still open
- **THEN** that text is shown to the user and the board is not refreshed for it

### Requirement: Comments and dependencies

The system SHALL let the user add a comment to a task with `POST /api/plugins/kanban/tasks/{id}/comments`, clearing the input once it is accepted, add a parent dependency by task id with `POST /api/plugins/kanban/links`, and remove one with `DELETE /api/plugins/kanban/links` passing `parent_id` and `child_id`. An empty comment SHALL NOT be sent.

#### Scenario: Add a comment

- **WHEN** the user types "Ship it" and sends
- **THEN** the comment is posted and the input is cleared

### Requirement: Tasks can be archived or deleted

The system SHALL let the user archive a task (as a one-task bulk archive) or delete it (`DELETE /api/plugins/kanban/tasks/{id}`), each after a confirmation, and close the detail afterwards without loading the task again.

#### Scenario: Delete a task

- **WHEN** the user confirms deleting a task
- **THEN** the task is deleted, the detail closes and the board refreshes

### Requirement: Cards move between columns by dragging

On a screen wide enough to show columns, the system SHALL let the user long-press a card and drag it onto another column, which changes the task's status like a move from the detail. Columns that are not user-settable (`running`, `archived`) SHALL NOT accept a drop. A refused move SHALL show the plugin's reason.

#### Scenario: Drag to Blocked

- **WHEN** the user drags a Todo card onto the Blocked column
- **THEN** the task is patched with status `blocked`

### Requirement: Several tasks can be changed at once

The system SHALL offer a selection mode, entered by long-pressing a card on a narrow screen or from the board menu ("Select tasks"). In selection mode tapping a card selects or deselects it instead of opening it, the app bar shows the number selected, and a bar offers Move, Assign, Priority and Archive (after a confirmation), applied with `POST /api/plugins/kanban/tasks/bulk`. When the plugin refuses some of the tasks, the system SHALL name how many failed and why, and SHALL keep exactly those tasks selected so the change can be retried; otherwise selection mode ends. Selected tasks that leave the board SHALL be dropped from the selection.

#### Scenario: Partial failure

- **WHEN** a bulk archive of two tasks is refused for one of them
- **THEN** a message says 1 of 2 could not be changed, and only the refused task stays selected

### Requirement: Triage helpers, reclaim, dispatcher and orchestration

For a task in Triage the system SHALL offer Decompose and Specify (`POST .../decompose` and `.../specify`). These run a language model on the server and report a refusal in the response body rather than as an HTTP error, so the system SHALL show the reason of a declined helper and SHALL only refresh the board when the helper succeeded, saying how many tasks a decomposition produced. For a running task the system SHALL offer Reclaim (`POST .../reclaim`) after a confirmation. The board menu SHALL offer "Run dispatcher now" (`POST /api/plugins/kanban/dispatch`) and "Orchestration…", a dialog for the server's auto-decompose and child-promotion switches and its orchestrator profile and default assignee (`GET` and `PUT /api/plugins/kanban/orchestration`). Saving orchestration SHALL send only the settings that changed.

#### Scenario: Helper declines

- **WHEN** Specify is answered with `ok: false` and a reason
- **THEN** the reason is shown and the task is left as it was

#### Scenario: Toggle one setting

- **WHEN** the user turns off auto-decompose and saves
- **THEN** the request carries only `auto_decompose: false`

### Requirement: Boards can be managed

The board menu SHALL list the boards and a "Manage boards…" entry that opens a list of boards with their slug and task count. From it the user SHALL be able to open a board, create one (the slug derived from the name by lowercasing and replacing runs of characters other than letters and digits with a hyphen; a name that leaves no slug is refused locally), rename one, and archive or delete one after a confirmation (archive and delete are offered only while more than one board exists). The plugin's refusal text SHALL be shown, including the first message of a validation error. The chosen board SHALL be remembered between launches; on start the app SHALL open the remembered board when it still exists, otherwise the board the server flags as current. When the selected board no longer exists after the list is reloaded, the app SHALL fall back to the current board. Exporting and importing boards are not offered: the plugin does those with paths on the server.

#### Scenario: Remembered board

- **WHEN** the user picked the "ops" board in an earlier session and it still exists
- **THEN** the board opens on "ops"

#### Scenario: Name without letters or digits

- **WHEN** the user creates a board named with characters that leave an empty slug
- **THEN** no request is sent and the user is asked to use letters or numbers

### Requirement: Runs, worker log and attachments

The task detail SHALL list the task's runs, each with its worker profile and outcome, offer Terminate for a run that is still active (`POST /api/plugins/kanban/runs/{id}/terminate`, after a confirmation), and open the tail of the worker log (`GET .../tasks/{id}/log`, at most 20000 bytes), saying so when no worker has run or the log was cut. It SHALL list the task's attachments with file name and size and allow removing one after a confirmation (`DELETE .../attachments/{id}`). It SHALL list the plugin's warnings for the task under "Needs attention". Uploading and downloading attachments, cost estimates, home-channel subscriptions and the fleet-wide active-worker list are not offered.

#### Scenario: Terminate an active run

- **WHEN** the user confirms Terminate on a running run
- **THEN** the plugin is asked to terminate that run and the detail reloads

### Requirement: Kanban works against Hermes Agent 0.21.1 and later

The system SHALL rely only on routes of the Kanban plugin bundled with Hermes Agent 0.21.1 or later. The contract test (`test/real_backend_contract_test.dart`) SHALL check plugin detection, the board and board list, a task's lifecycle, refusal messages, the orchestration settings and the live event stream against a real dashboard.

#### Scenario: Contract check against a real dashboard

- **WHEN** the contract test runs with `HERMES_DEV_URL` pointing at a Hermes Agent dashboard
- **THEN** the plugin is reported as on, a task can be created, commented on, blocked and deleted, and the event stream announces a new task
