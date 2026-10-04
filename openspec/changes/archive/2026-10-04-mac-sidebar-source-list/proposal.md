## Why

On macOS the sidebar still looks like the phone drawer: 36 pt rows, one flat list of threads and a Material menu. The Mac native concept turns it into a source list, as Finder and Mail have, with the threads in sections by recency and a Mac context menu. Copying a transcript from a thread that is not open copied nothing, because its messages were never loaded.

## What Changes

- macOS only: the destinations (Chat, Kanban, Schedules) become 28 pt source-list rows; Kanban carries the caption "All profiles", since the board is shared by every profile.
- macOS only: the threads sit under section headers (Pinned, Today, Previous 7 days, Previous 30 days, Older; empty ones left out). A click on a header folds its section away; which sections are folded is remembered across launches.
- macOS only: thread rows are 28 pt; under the pointer they show Archive and More buttons. More and a right-click open a Mac menu: Open in New Window (only where the app offers windows), Rename…, Pin/Unpin, Copy Transcript, Archive, Delete…, with their shortcuts shown.
- Every platform: Copy Transcript copies Markdown (a heading per speaker) and reads the whole history of a thread whose messages are not loaded yet. An open thread is not read again.
- Mac menus have 22 pt rows highlighted in the primary colour, and a context menu opens under the pointer.

### Non-goals

- The menu bar commands behind the shortcuts (another change).
- Separate windows per chat; the menu item only shows once a handler exists.
- Search and New Chat moving into the toolbar (follow-up change).

### Security and privacy

None. Copy Transcript reads the user's own sessions over the existing client; nothing new is stored, apart from the names of folded sections in shared preferences.

### Telemetry

None.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `chat`: adds "Thread sections on macOS" and "Copying a transcript".

## Impact

- `lib/src/macos/` (source-list rows, section headers, folded sections in `MacSidebarController`), `lib/src/chat/widgets/` (Mac thread row, menu items), `lib/src/widgets/adaptive_popup_menu_button.dart` (shortcuts, destructive items, pointer position).
- `ChatController` reads a thread's full history for the transcript through `ThreadHousekeeping`.
