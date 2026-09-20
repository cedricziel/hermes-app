# plugins Specification

## Purpose
Describes how the app lets the user manage the plugins of the connected Hermes dashboard: how the Plugins screen is reached, how installed plugins are listed and described, how one is enabled, disabled, updated, removed and hidden, and which backend routes this relies on. Later changes add the catalog, installing and the provider pickers to this same capability.
## Requirements
### Requirement: Plugins entry in the chat sidebar

The system SHALL show a Plugins entry in the footer of the chat sidebar, after Profiles and Bots, that opens the Plugins screen. The entry SHALL be shown only while the app is connected to a dashboard.

#### Scenario: Entry point

- **WHEN** the chat sidebar is shown for a connected dashboard
- **THEN** it lists Plugins after Profiles and Bots, and tapping it opens the Plugins screen

#### Scenario: No dashboard

- **WHEN** the chat runs without a dashboard connection (the demo chat)
- **THEN** the sidebar has no Plugins entry

### Requirement: Installed plugins are read from the plugins hub

The system SHALL load the installed plugins with `GET /api/dashboard/plugins/hub` when the Plugins screen opens, when the user pulls to refresh, and after every change the user makes on the screen. It SHALL read the `plugins` list of the response leniently: a row without a non-empty string `name` SHALL be left out, and a missing or malformed field SHALL fall back to a default (empty text for the version and description, false for every flag, no login command, no removed reason). A response that is not an object with a `plugins` list SHALL be read as no plugins. Only that list SHALL be shown: dashboard-only extensions, which the server reports apart from it (`orphan_dashboard_plugins`), SHALL NOT be listed.

The screen SHALL keep the list it already shows while a refresh is running, and SHALL show a progress indicator only for the first load.

#### Scenario: First load

- **WHEN** the Plugins screen opens
- **THEN** a progress indicator shows while the list loads, then each installed plugin appears

#### Scenario: Empty list

- **WHEN** the server reports no plugins
- **THEN** the screen says "No plugins installed"

#### Scenario: Rows that do not fit are skipped

- **WHEN** a row has no non-empty string `name`, or is not an object
- **THEN** that row is left out and the others are shown

#### Scenario: Dashboard-only extensions are not listed

- **WHEN** the response also lists plugins under `orphan_dashboard_plugins`
- **THEN** they do not appear on the screen

#### Scenario: Pull to refresh

- **WHEN** the user pulls the list down
- **THEN** the list is loaded again and the rows stay visible until the new answer arrives

#### Scenario: Loading fails

- **WHEN** loading the list fails
- **THEN** the screen shows "Could not load plugins" with a Retry button that loads it again

#### Scenario: Refresh fails after a first load

- **WHEN** a refresh fails while the list is showing
- **THEN** the list stays and the user is told "Could not refresh plugins"

#### Scenario: Server without the route

- **WHEN** the server answers 404 to the hub request
- **THEN** the screen says the plugin list is not available on this server, with no Retry button

### Requirement: Installed plugin rows

The system SHALL show each installed plugin as a row with its name, its version (when it has one), its description (when it has one, cut to two lines in the list; the details show all of it) and a status chip taken from `runtime_status`: `enabled` reads "Enabled", `disabled` reads "Disabled", `inactive` reads "Inactive". Any other or missing value SHALL read "Inactive". A plugin whose `auth_required` is true SHALL carry a "Needs login" tag. A plugin whose `removed_reason` is a non-empty string SHALL carry a "Removed" tag with that reason. A plugin whose `source` is `bundled` SHALL carry a "Bundled" tag. The rows SHALL appear in the order the server lists them.

#### Scenario: Status chips

- **WHEN** the server reports plugins with `runtime_status` of `enabled`, `disabled` and `inactive`
- **THEN** their rows read "Enabled", "Disabled" and "Inactive"

#### Scenario: Unknown status

- **WHEN** a plugin's `runtime_status` is missing or a value the app does not know
- **THEN** its chip reads "Inactive"

#### Scenario: Needs login

- **WHEN** a plugin has `auth_required` set to true
- **THEN** its row shows a "Needs login" tag

#### Scenario: Removed from the catalog

