# Proposal

## Why

The Lock Screen and StandBy are where a phone is looked at most without being unlocked. Two things fit there: how many requests are waiting for the user, and a one-tap way into a new chat or dictation. `home-screen-widgets` draws the snapshot on the Home Screen; this change adds the small accessory and StandBy forms, kept apart so each PR stays reviewable.

## What Changes

- **Needs you** gains the Lock Screen families: circular (the count of open requests with a hand symbol), rectangular (the count and "Approval"/"Question"/"Waiting for you" for the oldest one, its chat title redacted while locked) and inline (for example "2 waiting in Hermes"). A tap opens the oldest request's chat, or the chat list when none is open.
- Two new **Quick launch** widgets:
  - **New Chat**: Lock Screen circular, and small for the Home Screen and StandBy. Opens a new chat in the app's current profile.
  - **Dictate**: Lock Screen circular, and small for the Home Screen and StandBy. Opens a new chat with the microphone started.
- A medium **Quick launch** widget holds both buttons side by side for the Home Screen and StandBy.
- All of them read only the surface snapshot (whether the user is signed in, counts and titles) and link with `hermes://` URLs. Signed out, Quick launch widgets still open the app, which shows sign-in.

Non-goals:

- No Control Center or Action Button controls (`app-intents` adds those as `ControlWidget`s).
- No answering a request from the Lock Screen; the user unlocks and opens the app.
- No configurable profile per widget; a new chat uses the app's current profile.
- No Recent chats or Board accessory families.
- No Android or macOS equivalents.

Security and privacy impact: Lock Screen widgets are seen by anyone who picks up the phone. Only counts, symbols and fixed labels are shown in the clear; the rectangular family's chat title is `.privacySensitive()` and redacted while locked. A tap needs the device unlocked before the app opens (iOS behavior for widget links). No token, server address or identity is read; the extension has no network. Telemetry carries kinds and counts only.

Observability:

- The new kinds are counted by the `widgets.installed` log event from `home-screen-widgets` (per kind and family), which is what tells whether Lock Screen placements are used.
- No new span, log event or breadcrumb: the extension has no telemetry, and taps arrive as `hermes://` links that `deep-links` records.

## Capabilities

### New Capabilities

- `lock-screen-widgets`: the Needs you accessory families and the New Chat, Dictate and Quick launch widgets: what each shows, where a tap goes, and what stays hidden on a locked device.

### Modified Capabilities

None. The Home Screen sizes of `home-screen-widgets` are unchanged.

## Impact

- Depends on `home-screen-widgets` (the `ios/HermesSurfaceKit` package, the extension's snapshot decoder, provider and `kSurfaceWidgetKinds`), `deep-links` (`hermes://new`, `hermes://new?dictate=1`, `hermes://requests`) and `surface-snapshot`.
- iOS: new Swift files in `ios/HermesLiveActivity/` and their `project.pbxproj` entries; two SF Symbol-only views, no new assets. No new target, entitlement or signing change.
- Dart: two kinds appended to `kSurfaceWidgetKinds`.
- Backend: none.
