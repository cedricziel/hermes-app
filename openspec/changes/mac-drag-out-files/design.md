## Context

macOS takes drops only: `PluginAttachmentSource.dropTarget` wraps the chat in `desktop_drop`'s `DropTarget` (`lib/src/chat/attachments/plugin_attachment_source.dart`, used by `AttachmentSurface`). Nothing starts a native drag. The in-app Kanban card drag (`kanban_card_drag.dart`) uses Flutter's `Draggable`/`DragTarget`, which never leaves the Flutter view.

The content to hand out already has code behind it:

- Attachments: `ChatAttachment` has `path`, `bytes`, `fetchPath`; `MediaStore.file(path, name)` downloads once into the cache and returns a `File`; `MediaStore.save` is the Save button. `AttachmentCard` and `AttachmentThumbnail` are in `chat/widgets/attachment_views.dart`.
- Kanban: `KanbanTaskAttachments` rows; `KanbanRepository.downloadAttachment` calls `HermesApiClient.fetchKanbanAttachment` (hand-written because the generated method decodes JSON).

## Goals / Non-Goals

Goals: both file sources on macOS, content produced lazily on drop, one reusable layer that `mac-drag-out-text` builds on, no change to existing gestures. Non-goals are in `proposal.md`.

## Decisions

### Use super_drag_and_drop for the drag side

Candidates: write an `NSFilePromiseProvider` method channel by hand, or `super_drag_and_drop` (superlistapp, 0.9.1, Android/iOS/Linux/macOS/Web/Windows, about 577 likes and 100k downloads on pub.dev). CLAUDE.md prefers a mature plugin. This one gives virtual files (file promises on macOS) with a sink the app writes into when the receiver asks, lazy values, and a snapshot of the dragged widget. A hand-written promise provider would need Swift for the pasteboard, a drag source on the Flutter view and a cancellation path.

Costs, all checked in the spike (task 1.1):

- Its last release is about 16 months old (checked on pub.dev while writing this) and 155 issues are open on the repository. Mitigation: all use goes through `DragOutSource`, so replacing it touches one adapter.
- The native part is Rust (`super_native_extensions`). It downloads precompiled binaries when no Rust toolchain is present, otherwise builds with rustup. CI runners, the Android build (NDK, auto-installed) and the Linux package build will all pull it, because a Flutter plugin is linked on every platform it supports. The spike measures the change in CI time and bundle size, and confirms the macOS universal build and the App Store archive (`fastlane`) still work. If any of these fails, the fallback is a hand-written `hermes_app/drag_out` channel in `macos/Runner` (an `NSFilePromiseProvider` on the Flutter view), and this design is updated before any UI work. `mac-drag-out-text` inherits whichever result is recorded here.
- Minimum macOS version is not listed on pub.dev. The app targets macOS 26, which is above anything the plugin should ask for; the spike confirms it builds.

### Interplay with desktop_drop

Both plugins install themselves as drop destinations in the Flutter view on macOS. `desktop_drop` registers dragged types on a view above the Flutter view; `super_native_extensions` handles drag destinations through its own view and the drop side is only active when a `DropRegion` is in the tree. We use only the drag source side, so no `DropRegion` is added, and `desktop_drop` stays the only drop target. Starting a drag session does not need a destination.

Unverified assumption: the two do not both claim the view's `registerForDraggedTypes`, which could break one of them. The spike has two checks: a Finder file still attaches in the chat after the plugin is added, and a drag out of the app works while `DropTarget` is mounted. If they conflict, switch the chat drop to `DropRegion` (small, because `AttachmentSource.dropTarget` is already an interface).

### Interplay with the Kanban drag

`Slidable` appears only in non-macOS rows, so it never shares a widget with drag-out. The Kanban card keeps `Draggable<KanbanTask>` for column moves; attachments in the task panel are not inside a card, and no card is made a native drag source. The native drag starts from a pointer-down recognizer of its own; the plugin's hit slop for desktop (raised in 0.9.0-dev.3) keeps a plain click or small move from starting a drag. The spike verifies a click on an attachment card, `SelectionArea` selection next to it and a Kanban card drag still behave.

### One drag-out layer

`lib/src/drag_out/`:

