## MODIFIED Requirements

### Requirement: Profile-scoped thread ids

The system SHALL bind each watch thread ID to an opaque phone-issued context, the Hermes profile, and session ID. The context SHALL identify the canonical server and verified account owner without exposing either value to the watch. The watch SHALL treat thread IDs as opaque and return them unchanged. Historical-profile threads SHALL remain valid within the same current context; active-profile changes SHALL affect new chats and listings, not redirect existing chats. A malformed ID SHALL return `bad_request`. A stale context SHALL return `context_changed`, and no read or send SHALL reach Hermes. IDs in the old `<percent-encoded profile>/<session id>` format SHALL be rejected rather than rebound to the current owner.

#### Scenario: Profile switched since the list was loaded

- **WHEN** the active profile changes and the watch opens a chat listed under the previous profile in the current context
- **THEN** the phone reads or continues the chat under its original profile
- **AND** a new chat uses the current active profile

#### Scenario: Same session ID in different owners

- **WHEN** two servers or accounts contain the same profile and session ID
- **THEN** their watch IDs differ
- **AND** an ID from the previous context cannot read or send in the new context

#### Scenario: Legacy unbound thread

- **WHEN** the phone receives a profile-only thread ID from an older watch
- **THEN** it rejects the request before backend access
- **AND** the updated watch refreshes its context and list rather than retrying the legacy ID

#### Scenario: Same session id in two profiles

- **WHEN** two profiles each have session `s1` under the same context
- **THEN** the watch sees different IDs and each request reads or writes its original profile

## ADDED Requirements

### Requirement: Watch context handshake and isolation

A content-free `session` relay operation SHALL return `ok`, `protocolVersion: 2`, a durable session `revision`, and an opaque `contextId` only after the phone is ready. Auth restoration SHALL return `unavailable` until ready; confirmed absence SHALL return `signed_out`. The watch SHALL obtain this context before its first content operation. Every `threads`, `messages`, `send`, and `transcribe` request and every success reply SHALL carry `contextId` and the session `revision`. A missing or mismatched context SHALL return `context_changed` before private data access, remembered-reply lookup, transcription, or gateway submission. The watch SHALL clear private state upon a new context or `context_changed`, obtain a fresh handshake, and offer fresh navigation without automatically resubmitting a draft.

The context SHALL survive normal phone restarts and token refresh for the same verified owner. Sign-out, confirmed expiry, server departure, or a verified owner change SHALL rotate the context before accepting new work. Without an authenticated account, an ungated dashboard SHALL use a separate context tied to the canonical server. Unknown owner identity on a gated server SHALL NOT authorize a context. The watch SHALL scope saved lists, messages, drafts, audio, send state, status, and navigation to the context. Late results or invalidations for a previous context SHALL NOT replace the current context or its data. Each context publication SHALL carry a durable monotonically increasing revision so native delivery order cannot roll state backward.

#### Scenario: New-chat send crosses an account switch

- **WHEN** a draft for a new chat was prepared under context A and the phone now serves context B
- **THEN** the phone returns `context_changed` without submitting the draft
- **AND** the watch clears the draft and reloads the current context

#### Scenario: Refresh and restart retain ownership

- **WHEN** the phone refreshes tokens or restarts with the same verified owner and no intervening departure
- **THEN** the context remains stable and valid retries retain their owner

#### Scenario: Delayed context update

- **WHEN** the watch has accepted revision 8 and receives revision 7
- **THEN** it ignores revision 7 without restoring previous data or clearing revision 8 data

#### Scenario: Cold offline launch

- **WHEN** the watch cannot handshake but has previously verified cached data for one context
- **THEN** it may display that context's saved data with existing offline behavior
- **AND** it cannot submit requests until a current context handshake succeeds

#### Scenario: Upgrade with existing files

- **WHEN** an updated watch starts with caches that have no context
- **THEN** it removes those caches before displaying them and requests a new handshake

### Requirement: Watch identity uses the existing Hermes contract

The context protocol SHALL add no Hermes route or RPC method and SHALL retain the existing minimum supported Hermes version. Gated account identity SHALL use the current `GET /api/auth/me` identity fields `user_id`, `org_id`, and provider as parsed by the app, together with its canonical server URL. Ungated readiness SHALL use the existing `GET /api/status` `auth_required: false` response. No watch context SHALL authorize backend work independently of current phone authentication. Diagnostics SHALL NOT contain contexts, revisions, thread IDs, owner fields, URLs, or credentials.

#### Scenario: Existing backend with protocol version 2 watch

- **WHEN** the watch completes the version 2 handshake against a phone connected to an already supported Hermes server
- **THEN** normal chat reads and sends require no backend upgrade
