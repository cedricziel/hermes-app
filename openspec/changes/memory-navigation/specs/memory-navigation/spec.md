## ADDED Requirements

### Requirement: Memory entry in the chat sidebar

Off macOS, the chat sidebar SHALL show a "Memory" entry directly after Skills wherever Skills is shown (the phone drawer, the iPad sidebar and the desktop sidebar's More section), under the same condition as Skills. It SHALL open the Memory screen for the profile the chat shows.

#### Scenario: Drawer order

- **WHEN** the phone drawer lists Profiles, Skills and Messaging
- **THEN** Memory appears between Skills and Messaging

#### Scenario: Opens the chat's profile

- **WHEN** the chat shows profile "work" and the user taps Memory
- **THEN** the Memory screen opens on "work"

#### Scenario: No dashboard connection

- **WHEN** the sidebar does not show Skills
- **THEN** it does not show Memory either

### Requirement: Memory opens on a given profile

The Memory screen SHALL open on the profile its entry point names and SHALL NOT replace it with the server's active profile. Switching profile from the screen SHALL keep the rules of the learned-memory specs. When the named profile no longer exists, the screen SHALL say "This profile is no longer available."

#### Scenario: Profile removed

- **WHEN** the Memory screen is opened for a profile the server no longer lists
- **THEN** it says "This profile is no longer available." and shows no entries

### Requirement: No Memory row in Settings

The Settings dialog SHALL NOT list Memory; it lists app-wide settings only.

#### Scenario: Settings opened

- **WHEN** the user opens Settings
- **THEN** there is no Memory row

### Requirement: Memory navigation telemetry

Opening Memory from an entry point SHALL add a `nav.memory` breadcrumb carrying only `from` (`sidebar` or `profiles_page`). The Mac Profiles page's count read SHALL be traced as a `memory.fetch` span with `operation: count`. Neither SHALL carry a profile name, an entry count or memory text.

#### Scenario: Opened from the Profiles page

- **WHEN** the user opens Memory from the Mac Profiles page
- **THEN** a `nav.memory` breadcrumb with `from: profiles_page` is recorded
