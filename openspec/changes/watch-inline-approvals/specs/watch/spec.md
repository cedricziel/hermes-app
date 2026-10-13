## ADDED Requirements

### Requirement: Structured approval display

For an open approval in the current watch chat, the watch SHALL obtain current command, optional description, and offered choice values from the phone and show only those choices. The phone SHALL require a restored signed-in session, current connection/profile binding, device secure-storage availability, and App Lock disabled before releasing details or answering. A denied gate SHALL show an iPhone/unlock fallback without command details. Lock activation, logout, or connection change while details are visible SHALL immediately clear those details and invalidate controls; a late detail reply SHALL not restore them. Request-details and request-answer operations SHALL carry the mandatory context revision and binding from watch-context-identity; stale or incompatible context SHALL be rejected before reading or writing. Unknown, malformed, or oversized details SHALL offer the phone fallback and no approval actions.

#### Scenario: Offered choices

- **WHEN** the approval offers once and deny only
- **THEN** the watch displays the full command and only Once and Deny

#### Scenario: App locked

- **WHEN** App Lock is enabled before the details request
- **THEN** no command reaches the watch and the user is directed to Hermes on iPhone

#### Scenario: Oversized command

- **WHEN** the complete request cannot fit the safe relay payload
- **THEN** the watch offers iPhone handling without an approval action

### Requirement: Answer approval by identity

The watch SHALL require confirmation before sending once, session, or always with the full command and selected scope visible. Cancelling SHALL send nothing. Deny SHALL submit only the deny choice. Before submitting, the phone SHALL recheck security gates, request liveness, and offered choices. Duplicate activation SHALL issue at most one pending answer attempt. Expired or already answered requests SHALL refresh to their current state. Uncertain acknowledgement SHALL recheck request state without automatically approving again. Successful answering SHALL resume the existing turn rather than submit chat text.

#### Scenario: Confirm once

- **WHEN** the user confirms Once for a current approval
- **THEN** once is answered for that request and the existing turn resumes

#### Scenario: Changed or expired request

- **WHEN** the request is withdrawn or its choices change before confirmation
- **THEN** no stale answer is submitted and the view refreshes

#### Scenario: Lost answer acknowledgement

- **WHEN** the answer may have succeeded but the relay reply is lost
- **THEN** the watch checks the request state and does not automatically repeat approval

### Requirement: Inline approvals accessibility

All added controls SHALL have meaningful VoiceOver labels and hints describing their action and state. Content and essential actions SHALL remain reachable at the maximum supported watch text size without shrinking essential labels below readability. Status SHALL not depend on color alone. Automatic updates SHALL preserve VoiceOver focus while the user reads or edits.

#### Scenario: Maximum text size

- **WHEN** the user enables the largest supported watch text size
- **THEN** content can scroll and essential actions remain reachable

#### Scenario: VoiceOver

- **WHEN** the user navigates the new controls with VoiceOver
- **THEN** each action and state has a meaningful label and focus remains stable during updates

### Requirement: Inline approvals backend compatibility

The relay SHALL introduce `request_details` and `request_answer`, scoped by opaque thread and request identifiers and connection binding. Details SHALL return `{ok: true, kind: approval, requestId, command, description?, choices}` or a gated/gone/unavailable result. Answer SHALL carry `{choice}` and return an explicit accepted/gone/failed/unknown outcome. Hermes SHALL remain `/api/ws`: `session.active_list` resolves the live chat, `approval.pending` returns `{approvals: [{request_id, command, description, choices}]}`, and shared answering uses `request.answer` with `{id, result: {choice}, profile}` returning `status: ok`, or event-origin `approval.respond` with `{session_id, profile, request_id, choice}` returning `resolved > 0`. These methods are in the pinned `openrpc/HERMES_REF` contract; no unverified newer minimum release is assumed. After the mandatory context-identity protocol handshake succeeds, peers without inline-request capability SHALL omit inline actions and retain notification/iPhone guidance. Incompatible identity protocol peers SHALL follow watch-context-identity update-required behavior.

#### Scenario: Compatible relay

- **WHEN** a supported phone serves this watch change
- **THEN** the documented existing backend methods are used and unsupported optional fields degrade safely


## MODIFIED Requirements

### Requirement: Requests the watch cannot answer

