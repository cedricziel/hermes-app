# Design

## Context

Read against `main` at `fd9a626` and the Hermes source at `d923a5e` (0.22.2, the ref `openapi/HERMES_REF` and `openrpc/HERMES_REF` pin; `hermes_cli/web_routers/audio.py`).

**What exists.** iOS has a native voice call, shipped without a spec: `lib/src/voice/calls/` (`VoiceCall` state machine, `VoiceActivity` segmentation, `CallSpeechStream` for `/api/audio/speak-stream` and its `POST /api/audio/speak` fallback, `ChatCallAgent` sending through `ChatController.submit`, `CallReadinessChecker`), `packages/hermes_calls` (CallKit and one voice-processing AVAudioEngine graph), `docs/voice-calls.md`. The header button `header-voice-call` is iOS only (`chat_screen_calls.dart`, `_canCall`). Widgets: `VoiceCallView`, `VoiceCallSetupView`, `VoiceCallScreen`, with use cases in `widgetbook/voice_call_use_cases.dart`. `read_aloud` plays one finished reply and is separate.

**What the first draft got wrong now.** It planned a new `VoiceConversationController`, `VoiceActivity`, `SpeechSession`, a composer toggle, a 1.25 s pause, an end on background everywhere, and `voice.conversation.*` telemetry. All of that exists or conflicts with the shipped iOS call. The draft's thresholds, the echo guard and the stop phrases are kept as the rules below; the structure is replaced by reuse.

**What is missing for the new rules** (checked in code): no consent step; a failed transcription ends the call (`VoiceCall._turn` → `_end('turn')`); only "hang up" and "end the call" stop it; prompts carry no `voice_turn` or `interrupted` (`grep` finds none in `lib/`); the pause is a fixed 900 ms; no idle limit; no tones; no "Speak replies" switch; `CallBridge` has only the Apple implementation; `_canCall` is iOS only and does not read `voice_chat`.

**Backend facts at the ref.**

- `prompt.submit` takes `voice_turn`, `interrupted`, `voice_context`, `queued`; its result has `status` or, for a typed stop phrase, `voice_stopped` with no `status`.
- `/api/audio/speak-stream`: client `{"text"}`, `{"done": true}`, `{"stop": true}` (or disconnect); server `{"type":"start","sample_rate","channels":1}` with the first PCM frame, binary s16le PCM, `{"type":"end"}`, or `{"type":"fallback"}` only when no audio was made. Non-streaming providers (Edge, the default) still stream per-sentence PCM, which needs `ffmpeg` on the server; without it the socket falls back.
- `POST /api/audio/speak` answers a data URL (`{ok, data_url, mime_type}`); `POST /api/audio/tts-lease`, `stt-lease`; `GET /api/audio/voice-config`, `voice-live/status`. Transcription upload limit 25 MiB (a 60 s turn at 16 kHz is about 1.9 MB).
- Auth: the socket uses the same ticket or token as `/api/ws` (`hermesMixedSocketConnect`).

Not verifiable without a device: echo cancellation and barge-in on iOS and Android speakers, the CallKit hand-over, Bluetooth routes, audio focus on Android, `flutter_soloud` and `record` on Windows and Linux, tone loudness, haptics, VoiceOver and TalkBack announcements. CI proves compilation and the Dart state machine.

## Goals / Non-Goals

**Goals:** one loop on five platforms; nothing sent without per-call consent; a state the user can always see and hear; the microphone closed on every exit; plain-model widgets so every state is in Widgetbook.

**Non-Goals:** a second chat pipeline; background audio on Android and desktop; barge-in without platform echo cancellation; approvals by voice.

## Decisions

### 1. One loop, a platform audio seam

`VoiceCall` stays the owner of the loop. `CallBridge` is the seam: `events` (`pcm`, `muted`, `route`, `audioReset`, `deactivated`, `ended`, `error`), `start`, `mute`, `play`, `drain`, `stopPlayback`, `end`. `AppleCallBridge` is unchanged. `PortableCallBridge` (Android, macOS, Windows, Linux) feeds `pcm` from `record` (16 kHz mono; `echoCancel` and `noiseSuppress` on) and plays with `flutter_soloud` (a buffer stream, s16le mono at the `start` rate). It emits `deactivated` when audio focus is lost (`audio_session`, Android), `audioReset` on a route change, `error` when the microphone fails. Tests use a fake bridge.
Alternative rejected: a second controller. It would fork the barge-in and teardown rules that are already tested.

### 2. Consent

