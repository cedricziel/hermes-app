# mcp-catalog Specification

## Purpose
Hermes keeps an approved catalog of MCP servers and can sign in to servers that use OAuth. This capability lets the user browse that catalog, install an entry on the active profile with the credentials it declares, and sign in to an OAuth server, all from the app.
## Requirements
### Requirement: Catalog screen

The system SHALL offer a Catalog screen, opened from the "Add" button of the MCP servers screen and from the button of its empty state, acting on the active profile and naming it in the header as "Installing into: {profile}". It SHALL load the catalog with `GET /api/mcp/catalog` and the active profile, show a progress indicator while loading, and list every entry with its name, its description, a chip for its transport ("Remote" or "Command"), a chip for its sign-in kind ("API key", "OAuth" or "No auth"), a "Builds locally" chip when Hermes has to build it on the server, and an "Installed" chip when it is installed. Entries without a non-empty string name SHALL be skipped. When the answer carries diagnostics, the screen SHALL say that some catalog entries could not be read. When loading fails, or the active profile cannot be learned, the screen SHALL show "Could not load the catalog" with a Retry button and SHALL NOT install anything.

#### Scenario: Catalog is listed

- **WHEN** the Catalog screen opens and Hermes returns a remote OAuth entry "asana" that is installed and a command entry "buildkite" that needs a build
- **THEN** "asana" shows "Remote", "OAuth" and "Installed", and "buildkite" shows "Command" and "Builds locally"

#### Scenario: Entries that do not fit are skipped

- **WHEN** an entry has no non-empty string name
- **THEN** that entry is left out

#### Scenario: Loading fails

- **WHEN** the request fails, or the active profile cannot be learned for a reason other than the server not having the profiles route
- **THEN** the screen shows "Could not load the catalog" with a Retry button

#### Scenario: Entry point

- **WHEN** the user taps "Add" on the MCP servers screen, or the button of the empty state
- **THEN** the Catalog screen opens for the same profile

### Requirement: Search and filters

The system SHALL filter the loaded catalog on the device by a search text and by one of the filters All, Remote, Command and OAuth. The search SHALL match the entry's name and description, ignoring case. The filters SHALL match the entry's transport (Remote or Command) or its sign-in kind (OAuth). The search field SHALL show the number of entries it searches ("Search 65 servers").

#### Scenario: Searching

- **WHEN** the user types "graf"
- **THEN** only entries whose name or description contains "graf", ignoring case, are listed

#### Scenario: Filtering

- **WHEN** the user selects the OAuth filter
- **THEN** only entries whose sign-in kind is OAuth are listed

#### Scenario: Nothing matches

- **WHEN** the search and filter match no entry
- **THEN** the list says "No servers match" and offers to clear the search

### Requirement: Opening an entry

The system SHALL open the install sheet when the user taps an entry that is not installed, as a bottom sheet on layouts narrower than 900 logical pixels and in the right-hand pane on wider ones. It SHALL open the installed server's detail from `mcp-servers` when the user taps an installed entry.

#### Scenario: Not installed

- **WHEN** the user taps an entry that is not installed
- **THEN** the install sheet for that entry opens

#### Scenario: Installed

- **WHEN** the user taps an installed entry
- **THEN** the detail of that server opens and no install sheet is shown

### Requirement: The install sheet shows what will run

The install sheet SHALL show the entry's name, description and source, and a "What Hermes will run" block with the transport, and for a remote entry its URL, and for a command entry its command and arguments, and the sign-in kind. When the entry has build steps, the block SHALL also show the repository and reference it is fetched from and each build step, and the sheet SHALL say that the build runs on the Hermes server. The Install button SHALL NOT be enabled until every credential the entry marks as required has a non-empty value.

#### Scenario: Remote entry

- **WHEN** the sheet opens for a remote entry with the URL `https://mcp.airtable.com/mcp` and API key sign-in
- **THEN** it shows "remote (http)", that URL and "API key", and no command or build steps

