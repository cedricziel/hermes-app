# Spec Delta

## ADDED Requirements

### Requirement: Dictation engine setting

On iOS and macOS the app SHALL offer a Dictation setting, reached from the app's settings, with two engines: "Hermes", which transcribes on the chat profile's server, and "On this device", which transcribes with the operating system's on-device recognizer. On iOS and macOS "On this device" SHALL be the default; a choice the user made SHALL win over the default. The choice SHALL apply to every profile and server and SHALL be kept across launches. When the device language or the device cannot recognize on the device, dictation SHALL use the Hermes engine and the setting SHALL show Hermes as the engine in use. On other platforms the app SHALL NOT show the setting and SHALL use the Hermes engine. The setting SHALL say that with "On this device" speech does not leave the device.

#### Scenario: Default engine

- **WHEN** the user has never changed the Dictation setting on an iPhone whose language can be recognized on the device
- **THEN** dictation uses the on-device recognizer

#### Scenario: Default without on-device support

- **WHEN** the user has never changed the Dictation setting and the device language has no on-device recognition
- **THEN** dictation uses the Hermes engine, and the setting shows Hermes as the engine in use

#### Scenario: Choice kept over the default

- **WHEN** the user picked "Hermes" in the Dictation setting
- **THEN** dictation uses the Hermes engine after a restart

#### Scenario: Choice kept

- **WHEN** the user picks "On this device" and restarts the app
- **THEN** the Dictation setting still shows "On this device" and dictation uses the on-device recognizer

#### Scenario: Platform without on-device recognition

- **WHEN** the app runs on Windows, Linux or Android
- **THEN** the settings offer no Dictation entry and dictation uses the Hermes engine

### Requirement: On-device speech model

