# Design

## Context

Read against `main` and the Hermes source at `d923a5e` (0.22.2, the ref `openapi/HERMES_REF` and `openrpc/HERMES_REF` pin).

**What exists.** iOS has a native voice call, shipped without a spec: `lib/src/voice/calls/` (`VoiceCall` state machine, `VoiceActivity` segmentation, `CallSpeechStream` for `/api/audio/speak-stream` and its `POST /api/audio/speak` fallback, `ChatCallAgent` sending through `ChatController.submit`, `CallReadinessChecker`), `packages/hermes_calls` (CallKit and one voice-processing AVAudioEngine graph), `docs/voice-calls.md`. The header button `header-voice-call` is iOS only (`chat_screen_calls.dart`, `_canCall`). Widgets: `VoiceCallView`, `VoiceCallSetupView`, `VoiceCallScreen`, use cases in `widgetbook/voice_call_use_cases.dart`. `read_aloud` plays one finished reply and is separate.

**What the first draft got wrong.** It planned a new controller, activity detector and speech session, a composer toggle, a 1.25 s pause, end-on-background everywhere and `voice.conversation.*` telemetry. All of that exists or conflicts with the shipped call; the structure is replaced by reuse and the thresholds and rules are kept.

**What is missing for the new rules** (checked in code): no consent step; a failed transcription ends the call (`_turn` → `_end('turn')`); only "hang up" and "end the call" stop it (`voice_call.dart` regex); no `voice_turn` or `interrupted` anywhere in `lib/`; a fixed 900 ms pause; no idle limit; no tones; no "Speak replies" switch; `CallBridge` has only the Apple implementation; `_canCall` is iOS only; the views are not localised.

**Backend facts at the ref.**

- `prompt.submit` takes `voice_turn`, `interrupted`, `voice_context`, `queued`. `interrupted` makes Hermes latch a note onto that turn's model message (`mark_speech_interrupted`, `methods_prompt.py`). `voice_turn` runs the turn on the `voice_chat` model route. `voice_stopped` (no `status`) comes only from a typed stop phrase while Hermes' own voice mode is on, which the app never turns on; a typed prompt can get it too.
- `/api/audio/speak-stream`: client `{"text"}`, `{"done": true}`, `{"stop": true}` (or disconnect); server `{"type":"start","sample_rate","channels":1}` with the first PCM frame, binary s16le PCM, `{"type":"end"}`, or `{"type":"fallback"}` only when no audio was made. Non-streaming providers (Edge, the default) stream per-sentence PCM, which needs `ffmpeg` on the server.
- `POST /api/audio/speak` answers a data URL; `tts-lease`; `GET /api/audio/voice-config`, `voice-live/status`. Upload limit 25 MiB (60 s at 16 kHz is about 1.9 MB).
- `voice.stop_phrases` defaults to `["stop"]`, matched exactly after lowercasing and trimming `.,!?;: "'` (`tools/voice_mode_transcript.py`); `GET /api/config` returns defaults for unset keys, so the app cannot tell unset from default. `is_whisper_hallucination` in the same file lists the strings Whisper invents on silence ("thank you", "bye", "you", "the end", subtitle credits, repeats).

Not verifiable without a device: echo cancellation and barge-in on iOS and Android speakers, the CallKit hand-over, Bluetooth routes, Android audio focus, `flutter_soloud` and `record` on Windows and Linux, tone loudness, haptics, VoiceOver and TalkBack. CI proves compilation and the Dart state machine.

## Goals / Non-Goals

**Goals:** one loop on five platforms; nothing sent without per-call consent; a state the user can see and hear; the microphone closed on every exit; plain-model widgets so every state is in Widgetbook.

**Non-Goals:** a second chat pipeline; background audio on Android and desktop; native desktop lock observation (follow-up); barge-in without platform echo cancellation; approvals by voice.

## Decisions

### 1. One loop, a platform audio seam

`VoiceCall` stays the owner of the loop. `CallBridge` is the seam: `events` (`pcm`, `muted`, `route`, `audioReset`, `deactivated`, `ended`, `error`), `start`, `connected`, `mute`, `speaker`, `play`, `drain`, `stopPlayback`, `end`, and a new `stopCapture` (capture only; on iOS it ends the capture tap without touching CallKit, where `mute` goes through the system). `AppleCallBridge` implements it unchanged apart from `stopCapture`. `PortableCallBridge` (Android, macOS, Windows, Linux) feeds `pcm` from `record` (16 kHz mono; `echoCancel` and `noiseSuppress` on) and plays with `flutter_soloud` (a buffer stream, s16le mono at the `start` rate). It emits `deactivated` on Android audio-focus loss, `audioReset` on a route change, `error` when the microphone fails. `connected` is a no-op there; `speaker` routes with `audio_session` on Android and is absent on desktop. Tests use a fake bridge.

