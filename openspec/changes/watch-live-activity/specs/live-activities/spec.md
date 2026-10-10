## ADDED Requirements

### Requirement: Watch Smart Stack presentation

On iOS 18 and watchOS 11 or later, the activity SHALL declare a compact `small` presentation, which watchOS shows in the Smart Stack of a paired Apple Watch. It SHALL show the Hermes icon in the state's tint, the chat's title on one line, one short state word and, in the working state, the time since the send. The state word SHALL be "Working" for working, "Waiting for you" for an approval request, a question or a request that needs the user in Hermes, "Done" for a ready reply and "Failed" for a failed one. The presentation SHALL follow "Nothing sensitive on a locked device": it SHALL NOT show reply text, reasoning, tool names or arguments, the command of an approval, the text of a question or the name of a secret. The system SHALL start an activity only for a reply sent from the phone; a turn sent from the watch SHALL get none, because the phone app handles it in the background, where iOS does not allow an activity to start.

#### Scenario: Working reply

- **WHEN** the user sends a prompt from the phone in chat A and wears a paired watch
- **THEN** the watch Smart Stack shows chat A's title, "Working" and an elapsed-time counter

#### Scenario: Approval requested

- **WHEN** the agent asks for approval to run `rm -rf build`
- **THEN** the Smart Stack card shows "Waiting for you" and does not mention the command

#### Scenario: Reply finished

- **WHEN** the reply completes
- **THEN** the card shows "Done" and no counter

#### Scenario: Turn sent from the watch

- **WHEN** the user sends a turn from the watch
- **THEN** no Live Activity is started on the phone or the watch
