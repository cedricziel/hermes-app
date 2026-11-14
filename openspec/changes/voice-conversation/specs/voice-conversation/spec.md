# Spec Delta

## Purpose

A hands-free spoken conversation with the agent: the app listens, sends what was said as a chat prompt, speaks the reply as it streams, and lets the user stop at any moment. Hands-free sending is never on unless the user turned it on for that conversation.

## ADDED Requirements

### Requirement: Availability and readiness

The chat header SHALL offer "Start voice call" on iOS, Android, macOS, Windows and Linux whenever the chat can send (not in conversation windows, bot chats or the web). Whether the call can start SHALL be decided by the start screen's checks (microphone, speech recognition, Hermes speech, audio output, `voice_chat` model). A failed or 404 voice-model read SHALL be a warning, not a block.

#### Scenario: Speech not set up

- **WHEN** voice-config reports `tts.reason` `no credentials`
- **THEN** the button is still offered, the start screen shows the problem with its fix actions, and Start call stays unavailable

#### Scenario: Older server

- **WHEN** `/api/model/auxiliary` answers 404
- **THEN** the voice model row says "Couldn't check" and the call can start

### Requirement: Hands-free consent

Before a call opens the microphone, the start screen SHALL state that Hermes will send what the user says after each pause, without the user pressing send, and that the agent may act on it with its tools. The call SHALL start only after the user turns on "Send what I say automatically" for that call. The choice SHALL NOT be remembered, defaulted on, or carried to another call, chat or profile. "Start a new call" opens the start screen with the switch off.

#### Scenario: Consent off

- **WHEN** the user opens the start screen and has not turned the switch on
- **THEN** "Start call" is disabled, the microphone stays closed, and "Use dictation instead" is offered

#### Scenario: Next call asks again

- **WHEN** the user ends a call and starts another
- **THEN** the switch is off again

### Requirement: Visible and audible state

The call screen SHALL show the state in words and an icon, never by colour or motion alone: Connecting, Listening, Muted, Sending, Thinking, Speaking, Waiting for you, Stopped. A "Hands-free on" strip with a recording dot SHALL show on every screen while the microphone is open. Each return to Listening and each submit SHALL play a short tone, the end a falling tone; Speaking is the voice. Mobile adds a haptic tick. State changes SHALL be announced to screen readers.

#### Scenario: A turn is sent

- **WHEN** the user pauses after "remind me at five"
- **THEN** the screen shows "Sending" with the words, then "Thinking" and a tone when the prompt is submitted

#### Scenario: Screen reader

- **WHEN** the state changes from Listening to Speaking
- **THEN** a screen reader announces "Hermes is speaking"

### Requirement: Stopping at any moment

The user SHALL be able to stop the call at any moment by End, a stop phrase, or the platform's hang-up. Mute SHALL stop capture without ending the call. "Sending" lasts from the end of speech until `ChatController.submit` is called; End or mute in that time SHALL discard the turn and send nothing, and the mute SHALL be checked again just before the submit. After the submit the prompt stays in the chat; End then stops speech and this turn's reply.

#### Scenario: End while sending

- **WHEN** the user taps End while the words are being transcribed
- **THEN** nothing is sent and the call closes

#### Scenario: Mute while the speech socket opens

- **WHEN** the user mutes after the transcript arrived and before the submit
- **THEN** the turn is not submitted

### Requirement: Listening turn

The app SHALL detect speech from the microphone level and end the turn after a pause of 0.9 s, or the profile's `voice.silence_duration` when it is neither unset nor Hermes' default 3.0 (limited to 0.5 to 3 s). A turn SHALL end after 60 s. The audio SHALL be transcribed as dictation does. A transcript that is empty or a known Whisper hallucination on silence ("Thank you.", "Bye", repeats of them) SHALL NOT be sent and listening SHALL resume.

#### Scenario: Pause ends the turn

- **WHEN** the user says "remind me at five" and stays silent for the pause
- **THEN** the words are transcribed and sent once

#### Scenario: Near silence

- **WHEN** the recognizer answers "Thank you." for room noise
- **THEN** nothing is sent and the state stays Listening

### Requirement: Content the user did not say

Where the platform has no echo cancellation (macOS, Windows, Linux), capture SHALL be paused while a tone or the reply plays and SHALL resume 400 ms after the audio drained. On every platform the first transcript after playback that is 0.6 or more similar to the reply just spoken SHALL be treated as echo and not sent.

#### Scenario: Tone and speech are not heard

