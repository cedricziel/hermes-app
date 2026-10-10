# Design

## Context

See proposal.md for motivation and specs/ for behaviour. Builds on `headless-runtime` (`withHeadlessHermes`, `HeadlessOutcome`, `BackgroundPlugins`, `prepareBackgroundIsolate`), `surface-snapshot` (`SurfaceSnapshotBuilder`, `SurfaceSnapshotStore`) and peer PR #587 (the reusable notification category builder for approvals and questions). `background-refresh-alerts` adds steps to the run defined here.

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

- Dart: `registerPeriodicTask(uniqueName, taskName, frequency: 15 min, constraints: connected)`.
- iOS: `WorkmanagerPlugin.registerPeriodicTask(withIdentifier:frequency:)` in `application(_:didFinishLaunchingWithOptions:)`. BGTaskScheduler requires registration before launch ends.

The plugin warns that a frequency cannot be shortened after registration. 15 minutes is the floor on both platforms, so the frequency is set once and never changed.

Alternatives:

- `background_fetch` (1.7.0, May 2026) wraps the same iOS API, but it needs a separate headless registration on Android and is less used.
- A hand-written BGTaskScheduler bridge would be about 120 lines of Swift, plus its own engine handling. Rejected per the dependency rule.

### Native setup

- `ios/Runner/Info.plist`: `BGTaskSchedulerPermittedIdentifiers` = `$(PRODUCT_BUNDLE_IDENTIFIER).refresh` (so the Debug build's `.dev` id differs), and `UIBackgroundModes` = `fetch`.
- `AppDelegate.application(_:didFinishLaunchingWithOptions:)` calls:
  - `WorkmanagerPlugin.setPluginRegistrantCallback { BackgroundPlugins.register(with: $0) }`;
  - `WorkmanagerPlugin.registerPeriodicTask(withIdentifier: Bundle.main.bundleIdentifier! + ".refresh", frequency: 900)`.
- `BackgroundPlugins` gains `home_widget` and `workmanager_apple`.
- Android: WorkManager's engine registers all plugins, so no manifest change.

Platforms affected: iOS, Android. No entitlement change.

### Scheduling in Dart (`background_scheduler.dart`)

`BackgroundScheduler` listens to `AuthController`:

- On reaching `ready`, it calls `Workmanager().initialize(backgroundRefreshDispatcher)` and `registerPeriodicTask(... existingWorkPolicy: keep)`.
- On `signedOut`, it calls `cancelByUniqueName`.

Failures are logged as `background.refresh.schedule_failed` and swallowed. On other platforms it does nothing.

### The run (`background_refresh.dart`)

`backgroundRefreshDispatcher` (in `entry_points.dart`) does three things in order:

1. Calls `prepareBackgroundIsolate()`.
2. Calls `runBackgroundRefresh()` inside `Workmanager().executeTask`, always returning `true`. Returning `false` makes iOS less willing to schedule the task, and failures are already in telemetry.
3. Awaits `Telemetry.flush()`.

`runBackgroundRefresh` loads `NotificationSettings`, then calls `withHeadlessHermes(task: 'refresh', timeout: 25 s)` and switches over the `HeadlessOutcome`:

| Outcome               | Run does                                                                                  |
| --------------------- | ----------------------------------------------------------------------------------------- |
| `HeadlessDone`        | adds the step counts to the span                                                          |
| `HeadlessSignedOut`   | cancels the periodic task (the app in front registers it again on sign-in); nothing posted |
| `HeadlessLocked`      | nothing; the snapshot and announced ids stay as they are, the next run tries again        |
| `HeadlessUnreachable` | nothing; same as locked                                                                   |

No case clears the session or the snapshot; the snapshot's sign-out form is written only by the app in front. It runs a list of `BackgroundStep`s concurrently. A step is `Future<StepCounts> run(BackgroundContext)`, where the context holds the `HeadlessHermes`, the settings, the gateway transport (one socket shared by all steps), the state store and the notification service. Each step is settled on its own: an error or 20 s without an answer adds to `steps_failed`. `background-refresh-alerts` appends its steps to this list.

**Requests step:**

1. For each profile, call `session.active_list({profile})`.
2. For each session with status `waiting`, call `approval.pending({session_id: id, profile})`.
3. Each approval becomes a `PendingRequest(kind: approval, requestId)`.
4. A waiting session without any approval becomes `kind: input`, with the id `waiting:<session_key>:<last_active>`.

The chat id is `session_key`; the title comes from the session item. The requests found but not yet in `hermes.background.announced.v1` are posted with `kApprovalBody` or `kNeedsYouBody`, only when `settings.enabled` is on. The notification goes through #587's category builder, so an approval gets the same category and buttons as one raised in front; this change adds no category of its own. The result is the cross-profile pending list.

**Snapshot step:** waits for the requests step's pending list, or uses the previous list if that step failed. Then it calls `refreshSnapshot(pending:)`:

- the builder runs with `refreshRemote`;
- the full cross-profile pending list replaces every profile's entries;
- `redact` comes from the stored App Lock setting: with it on, titles and snippets are omitted (counts stay) and the Spotlight listener clears the index instead of refreshing it, as in `surface-snapshot`.

The store writes the snapshot and the registered listeners run, including the Spotlight index once `spotlight-search` registers it.

### Remembering announced requests

`hermes.background.announced.v1` in `SharedPreferencesAsync` holds the request ids already announced, keeping the newest 200. The app in front does not write it. A request the app already showed in front may be announced once more in the background. That notification replaces the chat's earlier one, so the user never sees two.

### `HeadlessHermes.refreshSnapshot()`

Added here, because `surface-snapshot` and `headless-runtime` were built in parallel. Its signature is `Future<SurfaceSnapshot> refreshSnapshot({List<PendingRequest>? pending})`, and it reads the previous snapshot from the store. The parameter is optional, so Contract 3's call shape still works.

### `hermes://requests` uses the snapshot

`ChatController`'s oldest-request lookup (from `deep-links`) first reads the stored snapshot's `pending`: the oldest `createdAt`, in any profile. It falls back to the loaded chats.

### Invariants touched

- Auth: only through `withHeadlessHermes`, which never signs out or clears storage.
- API layering: gateway RPCs go through `HermesGatewayTransport.request`; REST goes through the existing repositories.
- Telemetry:
  - counts are added to the `background.task` span in `runBackgroundRefresh`;
  - `background.refresh.schedule_failed` is logged in `BackgroundScheduler` with `error.type` and `platform`;
  - the dispatcher flushes at the end;
  - no id, title or text is recorded.
- Notifications: the same lock-screen texts as in front.

## Risks / Trade-offs

- [iOS runs the task at its discretion, often hours apart, and never after the user force-quits the app] → The spec documents it as best effort; widgets show the snapshot time.
- [About 30 s of runtime] → A 25 s budget, steps in parallel, one socket.
- [`session.active_list` may only see the dashboard process's sessions, and its answer may differ per profile] → It is asked per profile, and task 1.1 checks the real behaviour first.
- [`approval.pending` may expect the `session_key` rather than the runtime `id`] → Task 1.1 checks it first.
- [A waiting session may be a clarify, secret or sudo request] → It is announced as "Waiting for you in Hermes" without a request id. Deduplication uses `last_active`, so a new wait is announced again.
- [The periodic frequency cannot be shortened once registered] → It is set once, at 15 minutes.

## Migration Plan

Only a new preferences key. To roll back, ship a build without the task; iOS drops a task whose identifier the app no longer registers.
