## ADDED Requirements

### Requirement: Turns that end without the activity hearing a completion

The activity SHALL NOT stay in the working or a waiting state once its turn can no longer end it. The system SHALL end an activity that has not finished, at once, when:

- the user's stop found nothing left on the server to stop;
- the turn it follows can no longer be followed because the chat's profile went out of view and no reply sent from this app is still feeding it;
- the chat is closed while the reply runs.

It SHALL show "Reply failed" when a prompt that the server folded into the running turn loses its connection before that turn is followed to its end. A finished activity SHALL be left to end after its usual 15 minutes in all these cases. A reply sent from this app SHALL keep its activity when the chat's profile goes out of view, since the send still finishes it.

#### Scenario: Stop with nothing left to stop

- **WHEN** the user stops a reply whose turn the server already ended, and the app missed its completion
- **THEN** the activity disappears

#### Scenario: Folded prompt loses its connection

- **WHEN** the connection of a folded prompt breaks
- **THEN** the activity shows "Reply failed"

#### Scenario: Profile changes while a turn is followed

- **WHEN** the user switches profile while the activity follows a turn the app did not send
- **THEN** the activity disappears

#### Scenario: Profile changes while a reply sent here runs

- **WHEN** the user switches profile while a reply sent from this app runs, and the reply completes
- **THEN** the activity shows "Reply ready"

#### Scenario: Chat closed mid-reply

- **WHEN** the chat is closed while its reply runs
- **THEN** the activity disappears

### Requirement: The turn ahead of a prompt does not end the prompt's activity

When Hermes runs a turn of its own before the prompt's turn (after a resume that continues a goal), the end of that turn, completed or failed, SHALL NOT change the prompt's activity to "Reply ready" or "Reply failed". A request raised inside that turn SHALL still show the activity as waiting. A follow-up turn that no prompt of this app submitted SHALL NOT change an activity that already finished, which stays as it is until the next send.

#### Scenario: Resumed turn completes

- **WHEN** the turn Hermes ran ahead of the prompt completes while the prompt's reply waits
- **THEN** the activity still shows "Working", and "Reply ready" once the prompt's own reply completes

#### Scenario: Resumed turn fails

- **WHEN** the turn Hermes ran ahead of the prompt completes with a failure
- **THEN** the activity still shows "Working"

#### Scenario: Resumed turn asks

- **WHEN** the turn Hermes ran ahead of the prompt asks for approval
- **THEN** the activity shows "Waiting for your approval"

#### Scenario: Follow-up after the reply

- **WHEN** Hermes chains another turn onto a chat whose activity shows "Reply ready"
- **THEN** the activity keeps showing "Reply ready"
