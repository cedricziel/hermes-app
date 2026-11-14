# Spec Delta

## ADDED Requirements

### Requirement: Widgets show the surface snapshot only

The Android widgets SHALL draw only what the app last wrote to the surface snapshot. They SHALL NOT contact the Hermes server, read a token or show the server address. When no snapshot exists, it cannot be read, its version is unknown, or it says the user is signed out, every widget SHALL show "Open Hermes to sign in" and a tap SHALL open the app. When the snapshot is older than six hours, a widget SHALL keep its content and add "Open Hermes to refresh".

#### Scenario: Signed out

- **WHEN** the user signs out with a Recent chats widget on the home screen
- **THEN** the widget shows "Open Hermes to sign in" and no chat titles, and a tap opens the app

#### Scenario: Out of date

- **WHEN** the snapshot was written seven hours ago and the widget is redrawn
- **THEN** it shows its content and "Open Hermes to refresh"

#### Scenario: Unreadable snapshot

- **WHEN** the stored snapshot is not valid JSON or has an unknown version
- **THEN** every widget shows "Open Hermes to sign in" and none fails to draw

### Requirement: Recent chats widget

The Recent chats widget SHALL come in a small (2x2) and a medium (4x3) size and list the newest chats across profiles, newest first: one in small, up to three in medium. Each row SHALL show the title, the profile when the snapshot holds chats of more than one profile, and how long ago the chat changed; medium rows SHALL also show the snippet. A tap on a row SHALL open that chat in its profile. With no chats it SHALL show "No chats yet" and open a new chat.

#### Scenario: Tap a chat

- **WHEN** the user taps "Trip plan" in the medium widget
- **THEN** Hermes opens with "Trip plan" selected in its profile

#### Scenario: Small size

- **WHEN** the widget is small and the snapshot holds five chats
- **THEN** it shows only the newest chat, and a tap opens it

### Requirement: Needs you widget

The Needs you widget SHALL come in small and medium sizes and show the number of open approvals, questions and other input requests across profiles. Medium SHALL list up to three chats with open requests, oldest first, each with its title and a fixed kind word ("Approval", "Question", "Waiting for you") beside an icon. A tap on a row SHALL open that chat; a tap elsewhere SHALL open the chat of the oldest request. It SHALL NOT show a command, question text or secret name.

#### Scenario: Three requests waiting

- **WHEN** three requests are open in three chats
- **THEN** the medium widget shows 3 and three rows, each with its chat title and kind word

#### Scenario: Small size

- **WHEN** the widget is small and an approval is the oldest request
- **THEN** it shows the count and "Approval", and a tap opens that request's chat

#### Scenario: Nothing waiting

- **WHEN** no request is open
- **THEN** the widget shows "Nothing waiting" and a tap opens the chat list

### Requirement: Board widget

The Board widget SHALL come in small and medium sizes and show, in this order, the last failed scheduled job (name, age, an icon and "Failed"), the Kanban counts of blocked and in-review tasks, and the next run. Small shows the first two parts the server offers, medium up to three. A part whose feature the server lacks SHALL be left out. Each part SHALL open its place in the app.

#### Scenario: Failed job

- **WHEN** the job "Backup" failed and the user taps it in the widget
- **THEN** Hermes opens the Schedules tab on "Backup"

#### Scenario: Server without Kanban

- **WHEN** the snapshot's `kanban` is null
- **THEN** the widget shows only the schedules parts

#### Scenario: Neither feature

- **WHEN** the server offers neither Kanban nor schedules
- **THEN** the widget shows "No board or schedules on this server"

#### Scenario: Next run has passed

- **WHEN** the next run's time is in the past and the app has not written a new snapshot
- **THEN** the next-run part reads "Due"

### Requirement: Redacted rows while App Lock is on

While App Lock is on the snapshot holds no titles, snippets or job names. The widgets SHALL then draw a placeholder bar where a title, snippet or job name would be, never an invented title, and SHALL describe it to screen readers as "Hidden". Counts, ages, kind words and taps SHALL work as without App Lock, and a tap SHALL open the app, which asks for App Lock before showing the chat.

#### Scenario: Recent chats with App Lock on

- **WHEN** App Lock is on and the medium Recent chats widget is shown
- **THEN** it shows three rows with placeholder bars and their ages, no title or snippet, and a tap opens Hermes behind App Lock

