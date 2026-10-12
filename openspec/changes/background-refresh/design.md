# Design

## Context

See proposal.md for motivation and specs/ for behaviour. Builds on `headless-runtime` (`withHeadlessHermes`, `HeadlessOutcome`, `BackgroundPlugins`, `prepareBackgroundIsolate`), `surface-snapshot` (`SurfaceSnapshotBuilder`, `SurfaceSnapshotStore`) and #587 (on main) (`requestCategoryFor` and the `hermes.request.*` categories in `request_notifications.dart`). `background-refresh-alerts` adds steps to the run defined here.

What exists today:

- `HermesGatewayTransport.request(method, params)` sends a raw gateway RPC; Bot Mode uses it. `activeStatuses()` reads `session.active_list` by `session_key`.
- Gateway contract (`openrpc/hermes-gateway.openrpc.json`):
  - `session.active_list({profile?})` returns `sessions[]` of `{id, session_key, title, status, last_active, ...}`, where `status` is one of `idle`, `starting`, `waiting`, `working`, `streaming`, `resuming`.
  - `approval.pending({session_id, profile?})` returns `approvals[]` of `{request_id, command, choices, ...}`. This change never reads `command`.
  - There is no listing of open clarify, secret or sudo requests.
- `AttentionNotification` and `NotificationService.show` replace a chat's earlier notification, so each chat has one. `NotificationSettings` keeps `enabled` in shared preferences.

## Goals / Non-Goals

**Goals:**

- Everything finishes inside a 25 s budget.
- An open request is never announced twice by background runs.
- Each step is independent: one failure does not stop the others, and another change can add steps.
- Testable with `FakeHermesServer` and a fake gateway.

**Non-Goals:** finished replies and scheduled tasks (`background-refresh-alerts`), timing guarantees, answering requests, badge, macOS.

## Decisions

### `workmanager` (0.10.10) for scheduling

`workmanager` was published 2026-09-07 by fluttercommunity.dev and has 2400+ likes. It supports iOS through `workmanager_apple` (`BGAppRefreshTask` for periodic tasks) and Android through WorkManager, with one Dart API. It has a documented `setPluginRegistrantCallback` for the background engine.

A periodic task needs two registrations:

- Dart: `registerPeriodicTask(uniqueName, taskName, frequency: 15 min, initialDelay: 15 min, constraints: connected, existingWorkPolicy: keep)`. Android reads the frequency. `workmanager_apple` 0.9.11 ignores it on iOS and takes `initialDelay` as the earliest start of the BGAppRefreshTask, and repeats that delay after each run, so both are set.
- iOS: `WorkmanagerPlugin.registerPeriodicTask(withIdentifier:earliestBeginInSeconds:)` in `application(_:didFinishLaunchingWithOptions:)` (the `frequency:` variant is deprecated). BGTaskScheduler refuses a launch handler added after launch ends, which the Dart call alone would do on a first install. With UIScene the plugin cannot re-register handlers in time on its own, so this call is also what restores the handler on every launch.

The plugin warns that a frequency cannot be shortened after registration. 15 minutes is the floor on both platforms, so the frequency is set once and never changed.

The task's name is the BGTaskScheduler identifier on iOS (`<bundle id>.refresh`, read with `package_info_plus`, because the plugin hands that identifier to the Dart handler) and `hermes.background.refresh` on Android.

Alternatives:

- `background_fetch` (1.7.0, May 2026) wraps the same iOS API, but it needs a separate headless registration on Android and is less used.
- A hand-written BGTaskScheduler bridge would be about 120 lines of Swift, plus its own engine handling. Rejected per the dependency rule.

### Native setup

