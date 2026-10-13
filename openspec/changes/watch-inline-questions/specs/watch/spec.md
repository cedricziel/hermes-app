## ADDED Requirements

### Requirement: Structured question answering

The watch SHALL show each current question with its prompt and offered choices. Single-choice questions SHALL accept one offered value. Multi-select SHALL permit offered values and require explicit Submit. Text input SHALL appear only for an open-ended question. Blank text SHALL not submit. Answers SHALL identify the exact request and question and SHALL not become ordinary chat prompts. Unsupported or unavailable details SHALL retain the notification/iPhone fallback.

#### Scenario: Single choice

- **WHEN** the question offers Red and Blue
- **THEN** choosing Blue answers that question with Blue and submits no chat prompt

#### Scenario: Multi-select

- **WHEN** the user selects two offered values
- **THEN** nothing submits until Submit, and the answer contains exactly those values

#### Scenario: Open-ended

- **WHEN** the user enters a nonblank text answer
- **THEN** Submit answers the current question identity with the entered text

### Requirement: Question lifecycle and privacy

Question details and draft answers SHALL pass the same authentication, connection binding, secure-storage, and App Lock gates as inline approvals and SHALL remain transient. For multiple questions the watch SHALL show question progress and submit each under its own question identity, preserving already accepted answers. Request withdrawal, expiry, logout, or lock activation SHALL invalidate visible controls. Unknown answer acknowledgement SHALL trigger status checking without automatic resubmission.

#### Scenario: Multiple questions

- **WHEN** the first of three answers is accepted
- **THEN** the watch shows the next question and retains first-answer completion without repeating it

#### Scenario: Answered elsewhere

- **WHEN** the phone answers the question before the watch submits
- **THEN** the watch refreshes current state and sends no stale answer

#### Scenario: Lock changes

- **WHEN** App Lock activates during answer drafting
- **THEN** details and answer drafts clear and no answer is submitted

### Requirement: Inline questions accessibility

All added controls SHALL have meaningful VoiceOver labels and hints describing their action and state. Content and essential actions SHALL remain reachable at the maximum supported watch text size without shrinking essential labels below readability. Status SHALL not depend on color alone. Automatic updates SHALL preserve VoiceOver focus while the user reads or edits.

#### Scenario: Maximum text size

- **WHEN** the user enables the largest supported watch text size
- **THEN** content can scroll and essential actions remain reachable

#### Scenario: VoiceOver

- **WHEN** the user navigates the new controls with VoiceOver
- **THEN** each action and state has a meaningful label and focus remains stable during updates

### Requirement: Inline questions backend compatibility

Question `request_details` SHALL provide `{kind: question, requestId, batch, questions: [{qid, prompt, choices, multiSelect}]}` when the live phone request provides those fields. No new Hermes enumeration method SHALL be assumed. Shared `/api/ws` answering SHALL use `request.answer` with `{id, result: {answers: {<qid>: <value>}}, profile}` or event-origin `clarify.respond` with `{request_id, question_id, answer}` for event-origin single questions. Batch questions SHALL use `clarify.lock` with `{request_id, question_id, answer}` through the owning live request path; early locks remain editable until all questions lock. They SHALL NOT use one `request.answer` per question, since that resolves the whole server request. Multi-select values encode as a JSON string array in the answer value, while single-choice and text use strings. A `status: expired` result is gone. If live batch ownership cannot be safely recovered, the watch SHALL fall back to the phone. The pinned `openrpc/HERMES_REF` contract is the compatibility baseline; no newer release is asserted. After a successful mandatory context-identity handshake, peers missing optional inline-question capability SHALL keep notification/iPhone guidance; incompatible identity peers require an update.

#### Scenario: Compatible relay

- **WHEN** a supported phone serves this watch change
- **THEN** the documented existing backend methods are used and unsupported optional fields degrade safely


## MODIFIED Requirements

### Requirement: Requests the watch cannot answer

The system SHALL keep a send going when the agent asks for an approval or a question's answer during a turn sent from the watch. The phone SHALL post the actionable notification of the notifications spec, which watchOS mirrors, so the user can answer on the watch or the phone. When the watch's request says it can be answered this way (`waits: true`) and either an answerable notification was posted or eligible authenticated inline handling is available for this exact approval or question kind, the phone SHALL answer the send at once with success, the chat's thread id and `waiting` set to `approval` or `question`, without the command or the question in the send response. Approval and question details SHALL be available only through their separately gated transient request-details operations. If the required wait capability is absent, an authentication or App Lock gate denies answering, or neither an answerable notification nor an eligible inline handler for this request kind is available, the send SHALL end as for a request the watch cannot answer. Notifications being disabled alone SHALL NOT end a supported request with eligible inline handling. Unsupported or unavailable question details SHALL retain notification/iPhone fallback rather than fabricate an inline answer. Incompatible context-identity peers SHALL be rejected before sending. For supported approvals or questions with available inline details, the watch SHALL offer their structured answer actions. Otherwise the watch SHALL tell the user to answer in the Hermes notification or open Hermes on iPhone. The watch SHALL then show "Waiting for your approval" or "Hermes has a question" in place of "Hermes is thinking…" and send the same request again with the same send id, the chat's thread id and `retry` set, for at most 20 minutes. A phone that no longer knows a send asked with `retry` (for example because iOS ended the app meanwhile) SHALL NOT send the prompt again: it SHALL answer with a proven result for that send, otherwise an explicit pending or uncertain state without guessing the latest assistant reply; a retry naming no chat SHALL not resubmit and SHALL return an uncertain outcome. A retry of a waiting send SHALL be answered with the final reply once the turn completes, at once with the new state when it differs from the one the watch was told last (`working` once the turn goes on), and otherwise with the same waiting answer after 20 seconds. The send SHALL wait while any of the turn's requests is open: an expired or withdrawn request leaves the others, and the turn going on closes a request only when it is the only one open. When a retry fails, the watch SHALL keep the message and offer "Try again", which asks again with `retry` instead of sending the message again. While it waits the watch SHALL offer "Leave waiting view", which stops local polling and keeps the accepted message without denying, cancelling, or answering the request. The watch SHALL explain that Hermes keeps waiting and SHALL use the acceptance-state controls before permitting a replacement send. While the send waits the phone SHALL give up only after 15 minutes without an event, instead of 60 seconds. Any event that continues the turn SHALL end the waiting state.

The system SHALL end a send at once when the agent asks for something the app cannot answer (a secret value, a sudo password or a vault prompt) during a turn sent from the watch. It SHALL answer success with `failed` false and the text "Hermes asked for something the watch can't answer. Ask again on your iPhone." The text SHALL NOT include anything about what is asked for. The watch SHALL show it as Hermes's reply. The phone SHALL close the connection that raised the request, since nothing can answer it.

#### Scenario: Approval during a watch turn

- **WHEN** the agent asks for approval to run `rm -rf build` during a turn sent from the watch
- **THEN** the phone answers with `waiting` set to `approval`, the watch shows "Waiting for your approval" with notification/iPhone guidance, and command or question text is absent from the send response and available only through the gated details operation

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
