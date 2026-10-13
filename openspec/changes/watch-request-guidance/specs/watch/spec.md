## ADDED Requirements

### Requirement: Actionable request waiting guidance

When a watch turn waits for an approval or question, the watch SHALL state the request kind and tell the user to answer in the Hermes notification or open Hermes on iPhone. The local leave control SHALL be labeled Leave waiting view and SHALL explain that Hermes keeps waiting. Activating it SHALL stop local waiting only, leave the accepted outgoing message visible, and SHALL NOT deny, cancel, or answer the request. Secret and sudo input SHALL remain phone-only without sensitive details.

#### Scenario: Approval waiting

- **WHEN** Hermes asks for approval during the current watch turn
- **THEN** the watch shows notification/iPhone guidance and the local leave control

#### Scenario: Leave waiting

- **WHEN** the user activates Leave waiting view
- **THEN** local polling stops without an answer or cancellation and the accepted message stays

#### Scenario: Notifications unavailable

- **WHEN** the notification cannot be used
- **THEN** the guidance still names opening Hermes on iPhone as the answer path

### Requirement: Request guidance accessibility

All added controls SHALL have meaningful VoiceOver labels and hints describing their action and state. Content and essential actions SHALL remain reachable at the maximum supported watch text size without shrinking essential labels below readability. Status SHALL not depend on color alone. Automatic updates SHALL preserve VoiceOver focus while the user reads or edits.

#### Scenario: Maximum text size

- **WHEN** the user enables the largest supported watch text size
- **THEN** content can scroll and essential actions remain reachable

#### Scenario: VoiceOver

- **WHEN** the user navigates the new controls with VoiceOver
- **THEN** each action and state has a meaningful label and focus remains stable during updates

### Requirement: Request guidance backend compatibility

This change SHALL consume existing watch `send` responses with `waiting: approval | question | working`, `threadId`, and optional handoff metadata, without new backend calls. A waiting response SHALL NOT be presented as a completed assistant answer. It relies on the existing `/api/ws` request events and request-answer path in the pinned `openrpc/HERMES_REF` contract; no newer minimum version is required.

#### Scenario: Compatible relay

- **WHEN** a supported phone serves this watch change
- **THEN** the documented existing backend methods are used and unsupported optional fields degrade safely


## MODIFIED Requirements

### Requirement: Requests the watch cannot answer

The system SHALL keep a send going when the agent asks for an approval or a question's answer during a turn sent from the watch. The phone SHALL post the actionable notification of the notifications spec, which watchOS mirrors, so the user can answer on the watch or the phone. When the watch's request says it can be answered this way (`waits: true`) and an answerable notification was posted, the phone SHALL answer the send at once with success, the chat's thread id and `waiting` set to `approval` or `question`, without the command or the question. If the required wait capability is absent, App Lock denies answering, or no answerable notification can be posted, the send SHALL end as for a request the watch cannot answer. Peers incompatible with the required context-identity handshake SHALL be rejected before sending; a compatible peer without wait capability can still receive the notification. The watch SHALL tell the user to answer in the Hermes notification or open Hermes on iPhone. The watch SHALL then show "Waiting for your approval" or "Hermes has a question" in place of "Hermes is thinking…" and send the same request again with the same send id, the chat's thread id and `retry` set, for at most 20 minutes. A phone that no longer knows a send asked with `retry` (for example because iOS ended the app meanwhile) SHALL NOT send the prompt again: it SHALL answer with a proven result for that send, otherwise an explicit pending or uncertain state without guessing the latest assistant reply; a retry naming no chat SHALL not resubmit and SHALL return an uncertain outcome. A retry of a waiting send SHALL be answered with the final reply once the turn completes, at once with the new state when it differs from the one the watch was told last (`working` once the turn goes on), and otherwise with the same waiting answer after 20 seconds. The send SHALL wait while any of the turn's requests is open: an expired or withdrawn request leaves the others, and the turn going on closes a request only when it is the only one open. When a retry fails, the watch SHALL keep the message and offer "Try again", which asks again with `retry` instead of sending the message again. While it waits the watch SHALL offer "Leave waiting view", which stops local polling and keeps the accepted message without denying, cancelling, or answering the request. The watch SHALL explain that Hermes keeps waiting and SHALL use the acceptance-state controls before permitting a replacement send. While the send waits the phone SHALL give up only after 15 minutes without an event, instead of 60 seconds. Any event that continues the turn SHALL end the waiting state.

The system SHALL end a send at once when the agent asks for something the app cannot answer (a secret value, a sudo password or a vault prompt) during a turn sent from the watch. It SHALL answer success with `failed` false and the text "Hermes asked for something the watch can't answer. Ask again on your iPhone." The text SHALL NOT include anything about what is asked for. The watch SHALL show it as Hermes's reply. The phone SHALL close the connection that raised the request, since nothing can answer it.

#### Scenario: Approval during a watch turn

- **WHEN** the agent asks for approval to run `rm -rf build` during a turn sent from the watch
- **THEN** the phone answers with `waiting` set to `approval`, the watch shows "Waiting for your approval" with notification/iPhone guidance, and no command text reaches the watch's reply

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
