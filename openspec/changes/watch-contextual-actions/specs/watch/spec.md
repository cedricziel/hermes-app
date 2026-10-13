## ADDED Requirements

### Requirement: Built-in starters for a new chat

An empty new chat with an empty composer SHALL offer built-in Plan my day and Explain something starters. Selecting one SHALL insert an editable starter draft and SHALL NOT submit a prompt. The user SHALL edit, send, or discard the draft under the existing composer rules. Starters SHALL NOT overwrite an existing typed or voice draft. The watch SHALL NOT provide custom favorites storage or editing.

#### Scenario: Select a starter

- **WHEN** the user selects Plan my day in an empty new chat
- **THEN** an editable planning draft appears and no prompt is submitted

#### Scenario: Existing draft

- **WHEN** the user has typed a draft or has a voice transcript awaiting review
- **THEN** starter controls cannot overwrite that draft

### Requirement: Contextual actions accessibility and compatibility

Contextual controls SHALL have meaningful VoiceOver labels identifying whether the action inserts a draft, sends a follow-up, or answers a request. All actions SHALL remain reachable at the maximum supported watch text size without depending on color or shrinking essential labels. Updates SHALL preserve reading and edit focus. This change SHALL introduce no Hermes route or RPC. Ordinary follow-ups SHALL use the existing watch `send` and `/api/ws` `prompt.submit` contract; request answers SHALL use the exact identity-bound contracts of watch-inline-approvals and watch-inline-questions. The pinned `openrpc/HERMES_REF` contract remains the baseline with no newer minimum version. Required context-identity handshake gates SHALL remain unchanged.

#### Scenario: VoiceOver starter

- **WHEN** VoiceOver focuses a starter
- **THEN** its label explains that it creates an editable draft instead of submitting immediately

#### Scenario: Large text

- **WHEN** maximum watch text size is enabled
- **THEN** starter and follow-up labels remain readable and all essential actions remain reachable

#### Scenario: Existing gateway

- **WHEN** the user sends Continue after an answer
- **THEN** the same identity-bound ordinary send path is used without a new backend method

## MODIFIED Requirements

### Requirement: Quick replies and double tap

The watch SHALL show built-in starters under Built-in starters for a new chat before the first message. After a successfully completed assistant reply, it SHALL offer Continue and Summarize while idle with no draft, pending request, or unresolved delivery. A tap SHALL send the selected fixed text under Sending from the watch. Generic Yes and No chat chips SHALL NOT serve as approval or question answers. For an active approval or question, the watch SHALL show the structured request's exact offered actions under the inline-request requirements, or notification/iPhone fallback when unsupported. Ordinary starters and follow-ups SHALL be hidden while recording, transcribing, loading, sending, reviewing a draft, waiting for a request answer, or resolving uncertain delivery; stale activation SHALL submit nothing.

On watchOS 11 and later, double tap SHALL start recording while the chat is idle and SHALL manually stop recording while recording. The stopped recording SHALL follow Review voice before sending and Optional voice fast-send. Double tap SHALL do nothing when its control is disabled.

#### Scenario: Completed answer

- **WHEN** the assistant completes a successful answer and the chat is idle with no draft
- **THEN** Continue and Summarize appear and each sends its own text through the ordinary send path

#### Scenario: Active request

- **WHEN** an approval or question is pending
- **THEN** only the structured offered request actions or phone fallback appear, and no generic Yes/No chat answer is submitted

#### Scenario: Reply pending

- **WHEN** a reply or unresolved delivery is pending
- **THEN** ordinary follow-up actions are hidden and stale activation submits nothing

#### Scenario: Double tap idle

- **WHEN** the user double taps while idle with its control enabled
- **THEN** recording starts

#### Scenario: Double tap recording in review mode

- **WHEN** the user double taps during recording with fast-send off
- **THEN** recording stops and transcription produces a draft without submission

#### Scenario: Double tap recording in fast-send mode

- **WHEN** the user double taps during recording with fast-send on
- **THEN** the explicit manual stop follows Optional voice fast-send, while interruption and duration cap still require review
