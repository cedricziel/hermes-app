## Context

macOS takes drops only: `PluginAttachmentSource.dropTarget` wraps the chat in `desktop_drop`'s `DropTarget` (`lib/src/chat/attachments/plugin_attachment_source.dart`, used by `AttachmentSurface`). Nothing starts a native drag. The in-app Kanban card drag (`kanban_card_drag.dart`) uses Flutter's `Draggable`/`DragTarget`, which never leaves the Flutter view.

The content to hand out already has code behind it:

- Attachments: `ChatAttachment` has `path`, `bytes`, `fetchPath`; `MediaStore.file(path, name)` downloads once into the cache and returns a `File`; `MediaStore.save` is the Save button. `AttachmentCard` and `AttachmentThumbnail` are in `chat/widgets/attachment_views.dart`.
- Kanban: `KanbanTaskAttachments` rows; `KanbanRepository.downloadAttachment` calls `HermesApiClient.fetchKanbanAttachment` (hand-written because the generated method decodes JSON).

## Goals / Non-Goals

Goals: both file sources on macOS, content produced lazily on drop, one reusable layer that `mac-drag-out-text` builds on, no change to existing gestures. Non-goals are in `proposal.md`.

## Decisions

### A small Swift drag source behind a channel, not a plugin

The first candidate was `super_drag_and_drop` (superlistapp), which gives file promises, lazy values and drag previews. The spike (task 1.1) built it and found it too expensive for what it buys:

- Version 0.9.1 does not resolve: its `super_native_extensions` pins `device_info_plus <12`, and `flutter_otel_device_info` needs `>=12.4`. Only the 0.10 pre-release (August 2026) resolves, and it needs a second direct dependency, `super_clipboard`, to name its format types.
- The 0.10 line has no precompiled binaries: a build hook compiles its Rust core with `rustup` on every platform it is linked on. That puts a Rust toolchain on every developer machine and in every CI job (tests on Linux included, with GTK headers for the bindings), the Android, iOS and release builds and the `fastlane` archive, for a feature that only exists on macOS.
- The plugin also overrides `mouseDown:`/`mouseUp:` on the Flutter view and `mouseDownCanMoveWindow`, which touches every click in the window.

So the app does it itself: `macos/Runner/DragOut.swift` (about 200 lines, one Swift file in the Runner target, one registration line in `MainFlutterWindow`) and `lib/src/drag_out/mac_drag_out_source.dart`. Everything else goes through `DragOutSource`, so widgets and tests never see the platform. The spike's findings stay recorded here so nobody retries the plugin without them.

How the native side works:

- Flutter handles pointer events in Dart, so AppKit has no event for a drag Dart decides to start. A local `NSEvent` monitor on the main window remembers the latest left-button down and dragged events (and drops them on button up). It returns every event unchanged, so clicks, selection, `desktop_drop` and window dragging by the toolbar are not altered.
- Dart watches the pointer over the wrapped widget (a `Listener`, not the gesture arena). When the primary mouse button has moved 6 logical pixels, it asks `item()` and, if there is one, calls `startDrag` on the `hermes_app/drag_out` channel. Swift checks that the button is still down and calls `beginDraggingSession(with:event:source:)` on the Flutter view with the remembered event.
- A file goes out as an `NSFilePromiseProvider` (type: a UTI picked from the extension, `public.data` otherwise; name: the sanitized name, which Swift checks again: last path component, no leading dot, never empty). When the receiver asks, Swift calls `readFile` on Dart. Dart answers with the path of a local file when the content already is one (`DragOutFile.localPath`: the picked file, or the media cache copy, downloaded first if need be), which Swift copies to the URL the receiver gave, so a large attachment never crosses the channel. Only content with no file (an embedded attachment, a Kanban download) comes back as bytes from `DragOutFile.read`, held in memory while they are handed over (at most the 25 MB attachment limit). Swift reports `fileWritten`. Nothing is read at drag start.
- If Dart does not answer `readFile` within 60 s, Swift fails the promise with a readable error and tells Dart (`readTimedOut`), which logs `failed`/`fetch`; a late answer writes nothing. The errors Finder shows are `LocalizedError`s ("Hermes could not get this file...", "Hermes did not receive this file in time..."), not raw Swift types.
- When the session ends, the controller sends a synthetic `leftMouseUp` at the end point to the Flutter view controller before reporting `ended`. The dragging session swallows the real button up, so without it Flutter would believe the button is still down: hover would stop, a selection would keep growing and the next click would be lost.
- The session allows `.copy` only for a receiver outside the app (`.outsideApplication`) and nothing within it, so releasing a drag over the window cannot re-attach the file through `desktop_drop`'s whole-view drop target.
- Text goes out as an `NSPasteboardItem` with `public.utf8-plain-text` and `net.daringfireball.markdown`, both carrying the same string. It is first used by `mac-drag-out-text`.
- The drag image is the file type's icon at the pointer. The session ends with `ended {copied}`.

