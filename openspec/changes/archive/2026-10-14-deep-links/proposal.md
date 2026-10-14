# Proposal

## Why

The iOS surfaces planned next (widgets, quick actions, Spotlight, App Intents, Control Center controls) each need a way to open the app on a specific place: a chat, a new chat with the microphone on, the oldest open request, Kanban, a scheduled job. Today the app opens a place only from a notification tap, a Live Activity tap (`hermes-activity://`) or Handoff, each with its own parsing. One URL scheme with one parser and one builder gives every later producer the same entry point, and lets the macOS work that follows reuse it.

## What Changes

- The app registers the `hermes` URL scheme on iOS, macOS and Android, and opens these links:
  - `hermes://chat?profile=<p>&id=<threadId>&prompt=<text>`: that chat in that profile, fetched when the loaded pages do not hold it; `prompt` fills its composer and is never sent by itself;
  - `hermes://new?profile=<p>&dictate=1&prompt=<text>`: a new chat (all parameters optional); `dictate=1` starts the microphone; `prompt` fills the composer and is never sent by itself;
  - `hermes://requests`: the chat of the oldest open request the app knows of, else the chat list;
  - `hermes://kanban`: the Kanban tab, when the server has it;
  - `hermes://schedules?profile=<p>&job=<id>`: the Schedules tab, optionally with that job open.
- A link that arrives before sign-in, or before the server's Kanban and Schedules check has answered, waits for it; only the latest waiting link is kept.
- Unknown or malformed links, and links to a tab the server does not have, are ignored.
- A pure parser and a builder (`lib/src/deep_links/`) are the only places that read or write these URLs, so producers added later cannot drift from the app.
- `hermes-activity://` (Live Activity taps) and `hermes-share` (macOS share inbox) stay as they are.

Non-goals:

- No universal links (`https://`), no associated domains, no web fallback.
- No links that act without the user: a link never sends a prompt, answers a request or changes a setting.
- No producers in this change. Widgets, quick actions, Spotlight and intents arrive in their own changes and use the builder.
- No cross-profile lookup of open requests. `hermes://requests` uses what the chat already knows; the snapshot written by background refresh is consulted by that later change.
- No deep links into conversation windows on macOS; the main window handles them.

Security and privacy impact: any app or web page can open a `hermes://` URL. The links only select what the user sees and prefill text the user must still send, so a hostile link can at worst open a chat or put text in the composer. A link does not unlock App Lock: the target opens behind the lock screen. No token, server address or user data is in a link; profile names and thread ids are, which are already in the Live Activity tap URL. Telemetry gets no URL, parameter or text.

Observability: breadcrumbs only, since a link is a user step that can explain a later crash and is not worth exporting on its own: `deeplink.opened` with `kind` (`chat`, `new`, `requests`, `kanban`, `schedules`), `cold` (launched the app) and `waited` (held until sign-in or detection); `deeplink.ignored` with `reason` (`unknown`, `malformed`, `unavailable`). No URL, profile, id or prompt.

## Capabilities

### New Capabilities

- `deep-links`: the `hermes://` URL scheme, the targets it opens, how links wait for sign-in and server detection, and what is ignored.

### Modified Capabilities

None. Notification and Live Activity taps keep their behaviour.

## Impact

- Dart: new `lib/src/deep_links/` (target model, parser, builder, listener), a hook in `AppShell` next to `_openJob`, and a new-chat request on `ChatOpenRequests` that `ChatScreen` turns into a new thread, a prefill and a dictation start.
- Dependency: `app_links` from pub.dev.
- iOS and macOS: `hermes` added to `CFBundleURLTypes` in `ios/Runner/Info.plist` and `macos/Runner/Info.plist`. Android: one `intent-filter` for the scheme in `AndroidManifest.xml`.
- Backend: none.
- Dependencies: none inside the iOS surfaces set (wave 1).
