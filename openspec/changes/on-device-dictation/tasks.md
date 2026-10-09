# Tasks

## 1. PR 1: `feat(voice): on-device speech recognizer plugin`

- [x] 1.1 Spike on an iOS 26 device and macOS 26 (Release sandbox included) and record the answers in design.md's risks:
  - Does `SpeechTranscriber` need speech-recognition authorization?
  - Does `PlatformDispatcher.instance.locale` resolve through `supportedLocale(equivalentTo:)` on a non-English device?
  - Does the model download work under the sandbox?
  - Which audio converter works?

  If authorization is needed, add `NSSpeechRecognitionUsageDescription` to both `Info.plist`s.

- [x] 1.2 Create the local plugin `packages/hermes_speech`: iOS and macOS only, `sharedDarwinSource: true`, `darwin/hermes_speech/Package.swift` with iOS 26 and macOS 26 platforms. Add it to `pubspec.yaml` as a path dependency. Verify that `flutter build macos --debug` and the iOS simulator build register it. Commit the regenerated `GeneratedPluginRegistrant` files and restore the other tracked `ios/` and `macos/` files the build rewrites.
- [x] 1.3 Extract a `LiveTranscriber` interface (`add`, `partials`, `finish`, `cancel`) from `TranscribeStream`. Pure refactor, so verify by running `test/voice/` unchanged.
- [x] 1.4 Write failing tests in `test/voice/on_device_speech_test.dart` for `OnDeviceSpeech` (in `lib/src/voice/`) against a mocked `hermes_app/speech` method and event channel:
  - the four statuses;
  - `install` progress and failure codes;
  - a session's `add`, `partials`, `finish`, `cancel` and error code;
  - events for another session id ignored;
  - two listeners (session and install progress) at once over a single channel subscription.

  Implement it as a `LiveTranscriber` until they pass.

- [x] 1.5 Implement the Swift side as in design.md, "Native recognition and session lifecycle":
  - availability and the `AssetInventory` status mapping;
  - install with progress;
  - conversion to `bestAvailableAudioFormat(compatibleWith:)`;
  - volatile plus finalized live text;
  - `finish` draining results;
  - `cancel` with `cancelAndFinishNow()`;
  - one session at a time;
  - teardown on detach;
  - error codes only.

  Verify on macOS with the dev app or a throwaway harness that speaking produces partial and final text and that a cancel mid-sentence leaves no session running.

## 2. PR 2: `feat(voice): on-device dictation engine`

- [ ] 2.1 Write failing tests for `DictationSettings`: default `hermes`, persisted choice, and an edit during `load` winning. Implement it and provide it with the app-wide `OnDeviceSpeech` in `main.dart`.
- [ ] 2.2 Write failing `DictationController` tests with a fake `OnDeviceSpeech` and `FakeHermesServer`. For the device engine:
  - partials become `liveTranscript`;
  - the final text is inserted;
  - empty final text gives `noSpeech` with no upload;
  - an error gives `failed` with no Retry and no kept clip;
  - a model gone at `start` gives `modelMissing` without recording;
  - cancel discards the text;
  - the fake server sees no `/api/audio/` request;
  - `available` follows the model status.

  For engine changes, a change mid-recording cancels with no request to Hermes, and a change after a failed Hermes transcription drops the kept clip. The Hermes engine is otherwise unchanged. Implement the engine in the controller until they pass.

- [ ] 2.3 Write failing assertions for the breadcrumbs: `engine` on `voice.dictation.started` and `voice.dictation.ended`, `path: device` on settle, and the `voice.model.install` outcome. None may carry text, locale or a native message. Then add them. These are this change's only telemetry.

## 3. PR 3: `feat(voice): choose on-device dictation`

- [ ] 3.1 Build the Dictation settings dialog as a plain-model widget in `lib/src/voice/widgets/`, plus the composer's "model missing" notice. Add Widgetbook use cases in `widgetbook/voice_use_cases.dart`, each in both themes at phone and desktop width:
  - Hermes chosen;
  - device ready;
  - model not downloaded;
  - downloading;
  - download failed;
  - unsupported;
  - the composer's model-missing notice.

  Verify with `flutter test test/widgetbook_test.dart`.

- [ ] 3.2 Write a failing widget test, then wire the dialog. Add "Dictation…" to `settings_dialog.dart` and the account menu on iOS and macOS only, hidden elsewhere. Connect it to `DictationSettings` and to `OnDeviceSpeech` status and install, including reopening during a download.
- [ ] 3.3 Write a failing `ChatScreen` test: with the device engine and a ready model, the microphone shows while `voice-config` reports `stt disabled`; with the model missing it is hidden. Then make `ChatScreen` skip `voice-config` for the device engine and recheck on profile change, engine change and resume.
- [ ] 3.4 Update `CLAUDE.md`'s Voice paragraph, and the `verify-in-app` skill with the permission and model-download steps the dev app needs. At archive time, update the voice-dictation spec's Purpose, which today names only Hermes' transcript.
- [ ] 3.5 Verify all of these:
  - `dart format --output=none --set-exit-if-changed .`, `flutter analyze` and `flutter test` are green.
  - `verify-in-app` on macOS:
    - pick "On this device" and download the model;
    - dictate a sentence;
    - screenshot the live transcript and the inserted draft;
    - confirm the dev backend's log shows no `/api/audio/` request.
  - On an iOS device:
    - whether `SpeechTranscriber` asks for speech-recognition authorization (carried over from 1.1; the simulator has no on-device recognizer). If it does, add `NSSpeechRecognitionUsageDescription` to `ios/Runner/Info.plist`, request authorization in `start` and report a denial like a denied microphone;
    - the permission prompts;
    - backgrounding during a recording cancels it;
    - backgrounding during a download resumes its progress when the dialog reopens.
