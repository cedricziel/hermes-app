# Kanban Specification

## Purpose

Describes how the app surfaces the Hermes dashboard's optional Kanban plugin: when the Kanban tab is offered, how the Chat and Kanban destinations are laid out on narrow and wide screens, how the board is displayed and filtered, how it stays current, and which backend routes it relies on. The board is read-only in the app.

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
- **THEN** the app requests the board and the board list, and selects the board flagged as current as the active one

#### Scenario: Board list request fails

- **WHEN** the board list cannot be loaded but the board itself can
- **THEN** the board is shown without a board switcher

#### Scenario: Sparse task row

- **WHEN** the server sends a task without optional fields
- **THEN** the task is shown with its id and title and without the optional details

### Requirement: The board is shown as status chips on a narrow screen

When the Kanban page is narrower than 720 logical pixels, the system SHALL show a horizontally scrolling row of status chips, each labelled with the capitalised status name and its task count, and below it the cards of the selected status only. The initially selected status SHALL be `running`; if the board has no such column the first column SHALL be shown instead. A status with no tasks SHALL show "No tasks here". Pulling down on the list SHALL refetch the board.

#### Scenario: Switch status

- **WHEN** the user taps the "Todo 1" chip on a phone-width screen
- **THEN** the cards of the todo status are shown and those of the previously selected status are hidden

#### Scenario: Empty status

- **WHEN** the selected status has no tasks
- **THEN** the list shows "No tasks here"

### Requirement: The board is shown as columns on a wide screen

When the Kanban page is 720 logical pixels wide or more, the system SHALL show every column side by side in a horizontally scrolling row of 260-pixel columns, each headed by its capitalised status name and task count, in the order the server returns them.

#### Scenario: Wide board

- **WHEN** the page is 720 logical pixels wide or more and the board has running and todo tasks
- **THEN** both the running and the todo cards are visible at once under headers such as "Running 1"

### Requirement: Task cards summarise a task

The system SHALL render each task as a card showing its id in a monospace font and its title, plus, when present, the assignee, a priority tag `P<n>` when the priority is above zero, the tenant, the comment count when above zero, the child progress as `done/total` when the task has children, and a warning tag with the warning count when above zero.

#### Scenario: Card with metadata

- **WHEN** a task has assignee "coder", priority 2, four comments and child progress 2 of 5
- **THEN** its card shows "coder", "P2", "4" and "2/5"

### Requirement: Search and assignee filters apply locally

The system SHALL provide a search field that keeps only tasks whose title, id or body contains the entered text, ignoring case and surrounding whitespace. It SHALL provide an assignee filter, shown when the board lists assignees, that keeps only tasks of the chosen assignee. Neither filter SHALL trigger a network request.

#### Scenario: Search narrows the cards

- **WHEN** the user enters "docs" in the search field
- **THEN** only tasks whose title, id or body contain "docs" remain visible and no new board request is made

### Requirement: Tenant, archived and board selection reload the board from the server

The system SHALL offer a tenant filter when the board lists tenants, an Archived toggle, and a board switcher when more than one board exists. Changing any of them SHALL discard the current board, reset the event cursor, refetch the board with the new parameters and reopen the event stream for the selected board.

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

While no board has been loaded the system SHALL show a progress indicator during loading. If the first load fails the system SHALL show "Could not load the board" with a Retry button. If the plugin answers 404 the system SHALL instead show "Kanban isn’t available" with the detail "The plugin was turned off on this server." and no Retry button, and SHALL NOT open the event stream. If a refresh fails while a board is already displayed, the system SHALL keep showing that board.

#### Scenario: Load fails, then succeeds

- **WHEN** the first board request fails with a server error and the user taps Retry after the server recovers
- **THEN** the board is loaded and the error message disappears

#### Scenario: Plugin removed after detection

- **WHEN** the board request answers 404
- **THEN** the page says the plugin was turned off on this server

#### Scenario: Refresh fails

- **WHEN** a refetch fails while the board is displayed
- **THEN** the previously loaded board stays visible
