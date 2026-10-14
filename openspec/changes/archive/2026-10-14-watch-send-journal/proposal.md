## Why

The phone remembers send identities only in memory. A restart after dispatch but before acknowledgement can turn a repeated request into a duplicate command.

## What Changes

- Persist a protected dispatch journal before touching the gateway.
- Recover completed results by the exact send identity.
- Return pending or uncertain delivery without replaying a prompt.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `watch`: Add durable phone send-state lookup requirements.

## Impact

iOS Dart watch relay, protected storage, transport receipt metadata, and tests. Depends on `watch-session-privacy` and `watch-context-identity`.

Non-goals: Watch draft UI, server-side idempotency, automatic resend, and history-based answer guessing.

Security and privacy: records contain private payload fingerprints and completed reply text. Protect local files, exclude them from backup, scope every record to the current context and revision, and purge on logout or context departure. Store no tokens or raw server addresses. Check authentication and context before any lookup or reply.

Observability: use existing request diagnostics. Add a fixed-outcome `watch.send.journal` event in the phone relay for journal read/write outcomes to explain recovery failures. No user content, identifiers, contexts, revisions, addresses, or credentials enter diagnostics. No extra spans or breadcrumbs are needed beyond the existing request boundary.