#### Scenario: Entry with a build

- **WHEN** the sheet opens for an entry that is cloned and built
- **THEN** it shows the command, the arguments, the repository, the reference and each build step, and says the build runs on the server

#### Scenario: Required credential missing

- **WHEN** an entry declares a required credential and its field is empty
- **THEN** the Install button is disabled

### Requirement: Credentials are write-only

The system SHALL ask only for the credentials the entry declares (`required_env`), one obscured field per credential labelled with its name and prompt, and SHALL send only those in the install request. It SHALL NOT store a credential on the device, write it to any log, or include it in telemetry, and SHALL clear the fields after the request finishes, whether it succeeded or not. It SHALL say that the value is saved on the Hermes server and never shown again. Empty optional credentials SHALL NOT be sent.

#### Scenario: Only declared credentials are sent

- **WHEN** the user installs an entry that declares `AIRTABLE_API_KEY`
- **THEN** the request body contains `env` with that key alone

#### Scenario: Optional credential left empty

- **WHEN** an optional credential's field is empty
- **THEN** it is not in the request

#### Scenario: Fields are cleared

- **WHEN** an install request finishes with success or failure
- **THEN** the credential fields are empty

### Requirement: Installing an entry

The system SHALL install an entry with `POST /api/mcp/catalog/install`, sending the entry's `name`, the credentials as `env`, `enable` (from the "Turn on after installing" switch, on by default) and the active profile. While the request runs, the Install button SHALL show progress and SHALL NOT accept another tap. On success the entry SHALL show as installed, the MCP servers list SHALL show the new server, and the screen SHALL say "Installed {name}" with a way to open its server. When Hermes refuses the request, the sheet SHALL stay open, keep the entry as not installed and show Hermes' own reason.

#### Scenario: Installing without a build

- **WHEN** the user taps Install for an entry with no build steps and Hermes answers OK with `background: false`
- **THEN** the entry shows as installed and "Installed {name}" is shown

#### Scenario: Turning on

- **WHEN** the user switches "Turn on after installing" off
- **THEN** the request carries `enable: false` and the installed server shows as off

#### Scenario: Hermes refuses

- **WHEN** Hermes answers 400 with a reason such as "does not declare environment variable(s)"
- **THEN** the sheet stays open and shows that reason

#### Scenario: Unknown entry

- **WHEN** Hermes answers 404 because the entry no longer exists
- **THEN** the catalog is reloaded and the sheet closes

#### Scenario: The request fails

- **WHEN** the request cannot be made or Hermes answers with a server error and no reason
- **THEN** the sheet stays open and shows "Could not install {name}"

### Requirement: Installs that build on the server

The system SHALL treat an install answer with `background: true` and an `action` name as running, and SHALL poll `GET /api/actions/{action}/status` until it reports that the process is no longer running. While it runs, the sheet SHALL say "Building on your server…" and SHALL NOT allow a second install of the same entry. When the process ends with exit code 0, the entry SHALL show as installed as for a synchronous install. When it ends with another exit code, the sheet SHALL say that the build failed and show the last lines of the log, and the entry SHALL stay not installed. Closing the sheet SHALL NOT stop the build; when the screen loads again, an entry that finished building SHALL show its true state.

#### Scenario: Build finishes

- **WHEN** the status reports `running: false` and `exit_code: 0`
- **THEN** the entry shows as installed and the polling stops

#### Scenario: Build fails

- **WHEN** the status reports `running: false` and `exit_code: 1` with log lines
- **THEN** the sheet says the build failed and shows the last lines, and the entry is not installed

#### Scenario: Leaving while it builds

- **WHEN** the user closes the sheet while the build runs
- **THEN** polling stops, no request is made to cancel the build, and the next load of the catalog shows the entry's state as Hermes reports it

### Requirement: Signing in to an OAuth server

