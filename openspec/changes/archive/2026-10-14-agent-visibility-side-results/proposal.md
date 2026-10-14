## Why

The app shows delegated subagent lifecycle, but drops /background and /btw completion events. Their completed answers can be absent from the conversation.

## What Changes

- Render side results as separate compact cards in their owning chat, with expandable answer text and the optional reported question.

## Capabilities

### New Capabilities

- `agent-side-results`: Side agent answers.

### Modified Capabilities

None. The new capability extends existing chat behavior without changing the existing local-notification policy.

## Impact

App-only change affecting lib/src/chat/gateway/hermes_gateway_transport.dart; lib/src/chat/gateway/gateway_event_mapper.dart; lib/src/chat/chat_controller.dart; test/chat_background_subagent_test.dart. Contract: background.complete, btw.complete. No backend, REST schema, generated-client, or native entitlement changes.

## Non-goals

No new side-agent launch UI, operating-system delivery, inferred progress, or guaranteed cold-start history.

## Security and privacy

Treat server text as untrusted content. Preserve secure token storage and existing authentication behavior. Retain event details only in the owning session's memory unless already supported by existing history. Never export payload text, codes, URLs, credentials, message IDs, profile names, or server addresses to telemetry.

## Observability

Use existing gateway receive and RPC spans with connection `hermes.*` attributes. Add `gateway.visibility_outcome` through AppEventLogger at the owning event reducer or invalidation consumer, carrying allowlisted `feature` and `outcome` enums plus a count where useful. Record `chat.visibility_action` breadcrumbs at explicit details, retry, or browser actions, with feature and action enums only. These signals explain dropped or refused work without user content. Do not add payload-bearing spans.

## Delivery boundary

One conventional `feat(chat)` PR targeting roughly 500 implementation lines or fewer. Operating-system attention remains owned by mobile proposals.
