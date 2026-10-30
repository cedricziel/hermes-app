## MODIFIED Requirements

### Requirement: Profiles page on macOS

On macOS the sidebar SHALL have a Profiles destination under Schedules, opening a page with the toolbar title "Profiles", the subtitle "N profiles on <server host>" and a New Profile button. The page SHALL list the profiles in a 220 point column (avatar, name, description) and show the selected one's home: its name, its home directory, and a card of what it holds (Skills, Memory, Messaging, Plugins, MCP servers, Helper models), each with a count and opening the screen that manages it, scoped to that profile where the screen supports one. Counts SHALL be read when a profile is selected; a count that cannot be read SHALL show nothing rather than 0. Memory SHALL count the profile's memory entries, read with `GET /api/learning/graph?profile=<name>` (nodes of `kind: memory`), and SHALL open the Memory screen for that profile. Messaging SHALL count the platforms switched on in that profile, read with `GET /api/messaging/platforms?profile=<name>`, and SHALL open the Messaging screen for that profile. Plugins SHALL count the plugins switched on in that profile, read with `GET /api/dashboard/plugins/hub?profile=<name>`, and SHALL open the Plugins screen for that profile. A footnote SHALL say that everything listed lives in the profile's home directory, that chats, schedules, memory and API keys are per profile too, and that Kanban and sign-in are shared.

The per-profile management entries of the chat sidebar (Profiles, Skills, Memory, Messaging, Plugins, MCP servers, Helper models) SHALL not be shown on macOS; other platforms SHALL keep them.

#### Scenario: Counts of another profile

- **WHEN** the user selects "work" on the Profiles page and its helper models cannot be read
- **THEN** Skills and MCP servers show their counts, Helper models shows none, and Messaging and Plugins count what is switched on in "work"

#### Scenario: Memory of the selected profile

- **WHEN** the user selects "work", whose graph lists three memory nodes, and clicks Memory
- **THEN** the Memory row, directly after Skills, shows 3, and the Memory screen opens on "work"

#### Scenario: Memory count unreadable

- **WHEN** the graph request for the selected profile fails
- **THEN** the Memory row shows no count and still opens the Memory screen
