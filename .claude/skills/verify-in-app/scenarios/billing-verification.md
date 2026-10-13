# Billing verification

Use the parent isolated-backend procedure and a synthetic session on a known profile. Record the pinned backend revision. Never use personal billing credentials or trigger a charge.

1. Open an owned session. Confirm that listing the session and opening the billing disclosure send no `billing.step_up` RPC. Select Verify billing access explicitly and confirm one request carries the confirmed runtime and profile.
2. Emit the exact `billing.step_up.verification` event with a synthetic HTTPS URL and code. Expand the card, inspect the destination host, and use Copy code and Open verification explicitly. Confirm browser return leaves the request pending and main chat can continue independently.
3. Return `ok: true, granted: true` on the originating request. Confirm granted status and discarded details. Repeat with a refusal, server `retry_after`, and method-not-found. Confirm ordinary chat still works and no payment RPC is sent.
4. Lock while the RPC is pending, then unlock. Confirm code and URL remain absent and a second start is blocked. Deliver fresh details only after unlocking; old displayed callbacks must not open or copy them.
5. Replace profile, reclaim the session, retire authentication, and drop/reconnect the socket. Confirm details and old callbacks retire immediately. A replayed old code must stay absent; a current live parked frame can provide fresh details.
6. On a short narrow window, expand the card alongside usage, notices, and session status. Scroll details and actions while preserving the composer and transcript. Check keyboard and screen-reader disclosure labels.

Capture only synthetic evidence. Check gateway/request spans and fixed billing outcome/action telemetry for absence of codes, URLs, profile names, and runtime IDs.
