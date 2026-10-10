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

- [x] 2.1 Write failing tests for `DictationSettings`: default `hermes`, persisted choice, and an edit during `load` winning. Implement it and provide it with the app-wide `OnDeviceSpeech` in `main.dart`.
- [x] 2.2 Write failing `DictationController` tests with a fake `OnDeviceSpeech` and `FakeHermesServer`. For the device engine:
  - partials become `liveTranscript`;
  - the final text is inserted;
  - empty final text gives `noSpeech` with no upload;
  - an error gives `failed` with no Retry and no kept clip;
  - a model gone at `start` gives `modelMissing` without recording;
  - cancel discards the text;
  - the fake server sees no `/api/audio/` request;
  - `available` follows the model status.

  For engine changes, a change mid-recording cancels with no request to Hermes, and a change after a failed Hermes transcription drops the kept clip. The Hermes engine is otherwise unchanged. Implement the engine in the controller until they pass.

- [x] 2.3 Write failing assertions for the breadcrumbs: `engine` on `voice.dictation.started` and `voice.dictation.ended`, `path: device` on settle, None may carry text, locale or a native message. Then add them. The `voice.model.install` outcome moved to 3.2, where the install runs. These are this change's only telemetry.

## 3. PR 3: `feat(voice): choose on-device dictation`

- [x] 3.1 Build the Dictation settings dialog as a plain-model widget in `lib/src/voice/widgets/`, plus the composer's "model missing" notice. Add Widgetbook use cases in `widgetbook/voice_use_cases.dart`, each in both themes at phone and desktop width:
  - Hermes chosen;
  - device ready;
  - model not downloaded;
  - downloading;
  - download failed;
  - unsupported;
  - the composer's model-missing notice.

  Verify with `flutter test test/widgetbook_test.dart`.

- [x] 3.2 Write a failing widget test, then wire the dialog. Add "Dictation…" to `settings_dialog.dart` and the account menu on iOS and macOS only, hidden elsewhere. Connect it to `DictationSettings` and to `OnDeviceSpeech` status and install, including reopening during a download. Record the install's outcome as `voice.model.install` (outcome only), starting with a failing assertion.
- [x] 3.3 Write a failing `ChatScreen` test: with the device engine and a ready model, the microphone shows while `voice-config` reports `stt disabled`; with the model missing it is hidden. Then make `ChatScreen` skip `voice-config` for the device engine and recheck on profile change, engine change and resume.
- [x] 3.4 Update `CLAUDE.md`'s Voice paragraph, and the `verify-in-app` skill with the permission and model-download steps the dev app needs. At archive time, update the voice-dictation spec's Purpose, which today names only Hermes' transcript.
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

## 4. PR 4: `feat(voice): dictate on the device by default`

On a TestFlight iPhone, dictation still went to Hermes: the engine defaulted to Hermes and the switch is two menus deep. Nothing showed which engine was listening.

- [x] 4.1 Write failing `DictationSettings` tests: the default is `device` on iOS and macOS and `hermes` elsewhere, and a saved choice wins. Implement them.
- [x] 4.2 Write failing `ChatScreen` tests:
  - an unsupported model falls back to Hermes and reads `voice-config`;
  - a missing model is downloaded without a tap, then the microphone shows;
  - a failed download leaves the microphone hidden.

  Implement them.
- [x] 4.3 Write failing dialog tests: an early tap on On this device is kept and downloads once the model state is known, and an unsupported model shows Hermes as the checked engine. Implement them.
- [x] 4.4 Add the engine label to `VoiceWaveform` with Widgetbook use cases (On this device, Hermes), then pass it from the composer. Verify with the widget and Widgetbook tests.
- [x] 4.5 Update `CLAUDE.md`'s Voice paragraph for the new default. Then run `dart format`, `flutter analyze`, `flutter test` and `openspec validate on-device-dictation --strict`.

## 5. PR 5: `feat(voice): dictate into the field, with send in the controls row`

As in the Claude app: the words appear in the field as they are recognized, and one row below the field holds cancel, the waveform with the engine's name, stop and send. Send works while dictating.

- [x] 5.1 Write failing tests for a pure `DictationDraft` (`lib/src/voice/`) that holds the draft at the start of a recording: it shows recognized text at the cursor with single-space separation, puts the final transcript in its place, and gives the draft back on cancel or failure. Implement it, and move `ChatScreen._insertTranscript`'s spacing rule into it.
- [x] 5.2 Rework `VoiceWaveform` into the controls row's middle: recording dot, bars and the engine's name, or "Transcribing…" while settling. It has no live text and no clock. Update its Widgetbook use cases and tests (phone width).
- [x] 5.3 Rework the composer's dictation layout as a plain-model change with Widgetbook use cases for recording and settling, each with a draft:
  - the field stays and is read-only while dictating;
  - the row shows cancel, waveform, stop and send;
  - send is enabled while dictating and calls a new `DictationView.onSend`.
- [x] 5.4 Write failing `ChatScreen` tests:
  - partials appear in the field at the cursor;
  - cancel gives the draft back;
  - send while recording sends the draft with the transcript;
  - send after a failed transcription sends nothing.

  Wire `DictationDraft` and send-while-dictating into `ChatScreen` until they pass.
- [x] 5.5 Update `CLAUDE.md`'s Voice paragraph. Run `dart format`, `flutter analyze`, `flutter test` and `openspec validate on-device-dictation --strict`, and render the composer states on a phone width.