- **WHEN** a plugin has a non-empty `removed_reason`
- **THEN** its row shows a "Removed" tag with that reason

#### Scenario: Long description

- **WHEN** a plugin's description is longer than two lines
- **THEN** its row shows the first two lines followed by an ellipsis, and its details show the whole description

#### Scenario: Bundled plugin

- **WHEN** a plugin's `source` is `bundled`
- **THEN** its row shows a "Bundled" tag

### Requirement: Plugin details adapt to screen width

The system SHALL open a plugin's details when its row is tapped: as a bottom sheet when the available width is below 900 logical pixels, and as a pane beside the list when it is 900 logical pixels or wider, where the selected row stays highlighted. The details SHALL show the plugin's name, version, description and source, and the actions this capability defines. When a reload no longer lists the selected plugin, the details SHALL close.

#### Scenario: Phone-width layout

- **WHEN** the width is below 900 logical pixels and the user taps a row
- **THEN** a bottom sheet with the plugin's details opens over the list

#### Scenario: Wide layout

- **WHEN** the width is 900 logical pixels or more and the user taps a row
- **THEN** the details appear in a pane beside the list and the row is highlighted, and no sheet opens

#### Scenario: Selected plugin is gone

- **WHEN** a reload no longer lists the plugin whose details are open
- **THEN** the details close

### Requirement: Enabling and disabling a plugin

The system SHALL let the user turn a plugin on or off from its details with a switch that reflects `runtime_status`: on for `enabled`, off otherwise. Turning it on SHALL call `POST /api/dashboard/agent-plugins/{name}/enable` and turning it off SHALL call `POST /api/dashboard/agent-plugins/{name}/disable`. The details SHALL say the change applies to new chats. While the call runs, the switch SHALL be disabled. When it succeeds, the list SHALL be reloaded and the switch SHALL show the state the server now reports. When the server refuses, the switch SHALL stay as it was and the user SHALL be told why: with the server's `detail` when it is a non-empty string, otherwise "Could not update this plugin".

#### Scenario: Turning a plugin on

- **WHEN** the user turns on a disabled plugin
- **THEN** the enable call is made for that plugin, the list is reloaded, and the plugin then shows as Enabled

#### Scenario: Turning a plugin off

- **WHEN** the user turns off an enabled plugin
- **THEN** the disable call is made for that plugin, the list is reloaded, and the plugin then shows as Disabled

#### Scenario: Server refuses

- **WHEN** the server answers 400 with a `detail`
- **THEN** the switch stays as it was and the user is shown that `detail`

#### Scenario: Server unreachable

- **WHEN** the call fails without an answer
- **THEN** the switch stays as it was and the user is told "Could not update this plugin"

#### Scenario: Name is sent safely

- **WHEN** a plugin's name contains characters that are not safe in a URL path (for example a space or `#`)
- **THEN** the name is encoded so the call reaches that plugin and no other route

### Requirement: Updating a plugin

The system SHALL offer Update in a plugin's details only when the row's `can_update_git` is true. Update SHALL call `POST /api/dashboard/agent-plugins/{name}/update`. While it runs, the button SHALL show progress and be disabled. When the server answers `unchanged: true` the user SHALL be told "Already up to date"; when it answers success otherwise the user SHALL be told "Updated <name>" and the list SHALL be reloaded. When the server refuses, the user SHALL be shown its `detail` (otherwise "Could not update this plugin").

#### Scenario: Update offered

- **WHEN** a plugin has `can_update_git` set to true
- **THEN** its details show an Update button

#### Scenario: Update not offered

- **WHEN** a plugin has `can_update_git` false or missing
- **THEN** its details show no Update button

#### Scenario: Update changes the plugin

- **WHEN** the user taps Update and the server answers success without `unchanged`
- **THEN** the user is told "Updated <name>" and the list is reloaded

#### Scenario: Already up to date

- **WHEN** the server answers success with `unchanged` true
- **THEN** the user is told "Already up to date" and nothing else changes

#### Scenario: Update refused

- **WHEN** the server answers 400 with a `detail`
- **THEN** the user is shown that `detail` and the plugin is left as it was

### Requirement: Removing a plugin

