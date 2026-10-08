# Design

## Context

`voice-dictation` provides microphone capture (`record`, 16 kHz PCM), the transcription socket and upload, the `voice-config` reader and the waveform. Hermes' desktop runs the chained voice loop in `use-voice-conversation.ts`, `voice-barge-in.ts`, `voice-playback.ts`, `voice-stop-word.ts` and `voice-tts-echo.ts`; this design follows its thresholds so both clients behave alike against one server. Replies already stream through `ChatTransport` and `ChatController`. `ChatMessage.sealedProse` holds text written before a tool call. The Helper models screen already reads `/api/model/auxiliary` (`lib/src/models/auxiliary_models.dart`).

## Goals / Non-Goals

**Goals:**

- One `VoiceConversationController` that drives the loop from `ChatController`'s own reply state, so voice turns are ordinary chat turns.
- Plain-model call-screen widgets (orb, caption, transcript, controls), so every state is in Widgetbook.

**Non-Goals:**

- A second chat pipeline for voice. Speech is a reader of the reply, never a separate request.
- Background audio, CarPlay and the watch.

## Decisions

### UI modelled on assistant-ui's voice elements

The call screen follows assistant-ui's `VoiceConversation`: an orb that is also the interrupt button, a caption with a hint, the last two turns and a control bar.

- The orb has five states, resolved in assistant-ui's fixed order: `idle`, `connecting`, `muted` (wins over speaking), then `speaking` or `listening`.
- `VoiceOrb` is a `CustomPainter`, not WebGL: rings scaled by a 0–1 `amplitude`, with a palette taken from the theme. That is enough in Flutter and runs on every platform.
- The composer toggle follows assistant-ui's compact voice toggle ("Start voice" / "End voice"), next to the dictation microphone.

The call screen is a full-screen route on phones and a sheet over the chat pane at 760 pt or wider (the Mac split view stays visible). Widgets live in `lib/src/voice/widgets/` (`voice_orb.dart`, `voice_call_screen.dart`) and take a `VoiceCallView` model with `mode`, `amplitude`, `turns`, `muted`, `canInterrupt` and `note`.

### Availability (compatible voice models)

`VoiceAvailability` combines three reads per profile: speech-to-text and text-to-speech from `voice-config`, and the `voice_chat` slot from `/api/model/auxiliary`. The slot counts as resolved when it names a model, or when it follows the main model (`provider` `auto`/`main`, no model, no base URL) and the response's `main.model` is set. This matches `agent/voice_turn_route.py`, which runs a slot that follows the main model on the main model. Like dictation, `tts.reason == "no credentials"` means unusable. Edge, the default, always relays and is usable. The reads are repeated on profile switch, reconnect, resume, and after `HelperModelsScreen` saves a slot.
Alternative: require a pinned `voice_chat` model. The user chose against it; a slot that follows the main model still runs voice turns.

### Loop controller over the existing chat path

`VoiceConversationController` (`lib/src/voice/voice_conversation_controller.dart`) is a state machine: `connecting → listening → transcribing → thinking → speaking → listening`, with `ended(reason)`.

- It sends through `ChatController.send(text, voiceTurn: true, interrupted: …)`, which passes the flags down `ChatTransport.send` into `prompt.submit`. The fake transport records them for tests.
- It watches the thread's latest reply in `ChatController` for new text (content plus `sealedProse`) and for the reply's end. Each new suffix goes to the speech session, so a queued or retried reply behaves as in the chat.
- A `{"voice_stopped": true}` submit outcome becomes a new `SubmitOutcome`, which ends the call.

### Voice activity detection on PCM

`VoiceActivity` (`lib/src/voice/voice_activity.dart`) computes RMS per 20 ms frame of the 16 kHz PCM stream. It does not use `record`'s amplitude callback, whose rate differs per platform. The thresholds are the desktop's:

- Calibrate the noise floor over the first 400 ms of quiet.
- Speech is above max(floor × 3.5, a minimum level).
- End-of-turn is the configured pause after speech; the turn is capped at 60 s.
- Barge-in needs 80 % of the last 300 ms above a trigger raised during playback, with 500 ms of grace after playback starts.

