## Why

Bot creation exposes configuration before users need it and leaves them in the roster after saving. A short initial form should lead directly to the new bot's chat.

## What Changes

- Show Name, Title, and Description initially, with permanent-name guidance.
- Put standing instructions, model and provider selection, and API key copying under Advanced.
- Prevent duplicate submissions, validate empty names, and retain metadata-save retries.
- Open the canonical Bot Chat after creation and metadata persistence.

Non-goals: cloning, empty profiles, avatars, capability selection, and automatic introduction turns.

## Capabilities

### New Capabilities

- `bot-creation`: Progressive bot creation and immediate canonical chat navigation.

### Modified Capabilities

None.

## Impact

Flutter creation fields, roster orchestration, Widgetbook, and widget tests. Existing profile RPC and generated model-options client contracts remain sufficient. One small feature commit.

Security and privacy: credential copying stays server-side and defaults on. Copy labels distinguish API keys from OAuth sign-ins. No token handling changes.

Observability: None added. Existing request instrumentation covers backend calls; inline validation and retry messages expose UI failures without recording user content.
