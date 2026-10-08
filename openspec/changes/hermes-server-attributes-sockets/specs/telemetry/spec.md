## ADDED Requirements

### Requirement: Socket and feature telemetry carries the connected server's attributes

When telemetry is enabled the system SHALL add the `hermes.*` attributes of a connection, as defined in "HTTP and connection telemetry carries the connected server's attributes", to:

- every span of the chat gateway sockets (`/api/ws`) opened on that connection: the upgrade span, request spans and event spans;
- every span of the Kanban events socket (`/api/plugins/kanban/events`) opened on that connection: the upgrade span and event spans;
- the app events logged by the gateway transport (`gateway.reconnect`, `gateway.turn_settled`, `gateway.event_unmapped`), the Kanban board (`kanban.events.reconnect`), the plugin, catalog and provider screens (`plugins.*`) and the skills hub (`skills.job`) while they work against that connection.

A socket keeps the attributes of the connection it was opened on for as long as it lives, including across its own reconnects. Attributes a span or log record sets itself SHALL take precedence. Breadcrumbs of these events SHALL NOT carry `hermes.*` attributes. Events of the watch bridge and the token store SHALL NOT carry them. While telemetry is disabled no attribute is computed and the sockets behave as before.

No backend change is needed: the attributes come from the `GET /api/status` answer read when the app connects; the sockets and their frames are unchanged.

#### Scenario: Gateway spans are described

- **WHEN** the app is connected to a server reporting `version` = `0.14.2` and `install_id` = `inst_42`, and the user submits a prompt
- **THEN** the `/api/ws` upgrade span, the `prompt.submit send` span and the `message.complete receive` span carry `hermes.version` = `0.14.2` and `hermes.install_id` = `inst_42`

#### Scenario: Kanban spans are described

- **WHEN** the Kanban tab opens its events socket on that connection and receives a `claimed` event
- **THEN** the upgrade span and the `claimed receive` span carry the server's `hermes.*` attributes

#### Scenario: Gateway reconnect event is described

- **WHEN** the gateway socket drops while a reply runs and the transport reconnects
- **THEN** the `gateway.reconnect` log record carries the server's `hermes.*` attributes
- **AND** its breadcrumb does not

#### Scenario: Plugin action is described

- **WHEN** the user enables a plugin
- **THEN** the `plugins.enable.*` log record carries the server's `hermes.*` attributes

#### Scenario: Socket outlives a switch

- **WHEN** a gateway socket opened on server A is still open after the user connects to server B, and receives an event
- **THEN** that event's span carries server A's attributes
- **AND** sockets opened after connecting to B carry server B's

#### Scenario: Watch bridge stays undescribed

- **WHEN** the watch bridge logs an event
- **THEN** the record has no `hermes.*` attribute

### Requirement: Each socket links its messages to its own upgrade

Each gateway and Kanban socket SHALL link its request and event spans to the upgrade span of that same socket. When two sockets are open at once, for example the chat screen's and the shell's gateway sockets, neither SHALL link its messages to the other's upgrade span.

#### Scenario: Two gateway sockets

- **WHEN** the chat screen and the shell each open a gateway socket, and each then sends a request
- **THEN** each request span is linked to the upgrade span of the socket it was sent on
