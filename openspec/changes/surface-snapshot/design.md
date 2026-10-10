# Design

## Context

See proposal.md for motivation and specs/surface-snapshot/spec.md for behaviour. The JSON shape is Contract 2 of the iOS surfaces rollout and is not reopened here.

What exists today:

- `StarterContextLoader` (`lib/src/chat/starter_context_loader.dart`) reads cron jobs, the Kanban board and skills in parallel, each settled with a 5 s timeout so a failing source becomes null. The snapshot builder follows the same pattern.
- `HermesChatRepository.loadThreads(limit:, profile:)` returns `ChatThread`s (id, title, `updatedAt` from `last_active`) without messages. `KanbanRepository.loadBoard()` returns columns by status (`blocked`, `review`). `HermesCronRepository.listJobs(profile: 'all')` returns `CronJob`s with `nextRunAt`, `lastRunAt`, `outcome`, `profile`. `HermesPluginsRepository.isKanbanEnabled()` and `HermesCronRepository.isAvailable()` tell whether the sections exist.
- `replyPreview` (`attention_policy.dart`) cuts text to one line of 120 characters.
- `ChatController` holds the open profile's threads, sees every reply event in `_onReplyEvent`, and knows the open `InputRequest`s (approval, clarify, secret/sudo) of each reply.
- The App Group `group.com.cedricziel.hermesApp` (`kLiveActivityAppGroup`) is on Runner and HermesLiveActivity in every configuration.
- `AuthController.signedOut` fires on sign-out, an expired session and Change Server. `AppLockController` knows whether App Lock is on.

## Goals / Non-Goals

**Goals:** one writer in Dart, one JSON format, every section tolerant of failure, cheap in front (no extra request per chat event), testable without iOS.

**Non-Goals:** widget kinds, background writes, macOS.

## Decisions

### `home_widget` (0.10.0) as the App Group bridge

Published 2026-09-17, 2200+ likes, iOS and Android, supports the UIScene lifecycle (0.9.3). `saveWidgetData<String>(key, value)` writes to `UserDefaults(suiteName: groupId)` (iOS) and the plugin's `SharedPreferences` (Android), and `updateWidget(iOSName:)` calls `WidgetCenter.reloadTimelines(ofKind:)`. It claims only URLs carrying a `homeWidget` query item, so `hermes://` and `hermes-activity://` are unaffected. Its interactive/background callbacks are not used.

Trade-off: it reloads by widget kind, not all timelines. The store keeps `kSurfaceWidgetKinds` (empty in this change); `home-screen-widgets` adds its kinds there. Alternative: a hand-written channel for `UserDefaults` and `reloadAllTimelines` (about 40 lines of Swift). Rejected per the dependency rule; `home-screen-widgets` will also need the plugin on Android.

### Module `lib/src/surfaces/`

- `surface_snapshot.dart`: immutable `SurfaceSnapshot` with `RecentChat`, `PendingRequest` (`kind`: `approval`, `question`, `input`), `KanbanSummary`, `ScheduleSummary`, `FailedJob`; `toJson`/`fromJson` exactly per Contract 2 (ISO-8601 UTC times, `version: 1`); `fromJson` is lenient (unknown version or bad JSON → null) and `SurfaceSnapshot.signedOut()` is the empty form. Caps are enforced in the constructor: 10 recent chats, snippets via `replyPreview`, titles cut at 80 characters.
- `surface_snapshot_builder.dart`: `SurfaceSnapshotBuilder(HermesRepositories, {timeout: 5 s})` with `Future<SurfaceSnapshot> build({required SurfaceSnapshot? previous, ChatHints? chat, bool refreshRemote})`. With `refreshRemote`, it reads in parallel: profiles (their names become `profiles`, kept from `previous` on failure), then `loadThreads(limit: 10, profile: p)` per profile; `isKanbanEnabled` then `loadBoard`; `isAvailable` then `listJobs(profile: 'all')` (next run = earliest future `nextRunAt` of an enabled job; last failed = latest `lastRunAt` with `outcome != ok`). Each settles to "unknown" on error or timeout and then keeps `previous`'s section. "Unavailable" (Kanban off, no cron routes) sets the section to null. `ChatHints` (the open profile's threads with the last loaded message text, and its open requests) override the open profile's rows and pending entries without a request. Pending entries of other profiles come from `previous`.
- `surface_snapshot_store.dart`: `SurfaceSnapshotStore` with `read()`, `write(snapshot)` (JSON, `saveWidgetData`, `updateWidget` per kind, then emit on `writes`), and `clear()` (writes `signedOut()`). Skips the native write when the JSON equals the last one written. Every native call is wrapped; a failure logs `surface.snapshot.write_failed` and still emits to listeners. A platform without the plugin (macOS, desktop, tests) gets an in-memory store.
- `surface_snapshots.dart`: `SurfaceSnapshots`, the foreground updater provided in `main.dart` beside `HermesRepositories`. `chatChanged(ChatHints)` debounces 2 s and builds with `refreshRemote` only when the last remote read is older than 5 minutes; `didChangeAppLifecycleState(paused)` builds at once with `refreshRemote`; it listens to `AuthController.signedOut` and calls `store.clear()`. It reads `AppLockController.enabled` and passes `redact: true` to the builder, which then writes empty titles and no snippets or job names; counts, ids and links stay. One build at a time; a request during a build schedules one more. A move to the background reads the remote sources and, when the server has not answered within 800 ms, first writes what is known without the network (hints, App Lock), since iOS gives a suspended app little time; an earlier answer makes it one write and one widget reload. Turning App Lock on writes the stored snapshot redacted at once, without a server read, and a build that was under way respects the App Lock state when it is written; turning it off reads every source again, since what was written meanwhile had no titles. Nothing is built or written unless the connection is `ready` (repositories outlive a session, so their presence says nothing), and a read of the stored snapshot that a sign-out overtook is discarded. Deleting or archiving a chat reports `threads`, so its entry and open requests leave the snapshot. A job without a name of its own shows `Scheduled task`, never its prompt. `fromJson` returns null for any malformed shape. The store seeds its last-written snapshot from storage on first use, so an unchanged cold start writes nothing. The store compares content without `updatedAt` when it skips an unchanged write, so `updatedAt` is the time the content last changed.

