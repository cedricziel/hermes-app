## MODIFIED Requirements

### Requirement: The board loads only once its tab has been opened

The system SHALL NOT fetch the board or open the event stream until the user has selected the Kanban destination. The board and its event stream SHALL exist only while the Kanban destination is selected: leaving it for Chat SHALL close the event stream, and selecting it again SHALL load the board afresh. When the plugin goes off and on again, the board SHALL NOT be loaded until the user selects the Kanban destination again.

#### Scenario: Kanban tab never opened

- **WHEN** the plugin is on and the user stays on Chat
- **THEN** no board request and no event stream connection is made

#### Scenario: Leaving the Kanban tab

- **WHEN** the user selects Chat while the board is shown
- **THEN** the event stream is closed
- **AND WHEN** the user selects Kanban again
- **THEN** the board is loaded again

#### Scenario: Plugin turned off and on

- **WHEN** the user has opened Kanban and the plugin then goes off and on again
- **THEN** Chat is shown and no board request and no event stream connection is made until the user selects Kanban
