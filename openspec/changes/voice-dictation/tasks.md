# Tasks

Two stacked PRs, each about 500 changed lines or fewer: `feat(voice): transcribe speech through Hermes` (groups 1 and 2) and `feat(chat): dictate into the composer` (groups 3 to 5). No OpenAPI change: every REST route is already in `openapi/hermes-agent.openapi.json` and the generated client.

## 1. Capture and transcription

- [x] 1.1 Add `record` to `pubspec.yaml`, run `flutter pub get`, and verify `flutter build macos --debug` still links
- [x] 1.2 Write failing tests for a binary dashboard socket (ticket when gated, token otherwise, `profile` in the query, path `/api/audio/transcribe-stream`), then extend `gateway/gateway_connection.dart` until they pass
- [x] 1.3 Write failing tests for `TranscribeStream` against a fake `StreamChannel`: sample-rate frame first, PCM buffered until open, `eos` on finish, partial/final/error frames, close without `eos` on cancel, 5 s open timeout. Build `lib/src/voice/transcribe_stream.dart` until they pass
- [x] 1.4 Write failing tests for the WAV wrapper (header fields for 16 kHz mono 16-bit, data length) and the `voice-config` parser (usable unless the request fails, 404, or `stt.reason` is `stt disabled` or `no credentials`; reads `stt.streaming`; ignores `api_key`), then build them in `lib/src/voice/`

## 2. Dictation controller

- [x] 2.1 Write failing tests for `DictationController` with a fake recorder, a fake stream and `FakeHermesServer`: permission denied, live final transcript, error frame falls back to `POST /api/audio/transcribe` with a `data:audio/wav;base64,` body, empty final falls back, empty upload gives "No speech detected", upload failure keeps the clip for retry, cancel discards, 5-minute limit stops, stt-lease acquired and released and its failure ignored. Build `lib/src/voice/dictation_controller.dart` until they pass
- [x] 2.2 Add the breadcrumbs `voice.dictation.started` and `voice.dictation.ended` (`outcome`, `path`) through `Breadcrumbs`, with a test that no transcript text reaches the trail

## 3. Composer UI in the catalog

- [ ] 3.1 Write failing widget tests for `VoiceWaveform` (recording: bars follow the level, dot and timer; settling: "Transcribing") and for `ChatComposer` with a `DictationView`: mic hidden without one, mic beside send, waveform replaces the field and stop replaces the mic while recording, cancel, send unavailable until the transcript lands, live transcript over the waveform, error with Retry, "No speech detected", denied message. Build them until the tests pass
- [ ] 3.2 Add Widgetbook use cases for each of those states (component-catalog skill) and verify `test/widgetbook_test.dart` passes in both themes at phone and desktop width

## 4. Wiring and platforms

- [ ] 4.1 Write a failing chat-screen test: mic appears when `voice-config` answers 200 and not on 404, and a transcript is inserted at the cursor with a single space and not sent. Wire `DictationController` into `ChatScreen` and `buildChatComposer` (profile switch, dispose and backgrounding cancel) until it passes
- [ ] 4.2 Add `NSMicrophoneUsageDescription` to the iOS and macOS `Info.plist`, `com.apple.security.device.audio-input` to both macOS entitlement files, `RECORD_AUDIO` to the Android manifest, and `pulseaudio-utils` to the `.deb` `Depends` in `scripts/package-linux.sh`; verify with `plutil -lint` and a Linux package build in CI
- [ ] 4.3 Hide the mic in macOS conversation windows, and verify the window engine starts without the `record` plugin registered
- [ ] 4.4 Add a step to the chat workflow test (`test/workflows/`) that dictates with a fake recorder, and check its screenshots (workflow-screenshots skill)

## 5. Docs and verification

- [ ] 5.1 Add the voice routes to `test/real_backend_contract_test.dart` (`voice-config` shape, `transcribe` with a short WAV of silence returning an empty transcript)
- [ ] 5.2 Update `CLAUDE.md` (a Voice paragraph and the Chat composer line) and the `verify-in-app` skill with how to dictate on the macOS dev app (microphone permission prompt, a dev backend's STT provider)
- [ ] 5.3 Run `dart format --output=none --set-exit-if-changed .`, `flutter analyze` and `flutter test`, then dictate a prompt in the running macOS app against `scripts/dev-backend.sh` with the `verify-in-app` skill
