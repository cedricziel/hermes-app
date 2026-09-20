## RENAMED Requirements

- FROM: `### Requirement: Plugins screen has an Installed and a Catalog tab`
- TO: `### Requirement: Plugins screen has Installed, Catalog and Providers tabs`

## MODIFIED Requirements

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

## ADDED Requirements

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
