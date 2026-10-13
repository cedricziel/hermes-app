## Why

The backend emits connection operation snapshots and exposes response methods, but the app drops the events. Users cannot follow requested connections or continue past unresolved targets.

## What Changes

- Render target state and deadline in a compact operation card. Restore pending operations and expose only explicitly supported browser, Skip, and Continue paths.

## Capabilities

### New Capabilities

- `agent-connector-operations`: Connector operation cards.

### Modified Capabilities

None. The new capability extends existing chat behavior without changing the existing local-notification policy.

## Impact

App-only change affecting lib/src/chat/gateway/hermes_gateway_transport.dart; lib/src/chat/gateway/gateway_event_mapper.dart; lib/src/chat/widgets; openrpc/hermes-gateway.openrpc.json. Contract: connection.request, connection.update; session.resume.pending_connection; connection.respond. No backend, REST schema, generated-client, or native entitlement changes.

## Non-goals

No credential entry, catalog installation, native desktop integration, automatic browser launch, automatic connection-success reporting, or new connector endpoints.

## Security and privacy

Treat server text as untrusted content. Preserve secure token storage and existing authentication behavior. Retain event details only in the owning session's memory unless already supported by existing history. Never export payload text, codes, URLs, credentials, message IDs, profile names, or server addresses to telemetry.

## Observability

Use existing gateway receive and RPC spans with connection `hermes.*` attributes. Add `gateway.visibility_outcome` through AppEventLogger at the owning event reducer or invalidation consumer, carrying allowlisted `feature` and `outcome` enums plus a count where useful. Record `chat.visibility_action` breadcrumbs at explicit details, retry, or browser actions, with feature and action enums only. These signals explain dropped or refused work without user content. Do not add payload-bearing spans.

## Delivery boundary

One conventional `feat(chat)` PR targeting roughly 500 implementation lines or fewer. No backend changes. Unsupported target actions remain unavailable. Keep credential/install flows out of this PR.
