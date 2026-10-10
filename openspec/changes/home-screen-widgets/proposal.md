# Proposal

## Why

Hermes is something people check on: did the agent finish, is it waiting for an approval, did a scheduled job fail, is a Kanban task blocked. Today each of those answers needs the app opened. A Home Screen widget answers at a glance, and a tap goes straight to the chat, request or job concerned. The `surface-snapshot` change already writes everything a widget needs to the App Group; this change draws it.

## What Changes

- Three WidgetKit widgets on the iPhone and iPad Home Screen, rendered by the existing `HermesLiveActivity` widget extension (its bundle gains them next to the Live Activity):
  - **Recent chats** (small, medium, large): the newest chats across profiles with title, profile and age; medium and large add the latest-message snippet. A tap on a row opens that chat.
  - **Needs you** (small, medium): the number of open approvals, questions and other input requests across profiles, and in medium the chats they belong to. A tap opens the request's chat; the small widget opens the oldest request.
  - **Board** (small, medium): Kanban blocked and in-review counts, the next scheduled run, and the last failed job. Each part links to its tab or job; a part whose feature the server lacks is left out.
- Widgets read only the surface snapshot (`hermes.surface.v1` in the App Group). They make no network call and hold no token.
- Chat titles, snippets and job names are marked privacy sensitive, so iOS redacts them while the device is locked; counts stay visible.
- While App Lock is on the snapshot holds no titles or snippets; the widgets then draw redacted placeholders in their place, keep counts and ages, and still open the chat (where App Lock asks first).
- Signed out, or before the app wrote a snapshot, each widget shows "Open Hermes to sign in" and opens the app.
- A snapshot older than six hours adds "Open Hermes to refresh" (until `background-refresh` keeps it fresh).
- The app reports once a day which widgets are installed.

Non-goals:

- No Lock Screen, StandBy or Quick launch widgets; `lock-screen-widgets` adds them.
- No interactive widgets (buttons that approve or reply), no configurable widgets (pick a profile), no Control Center controls (`app-intents`).
- No Android or macOS widgets.
- No widget data beyond the snapshot, and no change to when or how the snapshot is written (`surface-snapshot`, `background-refresh`).
- No reply text beyond the snapshot's 120-character snippet, never a command, question or secret.

Security and privacy impact: the widget extension reads the App Group, which holds titles, snippets and counts but no token, server address or identity (Contract 2). Home Screen widgets are visible to anyone holding the unlocked phone; on a locked device (iPad Lock Screen, StandBy) titles and snippets are redacted by `.privacySensitive()`. The extension gets no network access and no keychain group. Telemetry carries widget kinds and counts only.

Observability:

- Log event `widgets.installed` through `AppEventLogger`, at most once a day on app start, with the count of installed widgets per kind and family: it is the only way to learn whether anyone uses them, since the extension has no telemetry.
- Log event `widgets.reload_failed` (error type) when reloading the timelines fails, so a broken bridge shows up.
- No span: nothing here waits on a server. Widget taps arrive as `hermes://` links, which `deep-links` already records.

## Capabilities

### New Capabilities

- `home-screen-widgets`: the Recent chats, Needs you and Board widgets: what each shows, where a tap goes, the signed-out and stale states, and what is redacted on a locked device.

### Modified Capabilities

None.

## Impact

- Depends on `deep-links` (the `hermes://` URLs and their handling); creates the Swift package `ios/HermesSurfaceKit` that `lock-screen-widgets` and `app-intents` reuse; and `surface-snapshot` (the JSON, the `home_widget` bridge and the store's reload after each write).
- iOS: new Swift files in `ios/HermesLiveActivity/` (added to that target in `project.pbxproj`); the Swift package `ios/HermesSurfaceKit` (snapshot reader and widget models, with tests), compiled into that target, which `app-intents` extends with the deep-link builder and entities; a CI step running `swift test` on it. No new target, bundle ID, entitlement or signing change.
- Dart: the widget kinds the snapshot store reloads, and the `widgets.installed` report.
- Backend: none.
