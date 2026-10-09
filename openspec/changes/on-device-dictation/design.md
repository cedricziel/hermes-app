# Design

## Context

Dictation lives in `lib/src/voice/`. `DictationController` records 16 kHz mono PCM through `VoiceRecorder` (the `record` plugin), feeds it to a `TranscribeStream` when the profile's server streams, keeps the whole clip, and uploads it on stop when the stream gave nothing. Partial text goes to `liveTranscript`, which the waveform shows as provisional. `ChatScreen` builds the controller, but only when the chat has a repository, and configures it with each profile's `VoiceSupport` from `voice-config`. Conversation windows use `ConversationWindowScreen`, register their plugins by hand, and offer no dictation.

The iOS and macOS deployment targets are 26.0, so Apple's `SpeechAnalyzer` with the `SpeechTranscriber` module exists on every build. Whether it works on a given device and language is a runtime question: `SpeechTranscriber.isAvailable` depends on the hardware, and `AssetInventory` reports each language's model as `unsupported`, `supported` (downloadable), `downloading` or `installed`. The system may remove a model the app has not used in a while. The recognizer takes audio buffers from the app and reports volatile (provisional) and finalized results.

The runners hold only English localizations, so on iOS `Locale.current` can report English on a device set to another language. The locale comes from Dart (`PlatformDispatcher.instance.locale`, the user's preferred language) instead.

## Goals / Non-Goals

**Goals:**

- The on-device engine reuses everything the Hermes engine has around recognition: the recorder, waveform, 5-minute limit, cancel, the "Transcribing" state, insertion and the notices.
- One Swift source serves iOS and macOS.

**Non-Goals:**

- Android, Windows and Linux recognizers (see proposal). The Dart interface must not block them, but nothing is built for them.
- Custom vocabulary, punctuation settings or a language picker.
- Retry for the device engine. Device failures such as resource limits or a missing model tend to repeat, and keeping no clip makes "nothing is kept" simple to state.

## Decisions

### Feed our own PCM to `SpeechAnalyzer` through a small local plugin

The recognizer takes the PCM `record` already captures, instead of opening the microphone itself.

- **Alternatives:**
  - `speech_to_text` (7.5.0) opens its own audio engine. Its docs say it is aimed at commands and short phrases, not continuous dictation. On Apple it uses the older `SFSpeechRecognizer`.
  - `liquid_speech` wraps `SpeechAnalyzer`, but it is at 0.1.0 and also captures audio itself.
  - Either one would need a second recording path in the controller, with its own level meter, time limit and cancel.
- **Where the native side lives:** a local Flutter plugin, `packages/hermes_speech`.
  - It declares iOS and macOS with `sharedDarwinSource: true`, so one Swift source serves both.
  - The repo builds through Swift Package Manager (no Podfile), so the plugin ships `darwin/hermes_speech/Package.swift` with iOS 26 and macOS 26 platforms.
  - The generated registrants pick it up: iOS through `engineBridge.pluginRegistry`, the macOS main window through `RegisterGeneratedPlugins`. The tracked `GeneratedPluginRegistrant` files change and get committed. The runners' Xcode projects do not change.
  - Conversation windows register plugins by hand and leave it out.
- **Native code only:** the package holds the Swift code and a pubspec, nothing else. The Dart wrapper and its tests live in the app (`lib/src/voice/on_device_speech.dart`, `test/voice/`), so CI's test shards run them.
- **Dependency rule:** this follows the rule's "say why in the PR": no mature plugin accepts app-supplied audio.

### Channel shape

- **Method channel `hermes_app/speech`:**
  - `status(locale)` → `unsupported | missing | downloading | installed`. Native `supported` maps to `missing`. `unsupported` also covers `SpeechTranscriber.isAvailable == false`.
  - `install(locale)` → completes when installed, or fails with a code.
  - `start(locale, sampleRate)` → session id. It cancels any session still open first, since Apple limits concurrent analyses.
  - `append(id, bytes)`.
  - `finish(id)` → final text.
  - `cancel(id)`.
- **Event channel `hermes_app/speech/events`:**
  - `{id, type: partial, text}`
  - `{id, type: error, code}`
  - `{type: progress, fraction}`
- **Errors:** they are fixed codes (`unsupported`, `modelMissing`, `resources`, `failed`), never native message text.
- **Chunk size:** chunks arrive about every 100 ms (about 3.2 KB), which method calls handle without trouble.
- **One app-wide listener:** an event channel has a single native sink, so one `OnDeviceSpeech` is created in `main.dart` and provided app-wide. It holds the only subscription and fans events out on the Dart side, to sessions by id and to install progress.
- **Session interface:** a session has the same shape as `TranscribeStream`, behind a small `LiveTranscriber` interface (`add`, `partials`, `finish`, `cancel`) that both implement. The controller treats the two engines alike while recording.

### Native recognition and session lifecycle

- **Recognizer setup:**
  - A `SpeechTranscriber` for the locale Dart passed in, resolved through `supportedLocale(equivalentTo:)`, with volatile results on (a preset if one fits).
  - It runs inside a `SpeechAnalyzer` fed by an `AsyncStream<AnalyzerInput>`.
- **Audio conversion:** incoming Int16 16 kHz PCM is converted to the format from `bestAvailableAudioFormat(compatibleWith:)`. `AVAudioConverter` with its input-block API does it, and only when the formats differ. Apple's `AnalyzerInputConverter` needs OS 27.
- **Live text:** the finalized results so far, plus the latest volatile one.
- **`finish`:**
  1. Ends the input stream.
  2. Calls `finalizeAndFinishThroughEndOfInput()`.
  3. Drains `transcriber.results` to its end.
  4. Returns the joined finalized text.
- **`cancel`:** ends the input stream and calls `cancelAndFinishNow()`.
- **Teardown:** plugin detach (engine teardown, hot restart) cancels every open session.
- **Model status and install:** `status` and `install` use `AssetInventory.status(forModules:)` and `assetInstallationRequest(supporting:)` with `downloadAndInstall()`, and report the request's `Progress`.
  - A download outlives the dialog and app backgrounding. Reopening the dialog reads `downloading` and listens for progress again.

### Engine in the controller

- `DictationController` gets an `engine` (`hermes` or `device`) and the app-wide `OnDeviceSpeech`.
- **`start` with `device`:**
  - Rechecks the model. If it is no longer `installed`, it ends in a new `modelMissing` notice without recording.
  - Takes no lease, opens no Hermes stream and never uploads.
- **Settling with `device`:**
  - On stop, the session's final text settles the dictation. Empty text gives `noSpeech`.
  - An error ends the dictation as `failed` with no clip, so `canRetry` is false.
- **Changing the engine** cancels whatever is in progress and drops the kept clip. `configure` already does this for a profile change, and it now does it for an engine change too.
- **`available`** follows the model status for `device` and `VoiceSupport.speechToText` for `hermes`.
- **Breadcrumbs** get `engine`, and settling gets `path: device`.

### Setting

- **`DictationSettings`:** a `ChangeNotifier` on `SharedPreferencesAsync`, key `hermes.dictation_engine`. It sits beside `NotificationSettings` in `main.dart`.
- **`ChatScreen`:** listens to it. While the device engine is chosen, it skips `voice-config` and reads the model status on profile change, engine change and resume.
- **The menu entry:** "Dictation…" goes into the settings dialog and the account menu on iOS and macOS only.
- **The dialog:** it shows the two engines, a privacy line, the model state, download progress and Try again.
  - The dialog and the composer's new "model missing" notice are built as Widgetbook use cases first.
  - `voice.model.install` records the download's outcome.

### Invariants touched

- **Telemetry:** breadcrumbs only, never text, locale or native error messages.
- **API layering:** the device engine adds no route and makes no Hermes call.
- **Tests:** the Hermes path keeps running against `FakeHermesServer`. Device-engine tests use a fake `OnDeviceSpeech` and assert that the fake server saw no `/api/audio/` request.

### Platforms

- **iOS and macOS:** the new local plugin and the regenerated plugin registrants. No entitlement change: the microphone entitlement and `NSMicrophoneUsageDescription` exist already. The model download goes through the system, and the 1.1 spike confirms it works under the Release sandbox.
- **Android, Windows and Linux:** no change. The plugin declares only iOS and macOS, and the setting is hidden there.
- **watchOS:** none.

## Spike findings (macOS 27, Xcode 27, unsandboxed command-line build)

- Feeding 100 ms chunks of 16 kHz Int16 PCM to `SpeechAnalyzer` with the `.progressiveTranscription` preset produced word-by-word volatile results and one final result. The volatile text there was cumulative for the segment.
- `SFSpeechRecognizer.authorizationStatus()` stayed `notDetermined` throughout, so on macOS `SpeechTranscriber` needs no speech-recognition authorization. iOS is still unchecked: no device was at hand. 3.5 checks it on a device.
- `bestAvailableAudioFormat(compatibleWith:)` answered 16 kHz Int16 mono, the format `record` delivers. The converter only runs when the formats differ.
- `AnalyzerInputConverter` exists only from OS 27, so the 26 target uses `AVAudioConverter`.
- `supportedLocale(equivalentTo:)` mapped `de` to `de_CH` but `de-DE` to `de_DE`. Dart must pass the full locale tag with its region.
- `AssetInventory.status` answered `installed` for en-US and `supported` for de-DE. An unknown locale gave `nil`, which maps to `unsupported`. The model download and the Release sandbox were not exercised; 3.5 covers them.

Then in the app itself (macOS 27, sandboxed debug build, through `OnDeviceSpeech` and the plugin):

- Models are reserved per app. en-US, installed for the command-line spike, read as `supported` (so `missing`) for the app until the app asked for it. `install` then finished in 83 ms with no progress events, because the files were already on disk. Picking "On this device" therefore always runs `install`, and the dialog must not assume a progress event arrives.
- Partials, the final text, a cancel mid-recording followed by a clean new session, and `modelMissing` for a language not reserved all behaved as designed. There was no speech-permission prompt and no privacy crash without `NSSpeechRecognitionUsageDescription`.
- The iOS 26.5 simulator reports `SpeechTranscriber.isAvailable == false`, so every language reads `unsupported` there. The iOS authorization question needs a real device; 3.5 covers it.

## Risks / Trade-offs

- **[Risk]** `SpeechTranscriber` may need speech-recognition authorization on top of microphone access. Third-party sources say it does; Apple's pages are silent.
  - Mitigation: the 1.1 spike decides. If it is needed:
    - add `NSSpeechRecognitionUsageDescription` to both `Info.plist`s;
    - request authorization in `start`;
    - report a denial like a denied microphone;
    - add it to the "Microphone permission" requirement.
- **[Risk]** Volatile results can rewrite earlier words, so the provisional text jumps.
  - Mitigation: it is already styled as provisional, and only the final text is inserted.
- **[Risk]** The locale Dart reports may have no on-device model even when a close variant does.
  - Mitigation: `supportedLocale(equivalentTo:)` resolves to the nearest supported variant. With none, the state is `unsupported`.
- **[Trade-off]** The change is three PRs instead of one.
  - The plugin and wrapper ship first, unused. The engine and setting come next, with no UI. The UI comes last.
  - Splitting it into three OpenSpec changes would leave the first one with no behaviour to specify, so it stays one change.
- **[Trade-off]** No automatic fallback to Hermes when the device recognizer fails. It keeps the privacy promise simple: with "On this device", speech never goes anywhere else.

## Migration Plan

- The default engine is Hermes, so existing users see no change until they pick the device engine.
- Rollback is reverting the PRs. A stored `device` value is ignored by older builds.
