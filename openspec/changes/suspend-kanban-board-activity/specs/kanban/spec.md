## ADDED Requirements

### Requirement: Retained board work follows authenticated activity

A retained board bound to an authenticated activity signal SHALL stop its event stream, pending refetch timer and reconnect timer when activity is suspended. It SHALL send no new board reads, task moves, bulk updates or dispatcher commands while suspended. Work already sent SHALL NOT be rolled back, and its late responses or events SHALL NOT update the retained board or trigger additional work, even after activity resumes. Mutation attempts during suspension and mutation completions from before suspension SHALL report suspension rather than successful completion. Protected work SHALL honor the live activity value and any suspension delivered during synchronous listener notifications.

The board SHALL retain its loaded snapshot, chosen board, filters, shown column and task selection on suspension. On resumed activity it SHALL read the board list and board snapshot afresh, and reopen the event stream only while visible. Fresh board results SHALL retain selected ids still present on the board. Ordinary hidden-board event and refetch behavior SHALL remain unchanged when authenticated activity is allowed. Callers without an activity signal SHALL keep existing behavior.

This boundary SHALL use the existing Kanban plugin routes: `GET /api/plugins/kanban/boards`, `GET /api/plugins/kanban/board`, task updates, bulk updates and dispatcher commands, plus the existing event stream carrying `cursor` and `events`. Existing board/list response shapes and minimum Hermes Agent 0.21.1 support SHALL remain unchanged. Session-owner wiring, task detail and create forms are separate integration work.

#### Scenario: Board activity suspends

- **WHEN** authenticated activity is suspended while the retained board has an event stream and pending timers
- **THEN** the stream closes, timers stop, and new protected board actions issue no requests
- **AND** the loaded board and local selection remain available

#### Scenario: Work completes after suspension and resume

- **WHEN** an old board read, stream connection or bulk update completes after suspension and renewed activity
- **THEN** it does not replace fresh board state, clear selection, reopen an old stream or trigger a follow-up refresh

#### Scenario: Activity changes during a notification

- **WHEN** a listener suspends activity, including a nested suspension and immediate resume, before protected dispatch
- **THEN** the older operation does not issue that dispatch

#### Scenario: Board activity resumes

- **WHEN** authenticated activity resumes for the retained board
- **THEN** fresh board reads run with the existing board and filters
- **AND** selected task ids still on the board remain selected
- **AND** the event stream opens only if the board is visible

#### Scenario: Activity changes while an event subscription attaches

- **WHEN** an event stream's synchronous listen callback suspends and immediately resumes activity
- **THEN** the retired subscription is cancelled instead of becoming the retained board's subscription
- **AND** fresh resume reads can open the current event stream

#### Scenario: Visibility changes while an event subscription attaches

- **WHEN** an event stream's synchronous listen callback hides and immediately shows the board
- **THEN** the retired subscription and its callbacks cannot replace or close the current event stream
- **AND** an event refetch scheduled before the board was hidden retains its existing behavior
