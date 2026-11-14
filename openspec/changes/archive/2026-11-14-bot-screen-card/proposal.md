# Proposal

## Why

`bot-screen-status` reads a profile's screen and fetches still frames, but nothing shows them. This change puts a **Bot screen** card in the chat's Activity panel, so a user can see what the agent's desktop shows, who is in control, and why there is no screen when there is none.

Design: https://claude.ai/artifact/Vh36BWznGNK6NZHJsqKQPJ

The series, one PR each, shipped and archived in this order:

1. `bot-screen-status`: repository and controller for the screen's state and still frames. No UI.
2. `bot-screen-card` (this change): the Bot screen card in the Activity panel.
3. `bot-screen-chat-preview`: the still preview in the transcript while a turn uses `computer_use`.
4. `bot-screen-rfb-client`: the display socket and a watch-only RFB 3.8 client. No UI.
5. `bot-screen-live-view`: the live, watch-only viewer.
6. `bot-screen-rfb-input`: pointer, key and clipboard messages, keysyms and gesture math. No UI.
7. `bot-screen-takeover`: take over and hand back control.
8. `bot-screen-host-install`: install the desktop packages on the server from the app.

Minimum Hermes version: the `display.*` methods first ship in Hermes v2026.9.24 (every later release, v0.21.x and v0.22.x, has them). An older server answers method-not-found and shows no card.

## What Changes

- A **Bot screen** card in the Activity panel's **Now** section (a Working item) for the open chat's profile, while that profile's screen runs or the open chat has a `computer_use` tool call. Nothing is added to the strip above the transcript.
- The card's states, chosen in this order: **Not offered** (`supported: false`: the server uses its own display), **Not installed** (the install command to copy, or, for a profile whose screen lives in the terminal sandbox, that the sandbox image needs the desktop stack), **Blocked** (the server's blocker text, with the free memory when reported), **Starting**, **Off** (with **Start Screen**), **Error** ("Couldn't read the screen", with Try Again), and running: the latest still frame refreshed every 3 seconds, or "Someone else is in control" with no picture while a person holds control.
- The running card has an **Enlarge** action that stays hidden until `bot-screen-live-view` gives it something to open.
- Frames are requested only while the app is in the foreground, the Activity panel shows the card, App Lock does not cover the app and, on macOS, the main window is on screen.
- The card is built in the Widgetbook catalog first and mirrored in `design/web` so Claude Design gets it at the next design sync.

## Non-goals

- Bot Screen in Mac conversation windows and in the quick panel. Conversation windows have no App Lock of their own (`lib/src/windows/conversation_window_app.dart`), so a frame there could outlive a lock; the quick panel has no Activity panel.
- The preview in the transcript (`bot-screen-chat-preview`), the live picture (`bot-screen-live-view`), control (`bot-screen-takeover`) and installing packages from the app (`bot-screen-host-install`).
- Stopping the screen.
- A card in the strip above the transcript.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `bot-screen`: the Bot screen card in the Activity panel.

## Impact

- New `lib/src/bot_screen/widgets/bot_screen_card.dart` (plain model and callbacks) and `widgetbook/bot_screen_use_cases.dart`.
- `lib/src/chat/activity/bound_activity_panel.dart`: takes the chat profile's `BotScreenController` (today it takes only `chat` and `thread`) and adds the card to Now; `activity_tier.dart` gains a Working kind for it.
- `lib/src/chat/chat_screen.dart` and its parts: own one `BotScreenController` per chat profile and pass it to the panel and the phone sheet.
- `design/web/src/components/BotScreenCard/` and `design/web/docs/BotScreenCard.md`.

## Security and privacy

- Frames follow `bot-screen-status`: memory only, dropped on App Lock, sign-out and profile switch. The card also drops its frame when it leaves the panel and never keeps an older frame on screen while a person holds control.
- The install command and blocker text are shown, never logged.
- No tokens or storage change.

## Observability

- Log event `bot_screen.start` with `outcome` (`started`, `blocked`, `error`) when the user presses Start Screen: an outcome worth counting.
- Breadcrumb `bot_screen.card.shown` with `state` (fixed values), recorded only when the card's state changes, and `bot_screen.start.pressed`: user steps that explain a later crash.
- The thumbnail span and `bot_screen.read_failed` from `bot-screen-status` cover each poll and the Error state; every poll also produces the `GatewayRpcClient` request span, which is why the poll stays at 3 s.
