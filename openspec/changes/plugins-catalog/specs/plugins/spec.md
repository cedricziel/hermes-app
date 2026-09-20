## ADDED Requirements

### Requirement: Plugins screen has an Installed and a Catalog tab

The system SHALL show the Plugins screen with two tabs, Installed and Catalog, Installed first and selected when the screen opens. Each tab SHALL keep its own state (list, search text, open details) while the user switches between them. The catalog SHALL NOT be requested until the Catalog tab has been opened for the first time.

#### Scenario: Opens on Installed

- **WHEN** the Plugins screen opens
- **THEN** the Installed tab is selected and no catalog request has been made

#### Scenario: Catalog opened

- **WHEN** the user selects the Catalog tab for the first time
- **THEN** the catalog is requested

#### Scenario: Tabs keep their state

- **WHEN** the user types a search in the Catalog tab, selects Installed, and selects Catalog again
- **THEN** the search text and the list are still there and the catalog is not requested again

### Requirement: Catalog is read from the plugins catalog route

The system SHALL load the catalog with `GET /api/dashboard/plugins/catalog` and read its `entries` list leniently: an entry without a non-empty string `name` SHALL be left out, and a missing or malformed field SHALL fall back to a default (empty text, false for `installed` and `update_available`, empty lists). An entry carries its name, description, maintainer, tier, the Hermes version it requires (`requires_hermes`), platforms, docs URL, pinned commit (`sha_short`, or the first seven characters of `sha`), the tools, hooks and middleware it provides and the environment variables it requires (all under `capabilities`), and its local state (`installed`, `update_available`). A response that is not an object with an `entries` list SHALL be read as an empty catalog. Pulling the list down SHALL load it again while keeping the rows visible.

#### Scenario: First load

- **WHEN** the Catalog tab is opened
- **THEN** a progress indicator shows while the catalog loads, then the entries appear in the order the server lists them

#### Scenario: Entries that do not fit are skipped

- **WHEN** an entry has no non-empty string `name`, or is not an object
- **THEN** it is left out and the others are shown

#### Scenario: Empty catalog

- **WHEN** the server returns no entries
- **THEN** the tab says "The catalog is empty"

#### Scenario: Loading fails

- **WHEN** loading the catalog fails
- **THEN** the tab shows "Could not load the catalog" with a Retry button that loads it again

#### Scenario: Server without the catalog

- **WHEN** the server answers 404
- **THEN** the tab says the catalog is not available on this server, with no Retry button

#### Scenario: Refresh keeps the rows

- **WHEN** the user pulls the list down
- **THEN** the catalog is loaded again and the rows stay visible until the new answer arrives, and a failed refresh tells the user "Could not refresh the catalog" and leaves the rows

### Requirement: Catalog rows and search

The system SHALL show each catalog entry as a row with its name, its maintainer, its description cut to two lines, its pinned commit as a short monospaced chip, an "Official" tag when its tier is `official`, and its state: an Install button when it is not installed, an "Installed" chip when it is, and an "Update available" chip in addition when the server says an update is available. A search field above the list SHALL narrow the rows to those whose name, description or maintainer contains the typed text, ignoring case, updating as the user types. A search that matches nothing SHALL say "No plugins match".

#### Scenario: Row content

- **WHEN** the catalog lists an official entry that is not installed
- **THEN** its row shows name, maintainer, description, commit chip, an "Official" tag and an Install button

#### Scenario: Installed entry

- **WHEN** an entry has `installed` true
- **THEN** its row shows an "Installed" chip instead of the Install button

#### Scenario: Update available

- **WHEN** an entry has `installed` and `update_available` true
- **THEN** its row shows "Installed" and "Update available" chips

#### Scenario: Search

- **WHEN** the user types "NETBOX" and an entry's name is `hermes-plugin-netbox`
- **THEN** that row stays and rows that match in neither name, description nor maintainer are hidden

#### Scenario: Nothing matches

- **WHEN** the search matches no entry
- **THEN** the list says "No plugins match"

### Requirement: Catalog entry details

The system SHALL open an entry's details when its row is tapped, as a bottom sheet below 900 logical pixels and as a pane beside the list at 900 or wider. The details SHALL show the entry's name, tier, maintainer, whole description, pinned commit, the Hermes version it requires (when it names one), its platforms (when it names any), the names of the tools, hooks and middleware it provides and of the environment variables it requires (each group only when non-empty), and a docs link when the entry has one. The docs link SHALL open in the system browser and SHALL only be offered for an `http` or `https` address.

#### Scenario: Declared capabilities

- **WHEN** an entry provides tools `netbox_query` and requires env `NETBOX_TOKEN`
- **THEN** its details list `netbox_query` under tools and `NETBOX_TOKEN` under environment variables

#### Scenario: Empty groups are hidden

- **WHEN** an entry declares no hooks
- **THEN** its details have no hooks group

#### Scenario: Docs link

- **WHEN** an entry's docs URL is an `https` address
- **THEN** its details offer a link that opens it in the system browser

#### Scenario: Other address schemes

- **WHEN** an entry's docs URL is not `http` or `https`
- **THEN** its details show no link

### Requirement: Installing a catalog entry

The system SHALL let the user install a catalog entry from its row or its details. The details SHALL carry an "Enable after install" switch, on by default. Installing SHALL call `POST /api/dashboard/agent-plugins/install` with the entry's name as `catalog_name`, an empty `identifier`, `enable` as the switch says, and `force` false. While it runs, that entry's Install control SHALL show progress and be disabled. The system SHALL NOT send the entry's repository or commit: the server resolves both.

