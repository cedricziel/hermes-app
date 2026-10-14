# Spec Delta

## Purpose

Describes the quick-reply chips and the double-tap gesture in a watch chat.

## ADDED Requirements

### Requirement: Quick replies and double tap

The watch SHALL show the fixed quick replies "Continue", "Yes", "No" and "Summarize" above the reply field of a chat. Tapping one SHALL send its text as a message under the rules of "Sending from the watch", and the quick replies SHALL be disabled whenever the field is, in particular while a reply is pending. They SHALL NOT be shown while a voice message is being recorded. On watchOS 11 and later, the double-tap gesture SHALL start a voice message when the chat is idle, and stop and send the recording while one is being made; it SHALL do nothing while the voice button is disabled.

#### Scenario: Tap a quick reply

- **WHEN** the user taps "Yes" in an idle chat
- **THEN** the watch sends "Yes" into that chat and shows "Hermes is thinking…"

#### Scenario: Reply pending

- **WHEN** a reply is pending
- **THEN** the quick replies are disabled and a tap sends nothing

#### Scenario: Double tap while idle

- **WHEN** the user double taps in an idle chat
- **THEN** a voice message starts recording

#### Scenario: Double tap while recording

- **WHEN** the user double taps while recording
- **THEN** the recording stops and is sent as a voice message