### 2. Consent

`VoiceCallSetupView` gets a consent row: the switch "Send what I say automatically" with the sentence "Hermes sends each thing you say after a pause, without you pressing send. It can use its tools to act on it." "Start call" is disabled until it is on. State lives in the screen's local state: no preference, no default, not carried across calls, chats or profiles; "Start a new call" on the stopped page reopens the setup with the switch off. Without consent the screen offers "Use dictation instead". `VoiceCall` takes `consented: true` at construction and refuses to open capture otherwise. Breadcrumb `voice_call.consent` records only that it was given.

### 3. State, in words, icon, sound and haptic

States from `CallPhase`: Connecting, Listening, Muted (`muted` wins), Sending (`transcribing` until `ChatController.submit` is called), Thinking, Speaking, Waiting for you (`attention`), Stopped (`ended`, `failed`). Each has an icon and a word. The orb (`VoiceOrb`, a `CustomPainter`, amplitude from the PCM level, static under reduce-motion) is also the interrupt button, enabled only while speaking.
Audible: three tones generated as PCM in Dart: rising when listening starts, a soft tick at submit, falling at stop. Speaking is the voice. With "Speak replies" off the tick is the only confirmation and the screen says "Reply is in the chat". Haptics: light on submit, medium on stop (iOS, Android). A live-region announces each state. The "Hands-free on" strip lives in the app shell, under the platform bar, on every screen while the microphone is open, with End; it also shows "paused" and "muted".

### 4. Stopping, and what Sending can cancel

