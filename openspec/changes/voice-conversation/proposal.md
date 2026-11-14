## Why

Dictation (`voice-dictation`) needs hands and eyes: the user taps, reads the transcript and sends. A hands-free conversation lets the user talk to Hermes while walking or cooking. Hermes already runs this loop for its desktop app (spoken turns run on the profile's fast `voice_chat` model route; speech streams back sentence by sentence).

Since this change was first written, iOS got a native voice call that is not specified anywhere (`lib/src/voice/calls/`, `packages/hermes_calls`, `docs/voice-calls.md`): CallKit, a voice-processing audio graph, a readiness check, a 900 ms pause, barge-in and the `speak-stream` socket. This change now specifies that call for every platform, adds the rules it lacks, and extends it to Android, macOS, Windows and Linux through the same loop. It replaces the original plan for a second loop controller, a second activity detector and a composer toggle.

## What Changes

- **Reuse the shipped loop.** `VoiceCall`, `VoiceActivity`, `CallSpeechStream` and `ChatCallAgent` stay the one implementation. `CallBridge`, today `AppleCallBridge`, becomes the platform audio seam (capture, playback, mute, route, end). A portable bridge for Android, macOS, Windows and Linux is built on `record` (capture) and `flutter_soloud` (PCM playback), with `audio_session` (already a dependency) on Android.
- **Hands-free consent, per call.** The start screen asks the user to turn on "Send what I say automatically" before the microphone opens. It is never remembered. Without it there is no call; dictation is offered instead.
- **State you can see and hear.** One orb, a state word with an icon, a "Hands-free on" strip with a recording dot, tones for listening, sent and ended, haptics on mobile and screen-reader announcements.
- **Stop at any moment.** End, mute, stop phrases (the profile's `voice.stop_phrases` or the built-in list), and the platform's hang-up. End or mute before a turn was submitted sends nothing.
- **Failed transcription sends nothing.** The turn is dropped with "Couldn't hear that. Nothing was sent."; two in a row end the call. (Today a failure ends the call at once.)
- **Interruptions and exits.** A system interruption ends the call; a route change drops the turn being heard and resumes. Background and lock end the call except on iOS, where the system call keeps the audio alive. Five minutes without speech end it. The microphone is closed first on every exit.
- **Voice turns are marked** (`prompt.submit` with `voice_turn: true`, and `interrupted: true` after a barge-in), so Hermes runs them on the `voice_chat` model route. Availability needs that slot to resolve (`GET /api/model/auxiliary`) as well as speech-to-text and text-to-speech (`GET /api/audio/voice-config`).
- **Call screen additions:** the last two turns, a "Speak replies" switch (on by default), tap the orb to interrupt, and the stopped and failed notices.
- **Entry point:** the header's "Start voice call" button that iOS has today, on every platform that passes the availability rule. No composer toggle.

## Capabilities

### New Capabilities

- `voice-conversation`: the hands-free spoken conversation, including consent, state, stopping, turn-taking, speech playback, interruption and platform limits.

### Modified Capabilities

- `chat`: a submitted prompt can be marked as a voice turn and as interrupting the previous reply.

## Impact

- Code: `lib/src/voice/calls/` gains consent, the stop-phrase matcher, the echo guard, tones, the idle limit, a transcription-failure path and the portable bridge (`record` plus `flutter_soloud`). `ChatController.submit` and `ChatTransport.send` gain `voiceTurn` and `interrupted`. Widgets in `lib/src/voice/widgets/`: `VoiceOrb` and the extended call view, start view and notices.
- Dependencies: `flutter_soloud` (new; streaming PCM on all five platforms). `record` and `audio_session` are already in `pubspec.yaml`.
- Native: Android needs `MODIFY_AUDIO_SETTINGS`; Linux builds miniaudio (CI may need `libasound2-dev`; the `.deb` gains `libasound2 | libasound2t64`). iOS needs no change. No new permission beyond dictation's.
- API: no OpenAPI or OpenRPC change. At the pinned ref (`d923a5e`) `prompt.submit` already takes `voice_turn` and `interrupted` and answers `voice_stopped`; the generated client has `speak`, `tts-lease`, `voice-live/status` and `model/auxiliary`; `speak-stream` is a socket opened like `/api/ws`.

## Non-goals

- GPT-Live (`voice.voice_chat_mode: gpt-live`): the chained loop is always used and the start screen says so.
- Keeping a call alive in the background or locked on Android and desktop (a foreground service is a follow-up).
- Barge-in on macOS, Windows and Linux, where echo cancellation cannot be relied on: the microphone is closed while Hermes speaks and the orb tap interrupts.
- A wake word, `voice.toggle`/`voice.record`, client-direct speech providers, thinking sounds, reading one message aloud (already `read_aloud`), the Apple Watch and CarPlay (`docs/voice-calls.md`).
- Answering approvals or questions by voice.

## Security and privacy impact

The microphone is open for the whole call, longer than for dictation, and the transcript is sent without a press of send. That is why consent is per call and explicit, why the open microphone is always visible, why a failed or interrupted turn sends nothing, and why approvals stay in the chat. Audio goes only to the user's Hermes server (or the device recognizer) and is not written to disk; reply text goes back to the same server to be spoken. No new credential is stored.

## Telemetry

The existing `voice_call.readiness`, `voice_call.connected` and `voice_call.ended` events (fixed words, buckets), plus breadcrumbs `voice_call.opened`, `voice_call.consent` (flag only, no text), `voice_call.speech_fallback`. This replaces the first draft's `voice.conversation.*` names. Never speech, transcripts, reply text, URLs or ids.