- **WHEN** a tone plays or Hermes speaks on a Mac
- **THEN** the microphone captures none of it and no turn is made from it

### Requirement: Failed transcription

A turn whose transcription fails or times out SHALL NOT be sent, in whole or in part. The screen SHALL show "Couldn't hear that. Nothing was sent." and listening SHALL resume. A second failure in a row SHALL end the call with that notice. The failed audio SHALL be dropped, not kept.

#### Scenario: Transcription fails

- **WHEN** the transcription of a turn fails
- **THEN** nothing is sent, the notice shows, and the call listens again

#### Scenario: Two failures

- **WHEN** two turns in a row fail to transcribe
- **THEN** the call ends and the screen says nothing was sent

### Requirement: Stop phrases

Each transcript SHALL be compared with the stop phrases before it is sent, after lowercasing, trimming surrounding punctuation and a leading "hey hermes", "hermes", "ok" or "hey". A match SHALL end the call and send nothing. An empty profile list leaves only End.

#### Scenario: Goodbye

- **WHEN** the profile has Hermes' default list and the user says "Hey Hermes, goodbye."
- **THEN** the call ends and nothing is sent

### Requirement: Stop phrase list

The phrases SHALL be the profile's `voice.stop_phrases`, except that an unset list, or exactly Hermes' default `["stop"]` (which `GET /api/config` returns for an unset key), SHALL mean the built-in list: stop, stop listening, stop it, please stop, that is all, never mind, end conversation, end the call, goodbye, bye, cancel, hang up, end call.

#### Scenario: Profile list

- **WHEN** the profile lists only "enough"
- **THEN** "enough" ends the call and "goodbye" is sent as a turn

#### Scenario: Default list

- **WHEN** the profile's list is `["stop"]` and the user says "end the call"
- **THEN** the call ends and nothing is sent

### Requirement: Speaking the reply

With "Speak replies" on (the default), the app SHALL speak this call's reply while it streams over `/api/audio/speak-stream`: new reply text (sealed prose included, reasoning and media paths excluded), then `done`, and the 16-bit mono PCM played from the first frame. With it off, or with nothing to speak, listening SHALL resume when the reply ends. A reply to a typed message is not spoken.

#### Scenario: Speech overlaps generation

- **WHEN** Hermes streams a two-sentence reply
- **THEN** the first sentence plays before the reply has finished

### Requirement: Speech fallback

On `fallback`, or a socket failure before any audio, the app SHALL synthesize the reply once with `POST /api/audio/speak` and play it. A failure after audio began SHALL count as finished speaking, not as a call failure.

#### Scenario: Server cannot stream

- **WHEN** speak-stream answers `{"type":"fallback"}`
- **THEN** the reply is synthesized once with `POST /api/audio/speak` and played

### Requirement: Interrupting the agent

Tapping the orb while the agent speaks SHALL stop playback and listen. The first spoken turn after an orb tap or a barge-in SHALL carry `interrupted: true`, and later turns SHALL NOT. Where the platform has no echo cancellation the microphone is closed while Hermes speaks, and the stall watchdog is suspended meanwhile.

#### Scenario: Tap to interrupt

- **WHEN** the agent speaks and the user taps the orb
- **THEN** speech stops within 100 ms, the state is Listening, and the next turn carries `interrupted: true`

### Requirement: Barge-in

Where the platform cancels echo (iOS, Android) and `voice.barge_in` is not false, speech over the agent SHALL stop playback at its onset. The running reply SHALL be stopped only when the resulting turn is about to be submitted; echo or an empty transcript leaves it running, unspoken, in the chat.

#### Scenario: Echo on a phone

- **WHEN** speech onset is the reply's own echo and the transcript repeats it
- **THEN** nothing is sent, the reply is still in the chat, and its speech stays stopped

#### Scenario: Desktop is quiet while speaking

- **WHEN** Hermes speaks for 30 s on a Mac
- **THEN** the call does not end with "The microphone stopped"

### Requirement: Waiting for you

While the agent waits for an approval or question, capture SHALL be paused and nothing the user says SHALL interrupt the turn or be sent. The call SHALL say "Waiting for you in the chat" and resume listening when the request is answered or closed. A spoken turn SHALL NOT answer or approve a request.

#### Scenario: Approval pending

- **WHEN** the agent asks to approve a command and the user says "yes"
- **THEN** the turn is not interrupted, nothing is sent, and nothing is approved

### Requirement: Interruptions

