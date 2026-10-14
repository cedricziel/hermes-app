# Proposal

## Why

Dictation always sends the recording to the Hermes server. That only works when the profile has a speech-to-text provider, shows no text while the user speaks unless that provider streams, and needs a connection. iPhones and Macs ship a speech recognizer that runs entirely on the device, gives text as the user speaks and needs no Hermes provider. The app already requires iOS 26 and macOS 26, where Apple's newest recognizer (`SpeechAnalyzer`) exists; whether a given device and language can use it is checked at runtime.

## What Changes

- A new **Dictation** setting with two engines: **Hermes** (today's behaviour, the default) and **On this device** (iOS and macOS only).
- With On this device, the composer's microphone records as before, the recognizer's text appears as the live transcript while the user speaks, and the final text goes into the draft at the cursor. Nothing is sent.
- With On this device, no audio and no request go to the Hermes server: no `voice-config`, no `transcribe-stream`, no `transcribe` upload, no `stt-lease`. The microphone button shows whenever the device's speech model for the user's language is ready, even when the profile has no speech-to-text provider.
- The recognizer works in the language the device's settings prefer. When that language's speech model is not on the device, the Dictation setting downloads it from Apple, with progress, and the composer hides the microphone until it is ready. If the system removed the model since the last check, tapping the microphone says so instead of recording.
- Changing the engine cancels a dictation in progress, so a recording is only ever transcribed by the engine chosen when it started.
- A failed on-device transcription shows the error without Retry, and no recording is kept for it.
- The setting is offered only on iOS and macOS. Elsewhere dictation stays on Hermes and the setting does not appear.

## Non-goals

- Android. Its on-device recognizer is a separate follow-up change (`createOnDeviceSpeechRecognizer` with app-supplied audio, API 33+).
- Windows and Linux. A downloadable model (sherpa-onnx) is a possible later change. Whisper-style engines are ruled out: they don't stream and are heavy on battery.
- Using the on-device text as a preview for the Hermes engine. Each engine produces its own transcript.
- A language picker. The device language is used. If it has no on-device model, the engine reports that it is unavailable.
- Falling back to Hermes when on-device recognition fails. The user switches engines in settings.
- Dictation in conversation windows, which still have none.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `voice-dictation`: adds the engine setting and the on-device engine, and changes when the microphone button is available. Live transcription, upload fallback and warm-up become Hermes-engine only.

## Impact

- Code: `lib/src/voice/` (an engine choice, and the Dart wrapper of the recognizer with its tests in `test/voice/`), the chat screen's dictation wiring, a new Dictation settings dialog listed in the settings dialog and the account menu, and the Widgetbook voice use cases.
- Native: a new local Flutter plugin, `packages/hermes_speech` (iOS and macOS, one shared Swift source with a Swift package manifest), on `SpeechAnalyzer`/`SpeechTranscriber` behind a `hermes_app/speech` channel. Registration goes through the generated plugin registrants, so the tracked `GeneratedPluginRegistrant` files change, but the runners' Xcode projects do not. The speech-recognition usage description goes in both `Info.plist`s if the framework asks for it.
- Dependencies: the local path package above, and no new pub.dev package. `record` keeps owning the microphone.
- Dictation still needs a signed-in chat screen. Recognition itself needs no server, but nothing here makes the chat usable offline.
- Backend: none. The on-device engine calls no Hermes route.
- Security and privacy: with On this device, the user's speech never leaves the device. Apple downloads the language model, and no audio goes with that download. The engine choice is kept in shared preferences. No tokens are touched.
- Telemetry: the existing `voice.dictation.started` and `voice.dictation.ended` breadcrumbs get an `engine` attribute (`hermes` or `device`), and `ended` gets `path: device`. A new `voice.model.install` breadcrumb records only the download's outcome. Never any text, locale or recognizer error message: native errors reach Dart as fixed codes.
- Size: more than one PR. The tasks ship it as three PRs: the plugin and its wrapper, then the engine and setting, then the UI. Each is reviewable alone, and the first two change nothing a user sees.