The on-device engine SHALL recognize speech in the language the device's settings prefer. While the on-device engine is chosen and the model is not downloaded, the chat screen SHALL start the download by itself, without asking. The setting SHALL show the model's state for that language: not supported on this device (the language, or the device's hardware, cannot recognize on the device), not downloaded, downloading with progress, or ready. Picking "On this device" while the model is not downloaded SHALL start the download. A failed download SHALL be shown with a way to try again. A download SHALL go on when the dialog closes or the app goes to the background, and SHALL show its progress again when the dialog reopens. When the language or device is not supported, the setting SHALL say so and dictation SHALL stay on Hermes.

#### Scenario: Model download

- **WHEN** the user picks "On this device" and the model for the device language is not downloaded
- **THEN** the setting shows the download's progress, and the engine is ready once it finishes

#### Scenario: Dialog reopened during a download

- **WHEN** the user closes the Dictation setting during a download and opens it again
- **THEN** the setting shows the download still in progress

#### Scenario: Unsupported language or device

- **WHEN** the user picks "On this device" and the device language or hardware has no on-device recognition
- **THEN** the setting says it is not supported on this device, and dictation stays on Hermes

### Requirement: On-device recognition

With the on-device engine, the app SHALL record as described in "Recording state", feed the recording to the on-device recognizer while the user speaks, and show the recognizer's latest text in the text field at the cursor, as described in "Recording state". On stop, the recognizer's final text SHALL be the transcript and SHALL be inserted as described in "Inserting the transcript". Cancel SHALL discard the recognizer's text. When recording starts, the app SHALL check the model again; if it is no longer ready (the system may remove an unused model), the app SHALL NOT record and SHALL show that the speech model needs downloading in the Dictation setting. When the recognizer fails, the app SHALL leave the draft unchanged and show the failure without Retry, and SHALL NOT keep the recording.

#### Scenario: Text while speaking

- **WHEN** the user speaks during an on-device recording
- **THEN** the recognized text appears in the text field at the cursor while the user speaks

#### Scenario: Transcript inserted

- **WHEN** the user taps stop and the recognizer's final text is "book a table for two"
- **THEN** that text is inserted into the draft at the cursor and nothing is sent

#### Scenario: Recognizer fails

- **WHEN** the on-device recognizer reports an error
- **THEN** the draft is unchanged and the composer shows the error with Dismiss and no Retry

#### Scenario: Model removed since the last check

- **WHEN** the user taps the microphone and the device language's model is no longer installed
- **THEN** no recording starts and the composer says the speech model needs downloading in the Dictation setting

### Requirement: Engine shown while recording

While recording, the composer's controls row SHALL say which engine turns the speech into text: "On this device" or "Hermes"; while transcribing it SHALL say "Transcribing" instead. Where the row is too narrow, the name MAY be left out before any control is.

#### Scenario: Recording on the device

- **WHEN** the user records with the on-device engine
- **THEN** the controls row says "On this device"

#### Scenario: Recording through Hermes

- **WHEN** the user records with the Hermes engine
- **THEN** the controls row says "Hermes"

### Requirement: Changing the engine

When the engine changes, the app SHALL cancel a recording or a transcription in progress, as if the user had tapped cancel, and SHALL drop any recording kept for Retry. A recording SHALL only ever be transcribed by the engine that was chosen when it started.

#### Scenario: Engine changed while recording

- **WHEN** the user switches from "On this device" to "Hermes" during a recording (for example from the Mac settings window)
- **THEN** the recording is discarded, the draft is unchanged, and nothing is sent to the Hermes server

#### Scenario: Engine changed with a failed Hermes transcription

- **WHEN** a Hermes transcription failed and shows Retry, and the user switches to "On this device"
- **THEN** the failure notice and the kept recording are gone

### Requirement: On-device dictation stays on the device

With the on-device engine, the app SHALL NOT send the recording, any part of it or its text anywhere, and SHALL NOT call any `/api/audio/` route. The transcript SHALL leave the device only when the user sends the draft. Errors the recognizer reports SHALL reach logs and telemetry only as fixed codes, never as text the recognizer produced.

#### Scenario: No audio requests

- **WHEN** the user dictates with the on-device engine
- **THEN** the app makes no request to `/api/audio/voice-config`, `/api/audio/transcribe`, `/api/audio/transcribe-stream` or `/api/audio/stt-lease`

### Requirement: Send while dictating

The send button, and Enter on a hardware keyboard, SHALL stay available while recording and while transcribing. Using it SHALL stop the recording and, once the transcript lands, send the draft with the transcript in place, with any attachments. When nothing was heard, it SHALL send the draft as it was. When transcription fails, the dictation is cancelled (by the user, the app leaving the foreground, a profile or engine change), or the user opened another chat meanwhile, the app SHALL send nothing. Anything else that writes the draft while dictating, such as Edit on a sent prompt, SHALL win: the dictation is dropped and that text stays.

#### Scenario: Send ends the recording

- **WHEN** the user taps send while recording and the transcript "book a table" lands for the draft "Please"
- **THEN** the app sends "Please book a table"

#### Scenario: Cancel after send

- **WHEN** the user taps send while recording and then cancel before the transcript lands
- **THEN** nothing is sent and the draft reads as it did before recording

#### Scenario: Another chat opened meanwhile

- **WHEN** the user taps send while recording and opens another chat before the transcript lands
- **THEN** nothing is sent

#### Scenario: Send after a failed transcription

- **WHEN** the user taps send while recording and transcription fails
- **THEN** nothing is sent and the composer shows the failure

## MODIFIED Requirements

### Requirement: Recording state

While recording, the composer SHALL keep the text field, read-only, holding the draft with the text recognized so far at the cursor, separated from the draft by a single space. Where the engine gives no text until the end, the field SHALL show the draft unchanged. The row below the field SHALL show a cancel button ("Cancel voice input"), a live waveform that follows the input level after a pulsing recording dot, the engine's name, a stop button ("Stop voice input") and the send button, in place of attach, the model picker and the microphone. Cancel SHALL discard the recording and give the draft back as it was before recording. After stop, the waveform SHALL dim and say "Transcribing" until the transcript lands, and the field SHALL then become editable again with the transcript in place. Recording SHALL stop by itself after 5 minutes, as if the user had tapped stop.

#### Scenario: Recording in progress

- **WHEN** the user has started a recording
- **THEN** the text field stays visible and the row below it shows cancel, the waveform, the engine's name, stop and send

#### Scenario: Cancel gives the draft back

- **WHEN** the draft was "Please", text was recognized while recording, and the user taps cancel
- **THEN** the field reads "Please" again

#### Scenario: Settling

- **WHEN** the user taps stop
- **THEN** the waveform says "Transcribing" until the transcript is in the field, and then the field is editable again

#### Scenario: Time limit

- **WHEN** a recording reaches 5 minutes
- **THEN** recording stops and the transcript is fetched as if the user had tapped stop

### Requirement: Microphone button availability

The composer SHALL show a microphone button ("Dictate" for assistive technologies) in its bottom row, beside send, only when the chosen engine can transcribe for the chat. With the on-device engine that is when the device language's speech model is ready, whatever the profile's server reports. With the Hermes engine that is when the chat's profile has a usable speech-to-text provider: the app SHALL read `GET /api/audio/voice-config?profile=<profile>` and treat speech-to-text as unusable when the request fails, the server answers 404, or `stt.reason` is `stt disabled` or `no credentials`. Any other answer, including a relay to a local provider, SHALL count as usable. The app SHALL check again when the profile changes, when the engine changes, when the app reconnects and when it returns to the foreground. While dictation is unavailable the composer SHALL look exactly as it does without this feature.

#### Scenario: Profile has a speech-to-text provider

- **WHEN** the Hermes engine is chosen, the chat screen opens for a profile and `voice-config` answers 200 with `stt.mode` `relay` and `stt.reason` `local provider`
- **THEN** the composer shows the microphone button

#### Scenario: Speech-to-text turned off

- **WHEN** the Hermes engine is chosen and `voice-config` answers with `stt.reason` `stt disabled`
- **THEN** the composer shows no microphone button

#### Scenario: Older server without voice routes

- **WHEN** the Hermes engine is chosen and `GET /api/audio/voice-config` answers 404
- **THEN** the composer shows no microphone button and the rest of the composer is unchanged

#### Scenario: On-device engine without a server provider

- **WHEN** the on-device engine is chosen, its model is installed, and the profile's `voice-config` reports `stt disabled`
- **THEN** the composer shows the microphone button

#### Scenario: On-device model missing

- **WHEN** the on-device engine is chosen and the device language's model is not installed
- **THEN** the composer shows no microphone button

### Requirement: Live transcription

With the Hermes engine, when `voice-config` reports `stt.streaming: true`, the app SHALL open the `/api/audio/transcribe-stream` socket (with the dashboard-socket credential and `profile`) when recording starts, send `{"sample_rate": N}` with N between 8000 and 48000, then binary 16-bit little-endian mono PCM frames while the user speaks, and `{"eos": true}` when the user taps stop. It SHALL show the latest `{"type":"partial","text":…}` frame's text in the text field at the cursor, as described in "Recording state", and SHALL take `{"type":"final","transcript":…}` as the result. Cancel SHALL close the socket without sending `eos`.

#### Scenario: Partial text while speaking

- **WHEN** the server sends a partial frame during a recording
- **THEN** the partial text appears in the text field at the cursor

#### Scenario: Final transcript

- **WHEN** the user taps stop and the server sends a final frame with a non-empty transcript
- **THEN** the partial text in the field is replaced by the transcript

#### Scenario: Cancel during live transcription

- **WHEN** the user taps cancel while the socket is open
- **THEN** the app closes the socket without sending `eos`, removes the partial text and leaves the draft as it was before recording

### Requirement: Upload fallback

With the Hermes engine, the app SHALL keep the whole recording in memory while recording and SHALL transcribe it with `POST /api/audio/transcribe?profile=<profile>`, body `{"data_url": "data:audio/wav;base64,<…>", "mime_type": "audio/wav"}`, when live transcription was not offered, the socket could not open within 5 seconds, the server sent an `error` frame, the socket closed before a final frame, or the final transcript was empty. While the upload runs the composer SHALL show that it is transcribing. The response's `transcript` field is the result.

#### Scenario: No live transcription for the provider

- **WHEN** the transcribe-stream socket answers `{"type":"error",…}` right after opening
- **THEN** the app keeps recording and, on stop, uploads the recording and inserts the returned transcript

#### Scenario: Socket drops mid-recording

- **WHEN** the socket closes during a recording
- **THEN** recording continues and the recording is uploaded on stop

### Requirement: Speech-to-text warm-up

With the Hermes engine, when recording starts the app SHALL send `POST /api/audio/stt-lease?profile=<profile>` with `{"lease": "app:voice-input:<id>", "active": true}`, where `<id>` is random per app run, and SHALL send the same lease with `"active": false` when the transcript settles, the recording is cancelled or the chat screen goes away. A failed lease request SHALL NOT affect recording or transcription.

#### Scenario: Lease fails

- **WHEN** the stt-lease request fails
- **THEN** recording and transcription proceed as normal

### Requirement: Inserting the transcript

The app SHALL insert a non-empty transcript at the cursor of the draft (at its end when the field had no cursor), separated from adjacent text by a single space, and SHALL NOT send it. An empty transcript SHALL leave the draft unchanged and show "No speech detected"; with the on-device engine an empty result SHALL NOT fall back to an upload. A failed Hermes transcription SHALL leave the draft unchanged and show the failure with a retry for the kept recording until the next recording starts, the engine changes or the user dismisses it. A failed on-device transcription is described in "On-device recognition".

#### Scenario: Transcript inserted, not sent

- **WHEN** the transcript "book a table for two" arrives and the draft is "Please"
- **THEN** the draft reads "Please book a table for two" and nothing is sent

#### Scenario: Silence

- **WHEN** the Hermes engine's transcript comes back empty from both paths
- **THEN** the draft is unchanged and the composer shows "No speech detected"

#### Scenario: Silence on the device

- **WHEN** the on-device recognizer's final text is empty
- **THEN** the draft is unchanged, the composer shows "No speech detected", and no upload is made

#### Scenario: Transcription fails

- **WHEN** `POST /api/audio/transcribe` answers with an error status
- **THEN** the draft is unchanged and the composer shows the error with Retry

### Requirement: Backend contract

With the Hermes engine, dictation SHALL rely only on these Hermes Agent routes. With the on-device engine it SHALL use no Hermes route. `voice-config` and `transcribe` are present since Hermes v2026.9.11, and `transcribe-stream` and `stt-lease` since v0.21.6. On an older server dictation SHALL still work by uploading, and SHALL ignore the missing lease route. The routes: `GET /api/audio/voice-config` (`{ok, stt: {mode, streaming?, …}, tts: {…}}`; only `stt.reason` and `stt.streaming` are read), the `/api/audio/transcribe-stream` WebSocket (protocol above, authenticated like `/api/ws` with `ticket` or `token`, closed with 4401 or 4403 when rejected), `POST /api/audio/transcribe` (`{ok, transcript, provider}`; 400 for empty or malformed audio, 413 above 25 MiB) and `POST /api/audio/stt-lease` (`{ok, lease, active, …}`). The app SHALL NOT use the client-direct provider settings or keys that `voice-config` may return.

#### Scenario: Server before v0.21.6

- **WHEN** the transcribe-stream socket is refused and `stt-lease` answers 405
- **THEN** the recording is uploaded on stop and its transcript inserted

#### Scenario: Provider keys ignored

- **WHEN** `voice-config` returns `stt.mode: "direct"` with an `api_key`
- **THEN** the app still transcribes through Hermes and does not keep or log the key
