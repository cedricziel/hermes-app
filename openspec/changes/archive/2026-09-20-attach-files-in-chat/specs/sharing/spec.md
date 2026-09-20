## ADDED Requirements

### Requirement: Shared files are removable attachments that are sent

Shared files SHALL appear as chips above the composer input, one per file, each with a "Remove <name>" control. Attachments alone SHALL be enough to send. On send, the files SHALL be sent to Hermes with the message, as the `chat-attachments` spec describes, and the attachments SHALL then be cleared.

#### Scenario: Remove an attachment

- **WHEN** the user removes one of two attached files
- **THEN** its chip disappears and the other remains

#### Scenario: Send attachments only

- **WHEN** the user sends with an attached file "report.pdf" and no typed text
- **THEN** the file is sent, the message shows it as an attachment, and the chip is gone

## REMOVED Requirements

### Requirement: Shared files appear as removable attachments

**Reason**: It said only the file names are sent, with a note under the chips. The files are now sent.

**Migration**: Use "Shared files are removable attachments that are sent".
