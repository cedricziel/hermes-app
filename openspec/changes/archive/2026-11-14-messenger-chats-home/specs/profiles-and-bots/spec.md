## MODIFIED Requirements

### Requirement: Switching profile

The system SHALL let the user select a profile for chatting locally without changing the dashboard's active profile, terminal default, or stored profile configuration. The local recipient and the server active profile SHALL be presented as distinct values. This behavior SHALL apply to profile pickers, profile pages, and new-message recipients on every Flutter platform. Only a separately labelled and explicitly invoked terminal-default action SHALL change the server active profile.

#### Scenario: Choosing another profile

- **WHEN** the user chooses a profile different from the server active profile for chatting
- **THEN** the app loads that profile's chats with explicit profile scope and sends no request to change the active profile or profile configuration

#### Scenario: Choosing the active profile when the chat shows another

- **WHEN** the user chooses the server active profile while the chat shows a different profile
- **THEN** the app changes its local chat scope without changing the server active profile

#### Scenario: Choosing the profile already in use

- **WHEN** the user chooses the profile already shown in the chat
- **THEN** selection sends no mutation and does not reload the chat

#### Scenario: Switch is rejected

- **WHEN** loading the selected profile fails or the profile is no longer available
- **THEN** the app shows a recoverable error and sends no message under a fallback profile

#### Scenario: The chat and the CLI default differ

- **WHEN** the profile shown in the chat differs from the server active profile
- **THEN** the app keeps the local selection and distinguishes the chat recipient from the CLI default without synchronizing either value to the other

#### Scenario: Explicit terminal-default action

- **WHEN** the user explicitly invokes a separately labelled terminal-default action
- **THEN** only that action may call POST /api/profiles/active and ordinary messaging does not invoke it implicitly

#### Scenario: Profile-scoped backend contract

- **WHEN** the user lists, creates, resumes, or sends a conversation for a selected profile
- **THEN** the app uses the existing profile-scoped REST session contracts and authenticated /api/ws session.create and session.resume methods with their existing profile arguments and response shapes
- **AND** no new endpoint, response field, or minimum Hermes Agent version beyond the app's existing contracts is required

#### Scenario: Reconnect preserves recipient

- **WHEN** a conversation reconnects after another client changes the server active profile
- **THEN** the conversation resumes with its original explicit profile and leaves the new server default unchanged
