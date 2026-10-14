## ADDED Requirements

### Requirement: Watch local send-attempt isolation

After the user stops waiting, the watch SHALL ignore every subsequent response belonging to that stopped local attempt. A stale response SHALL NOT append messages, replace the thread or Handoff target, change the current phase, restore retry content, or start another poll. Stop waiting SHALL preserve the accepted user message and SHALL NOT cancel the server turn. Reloading the chat can show its eventual answer through the normal history request.

This behavior SHALL use the existing phone `send` relay, including `threadId`, `text`, `sendId`, `retry`, and `waits`, and existing complete or `waiting` replies. It SHALL require no additional Hermes RPC, REST route, response field, or backend version beyond the existing watch relay requirements.

#### Scenario: Completion after Stop waiting

- **WHEN** the user stops an approval wait and its pending poll later returns a successful reply
- **THEN** the watch leaves messages, metadata, and the current phase unchanged and sends no further poll

#### Scenario: Old reply after a new send

- **WHEN** a new send starts after Stop waiting and the old attempt then returns a completion, failure, or waiting state
- **THEN** only the new attempt can update the conversation

#### Scenario: Answer available in history

- **WHEN** the user reloads the chat after the stopped server turn completes
- **THEN** the watch shows the answer returned by history without resuming the stopped local polling attempt
