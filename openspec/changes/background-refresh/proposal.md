# Proposal

## Why

Hermes has no push channel, so today the app learns about anything only while it is in front. An approval the agent raised after the user locked the phone waits silently until the user comes back. Widgets and Spotlight, which come next, would show whatever the app saw last. iOS (BGTaskScheduler) and Android (WorkManager) let an app run briefly in the background now and then. This change uses those moments to look for open requests and to refresh what the system surfaces show. It also provides the scheduling and the run that `background-refresh-alerts` extends with finished replies and scheduled tasks.

## What Changes

- The app asks the system for periodic background runs while someone is signed in, every 15 minutes at the earliest (iOS and Android decide when), and cancels them on sign-out.
- Each run uses the headless runtime and finishes within about 25 seconds:
  - **Open requests:** lists each profile's live sessions on the gateway and reads the pending approvals of sessions waiting for the user. It posts a notification for each request not announced before, using the same generic texts as today ("Waiting for your approval", "Waiting for you in Hermes") and the actionable categories of peer PR #587 (built with its reusable category builder, so an approval carries its buttons). Announced request ids are remembered.
  - **Snapshot and Spotlight:** rebuilds the surface snapshot with every profile's chats, all open requests, Kanban and schedules, and writes it for widgets. In-app snapshot listeners (the Spotlight index, later) run with it.
- The run is built as independent steps, so `background-refresh-alerts` can add its own.
- Nothing is posted when notifications are off. The run handles each outcome of the headless runtime explicitly: signed out (the scheduled task is cancelled), locked (nothing happens; the next run tries again), unreachable (nothing happens). It never signs the user out.
- `hermes://requests` opens the oldest open request from the stored snapshot, in any profile.

Non-goals:

- No finished-reply or scheduled-task notifications in the background; those are `background-refresh-alerts`.
- No in-app switch for background refresh. iOS Settings' Background App Refresh and the notification settings govern it.
- No guarantee of timing. iOS may run the task rarely, late, or not at all (Low Power Mode, little use of the app, Background App Refresh off). This does not replace push.
- No answering requests from the background, no badge (both belong to the notification changes, which read the pending count this change writes), no Live Activity updates.
- No clarify, secret or sudo listing. Hermes only lists pending approvals, so a session waiting for other input is announced generically.
- No macOS, Windows or Linux background runs.

Security and privacy impact: background runs use the stored session through the headless runtime. It is readable after the first unlock, never cleared and never logged. Notifications keep the existing lock-screen rules, and the approval's command is never read into a notification or the snapshot. App preferences now hold the ids of announced requests (the newest 200), with no text, token or server address. Telemetry records counts only.

Observability:

- The headless runtime's `background.task` span (`task: refresh`) gets counts as attributes: `requests.new` and `steps_failed`. It is the only way to see whether, and how often, iOS runs the task at all.
- Log event `background.refresh.schedule_failed` (`error.type`, `platform`) when the system refuses the periodic task. Without it the feature fails invisibly.
- Telemetry is flushed before the run returns to the system. Otherwise the span would be lost with the suspended process.
- No breadcrumbs: background runs are not user steps.

## Capabilities

### New Capabilities

- `background-refresh`: periodic background runs. Covers scheduling, open-request notifications and their deduplication, the snapshot refresh, the time budget and the platform limits.

### Modified Capabilities

None.

## Impact

- Dart: `lib/src/background/background_refresh.dart` (the run, as a list of steps), `background_scheduler.dart` (register and cancel), an entry point in `entry_points.dart`, and `HeadlessHermes.refreshSnapshot()`. `ChatController`'s oldest-request lookup reads the snapshot first.
- Dependency: `workmanager` from pub.dev.
- iOS: `BGTaskSchedulerPermittedIdentifiers` and `UIBackgroundModes: fetch` in `ios/Runner/Info.plist`. `AppDelegate` registers the task and the background plugin registrant (`BackgroundPlugins`, plus `home_widget` and `workmanager_apple`). Android: WorkManager needs no manifest change.
- Backend: gateway `session.active_list` and `approval.pending`, plus the snapshot's REST routes. The app already uses all of them.
- Depends on `headless-runtime` and `surface-snapshot` being merged, and on peer PR #587 for the request notification categories.
