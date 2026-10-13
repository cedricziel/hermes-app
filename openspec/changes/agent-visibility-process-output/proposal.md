## Why

Agent-owned process output and closure are dropped. Long processes can appear silent, and users cannot inspect the output already delivered to the app.

## What Changes

- Show compact process activity with an expandable bounded text tail. Close the matching process without inventing an exit result.

## Capabilities

### New Capabilities

- `agent-process-output`: Background process output.

### Modified Capabilities

None. The new capability extends existing chat behavior without changing the existing local-notification policy.

## Impact

App-only change affecting lib/src/chat/gateway/gateway_event_mapper.dart; lib/src/chat/chat_models.dart; lib/src/chat/widgets; lib/src/chat/gateway/gateway_replay.dart. Contract: agent.terminal.output, terminal.close. No backend, REST schema, generated-client, or native entitlement changes.

## Non-goals

No interactive terminal, shell input, process killing, file download, exit-code inference, or complete output archive.

## Security and privacy

Treat server text as untrusted content. Preserve secure token storage and existing authentication behavior. Retain event details only in the owning session's memory unless already supported by existing history. Never export payload text, codes, URLs, credentials, message IDs, profile names, or server addresses to telemetry.

## Observability

Use existing gateway receive and RPC spans with connection `hermes.*` attributes. Add `gateway.visibility_outcome` through AppEventLogger at the owning event reducer or invalidation consumer, carrying allowlisted `feature` and `outcome` enums plus a count where useful. Record `chat.visibility_action` breadcrumbs at explicit details, retry, or browser actions, with feature and action enums only. These signals explain dropped or refused work without user content. Do not add payload-bearing spans.

## Delivery boundary

One conventional `feat(chat)` PR targeting roughly 500 implementation lines or fewer. Full output recovery is unavailable in the existing event payloads; no backend extension is planned.
