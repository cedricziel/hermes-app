## ADDED Requirements

### Requirement: Shared content respects protected screens

Shared text, files, and selected-text quotes SHALL remain pending until routes above the shell allow dismissal and App Lock allows navigation. Receiving content SHALL NOT modify the selected chat, composer, or attachments before that boundary. Keeping an editor open or failing a save SHALL retain both the editor draft and the shared content. Delivery SHALL send no message automatically.

#### Scenario: Share while editing
- **WHEN** text or files arrive while a dirty editor is open
- **THEN** the existing discard confirmation is used and the share remains unapplied until dismissal

#### Scenario: Locked delivery
- **WHEN** shared content arrives while App Lock covers the app
- **THEN** the content stays pending until unlock and is delivered once

#### Scenario: Held launch share
- **WHEN** shared content is waiting when the shell starts
- **THEN** it uses the same guarded delivery boundary

### Requirement: Navigation replacement retains shared payloads

Waiting text and files SHALL accumulate independently of the latest navigation request. Only the latest waiting selected-text quote SHALL be retained, matching existing share behavior. A newer notification or link SHALL win navigation and SHALL leave shared payloads pending for the next explicit Chat section entry, including repeated selection of Chat. Disposing the shell SHALL cancel its callback without consuming pending content.

The backend contract SHALL remain existing chat/session/attachment behavior, with no new REST routes, RPC methods, response shapes, or minimum Hermes Agent version. Existing pending-quote sign-out cleanup SHALL remain intact.

#### Scenario: Several shares
- **WHEN** several text/file shares and quotes arrive while navigation waits
- **THEN** accepted delivery includes every text/file and only the latest quote once

#### Scenario: Newer navigation wins
- **WHEN** a newer notification or link replaces waiting share navigation
- **THEN** its destination opens and shared content remains pending until an explicit Chat entry

#### Scenario: Deferred Chat recovery
- **WHEN** a newer external request arrives after Chat selection but before share recovery runs
- **THEN** recovery does not override that request and the share remains pending

#### Scenario: Delayed initial lookup
- **WHEN** launch-inbox content arrives after newer navigation or a newer waiting quote
- **THEN** it does not replace that navigation or quote, and its remaining text/files stay retained

#### Scenario: Shell disposal
- **WHEN** the shell is disposed before share delivery
- **THEN** its callback does not mutate chat and untaken content remains pending
