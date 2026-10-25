# Proposal

## Why

The screen is most often needed when the agent cannot go on: a login, a 2FA code, a CAPTCHA, a payment confirmation. While a person holds the screen's control lease Hermes refuses its own screen actions and lets the person act in the session the agent was using. This change lets the user take over from the viewer, use the screen, and hand it back.

Design: https://claude.ai/artifact/Vh36BWznGNK6NZHJsqKQPJ

The series, one PR each, shipped and archived in this order:

1. `bot-screen-status`: repository and controller for the screen's state and still frames. No UI.
2. `bot-screen-card`: the Bot screen card in the Activity panel.
3. `bot-screen-chat-preview`: the still preview in the transcript while a turn uses `computer_use`.
4. `bot-screen-rfb-client`: the display socket and a watch-only RFB 3.8 client. No UI.
5. `bot-screen-live-view`: the live, watch-only viewer.
6. `bot-screen-rfb-input`: pointer, key and clipboard messages, keysyms and gesture math. No UI.
7. `bot-screen-takeover` (this change): take over and hand back control.
8. `bot-screen-host-install`: install the desktop packages on the server from the app.

Minimum Hermes version: `display.lease.acquire`/`release`, `viewer_hash` and `force` release first ship in Hermes v2026.9.24 (every later release, v0.21.x and v0.22.x, has them).

## What Changes

- **Take over** in the viewer. The app asks first: Hermes stops using the screen until you hand it back, and the step it is on may end and need you to tell it to continue (its screen tool reports that a human has control); what you type goes to the server's desktop; this app's previews and its viewers on other devices hide the picture meanwhile (Hermes Desktop's live viewers may still see it). "Don't ask again" is remembered per account.
- Acquire and release go over the gateway connection that minted the viewer id; if that connection changed, the app observes again and retries once. "You're in control" comes from the acquire and release answers as well as the broadcasts.
- **In control** the viewer sends input: Touch mode (tap clicks, long press right-clicks, one-finger drag drags) or Trackpad mode on touch devices; mouse and keyboard on computers; the on-screen keyboard through a hidden field with autocorrect, suggestions and learning off, sending text only when it is committed; a key bar with Esc, Tab, Ctrl, Alt, arrows and Paste.
- **Reserved keys on computers**: Paste (⌘V on macOS, Ctrl+V on Windows and Linux) over the picture runs the Paste action; ⌘Q, ⌘W, ⌘H, ⌘M and ⌘Tab stay with the app and the system; other ⌘ chords are sent as Ctrl; Escape goes to the screen; the viewer closes with its Close button or ⌘. on macOS and F8 on Windows and Linux (the toolbar offers Send F8).
- **Paste** sends the device clipboard's text to the screen's clipboard, presses Ctrl+V, and shortly after clears the screen's clipboard so a pasted secret does not stay there. Text outside Latin-1 is refused with a message. On iOS the system may ask permission to paste.
- **Hand Back** releases the lease; closing the viewer hands back too. Backgrounding and App Lock keep control: the stream closes with 4100, which the server treats as a dropped link, and the viewer takes control again on return. A quick cover (the notification shade, a Control Center glance) does not close the stream. Sign-out, a profile switch and Change Server hand back before closing.
- When another person takes control (4000, or a lease naming someone else) the viewer returns to watching and says so.
- **Hand back to Hermes** (force): when a person holds the lease under a viewer id this app does not hold (for example this device before the app restarted), the card and the viewer offer to hand control back to Hermes, behind a confirmation, with `display.lease.release {force: true}`. This frees a stranded lease.
- Every surface says "You're in control" while this device holds the lease.

## Non-goals

- Resizing the remote desktop (SetDesktopSize), file transfer, audio, multi-monitor.
- Taking over from the watch, a notification, a Mac conversation window or the quick panel.
- Pasting text outside Latin-1 (`bot-screen-rfb-input` explains why).
- Remembering the Touch/Trackpad choice across launches.
- Taking over from the card directly; the card opens the viewer.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `bot-screen`: taking over and handing back control, input while in control; the viewer is no longer always watch-only, Escape belongs to the screen while in control, and the stream's lifecycle keeps control across backgrounding.

## Impact

- `BotScreenRepository.acquire`/`release`; `HermesGatewayTransport`: a request pinned to a given connection.
- `BotScreenViewerController`: lease state, viewer ids, lifecycle codes; `BotScreenController`: "you" from the held viewer ids.
- Viewer chrome: Take over, Hand Back, the key bar (touch), the toolbar (desktop), Touch/Trackpad switch, the confirmations; `ScreenGestureLayer` and the hidden text field wired in. Widgetbook use cases and `design/web` `BotScreenViewer` states.
- Shared preferences: one boolean per account for the confirmation.

## Security and privacy

- Input goes only to the profile's own screen over the ticketed stream; the server's lease gate is the enforcement and the app adds no bypass.
- The viewer id is a capability. It is held in memory for the app's life, never stored or logged, and sent only to `display.observe` and the lease calls on the connection that minted it.
- Typed and pasted text, key names and pointer coordinates go to the server only as RFB messages and are never logged, kept or sent to telemetry. The on-screen keyboard's field has autocorrect, suggestions, smart punctuation and keyboard learning off and a password keyboard type, so the system keyboard does not learn or suggest what is typed into the screen; composing text is sent only when committed. Paste sends only what the user pastes and clears the screen's clipboard afterwards.
- Force hand back can take control away from another person; it asks first and is logged as its own reason.
- The confirmation preference is a boolean keyed by the account hash (`accountKeyFor`), not a server address.

## Observability

- Log events `bot_screen.takeover` (`outcome`: `acquired`, `refused`, `retried`, `error`), `bot_screen.handback` (`reason`: `button`, `close`, `sign_out`, `profile`, `server`, `force`, `error`) and `bot_screen.lost_control` (`cause`: `control_taken`, `other_holder`): outcomes worth counting. `bot_screen.paste_refused` (`reason`: `not_latin1`, `too_large`).
- Span attributes `took_over` (bool) and `input_events` (bucketed count) on `bot_screen.stream`.
- Breadcrumbs `bot_screen.takeover.pressed`, `bot_screen.handback.pressed`, `bot_screen.force_handback.pressed` and `bot_screen.input.mode` (`touch`, `trackpad`).
- Never key names, text, coordinates, viewer ids or profile names.
