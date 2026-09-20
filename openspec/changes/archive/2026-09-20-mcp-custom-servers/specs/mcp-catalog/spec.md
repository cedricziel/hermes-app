## MODIFIED Requirements

### Requirement: Catalog screen

The system SHALL offer a Catalog screen, opened by "Browse the catalog" in the menu of the "Add" button of the MCP servers screen and by the same button in its empty state, acting on the active profile and naming it in the header as "Installing into: {profile}". It SHALL load the catalog with `GET /api/mcp/catalog` and the active profile, show a progress indicator while loading, and list every entry with its name, its description, a chip for its transport ("Remote" or "Command"), a chip for its sign-in kind ("API key", "OAuth" or "No auth"), a "Builds locally" chip when Hermes has to build it on the server, and an "Installed" chip when it is installed. Entries without a non-empty string name SHALL be skipped. When the answer carries diagnostics, the screen SHALL say that some catalog entries could not be read. When loading fails, or the active profile cannot be learned, the screen SHALL show "Could not load the catalog" with a Retry button and SHALL NOT install anything.

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

- **WHEN** the user taps "Add" on the MCP servers screen and then "Browse the catalog", or taps "Browse the catalog" in the empty state
- **THEN** the Catalog screen opens for the same profile