#### Scenario: Needs you with App Lock on

- **WHEN** App Lock is on and two approvals are open
- **THEN** the widget shows 2 and two rows labelled "Approval" with placeholder bars

### Requirement: Home screen only and sample content in the picker

The widgets SHALL be declared for the home screen only and SHALL NOT be offered for the lock screen (keyguard), because Android cannot hide content in a widget on a locked device. The widget picker SHALL show static sample content from the widget's own resources, never the user's chats.

#### Scenario: Picker

- **WHEN** the user opens the widget picker with chats in the app
- **THEN** the Hermes previews show sample titles, not the user's

#### Scenario: Lock screen

- **WHEN** the user looks for Hermes among the lock screen widgets of a device that offers them
- **THEN** none is listed

### Requirement: Sizes, rows and touch targets

Every tappable row SHALL be at least 48 dp tall. A widget SHALL show as many of its rows as fit at that height and drop the rest from the bottom, never shrinking a row below 48 dp. At a text scale over 130% the snippet SHALL be dropped before any row. Titles SHALL wrap to two lines before they are cut, and text SHALL honour the system text size with no cap.

#### Scenario: Resized shorter

- **WHEN** the medium Recent chats widget is resized to a height that holds two rows
- **THEN** it shows the two newest chats

#### Scenario: Largest text size

- **WHEN** the system text size is the largest and the widget is medium
- **THEN** the snippet is gone and the rows that still fit at 48 dp are shown with titles on up to two lines

### Requirement: Appearance and accessibility

The widgets SHALL follow the system light or dark theme. On Android 12 and newer they SHALL use the system's wallpaper-derived colours; below it they SHALL use the Hermes palette. Text SHALL meet 4.5:1 contrast on its background. Status SHALL never be colour alone: a failed job SHALL carry an icon and the word "Failed", a request kind an icon and its word. Each tappable row SHALL have a content description that never contains a title while App Lock is on.

#### Scenario: Dark theme

- **WHEN** the device switches to dark theme
- **THEN** the widgets are drawn on a dark surface with light text, without the app running

#### Scenario: Failed job without colour

- **WHEN** the Board widget shows a failed job on a monochrome display
- **THEN** the job is still marked by its icon and "Failed"

### Requirement: Taps open snapshot links

A tap SHALL open the app at the `hermes://` link the snapshot holds for that row, unchanged, as the iPhone widgets do. A link of another scheme SHALL never be followed, and such a row SHALL be skipped. Signed out, a tap SHALL open the app as it is. If Hermes is not running the tap SHALL start it and deliver the link once the app is up.

#### Scenario: Cold start

- **WHEN** Hermes is not running and the user taps a chat row
- **THEN** Hermes starts and opens that chat

#### Scenario: Foreign link

- **WHEN** a snapshot row carries an `https://` link
- **THEN** the widget does not show that row

### Requirement: Refresh

After each snapshot write the app SHALL ask the system to redraw the widgets. The widgets SHALL also redraw at least every 30 minutes without the app running, so ages, the six-hour note and "Due" move on. A redraw SHALL read the stored snapshot only and make no network request.

#### Scenario: Reply finished

- **WHEN** a reply completes while the app is open and a Recent chats widget is on the home screen
- **THEN** within a few seconds the widget shows that chat first

#### Scenario: App never opened again

- **WHEN** the snapshot is six hours old and the app has not run since
- **THEN** within about 30 minutes the widget shows "Open Hermes to refresh"

### Requirement: Telemetry without content

At most once a day the app SHALL log `widgets.installed` with the Android widgets' kinds and counts (family `android`). A widget that cannot be redrawn after a snapshot write SHALL be logged as `widgets.reload_failed` with the kind and the error type. Neither SHALL contain titles, snippets, ids or profile names, and neither SHALL affect the app.

#### Scenario: Two widgets installed

- **WHEN** one Recent chats and two Board widgets are on the home screen
- **THEN** the report says `HermesBoard/android=2,HermesRecentChats/android=1`

### Requirement: Backend contract

The widgets SHALL rely on no Hermes route, RPC method or minimum version of their own; their data comes from the surface snapshot the app writes from the routes it already uses.

#### Scenario: Any supported server

- **WHEN** the app is connected to the oldest Hermes it supports
- **THEN** the widgets work, leaving out the Kanban or schedules part when that server lacks it
