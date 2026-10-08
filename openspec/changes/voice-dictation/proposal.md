## Why

Typing a long prompt on a phone is slow, and Hermes already transcribes speech with the profile's own speech-to-text provider (`/api/audio/transcribe-stream`, `/api/audio/transcribe`), which the Hermes desktop app uses for dictation. The app has no way to talk to the agent yet. Dictation is the first half of voice input; the hands-free voice conversation follows in `voice-conversation`, which reuses the capture and the socket built here.

## What Changes

- The controls follow assistant-ui's dictation element (`ComposerPrimitive.Dictate`, `StopDictation`, `DictationTranscript`, the `ComposerVoice` waveform). A microphone button sits in the composer's bottom row, beside send. It is shown only when the profile has a usable speech-to-text provider, as reported by `GET /api/audio/voice-config`.
- Tapping it asks for microphone permission once, then records. While recording, the text field becomes a live waveform with a recording dot and the elapsed time, and the microphone button becomes a stop button. When the server can transcribe while the user speaks, the recognized text shows over the waveform as a provisional live transcript. Cancel discards the recording.
- Stop, or the 5-minute limit, settles the waveform into a "Transcribing" state. Then the text field returns with the transcript inserted at the cursor. Nothing is sent; the user reviews the text and sends it as usual.
- Live transcription streams 16-bit mono PCM over the `/api/audio/transcribe-stream` socket. When the server has no live transcription for the profile's provider, the socket fails or the result comes back empty, the app uploads the whole recording to `POST /api/audio/transcribe` instead.
- The app asks Hermes to warm the speech-to-text model when recording starts (`POST /api/audio/stt-lease`) and releases it afterwards; a failure there never blocks recording.
- Microphone permission on iOS, macOS and Android (usage strings, the macOS sandbox entitlement, the Android manifest permission).

## Capabilities

### New Capabilities

- `voice-dictation`: recording speech in the composer and turning it into draft text through Hermes' transcription routes.

### Modified Capabilities

None. The composer gains a button, but its existing requirements are unchanged.

## Impact

- Code: a dictation controller and an audio-socket helper under `lib/src/voice/`; a `ChatComposer` mic button and recording row; wiring in `chat_composer_builder.dart` and `ChatScreen`.
- Dependencies: `record` (microphone capture as a PCM stream on all five platforms).
- Native: `NSMicrophoneUsageDescription` in the iOS and macOS `Info.plist`, `com.apple.security.device.audio-input` in both macOS entitlement files, `RECORD_AUDIO` in the Android manifest, and the Linux package's runtime dependencies.
- API: the generated client already has every REST route (`voice-config`, `transcribe`, `stt-lease`). The two sockets are not in the OpenAPI spec and are opened with the existing dashboard-socket credential (ticket or token).
- Widgetbook: composer use cases for the idle microphone, recording (waveform), the live transcript, transcribing, and the error, empty and denied states.

## Non-goals

- The hands-free voice conversation, speaking replies aloud and barge-in (`voice-conversation`).
- GPT-Live (`voice.voice_chat_mode: gpt-live`, WebRTC).
- On-device speech recognition. Hermes' transcription keeps one engine per profile and works on Linux and Windows, where the platform recognizers are missing or weak.
- Client-direct transcription from `voice-config` (provider keys handed to the client). The relay routes work for every provider.
- Dictation anywhere but the chat composer (Kanban, schedules, search).
- Sending automatically when the transcript arrives.
- The Apple Watch app.

## Security and privacy impact

Microphone audio leaves the device only to the user's own Hermes server, over the same authenticated connection as chat; Hermes may pass it on to the speech-to-text provider configured for the profile. Audio is held in memory for the length of one recording and never written to disk or preferences. The audio socket is opened with the same single-use ticket or session token as the chat socket; no new credential is stored. The OS asks for microphone permission on first use, with a usage string that says the audio goes to the user's Hermes server.

## Telemetry

Breadcrumbs only, through `Breadcrumbs` (no exported log record): `voice.dictation.started` and `voice.dictation.ended` with `outcome` (`inserted`, `empty`, `cancelled`, `failed`, `denied`) and `path` (`stream`, `upload`). Never the transcript, audio, durations precise enough to identify a recording, or server addresses.
