## MODIFIED Requirements

### Requirement: Adding a server from the catalog

The system SHALL show an "Add" button in the header of the MCP servers screen that opens a menu with "Browse the catalog", which opens the Catalog screen of `mcp-catalog` for the same profile, and "Add a custom server", which opens the form of `mcp-custom-servers` for the same profile. The empty state SHALL offer the same two choices as two buttons. The button SHALL be shown whenever the screen has loaded its servers, including when the list is empty.

#### Scenario: Add button

- **WHEN** the MCP servers screen has loaded its servers and the user taps "Add" and then "Browse the catalog"
- **THEN** the Catalog screen opens for the profile named in the header

#### Scenario: Add menu

- **WHEN** the MCP servers screen has loaded its servers and the user taps "Add"
- **THEN** a menu offers "Browse the catalog" and "Add a custom server"

#### Scenario: Empty state

- **WHEN** the profile has no MCP servers and the user taps "Browse the catalog" in the empty state
- **THEN** the Catalog screen opens for the same profile

#### Scenario: Empty state custom form

- **WHEN** the profile has no MCP servers and the user taps "Add a custom server" in the empty state
- **THEN** the custom form opens for the same profile

#### Scenario: Servers could not be loaded

- **WHEN** the screen shows "Could not load MCP servers"
- **THEN** no Add button is shown

## ADDED Requirements

### Requirement: Overflow menu

The system SHALL show an overflow menu in the header of the MCP servers screen, whenever the screen has loaded its servers, with the entry "Edit as JSON" that opens the JSON editor of `mcp-custom-servers` for the same profile. When the servers could not be loaded, no menu SHALL be shown.

#### Scenario: Edit as JSON

- **WHEN** the MCP servers screen has loaded its servers and the user opens the overflow menu and taps "Edit as JSON"
- **THEN** the JSON editor opens for the profile named in the header

#### Scenario: Servers could not be loaded

- **WHEN** the screen shows "Could not load MCP servers"
- **THEN** no overflow menu is shown
