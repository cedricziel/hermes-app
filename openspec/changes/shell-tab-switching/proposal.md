## Why

Two faults in the shell that hosts the Chat and Kanban tabs.

- With the Kanban tab selected, tapping a notification selects the chat thread and shared content fills the composer, but the shell stays on the board. The user keeps looking at the board and sees nothing happen (#94).
- The shell remembers that Kanban was opened and never forgets it. After the plugin goes off and on again, the Kanban page is built at once, fetching the board and opening the event stream without the user opening the tab. Once opened, the page also stays alive behind Chat, so its event stream keeps running while the user is on Chat (#97).

## What Changes

- The chat screen takes an optional callback that asks the shell to show Chat. It calls it for every notification tap and whenever it takes shared items. The shell switches to Chat.
- The shell builds the Kanban page only while the Kanban destination is selected. Leaving the tab closes the board and its event stream. Opening it again loads the board afresh. This replaces the "opened once" flag, so there is nothing left to reset when the plugin goes off and on.
- A notification tap switches to Chat even when the chat cannot be opened ("Could not open that chat."), so the message is shown on the screen the tap was about.

## Impact

- `lib/src/shell/app_shell.dart` and `lib/src/chat/chat_screen.dart` (one callback and two call sites).
- Tests: `test/app_shell_test.dart`.
- Specs: kanban, notifications and sharing (delta specs in this change).
- No new backend route or RPC method, no change to `packages/hermes_api`.

## Non-goals

- Keeping the board's local state (search text, assignee, tenant and archived filters, the selected status chip, bulk selection) across a visit to Chat. The chosen board is still remembered, since it is stored in preferences.
- A pause and resume mode on the board controller.
- Closing a secondary screen (task detail, board management) that is open over the board when a tap or share arrives.
- Changing how a notification tap picks its chat, or how shared content is put in the composer.

## Security and privacy impact

None. No token, storage or network behaviour changes. The board is fetched and its socket opened less often, never more.

## Telemetry

None. No span, log event or attribute is added. The HTTP and socket spans that already exist simply occur when the board is opened rather than once per session.
