## Why

The Mac account footer's Connection Details and Sign Out had no menu bar commands, and Sign Out acted on one click. The Profiles page showed no Messaging count for a profile other than the chat's, although the messaging routes take a profile.

## What Changes

- macOS: Connection Details and Sign Out… in the Hermes menu, under Settings…; Sign Out… is disabled without sign-in.
- macOS: Sign Out from the footer or the menu asks for confirmation first.
- macOS: the Profiles page counts and opens each profile's messaging platforms. Plugins still count only for the chat's profile: `GET /api/dashboard/plugins/hub` has no profile parameter.
- `HermesMessagingRepository.forProfile` scopes every messaging read and write that takes a profile.

### Non-goals

Profile-scoped plugins (no backend route).

### Security and privacy

None beyond asking before signing out.

### Telemetry

None.

## Capabilities

### Modified Capabilities

- `macos-menu-bar`: the Hermes menu gains Connection Details and Sign Out….
- `profiles-and-bots`: per-profile Messaging on the Profiles page; Sign Out asks first.

## Impact

`MacCommand`, `mac_menu_bar.dart`, `AppShell`, `AccountFooter`, `HermesMessagingRepository`, `MacProfilesPage`.
