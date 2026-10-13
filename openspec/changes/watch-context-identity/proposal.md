## Why

A watch thread ID currently contains only a profile and session ID. After a server or account switch, the same ID can name another chat, and saved watch data has no owner boundary.

## What Changes

- Issue an opaque, durable watch context for each verified phone session owner and rotate it on departure or owner changes.
- Bind versioned thread IDs, requests, replies, caches, send records, status, and handoff acceptance to that context.
- Reject stale and legacy unbound requests before contacting Hermes; require a fresh watch session handshake.
- Preserve explicit historical-profile chat ownership within the same server/account context.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `watch`: Replace profile-only thread ownership with server/account context and profile ownership.

## Impact

Affected areas include `VerifiedSessionOwner`, phone watch handler/bridge, native relay, watch relay models/cache, complication routing, and handoff validation. Platforms are iOS and watchOS. No backend change or entitlement is required.

Security and privacy: watch contexts are random identifiers, never credentials, account IDs, or encoded server URLs. Watch thread caches store the opaque context only. Existing handoff server metadata remains separate and is removed on invalidation. Context rotation also invalidates old durable sends.

Observability: add a fixed `watch.context.rejected` phone event with operation and rejection-reason enum; existing request events record the error code. Add local Apple context-change logs with only change reason and result. No new span or breadcrumb is required because existing relay signals cover the boundary and no new user step is introduced.

Non-goals: backend session migrations, account switching UI, profile deletion UX, server idempotency, or new handoff protocol fields. Depends on `watch-session-privacy` for cleanup and late-result invalidation.