The system SHALL offer a "Sign in" button on the detail of a server whose sign-in kind is OAuth, and on its "Sign in needed" banner. Tapping it SHALL call `POST /api/mcp/servers/{name}/auth` with the active profile, open the returned `authorization_url` in the system browser, and show a "Waiting for you to approve" screen with a way to open the browser again and a Cancel button. While that screen is open, the system SHALL poll `GET /api/mcp/oauth/flows/{flow_id}` about every two seconds. When the flow reports `approved`, the screen SHALL close and the server SHALL be tested so that its tools show. When the flow reports `error`, the screen SHALL show Hermes' error text with a Try again button. Cancel SHALL call `DELETE /api/mcp/oauth/flows/{flow_id}` and close the screen; leaving the screen by any other way SHALL cancel the flow the same way. The authorization URL SHALL NOT be logged or sent in telemetry.

#### Scenario: Sign-in succeeds

- **WHEN** the user taps "Sign in", approves in the browser, and the flow reports `approved`
- **THEN** the waiting screen closes, the server is tested, and its tools are shown

#### Scenario: Sign-in fails

- **WHEN** the flow reports `error` with "Authorization failed"
- **THEN** the screen shows that text and a Try again button

#### Scenario: Flow expired

- **WHEN** polling the flow answers 404 because Hermes has dropped it
- **THEN** the screen says "The sign-in expired" with a Try again button

#### Scenario: Cancelling

- **WHEN** the user taps Cancel
- **THEN** the flow is deleted on Hermes and the waiting screen closes

#### Scenario: Browser cannot be opened

- **WHEN** the system browser cannot be launched
- **THEN** the screen still shows the waiting state, with the authorization URL shown to copy and the button to try opening it again

### Requirement: Sign-in refusals

The system SHALL turn Hermes' refusals of a sign-in request into a message on the server's detail and SHALL NOT open the waiting screen. A 409 SHALL show "A sign-in for {name} is already in progress on your server. Try again in a few minutes.". A 429 SHALL show "Too many sign-ins are in progress on your server. Try again in a few minutes.". A 400 SHALL show Hermes' reason (for example that a command server signs in with environment keys, not OAuth). A 404 SHALL reload the server list. Any other failure SHALL show "Could not start signing in to {name}".

#### Scenario: Already in progress

- **WHEN** Hermes answers 409
- **THEN** the detail shows the already-in-progress message and no waiting screen opens

#### Scenario: Not an OAuth server

- **WHEN** Hermes answers 400 with "stdio servers authenticate via env keys, not OAuth"
- **THEN** the detail shows that reason

### Requirement: Backend contract

The system SHALL use `GET /api/mcp/catalog`, `POST /api/mcp/catalog/install`, `GET /api/actions/{name}/status`, `POST /api/mcp/servers/{name}/auth` and `GET` and `DELETE /api/mcp/oauth/flows/{flow_id}`, each with the `profile` query parameter where the route takes one. A catalog answer is an object with `entries` and `diagnostics`; an entry carries `name`, `description`, `source`, `transport` (`http` or `stdio`), `auth_type` (`api_key`, `oauth` or `none`), `required_env` (each with `name`, `prompt` and `required`), `command`, `args`, `url`, `install_url`, `install_ref`, `bootstrap`, `needs_install`, `installed` and `enabled`. An install answer carries `ok`, `name`, `background` and, when `background` is true, `action`. An action status carries `running`, `exit_code` and `lines`. A sign-in answer and a flow status carry `flow_id`, `server_name`, `status` (`starting`, `authorization_required`, `approved` or `error`), `authorization_url` and `error`. Bodies SHALL be parsed leniently: missing or malformed fields fall back to defaults and malformed entries are skipped. The minimum Hermes version is 0.21.3.

#### Scenario: Missing fields

- **WHEN** an entry has no `required_env` and no `bootstrap`
- **THEN** it is shown as needing no credentials and no build steps

#### Scenario: Unexpected flow status

- **WHEN** a flow reports a status the app does not know
- **THEN** the app keeps polling until it reports `approved` or `error`, or the user leaves the screen

