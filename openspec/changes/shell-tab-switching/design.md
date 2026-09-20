## Context

`AppShell` keeps Chat and the Kanban page in an `IndexedStack`. A `_kanbanOpened` flag delays building the page until the tab is first selected. Nothing resets the flag and nothing tells the page when it is hidden.

## Decisions

**Dispose the Kanban page when its tab is not selected.** Options were: (a) reset `_kanbanOpened` when the plugin goes off; (b) also pause the board controller while hidden; (c) build the page only while selected.

(a) alone fixes the flip but leaves the event stream running behind Chat. (b) needs a pause and resume API on `KanbanBoardController` (stop the socket and timers, refetch and reconnect on resume) plus a visibility signal into `KanbanScreen`. That is a new mode to test and get wrong. (c) is a few lines in the shell, removes the flag, so the plugin flip cannot leave stale state, and stops the stream and the timers with the page's own `dispose`.

The cost of (c) is that the board's local state is lost on every visit to Chat: search text, assignee, tenant and archived filters, the status chip and bulk selection. The chosen board survives because it is stored in preferences, and the board is fresh on every visit. That is acceptable for a first fix. If it turns out to matter, (b) can be added later.

**Chat asks the shell through a callback.** The chat screen already receives the notification tap and the shared items, so it is the one that knows a switch is needed. `ChatScreen.onShowChat` is an optional `VoidCallback`; the shell passes `_showChat`. With no shell, or with the plugin off, the callback does nothing, which is right since Chat is all there is.

**Switch on every tap, including a failed one.** A tap whose chat cannot be opened still means the user wants the chat. The "Could not open that chat." message then appears on the chat, not over a board that seems unrelated.

**A tap held while the list loads switches at once.** The selection is applied later; the tab switches when the tap arrives.

## Platforms

All platforms that show the shell (iOS, Android, macOS, Windows, Linux). watchOS has no shell. No native, entitlement, manifest or Xcode change.

## Invariants touched

None of the auth, API layering or telemetry invariants. Fewer requests are made, through the same client.
