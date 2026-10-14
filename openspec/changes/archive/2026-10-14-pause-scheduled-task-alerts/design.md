## Context

ScheduleWatcher joins concurrent checks with one inflight future. Availability loss clears the account-scoped baseline; temporary session suspension must keep it. Jobs, stored baseline, profile selection, and platform notification initialization can all complete later than a pause.

## Goals / Non-Goals

Introduce reusable watcher pause/resume and fence asynchronous client work. Authentication ownership and shell activity wiring remain with their owners. This change does not retain routes or drafts, pause background workers, or recall requests and writes already dispatched.

## Decisions

Use a paused flag, initially false, separate from availability. Pausing advances a check epoch and cancels the timer immediately; resuming starts a fresh check. Clear the joined inflight reference on invalidation and let a completion clear it only when it still owns that reference.

Check the epoch and activity gate after every awaited job, baseline, or profile dependency and immediately before starting a mute write, baseline write, or notification delivery. NotificationServices that support GuardedNotificationService receive a delivery predicate for their final platform call; simple synchronous fakes retain the existing show method.

Preserve the account-scoped baseline and settings during pause. Availability loss and explicit settings changes retain their existing destructive semantics. Continue using generated Hermes API calls and their existing spans. No new spans, log events, breadcrumbs, or attributes are added, and no telemetry receives user content.

Affected platforms are iOS, Android, macOS, Windows, and Linux. watchOS scheduled-job execution is unchanged. No native entitlement, manifest, or Xcode project changes are required.

## Risks / Trade-offs

An already dispatched HTTP request, preference write, or platform notification call can complete remotely. Epoch checks prevent new work after suspension but cannot undo that operation. Native presentation needs separate verification; deterministic fakes establish watcher semantics only.

## Migration Plan

Add and verify the watcher contract before shell wiring. The root integration passes the shared activity state into paused and supplies the guarded notification service. No data migration is required; rollback preserves the existing baseline format.

## Verification evidence

The watcher suite passes 41 tests, including six pause regressions against generated API clients with FakeHermesServer and controlled asynchronous dependencies. Focused analysis and formatting pass. The guarded-preparation regression observed a stale alert before capability dispatch was implemented. The shared verify-in-app isolation instructions were reviewed; no native fixture was launched, and native notification presentation, keychain, and persistent platform storage remain unverified. Shell and local-service integration verification remain with their owners.
