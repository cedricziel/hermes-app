## ADDED Requirements

### Requirement: Adding a server from the catalog

The system SHALL show an "Add" button in the header of the MCP servers screen, and a button of the same purpose in the empty state, that open the Catalog screen of `mcp-catalog` for the same profile. The button SHALL be shown whenever the screen has loaded its servers, including when the list is empty.

#### Scenario: Add button

- **WHEN** the MCP servers screen has loaded its servers and the user taps "Add"
- **THEN** the Catalog screen opens for the profile named in the header

#### Scenario: Empty state

- **WHEN** the profile has no MCP servers and the user taps the button of the empty state
- **THEN** the Catalog screen opens for the same profile

#### Scenario: Servers could not be loaded

- **WHEN** the screen shows "Could not load MCP servers"
- **THEN** no Add button is shown

## MODIFIED Requirements

### Requirement: Sign in needed

The system SHALL show "Sign in needed" instead of the plain failure when a test of a server that signs in with OAuth answers `ok: false` with an error that begins with "OAuth authentication required", or that begins with "MCP OAuth for" and says no cached tokens were found (Hermes' two wordings for a missing token). The row and the detail SHALL show it as a warning chip and banner ("Hermes has no OAuth token for this server yet, so it cannot list tools."). The banner SHALL offer a "Sign in" button, and so SHALL the detail of every server that signs in with OAuth, which start the sign-in of `mcp-catalog`.

#### Scenario: OAuth token missing

- **WHEN** the test of a server with `auth: "oauth"` answers `ok: false` with "OAuth authentication required — no token found."
- **THEN** the detail shows the "Sign in needed" banner with a "Sign in" button instead of "Could not connect", and the row shows a "Sign in needed" chip

#### Scenario: OAuth flow refused inside the dashboard

- **WHEN** the test of a server with `auth: "oauth"` answers `ok: false` with "MCP OAuth for 'grafana': non-interactive environment and no cached tokens found. Run `hermes mcp login grafana` interactively first…"
- **THEN** the detail shows the "Sign in needed" banner with its "Sign in" button, as for the first wording

#### Scenario: Other failure on an OAuth server

- **WHEN** the test of an OAuth server answers `ok: false` with any other error
- **THEN** the detail shows "Could not connect" and that error

#### Scenario: Sign in on an OAuth server

- **WHEN** the detail of a server that signs in with OAuth is shown
- **THEN** it offers a "Sign in" button, whether or not the server has been tested

#### Scenario: Not an OAuth server

- **WHEN** the detail of a server that does not sign in with OAuth is shown
- **THEN** it offers no "Sign in" button
