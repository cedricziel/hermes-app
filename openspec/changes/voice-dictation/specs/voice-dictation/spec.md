# Spec Delta

## Purpose

Lets the user speak a prompt instead of typing it: the chat composer records speech and puts Hermes' transcript into the draft for the user to review and send.

## ADDED Requirements

### Requirement: Microphone button availability

The composer SHALL show a microphone button ("Dictate" for assistive technologies) in its bottom row, beside send, only when the chat's profile has a usable speech-to-text provider. The app SHALL read `GET /api/audio/voice-config?profile=<profile>` and treat speech-to-text as unusable when the request fails, the server answers 404, or `stt.reason` is `stt disabled` or `no credentials`. Any other answer, including a relay to a local provider, SHALL count as usable. The app SHALL check again when the profile changes, when the app reconnects and when it returns to the foreground. While dictation is unavailable the composer SHALL look exactly as it does without this feature.

#### Scenario: Profile has a speech-to-text provider

- **WHEN** the chat screen opens for a profile and `voice-config` answers 200 with `stt.mode` `relay` and `stt.reason` `local provider`
- **THEN** the composer shows the microphone button

#### Scenario: Speech-to-text turned off

- **WHEN** `voice-config` answers with `stt.reason` `stt disabled`
- **THEN** the composer shows no microphone button

#### Scenario: Older server without voice routes

- **WHEN** `GET /api/audio/voice-config` answers 404
- **THEN** the composer shows no microphone button and the rest of the composer is unchanged

### Requirement: Microphone permission

The app SHALL ask the operating system for microphone access the first time the user taps the microphone button. When access is denied, the app SHALL NOT record, SHALL show a message saying microphone access is off and how to turn it on in the system settings, and SHALL leave the draft unchanged.

#### Scenario: First use

- **WHEN** the user taps the microphone button and the app has never asked for microphone access
- **THEN** the system permission prompt appears, and recording starts only if the user allows it

#### Scenario: Access denied

- **WHEN** the user taps the microphone button and microphone access is denied
- **THEN** no recording starts and the composer shows that microphone access is off

### Requirement: Recording state

While recording, the composer SHALL replace the text field with a live waveform that follows the input level, a pulsing recording dot and the elapsed time, and SHALL replace the microphone button with a stop button ("Stop voice input"). A cancel button SHALL discard the recording. After stop, the waveform SHALL settle into a "Transcribing" state until the transcript lands, and the text field with the draft SHALL then return. Sending SHALL be unavailable from the start of a recording until the transcript lands. Recording SHALL stop by itself after 5 minutes, as if the user had tapped stop.

#### Scenario: Recording in progress

- **WHEN** the user has started a recording
- **THEN** the composer shows the waveform, the recording dot, the elapsed time, cancel and stop in place of the text field and the microphone button

#### Scenario: Settling

- **WHEN** the user taps stop
- **THEN** the waveform shows "Transcribing" until the transcript is inserted, and then the text field returns with the draft

#### Scenario: Time limit

- **WHEN** a recording reaches 5 minutes
- **THEN** recording stops and the transcript is fetched as if the user had tapped stop

### Requirement: Live transcription

When `voice-config` reports `stt.streaming: true`, the app SHALL open the `/api/audio/transcribe-stream` socket (with the dashboard-socket credential and `profile`) when recording starts, send `{"sample_rate": N}` with N between 8000 and 48000, then binary 16-bit little-endian mono PCM frames while the user speaks, and `{"eos": true}` when the user taps stop. It SHALL show the latest `{"type":"partial","text":…}` frame's text as a live transcript over the waveform, styled as provisional and without editing the draft, and SHALL take `{"type":"final","transcript":…}` as the result. Cancel SHALL close the socket without sending `eos`.

#### Scenario: Partial text while speaking

- **WHEN** the server sends a partial frame during a recording
- **THEN** the waveform shows the partial text as a provisional live transcript, and the draft itself is unchanged

#### Scenario: Final transcript

- **WHEN** the user taps stop and the server sends a final frame with a non-empty transcript
- **THEN** the provisional text is replaced by the transcript inserted into the draft

#### Scenario: Cancel during live transcription

