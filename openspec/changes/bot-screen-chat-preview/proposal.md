# Proposal

## Why

On a phone the Activity panel is a sheet the user has to open; while Hermes clicks through a website the place they look is the transcript. This change shows the screen's still preview in the transcript for as long as the turn is using `computer_use`.

Design: https://claude.ai/artifact/Vh36BWznGNK6NZHJsqKQPJ

The series, one PR each, shipped and archived in this order:

1. `bot-screen-status`: repository and controller for the screen's state and still frames. No UI.
2. `bot-screen-card`: the Bot screen card in the Activity panel.
3. `bot-screen-chat-preview` (this change): the still preview in the transcript while a turn uses `computer_use`.
4. `bot-screen-rfb-client`: the display socket and a watch-only RFB 3.8 client. No UI.
5. `bot-screen-live-view`: the live, watch-only viewer.
6. `bot-screen-rfb-input`: pointer, key and clipboard messages, keysyms and gesture math. No UI.
7. `bot-screen-takeover`: take over and hand back control.
8. `bot-screen-host-install`: install the desktop packages on the server from the app.

Minimum Hermes version: the `display.*` methods first ship in Hermes v2026.9.24 (every later release, v0.21.x and v0.22.x, has them). An older server shows no preview.

## What Changes

- From the first `computer_use` call of a reply until that reply ends, the transcript shows the screen's still preview (Live badge, who is in control) right under the run of tool calls that holds the reply's latest `computer_use` call, outside any card: below the group header when consecutive calls are folded into a group, below the card of a single call. It moves to a later run when a later `computer_use` call starts, and leaves when the reply ends.
- The preview refreshes on the card's rules, and counts as a watcher only while it is actually on screen, not while it is merely built in the list's cache extent.
- Tapping or clicking the preview opens the Activity panel (it never closes it), where the Bot screen card is in Now. `bot-screen-live-view` later replaces this with the viewer.
- The preview is in the Widgetbook catalog and in `design/web` (`ToolCallCard` and `ToolCallGroup` preview slots).

## Non-goals

- Bots: tapping a bot opens its Bot Chat in the chat screen, so the preview reaches bot chats through the transcript; there is no bot page to add a group to.
- Previews of finished replies or a history of frames.
- Mac conversation windows and the quick panel (as in `bot-screen-card`).
- The live picture (`bot-screen-live-view`).

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `bot-screen`: the preview in the transcript while a turn uses `computer_use`.

## Impact

- `lib/src/chat/widgets/tool_call_group.dart`: an optional `preview` slot under the run.
- `lib/src/chat/chat_message_mapper.dart` picks the run that holds the reply's latest `computer_use` call of a pending reply; `lib/src/chat/widgets/chat_builders.dart` passes `BotScreenPreview` into it.
- New `lib/src/bot_screen/widgets/bot_screen_preview.dart`.
- `lib/src/chat/chat_screen_navigation.dart`: an open-only Activity action beside `_toggleActivity`.
- `BotScreenController`: thumbnail spans carry the number of watchers.
- New `lib/src/bot_screen/widgets/on_screen.dart`: a small in-repo check that tells on-screen from cache-extent builds (no new dependency).
- Widgetbook use cases; `design/web` `ToolCallCard`/`ToolCallGroup` `preview` props.

## Security and privacy

Same frames and rules as `bot-screen-status` and `bot-screen-card`: memory only, dropped on App Lock, sign-out, profile switch and when the preview leaves the screen. The preview is never part of Copy Transcript, drag out, notifications, the Live Activity or the watch.

## Observability

- Breadcrumb `bot_screen.preview.shown` once per reply when the preview first appears, and `bot_screen.preview.tapped`: user steps. No attributes.
- The `bot_screen.thumbnail` span gains `watchers` (count of surfaces on screen sharing the poll) instead of naming a single surface, since one poll feeds them all.
