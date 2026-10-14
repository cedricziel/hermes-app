## ADDED Requirements

### Requirement: Durable phone watch send journal

For a context-valid protocol-version-2 send with a nonempty `sendId`, the phone SHALL persist a protected record before any gateway call for that send. Records SHALL be keyed by context, revision, and send identity and SHALL bind the original profile, optional thread, and payload fingerprint. Reusing an identity with a different payload, original timestamp, or target SHALL return `bad_request` without dispatch. Concurrent identical requests SHALL join one live attempt. Persistence failure SHALL prevent new dispatch.

The phone SHALL persist the exact completed reply before acknowledging completion to the watch. After restart, an existing nonterminal dispatch record SHALL NOT authorize a new submission. A missing, expired, or damaged record on a status-only retry SHALL NOT authorize submission either. Authentication and current context validation SHALL precede journal access. Logout and context departure SHALL purge records and prevent late callbacks from restoring them. Failed deletion SHALL leave a persistent invalidation tombstone that prevents retained private records from being reloaded.

#### Scenario: Phone restarts after dispatch

- **WHEN** Hermes may have accepted a send and the phone restarts before saving completion
- **THEN** repeating its identity checks status and does not submit the prompt again

#### Scenario: Completion saved before lost reply

- **WHEN** the phone saves a completed result but its reply to the watch is lost
- **THEN** a status request for that identity returns only that saved result

#### Scenario: Journal write fails

- **WHEN** the phone cannot persist the dispatch record
- **THEN** it returns a non-dispatch failure and sends nothing to the gateway

#### Scenario: Reused identity changes payload

- **WHEN** a request reuses an existing send identity with different text or a different target
- **THEN** the phone returns `bad_request` and does not submit either request again

### Requirement: Safe watch send-state protocol

The protocol-version-2 session handshake SHALL advertise `sendState: true` when durable send-state lookup is supported. A `send` request with `retry: true` SHALL be status-only and SHALL never create a new gateway submission. A normal completed response SHALL carry the exact saved text, failure flag, optional tools, and bound thread metadata for that identity. Nonterminal responses SHALL contain `recoveryState` set to `pending`, `uncertain`, or `not_sent`, without assistant reply text. `pending` SHALL mean the phone still owns a live attempt. `uncertain` SHALL mean completion or delivery cannot be established, including a recovered dispatch record or missing record. `not_sent` SHALL be returned only when the phone proves it did not dispatch. Existing approval/question `waiting` replies SHALL retain their meaning and polling timing.

The phone SHALL NOT identify a send's answer by selecting the latest assistant history row, matching prompt text, or using timestamps. A saved result from the original attempt is sufficient proof. An optional accepted prompt row receipt is not proof of its final answer. The journal SHALL retain completed payloads for at most seven days and SHALL evict the oldest terminal payloads first under storage pressure. Active attempts SHALL remain retained. Detached uncertain records SHALL expire after seven days or explicit Forget recovery. The journal SHALL bound full records to 100 per context and compact identity tombstones to 1000 per context. A context-valid `forgetSend` request carrying sendId SHALL release a detached recovery record while retaining any still-valid non-dispatch tombstone. It SHALL NOT cancel an active server turn; a still-active record SHALL be retained until detached or complete. A genuinely full journal SHALL refuse new dispatch with a retryable capacity explanation. Status queries for expired or forgotten identities SHALL remain uncertain and SHALL never dispatch.

A first-dispatch request SHALL contain its original `createdAt` timestamp as UTC Unix milliseconds. A missing or malformed createdAt SHALL be rejected before dispatch. The phone SHALL accept first dispatch only when that timestamp is no more than ten minutes old and no more than sixty seconds ahead of phone time. Repeated requests SHALL retain the same timestamp with the same identity. Evicting or forgetting a record SHALL retain a compact non-dispatch tombstone until its first-dispatch validity window expires. Capacity pressure SHALL NOT remove a still-valid tombstone. An expired normal request SHALL be rejected without dispatch. Status-only requests SHALL remain valid regardless of age. These limits SHALL be client relay protections, not backend delivery guarantees. Clock disagreement SHALL explain that the user must check device time; the client SHALL NOT refresh the original timestamp and automatically redispatch.

The existing backend contract SHALL remain `session.create`, `session.resume`, and `prompt.submit` on `/api/ws`, with final streamed completion events. `prompt.submit` accepts session and text and can return `status` and optional `user_row_id`; the optional row ID SHALL be recorded only when present. No new Hermes route or RPC, idempotency key, or numeric minimum Hermes version SHALL be assumed. The minimum supported Hermes version SHALL remain unchanged, and missing receipt fields SHALL use the uncertain fallback. Existing history access through `GET /api/sessions/{sessionId}/messages` SHALL be navigation only, never inferred completion.

#### Scenario: Forgotten identity has an older assistant message

- **WHEN** a status request names an unknown identity in a chat whose latest message is an assistant reply
- **THEN** the phone returns `uncertain` without returning that message as the send's answer

#### Scenario: Live send remains pending

- **WHEN** a status request names a live send whose result is not complete
- **THEN** the phone returns pending or its current approval/question waiting state without submitting another prompt

#### Scenario: Optional receipt absent

- **WHEN** a supported Hermes backend returns no `user_row_id`
- **THEN** the send can complete normally and unresolved recovered delivery remains uncertain

#### Scenario: Journal full

- **WHEN** 100 active or young unresolved records leave no terminal payload to evict
- **THEN** the phone refuses a new dispatch and preserves existing recovery records

#### Scenario: Delayed normal request after eviction

- **WHEN** a normal request arrives for an evicted identity within its initial validity window
- **THEN** its compact tombstone prevents dispatch
- **AND** after the window expires the original timestamp still prevents dispatch

#### Scenario: Terminal payload makes room

- **WHEN** a new dispatch would exceed full-record capacity and an old terminal payload exists
- **THEN** the phone evicts that payload, preserves any still-valid identity tombstone, and admits the new send

#### Scenario: Detached uncertainty expires

- **WHEN** an unresolved detached record reaches seven days or the user forgets its recovery
- **THEN** the phone releases its full-record slot and later status checks remain uncertain without dispatch
