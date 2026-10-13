## Context

See proposal.md for motivation. Scheduler queries already expose iOS Background App Refresh availability and whether a periodic task is registered. `runBackgroundRefresh` handles headless outcomes without throwing. Notification settings currently have no last-check record. This change uses those existing boundaries without changing scheduling or sending work.

## Goals / Non-Goals

Show truthful mobile capability and last-check state. Do not add a polling loop, settings switch, push token, backend route, or diagnostic history.

## Decisions

Store one versioned account-scoped record through `SharedPreferencesAsync`, containing an account hash, last attempt timestamp, last completed timestamp, and fixed outcome. Record attempt before headless opening when an account key is available; finish with completed, partial, locked, unreachable, or signed-out outcome. A recorded attempt without a terminal result displays incomplete, including when the process stopped before saving completion. Use a local generation token to prevent an old task from overwriting newer status or recreating status after sign-out. Keep this token content-free. Failures to store status are swallowed.

The UI displays notification permission and scheduler capability independently. iOS uses the existing native availability query. Android displays registered, not registered, or unknown using existing registration lookup. No Android background battery setting is inferred from registration. Refresh capability at settings open and app resume; read stored status asynchronously without blocking sign-in. Show last attempt and completion in the user's local time, with no claimed next check. Reuse system notification settings guidance rather than adding a new toggle.

No server push infrastructure exists in the inspected app/OpenAPI contract. An app-only change cannot create timely server-triggered delivery. Future work would require authenticated device registration/revocation, provider setup, and server notification events. Those prerequisites remain outside this proposal.

Platforms: iOS and Android settings and background runtime only. Shared Dart store must compile on macOS, Windows, and Linux, but those platforms display no mobile scheduler status. watchOS remains unchanged. No entitlement, manifest, or Xcode project changes.

Project invariants: no authentication side effects or hand-written REST calls; no new telemetry. Existing `background.task` spans and scheduling log events remain unchanged. The status record contains only timestamps, fixed outcomes, account hash, and generation. It must never store raw server URL, user ID, profile names, request IDs, text, or tokens. Sign-out/server-change invalidation clears the record; an old completion cannot restore it.

## Risks / Trade-offs

- OS scheduling remains best effort. UI text states that a task can be delayed or absent.
- A successful check is not a notification receipt. Use check terminology throughout.
- Device clocks can change. Display stored times without using them for scheduling, authentication, or alert deduplication.

## Migration Plan

First run starts with no recorded check. There is no migration of historical telemetry into settings. Rollback ignores this versioned record. Verify denied/unknown capabilities and interruption outcomes with fixtures, then exercise the UI in an isolated verification app.
