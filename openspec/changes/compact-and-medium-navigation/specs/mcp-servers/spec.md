## MODIFIED Requirements

### Requirement: Sidebar entry

The system SHALL show an "MCP servers" entry that opens the MCP servers screen: in the chat sidebar below Profiles and Bots, and, where the shell shows a destination bar or rail, on the More page after Plugins. The entry SHALL NOT be shown when the chat has no MCP repository.

#### Scenario: Entry is shown

- **WHEN** the chat sidebar or the More page has an MCP repository
- **THEN** it shows an "MCP servers" entry that closes the drawer where one is open and opens the MCP servers screen

#### Scenario: No repository

- **WHEN** the chat sidebar or the More page has no MCP repository
- **THEN** the "MCP servers" entry is not shown