A system interruption SHALL end the call and say so. On Android a permanent or transient audio-focus loss (a call, an alarm, a navigation prompt) ends it, and a request to duck does not. A route change SHALL discard the turn being heard, say "Audio route changed. Please repeat if needed. Nothing was sent.", and resume listening. The call SHALL NOT resume by itself after an interruption. A submitted turn stays in the chat.

#### Scenario: Incoming phone call

- **WHEN** a phone call takes the audio during a call
- **THEN** the microphone closes, the call ends with "The call was interrupted", and nothing more is sent

#### Scenario: Notification sound on Android

- **WHEN** a notification asks the audio to duck
- **THEN** the call continues

### Requirement: Background, lock and idle

Where the platform keeps the call's audio alive in the background (iOS, through its system call), locking or leaving the app SHALL NOT end it. On Android, leaving the foreground or locking SHALL end it. On macOS, Windows and Linux, hiding or minimising the app SHALL end it, but a screen lock is not observed: the call continues until the idle limit, which is a platform limit. On every platform a call SHALL end after 5 minutes without speech and without a running reply, and say so.

#### Scenario: Android app backgrounded

- **WHEN** the user switches to another app during a call on Android
- **THEN** the call ends, the microphone closes, and the thread keeps every submitted turn

#### Scenario: Desktop locked

- **WHEN** a Mac is locked during a call and nobody speaks
- **THEN** the call ends after 5 minutes and says no one spoke

### Requirement: Microphone closed on every exit

On every way a call ends (End, stop phrase, interruption, error, sign-out, profile or chat change, idle, disposal), the app SHALL stop capture first, then close the speech socket, stop playback, release the audio session and the `tts-lease` if held. Each step SHALL have its own timeout and a failure or hang in one SHALL NOT skip another. An End while capture is still starting SHALL cancel the start and close capture when it resolves.

#### Scenario: Speech socket hangs during teardown

- **WHEN** closing the speech socket does not answer
- **THEN** after its timeout the audio session is still released and capture is already closed

#### Scenario: End while the microphone opens

- **WHEN** the user ends the call while capture is starting
- **THEN** capture is closed as soon as it started, and nothing is recorded

### Requirement: Platforms

The conversation SHALL run on iOS (system call and native audio engine), Android, macOS, Windows and Linux through one loop and one audio seam for capture, playback, mute, route and end. It SHALL NOT be offered in conversation windows or on watchOS. A platform whose microphone or audio output cannot be opened SHALL fail the matching start-screen check. Speaker routing is iOS and Android; desktop uses the system's output.

#### Scenario: Linux without audio output

- **WHEN** the audio output cannot be opened on Linux
- **THEN** the start screen's audio output check fails and Start call is unavailable

### Requirement: GPT-Live profiles

When `GET /api/audio/voice-live/status` reports `mode: "gpt-live"`, the app SHALL still run the chained call, and the start screen SHALL say so.

#### Scenario: Profile set to GPT-Live

- **WHEN** the profile's voice chat mode is `gpt-live`
- **THEN** the call runs the chained loop and the start screen shows the note

### Requirement: Backend contract

Voice conversation SHALL rely only on the dictation routes, `GET /api/model/auxiliary`, `GET /api/audio/voice-live/status`, the `/api/audio/speak-stream` socket (`start`, PCM, `end`, `fallback`; `text`, `done`, `stop`), `POST /api/audio/speak`, `POST /api/audio/tts-lease`, the `voice` section of `GET /api/config` (which returns Hermes' defaults for keys the profile did not set), and `prompt.submit` with `voice_turn` and `interrupted`.

#### Scenario: Profile without a voice section

- **WHEN** the profile's config has no `voice` section
- **THEN** the call uses the default pause, the built-in stop phrases, and barge-in where the platform allows it

### Requirement: Telemetry

The call SHALL log `voice_call.readiness`, `voice_call.connected` and one `voice_call.ended` (`outcome`, `reason`, `step`, `error_type`, `connected`, bucketed `turns`, `speech_fallbacks`, `duration`), plus breadcrumbs of fixed names, counts and flags. None SHALL carry speech, a transcript, reply text, a URL, a ticket or an id.

#### Scenario: Call ended

- **WHEN** a call ends by a stop phrase
- **THEN** `voice_call.ended` records `reason` stop_phrase and buckets and no words

#### Scenario: Reason words

- **WHEN** a call ends
- **THEN** `reason` is one of hang_up, stop_phrase, app, background, idle, transcription, interrupted, focus_lost, prepare, native_start, connect, microphone_stalled, native_error, speech, turn or mute
