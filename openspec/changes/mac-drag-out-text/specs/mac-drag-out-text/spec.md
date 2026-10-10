## Purpose

Lets macOS users drag message text and whole chats out of Hermes into other apps and Finder, as text and Markdown.

## ADDED Requirements

### Requirement: Drag message text out as plain text and Markdown

On macOS, on hover, a message SHALL show a drag grip. Dragging it SHALL offer the message's Markdown source as plain text and as Markdown, and SHALL NOT offer a file; dropping on a text field inserts the text. Text selection in the message SHALL be unaffected. A message with no text SHALL show no grip. The text of a reply that is still streaming SHALL NOT be draggable until it finishes. On other platforms no grip is shown.

#### Scenario: Drop into a notes app

- **WHEN** the user drags the grip of a finished reply into a text document
- **THEN** the reply's Markdown text is inserted

#### Scenario: Streaming reply

- **WHEN** a reply is still streaming
- **THEN** its grip is not shown

#### Scenario: Drop on Finder

- **WHEN** the user drops a message's grip on a Finder window
- **THEN** no file is created

### Requirement: Drag a thread out as a Markdown file

A thread row in the Mac sidebar SHALL be draggable to Finder, producing `<title>.md`. The file SHALL start with `# <chat title>`, a blank line, then the same Markdown that Copy Transcript puts on the clipboard. The content SHALL be produced when the drop lands, reading every page of history that is not loaded. Titles SHALL be made safe as file names; an empty title becomes `Chat`. Only threads saved on the server SHALL be draggable. A thread whose history cannot be read SHALL produce no file. A thread with no messages SHALL produce the heading alone. Selecting, double-click to open a window, right-click and the hover buttons SHALL keep working.

#### Scenario: Long thread, unloaded pages

- **WHEN** a thread with 3 unloaded pages is dropped on the Desktop
- **THEN** the file holds the heading and all turns in order, not only the loaded ones

#### Scenario: Hostile title

- **WHEN** a thread is titled `../../x/y: z`
- **THEN** the file name has no path separators or colon and stays inside the drop folder

#### Scenario: Unsaved chat

- **WHEN** the chat has not been saved to the server
- **THEN** its row is not draggable

#### Scenario: History unreadable

- **WHEN** the history request fails during the drop
- **THEN** no file is created

### Requirement: Backend contract

The feature SHALL use only routes the app already calls: the session history routes read by `HermesChatRepository`. It SHALL NOT require a new Hermes route and has no minimum Hermes version beyond what chat needs today.

#### Scenario: Message text needs no server

- **WHEN** the user drags a message's grip
- **THEN** no request is made

### Requirement: Observability without content

Each drag SHALL record a `drag_out.started` breadcrumb (kind only). Each drop that produced or failed to produce data SHALL log `drag_out.completed` with kind (`text` or `thread`), outcome and failure step. Spans, logs and breadcrumbs SHALL NOT contain names, titles, text, ids, paths or sizes.

#### Scenario: Failed promise

- **WHEN** a thread export fails to read history
- **THEN** one `drag_out.completed` event with `kind: thread`, `outcome: failed`, `failure: history` is logged and nothing else about the thread
