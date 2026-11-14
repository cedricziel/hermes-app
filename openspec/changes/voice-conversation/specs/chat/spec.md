# Spec Delta

## ADDED Requirements

### Requirement: Voice turns

A prompt sent from a voice call SHALL go through the same send path as a typed one: it appears in the transcript, is queued behind a pending reply and is retried alike. Its `prompt.submit` SHALL carry `voice_turn: true`, and `interrupted: true` when the user cut off the previous reply by speaking. A typed prompt SHALL carry neither. An answer of `{"voice_stopped": true}` without a `status` SHALL count as consumed: no reply placeholder remains and the call ends.

#### Scenario: Spoken prompt

- **WHEN** a call sends the transcript "what's on my calendar"
- **THEN** the thread shows it as a user message and `prompt.submit` carries `voice_turn: true`

#### Scenario: Barge-in prompt

- **WHEN** the user speaks over a reply and the call sends what they said
- **THEN** `prompt.submit` carries `voice_turn: true` and `interrupted: true`

#### Scenario: Typed prompt

- **WHEN** the user types and sends a message
- **THEN** `prompt.submit` carries neither flag

#### Scenario: Server ends voice mode

- **WHEN** `prompt.submit` answers `{"voice_stopped": true}`
- **THEN** no reply placeholder remains and the call ends
