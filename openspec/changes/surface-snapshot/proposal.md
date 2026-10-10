# Proposal

## Why

Home screen and Lock Screen widgets, quick actions, Spotlight and App Intents all show a little of the user's Hermes state: recent chats, open requests, Kanban and schedule status. WidgetKit extensions and intent entity queries cannot hold tokens or open network connections, and quick actions need the same list without a round trip. A single small snapshot, written by the app into the shared App Group whenever that state changes, gives every surface the same data, keeps the network and the session in the app, and makes it easy to check what may reach a locked screen.

## What Changes

- The app keeps a surface snapshot (Contract 2, key `hermes.surface.v1` in the App Group's `UserDefaults`): signed-in flag, current profile, the server's profile names (`profiles`, for intent pickers), up to 10 recent chats across profiles (title, snippet of at most 120 characters, time, `hermes://` link), open requests (chat title and kind only), Kanban blocked and in-review counts, and the next scheduled run and last failed job. Kanban and schedules are null when the server lacks them.
- The app writes it while in front: after the chat list loads, when a reply ends, when an open request appears or is answered, and when the app goes to the background. Network sources (other profiles' chats, Kanban, schedules) are re-read at most every five minutes in front and on every move to the background; chat changes in the open profile are applied at once.
- A source that fails or takes more than five seconds keeps its section from the previous snapshot (null when there is none), as the welcome view's starter prompts do.
- Sign-out (and an expired session, and Change Server) writes a signed-out snapshot with empty lists and null sections, and asks WidgetKit to reload.
- While App Lock is on, chat titles and snippets are left out of the snapshot (titles empty, no snippets or job names); counts and links stay.
- In-app listeners (quick actions, Spotlight, later) can subscribe to each write.

Non-goals:

- No widget, quick action, Spotlight or intent; each comes in its own change and reads the snapshot.
- No background writes; `background-refresh` adds them through the headless runtime.
- No cross-profile open-request lookup in front: requests of profiles the app is not showing are kept from the last background refresh until the next one.
- No macOS, Windows or Linux writing in this change (macOS is a later target). Android writes through the same plugin so quick actions can use it.
- No message text beyond the 120-character snippet the notification body already allows; no command, question or secret.

Security and privacy impact: the snapshot lives in the App Group container, readable by the app's own extensions only. It holds no token, server address or user identity. It holds chat titles, short snippets and profile names, which widgets will mark `.privacySensitive()` so a locked device redacts them; with App Lock on, titles and snippets are not written at all, because a widget on an unlocked home screen would otherwise show what App Lock hides. Open requests never include the command, question or secret name. Telemetry gets no content.

Observability:

- Span `surface.snapshot.build` (attributes `trigger`, `sources_failed`, `hermes.*`): a build crosses the network for up to three sources, and the span shows which trigger is costly or slow.
- Log event `surface.snapshot.write_failed` (`error.type`): a failed App Group write leaves every widget stale, which is worth counting.
- No breadcrumbs: writes are not user steps.

## Capabilities

### New Capabilities

- `surface-snapshot`: the shared snapshot of the user's Hermes state for system surfaces: its content, size and privacy limits, when the app writes it, how a failing source is handled, and the signed-out form.

### Modified Capabilities

None.

## Impact

- Dart: new `lib/src/surfaces/` (`SurfaceSnapshot`, `SurfaceSnapshotBuilder`, `SurfaceSnapshotStore`, `SurfaceSnapshots` updater); `ChatController` reports thread-list, reply-end and request changes through one optional callback; `main.dart` provides the updater; `AuthController.signedOut` triggers the signed-out write. Uses `deepLinkUri` from `deep-links` (or its URL shapes, if this merges first; see design).
- Dependency: `home_widget` from pub.dev.
- Dependencies on other changes in this set: none (wave 1). `home-screen-widgets`, `lock-screen-widgets`, `quick-actions`, `spotlight-search`, `app-intents` and `background-refresh` read the snapshot.
- iOS: no project change; the App Group is already on Runner and HermesLiveActivity.
- Backend: `GET /api/profiles`, `GET /api/sessions`, `GET /api/dashboard/plugins`, `GET /api/plugins/kanban/board`, `GET /api/cron/jobs?profile=all`, all already used.
