# Design

## Context

See proposal.md and specs/mac-quick-look/spec.md.

What exists today:

- `AttachmentCard` and `AttachmentThumbnail` (`lib/src/chat/widgets/attachment_views.dart`) render chat attachments. A card's `_use` downloads through `MediaStore.file(path, name)` and then runs `_openFile` (`MediaStore.open` -> `MediaActions.open` -> `OpenFile.open`) or `_saveFile`. Its "Downloading…" notice and `mediaFailureMessage` are the loading and failure states. `MediaStore` (`lib/src/chat/media/media_store.dart`) downloads into `getApplicationCacheDirectory()/hermes_media/<hash of server path>/<safe name>`, deduplicates fetches, writes aside then renames, and `clear()` (wired to sign-out in `main.dart` and in `conversation_window_app.dart`) deletes the folder.
- `KanbanTaskAttachments` (`lib/src/kanban/widgets/task_panel/kanban_task_attachments.dart`) lists a task's `KanbanAttachment`s as `ListTile`s with Save and Remove buttons. Save goes `KanbanTaskController.download` -> `KanbanRepository.downloadAttachment(id, board:)` -> `HermesApiClient.fetchKanbanAttachment` -> `KanbanFiles.save` (file dialog). Kanban never touches `MediaStore`.
- `MacCommandScope` and `macMenus` (`lib/src/macos/`) own menu-bar chords. Their rule: do not add a `HardwareKeyboard` or `Shortcuts` handler for a chord the menu owns, because menu shortcuts reach the menu only when no widget handled the key.
- The macOS Runner registers channels in `AppDelegate.swift` (`hermes_app/share`, `WebAuthSession`, handoff) and a conversation window's engine registers its own small set in `MainFlutterWindow.swift` (`ConversationWindow.registerPlugins`, `hermes_app/window`).

## Goals / Non-Goals

**Goals:**

- Finder-like attachments on macOS: click selects, double-click opens, Space toggles Quick Look, Escape or Space closes, plus a context menu, from the main window and from conversation windows.
- One cache and one cleanup path for chat and Kanban files.
- A Dart interface that tests fake, so no test needs macOS.

**Non-Goals:** iOS, multi-item navigation, source-frame animation, a menu-bar item. See proposal.

## Decisions

### A small Swift channel, not a plugin

pub.dev has no macOS Quick Look plugin. `quick_look` (0.2.0) wraps `QLPreviewController` and lists iOS only, with 7 likes and an unverified publisher. `native_file_preview` covers iOS and Android. `open_file_mac` (already a dependency through `open_file`) opens a file or reveals it in Finder and has no preview call. Per CLAUDE.md "Dependencies" a homegrown path is allowed when none fits; this one is about 80 lines of Swift in the same style as `WebAuthSession.swift`.

### The panel is driven directly, not through the responder chain

Apple's recommended route is `acceptsPreviewPanelControl`/`beginPreviewPanelControl` on a responder. That needs an `NSWindow` or `NSViewController` subclass in the chain. `MainFlutterWindow` is ours, but conversation windows are created by `desktop_multi_window`, and an `NSWindow` extension cannot override those methods. So `QuickLookPanel` is an app-wide singleton `NSObject` that conforms to `QLPreviewPanelDataSource` and `QLPreviewPanelDelegate`; `preview` sets itself as the panel's `dataSource` and `delegate`, calls `reloadData()` and `makeKeyAndOrderFront(nil)`. This is the documented fallback for apps that cannot join the chain. Cost: if the system ever hands the panel to another controller, our item list is dropped, which is acceptable because we hold no state worth keeping. The verify task checks that Escape, Space (toggle from the Flutter window and from the panel) and the close button all close it, that focus returns to the requesting window, and that a second `preview` swaps the item.

Channel `hermes_app/quick_look`:

- `preview({path})` -> `true` once the panel is ordered front, `false` when the file is gone. Replaces the item if the panel is open.
- `toggle({path})` -> `"closed"` when the panel was visible on the same file URL and is now closed, `"shown"` after showing or replacing the item, `false` when the file is gone. Space uses it; the menu's Quick Look uses `preview`.
- `close()` -> closes the panel if it is ours. Called on sign-out.
- `closed` (native -> Dart) is not needed: Dart holds no state that depends on the panel being open, so there is no event stream. Focus return comes from AppKit (the panel's previous key window becomes key again).

The singleton is created once; `AppDelegate` installs it on the main engine's messenger and `ConversationWindow.registerPlugins` installs a channel handler on the conversation engine's messenger that forwards to the same singleton. Both engines get the Dart `MacQuickLook` implementation; the iOS/other implementation is a `NoQuickLook` that reports `available == false`. The source file `macos/Runner/QuickLookPanel.swift` needs an Xcode reference like `WebAuthSession.swift` (a `PBXFileReference`, a `PBXBuildFile` and the Runner group and Sources entries).

Sandbox: `QLPreviewPanel` runs in-process and previews run in system extensions the OS grants read access to the item URL; a file in the app container's Caches is readable. No entitlement or Info.plist change. A file elsewhere (a picked file at its original path) might not be, so those are copied into the cache first.

### The interface sits beside `MediaActions`

`lib/src/chat/media/quick_look.dart`:

```dart
abstract interface class QuickLook {
  bool get available;                    // false off macOS
  Future<bool> preview(String path);     // false: could not show
  Future<bool> toggle(String path);      // true: now shown; false: closed or could not show
  Future<void> close();
}
```

`MethodChannelQuickLook` implements it for macOS; `NoQuickLook` elsewhere and in tests that do not care. `MediaStore` takes a `QuickLook` next to `MediaActions` and adds:

- `Future<bool> quickLook(File file)` -> `_quickLook.preview(file.path)`.
- `Future<File> stage(String key, String name, Future<Uint8List> Function() fetch)`: the body of `file()` with the source call replaced by `fetch`. `file(path, name)` becomes `stage(path, name, () => _source.file(path))`. Kanban uses key `kanban:<board>:<attachmentId>` and `() => repository.downloadAttachment(id, board:)`, so it shares the hashed folder, `_safeName`, in-flight deduplication, generation check on `clear()` and write-aside rename. Local sources use `stageBytes(key, name, bytes)` (bytes the history embedded) and `stageCopy(key, name, File)` (a picked file), keyed by their content-independent identity (`local:<path>`).
- `Future<void> sweep(Duration maxAge)`: deletes entries under the media folder whose modified time is older than `maxAge`. Called once at construction time in `main.dart` after the store is created, not awaited, failures swallowed (`_quietly`). Sign-out `clear()` also calls `quickLook.close()`.

Alternative considered: a second cache for Kanban in the repository. Rejected, it would copy the name sanitizing and the clear-on-sign-out wiring.

### Selection: owned by the target's focus node

A selected attachment is a focused attachment. Flutter already has this model, so no selection controller is added. Each `QuickLookTarget` owns one `FocusNode`; `hasFocus` is the selected state. At most one is selected because only one node is primary focus, and selecting a text field (the composer) or another target ends it.

- `AttachmentCard`, `AttachmentThumbnail` and each Kanban attachment row are wrapped in a `QuickLookTarget` (`lib/src/chat/widgets/quick_look_target.dart`, a plain widget with `onOpen`, `onPreview`, `enabled`, `child`, and an optional `menuItems` builder). On macOS it is a `Focus` (`canRequestFocus: true`, `skipTraversal: false`) around a `Listener` and `GestureDetector`.
- Pointer down (primary or secondary button) requests focus at once, so selection does not wait for the double-tap timeout. `GestureDetector.onDoubleTap` calls `onOpen`; there is no `onTap`, so a single click only selects. The secondary tap opens the context menu with `AdaptiveMenuController.open(at:)`.
- The surfaces stop opening on tap on macOS: `AttachmentCard`, `AttachmentThumbnail` and the Kanban row pass their old tap action to the target as `onOpen` and drop their own `onTap`/`InkWell` activation there. Off macOS the target returns `child` unchanged and the old tap stays.
- Keyboard: Enter or numpad Enter on the selected target calls `onOpen`, replacing the activation `InkWell` gave. Accessibility: the target exposes a semantics tap action wired to `onOpen`, so VoiceOver activation still opens.
- Deselecting: a `TapRegion` with `onTapOutside` unfocuses the target when it has focus, so a click on the chat background clears the selection as in Finder. Moving focus by Tab also clears it.
- Visual state: selected shows a 2 px outline in `colorScheme.primary` plus an 8% primary fill, with the surface's corner radius. Hover shows nothing extra and never selects. Loading while selected keeps the outline; the surface's own loading indicator is added to it.
- The Kanban row had no click action; a double-click now runs the new Open (stage, then `MediaStore.open`), the same as the menu item.

### Keyboard handling

`onKeyEvent` on the target's `Focus` runs only while that node is the primary focus or an ancestor of it, so it never sees keys typed into the composer (the `EditableText` is the primary focus there and consumes Space). Rules:

- Act on `KeyDownEvent` for `LogicalKeyboardKey.space` with no Meta, Control or Alt (Shift is allowed, Finder treats Shift-Space the same). Ignore `KeyRepeatEvent` and `KeyUpEvent`. Return `KeyEventResult.handled` so the list does not scroll on Space and the key does not fall to the menu bar.
- Space toggles. The target stages the file (a cache hit makes no request when it was shown or opened before) and calls the channel's `toggle`: if the panel is visible on that same file it closes, otherwise it shows or replaces the item.
- Escape: while the panel is key, AppKit closes it. In the Flutter window Escape on a selected target does nothing, so it never competes with `ChatScreen`'s search Escape or a dialog.
- Space belongs to no `MacCommand` and no menu shortcut is added. A bare-Space menu item would be offered to text fields and fight them; the `MacCommandScope` rule is respected because nothing is registered.
- No `HardwareKeyboard.instance.addHandler`, so the existing handlers (`ChatScreen`'s ⌘F) and the menu bar are unaffected.
- When the panel has key focus, AppKit handles Space and Escape before Flutter sees them.
- Enter is bound on the target only (see Selection), never globally.
- Composer focus: the composer's `EditableText` is primary focus while typing, so the selected target has already lost focus and sees no keys. Clicking an attachment takes focus from the composer, and Space then previews instead of typing; clicking the composer again restores typing. The composer keeps its text and cursor across that.
- `MacCommandScope` rule: nothing is registered, because Space and Enter are not menu chords. View > Back (⌘[) and the other scope commands are unaffected by selection.

### Download, loading and failure per surface

Chat card: `_use` already sets `_busy`, shows "Downloading…" and maps `MediaFetchException` to the card's notice. Quick Look is a third continuation next to `_openFile` and `_saveFile`, and double-click runs `_openFile`:
`_quickLookFile(store, file) => store.quickLook(file)` (`store.toggleQuickLook` for Space); a failed show shows the snackbar "Quick Look couldn't preview this file." For an attachment with `bytes` or a local `path`, the continuation is reached through `stageBytes`/`stageCopy` instead of `store.file`. `AttachmentThumbnail` gains the same path; while it runs it shows the existing `_ThumbnailPlaceholder` is not used (the picture is already on screen), so a 2 px `LinearProgressIndicator` along the thumbnail's bottom edge shows the wait. A thumbnail's image bytes are in `MediaStore`'s memory cache only, so preview downloads the file again through `file()`; it is cached afterwards. Acceptable because it happens on demand and images are capped by the server at 25 MB.

Kanban: `KanbanTaskController` gains `Future<bool> preview(KanbanAttachment, {bool toggle})` and `open(KanbanAttachment)` that sets `transferring` (the busy bar and disabled buttons already exist), stages the file through `MediaStore.stage` and calls `quickLook`. The controller gets `MediaStore` and `QuickLook` through its constructor, defaulting to the provider values in `KanbanTaskPanel` (`context.read<MediaStore?>()`); with no store the row's Quick Look is disabled. Errors use `KanbanException`, shown on the panel's existing error line.

A press while a request is running is ignored (`_busy` / `transferring`), which is what makes holding Space safe in addition to the key-repeat filter.

Late completion: after the download, the continuation checks `mounted` (chat) or `disposed` (Kanban) and a generation captured at the start; `MediaStore.clear()` bumps its generation, so `stage` already throws and nothing is previewed after sign-out.

### Context menu

`AdaptiveMenuItem`s built by `QuickLookTarget`'s `menuItems` builder: Quick Look (trailing shortcut text `Space`), Open (trailing text `Double-click`), Save…. The secondary click selects the target first. Kanban rows get an Open continuation that stages the file and calls `MediaStore.open` as the chat card does. Menu items act through `onTap` per the existing `AdaptiveMenuItem` convention. The menu is macOS only; other platforms keep their current controls.

### Platforms

macOS: Dart, Swift channel, Xcode source reference, both engines. iOS, Android, Windows, Linux, watchOS: no behaviour change; `NoQuickLook` and an unwrapped child. No entitlement, Info.plist, or Podfile change. Conversation windows: register the channel in `registerPlugins`-equivalent setup. Neither engine registers `record`/`hermes_speech` for this.

### Invariants touched

- API layering: no new call; both routes go through `HermesApiClient` helpers that already exist. Kanban keeps calling its repository.
- Auth: downloads use the managed `Dio`, so 401 refresh and the concurrent-401 rule are unchanged. Sign-out clears the store, which now includes Kanban files and closes the panel.
- Telemetry: opt-in, swallowed failures. New calls go through `safely`-style wrappers already used for `Breadcrumbs` and `AppEventLogger`.

### Observability

- Breadcrumb `quick_look.opened {source: chat|kanban, trigger: key|menu}` (only when the panel is shown; a toggle that closes it records nothing, and double-click open is unchanged) recorded in `QuickLookTarget`'s caller right after `preview` returns true; `quick_look.failed` with the same attributes on failure. Source: the chat card/thumbnail state and `KanbanTaskController`, via the `Breadcrumbs` provider (`Breadcrumbs.none` when absent).
- Log event `quick_look.failed {stage: download|stage_local|native, reason: <MediaFailure name>|unavailable}` through `AppEventLogger` from the same two places. In the chat widgets the logger comes from the `HermesRepositories.telemetry.events` the screen already holds; in Kanban from the panel's events as the Kanban plugin code logs today.
- No span. The download is a Dio client span already carrying `hermes.*` attributes, and `preview` is a local call that returns in milliseconds.
- None carries names, extensions, paths, sizes, ids or file contents.

## Risks / Trade-offs

- **Direct data-source takeover.** If AppKit or a future macOS rejects it, the panel stays empty. Mitigation: the Swift channel returns `false` when `QLPreviewPanel.shared()` is nil or the URL is unreadable; the verify task tries macOS main and conversation windows. Fallback is a first-responder controller on `MainFlutterWindow` for the main window only.
- **Click no longer opens.** A user who clicks to select gets the old open behaviour. Tracked as an open question; Space still works afterwards.
- **Key handling regression in the chat list.** The `Focus` wrapper adds tab stops in the message list. `skipTraversal` is false on purpose so keyboard users can reach them; a workflow test checks that Tab from the composer still goes where it did.
- **Slower open for existing users.** One click no longer opens a chat attachment on macOS. Intended (Finder model); the context menu and double-click keep it one gesture away, and the release note says so.
- **Double-click recognition.** `onDoubleTap` uses the platform double-tap time; a slow second click selects only. The selection outline makes that visible.
- **Thumbnails download twice** (memory image, then file). Acceptable, see above.

## Open Questions

- Should arrow keys step through a message's or task's attachments in the panel? Assumed a follow-up.
