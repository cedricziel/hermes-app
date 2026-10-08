## Why

Dictation (`voice-dictation`) still needs hands and eyes: the user taps, reads the transcript and sends. A hands-free conversation lets the user talk to Hermes while walking or cooking. Hermes already runs this loop for its desktop app: it marks spoken turns so they run on the profile's fast voice model, and it streams speech back sentence by sentence while the reply is still being written. The app should offer the same.

## What Changes

- The controls follow assistant-ui's realtime voice elements (`VoiceOrb`, `VoiceControl`, `VoiceConversation`). A "Start voice" toggle in the composer opens a call screen over the current chat, and starts a new chat when none is open. The screen shows an orb that tracks who is talking (connecting, listening, speaking or muted, scaled by the live level), a caption that names the turn with a hint, the last two spoken turns, and buttons to mute and to end the call. While Hermes speaks, tapping the orb interrupts it. Spoken turns are ordinary chat messages, so they stay in the thread after the call ends.
- Availability depends on the profile's voice models. The toggle shows only when speech-to-text and text-to-speech are both usable (`GET /api/audio/voice-config`) and the `voice_chat` helper model slot resolves to a model (`GET /api/model/auxiliary`). A slot that follows the main model counts.
- Listening: the app records until the user stops talking. A pause of the length set by the profile's `voice.silence_duration` ends the turn, 1.25 s unless the profile changed it. The app transcribes the turn with the same routes as dictation. A turn with no speech is dropped and listening restarts.
- The transcript is sent as a normal prompt in the open chat, marked as a voice turn (`prompt.submit` with `voice_turn: true`). The turn and its reply appear in the chat like typed ones.
- Speaking: the reply text is streamed to `/api/audio/speak-stream` while it arrives, and the 16-bit PCM audio that comes back is played as it comes. When the socket offers no audio, the app falls back to `POST /api/audio/speak`. When the reply ends, listening starts again.
- Barge-in: when the profile allows it (`voice.barge_in`, default on) and the device cancels echo (iOS and Android), speaking over Hermes stops the speech, stops the reply if it is still being written, and sends what the user said with `interrupted: true`. A transcript that only repeats the reply being spoken is treated as echo and ignored.
- Saying a stop phrase ends the conversation without sending anything. The phrases come from the profile's `voice.stop_phrases`, or the built-in list when the profile sets none.
- A "Speak replies" switch on the call screen. With it off, the loop still listens and sends, but does not speak.
- The app warms the profile's text-to-speech engine while the call screen is open (`POST /api/audio/tts-lease`).

## Capabilities

### New Capabilities

- `voice-conversation`: the hands-free spoken conversation with the agent, including turn-taking, speech playback, barge-in and stop phrases.

### Modified Capabilities

- `chat`: a submitted prompt can be marked as a voice turn, and as interrupting the previous reply.

## Impact

- Code: `lib/src/voice/` gains the speech playback (speak-stream client, PCM player, fallback), voice-activity detection, the echo guard, stop phrases and a `VoiceConversationController`. It also gains the call screen and orb under `lib/src/voice/widgets/`. `ChatTransport.send` gains `voiceTurn` and `interrupted`, and `ChatComposer` gains the Start voice toggle. Voice availability is read from `voice-config` and `/api/model/auxiliary`.
- Dependencies: `flutter_soloud` (streaming PCM playback on all five platforms) and `audio_session` (the iOS and Android voice-chat audio session). It reuses `record` and the waveform from `voice-dictation`.
- Native: iOS and Android need the microphone and speaker routed for voice chat (the audio session, Bluetooth headsets). There is no new permission beyond `voice-dictation`'s.
- API: no OpenAPI change. The generated client has `speak`, `tts-lease`, `voice-live/status` and `model/auxiliary`. `speak-stream` is a socket opened like the dictation socket.
- Depends on `voice-dictation` (capture, the transcription socket, the microphone permission).

## Non-goals

- GPT-Live (`voice.voice_chat_mode: gpt-live`, WebRTC to OpenAI). The app always uses the chained loop and says so on the call screen when the profile is set to GPT-Live.
- Keeping the conversation alive with the app in the background or the screen locked (iOS background audio). The conversation pauses when the app leaves the foreground.
- Barge-in on macOS, Windows and Linux, where the app cannot rely on echo cancellation. On those platforms the user taps the orb to interrupt.
- A wake word, server-side voice mode (`voice.toggle`, `voice.record`) and the backend host's microphone.
- Client-direct speech providers from `voice-config`.
- Reading a single message aloud outside the conversation.
- Thinking sounds (`voice.thinking_sound`).
- The Apple Watch app and CarPlay.

## Security and privacy impact

The microphone is open for the whole conversation, which is longer than for dictation. A recording indicator is always visible, and the OS shows its own. Audio goes only to the user's Hermes server, as in `voice-dictation`, and nothing is written to disk. Reply text is sent back to the same server to be spoken. The speak-stream socket uses the existing single-use ticket or session token. No new credential is stored, and no provider keys are read.

## Telemetry

The feature records breadcrumbs only:

- `voice.conversation.started` and `voice.conversation.ended`, with `reason`: `user`, `stop_phrase`, `background`, `error`, `profile_change`.
- `voice.turn.sent`, with `interrupted` (bool).
- `voice.speech.fallback`, when speak-stream gave no audio.

They record counts and flags, never transcripts, reply text or audio.
