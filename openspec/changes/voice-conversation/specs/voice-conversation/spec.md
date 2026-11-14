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

The user SHALL be able to stop the call at any moment by End, a stop phrase, or the platform's hang-up. Mute SHALL stop capture without ending the call. "Sending" lasts from the end of speech until `submit` hands the prompt to the transport, which is after its queue restore; End or mute in that time SHALL discard the turn, the requested mute counting at once and not when the bridge confirms it. After the send the prompt stays in the chat; End then stops speech and this turn's reply.

#### Scenario: End while sending

- **WHEN** the user taps End while the words are being transcribed
- **THEN** nothing is sent and the call closes

#### Scenario: Mute while the speech socket opens

- **WHEN** the user mutes after the transcript arrived and before the submit
- **THEN** the turn is not submitted

### Requirement: Listening turn

The app SHALL detect speech from the microphone level and end the turn after a pause of 0.9 s, or the profile's `voice.silence_duration` when the profile sets one (limited to 0.5 to 3 s). A turn SHALL end after 60 s. The audio SHALL be transcribed as dictation does.

#### Scenario: Pause ends the turn

- **WHEN** the user says "remind me at five" and stays silent for the pause
- **THEN** the words are transcribed and sent once

### Requirement: Which transcripts are sent

A transcript SHALL be checked in this order, and the first match decides: empty (dropped), echo of the reply just spoken, similarity 0.6 or more (dropped), a known Whisper hallucination on silence such as "Thank you." or "Bye" (dropped), a stop phrase (ends the call), else sent. A dropped transcript SHALL leave the state Listening and send nothing.

#### Scenario: Near silence

- **WHEN** the recognizer answers "Thank you." for room noise
- **THEN** nothing is sent and the state stays Listening

#### Scenario: Echoed goodbye

- **WHEN** Hermes says "Goodbye." and the microphone hears it back
- **THEN** the call does not end and nothing is sent

### Requirement: Content the user did not say

Where the platform has no echo cancellation (macOS, Windows, Linux), capture SHALL be paused while a tone or the reply plays and SHALL resume 400 ms after the audio drained. Pausing capture SHALL reset the speech detector, so no half-heard turn survives it.

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

- **WHEN** the profile sets no list and the user says "Hey Hermes, goodbye."
- **THEN** the call ends and nothing is sent

### Requirement: Stop phrase list

The phrases SHALL be the profile's `voice.stop_phrases` when the profile sets the key, and it replaces the built-in list. Without it, or when it is malformed (not a list or a string), the built-in list applies: stop, stop listening, stop it, please stop, that is all, never mind, end conversation, end the call, goodbye, cancel, hang up, end call. A string counts as one phrase, and only an explicit empty list turns phrases off.

#### Scenario: Profile list

- **WHEN** the profile lists only "enough"
- **THEN** "enough" ends the call and "goodbye" is sent as a turn

#### Scenario: Built-in list

- **WHEN** the profile sets no list and the user says "end the call"
- **THEN** the call ends and nothing is sent

#### Scenario: Profile lists only stop

- **WHEN** the profile sets `["stop"]` and the user says "goodbye"
- **THEN** "goodbye" is sent as a turn

### Requirement: Speaking the reply

With "Speak replies" on (the default), the app SHALL speak this call's reply while it streams over `/api/audio/speak-stream`: new reply text (sealed prose included, reasoning and media paths excluded), then `done`, and the 16-bit mono PCM played from the first frame. With it off, or with nothing to speak, listening SHALL resume when the reply ends. A reply to a typed message is not spoken.

#### Scenario: Speech overlaps generation

- **WHEN** Hermes streams a two-sentence reply
- **THEN** the first sentence plays before the reply has finished

### Requirement: Speech fallback

On `fallback`, or a socket failure before any audio, the app SHALL synthesize the reply once with `POST /api/audio/speak` and play it. A failure after audio began SHALL count as finished speaking. When the fallback also fails, the call SHALL end saying "Hermes could not speak this reply" with the reply left in the chat.

#### Scenario: Server cannot stream

- **WHEN** speak-stream answers `{"type":"fallback"}`
- **THEN** the reply is synthesized once with `POST /api/audio/speak` and played

### Requirement: Interrupting the agent

