## Why

In Hermes a profile is a whole home: its own chats, schedules, memory, skills, bots, plugins, MCP servers, helper models and API keys. Kanban and the dashboard sign-in are shared. The Mac sidebar did not say which profile it shows, and kept six management rows behind "More", which reads as if they belonged to the app rather than to a profile. The Mac native concept makes the profile the sidebar's scope.

## What Changes

- macOS: a profile switcher card at the top of the sidebar, with a menu of every profile (home directory under each), New Profile… and Manage Profiles….
- macOS: a Profiles destination and page: the profiles beside the selected one's home, with counts of what it holds and links to the screens that manage each, scoped to that profile.
- macOS: the sidebar's per-profile management rows go away; other platforms keep them.
- macOS: an account footer with the user's initials, name and server host, and a menu with Settings…, Connection Details and Sign Out. Settings… lists the existing settings dialogs.
- Every platform: profiles can be created (`POST /api/profiles`); the MCP servers screen can open for a given profile.

### Non-goals

- Renaming, deleting or exporting profiles.
- Moving Kanban or Schedules (other streams).
- Channels: the app has no channels screen.

### Security and privacy

Creating a profile writes a new home on the user's own server through the existing client. No new data is stored on the device.

### Telemetry

None.

## Capabilities

### Modified Capabilities

- `profiles-and-bots`: adds "Profile switcher on macOS", "Profiles page on macOS", "Creating a profile" and "Account footer on macOS".

## Impact

`ChatProfiles` (shared by `AppShell`, `ChatScreen` and the Profiles page), `HermesProfilesRepository.list`/`create` and `HermesProfile.path`, new widgets under `lib/src/profiles/widgets/` and `lib/src/settings/widgets/`, `McpServersScreen(profile:)`, `AdaptiveMenuItem.macHeight`.
