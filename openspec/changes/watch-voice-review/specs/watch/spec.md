## ADDED Requirements

### Requirement: Review voice before sending

Unless Optional voice fast-send applies, the watch SHALL transcribe a stopped recording into an editable draft and SHALL NOT submit a prompt until Send is activated. Send SHALL use the edited, trimmed, nonblank text. Discard SHALL release the transcript and temporary audio without submission. Recording SHALL show elapsed time and the 30-second limit. Failed transcription SHALL offer Retry transcription and Discard; no speech SHALL offer Record again.

#### Scenario: Default review

- **WHEN** a recording transcribes to "delete folder"
- **THEN** the transcript appears with Send, Edit, and Discard and no prompt is submitted

#### Scenario: Edited transcript

- **WHEN** the user changes the transcript and activates Send
- **THEN** only the changed text is submitted once

#### Scenario: Discard

- **WHEN** the user discards a transcript or failed recording
- **THEN** its local audio and text are released and nothing is sent

### Requirement: Optional voice fast-send

The watch SHALL offer a fast-send preference that defaults to off and explains that manually stopped recordings send after transcription. Fast-send SHALL apply only to a recording explicitly stopped by the user. Interruption, duration cap, and automatic termination SHALL always produce a review draft. Changing the setting SHALL NOT submit a current draft. A double tap during recording SHALL act like a manual stop under the selected mode.

#### Scenario: Manual fast-send

- **WHEN** fast-send is enabled and the user stops a recording
- **THEN** a successful nonblank transcript is submitted once

#### Scenario: Automatic stop

- **WHEN** fast-send is enabled and an interruption or the duration cap ends recording
- **THEN** the transcript awaits review and no prompt is submitted

#### Scenario: Leave during transcription

- **WHEN** the user leaves or signs out while transcription is pending
- **THEN** late transcription is ignored and sensitive draft state is cleared

### Requirement: Voice review accessibility

All added controls SHALL have meaningful VoiceOver labels and hints describing their action and state. Content and essential actions SHALL remain reachable at the maximum supported watch text size without shrinking essential labels below readability. Status SHALL not depend on color alone. Automatic updates SHALL preserve VoiceOver focus while the user reads or edits.

#### Scenario: Maximum text size

- **WHEN** the user enables the largest supported watch text size
- **THEN** content can scroll and essential actions remain reachable

#### Scenario: VoiceOver

- **WHEN** the user navigates the new controls with VoiceOver
- **THEN** each action and state has a meaningful label and focus remains stable during updates

### Requirement: Voice review backend compatibility

The phone SHALL continue to accept watch `transcribe` with nonempty audio and MIME type and reply `{ok: true, text, engine}`. The phone SHALL use its on-device recognizer when available and otherwise POST `/api/audio/transcribe` with `data_url` and `mime_type`, whose successful body provides `transcript`. Command submission SHALL remain a separate watch `send`. No new Hermes route or minimum version is introduced; compatibility follows the unchanged transcription method contracts pinned by `openapi/HERMES_REF` and `openrpc/HERMES_REF`.

#### Scenario: Compatible relay

- **WHEN** a supported phone serves this watch change
- **THEN** the documented existing backend methods are used and unsupported optional fields degrade safely

## MODIFIED Requirements

### Requirement: Quick replies and double tap

The watch SHALL show the fixed quick replies "Continue", "Yes", "No", and "Summarize" above the reply field. Tapping one SHALL send its text under Sending from the watch. Quick replies SHALL be disabled while the reply field is disabled, including while a reply is pending, and hidden during recording. On watchOS 11 and later, double tap SHALL start recording while the chat is idle and SHALL manually stop recording while recording. The stopped recording SHALL follow Review voice before sending and Optional voice fast-send. Double tap SHALL do nothing when its control is disabled.

#### Scenario: Double tap idle

- **WHEN** the user double taps while idle
- **THEN** recording starts

#### Scenario: Double tap recording in review mode

- **WHEN** the user double taps during recording with fast-send off
- **THEN** recording stops and transcription produces a draft without submission

#### Scenario: Reply pending

- **WHEN** a reply is pending
- **THEN** reply controls are disabled and double tap submits nothing