`VoiceCallSetupView` (the start screen) gets a consent row: a switch "Send what I say automatically" with the sentence "Hermes sends each thing you say after a pause, without you pressing send. It can use its tools to act on it." "Start call" is disabled until it is on. State lives in the screen's local state and is dropped with it: no preference, no default, not carried across calls, chats or profiles. Without consent the screen offers "Use dictation instead" (the existing dictation sheet). The call object takes `consented: true` at construction and refuses to open the microphone otherwise, so a code path that forgets the screen still cannot send. A breadcrumb `voice_call.consent` records only that it was given.
Alternative rejected: a one-time global setting. The microphone and a send without a tap is the highest-trust action in the app; asking each time costs one tap.

### 3. State, in words, icon, sound and haptic

States and their sources in `CallPhase`: Connecting, Listening, Muted (`muted` wins), Sending (new: `transcribing` plus the submit until `ChatController.submit` returns accepted), Thinking, Speaking, Waiting for you (`attention`), Stopped (`ended` or `failed`, with the notice). Each has an icon and a word; colour only tints. The orb (`VoiceOrb`, a `CustomPainter`, amplitude 0-1 from the PCM level, ring motion off under reduce-motion) is decoration plus the interrupt button.
Audible: three tones generated as PCM in Dart (no asset): rising "listening" (after connecting and after each reply), a soft tick "sent", falling "stopped". Played on the call's own output through the bridge. Speaking is the voice itself. With "Speak replies" off a reply is silent, so the tick is the only confirmation; the screen says "Reply is in the chat". Haptics: a light impact on sent and a medium one on stopped on iOS and Android. A `Semantics(liveRegion: true)` word announces each change ("Hermes is speaking"). The "Hands-free on" strip with a recording dot shows while the microphone is open and says "Muted" beside a struck mic when it is not.

### 4. Stopping

End, mute, stop phrases, and the platform hang-up (CallKit on iOS; the End button, and Escape on desktop). Back, or "Show chat", leaves the screen without ending the call, as on iOS today; the chat header then shows the "Hands-free on" strip with End, so a running microphone is never out of sight. End or mute during Sending cancels the epoch before submit, so nothing is sent (the existing epoch check; a test pins it). After submit, End stops the reply this call started (`ChatCallAgent.interrupt`).
Stop phrases port the desktop's `voice-stop-word.ts`: NFKC (`unorm_dart`, or a small table if the analyzer rejects it), lowercase, strip punctuation, strip a leading "hey hermes", "hermes", "ok", "hey"; the profile's `voice.stop_phrases` wins, empty turns them off; the built-in list is in the spec. It replaces the hang-up regex.

### 5. Listening and failed transcription

