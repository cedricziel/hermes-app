## Context

This change builds on `mac-drag-out-files` (merged), which added `lib/src/drag_out/` and a macOS drag source of its own: `macos/Runner/DragOut.swift` starts the native dragging session and `MacDragOutSource` talks to it over the `hermes_app/drag_out` channel. The plugin spike recorded there is moot; this change adds no dependency and no native code.

- Message text: bubbles are `SelectionArea(FlyerChatTextMessage)` in `chat/widgets/chat_builders.dart`; `MessageActions` (the action bar under a finished reply) holds the text.
- Threads: `MacThreadRow` (inside `MacSourceListTile`) in the sidebar; `threadTranscript(messages)` builds the Markdown, `ThreadHousekeeping.history(thread)` reads every page.

## Goals / Non-Goals

Goals: message text and thread export drag out on macOS, content produced lazily on drop, no change to existing gestures. Non-goals are in `proposal.md`.

## Decisions

### Builds on the Swift drag source

Text and file drags both go through `DragOut` / `DragOutSource`. The channel already handles `type: text` (an `NSPasteboardItem` with `public.utf8-plain-text` and `net.daringfireball.markdown`), and `type: file` promises. This change adds the `text` and `thread` kinds to `DragOutKind` and `history` to `DragOutFailure`, and lets a `DragOutFile` name the step its read failed at (`failure:`), which `MacDragOutSource` logs for a failed read and for a promise Swift gave up on.

### Message text: a grip, plain text and Markdown only

`SelectionArea` consumes pointer drags to select, so the text cannot be the drag handle. `MessageDragGrip` (`chat/widgets/message_drag_grip.dart`) wraps the message (the `SelectionArea` bubble of a sent message or of a finished reply, in `_buildText`) and, under the pointer, shows a grip (`AppIcons.dragHandle`) at its top end. The grip is a `DragOut` whose item is `DragOutText(message.text)`: the native side offers the same source text as plain text and as Markdown, so a notes app can pick the richer one and a text field takes the plain one. No `message.md` file is offered: an app that only takes files has the thread export. The grip appears only where a `DragOutSource` is provided (macOS), for a non-empty text, and not for a reply that is still streaming (`kMetaStreaming`). It does not touch `MessageActions`, so the action bar and the attachment widgets are unchanged.

Modifier-key drag and dragging the selection itself conflict with `SelectionArea` and are not offered.

### Threads: a Markdown file with a title heading

`MacThreadRow` is wrapped in `DragOut` in `ThreadSidebar._row` (the key moves to the wrapper); the item is `threadDragItem` (`chat/thread_export.dart`), a `DragOutFile` named by `threadExportFileName` whose `read` returns UTF-8 bytes of:

```
# <chat title>

<threadTranscript(history)>
```

The heading is the raw title, or `Chat` when it is blank (the file name is the sanitized one). The name always ends in `.md`: a dot inside a title (`Release 1.2 notes`) is not an extension. Everything after the blank line is exactly what Copy Transcript copies, so the two can be compared in a test. No timestamp is added. A thread with no messages, or only turns without text, yields the heading alone, so the file is never empty. Calling `history` when the housekeeping is null falls back to the loaded messages, as Copy Transcript does. A thread that is not `remote` yields no item. A history failure (`failure: DragOutFailure.history` on the item) produces no file and is logged as `history`; so is a promise Swift gave up on after 60 s.

`threadTranscript` is imported from `thread_actions_menu.dart` as is; the import is not circular. The content is UTF-8 bytes, so it crosses the channel as bytes (`DragOutFile.read`, no `localPath`): a long thread is text, far below the 25 MB attachment bound.

### Gestures on the row

`MacThreadRow` is not slidable (`Slidable` is used only in non-macOS rows), so it never shares a row with drag-out. `MacDragOutSource` starts a drag only after the primary button moved 6 px and listens to the pointer stream, not the gesture arena, so a click, a double-click that opens a window and a right-click menu keep working. A press on the hover buttons that then moves 6 px also drags the row; that is accepted. The tests and the manual check cover select, double-click, right-click and the hover buttons.

### Affected platforms and native changes

macOS only. No entitlement, no Info.plist key, no Swift change, no dependency. Other platforms and conversation windows provide no source, so the row and the grip are as before.

### Invariants touched

- API layering: history goes through `HermesChatRepository` via `ThreadHousekeeping`; no Dio calls in the drag layer.
- Auth: reads use the managed client; a drop after sign-out fails and is logged as failed.
- Telemetry must never break the app: the adapter's telemetry swallows its own errors.
- Tests use the real client against `FakeHermesServer`; only `DragOutSource` is faked.

### Observability

Uses the adapter's breadcrumb, span and log event from `mac-drag-out-files`; this change only adds the `text` and `thread` kinds and the `history` failure. A text drag logs `delivered` or `cancelled` when the session ends. None carries names, titles, text, ids or sizes. The allow-list test from that change is extended with the new values.

## Risks / Trade-offs

- A long thread takes several history requests before the file appears; the receiver waits (Finder shows progress). The span shows how long.
- The heading puts the title in the file; this is the user's own chat going where they dropped it.
- The grip adds a visible control on hover.

## Migration Plan

None; no stored data. Rollback removes the wraps.