The system SHALL keep a send going when the agent asks for an approval or a question's answer during a turn sent from the watch. The phone SHALL post the actionable notification of the notifications spec, which watchOS mirrors, so the user can answer on the watch or the phone. When the watch's request says it can be answered this way (`waits: true`) and either an answerable notification was posted or this request is an approval with eligible authenticated inline approval handling, the phone SHALL answer the send at once with success, the chat's thread id and `waiting` set to `approval` or `question`, without the command or the question in the send response. Approval details SHALL be available only through the separately gated transient request-details operation defined by Structured approval display. If the required wait capability is absent, an authentication or App Lock gate denies answering, or neither an answerable notification nor an eligible inline handler for this request kind is available, the send SHALL end as for a request the watch cannot answer. Notifications being disabled alone SHALL NOT end an approval supported by eligible inline handling. Questions without an answerable notification SHALL remain phone-only in this stage. Incompatible context-identity peers SHALL be rejected before sending. For approvals with available inline details, the watch SHALL offer the structured approval actions. Otherwise the watch SHALL tell the user to answer in the Hermes notification or open Hermes on iPhone. The watch SHALL then show "Waiting for your approval" or "Hermes has a question" in place of "Hermes is thinking…" and send the same request again with the same send id, the chat's thread id and `retry` set, for at most 20 minutes. A phone that no longer knows a send asked with `retry` (for example because iOS ended the app meanwhile) SHALL NOT send the prompt again: it SHALL answer with a proven result for that send, otherwise an explicit pending or uncertain state without guessing the latest assistant reply; a retry naming no chat SHALL not resubmit and SHALL return an uncertain outcome. A retry of a waiting send SHALL be answered with the final reply once the turn completes, at once with the new state when it differs from the one the watch was told last (`working` once the turn goes on), and otherwise with the same waiting answer after 20 seconds. The send SHALL wait while any of the turn's requests is open: an expired or withdrawn request leaves the others, and the turn going on closes a request only when it is the only one open. When a retry fails, the watch SHALL keep the message and offer "Try again", which asks again with `retry` instead of sending the message again. While it waits the watch SHALL offer "Leave waiting view", which stops local polling and keeps the accepted message without denying, cancelling, or answering the request. The watch SHALL explain that Hermes keeps waiting and SHALL use the acceptance-state controls before permitting a replacement send. While the send waits the phone SHALL give up only after 15 minutes without an event, instead of 60 seconds. Any event that continues the turn SHALL end the waiting state.

The system SHALL end a send at once when the agent asks for something the app cannot answer (a secret value, a sudo password or a vault prompt) during a turn sent from the watch. It SHALL answer success with `failed` false and the text "Hermes asked for something the watch can't answer. Ask again on your iPhone." The text SHALL NOT include anything about what is asked for. The watch SHALL show it as Hermes's reply. The phone SHALL close the connection that raised the request, since nothing can answer it.

#### Scenario: Approval during a watch turn

- **WHEN** the agent asks for approval to run `rm -rf build` during a turn sent from the watch
- **THEN** the phone answers with `waiting` set to `approval`, the watch shows "Waiting for your approval" with notification/iPhone guidance, and command text is absent from the send response and available only through the gated details operation

#### Scenario: Approved from the notification

- **WHEN** the user picks "Allow once" on the mirrored notification and the turn completes with "Done."
- **THEN** the watch's next retry of the send gets "Done." as the reply

#### Scenario: Still waiting

- **WHEN** a waiting send is retried and nothing happens for 20 seconds
- **THEN** the phone answers with the same waiting state and the watch keeps waiting

#### Scenario: Phone app ended while waiting

- **WHEN** iOS ends the phone app while a watch send waits, and the watch asks again with `retry`
- **THEN** the phone checks the persisted original send result and returns proven completion or explicit pending/uncertain state without sending the prompt again

#### Scenario: Stop waiting

- **WHEN** the user picks "Leave waiting view" while the watch shows "Waiting for your approval"
- **THEN** the message stays, local polling stops, and no request is denied or cancelled; recovery controls gate another send according to acceptance state

#### Scenario: Older watch

- **WHEN** a watch that does not send `waits` sends a message and the agent asks for approval
- **THEN** the send ends with the fixed text, as before

#### Scenario: Question during a watch turn

- **WHEN** the agent asks a clarifying question during a turn sent from the watch
- **THEN** the watch shows "Hermes has a question"

#### Scenario: Sudo password during a watch turn

- **WHEN** the agent asks for a sudo password during a turn sent from the watch
- **THEN** the send ends at once with the fixed text and the connection is closed
