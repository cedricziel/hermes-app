## MODIFIED Requirements

### Requirement: The board loads only once its tab has been opened

The system SHALL NOT fetch the board or open the event stream until the user has selected the Kanban destination for the first time. When the plugin goes off, the system SHALL forget that the tab was opened: after the plugin comes back on, the board SHALL NOT be loaded until the user selects the Kanban destination again. While the plugin stays on, the board SHALL stay alive when the user switches to Chat, so that its search text, filters and selection are still there when the user returns.

#### Scenario: Kanban tab never opened

- **WHEN** the plugin is on and the user stays on Chat
- **THEN** no board request and no event stream connection is made

#### Scenario: Plugin turned off and on

- **WHEN** the user has opened Kanban and the plugin then goes off and on again
- **THEN** Chat is shown and no board request and no event stream connection is made until the user selects Kanban

#### Scenario: Visit to Chat and back

- **WHEN** the user types a search in the board, selects Chat, and then selects Kanban again
- **THEN** the same board is shown with the search still in place
