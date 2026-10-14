## ADDED Requirements

### Requirement: Scheduled-task alerts suspend without losing their baseline

While session activity is paused, the system SHALL stop scheduled-task polling and SHALL retain the last-run comparison baseline. It SHALL NOT start new checks, prune mutes, write a comparison baseline, or deliver a notification from work invalidated by that pause. A lookup or write already dispatched can still finish; suspension SHALL prevent its later client continuations from starting further work. Resuming authorized activity SHALL start a fresh check without waiting for invalidated lookups and SHALL announce a newly observed run once against the preserved baseline.

Before submitting a local notification after asynchronous platform initialization or category registration, the system SHALL recheck the caller's current session activity permission and SHALL drop a delivery whose permission was invalidated during preparation.

The backend contract SHALL remain `GET /api/cron/jobs?profile=all`, with job `id`, optional `profile`, `last_run_at`, and existing outcome fields parsed as before, and the existing active-profile lookup for alert titles. This change SHALL require no new backend route, response field, or minimum Hermes version beyond the existing cron routes.

#### Scenario: Job lookup completes after pause
- **WHEN** a job lookup completes after session activity pauses
- **THEN** its result changes neither the baseline nor mutes and posts no notification

#### Scenario: Fresh recovery outruns an invalidated lookup
- **WHEN** activity resumes while a lookup from before the pause remains pending
- **THEN** a fresh check starts and the old completion cannot replace the fresh check or publish its result

#### Scenario: Newly completed run after recovery
- **WHEN** an authorized resumed check sees a run newer than the preserved baseline
- **THEN** the run is announced once and subsequent checks of the same run are silent

#### Scenario: Local lookup or notification initialization completes after pause
- **WHEN** activity pauses while a baseline read, active-profile lookup, or guarded notification preparation is pending
- **THEN** completion cannot start a new state write or deliver that stale alert

#### Scenario: Paused polling and explicit checks
- **WHEN** polling time elapses or an explicit check is requested while paused or disposed
- **THEN** no new job lookup starts
