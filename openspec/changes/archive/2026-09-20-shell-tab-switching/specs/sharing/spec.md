## MODIFIED Requirements

### Requirement: Shared items wait until the chat can take them

The system SHALL keep shared items pending, in the order received, until the chat screen takes them, including through server setup and sign-in. Taking the items SHALL hand them over exactly once and clear them. When the chat takes items that arrive while the Kanban destination is selected, the system SHALL select the Chat destination so the user sees them.

#### Scenario: Shared before sign-in

- **WHEN** the user shares to Hermes while signed out
- **THEN** the items stay pending and appear in the composer once the chat screen opens

#### Scenario: Taken once

- **WHEN** the chat screen has taken the pending items
- **THEN** a second take returns nothing

#### Scenario: Shared while Kanban is shown

- **WHEN** the user shares text or a file to Hermes while the Kanban destination is selected
- **THEN** the Chat destination is selected
- **AND** the text is in the composer, or the file is attached
