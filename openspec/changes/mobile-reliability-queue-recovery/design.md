## Context

See proposal.md for motivation. Main `chat` currently requires memory-only queues and profile reload deletion. The existing optional `PromptAcknowledged(int userRowId)` remains a canonical row receipt used by watch acknowledgements; queue ownership needs a separate positive-status signal. `sendQueued` removes an entry before `_send`, and `_submitTo` clears the composer through a synchronous success path. The transport receives `prompt.submit` acceptance before streaming but does not expose a durable-entry acceptance boundary to the controller. Server status `queued` is a successfully accepted prompt, not local unsent work.

## Goals / Non-Goals

Keep original live FIFO, settle, stop, and failure semantics while giving restored entries a stronger review barrier. Do not create backend idempotency or treat history text matches as receipts.

## Decisions

Depend on `mobile-reliability-durable-queue-store`. Replace object-keyed persistence with stable account/profile/conversation keys while retaining controller-facing lists. Await durable enqueue commitment before reporting success and clearing the composer. An attachment-copy or commit failure leaves the input intact. Profile switch cancels local dispatch timers and leaves entries durable; reload always restores paused entries. New input on a restored queue remains paused. Use explicit Send next for each restored entry rather than granting a queue-wide auto-drain permission.

Before dispatch, atomically claim submission-started with a random local dispatch claim whose hash is persisted. Only the same claim can restore unsent state after proof that RPC dispatch did not start. Before dispatch, capture queue-access, chat-activity, profile-load and session-action generations; any change invalidates the pending dispatch, even if authorization later returns. If that write fails, do not open a network send. Expose a narrow transport acceptance signal after a successful `prompt.submit` response. Only the finite statuses `streaming`, `queued`, `redirected`, and `steered` remove local ownership. Missing, malformed, empty or unknown statuses remain uncertain. A canonical row ID and status acceptance remain separate proofs. Preserve existing handling of their transcript and reply events. Accepted entries with a failed local acceptance write remain uncertain at next load; this conservative state avoids duplicate submission.

A pre-submit failure proven by the send phase leaves a local record unsent. Once submit may have reached the server, keep an uncertain outcome on disconnect, timeout, or app restart. Do not use JSON-RPC request IDs as idempotency keys. The recovery view offers inspect conversation and discard. A new send of uncertain text requires explicit user entry and explains possible duplication. No hidden retry, backend cancel, or text-matching reconciliation occurs.

Build Widgetbook cases for paused recovery, missing attachment, storage error, unknown submission, unavailable conversation, and locked app before wiring the UI. Reuse existing queue remove controls and compact composer-adjacent layout. An archived or unavailable original session does not become a new chat automatically. Explicit conversation deletion removes local records; App Lock hides them.

A resolved nonempty profile is required for durable enqueue, restore and broker leases. Existing active-profile lookup supplies the default profile as an explicit identity. Servers without that route retain ordinary immediate sends, but cannot authorize durable queueing. Null-scope records remain on disk and are never migrated to the backend's current profile. Missing durable conversations retain their original remote IDs; profile changes leave their records in the original scope. Deletion captures scopes before the existing server request and clears only those scopes after confirmed deletion.

Terminal credential expiry revokes queue access and clears visible DTOs and leases without deleting encrypted records. The private prior identity remains only as a cleanup handle, never as authorization. The same verified owner can reload records behind the review barrier. A later explicit sign-out or server removal clears the remembered scope. Another verified owner cannot acquire the old scope.

The primary chat screen owns the existing authenticated SessionActivity signal and passes it to chat and dictation. Credential expiry stops protected screen actions and stale stream publication; reverified matching ownership resumes paused recovery. Fixture auth without an owner retains its established fallback. Auxiliary windows keep the existing auth-only parent closeAll/header-denial lifecycle. App Lock hides queue DTOs and invalidates leases without stopping ordinary mounted reply activity.

The main Flutter engine owns the store and OS keys. Auxiliary engines use existing trusted window channels and generation-bound leases; App Lock invalidates leases and clears visible DTOs. This design claims neither SDK sender attestation nor cross-isolate locking.

Platforms: all Flutter app platforms. watchOS relay behavior remains unchanged and gains no queue review UI. No native entitlement, manifest, or Xcode project change here. Native storage changes belong to the dependency.

Project invariants: auth errors preserve existing refresh handling; no generated client edits or new REST calls; privacy respects App Lock and system-surface exclusions. Log `chat.queue.recovery` in controller restore with fixed outcome and count. Record breadcrumbs `chat.queue.reviewed`, `chat.queue.send_requested`, and `chat.queue.removed` at user actions with counts and fixed state only. Existing send spans continue, with no extra content or identity attributes. Telemetry failures never change queue state.

## Risks / Trade-offs

- No server idempotency guarantee exists in the current send contract. Unknown outcomes require human review and can remain unresolved.
- Awaiting disk commitment adds enqueue latency. Show in-progress queueing and disable duplicate submission until the write ends.
- Changing submission signaling touches existing send behavior. Add focused transport tests with `FakeHermesServer` or the existing fake RPC fixture, plus controller tests for each crash boundary.

- Cold restart reads exact scopes of known conversations. Hashed scope directory names do not discover conversations absent from the server list; their records remain encrypted in the original scope. Reconnect can retain an already-known unavailable durable conversation without rebinding it.

## Migration Plan

Apply storage first, then this integration. Replace the full main `Queued messages` requirement when archiving this delta, preserving its existing scenarios. No old memory-only queue can be recovered after termination. On rollback, do not auto-submit versioned durable records. Verify review controls against an isolated app/backend and leave user profiles untouched.
