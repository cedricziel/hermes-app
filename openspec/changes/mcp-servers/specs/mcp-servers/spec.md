## Purpose

Hermes gives the agent extra tools through MCP servers that belong to a profile. This capability lets the user see the MCP servers of the active profile, turn them on and off, test them to see the tools they offer, and remove them, from the chat sidebar.

## ADDED Requirements

### Requirement: Sidebar entry

The system SHALL show an "MCP servers" entry in the chat sidebar, below Profiles and Bots, that opens the MCP servers screen. The entry SHALL NOT be shown when the chat has no MCP repository.

#### Scenario: Entry is shown

- **WHEN** the chat sidebar has an MCP repository
- **THEN** it shows an "MCP servers" entry that closes the drawer on narrow layouts and opens the MCP servers screen

#### Scenario: No repository

- **WHEN** the chat sidebar has no MCP repository
- **THEN** the "MCP servers" entry is not shown

### Requirement: Screen acts on the active profile

The system SHALL act on the sticky active profile of the dashboard and SHALL name that profile in the screen header. Every request the screen makes SHALL carry that profile as the `profile` query parameter. When the dashboard has no profiles route (404), the screen SHALL act without a profile parameter and SHALL NOT show a profile name. When the request for the active profile fails for any other reason, the screen SHALL NOT list or change any server: it shows "Could not load MCP servers" with a Retry button that asks for the profile again.

#### Scenario: Profile is named

- **WHEN** the dashboard reports the active profile "work"
- **THEN** the header shows "Profile: work" and the request for the servers carries `profile=work`

#### Scenario: Server without profiles

- **WHEN** the request for the active profile answers 404
- **THEN** the servers are requested without a `profile` parameter and no profile name is shown

#### Scenario: Profile lookup fails

- **WHEN** the request for the active profile fails with anything other than 404
- **THEN** no server list request is made, the screen shows "Could not load MCP servers" with a Retry button, and no switch or removal is possible until Retry has learned the profile

### Requirement: Server list

The system SHALL list the MCP servers of the active profile in the order the dashboard returns them. Each row SHALL show the server's name, its address (the URL for a remote server, otherwise the command with its arguments joined by spaces), a chip for its transport ("Remote" or "Command"), a chip for how it signs in when it has a way ("OAuth", "Header" or another value the dashboard reports, "No auth" for a remote server without one), an "Off" chip when the server is off, and a switch showing whether it is on. Rows without a non-empty string name SHALL be skipped. A progress indicator SHALL show while the list loads. The list SHALL state that changes apply from the next chat, not to one that is already running.

#### Scenario: Servers are listed

- **WHEN** the screen opens and the dashboard returns a remote server "grafana" with `auth: "oauth"` and a command server "filesystem" that is off
- **THEN** "grafana" shows its URL with the chips "Remote" and "OAuth" and a switch that is on, and "filesystem" shows its command line with the chips "Command" and "Off" and a switch that is off

#### Scenario: Rows that do not fit are skipped

- **WHEN** a server row has no non-empty string name
- **THEN** that row is left out

#### Scenario: A server without an enabled flag

- **WHEN** a row does not say whether it is enabled
- **THEN** it is treated as on, as Hermes does

#### Scenario: Secret values are never shown

- **WHEN** a server has environment values, which the dashboard sends redacted
- **THEN** no environment value, redacted or not, is shown in the list

#### Scenario: Loading fails

- **WHEN** loading the servers fails
- **THEN** the screen shows "Could not load MCP servers" with a Retry button that loads them again

#### Scenario: No servers

- **WHEN** the profile has no MCP servers
- **THEN** the screen shows "No MCP servers on" followed by the profile name in quotes (or "No MCP servers" without a profile name), with a short explanation of what MCP servers are for

### Requirement: Turning a server on or off

The system SHALL let the user turn a server on or off with its switch, using `PUT /api/mcp/servers/{name}/enabled` with the new value and the active profile. The switch SHALL show the new state once the dashboard has confirmed it and SHALL NOT show it before. While the request runs, that switch SHALL NOT accept another tap. When the request fails, the switch SHALL keep its previous state and the screen SHALL show "Could not turn {name} on" or "Could not turn {name} off".

#### Scenario: Turning a server off

- **WHEN** the user taps the switch of a server that is on
- **THEN** the dashboard is asked to set `enabled` to false, and once it answers OK the switch and the "Off" chip show the server as off

#### Scenario: The request fails

- **WHEN** the dashboard refuses or cannot be reached
- **THEN** the switch stays as it was and the screen shows "Could not turn {name} off"

#### Scenario: The server was removed elsewhere

- **WHEN** the dashboard answers 404 because the server no longer exists
- **THEN** the list is reloaded and the server is no longer shown

### Requirement: Server detail and testing

