## ADDED Requirements

### Requirement: Kanban action errors belong to a live caller

When a Kanban action fails while the screen that started it remains available, the system SHALL show the existing error message. If that screen has been disposed before the action fails, the system SHALL not try to show an error message from that screen.

The existing Kanban backend routes and response shapes SHALL remain unchanged. This UI lifetime change SHALL require no new route, RPC method, or minimum Hermes Agent version.

#### Scenario: Action fails while its caller remains available
- **WHEN** a Kanban action fails while its calling screen is mounted
- **THEN** the system shows the existing error message in a snackbar

#### Scenario: Action fails after its caller closes
- **WHEN** a Kanban action fails after its calling screen has been disposed
- **THEN** the system does not show a snackbar from that screen and does not raise a UI lifecycle error
