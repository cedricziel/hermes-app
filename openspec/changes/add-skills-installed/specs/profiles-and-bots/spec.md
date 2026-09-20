## ADDED Requirements

### Requirement: Skills entry in the sidebar

The system SHALL show a Skills entry in the chat sidebar beside Profiles and Bots when the chat has a dashboard connection, opening the Skills page (see the `skills` capability).

#### Scenario: Entry is shown

- **WHEN** the chat sidebar has a connection to the dashboard
- **THEN** it shows a Skills entry that opens the Skills page

#### Scenario: Entry is hidden

- **WHEN** the chat has no dashboard connection
- **THEN** the sidebar does not show a Skills entry
