## 1. Group components in the catalog

- [x] 1.1 Start with failing widget tests for room rows, member checklist, attributed transcript rows, and activity/approval/failure controls; add plain-model Widgetbook cases for loading/empty/error, 2/6 members, long names, queued/working/blocked/failed, driver offline, and disband in both themes and phone/desktop widths before screen integration.
- [x] 1.2 Start with failing room-controller tests for visible/resumed polling, idle backoff, pagination, draft preservation, disposal, reconnect and stale results; integrate the protocol repository with lifecycle-aware state and no client agent driver.
- [ ] 1.3 Add plain-model hosted clarify card cases for single/batch questions, answered/skipped/expired states, long text, and pending submission in both themes and phone/desktop widths before screen integration.

## 2. Group UI integration

- [ ] 2.1 Start with failing create/open/rename/disband workflows; wire room rows into Bots and add desktop roster/conversation panes plus phone navigation, preserving stable room identities and tombstones.
- [ ] 2.2 Start with failing text/mention/thread reply workflows; wire a text-only composer, unambiguous fixed-member suggestions and attributed durable event projection using existing message bodies. Verify member replies use server discussion orchestration rather than `message_agent` in room sessions.
- [ ] 2.3 Start with failing Stop, exact Allow once/Deny, hosted clarify answer/skip, stale-action, and explicit-retry workflows; wire controls, pending request disabling, typed failures, and execution compatibility explanations. Reconnect must restore the same unanswered clarify card. Sudo/secret refusal must render as an attributed failure without a value-entry form.
- [x] 2.4 Retain existing opt-in method/status telemetry and existing foreground attention policy; no content events, push promise, new REST calls or client regeneration unless a demonstrated upstream REST extension is required.

## 3. Release verification

- [ ] 3.1 Update README/CLAUDE.md and stale project skills with hosted groups, fixed memberships, text-only messages and the legacy Desktop room boundary. Keep `feat(bots)` near 500 changed lines using existing message/adaptive widgets; protocol work stays in its prerequisite PR.
- [ ] 3.2 Run `dart format`, `flutter analyze`, `flutter test`, Widgetbook and group workflow screenshot checks; inspect images and complete verify-in-app for two active bots, direct handoff, hosted conversation, approvals, hosted clarify, sudo/secret refusal, stop, retry, and reconnect using an isolated Hermes home. Release executable groups only after all five dependent changes and the protocol interaction conformance gate pass.
