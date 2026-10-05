## Why

Group conversations need durable replay, exact approvals, and safe send identities before UI integration. An isolated Hermes 0.21.4 run confirmed that a hosted member can wait on `clarify` while `groups.state` reports no pending action and `groups.log` has no failure. The first release can use the available hosted protocol when the app explains this limitation and provides Stop for waiting work.

## What Changes

- Add typed same-server hosted-room contracts using the shared authenticated gateway.
- Discover room driver readiness and advertised methods, parse rooms/events/status, and replay monotonic log pages.
- Support idempotent create/send/rename/stop, exact once/deny approvals, explicit task retry, and disband tombstones.
- Permit group execution on a ready protocol 2 driver with the required methods and transport features. Do not invent room responses for clarify, sudo, or secret requests; explain that such requests may leave a member waiting and offer Stop.
- Test transport failures, ambiguous sends, replay duplication, and stopping work that waits for unsupported input.

## Capabilities

### New Capabilities

- `bot-mode-group-protocol`: Hosted-room transport and recovery behavior.

### Modified Capabilities

None.

## Impact

Depends on `bot-mode-chats`; `bot-mode-groups` provides the dependent UI. All changes are part of the same first Bot Mode release and PR. Affects `lib/src/bot_mode/`, shared gateway tests, and isolated real-backend contract checks. No new REST route, generated client change, or dependency.

Non-goals: This protocol layer has no group UI, client-side agent driver, peer connections, mutable membership, attachments, or unadvertised RPC methods. It does not add sudo or secret input to hosted groups.

Security and privacy impact: Calls use existing dashboard authorization; approval responses must match server pending actions and the current task generation. Do not store grants, tokens, secret values, or arbitrary transcript data in preferences. Unknown input requests are never automatically answered.

Telemetry: Existing opt-in RPC method/status tracing only, with content and identities excluded from added attributes.
