# Tasks

One code PR after this record (about 400 changed lines, `feat(notifications): split the Android notification channels`). No API routes change, so no OpenAPI regeneration. Android only; no native change, no Widgetbook use case (no UI), no design pass (nothing changes look or placement in the app).

## 1. Design record (this PR)

- [x] 1.1 Plugin API checked in `flutter_local_notifications` 23.0.2: `deleteNotificationChannel({required String channelId})`, `getNotificationChannels()` returning a nullable list, `channelAction` defaulting to `createIfNotExists` (design.md, Context).
- [ ] 1.2 Owner picks A, B or C of the migration, and whether `scheduled_tasks` stays high.

## 2. Code PR

- [ ] 2.1 Write failing tests, then implement `androidChannelFor` and the optional `channel` field of `AttentionNotification` (messages, jobs, requests, the background check's needs-you post with no category, "Couldn't send your answer", "Open Hermes to answer.", replies, "Ask not sent"). Table test over every kind that `showWhile` receives.
- [ ] 2.2 Write failing tests, then implement channel creation in `_start()` for both isolates, after the migration step, and the per-post details built from the chosen channel (id, name, description, importance); the answerable variant keeps secret visibility and the `hermes.request` tag. Test with the fake plugin that, once the flag is set, every post names one of the four ids and never `agent_activity`, and that while the step is pending every post names `agent_activity`.
- [ ] 2.3 Write failing tests, then implement the migration: untouched, muted or blocked (new channels created at the lowered importance, before any creation at `high`), absent, failed read (null list), failed delete (flag unset, retried), runs once, and two isolates starting together (the lock lets one run it; the other skips), and an isolate whose step failed that then sees the flag set by the other: its next post uses the new ids, and its start deletes an `agent_activity` that a late post recreated. Log event `notification.channels` (`outcome`, `carried_mute`) and a test that nothing but those fields is logged.
- [ ] 2.4 Add the eight strings to `app_en.arb` and `app_de.arb` under `@@x-area-notifications` and run `flutter gen-l10n`; build `AndroidChannelStrings` from `l10nForPlatformLocale()` read per run, at the shell and the background entry point; re-create the channels with the current text at each start and on a locale change. Test: a locale change re-creates the channels with the new text and the same importance.
- [ ] 2.5 Update `docs/architecture/notifications-and-background.md` (the channel list, the migration flag) and, when archived, sync the delta into `openspec/specs/notifications/spec.md`. Report any roadmap rows to the orchestrator; do not edit `docs/roadmap.md`.
- [ ] 2.6 Update any `.claude/skills` entry this makes stale (for example `verify-in-app`) or note that none is; no new skill is needed.
- [ ] 2.7 Run `dart format --output=none --set-exit-if-changed .`, `flutter analyze`, `flutter test`. Mutation check: make `androidChannelFor` return `chat_replies` for everything and watch 2.1 fail.
- [ ] 2.8 On an Android device or emulator (API 26 and 34), via `verify-in-app` or by hand: install the old build, mute `agent_activity`, update, check the four channels and their importance, that the old channel is gone, and that a reply, an approval, a task run and a message each land in their own channel. List what stays unverified in the PR's "Not verified on a device".
