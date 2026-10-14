## Why

Only compacting status is shown. Goal, loop, heartbeat, takeover, and hydration events disappear, leaving users unable to explain a running or interrupted session.

## What Changes

- Show persistent control state, transient waits, hydration progress, and a clear reclaimed-session explanation. Restore control through the existing read RPC.

## Capabilities

### New Capabilities

- `agent-session-state`: Session control and recovery status.

### Modified Capabilities

None. The new capability extends existing chat behavior without changing the existing local-notification policy.

## Impact

App-only change affecting lib/src/chat/gateway/hermes_gateway_transport.dart; lib/src/chat/gateway/gateway_event_mapper.dart; lib/src/chat/chat_controller.dart. Contract: status.update, session.control.update, session.reclaimed, session.resume_progress; session.control.read; session.resume. No backend, REST schema, generated-client, or native entitlement changes.

## Non-goals

No goal creation, loop editing, heartbeat scheduling, automatic prompt retry, new control mutations, or inferred completion.

## Security and privacy

Treat server text as untrusted content. Preserve secure token storage and existing authentication behavior. Retain event details only in the owning session's memory unless already supported by existing history. Never export payload text, codes, URLs, credentials, message IDs, profile names, or server addresses to telemetry.

## Observability

Use existing gateway receive and RPC spans with connection `hermes.*` attributes. Add `gateway.visibility_outcome` through AppEventLogger at the owning event reducer or invalidation consumer, carrying allowlisted `feature` and `outcome` enums plus a count where useful. Record `chat.visibility_action` breadcrumbs at explicit details, retry, or browser actions, with feature and action enums only. These signals explain dropped or refused work without user content. Do not add payload-bearing spans.

## Delivery boundary

One conventional `feat(chat)` PR targeting roughly 500 implementation lines or fewer. Coordinate with `mobile-reliability-queue-recovery` so reclaim never automatically delivers a saved prompt. Control mutation UI is a separate future proposal.

