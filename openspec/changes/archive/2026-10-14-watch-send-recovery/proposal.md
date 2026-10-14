## Why

The watch loses pending send identity on restart and cannot distinguish a safe retry from uncertain delivery. Users need to check the result before deciding whether to send a duplicate.

## What Changes

- Persist the watch pending send identity before delivery.
- Offer Check result and Open chat for uncertain delivery.
- Require explicit duplicate-risk confirmation before Send again creates a new identity.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `watch`: Add persistent watch recovery and explicit resend requirements.

## Impact

watchOS core models, protected outbox storage, native conversation UI, relay result parsing, and tests. Depends on `watch-send-journal`, `watch-send-attempt-isolation`, `watch-session-privacy`, and `watch-context-identity`. Coordinate with `watch-conversation-usability` for failed-message controls.

Non-goals: Automatic resend, backend cancellation, exactly-once claims, and inline approval actions.

Security and privacy: records contain private chat text and results. Protect local files, exclude them from backup, scope every record to the current context and revision, and purge on logout or context departure. Store no tokens or raw server addresses. Check authentication and context before any lookup or reply.

Observability: use existing request diagnostics. Add a fixed-outcome local Apple recovery log for Check result and confirmed Send again to explain recovery failures. No user content, identifiers, contexts, revisions, addresses, or credentials enter diagnostics. No extra spans or breadcrumbs are needed beyond the existing request boundary.