The system SHALL open a detail page when the user taps a row on a narrow layout, and SHALL show the same detail beside the list on a wide layout. The detail SHALL show the name, transport, address, how the server signs in, its on/off switch, a "Test connection" button and a "Remove" button. Testing SHALL call `POST /api/mcp/servers/{name}/test` with the active profile. A successful test SHALL show "Connected" with the counts of tools, prompts and resources, and a list of the tools with each tool's name, description and, when the dashboard sends it, the size of its schema in characters. A test that answers `ok: false` SHALL show "Could not connect" followed by the dashboard's error text. While a test runs, the button SHALL show progress and SHALL NOT accept another tap. The result SHALL stay available for the rest of the visit to the screen, and the row SHALL show the tool count once the server has been tested successfully.

#### Scenario: Successful test

- **WHEN** the user taps "Test connection" and the dashboard answers `ok: true` with 35 tools, 2 prompts and 0 resources
- **THEN** the detail shows "Connected", "35 tools · 2 prompts · 0 resources" and the tools, and the row shows "35 tools"

#### Scenario: Tool without a schema size

- **WHEN** a tool in the answer has no schema size
- **THEN** the tool is shown with its name and description and no size

#### Scenario: Failed test

- **WHEN** the dashboard answers `ok: false` with the error "connection refused"
- **THEN** the detail shows "Could not connect" and "connection refused", and no tool list

#### Scenario: The test request itself fails

- **WHEN** the request cannot be made or the dashboard answers with an error status other than 404
- **THEN** the detail shows "Could not test {name}" with a Retry button

#### Scenario: Server no longer exists

- **WHEN** the dashboard answers 404 to a test
- **THEN** the list is reloaded and the detail closes on a narrow layout, or shows the first server (or the empty state) on a wide layout

### Requirement: Sign in needed

The system SHALL show "Sign in needed" instead of the plain failure when a test of a server that signs in with OAuth answers `ok: false` with an error that begins with "OAuth authentication required". The row and the detail SHALL show it as a warning chip and banner ("Hermes has no OAuth token for this server yet, so it cannot list tools."). Signing in itself is not part of this capability.

#### Scenario: OAuth token missing

- **WHEN** the test of a server with `auth: "oauth"` answers `ok: false` with "OAuth authentication required — no token found."
- **THEN** the detail shows the "Sign in needed" banner instead of "Could not connect", and the row shows a "Sign in needed" chip

#### Scenario: Other failure on an OAuth server

- **WHEN** the test of an OAuth server answers `ok: false` with any other error
- **THEN** the detail shows "Could not connect" and that error

### Requirement: Removing a server

The system SHALL let the user remove a server from its detail. It SHALL first ask for confirmation, naming the server and saying that it is deleted from the profile and not just switched off. On confirmation it SHALL call `DELETE /api/mcp/servers/{name}` with the active profile. When the dashboard answers OK or 404, the server SHALL be gone from the list and the detail SHALL close (narrow layout) or move to another server (wide layout). When the request fails otherwise, the server SHALL stay and the screen SHALL show "Could not remove {name}".

#### Scenario: Confirmed removal

- **WHEN** the user taps Remove and confirms
- **THEN** the dashboard is asked to delete the server, and once it answers OK the server is no longer listed

#### Scenario: Cancelled removal

- **WHEN** the user taps Remove and cancels the confirmation
- **THEN** no request is made and the server stays

#### Scenario: Removal fails

- **WHEN** the dashboard cannot be reached or answers with an error other than 404
- **THEN** the server stays listed and the screen shows "Could not remove {name}"

### Requirement: Layout adapts to width

The system SHALL show the list and the selected server's detail side by side when the available width is 900 logical pixels or more, with the first server selected when none is, and SHALL show the list alone, with the detail as a separate page, below 900 logical pixels.

#### Scenario: Narrow layout

- **WHEN** the width is below 900 logical pixels
- **THEN** the list fills the screen and tapping a row opens the detail as its own page with a back button

#### Scenario: Wide layout

- **WHEN** the width is 900 logical pixels or more
- **THEN** the list is on the left and the detail of the selected server is on the right

### Requirement: Backend contract

The system SHALL read and change MCP servers only through the dashboard's routes: `GET /api/mcp/servers`, `PUT /api/mcp/servers/{name}/enabled`, `POST /api/mcp/servers/{name}/test` and `DELETE /api/mcp/servers/{name}`, each with the `profile` query parameter when a profile is known. The list response is an object with a `servers` array; each entry carries `name`, `transport`, `url`, `command`, `args`, `env` (redacted), `auth`, `enabled` and `tools`. A test response carries `ok`, and either `error` or `tools` (each with `name`, `description` and optionally `schema_chars`) with `prompts` and `resources` counts. Bodies SHALL be parsed leniently: missing or malformed fields fall back to defaults and malformed entries are skipped. The minimum Hermes version is 0.21.3.

#### Scenario: Malformed test answer

- **WHEN** a test answer has `ok: true` but a tool entry without a name
- **THEN** that tool is skipped and the others are shown

#### Scenario: Response is not the expected object

- **WHEN** the list answer is not an object with a `servers` array
- **THEN** it is treated as a failed load
