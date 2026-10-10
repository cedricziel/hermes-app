## Why

On macOS nothing can be dragged out of the app. People expect to drag a reply into a notes app and a chat out of the sidebar to keep it as a file. Today they have to use Copy Transcript and a file dialog.

This change depends on `mac-drag-out-files`, which chooses the drag plugin (spike), adds `lib/src/drag_out/` and lands first. It adds no dependency of its own.

## What Changes

- **Message text**: a message's text drags out through a grip shown on hover, because the text itself belongs to `SelectionArea`. The drag offers two representations of the message's Markdown source: plain text and Markdown. It does not offer a `.md` file.
- **Sidebar threads**: a thread row drags to Finder as `<title>.md`. The file starts with a `# <chat title>` heading, then the Markdown of Copy Transcript. It is a file promise, so the history (including unloaded pages) is read only when the drop lands.

Both use `DragOutSource`, `DragOutText`, `DragOutFile` and `sanitizeDragFileName` from `mac-drag-out-files`.

## Capabilities

### New Capabilities

- `mac-drag-out-text`: Drag message text and chat transcripts out of the macOS app as text and Markdown.

### Modified Capabilities

None. Copy Transcript, text selection and the sidebar row gestures keep their behaviour.

## Impact

- Wraps `MacThreadRow` (in `ThreadSidebar._row`) and `MessageActions` / the sent bubble. Adds a thread export function that builds `# <title>\n\n` plus `threadTranscript(messages)`.
- Reuses `threadTranscript`, `ThreadHousekeeping.history` and `AppIcons.dragHandle`. No new routes, no OpenAPI or generated client change, no dependency change.
- Widgetbook use cases for the grip and the draggable thread row; tests against `FakeHermesServer` for the exported content.
- Size: about 400 lines in one PR, after `mac-drag-out-files` is merged.

### Non-goals

- Attachments and Kanban attachments (`mac-drag-out-files`).
- Dragging a selection of text (`SelectionArea` keeps owning selection), multi-select of threads, dragging a whole message with its attachments as one item.
- A `.md` file for a dragged message; apps that take only files can use the thread export.
- Formats other than Markdown, or attachments in a thread export. A timestamp in the exported file.
- Windows, Linux, iOS, Android, other windows of the app, and conversation windows.

### Security and privacy

Dragging out hands content to whatever app receives it, which the user chose by dropping. The thread file is written by the app only when the receiver asks, into the destination the receiver gives. Nothing is added to tokens, secure storage or preferences, and history is read with the signed-in client. The thread title is sanitized into a safe file name (no path separators, no leading dots, bounded length; an empty title becomes `Chat`). The title appears in the file content as the heading, which is the user's own data going where they dropped it. The drag adds no content to the pasteboard that remains after it ends. No entitlement is added.

### Observability

Same events as `mac-drag-out-files`, with the new values:

- **Log event** `drag_out.completed`: `kind` `text|thread`, `outcome` (`delivered|failed|cancelled`), `failure` `history|write` for threads. No titles, text, ids or sizes.
- **Span** `drag_out.promise` around the history read, with `kind` and the connection's `hermes.*` attributes.
- **Breadcrumb** `drag_out.started` with `kind` only.
