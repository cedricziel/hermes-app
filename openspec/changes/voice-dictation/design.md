# Design

## Context

Hermes serves dictation for its desktop app from `hermes_cli/web_routers/audio.py`. `voice-config` says whether the profile's provider can transcribe live (`stt.streaming`). The `transcribe-stream` socket takes a sample-rate frame, binary PCM and `eos`, and answers with partials and a final transcript. It sends an `error` frame straight away when the provider has no live mode; the desktop then uploads its recording as a data URL to `POST /api/audio/transcribe`. `stt-lease` only pre-loads a local Whisper model. `voice-config` and `transcribe` exist since Hermes v2026.9.11; `transcribe-stream` and `stt-lease` came in v0.21.6, so on an older server the socket is refused (the app uploads) and the lease answers 405 (ignored). The generated client already has the REST calls.

The app opens dashboard sockets with `hermesSocketConnect` (`gateway/gateway_connection.dart`): a single-use `ticket` from `/api/auth/ws-ticket` when the dashboard is gated, otherwise the page's session `token`. The audio sockets accept the same credentials. That helper returns a `StreamChannel<String>`, but dictation has to send binary frames.

The composer is `ChatComposer` (`chat/widgets/chat_composer.dart`), a plain widget taking callbacks, built by `buildChatComposer`.

## Goals / Non-Goals

**Goals:**

- One capture and socket layer that `voice-conversation` can reuse for its listening turns.
- The composer stays a plain-model widget, so every dictation state can be shown in Widgetbook.

**Non-Goals:**

- Resampling, client voice-activity detection, echo cancellation. Those belong to `voice-conversation`.
- Persisting a recording across app restarts.

## Decisions

### Capture with `record`, as a PCM stream

`record` 7.x is the only maintained package that captures on all five platforms and streams 16-bit PCM at a chosen rate (`startStream` with `AudioEncoder.pcm16bits`, 16 kHz, mono). It also asks for microphone permission itself on every platform (`hasPermission`), so `permission_handler` is not needed, and it reports amplitude for the level meter. The same chunks go to the socket and into an in-memory buffer; on fallback the buffer gets a 44-byte WAV header and is uploaded as `audio/wav`. Five minutes at 16 kHz mono is 9.6 MB, 12.8 MB as base64, well under Hermes' 25 MiB limit.
Alternatives: `flutter_sound` (heavy, buggy, a long issue history); `speech_to_text` (on-device only, no PCM, missing on Linux; see the proposal's non-goals). A second compressed recording (m4a) next to the stream: `record` cannot do both at once, and WAV is accepted by every Hermes STT provider.

### A binary socket next to the text one

Add a `hermesBinarySocketConnect` (or make the existing helper generic over the frame type) in `gateway_connection.dart`, reusing `credential()` and `gatewayUri` with `path: '/api/audio/transcribe-stream'` and `profile` in the query. A small `TranscribeStream` class in `lib/src/voice/` speaks the protocol: it buffers PCM sent before the socket is ready, as the desktop does, and turns frames into `partial`, `final` and `error` events. The 5 s open timeout and every failure end in "use the upload".

### `DictationController` owns one recording

A `ChangeNotifier` in `lib/src/voice/dictation_controller.dart` with the states `idle`, `recording` (elapsed, level, partial text), `transcribing`, `failed` (message, retry available) and `denied`. It takes a recorder interface, a `TranscribeStream` factory and the generated client, so tests drive it with a fake recorder and `FakeHermesServer`. It returns the transcript; inserting it at the cursor is done by the composer's owner, which holds the `TextEditingController`. `ChatScreen` creates one controller, gives it the chat's profile, and stops it on profile switch, dispose and `AppLifecycleState.paused`/`hidden`.

### Availability per profile
`ChatScreen` reads `voice-config` when a profile is shown, on reconnect and on resume. It keeps only two values: whether speech-to-text is usable and `stt.streaming`. Hermes has no explicit "available" flag, so usability is inferred from `stt.reason`. `stt disabled` (`stt.enabled: false`) and `no credentials` (a cloud provider without a key) mean unusable. Every other relay reason means usable: local Whisper, command and plugin providers, and `voice.client_direct disabled`, which hides the provider. In those cases a transcription error is reported when it happens. The response can carry provider API keys in client-direct mode. The parser reads only those fields and drops the raw map at once; the keys are never logged or kept. The `voice_chat` helper model has no part in dictation, which sends no turn. It gates `voice-conversation`.

### Composer UI (assistant-ui's dictation element)
The controls mirror assistant-ui's `ComposerPrimitive.Dictate`, `StopDictation` and `DictationTranscript`, and its `ComposerVoice` element. A microphone button sits beside send. While a session is active (`recording`, then `settling`), a waveform replaces the text field. Its bars move with the input level. It shows a pulsing dot and a timer while recording, then a shimmering "Transcribing" label while settling. The microphone button becomes a square stop button. The live transcript sits over the waveform as muted text. It is never written into the `TextEditingController`, so cancel never has to undo edits, and the draft is never rewritten mid-recording. `ChatComposer` takes an optional `DictationView` model (phase, level, elapsed time, live transcript, notice) and the callbacks `onDictate`, `onStopDictation`, `onCancelDictation` and `onRetryDictation`. With no model there is no microphone button, so the bot chat and older servers look as they do today. The waveform is its own widget (`lib/src/voice/widgets/voice_waveform.dart`), so `voice-conversation` can reuse it.

### Platforms and native changes

- iOS: `NSMicrophoneUsageDescription` in `ios/Runner/Info.plist`. `record` sets the audio session for recording. The share extension and watch app are unchanged.
- macOS: `NSMicrophoneUsageDescription` in `macos/Runner/Info.plist`; `com.apple.security.device.audio-input` in `DebugProfile.entitlements` and `Release.entitlements`. Conversation windows run their own engine; `MainFlutterWindow.swift` registers only a few plugins there, so dictation is left out of conversation windows in this change (the mic button is hidden when the plugin is missing).
- Android: `android.permission.RECORD_AUDIO` in the main manifest.
- Linux: `record_linux` streams through `parecord`, so the `.deb` built by `scripts/package-linux.sh` adds `pulseaudio-utils` to `Depends`. ffmpeg is only needed for file recording, which this change does not use.
- Windows: no manifest change for the unpackaged build.
- watchOS: none.

### Invariants touched

- API layering: REST calls go through `authController.api!.raw`; the socket is not in the spec and is opened like `/api/ws`. No `packages/hermes_api` change.
- Telemetry must never break the app: breadcrumbs go through `Breadcrumbs`, which is a no-op when telemetry is off.
- Tokens: the socket credential is fetched per connection, as for the chat socket, and is not stored.
- Tests use `FakeHermesServer` for the REST routes; the socket is faked at the `StreamChannel` seam, as the gateway tests do.

## Risks / Trade-offs

- [Upload waits for the whole clip] On providers without live STT (local Whisper, the default) the user sees no text until done, then waits for the upload → the composer shows "Transcribing…", and the stt-lease warms the model while the user speaks.
- [Linux without PulseAudio] `parecord` missing means `record` fails to start → the controller shows the error, and the `.deb` dependency covers packaged installs; the tarball's README gets a line.
- [macOS conversation windows lack the plugin] → mic hidden there; registering `record` in the window engine can follow.
- [Large uploads on slow links] 12.8 MB at the 5-minute limit → the upload uses a timeout scaled to its size (at least 3 minutes, as the desktop does) and failure keeps the recording for Retry.
- [App Review] a new permission string needs a reason the reviewer accepts → the string names dictation into the chat.
