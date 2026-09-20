## MODIFIED Requirements

### Requirement: The board is shown as columns on a wide screen

When the Kanban page is 720 logical pixels wide or more, the system SHALL show every column side by side in a horizontally scrolling row of 260-pixel columns, each headed by its capitalised status name and task count, in the order the server returns them. The toolbar SHALL also show a refresh button with the tooltip "Refresh" that refetches the board.

#### Scenario: Wide board

- **WHEN** the page is 720 logical pixels wide or more and the board has running and todo tasks
- **THEN** both the running and the todo cards are visible at once under headers such as "Running 1"

#### Scenario: Manual refresh on a wide screen

- **WHEN** the page is 720 logical pixels wide or more and the user taps the refresh button after a task was added on the server
- **THEN** the board is refetched and the new task appears

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
