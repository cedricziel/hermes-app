## Why

Voice transcription currently sends a command immediately. Reviewing the transcript prevents recognition mistakes from becoming unintended agent work.

## What Changes

- Review voice transcripts by default with Send, Edit, and Discard.
- Offer an explicit watch-local fast-send preference, off by default.
- Show elapsed recording time and keep interrupted or capped recordings for review.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `watch`: Voice transcription currently sends a command immediately. Reviewing the transcript prevents recognition mistakes from becoming unintended agent work.

## Impact

ios/HermesWatch/VoiceRecorder.swift, ConversationView.swift, Core/ConversationModel.swift and their native fixtures. Implement after privacy reset and attempt guards. Adopt the native lifecycle verification change for interruption, sleep/wake, and late transcription.

### Non-goals

Streaming dictation, conversation voice mode, audio playback, persistent or cross-device drafts.

### Security and privacy

The watch receives no tokens. Sensitive text remains outside telemetry. Logout and identity change clear private watch state. App Lock additionally clears and blocks inline request details and answer drafts. Existing secure-storage and concurrent-401 behavior remain intact. Request detail changes do not expand the surface snapshot.

### Observability

Reuse content-free watch relay start/completion events and native operation/result logs. New relay operations, when present, become fixed operation values in those events. No new exported UI events or breadcrumbs are needed for local presentation. Test that logging failures cannot change results and fields never include text, audio, titles, profile names, addresses, or identifiers.
