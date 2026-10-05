## Why

Users need to find and configure persistent specialists as named bots while retaining profiles as the underlying state and configuration boundary. A shared roster should reflect Hermes Desktop's bots rather than inventing app-only agents.

## What Changes

- Add a top-level Bots destination with a searchable roster, identity, role, model, and honest loading/empty/error states.
- Read and update Hermes Bot Mode presentation metadata on the server; support adding an existing profile and creating a fresh specialist.
- Reuse existing profile model configuration and introduce a small identity editor for name/title, description, and standing instructions.
- Discover feature support through JSON-RPC and give older servers an actionable unavailable state.

## Capabilities

### New Capabilities

- `bot-mode-roster`: Named specialist roster, profile-backed identity, creation, and capability gating.

### Modified Capabilities

None.

## Impact

Depends on `disambiguate-messaging-bots`. Affects shell navigation, a new `lib/src/bot_mode/` feature, existing profile/model repositories, gateway connection reuse, Widgetbook, and tests. Uses the authenticated dashboard `/api/ws` profile methods; no new REST route or dependency is planned.

Non-goals: This PR does not deliver canonical conversations or rooms; `bot-mode-chats` and `bot-mode-groups` complete the same first release. Remote gateways/peers, generated/uploaded portraits, pets, roster sections, and full advanced capability editing are deferred.

Security and privacy impact: Agent identity and instructions are persisted on the connected server. Profiles separate state, not filesystem permissions. Creation uses fresh profiles by default; provider credentials and messaging accounts must not be copied by the app or exposed in responses, preferences, or logs.

Telemetry: Existing opt-in JSON-RPC method/status tracing only; exclude profile identifiers, descriptions, SOUL content, and credentials from added attributes.