The system SHALL offer Remove in a plugin's details only when the row's `can_remove` is true. Tapping Remove SHALL ask "Remove <name>?" with a note that its files are deleted from the server, and SHALL call `DELETE /api/dashboard/agent-plugins/{name}` only after the user confirms. When the server accepts, the list SHALL be reloaded and the details closed. When it refuses, the user SHALL be shown its `detail` (otherwise "Could not remove this plugin") and the plugin SHALL stay.

#### Scenario: Remove offered

- **WHEN** a plugin has `can_remove` set to true
- **THEN** its details show a Remove button

#### Scenario: Remove not offered

- **WHEN** a plugin has `can_remove` false or missing, as a bundled plugin does
- **THEN** its details show no Remove button

#### Scenario: Confirmed

- **WHEN** the user taps Remove and confirms
- **THEN** the delete call is made, the details close, and the plugin is no longer listed after the reload

#### Scenario: Cancelled

- **WHEN** the user taps Remove and cancels
- **THEN** no call is made and the plugin stays

#### Scenario: Remove refused

- **WHEN** the server answers 400 with a `detail`
- **THEN** the user is shown that `detail` and the plugin stays listed

### Requirement: Hiding a plugin from the dashboard sidebar

The system SHALL let the user hide a plugin from the web dashboard's sidebar with a switch in its details that reflects `user_hidden`, and SHALL call `POST /api/dashboard/plugins/{name}/visibility` with `{"hidden": <bool>}` when it is switched. The switch SHALL say it only affects the web dashboard. A refusal or failure SHALL leave the switch as it was and tell the user "Could not update this plugin".

#### Scenario: Hiding

- **WHEN** the user turns the switch on for a visible plugin
- **THEN** the visibility call is made with `hidden` true, the list is reloaded, and the switch shows on

#### Scenario: Showing again

- **WHEN** the user turns the switch off for a hidden plugin
- **THEN** the visibility call is made with `hidden` false and the switch shows off

#### Scenario: Call fails

- **WHEN** the visibility call fails or is refused
- **THEN** the switch stays as it was and the user is told "Could not update this plugin"

### Requirement: Login command for plugins that need one

The system SHALL show, in the details of a plugin whose `auth_required` is true, a "Needs login" block with the row's `auth_command` (when it is a non-empty string) in monospaced text and a copy button, and the note "Run this on the server." Copying SHALL put only that command on the clipboard and tell the user it was copied. The app SHALL NOT run the command. When `auth_command` is empty, the block SHALL say the plugin needs a login without a command.

#### Scenario: Command is shown and copied

- **WHEN** a plugin has `auth_required` true and `auth_command` "hermes auth netbox", and the user taps the copy button
- **THEN** "hermes auth netbox" is on the clipboard and the user is told it was copied

#### Scenario: No command

- **WHEN** a plugin has `auth_required` true and an empty `auth_command`
- **THEN** the block says the plugin needs a login and shows no copy button

#### Scenario: No login needed

- **WHEN** a plugin has `auth_required` false
- **THEN** its details have no "Needs login" block

### Requirement: Plugin management backend contract

The system SHALL manage plugins only through these Hermes Agent routes, sent through the app's managed HTTP client so they carry the same credentials as every other request: `GET /api/dashboard/plugins/hub`, `POST /api/dashboard/agent-plugins/{name}/enable`, `POST /api/dashboard/agent-plugins/{name}/disable`, `POST /api/dashboard/agent-plugins/{name}/update`, `DELETE /api/dashboard/agent-plugins/{name}` and `POST /api/dashboard/plugins/{name}/visibility`. It SHALL require Hermes 0.21.1 or newer. A hub row is an object with `name`, `version`, `description`, `source` (`bundled`, `user` or `entrypoint`), `runtime_status` (`enabled`, `disabled` or `inactive`), `can_remove`, `can_update_git`, `auth_required`, `auth_command`, `user_hidden` and `removed_reason`. A mutation answers `{ "ok": true, "name": <name> }` (plus `unchanged` for enable, disable and update) or an error status with a `detail` string. The app SHALL NOT show or send a row's `path`.

#### Scenario: Older server

- **WHEN** the server does not have the hub route and answers 404
- **THEN** the Plugins screen says the list is not available on this server

#### Scenario: Server without the auth gate

