# Spec Delta

## Purpose

A hands-free spoken conversation with the agent: the app listens, sends what was said as a chat prompt, speaks the reply as it streams, and lets the user stop at any moment. Hands-free sending is never on unless the user turned it on for that conversation.

## ADDED Requirements

### Requirement: Voice availability

The app SHALL offer "Start voice call" in a chat's header only when the chat's profile has speech-to-text (the dictation rule), text-to-speech (`GET /api/audio/voice-config` answered and `tts.reason` is not `no credentials`) and a `voice_chat` slot in `GET /api/model/auxiliary` that names a model or follows a main model that is set. A failed or 404 read SHALL hide the button. It SHALL be read again on profile change, reconnect, foreground and after a helper model changes.

#### Scenario: Compatible models

- **WHEN** voice-config reports usable speech-to-text and text-to-speech, and `voice_chat` follows a main model
- **THEN** the header shows "Start voice call"

#### Scenario: No text-to-speech credentials

- **WHEN** voice-config reports `tts.reason` `no credentials`
- **THEN** the button is hidden and dictation is still offered

### Requirement: Hands-free consent

Before a call opens the microphone, the start screen SHALL state that Hermes will send what the user says after each pause, without the user pressing send, and that the agent may act on it with its tools. The call SHALL start only after the user turns on "Send what I say automatically" for that call. The choice SHALL NOT be remembered, defaulted on, or carried to another call, chat or profile.

#### Scenario: Consent off

- **WHEN** the user opens the start screen and has not turned the switch on
- **THEN** "Start call" is disabled, the microphone stays closed, and "Use dictation instead" is offered

#### Scenario: Next call asks again

- **WHEN** the user ends a call and starts another
- **THEN** the switch is off again

### Requirement: Visible and audible state

The call screen SHALL show the state in words and an icon, never by colour or motion alone: Connecting, Listening, Muted, Sending, Thinking, Speaking, Waiting for you, Stopped. A "Hands-free on" strip with a recording dot SHALL show whenever the microphone is open. Each return to Listening and each send SHALL play a short tone, the end a falling tone; Speaking is the voice itself. Mobile adds a haptic tick. State changes SHALL be announced to screen readers.

#### Scenario: A turn is sent

- **WHEN** the user pauses after "remind me at five"
- **THEN** the screen shows "Sending" with the words, a tone plays, then it shows "Thinking"

#### Scenario: Screen reader

- **WHEN** the state changes from Listening to Speaking
- **THEN** a screen reader announces "Hermes is speaking"

### Requirement: Stopping at any moment

The user SHALL be able to stop the conversation at any moment by End, a stop phrase, or the platform's hang-up control. Mute SHALL stop capture without ending the call. End or mute before a turn was submitted SHALL discard that turn and send nothing. End SHALL stop speech and the reply this call's turn is still writing.

#### Scenario: End while sending

- **WHEN** the user taps End while the words are being transcribed
- **THEN** nothing is sent and the call closes

#### Scenario: Mute

- **WHEN** the user mutes
- **THEN** the screen shows Muted, no audio is captured or sent, and speech playback continues

### Requirement: Listening turn

The app SHALL detect speech from the microphone level and end the turn after a pause: 0.9 s by default, or the profile's `voice.silence_duration` when set to something other than Hermes' default of 3.0 (limited to 0.5 to 3 s). A turn SHALL end after 60 s. The audio SHALL be transcribed as dictation does (the device recognizer where chosen, else Hermes). A turn with no speech or an empty transcript SHALL NOT be sent, and listening SHALL resume.

#### Scenario: Pause ends the turn

- **WHEN** the user says "remind me at five" and stays silent for the pause
- **THEN** the words are transcribed and sent once

#### Scenario: Silence only

- **WHEN** nothing above the noise floor is heard
- **THEN** nothing is sent and the state stays Listening

### Requirement: Failed transcription

A turn whose transcription fails or times out SHALL NOT be sent, in whole or in part. The screen SHALL show "Couldn't hear that. Nothing was sent." and listening SHALL resume. A second failure in a row SHALL end the call with that notice. The failed audio SHALL be dropped, not kept.

#### Scenario: Transcription fails

- **WHEN** the transcription of a turn fails
- **THEN** nothing is sent, the notice shows, and the call listens again

#### Scenario: Two failures

- **WHEN** two turns in a row fail to transcribe
- **THEN** the call ends and the screen says nothing was sent

### Requirement: Stop phrases

Each transcript SHALL be compared with the stop phrases before it is sent, after NFKC normalization, lowercasing, removing punctuation and a leading "hey hermes", "hermes", "ok" or "hey". The phrases are the profile's `voice.stop_phrases`, else: stop, stop listening, stop it, please stop, that is all, never mind, end conversation, goodbye, bye, cancel, hang up, end call. A match SHALL end the call and send nothing. An empty profile list leaves only the End button.

#### Scenario: Goodbye

- **WHEN** the user says "Hey Hermes, goodbye."
- **THEN** the call ends and nothing is sent

### Requirement: Speaking the reply

With "Speak replies" on (the default), the app SHALL speak the reply while it streams over `/api/audio/speak-stream`: new reply text (sealed prose included, reasoning and media paths excluded), then `done`, and the 16-bit mono PCM played from the first frame. On `fallback`, or a failure before any audio, it SHALL use `POST /api/audio/speak` once. A failure after audio began counts as finished. With it off, or with nothing to speak, listening SHALL resume when the reply ends.

