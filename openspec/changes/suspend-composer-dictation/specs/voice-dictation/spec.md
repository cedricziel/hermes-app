## ADDED Requirements

### Requirement: Dictation suspension

When a composer's session becomes inactive, the app SHALL immediately reject new capability checks, model download starts, recordings, and transcription retries. It SHALL discard in-progress voice work and restore the original typed draft including selection before asynchronous microphone shutdown finishes. Late capability, partial, and transcript results SHALL NOT change the composer. A recording acquisition that completes after suspension SHALL be closed and SHALL NOT overlap a newer recording.

#### Scenario: An earlier listener resumes during suspension
- **WHEN** an earlier activity listener synchronously resumes activity before dictation listeners observe the inactive value
- **THEN** the delivered notifications still cancel the old recording and restore its original draft before held microphone cleanup completes
- **AND** text typed after that recovery is not overwritten by old cleanup

#### Scenario: Support lookup completes after suspension

- **WHEN** the session becomes inactive while a voice capability check is pending
- **THEN** its late response does not make dictation available or start a recording

#### Scenario: Microphone shutdown waits

- **WHEN** suspension cancels recording and microphone shutdown remains pending
- **THEN** the composer already contains its original typed text and selection, and late voice results cannot overwrite it

#### Scenario: Upload was already dispatched

- **WHEN** suspension occurs after a transcription upload was sent
- **THEN** the request may finish remotely, but its result is ignored locally

#### Scenario: Authorized session resumes

- **WHEN** the external session owner authorizes activity again
- **THEN** capabilities are refreshed and the typed draft remains unchanged, with no automatic recording, retry, or send

#### Scenario: Existing ungated caller

- **WHEN** no session activity signal is provided
- **THEN** existing dictation behavior remains available

#### Scenario: Suspension reenters transcript settlement

- **WHEN** activity pauses and resumes synchronously while a transcript or silence result settles
- **THEN** the invalidated dictation completes as cancelled, retains the original typed value, and does not send that draft

The existing backend contract is unchanged: `GET /api/audio/voice-config` and `POST /api/audio/transcribe` require Hermes v2026.9.11; `/api/audio/transcribe-stream` and `POST /api/audio/stt-lease` require v0.21.6. Responses and fallback behavior retain the existing voice-dictation specification.

## MODIFIED Requirements

### Requirement: Speech-to-text warm-up

When recording starts with the Hermes engine and authorized session activity, the app SHALL send `POST /api/audio/stt-lease?profile=<profile>` with `{"lease": "app:voice-input:<id>", "active": true}`, where `<id>` is random per app run. Normal transcript settlement, active cancellation, and active screen disposal SHALL release the same lease with `"active": false` and its acquired profile. Disposal alone SHALL NOT revoke authorization for cleanup.

While session activity is false, the app SHALL send neither lease acquisition nor lease release requests. It SHALL retain pending release metadata, including the acquired profile and acquisition completion, and release after the session owner authorizes the same session again. Releases SHALL finish before a newer lease acquisition starts. If cleanup fails, recording MAY proceed without a newer warm-up lease while the old cleanup remains pending. Failed lease requests SHALL NOT prevent recording or transcription.

If cleanup is still pending when the composer is disposed, it SHALL transfer that cleanup to its session owner without retaining activity listeners. Permanent authorization loss SHALL NOT send cleanup under another owner. Remote release cannot be guaranteed after permanent authorization loss. The backend contract specifies no lease TTL. Its model idle eviction does not establish lease expiry.

#### Scenario: Lease fails

- **WHEN** the stt-lease request fails
- **THEN** recording and transcription proceed as normal

#### Scenario: Active screen disposal

- **WHEN** the chat screen is disposed while the same session remains authorized
- **THEN** cleanup releases its captured lease and profile even though the recording controller is disposed

#### Scenario: Transient suspension

- **WHEN** activity becomes false after a lease acquisition starts
- **THEN** cleanup waits for that acquisition and remains pending without remote requests until the same owner authorizes activity again
- **AND** cleanup releases the captured lease before another lease acquisition, without starting a recording or upload automatically

#### Scenario: Inactive composer disposal

- **WHEN** the composer is disposed with pending cleanup while activity is false
- **THEN** its session owner receives the cleanup metadata, the controller removes its activity listener, and no lease request is sent while inactive

#### Scenario: Permanent authorization loss

- **WHEN** the original session cannot regain authorization
- **THEN** the app does not release its lease using another session's credentials and does not claim guaranteed remote lease expiry
