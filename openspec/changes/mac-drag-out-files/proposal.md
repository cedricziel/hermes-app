## Why

On macOS the app takes drops (`desktop_drop` on the chat) but nothing can be dragged out. People expect to drag an attachment to Finder or a mail draft. Today they have to use Save and a file dialog.

This change adds the drag-out layer and the plugin decision, and uses it for the two file sources. `mac-drag-out-text` (message text and thread export) depends on it.

## What Changes

- **Chat attachments**: a file or image in a message card drags out as a file, named as in the message.
- **Kanban task attachments**: each row in the task panel drags out as a file fetched with `fetchKanbanAttachment`.
- A small drag-out layer (`DragOutSource`, value types, file name sanitizer, observability) that the text change reuses.
- A spike that decides between `super_drag_and_drop` and a hand-written Swift channel, and checks that it coexists with `desktop_drop`.

Use `super_drag_and_drop` (virtual files, lazy data) behind `DragOutSource`, so widgets and tests do not touch the plugin. Keep `desktop_drop` for drops unless the spike shows the two cannot share the window.

## Capabilities

### New Capabilities

- `mac-drag-out-files`: Drag chat attachments and Kanban attachments out of the macOS app as files.

### Modified Capabilities

None. Existing attachment drop, Save and the in-app Kanban card drag keep their behaviour.

## Impact

- `pubspec.yaml`: add `super_drag_and_drop`. It is a native plugin for every platform the app builds, so Android, iOS, Linux and Windows builds link it too (Android needs the NDK it auto-installs). See the design for the CI cost.
- New `lib/src/drag_out/` (value types, source interface, plugin adapter, no-op adapter), wrapped around `AttachmentCard` / `AttachmentThumbnail` and `KanbanTaskAttachments`.
- Reuses `MediaStore.file` and `KanbanRepository.downloadAttachment`. No new routes, no OpenAPI or generated client change.
- Widgetbook use cases for the two drag affordances; tests against `FakeHermesServer` for the promised bytes.
- Size: about 500 lines in one PR. The spike is a commit at the front of the PR with its result in `design.md`; if the spike fails, the PR becomes the Swift channel and this change is revised before any UI work.

### Non-goals

- Message text and thread export (`mac-drag-out-text`).
- Windows and Linux: the plugin supports them (Linux has no virtual files), but they are not verified or required here. The adapter is the only macOS-gated code, so enabling Windows later is a follow-up.
- iOS and Android drag-out, and dragging to other windows of the app, including conversation windows.
- Multi-select of attachments, dragging a whole message with its attachments as one item.
- Dragging tool-call output, images embedded as data URLs beyond the attachment card, or Kanban cards out of the app (cards keep the in-app drag only).
- Replacing `desktop_drop` with `super_drag_and_drop`'s drop side, unless the spike forces it.
- Anything in the `hermes://` deep-link router or actionable notifications.

### Security and privacy

Dragging out hands content to whatever app receives it, which the user chose by dropping. Files are written by the app only when the receiver asks for them, into the destination the receiver gives. Nothing is added to tokens, secure storage or preferences. Downloads reuse the signed-in client, so the session token stays in headers. Attachment names are sanitized into safe file names before they reach the promise (no path separators, no leading dots, bounded length). The drag adds no content to the pasteboard that remains after it ends. No sandbox entitlement is added (promised files are written to the receiver's URL, which the sandbox allows).

### Observability

- **Log event** `drag_out.completed` through `AppEventLogger`: attributes `kind` (`attachment|kanban_attachment`; the text change adds `text|thread`), `outcome` (`delivered|failed|cancelled`) and `failure` (`fetch|write`; the text change adds `history`). It counts use and failed promises, which are invisible otherwise. No names, titles, ids, text or sizes.
- **Span** `drag_out.promise` around the fetch triggered by a drop, with the connection's `hermes.*` attributes and `kind`. The work crosses the network and can be slow, so a span shows how long a drop waited. The underlying HTTP spans already exist.
- **Breadcrumb** `drag_out.started` with `kind` only, so a crash during a drag shows what the user was doing.