### Feeding it from `ChatController`

`ChatController` gets an optional `void Function(SurfaceTrigger, ChatHints)? onSurfaceChange`, called after `loadThreads` finishes, when a reply stops being pending (completion, failure, stop) and when the set of open input requests of a reply changes (opened, answered, expired, withdrawn). Both are detected in `_updateReply`, which every reply edit goes through, so no event type is listed twice. `ChatHints` holds per thread: id, title, `updatedAt`, `replyPreview` of the last message text when loaded, and the open requests with the time the app first saw each (Hermes sends no creation time; see the spec). Conversation windows pass none, so only the main window writes.

### Links

Each row's `url` is built with `deepLinkUri` from `deep-links`. If this change merges first, a three-line private builder with the same shapes is used and replaced by `deepLinkUri` in `deep-links`' PR; the contract test pins the shape either way.

Platforms affected: iOS (App Group writes, WidgetKit reloads) and Android (plugin preferences). No entitlement, manifest or Xcode project change; the App Group already exists.

### Invariants touched

- Tokens: none in the snapshot; no server address or identity. Tested by a check that the JSON has no `token`, `http` or `@`.
- Telemetry: span `surface.snapshot.build` in `SurfaceSnapshots` with `trigger` (`threads`, `reply`, `request`, `pause`, `app_lock`), `sources_failed` and the connection's `hermes.*`; logs `surface.snapshot.write_failed` and `surface.snapshot.reload_failed` (a widget reload that failed after a successful save) in the store with `error.type`. No titles, ids or profile names.
- API layering: only existing repositories, all on the generated client.
- Tests: `FakeHermesServer` for the builder; a fake `HomeWidget` channel for the store.

### Dependencies

None inside this set of changes (wave 1).

### Deviations found while building

- Kanban and schedules availability come from `isKanbanEnabled` and `isAvailable`, which turn every error into "unavailable". A transient failure of that one probe therefore sets the section to null until the next read (at most five minutes in front, or the next background move). The other reads keep their previous section as designed.
- The store has a small `SurfaceStorage` interface (`HomeWidgetSurfaceStorage` on `home_widget`), so most store and updater tests use a fake storage; the plugin's channel is covered by its own tests.
- Per-call timeouts: profiles then their chats are two sequential reads of at most five seconds each.
- `bot` registry chats (`isCanonicalBotChat`) and chats without a server id are left out of the hints.

## Risks / Trade-offs

- [A source fails for days, and its section stays old] → `updatedAt` is per snapshot, not per section; widgets show the snapshot time. Accepted for now.
- [Chat list rows carry no last message] → snippet only for chats the app has loaded or that ended a reply; otherwise absent (the contract allows it).
- [Writes on every reply event would be costly] → only reply end and request changes trigger, debounced 2 s; the native write is skipped when nothing changed.
- [Profiles with many chats] → 10 per profile are read; only 10 overall are kept.
- [App Lock redaction makes widgets less useful] → deliberate; App Lock's purpose is to hide chats from someone holding the unlocked phone.

## Migration Plan

New key only. Rollback leaves a stale key in the App Group, which nothing reads until widgets ship; sign-out of a newer build overwrites it.
