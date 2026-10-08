# Spec Delta

## Purpose

Lets the user hold a hands-free spoken conversation with the agent. The app listens, sends what was said as a chat prompt, speaks the reply as it streams, and lets the user interrupt by speaking or tapping.

## ADDED Requirements

### Requirement: Voice availability

The composer SHALL show a "Start voice" toggle only when the chat's profile has compatible voice models. All three of these SHALL hold:

- Speech-to-text is usable, by the same rule as dictation.
- Text-to-speech is usable: `GET /api/audio/voice-config` answered, and `tts.reason` is not `no credentials`.
- The `voice_chat` slot in `GET /api/model/auxiliary?profile=<profile>` resolves to a model: either the slot names a model, or it follows the main model and `main.model` is set.

When any request fails or answers 404, the toggle SHALL be hidden. The app SHALL check again when the profile changes, when the app reconnects or comes back to the foreground, and after the user changes a helper model.

#### Scenario: Compatible models

- **WHEN** voice-config reports usable speech-to-text and text-to-speech, and `voice_chat` follows a main model `claude-sonnet`
- **THEN** the composer shows the Start voice toggle

#### Scenario: No text-to-speech credentials

- **WHEN** voice-config reports `tts.reason` `no credentials`
- **THEN** the Start voice toggle is hidden, and dictation is still offered if speech-to-text is usable

#### Scenario: Server without a voice_chat slot

- **WHEN** `/api/model/auxiliary` lists no `voice_chat` task
- **THEN** the Start voice toggle is hidden

### Requirement: Call screen

Starting voice SHALL open a call screen over the current chat. A new chat SHALL be started first when none is open. The screen SHALL show:

- An orb whose state is `connecting` while the microphone and sockets open, `muted` while the microphone is muted, and otherwise `listening` or `speaking`. Its motion scales with the live input or output level.
- A caption naming the turn ("Listening", "Thinking", "Speaking"), with a hint.
- The last two turns of this call, tagged as user or assistant.
- A mute toggle and an "End" button.

Tapping the orb, labelled "Interrupt the assistant", SHALL be enabled only while the agent is speaking. Ending the call SHALL close the screen and leave the thread with every spoken turn and reply as ordinary messages. A recording indicator SHALL be visible whenever the microphone is open.

#### Scenario: Call opens

- **WHEN** the user taps Start voice in a chat
- **THEN** the call screen shows the orb in `connecting`, then in `listening` with the caption "Listening"

#### Scenario: Call ends

- **WHEN** the user taps End
- **THEN** the microphone closes, speech stops, the screen closes, and the thread shows the call's turns as messages

#### Scenario: Mute

- **WHEN** the user mutes during a call
- **THEN** the orb shows `muted`, no audio is captured or sent, and speech playback continues

### Requirement: Listening turn

While listening, the app SHALL capture microphone audio and detect speech from its level. After speech was heard, a continuous pause of the profile's `voice.silence_duration` SHALL end the turn. When the profile leaves that value at Hermes' default of 3.0 s, the pause SHALL be 1.25 s. A turn SHALL also end after 60 s of speech. The turn's audio SHALL be transcribed as dictation does: live over `transcribe-stream` when `stt.streaming` is true, falling back to `POST /api/audio/transcribe`. The live transcript SHALL show as the user turn's caption. A turn with no detected speech, or an empty transcript, SHALL NOT be sent, and listening SHALL resume.

#### Scenario: Pause ends the turn

- **WHEN** the user says "remind me at five" and stays silent for 1.25 s
- **THEN** the app stops the turn, transcribes it and sends "remind me at five"

#### Scenario: Silence only

- **WHEN** nothing louder than the noise floor is heard
- **THEN** nothing is sent and the orb stays `listening`

### Requirement: Stop phrases

The app SHALL compare each transcript with the stop phrases before sending it. The comparison SHALL use the transcript normalized with NFKC, lowercased and stripped of punctuation, after removing a leading "hey hermes", "hermes", "ok" or "hey". The phrases SHALL be the profile's `voice.stop_phrases` when set; an empty list turns stop phrases off. Without that setting, the app SHALL use the built-in list: stop, stop listening, stop it, stop please, please stop, stop stop, that is all, never mind, nevermind, end conversation, end the conversation, goodbye, good bye, bye, cancel. A match SHALL end the call without sending anything.

#### Scenario: Saying goodbye

- **WHEN** the user says "Hey Hermes, goodbye."
- **THEN** the call ends and nothing is sent

### Requirement: Speaking the reply

When "Speak replies" is on (the default), the app SHALL speak each reply of the call while it streams.

