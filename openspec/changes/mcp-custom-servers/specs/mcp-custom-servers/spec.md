## Purpose

Some MCP servers are not in Hermes' catalog. This capability lets the user add a remote or command server to the active profile by hand, confirms what a command server will run before it is saved, and lets the user edit the whole list of servers as JSON.

## ADDED Requirements

### Requirement: Add menu

The system SHALL turn the "Add" button of the MCP servers screen into a menu with "Browse the catalog" and "Add a custom server", and SHALL make the second button of the empty state open the custom form. Both SHALL act on the active profile.

#### Scenario: Menu

- **WHEN** the user taps "Add" on the MCP servers screen
- **THEN** a menu offers "Browse the catalog" and "Add a custom server"

#### Scenario: Empty state

- **WHEN** the profile has no servers and the user taps "Add a custom server"
- **THEN** the custom form opens for the same profile

### Requirement: Add form for a remote server

The system SHALL offer an "Add server" form with a switch between "Remote (URL)" and "Command". For a remote server it SHALL ask for a name and a URL, and for how it signs in: None, Bearer token or OAuth. A bearer token field SHALL appear only for "Bearer token", SHALL be obscured, and SHALL be required for it. The Add button SHALL stay disabled until the name is not empty after trimming, the URL is an `http` or `https` address, and the token is present when required. Adding SHALL call `POST /api/mcp/servers` with `name`, `url`, `auth` (`none`, `header` for a bearer token, or `oauth`), `bearer_token` for a bearer token only, and the active profile. The form SHALL say that the token is kept on the Hermes server and never shown again.

#### Scenario: Adding a remote server with no sign-in

- **WHEN** the user enters a name and an `https` URL, leaves sign-in on None and taps Add
- **THEN** the request carries `name`, `url` and `auth: none` and no `bearer_token`

#### Scenario: Bearer token

- **WHEN** the user chooses Bearer token
- **THEN** the token field appears, Add stays disabled until it has a value, and the request carries `auth: header` and the token

#### Scenario: OAuth

- **WHEN** the user chooses OAuth and adds the server
- **THEN** the request carries `auth: oauth`, and the new server's detail opens showing its "Sign in" button

#### Scenario: Invalid URL

- **WHEN** the URL is not an `http` or `https` address
- **THEN** the field shows "Enter an http or https address" and Add is disabled

### Requirement: Add form for a command server

For a command server the form SHALL ask for a name, a command, the arguments and the environment variables. Arguments SHALL be entered one per line in a multi-line field, and empty lines SHALL be dropped, so that no argument needs quoting. Environment variables SHALL be entered as rows of a name and an obscured value, with a way to add and remove rows. A name SHALL match `[A-Za-z_][A-Za-z0-9_]*` and SHALL be unique in the form. Add SHALL stay disabled until the server name and the command are not empty after trimming and every environment row is valid. Adding SHALL call `POST /api/mcp/servers` with `name`, `command`, `args` and `env` (omitting empty ones) and the active profile, and SHALL NOT send `url`, `auth` or a token.

#### Scenario: Arguments

- **WHEN** the user enters the lines `-y`, `@modelcontextprotocol/server-filesystem` and `/srv/my notes`
- **THEN** the request carries those three arguments, the last one intact with its space

#### Scenario: Environment row is invalid

- **WHEN** a row's name is `1BAD` or repeats another row's name
- **THEN** the row shows the reason and Add is disabled

### Requirement: Review before a command server is saved

The system SHALL show a review step before saving any command server, whether from the form or the JSON editor. It SHALL say that the server is a program that runs on the Hermes host with that machine's permissions every time a chat uses it, SHALL show the exact command and each argument on its own line, and the names of the environment variables without their values, and SHALL offer "Add and run on server" (or "Save and run on server" in the JSON editor) and "Back to edit". No request that saves the server SHALL be made until the user confirms. The step SHALL be a bottom sheet on layouts narrower than 900 logical pixels and a centred dialog on wider ones. Remote servers SHALL NOT have this step.

#### Scenario: Confirming

- **WHEN** the user taps Add on a command server and then "Add and run on server"
- **THEN** the request is made, and not before

#### Scenario: Going back

- **WHEN** the user taps "Back to edit"
- **THEN** no request is made and the form keeps everything the user entered

#### Scenario: Values are hidden

- **WHEN** the server has an environment variable `NOTES_TOKEN`
- **THEN** the review shows `NOTES_TOKEN` and no value

### Requirement: Adding succeeds or is refused

While the add request runs, the Add button SHALL show progress and SHALL NOT accept another tap. On success the form SHALL close, the servers list SHALL show the new server, and its detail SHALL open on a narrow layout or be selected on a wide one. When Hermes answers 409, the name field SHALL show "A server with this name already exists". When it answers 400, the form SHALL stay open and show Hermes' reason, including when Hermes rejects the command as suspicious. When the request fails otherwise, the form SHALL stay open and show "Could not add {name}". Whatever the result, the token and environment value fields SHALL be cleared once the request has finished.

#### Scenario: Duplicate name

- **WHEN** Hermes answers 409
- **THEN** the name field shows "A server with this name already exists" and the form stays open

