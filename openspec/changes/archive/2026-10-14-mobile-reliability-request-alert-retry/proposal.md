## Why

Background request checks mark requests announced before posting a notification. A failed or interrupted post can suppress the alert permanently, and the current notification service hides posting failure.

## What Changes

- Expose a local posting result that distinguishes OS acceptance, failure, and unavailable delivery support while preserving the existing best-effort `show` behavior for other callers.
- Mark a request announced only after the OS accepts its notification attempt.
- Preserve unaccepted requests for later checks. Reuse stable per-chat notification IDs when a task stops between posting and marking.
- Retain existing permissions, privacy, categories, foreground suppression, and generic-wait deduplication.

Non-goals: guaranteed notification delivery, new alert types, background timing changes, push infrastructure, and retrying answered requests.

Security and privacy impact: unchanged generic request content and App Lock rules. Persist only existing deduplication identities, never prompt or approval text. No auth behavior changes.

Observability: log `background.request_alert.post_failed` with fixed reason and error type and `background.request_alert.mark_failed` with error type only. Add accepted, posting-failed, and mark-failed counts to the existing background task span. No breadcrumbs apply to background work.

## Capabilities

### New Capabilities

- `background-request-alert-retry`: acceptance-aware request notification deduplication and bounded retries.

### Modified Capabilities

None. `background-refresh` exists as an unarchived change, not a main capability. This proposal explicitly supersedes its remember-before-post sentence when integrated after that change.

## Impact

`NotificationService`, `LocalNotificationService`, `BackgroundRefresh._announce`, and background notification tests. No new API, backend version, dependency, entitlement, or manifest change. Target one fix PR under 500 lines.
