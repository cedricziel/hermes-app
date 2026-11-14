# Design

## Context

Read against `main` and the Hermes source at `d923a5e` (0.22.2, the ref `openapi/HERMES_REF` and `openrpc/HERMES_REF` pin).

**What exists.** iOS has a native voice call, shipped without a spec: `lib/src/voice/calls/` (`VoiceCall` state machine, `VoiceActivity` segmentation, `CallSpeechStream` for `/api/audio/speak-stream` and its `POST /api/audio/speak` fallback, `ChatCallAgent` sending through `ChatController.submit`, `CallReadinessChecker`), `packages/hermes_calls` (CallKit and one voice-processing AVAudioEngine graph), `docs/voice-calls.md`. The header button `header-voice-call` is iOS only (`chat_screen_calls.dart`, `_canCall`). Widgets: `VoiceCallView`, `VoiceCallSetupView`, `VoiceCallScreen`, use cases in `widgetbook/voice_call_use_cases.dart`. `read_aloud` plays one finished reply and is separate.

**What the first draft got wrong.** It planned a new controller, activity detector and speech session, a composer toggle, a 1.25 s pause, end-on-background everywhere and `voice.conversation.*` telemetry. All of that exists or conflicts with the shipped call; the structure is replaced by reuse and the thresholds and rules are kept.

**What is missing for the new rules** (checked in code): no consent step; a failed transcription ends the call (`_turn` → `_end('turn')`); only "hang up", "end call" and "end the call" stop it (`voice_call.dart` regex); no `voice_turn` or `interrupted` anywhere in `lib/`; a fixed 900 ms pause; no idle limit; no tones; no "Speak replies" switch; `CallBridge` has only the Apple implementation; `_canCall` is iOS only; the views are not localised.

**Backend facts at the ref.**

