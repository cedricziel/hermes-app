## Why

Group conversations need durable replay, exact approvals, safe send identities, and answerable clarification before UI integration. An isolated Hermes 0.21.4 run confirmed that a hosted member can wait on `clarify` while `groups.state` reports no pending action and `groups.log` has no failure. A separate protocol PR keeps backend-owned orchestration and recovery independently testable and limits the size of the group UI change.

## What Changes

- Add typed same-server hosted-room contracts using the shared authenticated gateway.
- Discover room driver readiness and advertised methods, parse rooms/events/status, and replay monotonic log pages.
- Support idempotent create/send/rename/stop, exact once/deny approvals, explicit task retry, and disband tombstones.
- Require an advertised, task-fenced hosted clarify action and response contract before group execution. Require the server to refuse sudo and secret requests visibly without collecting their values.
- Test transport failures, ambiguous sends, replay duplication, clarification responses, and unsupported interaction outcomes.

## Capabilities

### New Capabilities

- `bot-mode-group-protocol`: Hosted-room transport and recovery behavior.

### Modified Capabilities

None.

## Impact

Depends on `bot-mode-chats`; `bot-mode-groups` provides the dependent UI. All changes are part of the same first Bot Mode release. Affects `lib/src/bot_mode/`, shared gateway tests, and isolated real-backend contract checks. No new REST route, generated client change, or dependency.

Non-goals: This PR has no group UI, client-side agent driver, peer connections, mutable membership, attachments, or unadvertised RPC methods. It does not add sudo or secret input to hosted groups.

Security and privacy impact: Calls use existing dashboard authorization; approval and clarify responses must match server pending actions and the current task generation. Do not store grants, tokens, secret values, or arbitrary transcript data in preferences. Unknown input requests are never automatically answered.

Telemetry: Existing opt-in RPC method/status tracing only, with content and identities excluded from added attributes.
