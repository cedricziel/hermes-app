## Context

This change builds on `mac-drag-out-files`, which records the plugin decision (`super_drag_and_drop` or a Swift channel), the `desktop_drop` coexistence result and `lib/src/drag_out/`. If that spike falls back to the Swift channel, only the adapter changes; the decisions here do not.

- Message text: bubbles are `SelectionArea(FlyerChatTextMessage)` in `chat/widgets/chat_builders.dart`; `MessageActions` (the action bar under a finished reply) holds the text.
- Threads: `MacThreadRow` (inside `MacSourceListTile`) in the sidebar; `threadTranscript(messages)` builds the Markdown, `ThreadHousekeeping.history(thread)` reads every page.

## Goals / Non-Goals

Goals: message text and thread export drag out on macOS, content produced lazily on drop, no change to existing gestures. Non-goals are in `proposal.md`.

## Decisions

### Depends on mac-drag-out-files

Land that change first. This one adds no package and no native code. Plugin staleness, Rust builds on CI and the `desktop_drop` interplay are decided there.

### Message text: a grip, plain text and Markdown only

`SelectionArea` consumes pointer drags to select, so the text cannot be the drag handle. `MessageActions` (finished replies) and sent bubbles get a grip (a draggable around `AppIcons.dragHandle`) visible on hover. The item is `DragOutText(message.text)`. The adapter offers it as plain text (`public.utf8-plain-text`) and as Markdown (`net.daringfireball.markdown`), both carrying the same source text, so a notes app can pick the richer one and a text field takes the plain one. No `message.md` file is offered: an app that only takes files has the thread export. Streaming messages are skipped (`kMetaStreaming`), as are messages with no text.

If the grip is judged noisy it stays hidden until hover (current design). Modifier-key drag and dragging the selection conflict with `SelectionArea`.

### Threads: a Markdown file with a title heading

`MacThreadRow` is wrapped in `DragOutSource.wrap`; the item is a `DragOutFile` named `sanitizeDragFileName(title, fallback: 'Chat', extension: 'md')` whose `read` returns UTF-8 bytes of:

```
# <chat title>

<threadTranscript(history)>
```

The heading is the raw title (the file name is the sanitized one). Everything after the blank line is exactly what Copy Transcript copies, so the two can be compared in a test. No timestamp is added. A thread with no messages yields the heading alone, so the file is never empty. Calling `history` when the housekeeping is null falls back to the loaded messages, as Copy Transcript does. A thread that is not `remote` yields no item. A history failure produces no file and logs `failure: history`.

`threadTranscript` is imported from `thread_actions_menu.dart` as is; it moves to its own file only if the import would be circular.

### Gestures on the row

`MacThreadRow` is not slidable (`Slidable` is used only in non-macOS rows), so it never shares a row with drag-out. The plugin's drag hit slop keeps a click, a double-click that opens a window and a right-click menu working. The tests and the manual check cover select, double-click, right-click and the hover buttons.

### Affected platforms and native changes

macOS only. No entitlement, no Info.plist key, no pod change beyond `mac-drag-out-files`. Other platforms get `NoDragOutSource`.

### Invariants touched

- API layering: history goes through `HermesChatRepository` via `ThreadHousekeeping`; no Dio calls in the drag layer.
- Auth: reads use the managed client; a drop after sign-out fails and is logged as failed.
- Telemetry must never break the app: logging in the adapter is wrapped in `safely`.
- Tests use the real client against `FakeHermesServer`; only `DragOutSource` is faked.

### Observability

Uses the adapter's breadcrumb, span and log event from `mac-drag-out-files`; this change only adds the `text` and `thread` kinds and the `history` failure. None carries names, titles, text, ids or sizes. The allow-list test from that change is extended with the new values.

## Risks / Trade-offs

- A long thread takes several history requests before the file appears; the receiver waits (Finder shows progress). The span shows how long.
- The heading puts the title in the file; this is the user's own chat going where they dropped it.
- The grip adds a visible control on hover.

## Migration Plan

None; no stored data. Rollback removes the wraps.