End, mute, stop phrases and the platform hang-up stop it. The epoch check discards a turn on End or mute, but the shipped code only drops it when the phase is `transcribing` (`voice_call.dart:159`) and checks the epoch, not `muted`, while the speech socket opens (`:253`). The build re-checks `muted` and the epoch immediately before `agent.reply`. Sending ends when `submit` is called; the prompt is in the chat from then on and the hint stops promising a cancel ("Hermes is getting your words ready. End or mute now to cancel." only while transcribing). After submit, End stops the reply this call started (`ChatCallAgent.interrupt`).
Stop phrases: the matcher lowercases, trims surrounding punctuation and a leading "hey hermes", "hermes", "ok", "hey" (no Unicode normalisation: Hermes' own matcher has none, and no dependency is added). Because `GET /api/config` returns `["stop"]` for an unset key, that exact list counts as unset and the built-in list applies (it keeps the shipped "end the call" and "hang up" and "end call"). A profile that really wants only "stop" gets the built-in list: an accepted trade-off. Any other list is used as is; an empty list turns phrases off. `silence_duration` follows the same rule (3.0 is unset).

### 5. Listening, noise and false turns

`VoiceActivity` stays: 100 ms onset, 200 ms pre-roll, noise floor, 60 s cap, 0.9 s pause (the profile's value when set to something else). Transcripts that are empty or match Whisper's hallucination list (ported from `is_whisper_hallucination`, whole-transcript match) are dropped silently. A transcription failure or timeout drops the turn and its audio, shows "Couldn't hear that. Nothing was sent." and listens again; two in a row end the call; a success resets the count.
Where there is no echo cancellation (desktop) the bridge pauses capture while a tone or the reply plays and resumes 400 ms after the drain; on every platform the first transcript after playback is run through the echo guard (similarity ≥ 0.6 against the reply just spoken, sliding window for transcripts of 10 characters or more shorter than the reply) and dropped on a match. Tones play with capture paused.

### 6. Speaking and barge-in

`CallSpeechStream` is unchanged except for the portable output. "Speak replies" off skips the socket and the lease. Barge-in: iOS (native AEC, as shipped); Android with `record`'s `echoCancel` and the voice-communication stream, which is device-dependent: barge-in is on by default on Android but the platform check is one line and device tests decide (task 6.5). Off on desktop.
Shipped behaviour stops the reply at onset (`voice_call.dart:179-189`), so echo would kill a reply. The build changes it: onset stops playback and closes the speech socket, the reply keeps streaming, and `agent.interrupt()` runs only when a real turn is about to be submitted. If the transcript is echo, empty or a hallucination, the reply finishes in the chat unspoken. `interrupted` has one definition: the first spoken turn after the user cut off speech, by tap or by speaking over it; it is cleared once sent.
While the agent waits for an approval (`attention`), onset is ignored and capture pauses; today onset would interrupt the turn and send "yes" as a new turn.
The shipped 15 s stall watchdog (`voice_call.dart:126-133`) is suspended whenever capture is paused by design (desktop playback, Waiting for you, mute).

### 7. Voice turn flags and outcomes

`ChatController.submit` gains `voiceTurn` and `interrupted`, passed through `ChatTransport.send` into `prompt.submit`. A voice turn is never queued: `ChatCallAgent.reply` already refuses while the thread replies or its queue is non-empty, so the call drops the turn with "Hermes is still answering. Nothing was sent." (a queued turn could be sent after End, which cannot withdraw it). Statuses: `streaming` starts the turn; `queued`, `steered`, `redirected` (`hermes_gateway_transport_sending.dart`) mean Hermes was busy: the agent stops waiting at once instead of up to 10 minutes, the call says "Hermes was busy. Your words are in the chat." and listens. `voice_stopped` is handled for typed and spoken prompts alike: consumed, no placeholder, a running call ends. A typed message sent during a call is a chat message; its reply is not spoken.

### 8. Interruptions, background, idle

- System interruption: iOS `deactivated` → end (shipped). Android audio focus: permanent loss and transient loss end the call; `LOSS_TRANSIENT_CAN_DUCK` does not. No automatic resume.
- Route change: `audioReset` drops the turn being heard, caption "Audio route changed. Please repeat if needed. Nothing was sent.", listens.
- Background and lock: iOS keeps the call (CallKit, `UIBackgroundModes=audio`). Android: `paused` ends it (also on lock). macOS, Windows, Linux: `hidden` and `paused` end it. A desktop screen lock is not observed; the idle limit bounds it (a stated platform limit). Native lock observation (macOS `com.apple.screenIsLocked`, Windows session notifications, Linux logind) is a follow-up.
- Idle: 5 minutes with no speech and no running reply end the call. A constant.
- Sign-out, profile, chat or account change end it (shipped, `onContextLost`).

### 9. Teardown

`_end`: `stopCapture` first (before the notice shows) → close the speech socket and `stopPlayback` → release the audio session and focus → release the `tts-lease` if held → interrupt the agent. Those are the resources a call acquires: one capture, one speak-stream socket per reply, playback, the audio session and the optional `tts-lease`; there is no second socket and no `stt-lease` (dictation's). Every step has a 2 s timeout and its own guard, so a throw or a hang skips nothing. `PortableCallBridge.start` returns a cancellable future: End during a pending `record.startStream` marks it cancelled and the capture is closed when it resolves.

### 10. Availability, entry and screens

The header button is the entry on all platforms: `_canCall` loses the iOS-only line and keeps the chat-state rules. The start screen's readiness checker holds the rest: microphone, speech recognition, Hermes speech (reuse `VoiceSupport.textToSpeech`, which already handles `tts` disabled), audio output, and a new `voice_chat` row (names a model, or follows the main model: `provider` `auto`/`main`, no model, no base URL, `main.model` set, as `voice_turn_route.py`). A failed or 404 voice-model read is a warning. Re-run on every open. Phone: full-screen route (shipped). At 760 pt or wider and on the Mac: a 480 pt dialog over the chat (`showAdaptiveSheet`, no sheet on the Mac). Escape and "Show chat" close the dialog without ending the call; the shell strip stays and has End. Speaker control: iOS and Android only.

### 11. Config

`voice` section of `GET /api/config?profile=`, once per call: `silence_duration`, `stop_phrases`, `barge_in`, with the unset rule of decision 4. `voice-live/status` is read once at the start screen for the GPT-Live note. `tts-lease` is held while the call is open (`{"lease": "app:conversation:<id>", "active": …}`), failure ignored.

### 12. Dependencies

- `flutter_soloud` 5.3.0 (published 2026-11-13): publisher marcobavagnoli.com, 617 likes, 150 pub points, about 193k downloads in 30 days, Android, iOS, Linux, macOS, Windows and web, MIT, a wrapper over SoLoud and miniaudio with buffer streams for raw PCM. Alternatives per the first draft: `just_audio` and `flutter_pcm_sound` lack Windows and Linux, `audioplayers` cannot stream PCM; re-check at task 5.1 together with the open issues, which were not reviewed here. It is initialised only by `PortableCallBridge`: never on iOS (CallKit alone owns the audio session), never in conversation-window engines (registered out, as `record` is). SoLoud's optional Opus and Ogg libraries are not needed for PCM and are not enabled.
- `record` and `audio_session` are already dependencies. No `unorm_dart`.
- Native: Android `MODIFY_AUDIO_SETTINGS`. Linux builds miniaudio from source: CI's Linux job may need `libasound2-dev`; the packages built by `release-please.yml` (x86_64 and arm64 `.deb` and tar.gz) gain `libasound2 | libasound2t64` through `scripts/package-linux.sh`.

### Migration (iOS)

The call shipped on iOS; this change alters it, and the docs say so in PR 2:

- **Model route:** `voice_turn: true` moves calls onto the profile's `voice_chat` model route (`docs/voice-calls.md` says the selected model stays in use), and `interrupted` adds a note to the model's message (`methods_prompt.py`); "no hidden system instructions" no longer holds literally. Task 6.3 rewrites those paragraphs.
- **Consent:** a call needs the switch each time.
- **Stop phrases:** "hang up", "end call" and "end the call" stay; more are added; the profile list is honoured.
- **Transcription failure:** drops the turn instead of ending the call.
- **Speech failure:** fallback on a failure before audio and "failure after audio counts as finished" replace today's end-the-call in both cases (`call_speech_stream.dart`, `voice_call.dart` `_turn`).
- **Availability:** the `voice_chat` row joins the readiness checks.
- **Barge-in:** echo no longer kills the reply; approval-wait onset is ignored.
- **Strings:** the call views move to ARB (en, de).

### Platform matrix

| Platform | Audio                                        | Barge-in                   | Background     | Lock                     | Without a device            |
| -------- | -------------------------------------------- | -------------------------- | -------------- | ------------------------ | --------------------------- |
| iOS      | CallKit, voice-processing engine (shipped)   | yes                        | keeps running  | keeps running            | no                          |
| Android  | `record` + `flutter_soloud`, `audio_session` | yes (device-dependent AEC) | ends           | ends                     | no                          |
| macOS    | `record` + `flutter_soloud`                  | no, orb tap                | ends on hidden | not observed, idle limit | partly                      |
| Windows  | same                                         | no                         | ends on hidden | not observed, idle limit | compile only                |
| Linux    | same; needs ALSA or Pulse                    | no                         | ends on hidden | not observed, idle limit | compile, Xvfb without audio |

### Scope decision

The safety rules (consent, stopping, failed transcription, interruptions, teardown, waiting, flags) ship first. The turn list, the "Speak replies" switch and the tones are the last PR: they can be cut without weakening those rules. The GPT-Live note stays (a read and a line).

### Invariants touched

- API layering: REST through the generated client; sockets opened like `/api/ws`; no `packages/hermes_api` change.
- Privacy: events and breadcrumbs carry fixed words, flags, buckets. Audio is never written to disk.
- Auth: the call never signs the user out and ends on sign-out.
- Chat: voice turns are ordinary messages; End leaves the thread intact.

## Risks / Trade-offs

- **Echo on Android speakers** can trigger barge-in. Mitigations: AEC, a raised trigger during playback, grace after playback, the echo guard, `voice.barge_in`, a one-line platform switch.
- **`record` and SoLoud contend for the audio session** on Android. Configure `audio_session` once before either starts.
- **A call that ends on background surprises Android users.** The start screen says so.
- **A desktop lock keeps the microphone open up to 5 minutes.** Stated limit; the OS indicator shows it and the idle limit ends it.
- **Consent fatigue.** One tap per call; a "ask each call" preference is a later change, never default on.
- **Tones may be inaudible on a muted device.** The visible state is primary.
- **Linux audio** may be absent; the check fails and Start is unavailable.

## Design pass

Canvas and decisions: `docs/design-briefs/voice-conversation.md`. At the largest text size the start screen scrolls with the consent switch and "Start call" pinned at the bottom; the strip drops its second half instead of wrapping.
