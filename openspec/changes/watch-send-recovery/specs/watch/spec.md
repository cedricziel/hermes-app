## ADDED Requirements

### Requirement: Persistent watch pending-send identity

The watch SHALL persist the pending send's identity, context, revision, target profile/thread when known, text, original `createdAt`, and delivery state before attempting delivery. The same identity SHALL always retain its original timestamp. A restored send SHALL retain its original identity and SHALL issue only status requests after a fresh context handshake. The watch SHALL NOT turn a delivery error, sleep/wake, restart, or missing result into an automatic resend. Persistence failure SHALL prevent submission. Signed-out or departed-context pending data SHALL be purged, and stale asynchronous results SHALL NOT restore it.

The watch SHALL use the protocol-version-2 handshake and require `sendState: true` for this recovery flow. Every request and success response SHALL include the current context and revision. Missing recovery capability, unsupported protocol, or legacy unscoped pending records SHALL NOT authorize resubmission. An unsupported phone SHALL show an update-required state without presenting an unsafe Try again action. A normal restoration delay SHALL retain the current context's pending data without permitting delivery until readiness is established. Expired first-dispatch validity or device-clock disagreement SHALL show actionable guidance and SHALL NOT refresh the original timestamp or automatically dispatch a new identity.

#### Scenario: Watch restarts before acknowledgement

- **WHEN** the watch restarts after attempting to deliver a message and has no completed result
- **THEN** it restores the same identity and offers Check result without submitting the message again

#### Scenario: Context changes while checking

- **WHEN** a status response arrives for a context or revision that is no longer current
- **THEN** the watch discards it before displaying content or updating pending state

#### Scenario: Older phone lacks recovery capability

- **WHEN** the current handshake lacks `sendState: true`
- **THEN** the watch explains that the phone app needs updating and does not replay a restored send

### Requirement: User-controlled watch uncertain-delivery recovery

A send with pending or uncertain delivery SHALL remain visible as the user's outgoing message. The watch SHALL offer Check result using its original send identity and `retry: true`. A `pending` result SHALL display that Hermes is still working without inserting an assistant bubble. An `uncertain` result SHALL explain that delivery or completion cannot be confirmed, and SHALL offer Open chat when a bound thread is known. A missing thread SHALL not prevent the uncertainty explanation or explicit resend decision. Repeated status checks SHALL remain status-only.

Only a proven completed response for the original send identity SHALL become its assistant answer. Approval/question waiting replies SHALL remain actionable through the existing waiting workflow. A `not_sent` result SHALL offer retry using a new send identity because the original identity is terminal. An uncertain send SHALL enable Send again only after the user has attempted Check result in the current context. It SHALL submit only after a confirmation that the original message may already have reached Hermes and another submission can run the request twice. Confirmation SHALL create a new send identity and a new local attempt; cancellation SHALL dispatch nothing. The original uncertain message SHALL NOT be edited in place. A separate new draft can contain edited text, but submitting it as a replacement SHALL require the same duplicate-risk confirmation and a new identity. Forget recovery SHALL remove the local pending record and request release of its detached phone recovery record when reachable. It SHALL NOT cancel server work. The phone SHALL retain any still-valid non-dispatch tombstone.

This flow SHALL rely on the journal's existing `/api/ws` send contract and status-only phone relay. It SHALL add no Hermes route, RPC, or minimum backend version beyond existing watch support. The watch SHALL never interpret a latest assistant history message or the fixed still-replying placeholder as proof of this send's completion.

#### Scenario: Check result while still working

- **WHEN** the user checks a send and the phone returns `recoveryState: pending`
- **THEN** the outgoing message remains pending and no completed assistant bubble appears

#### Scenario: Uncertain resend confirmed

- **WHEN** the user chooses Send again for an uncertain message and confirms the duplicate-risk warning
- **THEN** the watch persists a new identity and submits one new request

#### Scenario: Uncertain resend cancelled

- **WHEN** the user cancels the duplicate-risk confirmation
- **THEN** no new request is dispatched and the original message remains available for status checking

#### Scenario: Proven saved completion

- **WHEN** Check result returns the journal's completed reply for the original identity
- **THEN** the watch displays that reply once and clears the corresponding pending send

#### Scenario: History contains another answer

- **WHEN** the user opens chat history during uncertain recovery and it contains a newer assistant message
- **THEN** the history remains ordinary chat content and does not silently mark the pending send completed
