## Context

`WatchRequestHandler._bind` emits profile/session IDs. The phone intentionally uses the ID's profile when reading and resuming chats, while the main watch spec still says inactive profiles must fail. This change reconciles that stale rule with existing cross-profile behavior and adds a server/account boundary. `VerifiedSessionOwner` already compares canonical server, user, organization, and provider.

Platforms affected: iOS and watchOS. Android, macOS, Windows, and Linux have no new behavior. No native entitlement or manifest changes are expected. Add new Swift files to the existing watch target only if implementation needs them.

## Goals / Non-Goals

Preserve owner identity across routine refresh and restart. Invalidate all previous watch work on actual departure. Keep owner values on the phone and maintain existing handoff target parsing.

## Decisions

Persist a phone-side random context ID, owner mapping, and monotonically increasing revision using app-owned protected storage. Compare the mapping only after the auth controller verifies ownership. Gated owners use `VerifiedSessionOwner`; ungated owners use a separate server-only variant. An unverifiable gated identity fails closed. Increment revision and replace the context on confirmed departure or changed owner, even when the user later signs back into the same account. Do not use access tokens, refresh tokens, or a hash of a token as identity.

Version 2 thread IDs encode context, profile, and session through a shared tested codec. Use a delimiter-safe serialization, not string splitting over raw IDs. Carry context separately on requests to cover new-chat sends and transcription. Durable send records key by context plus send ID and preserve the thread's original profile. `watch-send-journal` and `watch-send-recovery` consume this contract; it must not invent an owner representation.

The watch stores current context and revision separately from content caches. On context change, invoke `watch-session-privacy` cleanup before displaying new data. Guard all completion paths against both request context and work generation. Scope complication payloads, taps, and handoff activation to the same context; retain the existing handoff payload version and fields, but accept a locally saved target only while its context remains current. Do not encode server addresses into watch IDs or duplicate them in chat-cache filenames. Existing handoff metadata is a separate intentional payload.

Handle version skew explicitly. New watch with old phone receives `bad_request` for `session` and shows update/open-phone guidance without sending content. New phone rejects old unscoped content requests with `context_changed`; old watches map that unknown error to their generic failure. No legacy request is automatically assigned current ownership. Updated watch deletes unscoped caches once. Ship paired updates together, and explain update-required failures in release notes.

Record `watch.context.rejected` in `WatchBridge` through `AppEventLogger`, with fixed operation and reason enums. Log context-change reason and result locally from the watch session owner. Existing request timing covers the boundary. No new span or breadcrumb is required. Signals contain no user content, context values, revisions, or owner identifiers, and telemetry failure cannot affect relay results. Auth refresh invariants and generated REST client boundaries remain unchanged.

## Risks / Trade-offs

Version skew blocks older watches until update. Safety requires refusing ambiguous ownership. Loss of protected context storage rotates context and invalidates retries rather than guessing an owner. Context is a namespace, not authentication: every operation still checks phone readiness. A persisted revision must not reset on logout or context rotation; retain it outside deleted content data.

## Migration Plan

Implement after `watch-session-privacy`; share context plumbing with durable send recovery. Delete legacy caches, replace IDs through a fresh list, and reject old complication navigation targets. Rollback cannot safely revive version 1 IDs or deleted cache data. No OpenAPI generation is needed.