- `ios/Runner/Info.plist`: `BGTaskSchedulerPermittedIdentifiers` = `$(PRODUCT_BUNDLE_IDENTIFIER).refresh` (so the Debug build's `.dev` id differs), and `UIBackgroundModes` = `fetch`.
- `AppDelegate.application(_:didFinishLaunchingWithOptions:)` calls:
  - `WorkmanagerPlugin.setPluginRegistrantCallback { NotificationActions.registerPlugins($0) }`: `BackgroundPlugins` plus the Runner channels for the notification categories and the background task, which the run needs to register an approval's category;
  - `WorkmanagerPlugin.registerPeriodicTask(withIdentifier: bundleId + ".refresh", earliestBeginInSeconds: 900)`.
- `BackgroundPlugins` gains `home_widget` and `workmanager_apple`. Both add themselves as app delegates, as they do in their own background engines; that is harmless for a plugin whose events (a URL, a launch) the first instance already took. The macOS `GeneratedPluginRegistrant.swift` also lists `workmanager_apple` now, which nothing on macOS calls.
- Android: WorkManager's engine registers all plugins, so no manifest change.

Platforms affected: iOS, Android. No entitlement change.

### Scheduling in Dart (`background_scheduler.dart`)

`BackgroundScheduler` listens to `AuthController`:

- On reaching `ready`, it calls `Workmanager().initialize(backgroundRefreshDispatcher)` and `registerPeriodicTask(... existingWorkPolicy: keep)`.
- On `signedOut`, it calls `cancelByUniqueName`.

The listener only needs a `Listenable`, the connection state and the sign-out stream (`BackgroundScheduler.forAuth` binds them to `AuthController`), and the platform's task API sits behind `PeriodicTasks`, so both are faked in tests. Failures are logged as `background.refresh.schedule_failed` and swallowed, and the next transition to `ready` tries again. On other platforms it does nothing.

### The run (`background_refresh.dart`)

`backgroundRefreshDispatcher` (in `entry_points.dart`) does three things in order:

1. Calls `prepareBackgroundIsolate()`.
2. Calls `runBackgroundRefresh()` inside `Workmanager().executeTask`, always returning `true`. Returning `false` makes iOS less willing to schedule the task, and failures are already in telemetry.
3. Awaits `Telemetry.flush()`.

`runBackgroundRefresh` loads `NotificationSettings`, then calls `withHeadlessHermes(task: 'refresh', timeout: 25 s)` and switches over the `HeadlessOutcome`:

| Outcome               | Run does                                                                                   |
| --------------------- | ------------------------------------------------------------------------------------------ |
| `HeadlessDone`        | adds the step counts to the span                                                           |
| `HeadlessSignedOut`   | cancels the periodic task (the app in front registers it again on sign-in); nothing posted |
| `HeadlessLocked`      | nothing; the snapshot and announced ids stay as they are, the next run tries again         |
| `HeadlessUnreachable` | nothing; same as locked                                                                    |

No case clears the session or the snapshot; the snapshot's sign-out form is written only by the app in front. It runs a list of `BackgroundStep`s concurrently. A step is `Future<StepCounts> run(BackgroundContext)`, where the context holds the `HeadlessHermes`, whether notifications are on, the gateway transport (one socket shared by all steps, opened on first use), the announced-ids store, the notification service and the saved App Lock setting. Each step is settled on its own: an error or 20 s without an answer adds to `steps_failed`. The counts reach the `background.task` span through `HeadlessHermes.annotate`, after every step, so a run the budget cut off still shows what it had. `background-refresh-alerts` appends its steps to this list.

**Requests step:**

1. For each profile, call `session.active_list({profile})`.
2. For each session with status `waiting`, call `approval.pending({session_id: id, profile})`.
3. Each approval becomes a `PendingRequest(kind: approval, requestId)`.
4. A waiting session without any approval becomes `kind: input`, with the id `waiting:<session_key>:<last_active>`.

The chat id is `session_key`; the title comes from the session item. The requests found but not yet in `hermes.background.announced.v1` are posted with `kApprovalBody` or `kNeedsYouBody`, only when `settings.enabled` is on, one notification per chat (a later one would replace it). The notification goes through #587's `requestCategoryFor` and `pendingRequestFor`, built from an `ApprovalRequest` that holds the choices only, so an approval gets the same category and buttons as one raised in front, and the command is never read; with App Lock on it gets the placeholder category and no payload, as in front. This change adds no category of its own. Because a background launch never ran the app's start-up registration, `LocalNotificationService(background: true)` registers the category it posts under (the plugin's own `initialize` still registers none, which would drop the placeholders). The result is the cross-profile pending list.

If a profile's `session.active_list` is refused, the other profiles' requests are still announced, but the step then fails, so the snapshot keeps its previous pending list rather than dropping a profile's entries. An `approval.pending` that is refused counts as listing no approvals.

**Snapshot step:** waits up to 10 s for the requests step's pending list, or uses the previous list if that step failed or is late. Then it calls `refreshSnapshot(pending:)`:

- the builder runs with `refreshRemote`;
- the full cross-profile pending list replaces every profile's entries (`SurfaceSnapshotBuilder.build(pending:)`), which also drops entries of other profiles that earlier foreground snapshots left behind; a request already in the stored snapshot keeps its `createdAt`;
- the stored App Lock setting is read when the snapshot is saved: with it on, titles and snippets are omitted (counts stay) and the Spotlight listener clears the index instead of refreshing it, as in `surface-snapshot`.

The store writes the snapshot and its `writes` stream tells the listeners registered in the run's isolate. Nothing registers one yet; `spotlight-search` adds the Spotlight index there.

### Remembering announced requests

`hermes.background.announced.v1` in `SharedPreferencesAsync` holds what was already announced, keeping the newest 200. An entry is a request id, or the key of a wait (`g:<profile>/<session>/<turn>` for a wait announced without request ids, `a:...` for one announced with its approvals). The turn is the session's message count, else its `last_active`, else the hour, so a server that reports neither is announced once an hour. A request is new unless its id, or a `g:` key for its wait, is known; a generic wait is new unless either key for it is known. Ids are persisted only after the OS accepts a notification attempt, and the in-memory set advances only after persistence succeeds. A failed post or mark write stays eligible for a later live check; the stable chat notification ID replaces an earlier accepted attempt. Failure for one chat does not stop attempts for others. The app in front does not write it. A request the app already showed in front may be announced once more in the background. That notification replaces the chat's earlier one, so the user never sees two.

### `HeadlessHermes.refreshSnapshot()`

Added here, because `surface-snapshot` and `headless-runtime` were built in parallel. Its signature is `Future<SurfaceSnapshot> refreshSnapshot({List<PendingRequest>? pending})`, and it reads the previous snapshot from the store. The parameter is optional, so Contract 3's call shape still works. The store and the App Lock reader come from `HeadlessDeps` (the App Group and the saved setting by default), and the number of sources that could not be read goes on the span as `snapshot.sources_failed`.

### One grace for a run that is ending

`HeadlessDeps.closeGrace` used to be waited for twice: for a body to settle after the session failed (`execute`), then for a refresh to store its pair (`close`). All the waiting of a winding-down run, the sockets closing included, now shares one window that starts at the first wait. A run still lasts at most its timeout plus that grace (28 s at the defaults). The double wait could not be reproduced (a failed session leaves no refresh in flight), so the tests pin the bound instead.

### Two writers of the snapshot

The app in front and a background run both build the snapshot from the one they last read, and a run can be hours older than the app's idea of it. Contract 2 gains `revision`, an integer counting the writes of the stored snapshot (the Dart model carries it; the Swift reader never looks at it and ignores it whatever it holds). The rules are deliberately small:

- Every write saves the revision of what it replaces, plus one (`SurfaceSnapshotStore`).
- A background run reads the stored snapshot first (revision R) and builds from it. Right before saving, `writeIfCurrent` reads again. If the stored revision is still R, it saves R+1. Otherwise the app or another writer won, and the run drops its build whole and logs `surface.snapshot.write_skipped` (`reason`: `revision_changed`). There is no merging. Notifications already posted stay posted.
- A run never saves without having seen the stored state: a storage that fails to read, or a snapshot that cannot be understood, drops the build (`reason`: `unreadable`; nothing stored at all is fine). The app in front is not held to this.
- A run never writes over a stored snapshot that says signed out (`reason`: `signed_out`), and not after its own run is over (`reason`: `cancelled`; a body that outlived the timeout must not write).
- App Lock is read when saving, not when building, and asked before the stored snapshot is read, so only that read and the save lie between check and write. If it is on, the snapshot is redacted before saving.
- The app in front adopts the stored snapshot as its base when its revision is newer than the one it holds: on resume and before each build. That is how a run's open requests of every profile reach the app, whose own builds then replace only what they read (the open profile's chats and requests).