#### Scenario: Speech overlaps generation

- **WHEN** Hermes streams a two-sentence reply
- **THEN** the first sentence plays before the reply has finished

#### Scenario: Server cannot stream

- **WHEN** speak-stream answers `{"type":"fallback"}`
- **THEN** the reply is synthesized once with `POST /api/audio/speak` and played

### Requirement: Interrupting the agent

Tapping the orb while the agent speaks SHALL stop playback at once, stop the reply if still being written, and resume listening. Where the platform cancels echo (iOS, Android) and the profile's `voice.barge_in` is not false, speech over the agent SHALL do the same and the next turn SHALL carry `interrupted: true`. A barge-in transcript 0.6 or more similar to the reply being spoken SHALL be ignored as echo. Elsewhere the microphone SHALL stay closed while Hermes speaks.

#### Scenario: Tap to interrupt

- **WHEN** the agent speaks and the user taps the orb
- **THEN** speech stops within 100 ms and the state is Listening

#### Scenario: Desktop has no barge-in

- **WHEN** Hermes speaks on a Mac
- **THEN** the microphone is closed until the speech ends or the orb is tapped

### Requirement: Interruptions

A system interruption (phone call, alarm, another app taking the audio) SHALL end the call and say so. A route change (headset, Bluetooth, speaker) SHALL discard the turn being heard, say so, and resume listening on the new route. The call SHALL NOT resume by itself after an interruption. A turn already submitted stays in the chat.

#### Scenario: Incoming phone call

- **WHEN** a phone call takes the audio during a call
- **THEN** the microphone closes, the call ends with "The call was interrupted", and nothing more is sent

#### Scenario: Headphones unplugged

- **WHEN** the route changes while the user speaks
- **THEN** the unfinished turn is dropped, nothing is sent, and listening resumes

### Requirement: Background, lock and idle

Where the platform keeps the call's audio alive in the background (iOS, through its system call), locking or leaving the app SHALL NOT end it. Elsewhere, leaving the foreground or locking the screen SHALL end the call. On every platform a call SHALL end after 5 minutes in which no speech was heard and no reply was running, and say so.

#### Scenario: Android app backgrounded

- **WHEN** the user switches to another app during a call on Android
- **THEN** the call ends, the microphone closes, and the thread keeps every submitted turn

#### Scenario: Nobody speaks

- **WHEN** 5 minutes pass with no speech and no running reply
- **THEN** the call ends with "Stopped: no one spoke for 5 minutes"

### Requirement: Microphone closed on every exit

On every way a call ends (End, stop phrase, interruption, error, sign-out, profile or chat change, idle, disposal), the app SHALL close the microphone first, then close both audio sockets, stop playback, release the audio session and release the leases. A failure while closing one SHALL NOT keep another open.

#### Scenario: Speech socket fails during teardown

- **WHEN** closing the speech socket throws
- **THEN** the microphone and the audio session are still closed

### Requirement: Requests stay in the chat

A spoken turn SHALL NOT answer or approve a request (approval, clarify, sudo, secret). When the agent waits for one, the call SHALL say "Waiting for you in the chat", and the user answers there.

#### Scenario: Approval needed

- **WHEN** the agent asks to approve a command during a call
- **THEN** the call says it is waiting in the chat, and "yes" spoken aloud approves nothing

### Requirement: Platforms

The conversation SHALL run on iOS (system call and native audio engine, as today), Android, macOS, Windows and Linux, all through one loop and one audio seam for capture and playback. It SHALL NOT be offered in conversation windows or on watchOS. A platform that cannot open the microphone or the audio output SHALL NOT show the call button.

#### Scenario: Linux without audio output

- **WHEN** the audio output cannot be opened on Linux
- **THEN** the call button is hidden

### Requirement: GPT-Live profiles

When `GET /api/audio/voice-live/status` reports `mode: "gpt-live"`, the app SHALL still run the chained call, and the start screen SHALL say so.

#### Scenario: Profile set to GPT-Live

- **WHEN** the profile's voice chat mode is `gpt-live`
- **THEN** the call runs the chained loop and the start screen shows the note

### Requirement: Backend contract

Voice conversation SHALL rely only on the dictation routes, `GET /api/model/auxiliary`, `GET /api/audio/voice-live/status`, the `/api/audio/speak-stream` socket (`start`, PCM, `end`, `fallback`; `text`, `done`, `stop`), `POST /api/audio/speak`, `POST /api/audio/tts-lease`, the `voice` section of `GET /api/config`, and `prompt.submit` with `voice_turn` and `interrupted`. A missing `voice` key SHALL take the default stated here.

#### Scenario: Profile without a voice section

- **WHEN** the profile's config has no `voice` section
- **THEN** the call uses the default pause, the built-in stop phrases, and barge-in where the platform allows it

### Requirement: Telemetry

The call SHALL log `voice_call.readiness`, `voice_call.connected` and one `voice_call.ended` (`outcome`, `reason`, `step`, `error_type`, `connected`, bucketed `turns`, `speech_fallbacks`, `duration`), plus breadcrumbs of fixed names, counts and flags. None SHALL carry speech, a transcript, reply text, a URL, a ticket or an id.

#### Scenario: Call ended

- **WHEN** a call ends by a stop phrase
- **THEN** `voice_call.ended` records `reason` and buckets and no words
