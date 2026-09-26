## ADDED Requirements

### Requirement: Composer layout

The system SHALL show the composer as one rounded card with the text field on top and a row below it holding, from left to right, an attach button, the model pill when it is shown, a flexible gap and a send button. The send button SHALL be a filled circle in the primary colour with an upward arrow, and SHALL look disabled and do nothing while the field is blank and there are no attachments. The text field SHALL grow with its text up to eight lines and then scroll. The stop bar, the queued messages and the attachment chips SHALL be shown above the card. The card SHALL stay above the bottom safe area and the on-screen keyboard. The layout uses no backend route or RPC method.

#### Scenario: Empty composer

- **WHEN** the chat is open with nothing typed and nothing attached
- **THEN** the card shows the hint "Message Hermes…", and its bottom row shows the attach button, the pill and a disabled send button, in that order

#### Scenario: Text makes the message sendable

- **WHEN** the user types "hello"
- **THEN** the send button turns primary and tapping it sends "hello"

#### Scenario: Attachments alone are sendable

- **WHEN** the field is blank and a file is attached
- **THEN** the send button is enabled and the file's chip is shown above the card

#### Scenario: Reply in flight

- **WHEN** a reply is being written and a message is queued
- **THEN** the stop bar and the queued message are shown above the card and the hint reads "Queue a message…"

#### Scenario: No pill

- **WHEN** the model list is not available
- **THEN** the bottom row holds only the attach and send buttons

#### Scenario: Attach

- **WHEN** the user taps the attach button
- **THEN** the same attachment menu opens as before