Remaining risk: between the re-read and the save there is one storage round trip. A sign-out landing in it is not seen by the run; the signed-in snapshot it saves is replaced by the next foreground write, which is the sign-out's own `clear` (a signed-out snapshot always writes) or, failing that, `SurfaceSnapshots.sessionChanged`. Two writers can still both pass the check if their reads interleave inside that window; the loser's data is one build old.

### The task has one budget

`backgroundRefreshTask` allows 25 s from the start of `prepare` to the end of the flush. The run's timeout is what is left after the isolate is ready, less `closeGrace` (3 s) and the flush budget (2 s), so a run that is cut off still has its wind-down and telemetry inside it. workmanager's expiration handler only logs, so nothing else would end the task. The engine's own start-up is outside this and is what the remaining seconds are for.

### Only an empty storage cancels

`HeadlessSignedOut` carries a reason. `noServer` and `noSession` cancel the periodic task. `rejected` (the server refused the refresh token) does not: the app in front may have rotated the pair, and the run lost a race. The foreground scheduler also checks on every resume that the system still has the task (`isScheduled`: WorkManager's query on Android, the plugin's pending-request listing on iOS) and registers it again if not; where the system cannot say, it leaves it. Register and cancel carry a generation, so a registration that was waiting on the platform gives way to a cancel that came after it.