- **WHEN** the dashboard has no sign-in and expects the session token header
- **THEN** the plugin calls carry that header like the app's other requests

#### Scenario: Paths stay private

- **WHEN** a hub row carries a `path`
- **THEN** it is not displayed and not sent to telemetry

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

### Requirement: Plugins screen has Installed, Catalog and Providers tabs

The system SHALL show the Plugins screen with three tabs, Installed, Catalog and Providers, in that order, Installed selected when the screen opens. Each tab SHALL keep its own state (list, search text, open details, unsaved choices) while the user switches between them. The catalog SHALL NOT be requested until the Catalog tab has been opened for the first time, and the provider settings SHALL NOT be requested until the Providers tab has been opened for the first time.

#### Scenario: Opens on Installed

- **WHEN** the Plugins screen opens
- **THEN** the Installed tab is selected and no catalog request and no provider request has been made

#### Scenario: Catalog opened

- **WHEN** the user selects the Catalog tab for the first time
- **THEN** the catalog is requested

#### Scenario: Providers opened

- **WHEN** the user selects the Providers tab for the first time
- **THEN** the provider settings are requested

#### Scenario: Tabs keep their state

- **WHEN** the user types a search in the Catalog tab, selects Installed, and selects Catalog again
- **THEN** the search text and the list are still there and the catalog is not requested again

### Requirement: Provider settings are read from the plugins hub

The system SHALL load the provider settings from the `providers` object of `GET /api/dashboard/plugins/hub` and read it leniently. `memory_provider` is the name of the memory provider in use, an empty string meaning the built-in one; `memory_options` is a list of providers, each with a `name`, a `description`, a `status` and a `setup` object; `context_engine` is the name of the engine in use; `context_options` is a list of engines each with a `name` and a `description`. A provider or engine without a non-empty string `name` SHALL be left out, and a missing or malformed field SHALL fall back to a default (empty text, empty lists, a status that is not ready). A `status` of `ready` SHALL read as Ready, `needs_config` as Needs setup, and anything else as Unavailable. A `setup` object carries `required_env` (variable names), `external_dependencies` (each with a `name`, an `install` command and a `check` command) and `pip_dependencies` (package names). A response without a `providers` object SHALL read as no options with the built-in memory provider and no named context engine in use. Pulling the tab down SHALL load again while keeping what is shown.

#### Scenario: First load

- **WHEN** the Providers tab is opened
- **THEN** a progress indicator shows while the settings load, then the two pickers appear with what the server reports as in use selected

#### Scenario: Rows that do not fit are skipped

- **WHEN** a memory option or context option has no non-empty string `name`
- **THEN** it is left out and the others are shown

#### Scenario: Loading fails

- **WHEN** loading fails
- **THEN** the tab shows "Could not load provider settings" with a Retry button that loads them again

#### Scenario: Server without the hub

- **WHEN** the server answers 404
- **THEN** the tab says the provider settings are not available on this server, with no Retry button

#### Scenario: Refresh fails after a first load

- **WHEN** a refresh fails while the settings are showing
- **THEN** they stay and the user is told "Could not refresh provider settings"

### Requirement: Memory provider picker

The system SHALL show the memory providers as a single choice: "Built-in" first (no external memory), then each provider in the order the server lists them. The provider in use SHALL be selected, and SHALL be shown even when the server's list does not have it. Each provider SHALL carry its status as a chip (Ready, Needs setup, Unavailable) and its description. A provider whose status is not Ready SHALL NOT be selectable, unless it is the one in use. For such a provider the tab SHALL offer a "What it needs" view listing, when non-empty, its environment variable names, its external tools each with the name and the install command (with a copy button), and its Python packages; and SHALL say the setup is done on the server. The app SHALL NOT run a command and SHALL NOT show a value for an environment variable.

#### Scenario: In use

- **WHEN** the server reports `memory_provider` "honcho" and honcho is Ready
- **THEN** honcho is selected

#### Scenario: In use but not listed

- **WHEN** the server reports `memory_provider` "custom-memory" and its list has no such provider
- **THEN** "custom-memory" is still shown, first after Built-in, and selected

#### Scenario: Built-in

- **WHEN** the server reports an empty `memory_provider`
- **THEN** "Built-in" is selected

