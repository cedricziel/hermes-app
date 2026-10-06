## MODIFIED Requirements

### Requirement: Profiles page on macOS

On macOS the sidebar SHALL have a Profiles destination under Schedules, opening a page with the toolbar title "Profiles", the subtitle "N profiles on <server host>" and a New Profile button. The page SHALL list the profiles in a 220 point column (avatar, name, description) and show the selected one's home: its name, its home directory, and a card of what it holds (Skills, Messaging, Plugins, MCP servers, Helper models), each with a count and opening the screen that manages it, scoped to that profile where the screen supports one. Counts SHALL be read when a profile is selected; a count that cannot be read SHALL show nothing rather than 0. Messaging SHALL count the platforms switched on in that profile, read with `GET /api/messaging/platforms?profile=<name>`, and SHALL open the Messaging screen for that profile. Plugins SHALL count the plugins switched on only for the profile the chat shows, since the dashboard's plugin hub takes no profile. A footnote SHALL say that everything listed lives in the profile's home directory, that chats, schedules, memory and API keys are per profile too, and that Kanban and sign-in are shared.

The per-profile management entries of the chat sidebar (Profiles, Skills, Messaging, Plugins, MCP servers, Helper models) SHALL not be shown on macOS; other platforms SHALL keep them.

#### Scenario: Counts of another profile

- **WHEN** the user selects "work" on the Profiles page and its helper models cannot be read
- **THEN** Skills and MCP servers show their counts, Helper models shows none, Messaging counts the platforms switched on in "work", and Plugins shows none because "work" is not the chat's profile

### Requirement: Account footer on macOS

On macOS the bottom of the sidebar SHALL show the signed-in user's initials and name (the server host when the dashboard reports no user) with the server's host, above a hairline. A click SHALL open a menu headed "Signed in to the dashboard" ("Connected to the dashboard" without sign-in) with "Settings… ⌘,", "Connection Details" and, when the server needs sign-in, "Sign Out", which asks "Sign out of the dashboard?" first. Settings… SHALL open a list of the app's settings (Appearance, Notifications, App Lock, About Hermes, Change Server) that opens the same dialogs the account menu opens on other platforms.

#### Scenario: Settings from the footer

- **WHEN** the user chooses Settings… in the account menu
- **THEN** a Settings list opens, and Appearance… opens the appearance dialog
