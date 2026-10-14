## Context

`CachingClient` clears disk files when a request throws `signedOut`, but `ConversationModel.load()` leaves already visible messages intact. `_sendOnce` can serve `_sends` before `_send` checks session availability. `VoiceRecorder` owns a temporary `voice.m4a`; clearing model audio alone does not remove an active recording. Existing complication updates already carry sequence numbers and clear status, but transport callbacks currently dispatch only those updates.

Platforms affected: iOS and watchOS. Android, macOS, Windows, and Linux have no new behavior. No entitlement, manifest, or Xcode project changes are expected.

## Goals / Non-Goals

Keep cleanup idempotent across repeated errors and native deliveries. Reject old asynchronous results on both sides of the relay. See `proposal.md` for excluded work.

## Decisions

Add an explicit invalidation signal to the existing native relay rather than overloading complication state. Retain the latest session-state signal in application context and use user-info delivery when available. Persist a monotonically increasing session revision on the phone across restart and publish both invalidation and usable-session re-establishment. Persist the last accepted revision on the watch. Apply each revision once, ignore older or equal deliveries, and acknowledge accepted revisions through the next relay request. Successful session re-establishment publishes a newer revision before content replies; a stale logout must never erase newly authenticated content. Process the current application context before cache-backed UI on foreground entry. Do not replace unrelated complication context fields when updating the context.

Use one watch session-state owner to broadcast cleanup to list and conversation models, cache, recorder, and status consumers. Increment its work generation before clearing data. Capture that generation before load, send, and transcription work; validate it after each suspension before any mutation or follow-up send. Screen-local reset alone would miss background recordings and cache writes.

On the phone, subscribe to confirmed auth departure and clear remembered attempts before publishing invalidation. Guard relay entry and completed results against departure. Mark active attempts invalid and prevent later notification/status publication; close their local transport where possible. This does not cancel a command accepted by Hermes.

Keep unavailable and offline distinct from signed out. Auth restoration and concurrent refresh failures must not erase caches or sign the user out. Token storage stays in secure storage, and existing generated-client layering remains unchanged.

Record `watch.session.invalidated` through `AppEventLogger` in `WatchBridge` with `reason` from a fixed enum and `result` flag. Record local Apple cleanup results in the watch session-state owner using reason, success, and item-count fields. Existing request events cover boundary timing. No new span or breadcrumb is required; no diagnostic contains user content or identifiers. Logging failures are swallowed.

## Risks / Trade-offs

An offline watch may retain saved data until delivery. Document eventual cleanup and validate delivery on a paired test watch. Disk deletion can fail; persist a cleanup tombstone before removal, refuse reads from tombstoned caches, retry removal on startup, and log a content-free failure. Keep the tombstone until deletion succeeds. Operating-system notifications are outside this change.

## Migration Plan

Ship phone and watch changes together. Older watches ignore the new invalidation payload but still receive `signed_out` on requests; proactive cleanup requires the updated watch. Rollback does not restore deleted data. The later `watch-context-identity` change reuses the session revision and adds explicit owner binding.
