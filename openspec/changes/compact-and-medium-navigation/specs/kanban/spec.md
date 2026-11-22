## MODIFIED Requirements

### Requirement: Plugin detection gates the Kanban tab

The system SHALL offer the Kanban destination only while the server reports the Kanban plugin as on. It SHALL ask `GET /api/dashboard/plugins` and treat the plugin as on when the returned list contains an entry named `kanban`. Any failure to get a usable answer (network error, an error status, a body that is not a list, a server too old to have the route) SHALL count as off.

#### Scenario: Plugin is off

- **WHEN** the server lists no plugin named `kanban` and offers no other destination
- **THEN** an expanded layout shows only the chat and no sidebar, a destination bar or rail shows Chats and More and no Kanban item, and a Windows or Linux window under 600 logical pixels shows the chat alone with the chat's own drawer

#### Scenario: Plugin is on

- **WHEN** the server lists a plugin named `kanban`
- **THEN** the app shows a navigation with a Chat and a Kanban destination

#### Scenario: Detection fails

- **WHEN** the plugin list request fails or returns something that is not a list
- **THEN** the app treats Kanban as off and offers no Kanban destination

### Requirement: Chat and Kanban navigation adapts to screen width

While more than one destination is offered, the system SHALL list them (Chat, Kanban when the plugin is on, and any other) at the top of the sidebar, above Chat's threads. When the available width is 900 logical pixels or more the sidebar is shown next to every page. Switching to Kanban SHALL NOT discard the chat: the chat stays mounted, keeping its state, while the Kanban page is shown.

#### Scenario: Phone-width layout

- **WHEN** the plugin is on and the width is below 600 logical pixels on iPhone or Android
- **THEN** Chats, Kanban and More are items of the bottom bar on every destination's root page, and no menu button or drawer is shown

#### Scenario: Wide layout

- **WHEN** the plugin is on and the width is 900 logical pixels or more
- **THEN** Chat and Kanban are listed at the top of the sidebar next to the page, in the same place on both pages, and no bottom bar is shown

## ADDED Requirements

### Requirement: Home without Kanban

While the Kanban plugin is off and no other destination is offered, the signed-in home screen SHALL be the chat alone, without any sidebar, on an expanded layout and on a Mac, and a destination bar or rail SHALL hold Chats and More only, with no Kanban item. A Windows or Linux window under 600 logical pixels SHALL keep the chat alone with the chat's own drawer, as today, and SHALL NOT gain a shell drawer.

#### Scenario: Compact layout with Kanban off

- **WHEN** the Kanban plugin is off, no other destination is offered and the width is below 600 logical pixels on iPhone or Android
- **THEN** the destination bar holds Chats and More and no Kanban item

### Requirement: Kanban navigation below the wide breakpoint

On iPhone and iPad Split View below the expanded form, and on Android below 600 logical pixels, the destinations SHALL be items of a bottom tab bar or navigation bar, More last. From 600 to 899 logical pixels on Android, Windows and Linux they SHALL be items of a navigation rail, More last. On Windows and Linux below 600 they SHALL be in today's drawer, opened from the menu button in each page's app bar, with no More row; picking a destination SHALL close that drawer.

#### Scenario: Medium layout

- **WHEN** the plugin is on and the width is 600 to 899 logical pixels on Android
- **THEN** Chats, Kanban and More are items of a navigation rail next to the page, in the same place on both pages