#### Scenario: Install

- **WHEN** the user taps Install on an entry named `hermes-plugin-netbox` with the switch on
- **THEN** the install call is made with `catalog_name` "hermes-plugin-netbox", an empty `identifier`, `enable` true and `force` false

#### Scenario: Install without enabling

- **WHEN** the user turns the switch off and installs
- **THEN** the call carries `enable` false

#### Scenario: Install in progress

- **WHEN** an install for an entry is running
- **THEN** its Install control shows progress and cannot be tapped again

### Requirement: Install outcome

The system SHALL tell the user how an install ended, the same way for a catalog install and a Git URL install. On success it SHALL say "Installed <plugin_name>" using the name the server answers, and SHALL reload the Installed list and the catalog. When the answer lists `warnings`, it SHALL show them. When the answer lists `missing_env`, it SHALL show a dialog "Set these on the server" with each variable name and no value, and SHALL NOT offer to set them. When the server refuses, it SHALL show the server's `detail` when it is a non-empty string, otherwise "Could not install this plugin", and SHALL leave both lists as they were. When the app stops waiting before the server answers (the request times out), it SHALL NOT call that a failure: it SHALL tell the user "The server is still installing. Pull the list down in a moment to check." and SHALL reload both lists.

#### Scenario: Success

- **WHEN** the server answers `{"ok": true, "plugin_name": "netbox"}`
- **THEN** the user is told "Installed netbox" and the Installed list and the catalog are loaded again

#### Scenario: Warnings

- **WHEN** the answer has `warnings` of "Insecure URL scheme; prefer https:// or git@ for production installs."
- **THEN** that text is shown to the user

#### Scenario: Variables to set

- **WHEN** the answer has `missing_env` of `NETBOX_URL` and `NETBOX_TOKEN`
- **THEN** a dialog titled "Set these on the server" lists both names

#### Scenario: Refused

- **WHEN** the server answers 400 with `detail` "'x' is on the removed list."
- **THEN** the user is shown that text and neither list changes

#### Scenario: Slow install

- **WHEN** the install request times out before the server answers
- **THEN** the user is told "The server is still installing. Pull the list down in a moment to check." and both lists are loaded again

#### Scenario: Unreachable

- **WHEN** the install call fails without an answer
- **THEN** the user is told "Could not install this plugin"

### Requirement: Installing from a Git URL

The system SHALL offer "Install from Git URL" in the Catalog tab. It SHALL open a dialog with a field "Git URL or owner/repo", a notice "Unreviewed code. This plugin is not from the Hermes catalog. It runs on your server with full access.", a checkbox "I trust this source" that starts unticked, an "Enable after install" switch that starts on, and an Advanced section, collapsed, with an "Overwrite existing (force)" switch that starts off. The Install button SHALL stay disabled until the field holds non-blank text and the checkbox is ticked. Installing SHALL call `POST /api/dashboard/agent-plugins/install` with the trimmed text as `identifier`, no `catalog_name`, and `enable` and `force` as the switches say. The typed text SHALL NOT be logged, sent to telemetry, saved, or kept after the dialog closes. Its outcome SHALL be reported as the install outcome requirement says.

#### Scenario: Install is fenced

- **WHEN** the dialog opens
- **THEN** the notice is visible and Install is disabled

#### Scenario: Both conditions are needed

- **WHEN** the user types "someone/hermes-cool-plugin" but has not ticked the checkbox, or ticks it with the field blank
- **THEN** Install stays disabled

#### Scenario: Install

- **WHEN** the user types " someone/hermes-cool-plugin ", ticks the checkbox and taps Install
- **THEN** the call carries `identifier` "someone/hermes-cool-plugin", `enable` true and `force` false, and no `catalog_name`

#### Scenario: Force

- **WHEN** the user opens Advanced, turns on "Overwrite existing (force)" and installs
- **THEN** the call carries `force` true

#### Scenario: Server warnings

- **WHEN** the server answers success with a warning "Custom (unreviewed) source — not from the Hermes catalog."
- **THEN** the user is shown that warning after the install

#### Scenario: Dialog closes

- **WHEN** the install ends, whatever the outcome
- **THEN** the dialog is closed and the outcome is shown

### Requirement: Catalog and install backend contract

The system SHALL read the catalog and install only through `GET /api/dashboard/plugins/catalog` and `POST /api/dashboard/agent-plugins/install`, sent through the app's managed HTTP client, and SHALL require Hermes 0.21.1 or newer. The catalog answer is an object with `entries` (objects with `name`, `repo`, `sha`, `sha_short`, `description`, `maintainer`, `tier` of `official` or `community`, `requires_hermes`, `platforms`, `docs_url`, `capabilities` with `provides_tools`, `provides_hooks`, `provides_middleware` and `requires_env`, `installed`, `installed_sha`, `update_available` and `runtime_status`), `removed` and `generated_at`. The install body is `{ "identifier": <string>, "catalog_name": <string or absent>, "enable": <bool>, "force": <bool> }`. A successful install answers `{ "ok": true, "plugin_name": <string>, "warnings": [<string>], "missing_env": [<string>], "enabled": <bool> }`; a refusal answers an error status with a `detail` string. The app SHALL NOT show or send the server's install path.

#### Scenario: Older server

- **WHEN** the server does not have the catalog route and answers 404
- **THEN** the Catalog tab says the catalog is not available on this server

#### Scenario: Server without the auth gate

- **WHEN** the dashboard has no sign-in and expects the session token header
- **THEN** the catalog and install calls carry it like the app's other requests