Tapping the orb while the agent speaks SHALL stop playback and the running reply, wait until the session has settled, or at most 8 s (after which the next turn does not carry `interrupted`), and listen. The next turn submitted on a settled thread carries `interrupted: true` under the chat spec's rules. Where the platform has no echo cancellation the microphone is closed while Hermes speaks, and the stall watchdog is suspended whenever capture is closed by design.

#### Scenario: Tap to interrupt

- **WHEN** the agent speaks and the user taps the orb
- **THEN** speech stops at once, the state is Listening, and the next turn carries `interrupted: true`

### Requirement: Barge-in

Where the platform cancels echo and it has been verified (iOS; Android only after its device check) and `voice.barge_in` is not false, speech over the agent SHALL stop playback at its onset. The running reply SHALL be stopped only when the resulting turn is about to be submitted, and the turn SHALL wait for the session to settle; echo or an empty transcript leaves it running, unspoken, in the chat.

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

### Requirement: Waiting is tracked on its own

The waiting state SHALL be read from the chat, not only from the call's own reply, and tracked independently of any turn or barge-in: a request raised by a typed reply, a server-queued reply or a reply still running after speech was stopped SHALL still pause capture. It SHALL be checked again immediately before the app interrupts a reply and before it submits a turn, and a turn still in Sending (not yet handed to the transport) SHALL be dropped.

#### Scenario: Approval after a barge-in

- **WHEN** the user spoke over a reply, the reply keeps running, and it then asks for an approval
- **THEN** the call shows Waiting for you, and the next thing the user says is not sent and cancels nothing

#### Scenario: Approval while sending

- **WHEN** an approval arrives while a turn is still being transcribed
- **THEN** that turn is dropped and the approval is untouched

### Requirement: Interruptions

A system interruption SHALL end the call and say so. On Android a permanent or transient audio-focus loss (a call, an alarm) ends it, and a request to duck (a notification sound, a navigation prompt) does not. The call SHALL NOT resume by itself after an interruption. A submitted turn stays in the chat.

#### Scenario: Incoming phone call

- **WHEN** a phone call takes the audio during a call
- **THEN** the microphone closes, the call ends with "The call was interrupted", and nothing more is sent

#### Scenario: Notification sound on Android

- **WHEN** a notification asks the audio to duck
- **THEN** the call continues

### Requirement: Route change

A route change (headset, Bluetooth, speaker) SHALL discard the turn being heard and the speech, say "Audio route changed. Please repeat if needed. Nothing was sent.", and resume listening, without interrupting a running reply or a pending request.

#### Scenario: Headphones unplugged during an approval

- **WHEN** the route changes while the agent waits for an approval
- **THEN** the approval and the Waiting for you state stay, and capture stays paused

### Requirement: Background, lock and idle

Where the platform keeps the call's audio alive in the background (iOS, through its system call), locking or leaving the app SHALL NOT end it. On Android, leaving the foreground or locking SHALL end it. On macOS, Windows and Linux, hiding or minimising the app SHALL end it, but a screen lock is not observed: the call continues until the idle limit, which is a platform limit.

#### Scenario: Android app backgrounded

- **WHEN** the user switches to another app during a call on Android
- **THEN** the call ends, the microphone closes, and the thread keeps every submitted turn

### Requirement: Idle limit

Where barge-in is off, capture SHALL be open only while the call is Listening. On every platform a call SHALL end after 5 minutes without speech and without a running reply, and say so.

#### Scenario: Desktop locked

- **WHEN** a Mac is locked while the call is Listening and nobody speaks
- **THEN** the call ends after 5 minutes and says no one spoke, and while a reply runs capture is already closed

### Requirement: Microphone closed on every exit

On every way a call ends (every `reason` listed under Telemetry), the app SHALL stop capture first, then close the speech socket, stop playback, release the audio session and the `tts-lease` if held. Each step SHALL have its own timeout and a failure or hang in one SHALL NOT skip another. An End while capture is still starting SHALL cancel the start and close capture when it resolves.

#### Scenario: Speech socket hangs during teardown

- **WHEN** closing the speech socket does not answer
- **THEN** after its timeout the audio session is still released and capture is already closed

#### Scenario: End while the microphone opens

