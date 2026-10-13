## Why

A retained Schedules page can keep polling and accept late command results after its verified session becomes inactive. Its controller needs an activity boundary before the owner can retain routes during same-account reauthentication.

## What Changes

- Add an optional activity signal to the page controller, preserving existing behavior when omitted.
- Stop the minute timer and reject new protected commands and auxiliary reads during suspension.
- Retire asynchronous results on every activity notification, including nested suspension and immediate recovery.
- Freshly read a previously opened destination on resume while retaining local filter, scope and selection. Do not replay commands or external open requests.
- Reject disposed or suspended command futures with a typed `StateError` instead of reporting success. Catch this cancellation at existing UI callers and drop retired feedback, navigation and delayed history reads.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `scheduled-tasks`: Suspend retained page work and reject obsolete results.

## Impact

Limited to `SchedulesController`, its existing UI cancellation callers, focused tests and this change. Existing generated cron/profile API contracts remain unchanged.

Non-goals: form drafts and saves, owner/UI wiring, session-owner decisions, sign-out/server-departure clearing, ScheduleWatcher, native changes and undoing already dispatched server commands. Same verified-account expiry must retain drafts when the owner is wired; explicit departure must dispose and clear retained state. These owner responsibilities remain outside this page-controller component. The local `requestOpen` slot is cleared on suspension and inactive requests are dropped; retaining external intent metadata across expiry belongs to the future owner/broker integration.

Security and privacy: prevents protected work and obsolete results during suspension. No token, storage, preference-format or telemetry-content changes.

Observability: none added. Existing loading/error state and HTTP telemetry describe page requests; suspension reasons belong to the owner. No new spans, logs or breadcrumbs are needed for this local lifecycle boundary.