#### Scenario: Not selectable

- **WHEN** a provider's status is `needs_config` or `unavailable` and it is not the one in use
- **THEN** it cannot be selected and shows "Needs setup" or "Unavailable"

#### Scenario: What it needs

- **WHEN** the user opens "What it needs" for a provider with `required_env` of `MEM0_API_KEY` and an external tool `brv` installed by `curl -fsSL https://byterover.dev/install.sh | sh`
- **THEN** the view lists `MEM0_API_KEY`, and the tool `brv` with that command and a copy button, and says the setup is done on the server

#### Scenario: Copy an install command

- **WHEN** the user taps the copy button next to an install command
- **THEN** only that command is on the clipboard and the user is told it was copied

#### Scenario: Nothing needed

- **WHEN** a provider that is not Ready lists no requirements
- **THEN** its "What it needs" view says the server did not say what it needs

### Requirement: Context engine picker

The system SHALL show the context engines as a single choice among those the server lists, with the one in use selected. When the engine in use is not among them, it SHALL still be shown and selected. When the server lists no engines, the tab SHALL show the engine in use, when there is one, and the note "No other context engines are available on this server", and SHALL offer no choice.

#### Scenario: Engines listed

- **WHEN** the server lists engines `compressor` and `lossless` and reports `compressor` in use
- **THEN** both are shown with `compressor` selected

#### Scenario: In use but not listed

- **WHEN** the engine in use is `compressor` and the list is empty
- **THEN** `compressor` is shown and the note says no other engine is available

### Requirement: Saving provider choices

The system SHALL enable Save only while the memory provider or the context engine chosen differs from the one the server reports. Saving SHALL call `PUT /api/dashboard/plugin-providers` with only the fields that differ: `memory_provider` (an empty string for Built-in) and `context_engine`. While it runs, Save SHALL show progress and be disabled. On success it SHALL tell the user "Saved. Applies to new chats." and load the settings again. When the server refuses, it SHALL show the server's `detail` when it is a non-empty string, otherwise "Could not save provider settings", and SHALL keep the user's choices. Loading again after a refresh SHALL replace the choices with what the server reports.

#### Scenario: Nothing changed

- **WHEN** the tab shows what the server reports
- **THEN** Save is disabled

#### Scenario: Only what changed is sent

- **WHEN** the user picks a different memory provider and leaves the context engine
- **THEN** the call carries `memory_provider` and no `context_engine`

#### Scenario: Back to built-in

- **WHEN** the user picks "Built-in" while a provider is in use
- **THEN** the call carries `memory_provider` as an empty string

#### Scenario: Saved

- **WHEN** the server accepts the change
- **THEN** the user is told "Saved. Applies to new chats.", the settings are loaded again and Save is disabled

#### Scenario: Refused

- **WHEN** the server answers 400 with `detail` "Memory provider 'mem0' is not ready (needs config). Configure it in the dashboard first."
- **THEN** that text is shown, the user's choices are kept and Save stays enabled

#### Scenario: Unreachable

- **WHEN** the call fails without an answer
- **THEN** the user is told "Could not save provider settings" and the choices are kept

### Requirement: Provider settings backend contract

The system SHALL read provider settings from the `providers` object of `GET /api/dashboard/plugins/hub` and change them only with `PUT /api/dashboard/plugin-providers`, sent through the app's managed HTTP client, and SHALL require Hermes 0.21.1 or newer. The `providers` object has `memory_provider`, `memory_options` (objects with `name`, `description`, `available`, `configured`, `status` of `ready`, `needs_config` or `unavailable`, and `setup` with `pip_dependencies`, `external_dependencies`, `required_env` and `dependencies_installed`), `context_engine` and `context_options`. The body is `{ "memory_provider": <string or absent>, "context_engine": <string or absent> }`; success answers `{ "ok": true }` and a refusal an error status with a `detail` string.

#### Scenario: Older server

- **WHEN** the server does not have the hub route and answers 404
- **THEN** the Providers tab says the provider settings are not available on this server

#### Scenario: Server without the auth gate

- **WHEN** the dashboard has no sign-in and expects the session token header
- **THEN** the provider calls carry it like the app's other requests

