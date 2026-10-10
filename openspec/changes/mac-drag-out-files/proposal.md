## Why

On macOS the app takes drops (`desktop_drop` on the chat) but nothing can be dragged out. People expect to drag an attachment to Finder or a mail draft. Today they have to use Save and a file dialog.

This change adds the drag-out layer and its macOS native source, and uses it for the two file sources. `mac-drag-out-text` (message text and thread export) depends on it.

## What Changes

- **Chat attachments**: a file or image in a message card drags out as a file, named as in the message.
- **Kanban task attachments**: each row in the task panel drags out as a file fetched with `fetchKanbanAttachment`.
- A small drag-out layer (`DragOutSource`, value types, file name sanitizer, observability) that the text change reuses.
- A small Swift drag source behind a method channel (`NSFilePromiseProvider` for files, an `NSPasteboardItem` for text). A spike built `super_drag_and_drop` first and rejected it: see the design.

The platform code sits behind `DragOutSource`, so widgets and tests never touch it. `desktop_drop` stays the only drop target.

## Capabilities

### New Capabilities

- `mac-drag-out-files`: Drag chat attachments and Kanban attachments out of the macOS app as files.

### Modified Capabilities

None. Existing attachment drop, Save and the in-app Kanban card drag keep their behaviour.

## Impact

- No new dependency. `macos/Runner/DragOut.swift` is added to the Runner target (with its tests in `RunnerTests`) and registered by one line in `MainFlutterWindow.swift`.
- New `lib/src/drag_out/` (value types, source interface, macOS adapter, no-op adapter), wrapped around `AttachmentCard` / `AttachmentThumbnail` and `KanbanTaskAttachments`.
- Reuses `MediaStore.file` and `KanbanRepository.downloadAttachment`. No new routes, no OpenAPI or generated client change.
- Widgetbook use cases for the two drag affordances; tests against `FakeHermesServer` for the promised bytes.
- Size: about 500 lines in one PR. The spike's result, and why the PR uses a Swift channel, is in `design.md`.

### Non-goals

- Message text and thread export (`mac-drag-out-text`).
- Windows and Linux: not verified or required here. The adapter is the only macOS-gated code.
- iOS and Android drag-out, and dragging to other windows of the app, including conversation windows.
- Multi-select of attachments, dragging a whole message with its attachments as one item.
- Dragging tool-call output, images embedded as data URLs beyond the attachment card, or Kanban cards out of the app (cards keep the in-app drag only).
- Replacing `desktop_drop`.
- Anything in the `hermes://` deep-link router or actionable notifications.

### Security and privacy

Dragging out hands content to whatever app receives it, which the user chose by dropping. Files are written by the app only when the receiver asks for them, into the destination the receiver gives. Nothing is added to tokens, secure storage or preferences. Downloads reuse the signed-in client, so the session token stays in headers. Attachment names are sanitized into safe file names before they reach the promise (no path separators, no leading dots, bounded length). The drag adds no content to the pasteboard that remains after it ends. No sandbox entitlement is added (promised files are written to the receiver's URL, which the sandbox allows).

### Observability

- **Log event** `drag_out.completed` through `AppEventLogger`: attributes `kind` (`attachment|kanban_attachment`; the text change adds `text|thread`), `outcome` (`delivered|failed|cancelled`) and `failure` (`fetch|write`; the text change adds `history`). It counts use and failed promises, which are invisible otherwise. No names, titles, ids, text or sizes.
- **Span** `drag_out.promise` around the fetch triggered by a drop, with the connection's `hermes.*` attributes and `kind`. The work crosses the network and can be slow, so a span shows how long a drop waited. The underlying HTTP spans already exist.
- **Breadcrumb** `drag_out.started` with `kind` only, so a crash during a drag shows what the user was doing.