- **WHEN** the user ends the call while capture is starting
- **THEN** capture is closed as soon as it started, and nothing is recorded

### Requirement: Unconfirmed close

When closing capture could not be confirmed, the screen SHALL say "The call ended, but the microphone may still be open" instead of "The microphone is closed", and the strip SHALL read "microphone may still be open" until a late `stopCapture` completion or a bridge `deactivated` or `ended` event; End on the strip retries `stopCapture`.

#### Scenario: Close not confirmed

- **WHEN** stopping capture times out
- **THEN** the call ends with the warning, not with "The microphone is closed"

### Requirement: Platforms

The conversation SHALL run on iOS (system call and native audio engine), Android, macOS, Windows and Linux through one loop and one audio seam for capture, playback, mute, route and end. It SHALL NOT be offered in conversation windows or on watchOS. A platform whose microphone or audio output cannot be opened SHALL fail the matching start-screen check. Speaker routing is iOS and Android; desktop uses the system's output.

#### Scenario: Linux without audio output

- **WHEN** the audio output cannot be opened on Linux
- **THEN** the start screen's audio output check fails and Start call is unavailable

### Requirement: Strip in other windows

The Hands-free strip is drawn by the main window. On macOS a focused conversation window or the quick panel is a separate engine and SHALL be documented as showing none while capture runs, a stated limit; the OS microphone indicator remains.

#### Scenario: Conversation window in front

- **WHEN** a conversation window is focused during a call on a Mac
- **THEN** it shows no strip, and the main window's strip still has End

### Requirement: App Lock

App Lock SHALL NOT end a call, and while it is on the call screen, the strip and notices SHALL show no turn text, caption or reply. The App Lock cover SHALL keep a "Hands-free on" mark with End, so an open microphone is never hidden by it.

#### Scenario: Locked while listening

- **WHEN** App Lock covers the app during an iOS call
- **THEN** the cover shows "Hands-free on" and End and no words

### Requirement: GPT-Live profiles

When `GET /api/audio/voice-live/status` reports `mode: "gpt-live"`, the app SHALL still run the chained call, and the start screen SHALL say so.

#### Scenario: Profile set to GPT-Live

- **WHEN** the profile's voice chat mode is `gpt-live`
- **THEN** the call runs the chained loop and the start screen shows the note

### Requirement: Backend contract

Voice conversation SHALL rely only on the dictation routes, `GET /api/model/auxiliary`, `GET /api/audio/voice-live/status`, the `/api/audio/speak-stream` socket (`start`, PCM, `end`, `fallback`; `text`, `done`, `stop`), `POST /api/audio/speak`, `POST /api/audio/tts-lease`, the `voice` section of `GET /api/config` read with `include_defaults=false`, so a key the profile did not set is absent, and `prompt.submit` with `voice_turn` and `interrupted`.

#### Scenario: Profile without a voice section

- **WHEN** the profile's config has no `voice` section
- **THEN** the call uses the app's defaults: a 0.9 s pause, the built-in stop phrases, and barge-in where it is allowed

### Requirement: Telemetry

The call SHALL log `voice_call.readiness`, `voice_call.connected` and one `voice_call.ended` (`outcome`, `reason`, `step`, `error_type`, `connected`, bucketed `turns`, `speech_fallbacks`, `duration`), plus breadcrumbs of fixed names, counts and flags. None SHALL carry speech, a transcript, reply text, a URL, a ticket or an id.

#### Scenario: Call ended

- **WHEN** a call ends by a stop phrase
- **THEN** `voice_call.ended` records `reason` stop_phrase and buckets and no words

#### Scenario: Reason words

- **WHEN** a call ends
- **THEN** `reason` is one of hang_up, stop_phrase, voice_stopped, app, app_failure, background, idle, transcription, interrupted, focus_lost, prepare, audio_focus, native_start, native_events, connect, microphone_stalled, native_error, speech, turn or mute

### Requirement: Content stays out of other surfaces

Captions, transcripts and reply text SHALL NOT reach logs, the crash reporter's messages, notifications beyond existing rules, the surface snapshot, Live Activities or the watch.

#### Scenario: Caption on the call screen

- **WHEN** a turn's caption shows during a call
- **THEN** it appears on the call screen only
