# Sharing Specification

## Purpose

Describes how content shared from other apps through the operating system's share sheet reaches Hermes: the share targets per platform, the hand-off from the native side to the app, how shared items are held until the chat is ready, and how they appear in the chat composer. Sharing only fills the composer; nothing is sent until the user sends it.

## Requirements

### Requirement: Hermes is a share target on iOS, Android and macOS

The system SHALL register Hermes in the share sheet of iOS (a share extension), Android (an intent filter for single and multiple `SEND` of any MIME type) and macOS (a share extension). The iOS and macOS extensions SHALL accept text, one web URL, up to 10 images and up to 10 files per share. On Linux, Windows and the web the app SHALL have no share target and SHALL ignore sharing.

#### Scenario: Share from another app on a phone

- **WHEN** the user shares a link or a file to Hermes from the share sheet on iOS or Android
- **THEN** Hermes opens and the shared content is offered in the chat composer

#### Scenario: Unsupported desktop platform

- **WHEN** the app runs on Linux or Windows
- **THEN** no share content is ever received and the app is unaffected

### Requirement: iOS and Android hand-off

On iOS and Android the system SHALL receive shared content through the `receive_sharing_intent` plugin. The iOS share extension SHALL store the shared content in the shared App Group container and open Hermes. Content that launched the app SHALL be read once at startup and the platform SHALL then be told it has been handled so that it is not delivered again on the next start. Content shared while the app is running SHALL arrive as a stream.

#### Scenario: Content launches the app

- **WHEN** the app is started by a share
- **THEN** the shared items are collected and the platform's launch data is reset

#### Scenario: Content shared while running

- **WHEN** the app is already running and the user shares to it
- **THEN** the items are delivered without restarting the app

### Requirement: Shared item mapping on iOS and Android

The system SHALL turn shared text and shared URLs into text items, using the shared string as-is, and SHALL turn shared images, videos and other files into file items carrying the file path, a display name (the last path segment), the MIME type when known, and whether the file is an image.

#### Scenario: Link and text

- **WHEN** a text and a URL are shared
- **THEN** two text items are produced holding those strings

#### Scenario: Image and document

- **WHEN** a PNG and a PDF are shared
- **THEN** two file items are produced named after their files, the first marked as an image

### Requirement: macOS hand-off

On macOS the share extension SHALL copy each shared file into the App Group container, append entries to a pending list there (`{type: "text", text}` or `{type: "file", path, name, mimeType?, isImage}`), open the `hermes-share://share` URL to bring Hermes forward, and finish. Web URLs SHALL be stored as text entries carrying the URL string; plain text as text entries; images and files as file entries. The app SHALL fetch and clear the pending list through the `hermes_app/share` method channel: once at startup, and again whenever the native side reports `shared` while the app is running. Entries that are malformed or of an unknown type SHALL be skipped. If the native side is missing, the result SHALL be empty. Copied files older than seven days SHALL be removed when the list is fetched.

#### Scenario: Share while the app runs

- **WHEN** the extension opens `hermes-share://share` and the native side signals `shared`
- **THEN** the app takes the pending entries and delivers them as shared items

#### Scenario: Signal with nothing pending

- **WHEN** the native side signals `shared` but the pending list is empty
- **THEN** nothing is delivered

#### Scenario: Unknown entries

- **WHEN** the pending list contains an entry of an unknown type, a text entry without text, and a valid text entry
- **THEN** only the valid text entry becomes a shared item

### Requirement: Shared items wait until the chat can take them

The system SHALL keep shared items pending, in the order received, until the chat screen takes them, including through server setup and sign-in. Taking the items SHALL hand them over exactly once and clear them. When the chat takes items that arrive while the Kanban destination is selected, the system SHALL select the Chat destination so the user sees them, and SHALL dismiss the screens pushed over the board (a task, board management, the create form).

#### Scenario: Shared before sign-in

- **WHEN** the user shares to Hermes while signed out
- **THEN** the items stay pending and appear in the composer once the chat screen opens

#### Scenario: Taken once

- **WHEN** the chat screen has taken the pending items
- **THEN** a second take returns nothing

#### Scenario: Shared while Kanban is shown

- **WHEN** the user shares text or a file to Hermes while the Kanban destination is selected
- **THEN** the Chat destination is selected
- **AND** the text is in the composer, or the file is attached

#### Scenario: Shared while a task is open over the board

- **WHEN** the user shares to Hermes while a task, board management or the create form is open over the Kanban board
- **THEN** that screen is dismissed and the Chat destination is selected

### Requirement: Shared text fills the composer

When the chat screen takes shared items, it SHALL join all shared text with newlines and put it in the composer. If the composer already holds a draft, the shared text SHALL be appended on a new line, and the caret SHALL be placed at the end. This SHALL happen both for items pending when the chat opens and for items that arrive while it is open.

#### Scenario: Shared before the chat opens

- **WHEN** two text items are pending as the chat opens
- **THEN** the composer holds them on two lines

#### Scenario: Shared onto a draft

- **WHEN** the composer holds "Summarise:" and a URL is shared
- **THEN** the composer holds "Summarise:" followed by the URL on the next line

### Requirement: Shared files appear as removable attachments

Shared files SHALL appear as chips above the composer input, one per file, each with a "Remove <name>" control. Attachments alone SHALL be enough to send. On send, the message text SHALL be the typed text followed, after a blank line, by "Attached: " and the comma-separated file names, and the attachments SHALL then be cleared. Only the names are sent; the file contents are not uploaded.

#### Scenario: Remove an attachment

- **WHEN** the user removes one of two attached files
- **THEN** its chip disappears and the other remains

#### Scenario: Send attachments only

- **WHEN** the user sends with an attached file "report.pdf" and no typed text
- **THEN** the sent message reads "Attached: report.pdf" and the chip is gone
