## MODIFIED Requirements

### Requirement: Requests the watch cannot answer

The system SHALL keep a send going when the agent asks for an approval or a question's answer during a turn sent from the watch. The phone SHALL post the actionable notification of the notifications spec, which watchOS mirrors, so the user can answer on the watch or the phone. When the watch's request says it can be answered this way (`waits: true`) and an answerable notification was posted, the phone SHALL answer the send at once with success, the chat's thread id and `waiting` set to `approval` or `question`, without the command or the question. Otherwise (an older watch, notifications off or denied, App Lock on) the send SHALL end as for a request the watch cannot answer. The watch SHALL then show "Waiting for your approval" or "Hermes has a question" in place of "Hermes is thinking…" and send the same request again with the same send id, the chat's thread id and `retry` set, for at most 20 minutes. A phone that no longer knows a send asked with `retry` (for example because iOS ended the app meanwhile) SHALL NOT send the prompt again: it SHALL answer with the chat's latest reply, or "Hermes is still replying. Open the chat again in a moment." when it has none, and `failed` when the retry names no chat. A retry of a waiting send SHALL be answered with the final reply once the turn completes, at once with the new state when it differs from the one the watch was told last (`working` once the turn goes on), and otherwise with the same waiting answer after 20 seconds. The send SHALL wait while any of the turn's requests is open: an expired or withdrawn request leaves the others, and the turn going on is taken as the oldest open request answered. When a retry fails, the watch SHALL keep the message and offer "Try again", which asks again with `retry` instead of sending the message again. While it waits the watch SHALL offer "Stop waiting", which ends the wait on the watch, keeps the message and lets the user send again. While the send waits the phone SHALL give up only after 15 minutes without an event, instead of 60 seconds. Any event that continues the turn SHALL end the waiting state.

The system SHALL end a send at once when the agent asks for something the app cannot answer (a secret value, a sudo password or a vault prompt) during a turn sent from the watch. It SHALL answer success with `failed` false and the text "Hermes asked for something the watch can't answer. Ask again on your iPhone." The text SHALL NOT include anything about what is asked for. The watch SHALL show it as Hermes's reply. The phone SHALL close the connection that raised the request, since nothing can answer it.

#### Scenario: Approval during a watch turn

- **WHEN** the agent asks for approval to run `rm -rf build` during a turn sent from the watch
- **THEN** the phone answers with `waiting` set to `approval`, the watch shows "Waiting for your approval", and no command text reaches the watch's reply

#### Scenario: Approved from the notification

- **WHEN** the user picks "Allow once" on the mirrored notification and the turn completes with "Done."
- **THEN** the watch's next retry of the send gets "Done." as the reply

#### Scenario: Still waiting

- **WHEN** a waiting send is retried and nothing happens for 20 seconds
- **THEN** the phone answers with the same waiting state and the watch keeps waiting

#### Scenario: Phone app ended while waiting

- **WHEN** iOS ends the phone app while a watch send waits, and the watch asks again with `retry`
- **THEN** the phone reads the chat instead of sending the prompt again

#### Scenario: Stop waiting

- **WHEN** the user picks "Stop waiting" while the watch shows "Waiting for your approval"
- **THEN** the message stays, the watch asks the phone no more, and the user can send another message

#### Scenario: Older watch

- **WHEN** a watch that does not send `waits` sends a message and the agent asks for approval
- **THEN** the send ends with the fixed text, as before

#### Scenario: Question during a watch turn

- **WHEN** the agent asks a clarifying question during a turn sent from the watch
- **THEN** the watch shows "Hermes has a question"

#### Scenario: Sudo password during a watch turn

- **WHEN** the agent asks for a sudo password during a turn sent from the watch
- **THEN** the send ends at once with the fixed text and the connection is closed
