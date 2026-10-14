## Context

AuthController exposes verifiedOwner, expiredOwner, ownerGeneration and protectedRequestsAllowed. Expiry closes authorization before asynchronous token cleanup. sessionExpired remains historical after recovery, so it cannot identify a fresh closure alone.

## Decisions

Increment an expiry generation synchronously when a live session expires. Capture the active verified owner, departure generation and expiry generation. A fresh expiry for that owner pauses a stable ValueListenable<bool>. Recovery requires ready state, protected authorization, unchanged departure generation and identical verified ownership. Explicit departure, unverified ownership or different ownership retires the coordinator permanently. Retired coordinators cannot resume. A same-server connection check that retains protected authorization may temporarily pause ready-only activity without retiring its owner; it does not permit retaining state after protected authorization closes.

The coordinator owns only authorization state. It does not clear local drafts, create requests, replay interrupted navigation or renew transports. Consumers retain their established lifecycle responsibilities.

## Verification

Exercise immediate gate closure before token cleanup, same-owner recovery, different-owner recovery, explicit departure, repeated sign-in attempts and historical expiry followed by non-expiry closure. Verify disposal removes listeners. Existing authentication refresh tests must remain green.
