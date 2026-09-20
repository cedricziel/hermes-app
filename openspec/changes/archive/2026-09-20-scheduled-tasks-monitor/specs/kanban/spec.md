## MODIFIED Requirements

### Requirement: Plugin detection gates the Kanban tab

The system SHALL offer the Kanban destination only while the server reports the Kanban plugin as on. It SHALL ask `GET /api/dashboard/plugins` and treat the plugin as on when the returned list contains an entry named `kanban`. Any failure to get a usable answer (network error, an error status, a body that is not a list, a server too old to have the route) SHALL count as off. While the plugin is off and no other destination is offered, the signed-in home screen SHALL be the chat alone, without any navigation bar or rail.

#### Scenario: Plugin is off

- **WHEN** the server lists no plugin named `kanban` and offers no other destination
- **THEN** the app shows only the chat and no navigation bar or navigation rail

#### Scenario: Plugin is on

- **WHEN** the server lists a plugin named `kanban`
- **THEN** the app shows a navigation with a Chat and a Kanban destination

#### Scenario: Detection fails

- **WHEN** the plugin list request fails or returns something that is not a list
- **THEN** the app treats Kanban as off and offers no Kanban destination

### Requirement: Chat and Kanban navigation adapts to screen width

While more than one destination is offered, the system SHALL show them (Chat, Kanban when the plugin is on, and any other) in a bottom navigation bar when the available width is below 900 logical pixels and in a side navigation rail with labels when it is 900 logical pixels or wider. Switching to Kanban SHALL NOT discard the chat: the chat stays mounted, keeping its state, while the Kanban page is shown.

#### Scenario: Phone-width layout

- **WHEN** the plugin is on and the width is below 900 logical pixels
- **THEN** a bottom navigation bar with Chat and Kanban is shown and no rail

#### Scenario: Wide layout

- **WHEN** the plugin is on and the width is 900 logical pixels or more
- **THEN** a navigation rail with Chat and Kanban is shown and no bottom bar
