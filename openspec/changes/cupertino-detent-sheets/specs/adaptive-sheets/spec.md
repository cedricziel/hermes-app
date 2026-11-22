## ADDED Requirements

### Requirement: iPhone sheets have detents and a grabber

On a compact iOS layout, a sheet opened through the shared adaptive sheet SHALL have rounded top corners, a grabber, and one of three detent profiles chosen by its caller. A `fit` sheet opens at its content's height up to the full height. A `mediumLarge` sheet opens at half of the height below the top safe inset and can be dragged to the full height. A `large` sheet opens at the full height. A drag down from the lowest detent SHALL dismiss the sheet.

#### Scenario: Medium and large

- **WHEN** a `mediumLarge` sheet opens on an iPhone 393 by 852
- **THEN** it is about half the screen tall, dragging its grabber up makes it more than 90% tall, and dragging it down past the lowest stop dismisses it

#### Scenario: Fit

- **WHEN** a `fit` confirmation opens and its content is shorter than half the screen
- **THEN** the sheet is as tall as its content, not half the screen

#### Scenario: Large

- **WHEN** a `large` form sheet opens
- **THEN** it opens at the full height and still dismisses by swipe down

### Requirement: Other platforms keep what they have

On macOS and on wide layouts, including a full-screen iPad, the adaptive sheet SHALL remain a dialog. On Android, Windows and Linux it SHALL remain a Material bottom sheet with its existing handle and height options. The detent profile SHALL have no effect there.

#### Scenario: iPad

- **WHEN** a sheet opens on a full-screen iPad
- **THEN** it is a dialog, as today

#### Scenario: Android

- **WHEN** a sheet opens on an Android phone with a drag handle requested
- **THEN** the Material sheet with its handle is shown

### Requirement: Dismissal respects busy sheets

A swipe down, a barrier tap and the system Back action SHALL go through the sheet's pop guard. A sheet that refuses to close while it works SHALL return to its detent and stay open. Dismissing a confirmation sheet SHALL count as cancel and SHALL NOT send, save or run anything.

#### Scenario: Busy install

- **WHEN** the user swipes down on the MCP install sheet while its install request is in flight
- **THEN** the sheet returns to its detent and the install continues
- **AND WHEN** the install request has been answered and the server is building in the background
- **THEN** a swipe down closes the sheet and the build goes on

#### Scenario: Confirmation dismissed

- **WHEN** the user swipes down on the restore confirmation
- **THEN** no restore request is sent and the chat is unchanged

### Requirement: The sheet never clips its content

When a sheet's content is taller than its detent at a large text size or with the keyboard shown, the sheet SHALL open at the smallest detent that fits, up to the full height, and the content SHALL scroll beyond that. A text field that takes focus SHALL move the sheet to the full height and stay visible. On a phone in landscape, where the available height is under 500 points, every sheet SHALL be full height.

#### Scenario: Large text

- **WHEN** the text scale is 2.0 on a 320 by 568 screen and a `fit` confirmation opens
- **THEN** all of its text and its buttons are reachable

#### Scenario: Typing

- **WHEN** a field in a half-height sheet takes focus
- **THEN** the sheet moves to full height and the field is above the keyboard

#### Scenario: Landscape

- **WHEN** a sheet opens on an iPhone in landscape
- **THEN** it is full height

### Requirement: Every sheet has a way out that is not a gesture

Every iOS sheet SHALL keep a Close, Cancel or Done control of at least 44 points in its content. The grabber of a `mediumLarge` sheet SHALL expose increase and decrease actions to assistive technology that move it between its detents, and SHALL carry an accessible name.

#### Scenario: Screen reader

- **WHEN** a screen reader user focuses the grabber of a model picker sheet and chooses increase
- **THEN** the sheet grows to full height

### Requirement: Each sheet declares its detent

Every call of the shared adaptive sheet in the app SHALL state its detent profile explicitly, and a source-scan check SHALL fail when one does not.

#### Scenario: A new sheet

- **WHEN** a developer adds a call to the adaptive sheet without a detent profile
- **THEN** the architecture check fails and names the three profiles

### Requirement: Sheets record nothing about their content

Opening, resizing or dismissing a sheet SHALL NOT add a breadcrumb, span or log event, and no sheet content SHALL be recorded by this behaviour. App Lock SHALL hide an open sheet with the rest of the app.

#### Scenario: Locked with a sheet open

- **WHEN** App Lock covers the app while a sheet is open
- **THEN** the sheet is hidden and not focusable until unlock
