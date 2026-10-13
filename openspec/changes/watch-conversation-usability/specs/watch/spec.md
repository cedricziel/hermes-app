## ADDED Requirements

### Requirement: Visible failed outgoing message recovery

The watch SHALL retain a failed outgoing text visibly with its delivery status. Retry SHALL follow watch-send-recovery: status lookup retains the original identity, proven not_sent permits a new identity, and uncertain resubmission requires an explicitly confirmed new attempt. Retry SHALL never blindly duplicate a command. Edit SHALL restore definitely unsent text to the composer without submitting it and SHALL assign a new identity only when the user sends. For unknown acceptance, the watch SHALL offer Check result. If acceptance remains uncertain after that check, it SHALL offer a separate Send again action only after explicit confirmation that the original command may already have run. Confirmed Send again SHALL create a new send identity; it SHALL NOT masquerade as Retry. Edit of the original uncertain send SHALL remain unavailable. Discard SHALL discard a local unsent draft without cancelling server work. An accepted message SHALL remain in history; leaving its wait SHALL NOT offer Edit as though it were unsent.

#### Scenario: Definitely unsent

- **WHEN** the phone could not be reached before any request was delivered
- **THEN** the outgoing text remains visible with Retry, Edit, and Discard

#### Scenario: Acceptance unknown

- **WHEN** delivery fails after submission may have reached Hermes
- **THEN** Check result is available and Edit cannot issue a replacement prompt; Send again requires a prior check and duplicate-risk confirmation

#### Scenario: Edit and discard

- **WHEN** the user edits definitely unsent text and then discards it
- **THEN** no prompt is submitted and the local failed draft is removed

### Requirement: Stable conversation reading position

The watch SHALL preserve the visible message position when the user reads older messages and new messages arrive. When following the current turn, a new answer SHALL reveal its beginning. A New reply action SHALL let a reader move to that answer. Status transitions and retries SHALL NOT scroll to the composer automatically.

#### Scenario: Reading history

- **WHEN** a reply arrives while the user reads an older message
- **THEN** the position remains stable and New reply is available

#### Scenario: Following the turn

- **WHEN** the user waits at the current turn and its answer arrives
- **THEN** the beginning of that answer is visible

#### Scenario: Status update

- **WHEN** a pending message changes to waiting or failed
- **THEN** the visible reading position does not jump

### Requirement: Conversation usability accessibility

All added controls SHALL have meaningful VoiceOver labels and hints describing their action and state. Content and essential actions SHALL remain reachable at the maximum supported watch text size without shrinking essential labels below readability. Status SHALL not depend on color alone. Automatic updates SHALL preserve VoiceOver focus while the user reads or edits.

VoiceOver SHALL identify each message's speaker as the user or Hermes before its content, in chronological reading order.

#### Scenario: Read a conversation with VoiceOver

- **WHEN** the user reads successive user and assistant messages with VoiceOver
- **THEN** each message announces its speaker before its content without relying on bubble position

#### Scenario: Maximum text size

- **WHEN** the user enables the largest supported watch text size
- **THEN** content can scroll and essential actions remain reachable

#### Scenario: VoiceOver

- **WHEN** the user navigates the new controls with VoiceOver
- **THEN** each action and state has a meaningful label and focus remains stable during updates

### Requirement: Conversation usability backend compatibility

This change SHALL preserve watch `messages` and `send` and their existing Hermes contracts. Send/recovery responses SHALL distinguish definite nonacceptance, unknown acceptance, accepted pending, and completion under the reliability changes. No new backend route or minimum version is introduced by reading or draft presentation; gateway compatibility remains the pinned `openrpc/HERMES_REF` contract.

#### Scenario: Compatible relay

- **WHEN** a supported phone serves this watch change
- **THEN** the documented existing backend methods are used and unsupported optional fields degrade safely

### Requirement: Explicit replacement after uncertain delivery

After Check result leaves delivery uncertain, the watch SHALL explain that the original command may already have run before offering Send again. Cancelling confirmation SHALL send nothing. Confirming SHALL submit a new send with a new identity while keeping the original uncertain result distinct. No background or automatic resend SHALL occur.

#### Scenario: Explicit resend

- **WHEN** Check result remains uncertain and the user confirms Send again despite the duplicate-risk explanation
- **THEN** exactly one new send identity is submitted and the original uncertain send remains separately identified

#### Scenario: Cancel resend

- **WHEN** the user cancels the Send again confirmation
- **THEN** no prompt is submitted

## MODIFIED Requirements

### Requirement: Sending from the watch

The system SHALL send a message the user dictates or types on the watch into the chosen chat in its original bound profile, or into a new chat in the active Hermes profile when none is chosen. The text SHALL be trimmed and a blank text SHALL NOT be sent. The phone SHALL answer with a completed result only when the exact submitted turn is proven complete, with the chat's thread id, final text, and failure state; the reply SHALL NOT stream to the watch. It SHALL answer early with an explicit pending state while work or an answerable request remains open. A lost outcome SHALL be pending or uncertain until the original turn's result is proven, never inferred from the latest assistant message. When a turn that did not fail completes with a blank final text, the phone SHALL answer with the text that had streamed, or, when nothing streamed either, with "Hermes replied without any text.", so the watch never shows an empty reply; such a reply is not a failure, as for its notification. While waiting the watch SHALL show the user's message and "Hermes is thinking…", and SHALL NOT send another message. Outside request waiting, the phone SHALL give up and answer `failed` when no event arrives for 60 seconds. A request waiting turn SHALL use the existing 20-second state poll, 15-minute phone no-event limit, and 20-minute local watch wait limit. When a send fails, the watch SHALL show the outgoing text and its delivery state with the recovery controls defined by "Visible failed outgoing message recovery". Retry SHALL use the identity and acceptance-state rules of watch-send-recovery; a status lookup preserves the original identity, while proven non-dispatch or explicitly confirmed resubmission creates a new attempt.

#### Scenario: New chat

- **WHEN** the user sends "Hello" from the new chat control
- **THEN** the phone starts a chat, answers with its thread id and the reply, and the watch shows both messages and sends the next one into that chat

#### Scenario: Reply without text

- **WHEN** a turn completes without failure, its final text is blank and nothing streamed
- **THEN** the phone answers success with `failed` false and the text "Hermes replied without any text."

#### Scenario: Final text empty after streaming

- **WHEN** a turn completes without failure with a blank final text after "Hi there" streamed
- **THEN** the phone answers with "Hi there"

#### Scenario: Failed turn

- **WHEN** the reply ends in failure with the message "Model unavailable"
- **THEN** the watch shows that message as the reply

#### Scenario: Connection drops

- **WHEN** the connection to the dashboard drops or the stream ends before a reply
- **THEN** the phone answers `failed` and the watch shows its delivery state and safe recovery controls

#### Scenario: Silent gateway

- **WHEN** no event arrives for 60 seconds outside request waiting
- **THEN** the phone gives up and answers `failed`
