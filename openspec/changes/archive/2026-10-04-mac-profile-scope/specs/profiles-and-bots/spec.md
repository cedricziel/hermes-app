## ADDED Requirements

### Requirement: Profile switcher on macOS

On macOS the sidebar SHALL show the profile the chat works in as a card at its top, above the destinations: the profile's initials, name and description. A click SHALL open a menu headed "Profiles" with one item per profile (its name with its home directory below, a check on the current one), then "New Profile…" and "Manage Profiles…". Picking another profile SHALL switch to it as the Profiles screen does: the dashboard is asked to make it active, and the chat lists that profile's threads; a refusal SHALL be reported as "Could not switch profile" and change nothing. Picking the current profile SHALL do nothing. "Manage Profiles…" SHALL open the Profiles page.

#### Scenario: Switching from the sidebar

- **WHEN** the user picks "work" in the switcher while "default" is shown
- **THEN** "work" is made the active profile and the chat lists the threads of "work"

### Requirement: Profiles page on macOS

On macOS the sidebar SHALL have a Profiles destination under Schedules, opening a page with the toolbar title "Profiles", the subtitle "N profiles on <server host>" and a New Profile button. The page SHALL list the profiles in a 220 point column (avatar, name, description) and show the selected one's home: its name, its home directory, and a card of what it holds (Skills, Bots, Plugins, MCP servers, Helper models), each with a count and opening the screen that manages it, scoped to that profile where the screen supports one. Counts SHALL be read when a profile is selected; a count that cannot be read SHALL show nothing rather than 0. Bots and plugins are managed for the profile the dashboard is scoped to, so their counts SHALL only show for the profile the chat shows. A footnote SHALL say that everything listed lives in the profile's home directory, that chats, schedules, memory and API keys are per profile too, and that Kanban and sign-in are shared.

The per-profile management entries of the chat sidebar (Profiles, Skills, Bots, Plugins, MCP servers, Helper models) SHALL not be shown on macOS; other platforms SHALL keep them.

#### Scenario: Counts of another profile

- **WHEN** the user selects "work" on the Profiles page and its helper models cannot be read
- **THEN** Skills and MCP servers show their counts, Helper models shows none, and Bots and Plugins show none because "work" is not the chat's profile

### Requirement: Creating a profile

The system SHALL let the user create a profile from the Mac switcher's "New Profile…" or the Profiles page's New Profile button: a dialog asks for a name (letters, digits, `-` and `_`, starting with a letter or digit) and an optional description, and Create sends `POST /api/profiles` with them. The profile list SHALL be read again afterwards. A refusal SHALL be reported as "Could not create the profile", followed by the dashboard's explanation when it gave one.

#### Scenario: Name refused

- **WHEN** the dashboard answers that the profile exists
- **THEN** the user is told "Could not create the profile: <detail>" and the list is unchanged

### Requirement: Account footer on macOS

On macOS the bottom of the sidebar SHALL show the signed-in user's initials and name (the server host when the dashboard reports no user) with the server's host, above a hairline. A click SHALL open a menu headed "Signed in to the dashboard" ("Connected to the dashboard" without sign-in) with "Settings… ⌘,", "Connection Details" and, when the server needs sign-in, "Sign Out". Settings… SHALL open a list of the app's settings (Appearance, Notifications, App Lock, About Hermes, Change Server) that opens the same dialogs the account menu opens on other platforms.

#### Scenario: Settings from the footer

- **WHEN** the user chooses Settings… in the account menu
- **THEN** a Settings list opens, and Appearance… opens the appearance dialog
