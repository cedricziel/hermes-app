## ADDED Requirements

### Requirement: Shared content is attached and sent

The system SHALL accept content shared into the app while the chat is open or before it opens: shared text SHALL go into the composer and shared files SHALL be listed as removable attachments above it. Attachments SHALL be sent to Hermes with the message, as the `chat-attachments` spec describes, and SHALL then be cleared from the composer.

#### Scenario: Shared text prefills the composer

- **WHEN** text is shared and the composer is empty
- **THEN** the text fills the composer
- **AND WHEN** the composer already holds a draft
- **THEN** the shared text is appended on a new line

#### Scenario: Shared files become chips

- **WHEN** files are shared
- **THEN** each shows as a chip with its name and a remove control, and attachments alone are enough to send

#### Scenario: Files are sent with the message

- **WHEN** the user sends with attachments
- **THEN** the attachments are sent to Hermes with the message and cleared from the composer

## REMOVED Requirements

### Requirement: Shared content

**Reason**: It said shared files are only named, never uploaded. Attachments are now sent to Hermes.

**Migration**: Use "Shared content is attached and sent".
