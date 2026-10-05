## Why

Group conversations need durable replay, exact approvals, and safe send identities before UI integration. A separate protocol PR keeps backend-owned orchestration and recovery independently testable and limits the size of the group UI change.

## What Changes

- Add typed same-server hosted-room contracts using the shared authenticated gateway.
- Discover room driver readiness and advertised methods, parse rooms/events/status, and replay monotonic log pages.
- Support idempotent create/send/rename/stop, exact once/deny approvals, explicit task retry, and disband tombstones.
- Test transport failures, ambiguous sends, replay duplication, and unsupported interaction outcomes.

## Capabilities

### New Capabilities

- `bot-mode-group-protocol`: Hosted-room transport and recovery behavior.

### Modified Capabilities

None.

## Impact

Depends on `bot-mode-chats`; `bot-mode-groups` provides the dependent UI. All changes are part of the same first Bot Mode release. Affects `lib/src/bot_mode/`, shared gateway tests, and isolated real-backend contract checks. No new REST route, generated client change, or dependency.

Non-goals: This PR has no group UI, client-side agent driver, peer connections, mutable membership, attachments, or unadvertised RPC methods.

Security and privacy impact: Calls use existing dashboard authorization; approval coordinates must match server pending actions. Do not store grants, tokens, or arbitrary transcript data in preferences. Unknown input requests are never automatically approved.

Telemetry: Existing opt-in RPC method/status tracing only, with content and identities excluded from added attributes.
