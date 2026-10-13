## Why

The gateway can send a device verification URL and code, but the app drops the event. A user-initiated billing scope request can become an unexplained wait.

## What Changes

- Provide an explicit user-initiated Verify billing access action backed by billing.step_up. Show the supplied verification code and browser link, then report the RPC result.

## Capabilities

### New Capabilities

- `agent-billing-verification`: Billing browser verification.

### Modified Capabilities

None. The new capability extends existing chat behavior without changing the existing local-notification policy.

## Impact

App-only change affecting lib/src/chat/gateway/gateway_rpc_client.dart; lib/src/chat/gateway/hermes_gateway_transport.dart; lib/src/chat/widgets. Contract: billing.step_up.verification; billing.step_up. No backend, REST schema, generated-client, or native entitlement changes.

## Non-goals

No billing charges, automatic top-up, payment details, automatic step-up, credential collection, persistent code storage, or portal callback endpoint.

## Security and privacy

Treat server text as untrusted content. Preserve secure token storage and existing authentication behavior. Retain event details only in the owning session's memory unless already supported by existing history. Never export payload text, codes, URLs, credentials, message IDs, profile names, or server addresses to telemetry.

## Observability

Use existing gateway receive and RPC spans with connection `hermes.*` attributes. Add `gateway.visibility_outcome` through AppEventLogger at the owning event reducer or invalidation consumer, carrying allowlisted `feature` and `outcome` enums plus a count where useful. Record `chat.visibility_action` breadcrumbs at explicit details, retry, or browser actions, with feature and action enums only. These signals explain dropped or refused work without user content. Do not add payload-bearing spans.

## Delivery boundary

One conventional `feat(chat)` PR targeting roughly 500 implementation lines or fewer. No backend extension. The schema does not expose discoverable method capabilities; method-not-found fallback provides runtime availability. The action grants billing scope only and never initiates a charge.
