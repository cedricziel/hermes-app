## Why

On a Mac, people expect Finder's model: click a file to select it, double-click to open it, press Space to see it. Today a click on a chat attachment card downloads the file and hands it to `open_file`, which launches whatever app owns the type; a Kanban task attachment can only be saved. Both interrupt the user to answer "what is this file?". The system Quick Look panel answers that in place and closes with Space or Escape.

## What Changes

- On macOS, attachments follow Finder: a single click selects an attachment (a chat file card or image thumbnail, a Kanban task attachment row) and shows a selection state; a double-click opens it (what a single click does today); Space toggles the system Quick Look panel (`QLPreviewPanel`) for the selected attachment; Escape or Space closes the panel. **BREAKING** for macOS users: one click no longer opens a chat attachment.
- Other platforms keep click-to-open and gain nothing.
- A "Quick Look" item in the attachment's context menu (secondary click) does the same as Space, and the secondary click also selects. The menu also carries the existing Open and Save actions, so Kanban attachments gain Open; a double-click on a Kanban row runs it.
- The file is downloaded to the app's cache directory first, with the loading state each surface already has ("Downloading…" on the chat card, the busy bar in the Kanban panel), then shown. Failures use the messages the surfaces already show.
- A small Swift channel in the macOS Runner (`hermes_app/quick_look`) drives the panel. No pub.dev plugin covers macOS (see design).
- Kanban attachments are staged through `MediaStore`, so both surfaces share one cache, one safe-file-name rule and one cleanup path.

## Capabilities

### New Capabilities

- `mac-quick-look`: Preview a chat or Kanban attachment in the macOS Quick Look panel from the keyboard or a context menu.

### Modified Capabilities

None. No main spec describes attachment clicks, so the macOS click change (select on click, open on double-click) is specified in `mac-quick-look`.

## Impact

- Dart: `lib/src/chat/media/` (`MediaStore` gains a staging method for bytes that are not fetched by server path, plus a `QuickLook` interface beside `MediaActions`), `lib/src/chat/widgets/attachment_views.dart` (selection, double-click, key handling, context menu), `lib/src/kanban/widgets/task_panel/kanban_task_attachments.dart` and `kanban_task_panel.dart`.
- Native: `macos/Runner/QuickLookPanel.swift`, registered in `AppDelegate.swift` and in the conversation-window engine in `MainFlutterWindow.swift`, plus the Xcode source reference. No entitlement change; no new Dart dependency.
- Widgetbook: use cases for the idle, selected, loading, failed and selected-while-loading states of the attachment card, image thumbnail and Kanban row.
- One PR of roughly 500 lines.

### Non-goals

- iOS and iPadOS. `QLPreviewController` exists, and the `quick_look` pub package wraps it, but iOS already hands files to the share and open flows, has no Space key, and gains little for the cost of a second native path. Out of scope; the Dart interface leaves room for it.
- Android, Windows, Linux.
- Stepping through several attachments with the arrow keys, Quick Look's zoom-from-source animation, and sharing from the panel's toolbar beyond what the system panel itself provides.
- Previewing files that are not attachments (tool results, code blocks, generated media outside the attachment cards).
- A File menu item or a menu-bar shortcut for Quick Look. Space is handled by the selected attachment only (see design).
- Changing click behaviour off macOS, or anywhere other than chat and Kanban attachments.
- Multi-selection (Shift or Command click), drag selection, and rename on Enter.
- Offline previews of files never downloaded.

### Security and privacy

Attachment bytes are written to the app container's cache directory by the existing `MediaStore` rules (sanitized name, per-path hashed folder, written aside then renamed) and deleted on sign-out and by a launch sweep. Quick Look runs in the app process, which hands the system a `file://` URL inside the container; no entitlement is added and nothing is written outside the container. Quick Look's preview generators are system extensions: they read the file, they do not receive tokens, and the app's session never leaves Dart's `Dio`. Locally picked files outside the container are copied in first rather than shown from their original location. File contents, names and paths never go to telemetry.

### Observability

- Log event `quick_look.failed` through `AppEventLogger`, with `stage` (`download`, `stage_local`, `native`) and `reason` (the `MediaFailure` name or `unavailable`). A failure here is worth counting after a macOS update changes Quick Look behaviour.
- Breadcrumbs `quick_look.opened` and `quick_look.failed` through `Breadcrumbs`, with `source` (`chat` or `kanban`) and `trigger` (`key` or `menu`); opening by double-click is not a Quick Look event, so a later crash shows what the user was doing.
- No span of its own. The download is already a client span from the Dio interceptor with `hermes.*` attributes, and the native call is a local show that returns at once.
- No names, extensions, paths, sizes or ids in any of them.

### Coordination

No dependency on the `hermes://` URL scheme or the actionable-notification changes. Neither touches attachments.
