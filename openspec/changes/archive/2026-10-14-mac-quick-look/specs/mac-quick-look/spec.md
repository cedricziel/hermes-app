# Spec Delta

## Purpose

Describes selecting and opening a chat or Kanban attachment like Finder on macOS, and previewing it in the Quick Look panel: how an attachment becomes selected, what double-click, Space and the context menu do, the loading and failure states, and how the downloaded file is kept and removed.

## ADDED Requirements

### Requirement: Select and open like Finder

On macOS, a single click on an attachment SHALL select it and show a selection state; a double-click SHALL open it with the action a single click performs today (a chat file card downloads and opens the file, a chat image thumbnail opens the full-screen image, a Kanban row downloads and opens the file). The attachments that can be selected are a chat file card, a chat image thumbnail, and a row of a Kanban task's attachment list. At most one attachment is selected at a time. A secondary click SHALL select the attachment before its menu opens. Hovering SHALL NOT select. Selection SHALL end when the user clicks outside the attachment, moves focus to another control such as the composer, or tabs away. The attachment SHALL also be reachable by Tab, selected when it takes keyboard focus, and Enter SHALL open the selected attachment. The selection state SHALL be visible in light and dark themes and SHALL NOT rely on colour alone (an outline and a fill). This requirement applies on macOS only; on other platforms a single click opens the attachment as before and there is no selection state.

#### Scenario: Click selects

- **WHEN** the user clicks a file card in a chat
- **THEN** the card shows the selection state and the file does not open

#### Scenario: Double-click opens

- **WHEN** the user double-clicks a selected or unselected chat file card
- **THEN** the card shows "Downloading…" and the file opens as a single click did before

#### Scenario: Kanban row

- **WHEN** the user double-clicks a Kanban task attachment
- **THEN** the file is downloaded and opened, and a single click only selects it

#### Scenario: Hover does not select

- **WHEN** the pointer rests over an attachment
- **THEN** the attachment is not selected and Space does nothing to it

#### Scenario: One selection

- **WHEN** attachment A is selected and the user clicks attachment B
- **THEN** only B shows the selection state

#### Scenario: Click outside clears

- **WHEN** an attachment is selected and the user clicks the empty chat background
- **THEN** no attachment is selected and Space does nothing to an attachment

#### Scenario: Tab reaches the attachment

- **WHEN** the user tabs through the page
- **THEN** each attachment becomes selected in reading order

#### Scenario: Not macOS

- **WHEN** the app runs on iOS, Android, Windows or Linux
- **THEN** a single click opens an attachment, none shows a selection state, no attachment handles Space and no "Quick Look" menu item appears

### Requirement: Space toggles Quick Look

While a selected attachment holds focus, pressing Space (without Command, Control or Option) SHALL toggle the Quick Look panel for it: show it when the panel is closed or shows another file, close it when it already shows this attachment's file. The key SHALL be consumed so it neither scrolls the list nor reaches the menu bar. Space SHALL NOT start a preview while a text field, including the composer or a dictation draft, holds focus, and the composer SHALL keep receiving Space as a space character. Holding the key SHALL NOT repeat the toggle. While the Quick Look panel is key, Space and Escape close it through the system's own handling. Escape on a selected attachment in the app window SHALL do nothing. This requirement applies on macOS only.

#### Scenario: Preview a chat file

- **WHEN** a chat file card is selected and the user presses Space
- **THEN** the card shows "Downloading…" until the file is on the device, then the Quick Look panel shows it

#### Scenario: Space closes

- **WHEN** the panel shows the selected attachment's file and the user presses Space in the app window
- **THEN** the panel closes and no request is made

#### Scenario: Escape closes

- **WHEN** the panel is key and the user presses Escape
- **THEN** the panel closes and the requesting window becomes key

#### Scenario: Typing in the composer

- **WHEN** the composer has focus and the user types a space
- **THEN** a space is inserted and no preview starts

#### Scenario: Composer after selecting

- **WHEN** the user selects an attachment, then clicks the composer and types a space
- **THEN** the attachment is no longer selected and a space is inserted

#### Scenario: Key held down

- **WHEN** the user holds Space on a selected attachment
- **THEN** the panel is toggled once

