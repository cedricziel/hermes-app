# Spec Delta

## Purpose

Keeps the Mac sidebar visible while a sub-page of the chat shell is open.

## ADDED Requirements

### Requirement: Sub-pages open beside the sidebar

On macOS, a sub-page of the chat shell (Profiles, Messaging, Skills, Plugins, MCP servers, Tools, Providers, Helper models, Memory, Files, Kanban board and task pages, and server-care pages) SHALL open in the content area, with the sidebar kept beside it, instead of over the whole window.

#### Scenario: Open Skills from the sidebar

- **WHEN** the user opens Skills in a window wide enough for a docked sidebar
- **THEN** the Skills page fills the content area and the sidebar stays visible and usable

#### Scenario: Compact window

- **WHEN** the window is narrower than the docked-sidebar width and the user opens a sub-page
- **THEN** the page fills the window and the sidebar opens over it from the toolbar button

### Requirement: Routes that stay window wide

Connection details, sign-in, the voice call screen, the Bot Screen viewer, media and Quick Look viewers, and every dialog, sheet and popup menu SHALL stay above the whole window.

#### Scenario: Dialog from a sub-page

- **WHEN** a sub-page opens a confirmation dialog
- **THEN** the dialog covers the whole window as it does today

### Requirement: Back from a sub-page

Back, ⌘[ and ⌘] SHALL move through sub-pages as they do today, and Back from the first sub-page SHALL show the content the user came from.

#### Scenario: Back

- **WHEN** the user opens Memory from the chat and presses ⌘[
- **THEN** the chat is shown again in the content area and its row in the sidebar is selected again

#### Scenario: Dialog over the page

- **WHEN** a dialog is open over a sub-page and the user presses ⌘[
- **THEN** the dialog is not treated as a page and the sub-page stays

### Requirement: The sidebar works while a sub-page is open

Choosing a chat or a destination in the sidebar SHALL close the open sub-pages and show the choice.

#### Scenario: No chat row selected while a sub-page is open

- **WHEN** the user opens Skills from a chat
- **THEN** the Chat destination stays current and no chat row is selected until the user goes back or picks a chat

#### Scenario: Pick a chat

- **WHEN** a sub-page is open and the user picks a chat in the sidebar
- **THEN** the sub-pages close and that chat is shown

### Requirement: Sub-pages end with the connection and under App Lock

A sub-page SHALL be removed when the connection ends by sign-out, server change or session expiry, and SHALL be covered while App Lock covers the app.

#### Scenario: Sign out with a sub-page open

- **WHEN** the connection ends while Files is open in the content area
- **THEN** the page is gone in the same frame the sign-in screen appears, and its downloads are cleared

#### Scenario: Lock with a sub-page open

- **WHEN** App Lock covers the app while a sub-page is open
- **THEN** the sub-page is covered and shows no content under the cover

### Requirement: Layout at the narrowest docked width

A sub-page in the content area SHALL lay out for the width of the content area, not for the width of the window.

#### Scenario: Window 760 wide

- **WHEN** a sub-page with a list and details is open in a 760 point wide window with the sidebar docked
- **THEN** it shows the stacked layout and nothing is clipped or unreachable

### Requirement: Other platforms unchanged

iOS, iPadOS, Android, Windows and Linux SHALL keep opening sub-pages over the whole window.

#### Scenario: iPhone

- **WHEN** the user opens Skills on an iPhone
- **THEN** the page is pushed as before

### Requirement: Backend contract

Keeping the sidebar SHALL rely on no Hermes route, RPC method or minimum Hermes version; the sub-pages make the same requests they make today.

#### Scenario: Any supported server

- **WHEN** the app is connected to the oldest Hermes it supports
- **THEN** sub-pages open beside the sidebar as on the newest one
