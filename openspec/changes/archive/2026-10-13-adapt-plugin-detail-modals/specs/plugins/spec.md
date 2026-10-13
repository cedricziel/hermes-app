## MODIFIED Requirements

### Requirement: Plugin details adapt to screen width

The system SHALL open a plugin's details when its row is tapped: as a centered desktop dialog on compact macOS layouts, as a bottom sheet on other compact layouts, and as a pane beside the list on regular-width layouts, where the selected row stays highlighted. The details SHALL show the plugin's name, version, description and source, and the actions this capability defines. When a reload no longer lists the selected plugin, the details SHALL close.

#### Scenario: Phone-width layout

- **WHEN** an iOS or Android layout is compact and the user taps a row
- **THEN** a bottom sheet with the plugin's details opens over the list

#### Scenario: Wide layout

- **WHEN** the width is 900 logical pixels or more and the user taps a row
- **THEN** the details appear in a pane beside the list and the row is highlighted, and no sheet opens

#### Scenario: Selected plugin is gone

- **WHEN** a reload no longer lists the plugin whose details are open
- **THEN** the details close

#### Scenario: Compact macOS layout

- **WHEN** a macOS window is too narrow for a details pane and the user taps a plugin row
- **THEN** its existing detail content opens in a centered desktop dialog without a mobile bottom sheet

#### Scenario: Dismissed details

- **WHEN** the user dismisses compact plugin details
- **THEN** the plugin list remains open and the selected detail is cleared

### Requirement: Catalog entry details

The system SHALL open an entry's details when its row is tapped, as a centered desktop dialog on compact macOS layouts, as a bottom sheet on other compact layouts, and as a pane beside the list on regular-width layouts. The details SHALL show the entry's name, tier, maintainer, whole description, pinned commit, the Hermes version it requires (when it names one), its platforms (when it names any), the names of the tools, hooks and middleware it provides and of the environment variables it requires (each group only when non-empty), and a docs link when the entry has one. The docs link SHALL open in the system browser and SHALL only be offered for an `http` or `https` address.

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

#### Scenario: Compact macOS catalog details

- **WHEN** the user opens a catalog entry in a compact macOS window
- **THEN** its existing content and install controls appear in a centered desktop dialog without a mobile bottom sheet

#### Scenario: Install finishes after dismissal

- **WHEN** the user dismisses catalog details while an installation remains pending
- **THEN** duplicate install controls stay disabled while pending and the completed result is still reported on the plugin screen

The existing backend contract remains unchanged: `GET /api/dashboard/plugins/hub`, `GET /api/dashboard/plugins/catalog`, and the established agent-plugin mutation and install routes keep their existing response shapes and Hermes 0.21.1 minimum. This presentation change adds no route, field, or protocol requirement.
