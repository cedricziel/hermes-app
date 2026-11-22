# Tasks

One code PR after this record (about 400 changed lines, `feat(notifications): split the Android notification channels`). No API routes change, so no OpenAPI regeneration. Android only; no native change, no Widgetbook use case (no UI), no design pass (nothing changes look or placement in the app).

## 1. Design record (this PR)

- [ ] 1.1 Before coding, read the pinned `flutter_local_notifications` Android source for `createNotificationChannel`, `getNotificationChannels` and `deleteNotificationChannel`: names, parameter style, return types, and what a repeated create does to name and importance. Fix this design where it is wrong.
- [ ] 1.2 Owner picks A, B or C of the migration, and whether `scheduled_tasks` stays high.

## 2. Code PR

- [ ] 2.1 Write failing tests, then implement `androidChannelFor` and the optional `channel` field of `AttentionNotification` (messages, jobs, requests, needs-you, "Couldn't send your answer", replies, "Ask not sent"). Table test over every kind that `showWhile` receives.
- [ ] 2.2 Write failing tests, then implement channel creation in `_start()` for both isolates, and the per-post details built from the chosen channel (id, name, description, importance); the answerable variant keeps secret visibility and the `hermes.request` tag. Test with the fake plugin that every post names one of the four ids and never `agent_activity`.
- [ ] 2.3 Write failing tests, then implement the migration: untouched, muted or blocked, absent, failed read, failed delete (flag unset, retried), runs once. Log event `notification.channels` (`outcome`, `carried_mute`) and a test that nothing but those fields is logged.
- [ ] 2.4 Add the eight strings to `app_en.arb` and `app_de.arb` under `@@x-area-notifications` and run `flutter gen-l10n`; build `AndroidChannelStrings` at the shell and the background entry point; update the text on a locale change. Test: a locale change re-creates the channels with the new text and the same importance, and the service imports no `AppLocalizations` (a source-scan test or architecture guard).
- [ ] 2.5 Update `docs/architecture/notifications-and-background.md` (the channel list, the migration flag) and, when archived, sync the delta into `openspec/specs/notifications/spec.md`. Report any roadmap rows to the orchestrator; do not edit `docs/roadmap.md`.
- [ ] 2.6 Run `dart format --output=none --set-exit-if-changed .`, `flutter analyze`, `flutter test`. Mutation check: make `androidChannelFor` return `chat_replies` for everything and watch 2.1 fail.
- [ ] 2.7 On an Android device or emulator (API 26 and 34), via `verify-in-app` or by hand: install the old build, mute `agent_activity`, update, check the four channels and their importance, that the old channel is gone, and that a reply, an approval, a task run and a message each land in their own channel. List what stays unverified in the PR's "Not verified on a device".
