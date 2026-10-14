## Context

See proposal.md for the problem and specs/scheduled-task-editor/spec.md for the form contract. `JobFormController` currently drops reads only when a newer load starts and `JobFormScreen` treats every null save result as a form error. Session activity is an optional `ValueListenable<bool>` in related controllers, so callers that do not provide it must retain current behavior.

## Goals / Non-Goals

**Goals:**

- Make `JobFormController` pause protected metadata reads and saves at an activity boundary.
- Reject state updates and save results that belong to an older activity epoch.
- Keep existing form behavior when no activity signal is supplied.

**Non-Goals:**

- Change who creates or owns `SessionActivity`; AppShell wiring is a separate slice.
- Change blueprint forms, schedule list polling, or backend APIs.
- Attempt to cancel a request already sent to Hermes.

## Decisions

- Accept an optional `ValueListenable<bool>` in `JobFormController`; use an `active` getter so the form can render from the same live state. This matches adjacent activity-aware controllers and keeps isolated callers compatible. A new required auth dependency would force unrelated construction sites to change before AppShell wiring.
- Read current activity live for authorization. Treat each delivered activity notification as a new local epoch, including nested notifications whose current value has already returned to active. Invalidate target/model load generations for each notification and check both the epoch and request generation after each await and before notifying listeners. Keep the current draft and metadata values during a pause.
- Remember the models repository supplied by the screen. Queue metadata refresh in a microtask and let only the latest active epoch start it, coalescing nested resume notifications. Do not queue or replay saves.
- Throw `JobFormActivityCancelled` when save starts while inactive or its activity epoch changes before its result can be returned. `JobFormScreen` catches this outcome and keeps the route open without presenting a validation/server error. Returning a nullable result cannot distinguish cancellation from ordinary save refusal for that caller.
- Settle each save's busy state once. A listener may start a new save during cancellation notification, and the stale save must not clear that newer operation's busy state afterward.

## Risks / Trade-offs

- A save sent before suspension may still complete on the server. The controller drops its stale result, so the form stays open; callers must not infer that the backend write was rolled back.
- Metadata can briefly reflect the previous activity until the resumed read completes; keeping it avoids clearing form state during a recoverable pause.
- A caller that never supplies activity keeps legacy behavior until its owner is wired separately.

Platforms affected: iOS, Android, macOS, Windows, and Linux through shared Flutter code. No watchOS, native entitlement, manifest, or Xcode changes.

API layering remains unchanged: all reads and saves use the existing generated client repositories and routes. No spans, logs, or breadcrumbs are added because suspension and cancellation are expected local lifecycle behavior; no user content is added to telemetry.

## Migration Plan

Existing callers remain source-compatible because activity is optional. The production owner can pass its captured activity in a follow-up wiring slice. No data migration or rollback step is required.
