## MODIFIED Requirements

### Requirement: Opening an entry

The system SHALL open installation details when the user taps an entry that is not installed, as a centered desktop dialog on compact macOS layouts, as a bottom sheet on other compact layouts, and in the right-hand pane on regular-width layouts. It SHALL open the installed server's detail from `mcp-servers` when the user taps an installed entry. Dismissal SHALL preserve the catalog route beneath the modal and the existing installation result and server-build behavior.

#### Scenario: Not installed

- **WHEN** the user taps an entry that is not installed
- **THEN** installation details for that entry open

#### Scenario: Installed

- **WHEN** the user taps an installed entry
- **THEN** the detail of that server opens and no install sheet is shown

#### Scenario: Compact macOS installation

- **WHEN** the user opens an uninstalled catalog entry in a compact macOS window
- **THEN** its existing installation panel opens in a desktop dialog without a mobile bottom sheet

#### Scenario: Mobile installation

- **WHEN** the user opens an uninstalled entry on a compact iOS or Android layout
- **THEN** the existing scroll-controlled safe-area bottom sheet opens

#### Scenario: Pending installation dismissed

- **WHEN** the user dismisses a pending installation and its result later arrives
- **THEN** the catalog remains open and the result does not close an underlying route or open a server automatically

#### Scenario: Server build dismissed

- **WHEN** the user dismisses installation details while Hermes is building the server
- **THEN** local polling stops and no build-cancellation request is sent

The existing backend contract remains unchanged. `GET /api/mcp/catalog`, `POST /api/mcp/catalog/install`, and `GET /api/actions/{name}/status` retain their established profile parameters and catalog, install, and action-status response shapes. Existing server refresh and navigation use the same MCP server routes. The minimum Hermes version remains 0.21.3; no route or field is added.
