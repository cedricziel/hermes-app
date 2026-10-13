## Context

`WatchRequestHandler._sends` is an in-memory map. `_afterLostReply` reads the latest text-bearing row and can report an unrelated answer or a still-replying placeholder as completed success. `prompt.submit` has no client idempotency key. Its optional `user_row_id` is currently ignored by the transport.

Platforms: iOS phone relay and its Dart tests. watchOS consumes the companion recovery change. Android, macOS product UI, Windows, and Linux are unaffected. No entitlement or manifest change. Use existing application private storage with platform file protection; no new shared group.

## Goals / Non-Goals

Goal: retain enough evidence to avoid silent resubmission and recover a proven completed response.

Non-goal: promise exactly-once delivery. A crash between a dispatch marker and network submission remains uncertain.

## Decisions

Create a narrow storage adapter used by the watch relay. Persist an atomic record before any gateway call. A record contains schema version, context/revision, send ID, profile, bound thread when known, payload fingerprint, immutable createdAt as UTC Unix milliseconds, dispatch state, optional accepted row receipt, timestamps, and completed relay result. Store no original prompt on the phone journal. Treat fingerprints and results as private data. Apply file protection, exclude backup, validate decoded shape, and fail closed on corruption or unavailable storage.

Reserve the send identity before dispatch. Mark the record as dispatch-started before gateway work. A record known to have failed before dispatch can prove not_sent. A crash after the marker cannot prove delivery and therefore yields uncertain after restart. Persist bound thread updates and optional accepted-row receipts, but do not treat any received event as proof the user's prompt was accepted: session binding can precede submission. Add a narrow transport receipt event only when `prompt.submit` supplies `user_row_id`. A final result from the original owned stream can be persisted as its completed result.

Bind the immutable original target and payload. For a new-chat send, permit status requests to name its subsequently server-bound thread without treating that binding as a changed initial target. Never let a request redirect the stored profile or bound thread.

Serialize per-context journal mutations and in-process deduplication. Never persist a completed result after the captured auth/context generation has departed. Check current authentication and context before lookup; compose the privacy and identity changes' invalidation hooks with atomic purge. If protected deletion fails, persist the privacy change's invalidation tombstone before forgetting the context, so retained records cannot become readable after relaunch. Enforce 100 full records per context. Remove terminal payloads older than seven days and evict oldest terminal payloads under pressure. Keep active records. Detached uncertain records expire after seven days or explicit Forget recovery. Retain compact tombstones until the original first-dispatch window expires, bounded at 1000 per context. If active records or unexpired tombstones fill capacity, fail with retryable capacity guidance. Status lookup for absent records is uncertain and never rewrites absence into permission to submit.

Require a persisted original createdAt on first-dispatch requests and validate at the phone against a ten-minute age and sixty-second future-skew window. Include createdAt in identity binding. Never change createdAt for the same send ID. After record eviction, a compact tombstone blocks delayed normal delivery during that window; after expiry the request age blocks it. Status-only requests are not age-limited. Clock skew rejects safely and offers device-time guidance without automatic timestamp replacement. These are local protocol limits, not server idempotency.

Extend the version-2 handshake with `sendState: true`. Keep `retry: true` status-only. Add `recoveryState` responses without assistant text. Preserve approval/question waits from `actionable-request-notifications` and later inline-request changes. Coordinate the final Sending block with `watch-conversation-usability`; this change adds unique requirements and does not replace that block.

Do not use history to recover a completed answer. The REST history has row IDs but no durable watch send identity. `session.events.since` replay is epoch-bound and can truncate. Optional accepted-row evidence cannot prove assistant ownership across queued, steered, or concurrent turns. Persisted final results provide strong correlation; lost final results fall back to uncertain plus ordinary chat navigation. Stronger replay or server-side idempotency requires a separate backend contract change after its semantics and minimum version are defined.

Project invariants: tokens stay in secure storage, REST reads use the generated client, and telemetry remains opt-in and non-blocking. Record `watch.send.journal` through `AppEventLogger` inside journal read/write handling with fixed `operation` and `outcome` values only. Existing request diagnostics measure the boundary; no additional span or breadcrumb is needed. Never export send IDs, row IDs, context, revision, fingerprints, content, URLs, or exception details.

## Risks / Trade-offs

- A dispatch marker can overstate uncertainty when a crash occurs before actual submission. This prevents duplicate commands and leaves explicit resend to the user.
- Journal results increase private local storage. File protection, backup exclusion, bounded retention, and purge limit exposure.
- Journal and receipt plumbing could exceed one PR. Keep the adapter, relay integration, and narrow optional receipt event together; defer backend replay and UI to their own changes. Target fewer than 500 changed lines.

## Migration plan

Ship after context identity and privacy cleanup. Existing in-memory attempts can finish, but absent historical records remain uncertain after restart. Advertise sendState only once protected persistence is available. Rollback removes the capability advertisement; an upgraded watch must refuse unsafe recovery against an older phone. Do not automatically delete uncertain records during downgrade.
