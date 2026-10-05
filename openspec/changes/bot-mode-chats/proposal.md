## Why

A named bot needs one durable conversation that the user can return to across app launches, Hermes Desktop, and agent handoffs. Ordinary new-chat behavior can lose that identity and prevent Hermes from injecting its Bot Mode messaging protocol.

## What Changes

- Open each bot's server-owned canonical Bot Chat, following compression lineage and preserving exact profile ownership.
- Create the canonical chat when missing, preserving its upstream identity while showing the bot's friendly title in the app.
- Support roster-resolved @mentions and attributed bot-to-bot replies through Hermes' `message_agent` protocol.
- Keep bot conversations distinct from ordinary sessions; New Chat creates a regular session and `/new` or `/reset` in a canonical bot conversation compacts it.
- Provide explicit archive/retirement behavior and reconnect recovery.

## Capabilities

### New Capabilities

- `bot-mode-chats`: Canonical bot conversations and agent messaging.

### Modified Capabilities

None; bot-specific behavior is additive to ordinary chat.

## Impact

Depends on `bot-mode-roster`. Affects bot roster actions, chat identity/open requests, gateway transport, composer mention UI, and thread actions. JSON-RPC and existing generated profile-scoped session REST calls provide the integration points.

Non-goals: Hosted group rooms are the dependent `bot-mode-groups` change, included in the same first release. Desktop relay, cross-server peers, voice customization, and embedded routine management are deferred; the existing Schedules destination remains available.

Security and privacy impact: The server resolves messaging targets and executes each agent with its own profile. The app must preserve attribution, avoid sending fabricated assistant messages, and retain the current approval/clarification behavior. No new credential storage.

Telemetry: Existing opt-in gateway method/status tracing only. Do not attach message bodies, mention text, bot identities, or transcripts to telemetry.
