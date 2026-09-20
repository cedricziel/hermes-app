## Context

`AppShell` keeps Chat and the Kanban page in an `IndexedStack`. A `_kanbanOpened` flag delays building the page until the tab is first selected. Nothing resets the flag and nothing tells the page when it is hidden.

## Decisions

**Reset `_kanbanOpened` when the plugin goes off, and keep the page alive otherwise.** Options were: (a) reset the flag when the plugin goes off; (b) also pause the board controller while hidden; (c) build the page only while its tab is selected.

(c) is the smallest change and also stops the stream behind Chat, but it discards the board's local state on every visit to Chat: search text, assignee, tenant and archived filters, the status chip and bulk selection. That is too costly for people who use the board. (b) keeps the state and stops the stream, but needs a pause and resume API on `KanbanBoardController` (close the socket and timers, refetch and reconnect on resume) plus a visibility signal into `KanbanScreen`; that is more than this fix should carry. (a) fixes the report that the page is built without the user opening the tab, in three lines, and keeps the state.

The remaining symptom of #97, the event stream running while the user is on Chat, is left alone and written down as a non-goal. It costs one idle socket and a debounced refetch per burst of events. Option (b) is the follow-up.

When the plugin goes off the shell returns to Chat and stops building the page, which disposes it. Turning the plugin back on therefore starts from a closed tab.

**Chat asks the shell through a callback.** The chat screen already receives the notification tap and the shared items, so it is the one that knows a switch is needed. `ChatScreen.onShowChat` is an optional `VoidCallback`; the shell passes `_showChat`. With no shell, or with the plugin off, the callback does nothing, which is right since Chat is all there is.

**Switch on every tap, including a failed one.** A tap whose chat cannot be opened still means the user wants the chat. The "Could not open that chat." message then appears on the chat, not over a board that seems unrelated.

**A tap held while the list loads switches at once.** The selection is applied later; the tab switches when the tap arrives.

## Platforms

All platforms that show the shell (iOS, Android, macOS, Windows, Linux). watchOS has no shell. No native, entitlement, manifest or Xcode change.

## Invariants touched

None of the auth, API layering or telemetry invariants.
