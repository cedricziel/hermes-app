# Proposal

## Why

With `background-refresh`, the app gets periodic background runs and announces open requests. Two other things still wait until the user comes back:

- A reply that finished while the app was suspended. Hermes has no push channel, so its "reply ready" notification only appears after the user reopens the app.
- A scheduled job that ran or failed in the meantime. It is noticed only on the next visit, because the schedule check runs only in front.

Both checks already exist in front. This change runs them during the background runs too.

## What Changes

- **Finished replies:** when the app moves to the background, it remembers the chats whose reply is still running. A background run checks whether each one's session is still working. For each reply that finished, it posts the usual notification with the reply's one-line preview, or "Reply failed".
- **Scheduled tasks:** a background run makes the existing schedule check, with the same rules (`runsSince`, `alertsFor`), settings and mutes, and posts its notifications.
- The last-seen run time of each job is now kept on the device, so the app in front and the background runs never announce the same run twice.
- Both checks are added as steps to the background run and follow its budget, its failure isolation and its handling of the headless outcomes: they run only when the run got a connection, so when signed out, locked or unreachable they post nothing and keep their lists and baseline.

Non-goals:

- No change to which runs are announced or to their texts. They match the app in front, successful runs included.
- No reply text beyond the existing 120-character preview.
- No polling while in the background. The checks happen only when the system grants a run.
- No macOS, Windows or Linux.

Security and privacy impact: app preferences now hold the chats whose replies were running when the app left (profile, chat id, session key) and the schedule baseline (job key and last run time). They hold no text, token or server address. Notifications keep the lock-screen rules of the notifications spec. Telemetry records counts only.

Observability: the `background.task` span of the refresh run gets two more counts, `replies.finished` and `schedules.ran`, so it shows whether background announcements happen at all. No new log events or breadcrumbs: outcomes are already counted on the span, and background runs are not user steps.

## Capabilities

### New Capabilities

- `background-refresh-alerts`: finished-reply notifications from background runs, and the list of running replies the app keeps for them.

### Modified Capabilities

- `notifications`: "Watching for runs" now also runs during background runs, and its baseline is kept on the device.

## Impact

- Dart:
  - two new `BackgroundStep`s in `lib/src/background/`: running replies and schedules;
  - `ChatController` records the running replies on pause and clears them on resume;
  - `ScheduleWatcher` loads and saves its baseline.
- Dependencies: none new.
- Native: none.
- Backend: gateway `session.active_list`; REST `GET /api/sessions/{session_id}/messages`, `GET /api/cron/delivery-targets` and `GET /api/cron/jobs?profile=all`. The app already uses all of them.
- Depends on `background-refresh` being merged (and through it on `headless-runtime`, `surface-snapshot` and peer PR #587).