- **WHEN** the user taps cancel while the socket is open
- **THEN** the app closes the socket without sending `eos`, removes the provisional text and leaves the draft as it was before recording

### Requirement: Upload fallback

The app SHALL keep the whole recording in memory while recording and SHALL transcribe it with `POST /api/audio/transcribe?profile=<profile>`, body `{"data_url": "data:audio/wav;base64,<…>", "mime_type": "audio/wav"}`, when live transcription was not offered, the socket could not open within 5 seconds, the server sent an `error` frame, the socket closed before a final frame, or the final transcript was empty. While the upload runs the composer SHALL show that it is transcribing. The response's `transcript` field is the result.

#### Scenario: No live transcription for the provider

- **WHEN** the transcribe-stream socket answers `{"type":"error",…}` right after opening
- **THEN** the app keeps recording and, on stop, uploads the recording and inserts the returned transcript

#### Scenario: Socket drops mid-recording

- **WHEN** the socket closes during a recording
- **THEN** recording continues and the recording is uploaded on stop

### Requirement: Inserting the transcript

The app SHALL insert a non-empty transcript at the cursor of the draft (at its end when the field had no cursor), separated from adjacent text by a single space, and SHALL NOT send it. An empty transcript SHALL leave the draft unchanged and show "No speech detected". A failed transcription SHALL leave the draft unchanged and show the failure with a retry for the kept recording until the next recording starts or the user dismisses it.

#### Scenario: Transcript inserted, not sent

- **WHEN** the transcript "book a table for two" arrives and the draft is "Please"
- **THEN** the draft reads "Please book a table for two" and nothing is sent

#### Scenario: Silence

- **WHEN** the transcript comes back empty from both paths
- **THEN** the draft is unchanged and the composer shows "No speech detected"

#### Scenario: Transcription fails

- **WHEN** `POST /api/audio/transcribe` answers with an error status
- **THEN** the draft is unchanged and the composer shows the error with Retry

### Requirement: Speech-to-text warm-up

When recording starts the app SHALL send `POST /api/audio/stt-lease?profile=<profile>` with `{"lease": "app:voice-input:<id>", "active": true}`, where `<id>` is random per app run, and SHALL send the same lease with `"active": false` when the transcript settles, the recording is cancelled or the chat screen goes away. A failed lease request SHALL NOT affect recording or transcription.

#### Scenario: Lease fails

- **WHEN** the stt-lease request fails
- **THEN** recording and transcription proceed as normal

### Requirement: Recording ends when the app leaves the foreground

When the app goes to the background or the chat screen is closed during a recording, the app SHALL stop recording and discard it, as if the user had tapped cancel.

#### Scenario: App backgrounded

- **WHEN** the user switches to another app during a recording
- **THEN** the recording is discarded and the draft is unchanged when the user returns

### Requirement: Backend contract

Dictation SHALL rely only on these Hermes Agent routes. `voice-config` and `transcribe` are present since Hermes v2026.9.11, and `transcribe-stream` and `stt-lease` since v0.21.6. On an older server dictation SHALL still work by uploading, and SHALL ignore the missing lease route. The routes: `GET /api/audio/voice-config` (`{ok, stt: {mode, streaming?, …}, tts: {…}}`; only `stt.reason` and `stt.streaming` are read), the `/api/audio/transcribe-stream` WebSocket (protocol above, authenticated like `/api/ws` with `ticket` or `token`, closed with 4401 or 4403 when rejected), `POST /api/audio/transcribe` (`{ok, transcript, provider}`; 400 for empty or malformed audio, 413 above 25 MiB) and `POST /api/audio/stt-lease` (`{ok, lease, active, …}`). The app SHALL NOT use the client-direct provider settings or keys that `voice-config` may return.

#### Scenario: Server before v0.21.6

- **WHEN** the transcribe-stream socket is refused and `stt-lease` answers 405
- **THEN** the recording is uploaded on stop and its transcript inserted

#### Scenario: Provider keys ignored

- **WHEN** `voice-config` returns `stt.mode: "direct"` with an `api_key`
- **THEN** the app still transcribes through Hermes and does not keep or log the key
