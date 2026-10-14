## Why

The todo tool card shows individual results, but authoritative todo.updated and session.resume.todo_state are discarded. Users cannot reliably see the current plan after reconnection.

## What Changes

- Show a compact read-only plan summary with expandable tasks. Replace plans by authoritative revisions and restore available resume snapshots.

## Capabilities

### New Capabilities

- `agent-todo-state`: Agent todo snapshots.

### Modified Capabilities

None. The new capability extends existing chat behavior without changing the existing local-notification policy.

## Impact

App-only change affecting lib/src/chat/gateway/gateway_event_mapper.dart; lib/src/chat/gateway/hermes_gateway_transport.dart; lib/src/chat/chat_controller.dart; lib/src/chat/widgets. Contract: todo.updated; session.resume.todo_state. No backend, REST schema, generated-client, or native entitlement changes.

## Non-goals

No task editing, Kanban synchronization, inferred todo item schema, or new history endpoint.

## Security and privacy

Treat server text as untrusted content. Preserve secure token storage and existing authentication behavior. Retain event details only in the owning session's memory unless already supported by existing history. Never export payload text, codes, URLs, credentials, message IDs, profile names, or server addresses to telemetry.

## Observability

Use existing gateway receive and RPC spans with connection `hermes.*` attributes. Add `gateway.visibility_outcome` through AppEventLogger at the owning event reducer or invalidation consumer, carrying allowlisted `feature` and `outcome` enums plus a count where useful. Record `chat.visibility_action` breadcrumbs at explicit details, retry, or browser actions, with feature and action enums only. These signals explain dropped or refused work without user content. Do not add payload-bearing spans.

## Delivery boundary

One conventional `feat(chat)` PR targeting roughly 500 implementation lines or fewer. No backend changes. Cold-start restoration is limited to the existing todo_state snapshot.
