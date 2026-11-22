## MODIFIED Requirements

### Requirement: Rendering of messages

The system SHALL render a message as its tool call cards, each after the reasoning that led to it, with each agent input request card right after the tool call that was running when it arrived, then the reasoning that followed the last call, then the text, then a thinking indicator, and SHALL render message text as markdown.

#### Scenario: What follows an input request renders below it

- **WHEN** a reply reasons, writes text or starts tool calls after an input request arrived
- **THEN** those render below the request's card, and the request's card stays below the tool call that asked it

#### Scenario: Thinking indicator

- **WHEN** an assistant reply is pending with no text yet, no reasoning yet and no input request is waiting
- **THEN** a thinking indicator (three pulsing dots) is shown in place of text

#### Scenario: No indicator while the agent waits for the user

- **WHEN** a reply is still thinking and one of its input requests is pending
- **THEN** the thinking indicator is hidden

#### Scenario: No indicator once reasoning shows

- **WHEN** a reply is still thinking and has reasoning
- **THEN** the thinking indicator is hidden and the reasoning block is shown

#### Scenario: Failed reply

- **WHEN** a reply ended in error and has text
- **THEN** its text is drawn in the error colour

#### Scenario: Empty thread

- **WHEN** the open thread has no messages, or no thread is selected
- **THEN** the welcome view shows "Where should we begin?" (with the user's display name appended when known) and four starter prompts as defined by "Context-based starter prompts"

#### Scenario: Responsive layout

- **WHEN** the shell form is expanded (900 logical pixels or more on any platform, a full-screen iPad from 700, any Mac window)
- **THEN** the thread rail is permanently shown beside the transcript, with the thread title above it
- **AND WHEN** the form is medium on Android, Windows or Linux and the width is 720 logical pixels or more
- **THEN** the thread list is shown beside the transcript, right of the navigation rail, and the thread title is shown in the conversation's app bar
- **AND WHEN** the form is not expanded on iOS (compact or medium, such as an iPhone at 852 x 393), compact on Android, or medium below 720 on Android, Windows or Linux
- **THEN** the thread list is a full page with the tab bar, navigation bar or rail and no drawer, and the conversation is pushed over it with the thread title in its app bar
- **AND WHEN** the form is compact on Windows or Linux
- **THEN** the thread list is a full page whose drawer holds the destinations, the management entries and the account menu, as today, and the conversation is pushed over it with the thread title in its app bar
