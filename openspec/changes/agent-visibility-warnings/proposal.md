## Why

The gateway emits tool-risk findings and credit or startup notices, but the mapper drops them. Users lose information needed to understand tool results and delayed work.

## What Changes

- Show a compact risk badge beside its tool result with expandable findings. Show session notices and replace or withdraw keyed warnings.

## Capabilities

### New Capabilities

- `agent-warnings`: Agent warnings and notices.

### Modified Capabilities

None. The new capability extends existing chat behavior without changing the existing local-notification policy.

## Impact

App-only change affecting lib/src/chat/gateway/gateway_event_mapper.dart; lib/src/chat/chat_models.dart; lib/src/chat/widgets; test/gateway/gateway_contract_test.dart. Contract: tool.output_risk, notice, notification.show, notification.clear. No backend, REST schema, generated-client, or native entitlement changes.

## Non-goals

No operating-system notifications, automatic tool cancellation, secret recovery, credit purchase, or persisted warning history.

## Security and privacy

Treat server text as untrusted content. Preserve secure token storage and existing authentication behavior. Retain event details only in the owning session's memory unless already supported by existing history. Never export payload text, codes, URLs, credentials, message IDs, profile names, or server addresses to telemetry.

## Observability

Use existing gateway receive and RPC spans with connection `hermes.*` attributes. Add `gateway.visibility_outcome` through AppEventLogger at the owning event reducer or invalidation consumer, carrying allowlisted `feature` and `outcome` enums plus a count where useful. Record `chat.visibility_action` breadcrumbs at explicit details, retry, or browser actions, with feature and action enums only. These signals explain dropped or refused work without user content. Do not add payload-bearing spans.

## Delivery boundary

One conventional `feat(chat)` PR targeting roughly 500 implementation lines or fewer. Notice persistence across cold start is unavailable in the current resume schema.
