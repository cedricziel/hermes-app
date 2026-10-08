# Spec Delta

## ADDED Requirements

### Requirement: Voice turns

A prompt sent from a voice conversation SHALL go through the same send path as a typed one. It appears in the transcript, is queued behind a pending reply and is retried in the same way. Its `prompt.submit` SHALL carry `voice_turn: true`, so Hermes runs that turn on the profile's `voice_chat` model route. When the user cut off the previous reply by speaking, the prompt SHALL also carry `interrupted: true`. A typed prompt SHALL carry neither flag. When the server answers `{"voice_stopped": true}` without a `status`, the app SHALL take the prompt as consumed, show no reply, and end the voice conversation.

#### Scenario: Spoken prompt

- **WHEN** a voice conversation sends the transcript "what's on my calendar"
- **THEN** the thread shows "what's on my calendar" as a user message, and `prompt.submit` carries `voice_turn: true`

#### Scenario: Barge-in prompt

- **WHEN** the user speaks over a reply and the conversation sends what they said
- **THEN** `prompt.submit` carries `voice_turn: true` and `interrupted: true`

#### Scenario: Typed prompt

- **WHEN** the user types and sends a message
- **THEN** `prompt.submit` carries neither `voice_turn` nor `interrupted`

#### Scenario: Server ends voice mode

- **WHEN** `prompt.submit` for a spoken stop phrase answers `{"voice_stopped": true}`
- **THEN** no reply placeholder remains and the voice conversation ends
