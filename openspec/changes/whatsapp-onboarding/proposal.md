# Proposal

## Why

The Messaging screen can switch WhatsApp on and take its settings, but the account has to be linked first, and only the web dashboard does that: it starts a bridge on the server, shows a QR code and waits for a scan. The app already pairs Telegram this way (`profiles-and-bots`). WhatsApp has the same routes and nothing in the app uses them.

## What Changes

- A **Link WhatsApp** button above the manual fields of the WhatsApp platform's setup form, opening a pairing screen: choose the mode (Bot, or Self-chat) and who may message it, then start. The server starts its bridge; the screen shows its progress, then the QR code, then the linked account.
- The user scans the QR in WhatsApp (Settings, Linked devices, Link a device) **on the phone that has the account**. That phone cannot scan its own screen, so on a handset the screen first says to open it on another device and shows the code only after a tap. Mac, Windows, Linux and tablets show it at once.
- Finish applies the setup to the chat's profile: the server saves the WhatsApp settings and asks its messaging gateway to restart, which can still refuse. The app asks first, because a restart interrupts conversations on messaging channels.
- Leaving before Finish cancels the pairing.

Non-goals:

- Linking by phone number and code: the server's bridge has no such mode.
- Unlinking or replacing a linked account: no server route; a pairing started over a linked session reports "connected" at once.
- Allowed senders other than phone numbers: `*` (everyone) and JIDs/LIDs, which the bridge accepts, are not offered here, so the app never opens the bot to everyone. They stay a server setting.
- Group, reply-prefix and other WhatsApp settings: they stay in the setup form.
- Approving the pairing codes strangers send to the bot.
- Telegram, which is unchanged.

## Capabilities

### New Capabilities

- `whatsapp-onboarding`: starting, polling, finishing and cancelling a WhatsApp link, the QR code and its secrecy, and the phone flow.

### Modified Capabilities

None. `profiles-and-bots` gains a sibling entry point only.

## Impact

- Code: `lib/src/messaging/` (a repository group on `HermesMessagingRepository`, a pairing screen and plain-model widgets in `widgets/`), a QR renderer package chosen under the pub.dev rule, Widgetbook use cases. No new route; the generated client has all four methods.
- Platforms: all but watchOS. No native change.
- Security and privacy: the QR payload and the pairing id are credentials. They live in screen state only: never logged, in a span, a breadcrumb, preferences, the clipboard (no Copy button) or a screenshot-friendly cache, and cleared when the screen closes. When App Lock locks or the app leaves the foreground the code is hidden: on a handset it needs the "Show QR code" tap again, on a tablet or computer it returns on unlock or return. The linked account's name and number are shown to the user and never recorded.
- Observability: span `whatsapp.pair.start` (`outcome`) and `whatsapp.pair.apply` (`outcome`, `restart` requested | not_requested); log events `whatsapp.pair.ended` (`status` connected | error | expired | cancelled | superseded) and `whatsapp.pair.unavailable`; breadcrumbs `whatsapp.pair.opened`, `whatsapp.pair.qr_shown`, `whatsapp.pair.applied`. Fixed words only.
- Delivery: two PRs, the catalog widgets first, then the screen.

## Design pass

For the later Claude Design pass; every screen covers loading, error, offline, lost answer, long text, dark, large text, and phone and desktop width.

- Link WhatsApp, setup - mode (Bot, Self-chat) with one line each, allowed numbers field, Start. States: empty, invalid number, server refused.
- Link WhatsApp, preparing - "Installing" and "Starting" (the server may install packages for up to 5 minutes), Cancel.
- Link WhatsApp, handset notice - "Scan this with the phone that has WhatsApp", Show QR code. States: before and after the tap.
- Link WhatsApp, QR - the code, a countdown to expiry, "Waiting for a scan", steps to scan. States: code replaced while shown, expiring, expired (Start again).
- Link WhatsApp, linked - account name and number, "Already linked" variant, Finish, the restart question.
- Link WhatsApp, failed - the server's reason (setup could not install Node, bridge exited with a code), Start again; and "Superseded".
- Finish result - saved, restart requested; saved, restart not requested (restart it from Server); lost answer; "setup no longer on the server" with Start again.
