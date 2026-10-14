## Why

The backend publishes message reactions and identity-free affection signals, but the app drops both. Users miss an acknowledgement the backend already provides.

## What Changes

- Retain durable transcript identity and show backend reactions on the correct message. Show identity-free reaction signals separately from message reaction badges.

## Capabilities

### New Capabilities

- `agent-reactions`: Read-only agent reactions.

### Modified Capabilities

None. The new capability extends existing chat behavior without changing the existing local-notification policy.

## Impact

App-only change affecting lib/src/chat/chat_models.dart; lib/src/chat/hermes_chat_repository.dart; lib/src/chat/gateway/hermes_gateway_transport.dart; lib/src/chat/gateway/gateway_event_mapper.dart. Contract: message.reaction, reaction; session.history transcript row_id. No backend, REST schema, generated-client, or native entitlement changes.

## Non-goals

No sending reactions, editing reactions, emoji inference, nearest-message matching, or new reaction history API.

## Security and privacy

Treat server text as untrusted content. Preserve secure token storage and existing authentication behavior. Retain event details only in the owning session's memory unless already supported by existing history. Never export payload text, codes, URLs, credentials, message IDs, profile names, or server addresses to telemetry.

## Observability

Use existing gateway receive and RPC spans with connection `hermes.*` attributes. Add `gateway.visibility_outcome` through AppEventLogger at the owning event reducer or invalidation consumer, carrying allowlisted `feature` and `outcome` enums plus a count where useful. Record `chat.visibility_action` breadcrumbs at explicit details, retry, or browser actions, with feature and action enums only. These signals explain dropped or refused work without user content. Do not add payload-bearing spans.

## Delivery boundary

One conventional `feat(chat)` PR targeting roughly 500 implementation lines or fewer. No backend changes. Fixture identity-free supported kinds before rendering them; otherwise keep this path unavailable.