- `prompt.submit` takes `voice_turn`, `interrupted`, `voice_context`, `queued`. `interrupted` calls `mark_speech_interrupted()`, which sets a process-wide latch (`tools/tts_streaming.py`, 120 s TTL) before the session is validated or the busy mode applied; `take_speech_interrupted()` (`tui_gateway/prompt_turn.py`) then prepends the note "the user interrupted your previous spoken reply" to whichever turn the process starts next, which may be another session's or profile's. A voice turn answered `queued`, `steered` or `redirected`, or refused, therefore leaves the note for someone else's turn. Consequence: the app sends `interrupted` only on a submit it expects to start at once (idle thread, nothing queued) and clears it after that submit whatever the answer; the residual risk is accepted and an upstream request (a per-session or per-turn note) goes on the roadmap's Upstream list. `voice_turn` runs the turn on the `voice_chat` model route. `voice_stopped` (no `status`) comes only from a typed stop phrase while Hermes' own voice mode is on, which the app never turns on; a typed prompt can get it too.
- `/api/audio/speak-stream`: client `{"text"}`, `{"done": true}`, `{"stop": true}` (or disconnect); server `{"type":"start","sample_rate","channels":1}` with the first PCM frame, binary s16le PCM, `{"type":"end"}`, or `{"type":"fallback"}` only when no audio was made. Non-streaming providers (Edge, the default) stream per-sentence PCM, which needs `ffmpeg` on the server.
- `POST /api/audio/speak` answers a data URL; `tts-lease`; `GET /api/audio/voice-config`, `voice-live/status`. Upload limit 25 MiB (60 s at 16 kHz is about 1.9 MB).
- `voice.stop_phrases` defaults to `["stop"]`, matched exactly after lowercasing and trimming `.,!?;: "'` (`tools/voice_mode_transcript.py`). `GET /api/config` takes `include_defaults` (`config_env.py`, the OpenAPI spec, the generated client's `includeDefaults`, already used with `false` by `platform_hint_repository.dart`), so the app reads the profile's own keys and an unset key is absent. `is_whisper_hallucination` in the same file lists the strings Whisper invents on silence ("thank you", "bye", "you", "the end", subtitle credits, repeats).

Not verifiable without a device: echo cancellation and barge-in on iOS and Android speakers, the CallKit hand-over, Bluetooth routes, Android audio focus, whether Windows and Linux embedders report hidden and paused lifecycle states, `flutter_soloud` and `record` on Windows and Linux, the Android playback stream usage, tone loudness, haptics, VoiceOver and TalkBack. CI proves compilation and the Dart state machine.

## Goals / Non-Goals

**Goals:** one loop on five platforms; nothing sent without per-call consent; a state the user can see and hear; the microphone closed on every exit; plain-model widgets so every state is in Widgetbook.

**Non-Goals:** a second chat pipeline; background audio on Android and desktop; native desktop lock observation (follow-up); barge-in without platform echo cancellation; approvals by voice.

## Decisions

### 1. One loop, a platform audio seam

`VoiceCall` stays the owner of the loop. `CallBridge` is the seam: `events` (`activated`, `pcm`, `muted`, `route`, `audioReset`, `deactivated`, `ended`, `error`, and a new `capturePaused` with a flag and a reason for pauses the bridge makes itself), `start`, `connected`, `mute`, `speaker`, `play`, `drain`, `stopPlayback`, `end`, and three new calls: `pauseCapture`, `resumeCapture` (for Waiting for you and tones, without going through CallKit's mute on iOS) and `stopCapture` (capture only; on iOS it ends the capture tap without touching CallKit). The stall watchdog and the strip's "paused" read `capturePaused`. The portable bridge emits `activated` when capture started. `AppleCallBridge` implements it unchanged apart from `stopCapture`. `PortableCallBridge` (Android, macOS, Windows, Linux) feeds `pcm` from `record` (16 kHz mono; `echoCancel` and `noiseSuppress` on) and plays with `flutter_soloud` (a buffer stream, s16le mono at the `start` rate). It emits `deactivated` on Android audio-focus loss, `audioReset` on a route change, `error` when the microphone fails. `connected` is a no-op there; `speaker` routes with `audio_session` on Android and is absent on desktop. Tests use a fake bridge.

### 2. Consent

`VoiceCallSetupView` gets a consent row: the switch "Send what I say automatically" with the sentence "Hermes sends each thing you say after a pause, without you pressing send. It can use its tools to act on it." "Start call" is disabled until it is on. State lives in the screen's local state: no preference, no default, not carried across calls, chats or profiles; "Start a new call" on the stopped page reopens the setup with the switch off. Without consent the screen offers "Use dictation instead". `VoiceCall` takes `consented: true` at construction and refuses to open capture otherwise. Breadcrumb `voice_call.consent` records only that it was given.

### 3. State, in words, icon, sound and haptic

States from `CallPhase`: Connecting, Listening, Muted (`muted` wins), Sending (`transcribing` until `ChatController.submit` is called), Thinking, Speaking, Waiting for you (`attention`), Stopped (`ended`, `failed`). Each has an icon and a word. The orb (`VoiceOrb`, a `CustomPainter`, amplitude from the PCM level, static under reduce-motion) is also the interrupt button, enabled only while speaking.
Audible: three tones generated as PCM in Dart: rising when listening starts, a soft tick at submit, falling at stop. Speaking is the voice. With "Speak replies" off the tick is the only confirmation and the screen says "Reply is in the chat". Haptics: light on submit, medium on stop (iOS, Android). A live-region announces each state. The "Hands-free on" strip lives in the main window's shell, under the platform bar, on every screen while the microphone is open, with End; it also shows "paused" and "muted". On macOS a conversation window or the quick panel is a separate engine and shows none while capture runs: a stated limit, covered by the OS microphone indicator.

### 4. Stopping, and what Sending can cancel

End, mute, stop phrases and the platform hang-up stop it. The epoch check discards a turn on End or mute, but the shipped code only drops it when the phase is `transcribing` (`voice_call.dart:159`) and checks the epoch, not `muted`, while the speech socket opens (`:253`). The build re-checks `muted` and the epoch immediately before `agent.reply`. Sending ends when `submit` is called; the prompt is in the chat from then on and the hint stops promising a cancel ("Hermes is getting your words ready. End or mute now to cancel." only while transcribing). After submit, End stops the reply this call started (`ChatCallAgent.interrupt`).
Stop phrases: the matcher lowercases, trims surrounding punctuation and a leading "hey hermes", "hermes", "ok", "hey" (no Unicode normalisation: Hermes' own matcher has none, and no dependency is added). The config is read with `include_defaults=false`. Hermes treats a string as one phrase and anything else malformed as `["stop"]` (`voice_mode_transcript.py`); the app uses the built-in list for a malformed value, one phrase for a string, and only an explicit empty list turns phrases off. A profile that sets a list replaces the built-in list (which keeps the shipped "end the call", "hang up" and "end call" only when the profile sets none), `["stop"]` included, and an empty list turns phrases off. `silence_duration` is used when the profile sets it. There is no unset-equals-default heuristic.

### 5. Listening, noise and false turns

`VoiceActivity` stays: 100 ms onset, 200 ms pre-roll, noise floor, 60 s cap, 0.9 s pause (the profile's value when it sets one). Transcripts are checked in one order: empty, echo, Whisper hallucination (ported from `is_whisper_hallucination`, whole-transcript match), stop phrase, else sent; each dropped one is silent. "bye" is a hallucination string and so never stops the call; "goodbye" does. A transcription failure or timeout drops the turn and its audio, shows "Couldn't hear that. Nothing was sent." and listens again; two in a row end the call; a success resets the count.
Where there is no echo cancellation (desktop) the bridge pauses capture while a tone or the reply plays and resumes 400 ms after the drain; on every platform the first transcript after playback is run through the echo guard (similarity ≥ 0.6 against the reply just spoken, sliding window for transcripts of 10 characters or more shorter than the reply) and dropped on a match. Tones play with capture paused (`pauseCapture`, also on iOS, where tones share CallKit's graph) and pausing resets the speech detector.

### 6. Speaking and barge-in

`CallSpeechStream` is unchanged except for the portable output. "Speak replies" off skips the socket and the lease. Barge-in: iOS (native AEC, as shipped). Android: off until a device check passes, because miniaudio's default playback stream may not be the voice-communication stream that echo cancellation needs; the portable bridge asks for it with `SoLoud.init(androidAAudioAttributes: AndroidAAudioAttributes.voiceCommunication)` (honoured with `lowLatency: false` only; SoLoud's default is media music, and `audio_session` cannot set another library's AAudio usage), and task 6.5 turns barge-in on only if it holds. Off on desktop; there the orb tap interrupts.
Shipped behaviour stops the reply at onset (`voice_call.dart:179-189`), so echo would kill a reply. The build changes it: onset stops playback and closes the speech socket, the reply keeps streaming, and `agent.interrupt()` runs only when a real turn is about to be submitted. If the transcript is echo, empty or a hallucination, the reply finishes in the chat unspoken. An orb tap also interrupts the running reply (`agent.interrupt()` awaited until the session has settled, at most 8 s, not just until the message stops being pending) and then listens, so the next turn is not refused as "still answering". `interrupted` has one definition: the first spoken turn after the user cut off speech, by tap or by speaking over it. It is sent only when the thread is settled (no pending reply and `session.info` running false: `_submitTo` does not wait for the settle timers and Hermes can still be running after the message stopped pending, which would mark the latch and leave the note for another session). A refused, dropped or echoed turn keeps it pending; it is cleared by the first submit that reaches the transport, whatever the answer, and by mute, a route change, a typed message or 120 s.
While the agent waits for an approval (`attention`), onset is ignored and capture pauses; today onset would interrupt the turn and send "yes" as a new turn. Because the build keeps the reply running after onset, and the shipped `onAttention` drops callbacks for a stale epoch (`voice_call.dart:260-261`), `attention` is tracked per call, not per epoch, and read from the thread: `ChatCallAgent` reports attention only for its own reply, so an approval from a typed reply or a server-queued one would otherwise never pause capture. It is re-checked immediately before `agent.interrupt()` and before `submit`, a turn already in Sending when the approval arrives is dropped, and `pauseCapture` resets the speech detector.
The shipped 15 s stall watchdog (`voice_call.dart:126-133`) is suspended whenever capture is closed or paused by design: desktop playback, Sending and Thinking where barge-in is off, Waiting for you, and mute.

### 7. Voice turn flags and outcomes

`ChatController.submit` gains `voiceTurn` and `interrupted`, passed through `ChatTransport.send` into `prompt.submit`. The client never queues a voice turn. `ChatCallAgent.reply` checks `queuedIn(thread)`, which is empty while the persisted queue is not restored, and `submit` then goes through `_submitAfterQueueRestore` and `_submitTo`, which enqueues when a reply started meanwhile or the restored queue is not empty; End cannot withdraw that, and End or mute during the restore's secure-storage await would not stop the send either, because the epoch and mute checks happen before the call. So `submit(voiceTurn: true)` takes a still-wanted predicate (epoch, requested mute, attention, consent), awaits the queue restore, re-checks the predicate right before `_send`, and passes it as the `authorize` check of the `prompt.submit` request itself (`gateway_rpc_client.dart`). `_send` only hands off: the transport then awaits `_client()`, `session.resume` or `create` (up to three attempts with backoff), `_switchModel` and `_attach` before it writes `prompt.submit`, and an unprotected send has no stop check after that (`authorize` runs only with `beforeSubmit`). End does not stop it today: `ChatCallAgent.interrupt` -> `stopReply` finds no running turn, and the controller only marks the placeholder stopped locally, so the stream is never cancelled and the prompt still goes out (a live bug in the shipped iOS call: End during `session.resume` still submits). With the predicate as `authorize`, End cancels a send whose `prompt.submit` was not written. It returns a typed refusal rather than enqueue: busy, no longer wanted, queue restore failed, model or branch not allowed, profile not confirmed, or session reclaimed. Only busy says "Hermes is still answering. Nothing was sent."; the others that leave the call usable say "Couldn't send. Nothing was sent.", and a lost session or profile ends the call. Mute is the requested mute, set synchronously in `setMuted`, not the `muted` the bridge event confirms later. Hermes itself may still answer `queued`, `steered` or `redirected` (its `busy_input_mode`, default interrupt), which is handled below. Statuses: `streaming` starts the turn; `queued`, `steered`, `redirected` (`hermes_gateway_transport_sending.dart`) mean Hermes was busy: the agent stops waiting at once instead of up to 10 minutes, the call says which one ("Hermes will answer your words after its current reply.", "Hermes took your words into its current reply.", "Hermes is adjusting its current reply to your words."; `steered` and `redirected` fold the text into the running turn, which keeps streaming, as the main chat spec's "Submit outcome" says) and listens. `voice_stopped` is handled for typed and spoken prompts alike: consumed, no placeholder, a running call ends. A typed message sent during a call is a chat message; its reply is not spoken.

### 8. Interruptions, background, idle

- System interruption: iOS `deactivated` → end (shipped). Android audio focus: permanent loss and transient loss end the call; `LOSS_TRANSIENT_CAN_DUCK` does not. No automatic resume.
- Route change: `audioReset` drops the turn being heard and the speech, caption "Audio route changed. Please repeat if needed. Nothing was sent.", listens. The shipped handler also calls `agent.interrupt()` and forces `listening` (`voice_call.dart:143-155`), which cancels a pending approval; the build removes both: the running reply and the Waiting for you state survive, and capture stays paused if waiting.
- Background and lock: iOS keeps the call (CallKit, `UIBackgroundModes=audio`). Android: `paused` ends it (also on lock). macOS, Windows, Linux: `hidden` and `paused` end it. A desktop screen lock is not observed; the idle limit bounds it (a stated platform limit). Native lock observation (macOS `com.apple.screenIsLocked`, Windows session notifications, Linux logind) is a follow-up.
- Idle: 5 minutes with no speech and no running reply end the call. A constant. Wherever barge-in is off (desktop, Android until verified, and any profile with `voice.barge_in: false`) capture is open only while Listening, so during a reply nothing is captured and a locked desktop is exposed for at most 5 minutes after the reply's end; where barge-in is on (iOS, Android once verified) capture also runs during replies, and Android ends on lock.
- Sign-out, profile, chat or account change end it (shipped, `onContextLost`).

### 9. Teardown

`_end`: `stopCapture` first (before the notice shows) → close the speech socket and `stopPlayback` → release the audio session and focus → release the `tts-lease` if held → interrupt the agent. Those are the resources a call acquires: one capture, one speak-stream socket per reply, playback, the audio session and the optional `tts-lease`; there is no second socket and no `stt-lease` (dictation's). Every step has a 2 s timeout and its own guard, so a throw or a hang skips nothing. `PortableCallBridge.start` returns a cancellable future: End during a pending `record.startStream` marks it cancelled and the capture is closed when it resolves.

### 10. Availability, entry and screens

The header button is the entry on all platforms: `_canCall` loses the iOS-only line in the PR that ships the portable bridge, and keeps the chat-state rules. The start screen's readiness checker holds the rest: microphone, speech recognition, Hermes speech (reuse `VoiceSupport.textToSpeech`, which already handles `tts` disabled), audio output, and a new `voice_chat` row (resolves when the slot names a model; follows the main model with `provider` `auto`/`main`, no model, no base URL and `main.model` set; or pins a provider without a model, which Hermes' `_route_target` runs on that provider's fast auxiliary model; as `voice_turn_route.py`). A failed or 404 voice-model read is a warning. Re-run on every open. Phone: full-screen route (shipped). At 760 pt or wider and on the Mac: a 480 pt dialog over the chat (`showAdaptiveSheet`, no sheet on the Mac). Escape and "Show chat" close the dialog without ending the call; the shell strip stays and has End. Speaker control: iOS and Android only.

### 11. Config

`voice` section of `GET /api/config?profile=&include_defaults=false`, once per call: `silence_duration`, `stop_phrases`, `barge_in`; an absent key takes the app's default. `voice-live/status` is read once at the start screen for the GPT-Live note. `tts-lease` is held while the call is open (`{"lease": "app:conversation:<id>", "active": …}`), failure ignored.

### 12. Dependencies

- `flutter_soloud` 5.3.0 (published 2026-11-13): publisher marcobavagnoli.com, 617 likes, 150 pub points, about 193k downloads in 30 days, Android, iOS, Linux, macOS, Windows and web, MIT, a wrapper over SoLoud and miniaudio with buffer streams for raw PCM. Alternatives: `just_audio` and `flutter_pcm_sound` lack Windows and Linux and `audioplayers` cannot stream PCM (first-draft findings, re-checked at task 6.1); `media_kit`, already a dependency on every platform, plays files, URLs and memory buffers through libmpv but offers no push-PCM API for a stream that is still arriving, so it would need a local HTTP source and adds latency; reconsider it only if SoLoud fails on a device. Open issues were not reviewed here: task 6.1 does. The release is one day old at the time of writing: pin `5.3.0` exactly, read its changelog and wait for a patch if one appears. It is initialised only by `PortableCallBridge`: never on iOS (CallKit alone owns the audio session), never in conversation-window engines (registered out, as `record` is). In 5.3.0 the Xiph libraries (Opus, Ogg, Vorbis, FLAC) are linked by default through a Dart build hook (`hook/build.dart`) that downloads prebuilt archives from a GitHub release during every build, iOS included. PCM needs none of them, so the pubspec sets the hook user-define `no_xiph_libs: true`; task 6.1 confirms that this also removes the download from CI, the release workflows and the Linux arm64 build.
- `record` and `audio_session` are already dependencies. No `unorm_dart`.
- Native: Android `MODIFY_AUDIO_SETTINGS`. On Linux the plugin links only `dl` (plus `pthread` only with VST3; miniaudio loads ALSA and Pulse at run time), so `libasound2-dev` is not needed, and the `.deb` already depends on `pulseaudio-utils` and `libmpv2`; task 6.1 checks the x86_64 and arm64 packages built by `release-please.yml` run with it.

### Migration (iOS)

The call shipped on iOS; this change alters it, and the docs say so in the PR that makes each change (the model-route and `interrupted` paragraphs with the flags PR):

- **Model route:** `voice_turn: true` moves calls onto the profile's `voice_chat` model route (`docs/voice-calls.md` says the selected model stays in use), and `interrupted` adds a note to the model's message (`methods_prompt.py`); "no hidden system instructions" no longer holds literally. Task 5.3 rewrites those paragraphs.
- **Consent:** a call needs the switch each time.
- **Stop phrases:** with no profile list, "hang up", "end call" and "end the call" stay and more are added; a profile list replaces them, so a profile that sets one loses the shipped phrases unless it lists them.
- **Transcription failure:** drops the turn instead of ending the call.
- **Speech failure:** fallback on a failure before audio and "failure after audio counts as finished" replace today's end-the-call in both cases (`call_speech_stream.dart`, `voice_call.dart` `_turn`).
- **Availability:** the `voice_chat` row joins the readiness checks.
- **Barge-in:** echo no longer kills the reply; approval-wait onset is ignored; a route change no longer cancels a pending approval.
- **Also visible:** the 5-minute idle end, capture pausing while Waiting for you, silent drops of hallucinated transcripts, and a turn spoken while a reply runs being dropped with "Hermes is still answering" instead of ending the call.
- **Telemetry:** the shipped reason `voice_hang_up` becomes `stop_phrase`; `voice_stopped` is new.
- **Strings:** the call views move to ARB (en, de).

### Platform matrix

| Platform | Audio                                        | Barge-in                   | Background     | Lock                     | Without a device            |
| -------- | -------------------------------------------- | -------------------------- | -------------- | ------------------------ | --------------------------- |
| iOS      | CallKit, voice-processing engine (shipped)   | yes                        | keeps running  | keeps running            | no                          |
| Android  | `record` + `flutter_soloud`, `audio_session` | off until device-verified  | ends           | ends                     | no                          |
| macOS    | `record` + `flutter_soloud`                  | no, orb tap                | ends on hidden | not observed, idle limit | partly                      |
| Windows  | same                                         | no                         | ends on hidden | not observed, idle limit | compile only                |
| Linux    | same; needs ALSA or Pulse                    | no                         | ends on hidden | not observed, idle limit | compile, Xvfb without audio |

### Scope decision

The safety rules (consent, stopping, failed transcription, interruptions, teardown, waiting, flags) ship first. The tones are part of the core: they are the only audible cue for Listening and Sending, so they ship with PR 2 and are not cuttable. The turn list and the "Speak replies" switch are the last PR and can be cut without weakening the rules; cutting them amends the spec in the same PR (the "Speak replies" sentences in "Speaking the reply", and the call view's turn list). The GPT-Live note stays (a read and a line).

### Invariants touched

- API layering: REST through the generated client; sockets opened like `/api/ws`; no `packages/hermes_api` change.
- Privacy: events and breadcrumbs carry fixed words, flags, buckets. Audio is written only to temporary files that are deleted after use (the device recognizer's `transcribeFile` WAV and the speech-fallback decoder's files).
- Auth: the call never signs the user out and ends on sign-out.
- Chat: voice turns are ordinary messages; End leaves the thread intact.
- App Lock: it never ends a call; under it the call screen, strip and notices show no words, and the lock cover keeps a "Hands-free on" mark with End.

## Risks / Trade-offs

- **Echo on Android speakers** could trigger barge-in, so it is off until verified. When enabled: AEC, a raised trigger during playback, grace after playback, the echo guard, `voice.barge_in`.
- **Hermes' interrupted latch** can annotate another session's turn (see the backend facts); mitigated by sending the flag sparingly, and an upstream request.
- **`record` and SoLoud contend for the audio session** on Android. Configure `audio_session` once before either starts.
- **A call that ends on background surprises Android users.** The start screen says so.
- **A desktop lock is not observed.** Capture is open only while Listening there, so the exposure is at most 5 minutes after the last speech or the end of a reply; the OS indicator shows it.
- **Consent fatigue.** One tap per call; a "ask each call" preference is a later change, never default on.
- **Tones may be inaudible on a muted device.** The visible state is primary.
- **Linux audio** may be absent; the check fails and Start is unavailable.

## Design pass

Canvas and decisions: `docs/design-briefs/voice-conversation.md`. At the largest text size the start screen scrolls with the consent switch and "Start call" pinned at the bottom; the strip drops its second half instead of wrapping.
