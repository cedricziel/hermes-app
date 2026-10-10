# Spec Delta

## Purpose

Describes the Recent chats, Needs you and Board widgets on the iPhone and iPad Home Screen: what each shows from the app's surface snapshot, where a tap goes, how they look when signed out or out of date, and what iOS hides while the device is locked.

## ADDED Requirements

### Requirement: Redacted rows while App Lock is on

While App Lock is on, the snapshot holds no titles, snippets or job names. The widgets SHALL then draw a redacted placeholder where the title and snippet would be, never an invented title. Counts, ages, kind labels and taps SHALL work as without App Lock, and a tap SHALL open the app, which asks for App Lock before showing the chat.

#### Scenario: Recent chats with App Lock on

- **WHEN** App Lock is on and the Recent chats medium widget is shown on the unlocked Home Screen
- **THEN** it shows three rows with a redacted placeholder and their age, no title or snippet, and a tap opens Hermes behind App Lock

#### Scenario: Needs you with App Lock on

- **WHEN** App Lock is on and two approvals are open
- **THEN** the Needs you widget shows 2 and two rows labelled "Approval" with redacted titles

### Requirement: Widgets show the surface snapshot only

The widgets SHALL draw only what the app last wrote to the surface snapshot. They SHALL NOT contact the Hermes server, read a token or show the server address. When no snapshot exists, it cannot be read, its version is unknown, or it says the user is signed out, every widget SHALL show "Open Hermes to sign in" and a tap SHALL open the app. When the snapshot is older than six hours, a widget SHALL add "Open Hermes to refresh" under its content.

#### Scenario: Signed out

- **WHEN** the user signs out with a Recent chats widget on the Home Screen
- **THEN** the widget shows "Open Hermes to sign in" and no chat titles

#### Scenario: Out of date

- **WHEN** the snapshot was written seven hours ago
- **THEN** the widget shows its content and "Open Hermes to refresh"

### Requirement: Recent chats widget

The Recent chats widget SHALL come in small, medium and large sizes and list the newest chats across profiles, newest first: one in small, three in medium, six in large. Each row SHALL show the chat's title, its profile when the snapshot holds chats of more than one profile, and how long ago it changed; medium and large rows SHALL also show the latest-message snippet. Tapping a row SHALL open that chat in its profile. With no chats the widget SHALL show "No chats yet" and open a new chat.

#### Scenario: Tap a chat

- **WHEN** the user taps "Trip plan" in the medium widget
- **THEN** Hermes opens with "Trip plan" selected in its profile

#### Scenario: Small size

- **WHEN** the widget is small
- **THEN** it shows only the newest chat, and a tap opens it

### Requirement: Needs you widget

The Needs you widget SHALL come in small and medium sizes and show the number of open approvals, questions and other input requests across profiles. The medium size SHALL also list up to three chats with open requests, oldest request first, each with its chat title and a fixed label for its kind ("Approval", "Question", "Waiting for you"). Tapping a chat SHALL open it; tapping the small widget or the count SHALL open the chat of the oldest open request. With no open request the widget SHALL show "Nothing waiting" and open the chat list. It SHALL NOT show a command, question text or secret name.

#### Scenario: Two approvals waiting

- **WHEN** two approvals are open in two chats
- **THEN** the widget shows 2 and, in medium, both chat titles labelled "Approval"

#### Scenario: Tap the count

- **WHEN** the user taps the small widget while requests are open
- **THEN** Hermes opens the chat of the oldest open request

### Requirement: Board widget

The Board widget SHALL come in small and medium sizes. It SHALL show the Kanban counts of blocked and in-review tasks, the time and name of the next scheduled run, and the last failed scheduled job with its name and time. A part whose feature the server does not offer SHALL be left out, and with neither feature the widget SHALL show "No board or schedules on this server". Tapping the Kanban part SHALL open the Kanban tab, the next run the Schedules tab, and the failed job that job. A next run whose time has passed SHALL read "Due" until the app writes a new snapshot.

#### Scenario: Failed job

- **WHEN** the job "Backup" failed and the user taps it in the widget
- **THEN** Hermes opens the Schedules tab on "Backup"

#### Scenario: Server without Kanban

- **WHEN** the server does not report the Kanban plugin
- **THEN** the widget shows only the schedules part

### Requirement: Redaction on a locked device

Chat titles, snippets, profile names and job names in the widgets SHALL be marked privacy sensitive, so iOS hides them while the device is locked. Counts, symbols and fixed labels SHALL stay visible. The widget gallery SHALL show sample content, never the user's chats.

#### Scenario: iPad Lock Screen

- **WHEN** a Recent chats widget is shown on a locked iPad
- **THEN** titles and snippets are redacted

#### Scenario: Counts stay visible

- **WHEN** a Needs you widget is shown on a locked device
- **THEN** the count is readable and chat titles are redacted

### Requirement: Backend contract

The widgets SHALL rely on no Hermes route, RPC method or minimum version of their own; their data comes from the surface snapshot the app writes from the routes it already uses.

#### Scenario: Any supported server

- **WHEN** the app is connected to the oldest Hermes it supports
- **THEN** the widgets work, leaving out the Kanban or schedules part when that server lacks it
