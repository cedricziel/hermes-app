## Why

A retained composer must stop voice work when its session becomes inactive. Pending capability checks and transcription callbacks can currently change the composer after suspension, and microphone shutdown delays restoring the typed draft.

## What Changes

- Accept an optional activity signal, with existing callers remaining active by default.
- Fence support/model requests and dictation starts while inactive; cancel recording and discard late partials and transcripts.
- Restore the typed draft and selection synchronously on suspension, before microphone shutdown completes.
- Refresh capabilities on authorized reactivation without restarting recording or transcription.
- Defer captured lease release while inactive, flush it before new acquisition on authorized resume, and hand inactive-disposal cleanup to the original session owner.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `voice-dictation`: Suspend voice work and preserve the original typed composer value.

## Impact

Changes are limited to composer dictation, its recording controller, and focused tests. Existing Hermes voice routes and versions are unchanged. Non-goals: authentication proof, navigator retention, auxiliary windows, native microphone implementations, and automatic recording restart.

Security and privacy: inactive sessions cannot start new microphone or voice requests; already dispatched uploads may still finish remotely, but their results are ignored. No token or storage changes.

Lease cleanup requires the original session's authorization. Permanent authorization loss prevents guaranteed remote cleanup; the backend contract specifies no lease expiry timer. Owner-held disposal cleanup remains part of session integration.

Observability: retain the existing fixed cancellation breadcrumb; no new spans or events are needed for the local activity gate. Breadcrumbs contain no text, profile, or credential data.