The existing `VoiceActivity` stays: 100 ms onset, 200 ms pre-roll, noise floor, 60 s cap. The pause is `voice.silence_duration` when set to a value other than 3.0 (Hermes' default, which is too slow for conversation), clamped to 0.5-3 s; otherwise the shipped 0.9 s. This replaces the draft's 1.25 s so iOS does not change. A transcription failure or timeout drops the turn and its audio, shows "Couldn't hear that. Nothing was sent.", and listens again; a second consecutive failure ends the call. A successful turn resets the count. This changes the shipped behaviour (end on first failure).

### 6. Speaking and barge-in

`CallSpeechStream` is unchanged except for the portable output. "Speak replies" off skips the socket and lease. Barge-in: on iOS (native AEC) as shipped; on Android with `record`'s `echoCancel` and the `voiceCommunication` audio usage; off elsewhere, where the bridge pauses capture while audio plays and resumes at the drain or the orb tap. The echo guard ports `voice-tts-echo.ts`: similarity ≥ 0.6 against the reply being spoken, with a sliding window for transcripts of 10 characters or more shorter than the reply; a matching barge-in transcript is dropped. `voice.barge_in: false` turns it off. If device tests show Android echo triggering barge-in, it is a one-line platform check to turn off there.

### 7. Voice turn flags

`ChatController.submit` gains `voiceTurn` and `interrupted`, passed through `ChatTransport.send` into `prompt.submit`. `ChatCallAgent.reply` sets `voiceTurn: true` and `interrupted` when the previous turn of this call was cut off. The `voice_stopped` outcome ends the call. The queue and retry paths keep the flags with the entry.

### 8. Interruptions, background, idle

- System interruption: iOS `deactivated` → end (shipped); Android audio focus loss → `deactivated` → end. No automatic resume: a call the user did not choose to pause must not reopen the microphone by itself.
- Route change: `audioReset` drops the epoch, discards the turn being heard, sets "Audio route changed. Please repeat if needed." and listens (shipped on iOS; the portable bridge emits it on device change).
- Background and lock: iOS keeps the call (CallKit, `UIBackgroundModes=audio`). Android: `AppLifecycleState.paused` ends it. macOS, Windows, Linux: `hidden` and `paused` end it; losing focus alone does not, since the OS shows its microphone indicator; a screen lock the app cannot observe is covered by the idle limit. A foreground service is a follow-up.
- Idle: 5 minutes with no speech and no running reply end the call ("Stopped: no one spoke for 5 minutes"). A constant, not a setting.
- Sign-out, profile, chat or account change end it (shipped, `ChatCallAgent.onContextLost`).

### 9. Teardown order

`_end` becomes: stop capture (microphone) → close the speech socket and stop playback → release the audio session and focus → release leases (`tts-lease`, `stt-lease`) → interrupt the agent. Each step is guarded so a throw does not skip the next, and the first step runs before the notice is shown. The shipped order releases native audio before waiting on remote cancel; the microphone-first rule only moves the capture stop up.

### 10. Availability, entry and screens

The header button is the entry on all platforms. `_canCall` adds the platform check (iOS, Android, macOS, Windows, Linux; not web, not conversation windows) and `VoiceAvailability`: speech-to-text and text-to-speech from `voice-config`, and the `voice_chat` slot from `/api/model/auxiliary` (names a model, or follows the main model: `provider` `auto`/`main`, no model, no base URL, and `main.model` set; this matches `agent/voice_turn_route.py`). `tts.reason == "no credentials"` means unusable; Edge always relays and is usable. Re-read on profile switch, reconnect, resume and after Helper models saves. On iOS the readiness checker gets the `voice_chat` check as a fifth row.
Screens: phone, a full-screen route (shipped). At 760 pt or wider, a 480 pt dialog over the chat so the split view stays visible; on the Mac, a window-modal sheet. The Speaker control is iOS and Android only; desktop has no earpiece. Desktop gets "Output" as the system's choice, no in-app picker.

### 11. Config

`GET /api/config?profile=` `voice` section, read once per call: `silence_duration`, `stop_phrases`, `barge_in`. Missing keys take the defaults above. Nothing is written. Warm-up: `tts-lease` while the call is open (`{"lease": "app:conversation:<id>", "active": …}`), failure ignored.

### Platform matrix

| Platform | Audio                                        | Barge-in                   | Background     | Verified without a device            |
| -------- | -------------------------------------------- | -------------------------- | -------------- | ------------------------------------ |
| iOS      | CallKit, voice-processing engine (shipped)   | yes                        | keeps running  | no                                   |
| Android  | `record` + `flutter_soloud`, `audio_session` | yes (device-dependent AEC) | ends           | no                                   |
| macOS    | `record` + `flutter_soloud`                  | no, orb tap                | ends on hidden | partly (Mac is the dev host, not CI) |
| Windows  | same                                         | no                         | ends on hidden | compile only                         |
| Linux    | same; needs ALSA/Pulse                       | no                         | ends on hidden | compile and Xvfb without audio       |

macOS adds no entitlement (the audio-input one exists for dictation). Android adds `MODIFY_AUDIO_SETTINGS`. Linux adds `libasound2 | libasound2t64` to the `.deb`.

### Invariants touched

- API layering: REST through the generated client; sockets opened like `/api/ws`; no `packages/hermes_api` change.
- Privacy: events and breadcrumbs carry fixed words, flags, buckets only. Audio is never written to disk (the Apple converter's temporary files are removed, as today).
- Auth: the call never signs the user out and ends on sign-out.
- Chat: voice turns are ordinary messages; nothing is held back from the thread after End.

## Risks / Trade-offs

- **Echo on speakerphone triggers barge-in** on Android. Mitigations: platform AEC, a raised trigger during playback, grace after playback starts, the echo guard, `voice.barge_in`.
- **`record` and SoLoud contend for the audio session** on Android. Configure `audio_session` once before either starts; device test is a task.
- **A call that ends on background surprises Android users.** The start screen says "The call ends if you leave Hermes."
- **Consent fatigue.** One tap per call. If it proves too much, a per-profile "ask each call" preference is a later change, never default-on.
- **Tones may be inaudible on a muted device.** The visible state is the primary; the tone is the second channel.
- **Linux audio** may be absent (headless, containers); the button hides.

## Design pass

The canvas and its decisions are in `docs/design-briefs/voice-conversation.md`. Two findings change the build: at the largest text size the start screen overflows, so its body scrolls and the consent switch and "Start call" are pinned at the bottom; and the "Hands-free on" strip drops its second half at large sizes instead of wrapping. Sending is a state of its own so End and mute have a visible last moment.
