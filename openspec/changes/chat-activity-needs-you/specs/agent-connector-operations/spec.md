# Spec Delta

## ADDED Requirements

### Requirement: A response is confirmed or reported unconfirmed within 10 seconds

The app SHALL end the wait for a connection response within 10 seconds of sending it. A response the server refuses, a failed call and a missing confirmation SHALL each be reported as unconfirmed and SHALL re-enable the response actions while the operation still has authority. The app SHALL NOT resend a response automatically, and a settlement that arrives after the report SHALL still settle the operation.

#### Scenario: The server does not answer

- **WHEN** connection.respond has no result after 10 seconds
- **THEN** the operation reports an unconfirmed answer and Skip and Continue are offered again
- **AND** no second connection.respond call was made
