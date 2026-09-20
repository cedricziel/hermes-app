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

