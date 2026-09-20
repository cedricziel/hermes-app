## Why

Two faults in the shell that hosts the Chat and Kanban tabs.

- With the Kanban tab selected, tapping a notification selects the chat thread and shared content fills the composer, but the shell stays on the board. The user keeps looking at the board and sees nothing happen (#94).
- The shell remembers that Kanban was opened and never forgets it. After the plugin goes off and on again, the Kanban page is built at once, fetching the board and opening the event stream without the user opening the tab (#97).

## What Changes

- The chat screen takes an optional callback that asks the shell to show Chat. It calls it for every notification tap and whenever it takes shared items. The shell switches to Chat.
- The shell forgets that Kanban was opened when the plugin goes off. When the plugin comes back on, the page is not built until the user selects the Kanban destination again.
- A notification tap switches to Chat even when the chat cannot be opened ("Could not open that chat."), so the message is shown on the screen the tap was about.
- While the plugin stays on, the Kanban page still stays alive behind Chat once opened, so its search text, filters, status chip and bulk selection survive a visit to Chat.

## Impact

- `lib/src/shell/app_shell.dart` and `lib/src/chat/chat_screen.dart` (one callback and two call sites).
- Tests: `test/app_shell_test.dart`.
- Specs: kanban, notifications and sharing (delta specs in this change).
- No new backend route or RPC method, no change to `packages/hermes_api`.

## Non-goals

- Stopping or pausing the board's event stream while the user is on Chat. #97 also reports that the stream keeps running there. This change keeps that behaviour on purpose, to keep the board's local state; a follow-up should add a pause and resume mode on the board controller.
- Disposing the Kanban page when the user leaves its tab.
- Closing a secondary screen (task detail, board management) that is open over the board when a tap or share arrives.
- Changing how a notification tap picks its chat, or how shared content is put in the composer.

## Security and privacy impact

None. No token, storage or network behaviour changes. The board is fetched and its socket opened less often, never more.

## Telemetry

None. No span, log event or attribute is added.