### Requirement: Context menu

On macOS, a secondary click on an attachment SHALL select it and open a menu with "Quick Look", "Open" and "Save…", in that order. "Quick Look" shows the panel for the attachment (it does not toggle it closed). "Open" does what a double-click does, and "Save…" what the card's save button does for a chat attachment; for a Kanban attachment "Open" downloads it and hands it to the system as a chat file card does, and "Save…" is the existing save. Items for actions the attachment cannot take (a chat attachment with no server path and no local file) SHALL be disabled.

#### Scenario: Quick Look from the menu

- **WHEN** the user secondary-clicks a Kanban attachment and chooses Quick Look
- **THEN** the attachment is selected, the file is downloaded and previewed

#### Scenario: Nothing to fetch

- **WHEN** the user secondary-clicks a chat attachment that has no fetchable path and no local copy
- **THEN** Quick Look, Open and Save… are disabled

### Requirement: Loading and failure

A preview request SHALL show the surface's loading state from the moment it starts until the panel opens or the request fails, and SHALL ignore a second request for the same attachment meanwhile. A request SHALL fail without opening the panel when the download fails (reported with the messages the chat card already uses for missing, refused, too large and failed files; a Kanban attachment reports through the panel's existing error line), when a local file cannot be copied into the cache, or when the panel cannot be shown (reported as "Quick Look couldn't preview this file."). A request for an attachment whose widget has gone, or whose cache was cleared by sign-out, before the file arrived SHALL open nothing. A failed request SHALL leave the attachment selected so Space tries again.

#### Scenario: Download fails

- **WHEN** the server answers 404 for the attachment
- **THEN** no panel opens and the card says "This file is no longer available."

#### Scenario: Signed out meanwhile

- **WHEN** the user signs out while a file is downloading for preview
- **THEN** the panel does not open and no file stays in the cache

#### Scenario: Second press while loading

- **WHEN** the user presses Space again while the card shows "Downloading…"
- **THEN** no second download starts

### Requirement: One panel

The app SHALL have one Quick Look panel. A preview requested while the panel is open SHALL replace the item shown. The panel SHALL work from the main window and from a conversation window. Closing the panel by Space, Escape or its close button SHALL return focus to the window that requested it. Sign-out SHALL close the panel.

#### Scenario: Replace the item

- **WHEN** the panel shows attachment A and the user presses Space on attachment B in the window behind it
- **THEN** the panel shows B

#### Scenario: Conversation window

- **WHEN** the user presses Space on an attachment in a conversation window
- **THEN** the panel opens over that window

### Requirement: Cached files

Files shown in Quick Look SHALL live in the app's cache directory under the existing media folder, named by the same sanitizing rule as other downloads, so a name from the server cannot leave its folder. A file already downloaded for Open or Save SHALL be reused. Bytes the history embedded SHALL be written there, and a file the user picked from elsewhere on the device SHALL be copied there, so the panel never reads outside the app container. Sign-out SHALL delete all of them. At launch the app SHALL delete cached files older than 24 hours. A download SHALL be written aside and renamed, so a partial file is never previewed.

#### Scenario: Reuse

- **WHEN** the user opens a file and then previews it
- **THEN** the second step makes no request

#### Scenario: Hostile name

- **WHEN** the server names an attachment `../../x`
- **THEN** the file is cached inside its own folder under a safe name

#### Scenario: Stale cache

- **WHEN** the app starts and a cached file was written two days ago
- **THEN** it is deleted

### Requirement: Backend contract

The feature SHALL use only routes the app already calls: `GET /api/files/download?path=` for chat files (`HermesApiClient.fetchManagedFile`) and `GET /api/plugins/kanban/attachments/{id}` for Kanban attachments (`fetchKanbanAttachment`), both as raw bytes with the signed-in session in the header. It SHALL add no route, and needs no Hermes version beyond the one that serves these two routes. The 25 MB Kanban attachment cap and the server's refusal codes (404, 403, 413) apply as they do today.

#### Scenario: No new route

- **WHEN** a preview is requested
- **THEN** the only requests made are the two download routes above, and none carries the token in the URL