- `DragOutItem`: sealed, a `name` (already sanitized) and either `DragOutText(text)` or `DragOutFile(name, read)` where `read` is `Future<Uint8List> Function()`, called only on drop. Nothing is fetched at drag start. `DragOutText` is defined here so the adapter is complete, and is first used by `mac-drag-out-text`.
- `DragOutSource`: interface with `Widget wrap({required DragOutItem? Function() item, required DragOutKind kind, required Widget child})`. `PluginDragOutSource` implements it with `DragItemWidget` + `DraggableWidget`; `NoDragOutSource` returns the child. `PluginDragOutSource.supported` is `defaultTargetPlatform == macOS && !kIsWeb`.
- Provided next to `AttachmentSource` in `main.dart`; widgets read `context.read<DragOutSource?>()` so Widgetbook and conversation windows pass none and see none. Conversation windows are separate engines that register few plugins (`MainFlutterWindow.swift`), so they do not register the plugin and get `NoDragOutSource`.
- The adapter turns `DragOutFile` into `addVirtualFile`: it calls `read()`, writes the bytes to the sink (`sinkProvider(fileSize:)`), closes it, and reports progress. A thrown error closes the sink with an error and logs the event. Attachments are bounded by `kanbanAttachmentLimitBytes` (25 MB) and the media store's limits, so reading into memory is acceptable and matches `fetchKanbanAttachment`.
- `sanitizeDragFileName(String, {String fallback, String extension})`: removes `/ \ : NUL` and control characters, strips leading dots and spaces, bounds the length at 120 characters, keeps the extension, and applies the fallback when empty. Unit tested including `../x`.

### The two sources

1. **Attachments.** In `AttachmentCard` and the image branch of `AttachmentThumbnail`, wrap the card. `read`: `bytes` if present, else `File(path).readAsBytes()`, else `MediaStore.file(fetchPath, name)` then read it. No source (relative `remotePath` only) gives `item() == null`, which cancels the drag. The tap/InkWell still gets the click because the plugin only claims a drag past the slop.
2. **Kanban attachments.** `KanbanTaskAttachments` is a plain widget fed by callbacks, so the row takes an optional `onRead(KanbanAttachment)` future callback from the controller, wired to `downloadAttachment(id, board:)`. The row is wrapped when the callback is non-null; Widgetbook leaves it null.

### Affected platforms and native changes

- macOS: required. No new entitlement, no Info.plist key, no change to `Release.entitlements`. Pods change from the new plugin (`macos/` Xcode files are rewritten on build; stage by name as CLAUDE.md says).
- iOS, Android, Linux, Windows: the plugin links but is inert (`NoDragOutSource`). The spike measures build impact; if Android or Linux CI breaks or grows unacceptably, move to the fallback channel.
- watchOS: unaffected.

### Invariants touched

- API layering: attachment reads go through `MediaSource`; Kanban bytes keep the hand-written `fetchKanbanAttachment`. No Dio calls in the drag layer, no generated client edit.
- Auth: reads use the managed client, so refresh and the 401 rules are unchanged. A drop after sign-out fails the read and is logged as failed.
- Telemetry must never break the app: logging in the adapter is wrapped in `safely`. If the plugin throws on a drag, the drag is dropped silently.
- Tests use the real client against `FakeHermesServer`; only the plugin boundary (`DragOutSource`) is faked.

### Observability

- Breadcrumb `drag_out.started {kind}` in the adapter when the plugin's `dragItemProvider` returns an item. `Breadcrumbs` comes from context.
- Span `drag_out.promise {kind, hermes.* from the connection}` in the adapter around `read()`. Attributes carry kind and outcome only.
- Log event `drag_out.completed {kind, outcome, failure}` through `AppEventLogger` after the sink is closed or the drop is cancelled.
- None carries names, titles, text, ids, sizes or paths. A test asserts that the attributes of all three are in an allow-list.

## Risks / Trade-offs

- Plugin staleness (16 months): isolated behind one interface; fallback is a small Swift channel.
- Plugin conflicts with `desktop_drop` or Flutter version: spike first, no UI work before it passes.
- Rust binary download on CI and offline builds: measured in the spike; CI must allow network for the plugin's binary download. If it cannot, the Rust toolchain is installed in the workflow.
- Dragging a big attachment holds up to 25 MB in memory while it is written: accepted, same as Save.
- A drop to a slow receiver that cancels mid-write: the sink is closed with an error; the partial file is the receiver's to remove.

## Migration Plan

None; no stored data. Rollback removes the plugin and the wraps. Merge this change before `mac-drag-out-text`.