The desktop's levels are calibrated to Web Audio byte samples, so the minimum level is set again for int16 RMS and checked on devices. It is a constant, not a setting.

### Speech playback with `flutter_soloud`

`SpeechSession` (`lib/src/voice/speech_session.dart`) owns one speak-stream socket per reply. It is opened with the binary socket helper from `voice-dictation`. It feeds text frames, and on `start` it creates a SoLoud buffer stream (s16le, mono, the given rate). Each PCM frame goes in with `addAudioDataStream`, carrying an odd trailing byte over to the next frame. `stop()` stops the voice handle and sends `stop`. On fallback it calls `POST /api/audio/speak`, decodes the data URL and plays it with `loadMem`. `flutter_soloud` is the only maintained package with raw PCM streaming on all five platforms. `just_audio` and `flutter_pcm_sound` miss Windows and Linux, and `audioplayers` cannot stream PCM. The `SpeechPlayer` interface keeps it replaceable, and tests use a fake player.

### Audio session and echo cancellation

On iOS and Android, `audio_session` sets a voice-chat session for the call: `playAndRecord`, mode `voiceChat`, `defaultToSpeaker` and `allowBluetooth`, with the Android `voiceCommunication` usage. `record` starts with `echoCancel: true, noiseSuppress: true`. Barge-in is enabled only there (`Platform.isIOS || Platform.isAndroid`). Elsewhere the microphone closes while the agent speaks, and the orb tap interrupts. If device tests show SoLoud's iOS output escaping the voice-processing unit, the transcript echo guard still catches the echo. The fallback is to turn off barge-in on iOS, which is a one-line platform check.

### Echo guard and stop phrases

These are ports of the desktop's `voice-tts-echo.ts` and `voice-stop-word.ts`. The echo guard uses a `SequenceMatcher` ratio of 0.6 or higher, with a sliding window for transcripts of 10 characters or more that are shorter than the reply. Stop phrases use NFKC, lowercasing, punctuation removal, the leading-address prefixes and the built-in list. NFKC needs the `unorm_dart` package, or a small table if the analyzer rejects that package. Both are pure Dart and unit tested.

### Config

The controller reads the `voice` section of `GET /api/config?profile=` once per call: `silence_duration`, `stop_phrases` and `barge_in`. A missing key takes Hermes' default. No setting is written.

### Platforms and native changes

- **iOS:** the audio session category is set at runtime. There is no `UIBackgroundModes` audio entry (background audio is a non-goal), and the permission string comes from `voice-dictation`.
- **Android:** `MODIFY_AUDIO_SETTINGS` in the manifest, for `audio_session` and speakerphone routing.
- **macOS:** no change beyond `voice-dictation`. Playback needs no entitlement. The call is not offered in conversation windows, as with dictation.
- **Linux:** `flutter_soloud` builds miniaudio from source with CMake. CI's Linux job may need `libasound2-dev`, and the `.deb` gains `libasound2 | libasound2t64`.
- **Windows:** none.
- **watchOS:** none.

### Invariants touched

- **API layering:** REST goes through the generated client, and the sockets are opened like `/api/ws`. There is no `packages/hermes_api` change.
- **Telemetry:** breadcrumbs only, through `Breadcrumbs`, and never text.
- **Tests:** availability and the fallbacks run against `FakeHermesServer`. The loop runs against `FakeChatTransport` with fake recorder and player seams.

## Risks / Trade-offs

- **Echo on speakerphone triggers barge-in.** Mitigations: platform AEC, a trigger raised during playback, a grace period after playback starts, and the transcript echo guard. Barge-in can be turned off per profile (`voice.barge_in: false`).
- **SoLoud and `record` contend for the audio session on iOS.** The session is configured once, before either starts. Device testing is a task, not an assumption.
- **The VAD levels differ from the desktop's.** They are tuned on device during verification and kept as named constants.
- **A long reply stays unspoken until its first sentence ends.** The server flushes on punctuation or after 2 s idle, as on the desktop.
- **The call ends when the app is backgrounded,** which surprises users who lock the phone. The call screen says so; background audio is a follow-up change.
- **Size.** The work spans three stacked PRs (see tasks). Each is reviewable alone, and the feature is hidden until the last one wires the toggle.
