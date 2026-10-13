## Why

Model settings expose mixture-of-agents configuration, but its runtime progress and advisor text disappear. Users see an unexplained wait until aggregation finishes.

## What Changes

- Show a compact advisor progress card and expandable reference answers while preserving the final assistant answer.

## Capabilities

### New Capabilities

- `agent-moa-progress`: Advisor and aggregation progress.

### Modified Capabilities

None. The new capability extends existing chat behavior without changing the existing local-notification policy.

## Impact

App-only change affecting lib/src/chat/gateway/gateway_event_mapper.dart; lib/src/chat/chat_controller.dart; lib/src/chat/widgets. Contract: moa.reference, moa.progress, moa.phase, moa.aggregating. No backend, REST schema, generated-client, or native entitlement changes.

## Non-goals

No advisor model selection changes, inferred advisor errors, backend cancellation controls, or durable advisor archive.

## Security and privacy

Treat server text as untrusted content. Preserve secure token storage and existing authentication behavior. Retain event details only in the owning session's memory unless already supported by existing history. Never export payload text, codes, URLs, credentials, message IDs, profile names, or server addresses to telemetry.

## Observability

Use existing gateway receive and RPC spans with connection `hermes.*` attributes. Add `gateway.visibility_outcome` through AppEventLogger at the owning event reducer or invalidation consumer, carrying allowlisted `feature` and `outcome` enums plus a count where useful. Record `chat.visibility_action` breadcrumbs at explicit details, retry, or browser actions, with feature and action enums only. These signals explain dropped or refused work without user content. Do not add payload-bearing spans.

## Delivery boundary

One conventional `feat(chat)` PR targeting roughly 500 implementation lines or fewer. No dependency on model-settings changes; configuration API behavior remains unchanged.