Not covered: a rich snapshot of the dragged widget as drag image, iOS/Android/Windows/Linux (non-goals), and multi-item drags.

### Interplay with desktop_drop

`desktop_drop` registers a drag destination view over the whole Flutter view, which accepts file promises and always answers copy. This change registers no drag destination at all: the controller only starts sessions. Dropping a Finder file on the chat is untouched. A drag started here is refused within the app (see the operation mask above), so it cannot land on that drop target and attach itself to the composer.

### Interplay with the Kanban drag

`Slidable` appears only in non-macOS rows, so it never shares a widget with drag-out. The Kanban card keeps `Draggable<KanbanTask>` for column moves; attachments in the task panel are not inside a card, and no card is made a native drag source. Because the starter listens to the pointer stream rather than joining the gesture arena, a tap, a `SelectionArea` selection beside it and a card drag are not competing with it; only the movement threshold starts a native drag.

### One drag-out layer

`lib/src/drag_out/` (all of it is what `mac-drag-out-text` builds on):

- `DragOut(kind:, item:, child:)` is the widget to wrap with. It reads the `DragOutSource?` provider (`context.watch`, so a new connection's telemetry replaces the old) and returns `child` itself when there is none. `item` is called when a drag starts and may return null to cancel that drag.
- `DragOutItem` is `DragOutFile(name:, read:)` (`read` is `Future<Uint8List> Function()`, called only on the drop) or `DragOutText(text)`. `DragOutKind` (`attachment`, `kanbanAttachment`) holds the slugs for telemetry: the text change adds `text` and `thread` to it, and `history` to `DragOutFailure`.
- `DragOutSource.wrap({kind, item, child})` is the interface; `NoDragOutSource` returns the child; `MacDragOutSource` is the macOS implementation. `main.dart` keeps one `MacDragOutSource` for the engine and only swaps its `telemetry` on a reconnect, so a drop in flight is still answered. An entry whose session was taken by a receiver that never asks for the file is forgotten after 5 minutes (logged as `cancelled`). `MacDragOutSource.supported` is the macOS gate and `main.dart` provides `null` elsewhere, so Widgetbook, conversation windows (separate engines that do not register the controller) and other platforms see no source.
- `sanitizeDragFileName(String, {String fallback, String extension})`: removes `/ \ : NUL` and control characters, drops bidi override, embedding, isolate and mark characters (so a right-to-left override cannot make `invoice<RLO>fdp.exe` pose as another type), strips leading dots and spaces, bounds the length at 120 characters (grapheme clusters, so a surrogate pair or an emoji sequence is never split), keeps the extension, and applies the fallback when empty. `dragFileType(name)` maps an extension to a UTI.
- Attachments are bounded by `kanbanAttachmentLimitBytes` (25 MB) and the media store's limits. Content that is already a file is copied natively; the bytes path (embedded attachments, Kanban downloads) holds at most that much in memory while it crosses the channel, which matches `fetchKanbanAttachment`.
- Tests use `FakeDragOutSource` (`test/support/`), which records each wrap and lets a test call `item()` and `read()`. The catalog uses `CatalogDragOutSource` (`widgetbook/`), which shows a grab cursor and the file name on hover. `MacDragOutSource` is tested against a mocked channel and `DragOutTests.swift` tests the promises with a fake backend.
- `DraggableAttachment` (chat) and `DraggableKanbanAttachment` (Kanban task panel) are the two wrappers; they sit around `AttachmentCard`/`AttachmentThumbnail` and the `ListTile` of a row without changing them.

Deviation: a failed fetch on a drop is logged and ends the drop with no file, but the chat card does not show its "no longer available" notice. The drop happens in the receiver's time, and the card's notice lives in its own tap state; surfacing it would mean reaching into `AttachmentCard`, which `mac-quick-look` also changes.

### The two sources

1. **Attachments.** In `chat_builders.dart` the card and the thumbnail are wrapped in `DraggableAttachment`. `read`: `bytes` if present, else `File(path).readAsBytes()`, else `MediaStore.file(fetchPath, name)` then read it. No source (relative `remotePath` only) gives `item() == null`, which cancels the drag.
2. **Kanban attachments.** `KanbanTaskAttachments` is a plain widget fed by callbacks, so the row takes an optional `onRead(KanbanAttachment)` future callback from the controller, wired to `downloadAttachment(id, board:)`. The row is wrapped when the callback is non-null; Widgetbook leaves it null.

### Affected platforms and native changes

- macOS: required. A new Swift file in the Runner target (`pbxproj` entries added on purpose), one line in `MainFlutterWindow.awakeFromNib`, and `DragOutTests.swift` in `RunnerTests`. No new entitlement, no Info.plist key, no change to `Release.entitlements`, no new dependency.
- iOS, Android, Linux, Windows: no source is provided, so nothing changes. watchOS: unaffected.

### Invariants touched

- API layering: attachment reads go through `MediaSource`; Kanban bytes keep the hand-written `fetchKanbanAttachment`. No Dio calls in the drag layer, no generated client edit.
- Auth: reads use the managed client, so refresh and the 401 rules are unchanged. A drop after sign-out fails the read and is logged as failed.
- Telemetry must never break the app: logging in the adapter swallows its own errors. If the channel throws on a drag, the drag is dropped silently.
- Tests use the real client against `FakeHermesServer`; only the platform boundary (`DragOutSource`) is faked.

### Observability

- Breadcrumb `drag_out.started {kind}` in the adapter when Swift reports that a session began. `Breadcrumbs` comes from context.
- Span `drag_out.promise {kind, hermes.* from the connection}` in the adapter around `read()`. Attributes carry kind and outcome only.
- Log event `drag_out.completed {kind, outcome, failure}` through `AppEventLogger` when the file was written, a read or write failed, or the session ended with no receiver.
- None carries names, titles, text, ids, sizes or paths. A test asserts that the attributes of all three are in an allow-list.

## Risks / Trade-offs

- The drag starts from the latest `NSEvent` the monitor saw, not from the event Dart reacted to. If the user releases the button between the two, no session starts (`startDrag` returns false) and the click stands. Real drags could not be driven in the build session; the hand checks are in the pull request.
- Only one native drag session at a time; a second `startDrag` while one is active is refused.
- Dragging an attachment with no local file (embedded, or a Kanban download) holds up to 25 MB in memory while it is written: accepted, same as Save.
- A drop to a slow receiver that cancels mid-write: the receiver owns the partial file.
- The drag image is the file type's icon, not a snapshot of the widget.

## Migration Plan

None; no stored data. Rollback removes the Swift file, its registration line and the wraps. Merge this change before `mac-drag-out-text`.
