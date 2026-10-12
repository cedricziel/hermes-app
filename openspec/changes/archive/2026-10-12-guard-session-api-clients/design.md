## Context

See proposal.md for motivation. Authenticated Dio interceptors read AuthController's current session, and existing asynchronous refresh/storage work is shared across callers. Draft restoration must not allow those retained clients to acquire another owner's credentials.

## Goals / Non-Goals

Provide a safe protected-HTTP foundation before preserving navigator branches. Keep existing token rotation/adoption and same-session reconnect behavior. This layer does not retain drafts, cover routes, suspend socket/dictation work, or restore auxiliary windows.

## Decisions

Use separate owner and request epochs. Owner lifetime ends on explicit sign-out/server departure or verified owner mismatch; changing between anonymous and gated access also ends the old lifetime. Request lifetime also ends on expiry, preventing pre-expiry responses/retries from crossing reauthentication. Token rotation and adoption preserve both lifetimes. Bind each client to its server and owner epoch, and bind each request when it starts.

Recheck access and bindings before credential lookup, after asynchronous refresh/adoption, after all asynchronous request middleware immediately before dispatch, before retrying a 401, and before exposing a response. Retired/suspended requests fail locally with cancellation rather than reaching the server. Header lookups already in flight must also recheck their owner/request epochs after awaits.

Represent restoration proof with normalized server plus a nonempty user ID from /api/auth/me, conservatively scoped by organization and provider. Capture expiredOwner before clearing identity. Missing identity provides no proof. Email, display name, token equality, and accountKey are not restoration proof.

Candidate-token verification uses the existing plain authentication client. Bootstrap stored-session verification retains the refresh interceptor through a temporary allowance restricted to that fresh client's identity check; revoke it after verification. Public provider discovery uses the plain authentication client. A retired client's identity-check path is not an exception.

Serialize token mutations. Validate writes before execution and after completion; an invalidated write is cleared within its own serialized operation before later writes can run. Sign-in waits for departure cleanup before beginning. Explicit departure invalidates pending connects, and abandoned sign-in exceptions cannot replace newer state. Departure and expiry enter recoverable login/setup and emit account cleanup even if secure-storage deletion fails; their error messages report that failure. Ignore credentials left by failed deletion until a fresh sign-in replaces them. Failed preference removal does not suppress in-memory server departure. Scope shared refresh work to its owner/request lifetime and clear its slot only if it still owns that slot.

All Flutter application targets are affected: iOS, Android, macOS, Windows, Linux. watchOS continues using its existing phone relay; there is no native project, manifest, or entitlement change. API layering, secure token storage, concurrent-401 handling, and telemetry privacy invariants remain intact. auth.client.retired is recorded by AuthController with a fixed reason only, never identifiers or request paths.

## Risks / Trade-offs

- Suspension could break bootstrap/sign-in → separate public/candidate verification from application requests and preserve the existing refresh suites.
- Overly broad invalidation could break token rotation or same-session reconnect → test those existing flows and use logical epochs rather than token equality.
- Cleanup could delete a new sign-in → serialize mutations and hold old/new operations with completers in regressions.
- HTTP isolation alone leaves route visibility and other transports unresolved → the following navigator boundary must use the proof/access signal and complete the confirmed draft policy before that backlog outcome is closed.

## Migration Plan

Ship this independently useful safety layer after focused tests, isolated review, and full CI/builds. Add navigator preservation and transport suspension in the next bounded change. No stored-token format or backend migration is required.
