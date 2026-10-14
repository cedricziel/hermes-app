## Context

See proposal.md for motivation. `_announce` saves all fresh marks before posting. `NotificationService.show` promises never to throw, and `LocalNotificationService` swallows native errors. Moving the existing void call before the mark would therefore still treat silent failure as success.

The unarchived `background-refresh/specs/background-refresh/spec.md` explicitly says to remember requests before posting. This proposal intentionally supersedes that sentence after `background-refresh` is integrated. Do not edit its existing planning artifacts here. If it is archived first, reconcile its main requirement in the retry implementation's spec sync so no contradictory remember-before-post rule remains. Other requirements and generic-wait deduplication stay unchanged.

## Goals / Non-Goals

Expose whether the local API accepted an attempt. Do not claim OS presentation, user attention, provider delivery, or exactly-once notification display.

## Decisions

Add a result-bearing notification operation with fixed results accepted, failed, denied, and unsupported. Keep `show` as a wrapper that discards the result so existing best-effort callers retain their contract. Return accepted only after the native plugin call returns successfully. Report permission refusal or unavailable support distinctly when known. Do not swallow the outcome inside the new operation. Tests must verify native plugin failures, not only throwing fake services.

Process fresh requests per chat. Post one notification for the requests actually represented, then persist that chat's accepted marks. A failed post retains its marks as unannounced. Persist marks before remembering them in the current store object. If persistence throws, leave those marks eligible for retry and continue other chats. A failure for one chat does not stop the others. Persist generic-wait and approval marks with the same equivalence rules as today. An unavailable channel remains retryable only when a later check still finds the wait pending and settings permit alerts.

Use current stable notification IDs derived from profile and chat. An interruption between post and mark causes replacement on the next check. Do not hold a retry list containing request content. Every new run rereads live requests through existing `session.active_list` and `approval.pending`. The snapshot steps remain independent.

Platforms: iOS and Android background paths, with shared notification adapter compilation on macOS, Windows, and Linux. watchOS remains unchanged. No entitlement, native project, manifest, generated API, or backend change.

Project invariants: preserve auth handling and generic locked-screen content; telemetry remains best effort. At `_announce`, add `requests.post_accepted`, `requests.post_failed`, and `requests.mark_failed` counts to the current `background.task` span. Record `background.request_alert.post_failed` with fixed reason and error type, and `background.request_alert.mark_failed` with error type only. No breadcrumbs, prompt text, commands, request IDs, profile names, or server addresses appear in these signals.

## Risks / Trade-offs

- OS acceptance does not guarantee presentation. Settings copy must say this, independently of the status proposal.
- A persistence failure after acceptance repeats a stable notification. Replacement is preferable to permanently losing attention.
- Successful plugin calls under disabled OS permissions can still mean no presentation. Do not present acceptance as a delivery receipt.

## Migration Plan

Keep existing announcement records valid. Apply after the existing background-refresh code, then supersede the pending ordering clause during spec integration. No mass replay of historical announcements. Rollback retains the records and old best-effort posting behavior.