### iOS refusals are logged

Background App Refresh turned off (or restricted) makes the whole feature a no-op. On iOS the scheduler reads `UIApplication.backgroundRefreshStatus` over `hermes_app/background_refresh` once per launch, after sign-in, and logs `background.refresh.unavailable` with the status (`denied` or `restricted`) when it is not `available`.

### The app in front announces for itself

WorkManager runs a task while the app is open. The app answers pings on `IsolateNameServer` (`AppPresence`, started with the scheduler) with whether its lifecycle is `resumed`; a run that gets `true` within 500 ms posts nothing and records nothing as announced, but still reads the requests for the snapshot. An app that is alive but suspended or cached answers `false`, and a port left by a dead isolate answers nothing, so neither suppresses the announcement.

### `hermes://requests` uses the snapshot

The chat screen first tries `ChatController.openOldestRequest`: the open profile's loaded chats are live, so they are the truth for that profile. Only then does `openOldestStoredRequest` read the stored snapshot's `pending`, for profiles other than the open one: the oldest `createdAt`, opened with `fetchMissing` (a profile the server no longer has is skipped by `knownProfile`). The snapshot can be stale, so each such request (oldest first) is checked with `session.active_list` for its profile before anything changes: the first whose session is still `waiting` is opened, and when none is, nothing moves and the chat list shows.

### Invariants touched

- Auth: only through `withHeadlessHermes`, which never signs out or clears storage.
- API layering: gateway RPCs go through `HermesGatewayTransport.request`; REST goes through the existing repositories.
- Telemetry:
  - counts are added to the `background.task` span in `runBackgroundRefresh`;
  - `background.refresh.schedule_failed` is logged in `BackgroundScheduler` with `error.type` and `platform`;
  - the dispatcher flushes at the end (`Telemetry.flush` is no longer test-only);
  - no id, title or text is recorded.
- Notifications: the same lock-screen texts as in front.

## Risks / Trade-offs

- [iOS runs the task at its discretion, often hours apart, and never after the user force-quits the app] → The spec documents it as best effort; widgets show the snapshot time.
- [About 30 s of runtime] → A 25 s budget, steps in parallel, one socket.
- [`session.active_list` may only see the dashboard process's sessions, and its answer may differ per profile] → It is asked per profile. A real-backend contract case checks its row shape; whether other profiles' sessions show without `profile` is not yet verified (task 1.1 was not run: no `hermes` on the build machine).
- [`approval.pending` may expect the `session_key` rather than the runtime `id`] → The step sends the runtime `id`, as every other `session_id` parameter takes. The contract case asks it that way. On CI's backend (no model provider) `session.active_list` answered for every profile argument, but `approval.pending` was refused with code 5032 ("not connected to any AI provider"), so that case skips there; the step reads a refused `approval.pending` as no approvals.
- [A waiting session may be a clarify, secret or sudo request] → It is announced as "Waiting for you in Hermes" without a request id. Deduplication uses `last_active`, so a new wait is announced again.
- [The periodic frequency cannot be shortened once registered] → It is set once, at 15 minutes.

## Migration Plan

Only a new preferences key. To roll back, ship a build without the task; iOS drops a task whose identifier the app no longer registers.
