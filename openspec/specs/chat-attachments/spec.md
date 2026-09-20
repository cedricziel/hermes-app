# chat-attachments Specification

## Purpose
Defines how files the user attaches to a chat message reach Hermes and how they appear in the transcript, live and after the thread is reloaded.
## Requirements
### Requirement: Attachments are sent to Hermes

On send, the system SHALL make each attachment available to the agent before the message is submitted. An image SHALL be attached to the session as an image, so a model with vision receives it. Any other file SHALL be attached to the session as a file, and the reference Hermes returns SHALL be added to the message text so the agent can open the file. An image the server does not accept as an image, for example an unsupported format, SHALL be attached as a file instead. The message SHALL NOT be submitted when any attachment fails.

#### Scenario: Send an image

- **WHEN** the user sends with an attached PNG and the text "what is this?"
- **THEN** the image is attached to the session and the text is submitted with it

#### Scenario: Send a document

- **WHEN** the user sends with an attached "report.pdf" and no text
- **THEN** the file is attached to the session, and the submitted text is the file reference Hermes returned

#### Scenario: One attachment fails

- **WHEN** one of two attachments is rejected by the server
- **THEN** the reply shows "Could not attach <name>: <reason>" and nothing is submitted to the agent

#### Scenario: Server without attachment support

- **WHEN** the server answers that the attach method does not exist
- **THEN** the reply shows "This Hermes server can't receive attachments. Update Hermes to attach files."

### Requirement: Attachment size limit

The system SHALL NOT send an attachment larger than 25 MB. It SHALL refuse the send, tell the user which file is too large with "<name> is larger than 25 MB and can't be sent.", and keep the composer text and attachments.

#### Scenario: Too large

- **WHEN** the user sends with a 30 MB attachment
- **THEN** nothing is sent, the message names the file, and the composer keeps its text and the attachment

### Requirement: Attachments in the transcript

A sent message SHALL show its attachments above its text: an image as a thumbnail and any other file as a card with its name and size. A message with attachments and no text SHALL show only the attachments.

#### Scenario: Image thumbnail

- **WHEN** the user sends an image
- **THEN** the message shows the image as a thumbnail

#### Scenario: File card

- **WHEN** the user sends "report.pdf" of 120 KB
- **THEN** the message shows a card reading "report.pdf" and "120 KB"

### Requirement: Attachments in reloaded history

When a thread loads from history, the system SHALL read attachments from the stored user messages and show them as it does for a message just sent. It SHALL recognise `@image:<path>` and `@file:<path>` references and "[User attached file: <path>]" lines, remove them from the visible text, and use the file name as the attachment's label. A stored message whose content is a list of parts SHALL load, its text parts joined in order; its embedded images MAY be shown from their data. A row it cannot read SHALL be skipped without failing the rest of the thread.

#### Scenario: Reloaded image message

- **WHEN** a stored user message reads "look\n@image:/home/u/.hermes/images/a.png"
- **THEN** the thread shows the text "look" and one image attachment named "a.png"

#### Scenario: List content

- **WHEN** a stored message's content is a list with a text part and an image part
- **THEN** the thread loads, shows the text, and does not fail

#### Scenario: File reference

- **WHEN** a stored user message contains "@file:docs/report.pdf"
- **THEN** the thread shows a file card named "report.pdf" and the reference is not in the visible text

