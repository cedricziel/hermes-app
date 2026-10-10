## Purpose

Lets macOS users drag chat attachments and Kanban task attachments out of Hermes into Finder and other apps as files.

## ADDED Requirements

### Requirement: Drag out is a macOS feature

On macOS the app SHALL offer the drag sources below. On iOS, Android, Windows and Linux it SHALL offer no drag-out, and the affected widgets SHALL behave as before. The app SHALL work when the drag-out plugin is absent or fails to start a drag.

#### Scenario: Other platform

- **WHEN** the app runs on Windows, Linux, iOS or Android
- **THEN** no drag affordance is shown and no drag session is started

#### Scenario: Plugin cannot start a drag

- **WHEN** the system refuses to start a drag
- **THEN** the click or selection the user made still works and no error is shown

### Requirement: Drag a chat attachment out as a file

A file or image attachment card in a message SHALL be draggable to Finder, Mail and other file drop targets. The dropped file SHALL carry the attachment's display name. An attachment already on this device (picked path, embedded bytes, downloaded cache) SHALL be dropped from that source. An attachment that exists only on the server (`fetchPath`) SHALL be fetched when the receiver asks for the file, through the existing media store. An attachment that cannot be fetched (relative server path) SHALL NOT start a drag. Tap, Save and image viewing SHALL keep working.

#### Scenario: Drop a downloaded report

- **WHEN** the user drags a PDF attachment card onto a Finder window
- **THEN** a file with the attachment's name and the server's bytes appears there

#### Scenario: Fetch fails

- **WHEN** the receiver asks for the file and the server answers 404
- **THEN** the drop produces no file, the card shows its existing "no longer available" notice and a `drag_out.completed` event with `outcome: failed` is logged

#### Scenario: Not downloadable

- **WHEN** an attachment has only a workspace-relative server path
- **THEN** dragging it does nothing

#### Scenario: Hostile name

- **WHEN** an attachment is named `../../x/y: z.pdf`
- **THEN** the dropped file's name has no path separators or colon and keeps the `.pdf` extension

### Requirement: Drag a Kanban task attachment out as a file

Each attachment row in the Kanban task panel SHALL be draggable as a file named by `filename`, fetched with the signed-in client from `GET /api/plugins/kanban/attachments/{id}` (with `board` when the task's board is not the default) when the receiver asks. The existing Save and Remove buttons SHALL keep working, and a transfer in progress SHALL not block dragging. The in-app Kanban card drag between columns SHALL be unchanged.

#### Scenario: Drag to Finder

- **WHEN** the user drags an attachment row to the Desktop
- **THEN** the file with that name and the attachment's bytes is created

#### Scenario: Card drag unchanged

- **WHEN** the user drags a card between columns
- **THEN** it moves as before and no native drag session starts

### Requirement: Drag-out coexists with drops and gestures

Adding drag sources SHALL NOT stop the chat from accepting dropped files or `SelectionArea` from selecting text. A drag of a file from outside the app onto the chat SHALL still attach it.

#### Scenario: Drop still attaches

- **WHEN** the user drops a file from Finder on the chat
- **THEN** it is attached as before

### Requirement: Backend contract

The feature SHALL use only routes the app already calls: `GET /api/files/download?path=` and `GET /api/media` (through `MediaSource`) and `GET /api/plugins/kanban/attachments/{id}`. It SHALL NOT require a new Hermes route and has no minimum Hermes version beyond what those screens need today.

#### Scenario: Older Hermes without Kanban

- **WHEN** the server has no Kanban plugin
- **THEN** only chat attachments are draggable, as the Kanban tab is absent

### Requirement: Observability without content

Each drag SHALL record a `drag_out.started` breadcrumb (kind only). Each drop that produced or failed to produce data SHALL log `drag_out.completed` with kind, outcome and failure step. Spans, logs and breadcrumbs SHALL NOT contain names, titles, text, ids, paths or sizes.

#### Scenario: Failed promise

- **WHEN** a Kanban attachment fetch fails
- **THEN** one `drag_out.completed` event with `kind: kanban_attachment`, `outcome: failed`, `failure: fetch` is logged and nothing else about the attachment