- It SHALL open the `/api/audio/speak-stream` socket when the reply starts, authenticated like `/api/ws` with `profile` in the query.
- It SHALL send the reply's new text as `{"text": …}` frames while it arrives, including text sealed before a tool call, and `{"done": true}` when the reply ends.
- It SHALL play the binary 16-bit mono PCM frames at the rate given by the `{"type":"start","sample_rate":N}` frame, without gaps, from the first frame on.
- On `{"type":"end"}` and the end of playback, listening SHALL resume.
- On `{"type":"fallback"}`, or a socket that fails before any audio, the app SHALL synthesize the reply with `POST /api/audio/speak` (`{"text": …}`, answered `{ok, data_url, mime_type}`) and play the returned audio.
- A socket that fails after audio has started SHALL count as finished speaking.

With "Speak replies" off, listening SHALL resume when the reply ends. A reply with nothing to speak (only tool calls, or a failure) SHALL also resume listening.

#### Scenario: Speech overlaps generation

- **WHEN** Hermes streams a two-sentence reply
- **THEN** the first sentence plays before the reply has finished streaming

#### Scenario: Server cannot stream speech

- **WHEN** speak-stream answers `{"type":"fallback"}`
- **THEN** the app plays the audio from `POST /api/audio/speak` for the reply text

### Requirement: Interrupting the agent

Tapping the orb while the agent speaks SHALL stop playback at once and send `{"stop": true}` on the speak socket. When the reply is still streaming, it SHALL also stop the reply. Listening SHALL then resume.

Barge-in SHALL be on only when the profile's `voice.barge_in` is not false and the platform cancels echo (iOS and Android). When on, the microphone SHALL stay open while the agent thinks and speaks. Speech above a trigger level derived from the measured noise floor, and raised during playback, SHALL interrupt as a tap does. That speech SHALL then be captured as the next turn and sent with `interrupted: true`. A barge-in transcript whose similarity to the reply text being spoken is 0.6 or higher SHALL be treated as echo and ignored. On macOS, Windows and Linux the orb tap is the only way to interrupt.

#### Scenario: Tap to interrupt

- **WHEN** the agent is speaking and the user taps the orb
- **THEN** playback stops within 100 ms, the orb shows `listening`, and the next turn is sent with `interrupted: true`

#### Scenario: Speaking over the agent on a phone

- **WHEN** barge-in is on and the user starts talking while Hermes speaks
- **THEN** speech stops, the running reply is stopped, and what the user said is sent with `interrupted: true`

#### Scenario: Echo ignored

- **WHEN** a barge-in transcript closely repeats the sentence being played
- **THEN** nothing is sent and the call carries on

### Requirement: Call lifecycle

The call SHALL end when the user taps End, a stop phrase is heard, the app leaves the foreground, the chat's profile changes, the user opens another chat, or the microphone fails twice in a row. When the call ends, the app SHALL close the microphone and both audio sockets, stop playback, and release its leases. Text-to-speech and speech-to-text warm-up leases (`POST /api/audio/tts-lease` and `stt-lease`, `{"lease": "app:conversation:<id>", "active": …}`) SHALL be held while the call is open; their failure SHALL NOT affect the call. A typed message sent during a call SHALL be sent as a typed prompt, and its reply SHALL be spoken.

#### Scenario: App backgrounded

- **WHEN** the user leaves the app during a call
- **THEN** the call ends and the thread keeps every completed turn

### Requirement: GPT-Live profiles

When `GET /api/audio/voice-live/status` reports `mode: "gpt-live"`, the app SHALL still run the chained call. The call screen SHALL say that this app uses the standard voice chat.

#### Scenario: Profile set to GPT-Live

- **WHEN** the profile's voice chat mode is `gpt-live`
- **THEN** the call runs the listen, send and speak loop and shows the note

### Requirement: Backend contract

Voice conversation SHALL rely only on these Hermes Agent routes and methods, present since Hermes v2026.9.11 unless noted:

- The dictation routes (`transcribe-stream` and `stt-lease` since v0.21.6).
- `GET /api/model/auxiliary` (`{tasks: [{task, provider, model, base_url, …}], main: {provider, model}}`).
- `GET /api/audio/voice-live/status` (`{ok, mode, available, …}`).
- The `/api/audio/speak-stream` WebSocket (protocol above).
- `POST /api/audio/speak` (`{ok, data_url, mime_type, provider}`).
- `POST /api/audio/tts-lease`.
- The `voice` section of `GET /api/config` (`silence_duration`, `stop_phrases`, `barge_in`).
- `prompt.submit` with `voice_turn` and `interrupted`.

Missing `voice` keys SHALL take Hermes' defaults.

#### Scenario: Profile without a voice section

- **WHEN** the profile's config has no `voice` section
- **THEN** the call uses a 1.25 s pause, the built-in stop phrases, and barge-in where the platform allows it
