## MODIFIED Requirements

### Requirement: Sign-in outcome and progress

While a sign-in runs, the state SHALL be signing in, and the login screen SHALL show a progress indicator, the text "Continue in your browser…" and a Cancel button, and SHALL disable the "Change server" action. On success the system SHALL store the session, load the identity with `GET /api/auth/me` and go to ready. On any failure it SHALL go to needs login and SHALL show the failure message. The state SHALL NOT remain signing in after a failure or cancellation, including a cancellation that arrives after the browser flow has already produced its result.

#### Scenario: Flow failure

- **WHEN** the native flow fails with a readable message
- **THEN** the state is needs login
- **AND** that message is shown

#### Scenario: Identity load fails after sign-in

- **WHEN** the token exchange succeeds and the identity request fails
- **THEN** the state is needs login
- **AND** the message is the server's `detail` string if present, otherwise "Sign-in succeeded but loading your profile failed" for network failures

#### Scenario: Unexpected error

- **WHEN** the sign-in raises an error of an unexpected type, such as a platform exception
- **THEN** the state is needs login
- **AND** the message is "Sign-in failed. Please try again."

#### Scenario: User cancels

- **WHEN** the user presses Cancel while waiting for the browser
- **THEN** the loopback listener is released and the browser sheet is closed
- **AND** the state is needs login without an error message

#### Scenario: Cancel during the token exchange

- **WHEN** the user cancels after the callback arrived but before the token response is processed
- **THEN** the session is discarded and never stored

#### Scenario: Cancel while the browser is closing

- **WHEN** the browser flow has already produced a session and the user presses Cancel while the browser sheet is still closing
- **THEN** the session is discarded and never stored
- **AND** the state is needs login without an error message
- **AND** the sign-in is recorded as cancelled

#### Scenario: Server changed while sign-in was finishing

- **WHEN** the user leaves the server (or signs out) while a sign-in is still completing
- **THEN** the late result is discarded and no token is stored
- **AND** the state stays where the user's action put it
