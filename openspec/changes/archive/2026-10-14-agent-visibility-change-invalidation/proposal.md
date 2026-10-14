## Why

The app drops change signals even though it already has list-reading APIs. Changes made elsewhere can leave sessions, schedules, messaging, and pairing stale until manual refresh or polling.

## What Changes

- Route connection-level change signals to the relevant list and coalesce refreshes while protecting active profile and unsaved forms.

## Capabilities

### New Capabilities

- `agent-change-invalidation`: Gateway-driven list refresh.

### Modified Capabilities

None. The new capability extends existing chat behavior without changing the existing local-notification policy.

## Impact

App-only change affecting lib/src/chat/gateway/hermes_gateway_transport.dart; lib/src/chat/chat_controller.dart; lib/src/schedules/schedules_controller.dart; lib/src/messaging/messaging_screen.dart; lib/src/messaging/telegram_pairing_screen.dart. Contract: sessions.changed, cron.changed, platforms.changed, pairing.changed; existing session and REST list methods. No backend, REST schema, generated-client, or native entitlement changes.

## Non-goals

No new socket solely for invalidation, continuous background execution, guaranteed signal delivery, projects or skin support, or replacing polling recovery.

## Security and privacy

Treat server text as untrusted content. Preserve secure token storage and existing authentication behavior. Retain event details only in the owning session's memory unless already supported by existing history. Never export payload text, codes, URLs, credentials, message IDs, profile names, or server addresses to telemetry.

## Observability

Use existing gateway receive and RPC spans with connection `hermes.*` attributes. Add `gateway.visibility_outcome` through AppEventLogger at the owning event reducer or invalidation consumer, carrying allowlisted `feature` and `outcome` enums plus a count where useful. No new breadcrumb is needed because automatic invalidation adds no user action. These signals explain dropped or refused work without user content. Do not add payload-bearing spans.

## Delivery boundary

One conventional `feat(chat)` PR targeting roughly 500 implementation lines or fewer. Coordinates with `backend-contract-advisory-alignment`, but requires no new backend behavior.