#### Scenario: Refused as suspicious

- **WHEN** Hermes answers 400 with "rejected: suspicious command/args configuration"
- **THEN** the form stays open and shows that reason

#### Scenario: Secrets are cleared

- **WHEN** an add request finishes with failure
- **THEN** the token and environment value fields are empty and the rest of the form is unchanged

### Requirement: JSON editor loads the full map

The system SHALL offer "Edit as JSON" in the overflow menu of the MCP servers screen. It SHALL load the active profile's whole `mcp_servers` map from `GET /api/config` with the profile, and show it as formatted JSON in a monospace editor, because the server list route leaves out fields such as headers, OAuth settings and timeouts. The screen SHALL name the profile and say that the text holds the profile's real configuration, including secrets such as environment values and bearer tokens. A progress indicator SHALL show while loading, and a failure SHALL show "Could not load the configuration" with a Retry button. A profile with no servers SHALL show `{}`.

#### Scenario: Loading

- **WHEN** the editor opens and the configuration has two servers
- **THEN** both are shown as formatted JSON keyed by name, with every field Hermes stored, and the profile is named

#### Scenario: Loading fails

- **WHEN** the request fails
- **THEN** the screen shows "Could not load the configuration" with a Retry button and no editor

### Requirement: JSON editor checks before it saves

The Save button SHALL stay disabled while the text is unchanged. When the text is not valid JSON, or is not an object whose values are all objects, the screen SHALL show the error with its line number and SHALL NOT allow saving. The screen SHALL warn, above the editor, that saving replaces all servers of the profile. When saving would remove servers that were present when the editor loaded, the system SHALL ask for confirmation first, naming them and saying that they are deleted and not just switched off. When the saved map contains a command server that is new or whose command, arguments or environment changed (a name added or removed, or a value changed), the review step SHALL be shown for those servers, listing each of them.

#### Scenario: Invalid JSON

- **WHEN** the text has a missing comma on line 6
- **THEN** the screen shows the error with line 6 and Save is disabled

#### Scenario: Not an object of objects

- **WHEN** the text is `[]`, or a server's value is a string
- **THEN** the screen says each server must be an object and Save is disabled

#### Scenario: Removing servers

- **WHEN** the user deletes the entry "grafana" and taps Save
- **THEN** a confirmation names "grafana", says it is deleted and not just switched off, and no request is made until the user confirms

#### Scenario: New command server

- **WHEN** the user adds a command server in the text and taps Save
- **THEN** the review step lists that server's command, arguments and environment names before any request is made

#### Scenario: Unchanged command server

- **WHEN** the user changes only a remote server's URL
- **THEN** no review step is shown

### Requirement: JSON editor saves the whole map

Saving SHALL call `PUT /api/mcp/servers` with the parsed map as `servers` and the active profile. While it runs, the Save button SHALL show progress and SHALL NOT accept another tap. On success the screen SHALL close and the servers list SHALL reload. When Hermes answers 400, the screen SHALL stay open with the text unchanged and show its problems as a list, splitting Hermes' reason at each "; ". When the request fails otherwise, the screen SHALL stay open and show "Could not save". Leaving the screen with unsaved changes SHALL ask whether to discard them.

#### Scenario: Saved

- **WHEN** Hermes answers OK
- **THEN** the editor closes and the servers list shows the new map

#### Scenario: Refused

- **WHEN** Hermes answers 400 with `Server 'filesystem': expected an object; Server 'x': …`
- **THEN** the screen shows each problem on its own line and the text is unchanged

#### Scenario: Leaving with changes

- **WHEN** the user goes back with unsaved changes
- **THEN** the screen asks whether to discard them

### Requirement: Secrets stay off the device and out of telemetry

The system SHALL NOT store a bearer token, an environment value or the JSON editor's text on the device outside the running screen, SHALL NOT write any of them to a log, and SHALL NOT include them, or the request bodies that carry them, in telemetry. Leaving a form or the editor SHALL discard what it holds.

#### Scenario: Telemetry

- **WHEN** a server with a bearer token or an environment value is added, or the JSON is saved
- **THEN** no span or log record contains the token, a value, or the request body

### Requirement: Backend contract

The system SHALL use `POST /api/mcp/servers`, `PUT /api/mcp/servers` and `GET /api/config` with the `profile` query parameter. An add answers the server's summary as the list does. An add for a remote server SHALL NOT send arguments or environment values, and an add for a command server SHALL NOT send an authentication mode or a token, because Hermes refuses both with 400. A replace body is `{"servers": {...}, "profile": ...}` and answers `{"ok": true}` or 400 with the problems joined by "; ". The config answer is an object whose `mcp_servers` is a map of objects, missing when there are none, and Hermes has expanded `${VAR}` references in it, so a bearer token shows in plain text; a value saved back unchanged keeps its reference in Hermes' file. The minimum Hermes version is 0.21.3.

#### Scenario: No `mcp_servers` key

- **WHEN** the config answer has no `mcp_servers`
- **THEN** the editor shows `{}`

#### Scenario: Remote server body

- **WHEN** a remote server is added
- **THEN** the body has no `command` and no non-empty `args` or `env`
