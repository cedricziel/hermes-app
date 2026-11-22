## MODIFIED Requirements

### Requirement: Memory entry in the chat sidebar

Off macOS, a "Memory" entry SHALL follow Skills directly wherever Skills is listed (the More page wherever the shell shows a destination bar or rail, the drawer of a Windows or Linux window under 600 logical pixels, the iPad sidebar and the desktop sidebar's More section), under the same condition as Skills. It SHALL open the Memory screen for the profile the chat shows.

#### Scenario: Drawer order

- **WHEN** the More page or the drawer lists Profiles, Skills and Messaging
- **THEN** Memory appears between Skills and Messaging

#### Scenario: Opens the chat's profile

- **WHEN** the chat shows profile "work" and the user taps Memory
- **THEN** the Memory screen opens on "work"

#### Scenario: No dashboard connection

- **WHEN** the sidebar or the More page does not show Skills
- **THEN** it does not show Memory either
