# Voice conversations

Open a chat and tap **Start voice call**. On iOS it is always there. On
Android, macOS, Windows and Linux it is there once you turn on **Voice calls on
this device (beta)** in Settings (see **Other platforms**, which also says what
differs from iOS). A readiness screen checks microphone
access, the selected speech-recognition engine, Hermes speech configuration,
the profile's voice model and the authenticated voice connection before
starting CallKit. It does not
record audio, synthesize sample speech, prompt for permission, or send a chat
message while checking. Each check has a timeout; Cancel discards late results.
Local issues offer microphone access or the existing Dictation settings.

For server issues, **Ask Hermes to set this up** explicitly sends an ordinary
message in the current chat and returns to that conversation. Watch the reply,
steer the agent, answer follow-up questions and approve changes through the
normal chat controls. The composer's existing draft and attachments are kept.
The request contains curated diagnostics, never voice-config credentials or
raw server responses, and asks Hermes to explain and confirm changes first.
Nothing installs or changes server settings automatically. Check again after
setup to start a call. A failed call also offers **Ask Hermes for help**.

The checks validate reported configuration and a WebSocket upgrade, not actual
synthesis, provider credentials at runtime, or installed server executables.
There is no backend dependency-health endpoint; Hermes can diagnose dependencies
such as ffmpeg in the visible setup conversation. Checking makes no paid test
request. Auth failures ask the user to sign in again instead of asking the agent
to repair credentials.

The **Voice model** row reads `GET /api/model/auxiliary` and looks at the
profile's `voice_chat` slot. It is fine when the slot names a model, follows
the main model (provider `auto` or `main`, no model, no base URL, and a main
model is set), or pins a provider without a model (Hermes then runs it on that
provider's fast auxiliary model). A slot with nothing to run on, an older
server without the slot, or a failed or 404 read is a **warning**: the row says
so and the call can still start. A profile whose voice chat mode is GPT-Live
(`GET /api/audio/voice-live/status`) gets a note on the same screen: this app
runs the standard voice chat (listen, send, speak), not GPT-Live. A failed
status read shows no note.

**Consent.** Before the microphone opens the start screen says that Hermes sends
each thing you say after a pause, without you pressing send, and that the agent
may act on it with its tools. The call starts only after you turn on **Send what
I say automatically** for that call. The switch is off on every open, after
**Start a new call**, in another chat or profile, and is never stored. Without
it Start call is disabled, nothing is captured, and **Use dictation instead** is
offered. A transcript is never sent to the chat without that switch.

After the checks pass and you turn the switch on, Hermes presents its own voice
view. The orb shows the state in an icon and a word, never by colour or motion
alone: Connecting, Listening, Muted, Sending, Thinking, Speaking, Waiting for
you, Stopped. **Show chat** minimizes that view without ending the call; the
header's phone button returns to it. System mute, audio route and hang-up
controls belong to CallKit from the start. Backgrounding or locking the phone
does not create a second call or reconnect the conversation. Ending the call
releases native audio before waiting for remote cancellation.

While the microphone is open a **Hands-free on** strip stays above every screen
of the main window (the app's navigator sits under it), with its state
(microphone open, paused, muted or opening) and an End button while the call
screen is closed. A macOS conversation window and the quick panel are separate
engines and show no strip; the system's microphone indicator covers them. After
a call that ended without confirming that the microphone closed the strip says
"Microphone may still be open" until the next call. App Lock never ends a call:
under it the call screen, the strip and the notices show no words, and the lock
cover keeps a "Hands-free on" mark with End.

Calls use the selected chat/profile and its normal model and tools. Speech
recognition follows the Dictation setting, including on-device recognition and
its existing fallback for unsupported languages. Missing on-device language
models must be installed in Dictation settings. Configure text-to-speech on
Hermes as well. The server must offer `/api/audio/speak-stream`.

A pause of 0.9 s sends an utterance, or the profile's `voice.silence_duration`
(clamped to 0.5 to 3 s); each utterance is limited to one minute. The call
reads the profile's `voice` keys once with `include_defaults=false`, so a key the
profile never set is absent and the app's own default applies.

**Sending** lasts from the end of speech until the prompt is about to be written
to Hermes (`prompt.submit`). End, mute or an approval before that sends nothing,
also while the persisted queue is read and while the session is opened or
resumed (a mute counts when it is requested, not when the system confirms it).
After the write the prompt stays in the chat and End stops this turn's reply.
Transcripts are filtered in one order, the first match
decides: empty, an echo of the reply just spoken (see **Echo guard**), a Whisper invention (the filter is a port of Hermes'
`is_whisper_hallucination`: "Thank you.", "Bye", "you", "the end", subtitle
credits and short repeats; a lone "ok" counts too, as in Hermes), a stop
phrase, else it is sent. A dropped transcript says nothing.

**What happens to a spoken turn.** The chat decides, and the call says so:

- Hermes is still answering, or a queue (paused ones included) holds prompts:
  "Hermes is still answering. Nothing was sent." A call never joins a queue and
  never sends a queued prompt.
- The persisted queue could not be read, the model, a branch or a restore does
  not allow a send now: "Couldn't send. Nothing was sent." The call goes on
  listening.
- The chat's session was taken back or its profile is not confirmed: the call
  ends.
- Hermes answers `queued`, `steered` or `redirected` (its own busy-input mode;
  the call never asks to queue): the call stops waiting at once, says "Hermes
  will answer your words after its current reply.", "Hermes took your words into
  its current reply." or "Hermes is adjusting its current reply to your words."
  and listens. The reply, if any, is in the chat and is not spoken.
- Hermes takes the words as the stop phrase of its own voice mode (`voice_stopped`,
  for a typed prompt too): no turn runs, no message is left in the chat, and a
  running call ends (telemetry reason `voice_stopped`). A prompt typed, queued
  or answered from a notification that Hermes takes this way is not lost
  silently: the chat says "Hermes took that as a stop command. Nothing was
  sent." and puts the words back in the message box (a notification reply ends
  in "Reply not sent" with the text kept).

**Voice model and the interrupted note.** A spoken turn is sent with
`voice_turn: true`, so Hermes runs it on the profile's `voice_chat` model route
(the Voice model row of the start screen). When the user cut the previous reply
off, the turn also carries `interrupted: true` and Hermes adds a note to the
model's message that the user interrupted its previous spoken reply. The flag is
sent on the first spoken turn after the user cut off speech (orb tap, or
speaking over the reply) and only while the thread is settled: no reply pending
and the session reported idle. It stays pending across a turn that was refused,
dropped or echoed, and is cleared by the first turn that reaches the server
(whatever Hermes answers), by mute, a route change, a typed message in the chat
and after 120 seconds. Hermes keeps one process-wide latch for 120 seconds, so a
flag that went unused could mark another session's turn; the app therefore sends
it sparingly (an upstream request is open for a per-turn note).

**Stopping.** End, mute (stops capture without ending the call), the platform's
hang-up and a stop phrase end or silence the call. A stop phrase is the whole
utterance, lowercased with surrounding punctuation and a leading "hey hermes",
"hermes", "ok" or "hey" removed. With no `voice.stop_phrases` in the profile the
built-in list applies: stop, stop listening, stop it, please stop, that is all,
never mind, end conversation, end the call, goodbye, cancel, hang up, end call.
A profile list replaces it (so a profile that sets one loses "hang up" unless it
lists it), a single string is one phrase, a malformed value gives the built-in
list, and only an explicit empty list turns stop phrases off.

**Failures.** A transcription that fails or times out drops the turn and its
audio, says "Couldn't hear that. Nothing was sent." and listens again; two in a
row end the call, and a success resets the count. A speech failure before any
audio falls back once to the whole reply from `POST /api/audio/speak`; after
audio has played the reply counts as finished; a failed fallback ends the call
with "Hermes could not speak this reply." and the reply stays in the chat.

**Waiting for you.** While Hermes waits for an approval or a question (whoever's
reply raised it, including a typed or queued one) capture pauses, speech is
ignored, nothing is interrupted or sent, and the screen says to answer in the
chat. Capture resumes when the request closes. Approvals are never answered by
voice.

**Talking over a reply.** Speech onset stops playback and closes the speech
socket only; the reply keeps running in the chat. It is stopped only when a real
turn is about to be sent, so an echo or a stray sound does not kill it. Tapping
the orb while Hermes speaks interrupts the reply and listens.

**Route change.** A reconfigured audio route drops the turn being heard and the
speech, says "Audio route changed. Please repeat if needed. Nothing was sent."
and listens on the new route. A running reply and the Waiting for you state
survive it. An audio interruption (another call or app taking the audio) ends
the call.

**Idle.** Five minutes with no speech and no running reply end the call with
"No one spoke for 5 minutes." Off iOS, hiding or backgrounding Hermes ends the
call (see **Other platforms**).

**Sounds.** A rising tone when listening starts, a soft tick when the words are
sent and a falling tone at stop, with a light haptic at the send and a medium
one at stop on phones. They play with capture paused so the call never hears
them. Changing chat, profile or signed-in account ends the call.

**Ending.** Every exit runs one ordered teardown: the capture closes first
(before any notice shows), then the speech socket and playback, the stop tone,
the audio session and focus, the optional `tts-lease`, and last the agent. Each
step has its own two seconds, so a throw or a hang skips nothing, and it runs
once. If the capture's close cannot be confirmed the call says "The call ended,
but the microphone may still be open." and so does the strip. A chat that
closes while a call runs (sign-out, account change) ends the call first.
"Hang up" and "End the call" are stop phrases. Approvals and clarification
cards remain in the chat and require the existing user interaction.

## Echo guard

On every platform, iOS included, the first transcript after a reply is compared
with that reply, and dropped silently when it is the reply heard back through
the microphone. Only the first transcript after a reply is checked, whatever
the answer; a later one never is, and a new reply arms the guard again. The
check runs before the invented-transcript and stop-phrase checks.

**The timing rule.** A real echo is acoustically close to the playback, so the
guard only counts for speech that began (the speech detector's onset, not the
end of the utterance or the time the transcript came back) while the reply was
playing or within 1.5 s after its audio drained (`VoiceCall.echoTail`). The
reply begins at its first text handed to the speech; its audio ends when the speech drained
or was cut off (the user speaking over it, End, an error). Speech that began
later is never an echo, whatever it says and however alike: "Goodbye." said
3 s after a reply of "Goodbye." ends the call as a stop phrase, and "Turn the
lights on" after "Should I turn the lights on or off?" is sent. Where there is
no barge-in the microphone is closed through the playback and reopens 400 ms
after it, so only speech inside that 1.5 s tail can count there. A transcript
outside the window still spends the guard (an empty transcript does not: it is
dropped first). The rule below applies to what is inside the window.

**What this costs, plainly.** An answer that begins within 1.5 s of the reply
and consists of the reply's own words is dropped silently, with no notice.
Normal turn-taking gaps (0.2 to 1 s) are inside the window, so a quick "turn
the lights on" after "Should I turn the lights on or off?" is dropped; said
after a longer pause it is sent. Where barge-in is off the microphone reopens
400 ms after the audio, so the 1.5 s tail there mostly catches the user's own
answers, not the room. The tail stays 1.5 s on every platform: shortening it
for the no-barge-in case would need the portable bridge's real output latency
(SoLoud's buffer plus the device's) and the room's reverberation, and neither
has been measured on a device (see the device checks). If the device checks show
a shorter tail still catches the echo, shorten it then.

**The exact rule.** Both texts are lowercased and reduced to words (letters and
digits; everything else is a space). For a transcript T and a stretch S of the
reply, T is the echo of S when both hold:

1. **Alike:** `1 - editDistance(T, S) / max(len(T), len(S)) >= 0.6`, by
   character on the word-only text.
2. **Nothing new:** at most one word in eight of T (`floor(words(T) / 8)`) is
   missing from S. A word is in S when it equals a word of S or, when both
   have four or more letters, is at least 0.6 alike to one (a transposed
   letter, "Hannah" for "Anna"). A word of up to three letters has to match
   exactly.

S is the whole reply; or, when T has ten characters or more and fewer words than
the reply, any run of the reply with the same number of words as T (the
microphone often hears only part of the reply). A reply longer than 4,000
characters is compared by its end, and a transcript longer than 200 characters
only with the whole reply.

**Why the second condition.** The first alone (the rule the call shipped with)
drops a real answer that repeats the question: "Yes, send the email to Anna"
after "Shall I send the email to Anna?" is 0.88 alike to a stretch of the
question, and "Yes, goodbye" after a reply of just "Goodbye." is 0.64 alike (0.67
to the last two words of a longer reply). A
reply read back has no words of its own: a recognizer garbles a letter or adds
an occasional filler word, but the user's "yes", "no", "please" or a name is
not in the reply. So a word that is not in the reply, beyond the one-in-eight
allowance (zero below eight words), marks a person speaking. The allowance is
there so a long echo with a stray "uh" is still caught; a short echo with a
filler word is not (it is sent, which costs one wasted turn, where the other
error drops a real answer silently).

| Reply | Heard | Result |
| --- | --- | --- |
| The weather in Berlin is cloudy today with a chance of rain. | the same, any case or punctuation | dropped |
| It is cloudy. I will remind you at five. Talk to you later. | I will remind you at five. Talk to you later | dropped (last sentences) |
| The weather in Berlin is cloudy today. | weather in Berlin is cloudy toady | dropped (tail, typo) |
| Shall I send the email to Anna? | shall I send the email to Hannah | dropped (name misheard) |
| Goodbye. | Goodbye. | dropped |
| I have turned the living room lights off now. | I have turned the uh living room lights off (9 words, 1 new) | dropped |
| The reminder is set for five. Goodbye. | Yes, goodbye. | kept and sent |
| Goodbye. | Yes, goodbye. | kept and sent |
| Shall I send the email to Anna? | Yes, send the email to Anna | kept and sent |
| Shall I send the email to Anna? | send the email to Anna please | kept and sent |
| Shall I send the email to Anna? | No, send the email to Anna | kept and sent |
| I have turned the living room lights off now. | I have turned the uh um living room lights off (10 words, 2 new) | kept and sent |
| Okay, goodbye. Talk to you later. | Goodbye. (under ten characters, part of a longer reply) | kept and sent |
| The weather in Berlin is cloudy today. | please turn on the kitchen lights now | kept and sent |

The table is the test (`test/voice/calls/echo_guard_test.dart`, one row each,
both ways). Answers made of the reply's own wording ("turn the lights on" after
"Should I turn the lights on or off?", "book the table for Petra" after "...for
Peter or Petra?", "send the email to Anna" after "Shall I send the email to
Anna?", "move the meeting to Thursday" after "...Tuesday?", "the meeting is on
Monday" after "...Sunday?") match the rule, so only the timing keeps them:
call-level tests with a fake clock send them when said 3 s after the reply, drop
them when said 0.5 s after it, and check the 1.4 s and 1.6 s edges and that the
onset, not the end of the utterance, decides. Call-level tests also send "Yes,
send the email to Anna" and "Yes, goodbye". There is deliberately no notice for a dropped echo.

## Other platforms

Android, macOS, Windows and Linux run the same loop through `PortableCallBridge`
(`lib/src/voice/calls/portable_call_bridge.dart`) instead of CallKit.

- **The switch (off by default).** Calls on these platforms are new, so they
  stay off until the user turns on **Voice calls on this device (beta)**
  (Settings on a Mac; the account menu's **Voice calls** elsewhere; a note says
  it is new on this platform). The default is the constant
  `kPortableCallsDefault` (`lib/src/voice/calls/portable_call_settings.dart`,
  `false`); it flips after the device checks below, which is the owner's call.
  iOS is unchanged: always available, no switch shown. It is a plain device
  preference (`SharedPreferencesAsync`, key `hermes.portable_calls`, not a
  secret); sign-out, a server change and a profile switch leave it alone, and
  only the user changes it. With the switch off there is no header button and
  no Mac toolbar button, and no other way in: no menu item, deep link, App
  Intent, quick action, Spotlight or watch entry starts a call (`hermes://`
  links only ever fill the composer). No bridge is created, the microphone
  permission is never queried or requested for a call, and `flutter_soloud`
  never initialises: its engine starts only inside `PortableCallBridge.start`,
  and nothing else in `lib/` imports it. Turning the switch off while a call
  runs leaves that call alone (its End and the strip stay); it only hides the
  way to start the next one. Until the saved choice has been read from disk
  the switch counts as off. Android's backup rules exclude only the Home Screen
  widget preferences, so the switch is backed up and a restore onto a new device
  from the user's own backup keeps their choice; that is intended.

- **Audio.** The microphone is the `record` plugin (16 kHz mono PCM, the
  platform's echo canceller and noise suppressor asked for, the
  voice-communication input on Android). The voice plays through `flutter_soloud`
  (a buffer stream of s16le mono at the rate the server sends). Android takes
  audio focus and the in-communication audio mode through `audio_session` and
  asks SoLoud for a voice-communication output stream. Neither library starts
  before the user pressed Start, and on iOS neither is used.
- **No barge-in.** None of these platforms cancels the echo of what the call
  plays (Android's is to be proven on a device first), so the microphone is
  closed while Hermes sends, thinks, speaks and plays a tone, and reopens 400 ms
  after the audio ends. Closed means the recorder is stopped, not that samples
  are dropped. Tapping the orb interrupts the reply. Speaking shows "Tap the
  orb to interrupt." (Android) or "Microphone paused while Hermes speaks. Tap
  the orb to interrupt." (desktop), and the strip says "paused".
- **A hung plugin is bounded.** On End the bridge waits at most two seconds for
  the recorder to stop, and two for each later release (player, recorder
  dispose, audio session), so a recorder that hangs cannot keep the audio focus
  and communication mode from being released.
- **Echo guard.** See **Echo guard** above; on these platforms it is the second
  line after the closed microphone.
- **When the microphone is closed.** On End, on sign-out, an account change
  or a profile switch (the chat ends the call), on losing audio focus, and
  when the window is hidden or minimised or the app is paused or detached (the
  lifecycle ends it; `inactive` does not) the capture closes first, then
  playback, the recorder, and the Android audio focus and communication mode
  are released, each step bounded by two seconds. Tests drive these through the
  real `PortableCallBridge` with a fake recorder, player and audio session. App
  Lock never ends a call (as on iOS): under it the capture continues, and the
  cover keeps the Hands-free strip with End and shows no words. No audio,
  transcript, reply or device name reaches a log, span or breadcrumb: the
  bridge's events carry audio only as `pcm` and otherwise fixed words, a route
  name is shown on the screen and never logged, and the bridge has no logging
  of its own.
- **Leaving the app ends the call.** The screen says so ("The call ends if you
  leave Hermes." on Android, "...hide or minimise Hermes." on desktop). Android
  ends it when the app is paused, which includes the screen locking; desktop
  ends it when the window is hidden. A desktop screen lock is not observed: the
  five-minute idle limit and the OS microphone indicator bound it. Android audio
  focus loss (another app, a phone call), permanent or transient, ends the call;
  ducking does not. A changed audio device is a route change.
- **Where it opens.** A full-screen page on a phone; a 480 pt dialog over the
  chat from 760 pt wide and on every Mac width (never a sheet on the Mac). Escape
  and "Show chat" close the dialog and the call keeps running; the strip has End.
  The Speaker control exists on iOS and Android only. A macOS conversation window
  and the quick panel offer no call.
- **Permissions.** The microphone is asked for with the same call as dictation
  (`record`), and only once the switch is on and the call screen was opened. When it is denied iOS, macOS and Windows offer "Open Settings";
  Android and Linux have no link the app can open, so they offer Allow again.
  Android declares `MODIFY_AUDIO_SETTINGS`.
- **Recognition.** Apple platforms use the device recognizer the Dictation
  setting chooses; everywhere else the call transcribes through Hermes.
- **Linux without audio.** SoLoud cannot start without an output device, and
  the call then fails to start with "Could not start the call".

## Implementation

- `packages/hermes_calls`: outgoing CallKit calls and a single native
  voice-processing AVAudioEngine graph for capture and playback. CallKit alone
  activates AVAudioSession. Capture is echo-cancelled 16 kHz mono PCM; incoming
  server PCM (8–96 kHz) is resampled for playback. Bluetooth HFP is enabled.
- `lib/src/voice/calls`: bounded voice activity segmentation, transcription,
  normal ChatController submission, incremental speech and cancellation.
  Reasoning and MEDIA paths are excluded from spoken prose.
- Hermes supplies PCM over an authenticated, profile-scoped
  `/api/audio/speak-stream` socket, so call playback is independent of file
  attachment codecs and the voice-message player. Providers which produce no
  streaming audio can report `fallback`. The app then submits the completed
  reply to the same profile's authenticated `POST /api/audio/speak` once.
  Local libmpv/FFmpeg decoding converts inline Ogg/Opus, Vorbis, MP3, AAC,
  WAV or FLAC to 24 kHz mono PCM for the existing CallKit graph. The converter
  writes only temporary files and never selects a hardware audio output or
  configures AVAudioSession. Files are removed after conversion, cancellation
  or failure. Barge-in, hang-up and context changes cancel synthesis/conversion
  and discard late audio. A fallback after PCM already played is an error,
  preventing the reply from being spoken twice.
- Current Hermes can also turn non-streaming providers into sentence PCM on
  the server; `fallback` is its last resort when no audio was produced. Piper
  does not require a provider change solely because it lacks a streaming API.
  Synthesis/decoding failures use the existing explicit call-error recovery.
- A call keeps what it acquires small: one capture, one speak-stream socket per
  reply, playback, the audio session and the optional `tts-lease`. Registry
  (`ActiveCallRegistry`) tells the shell strip and the App Lock cover what the
  call is doing (a fixed state, never words) and offers End.
- This is Hermes' chained STT → agent → TTS conversation, not the separately
  configured GPT-Live/WebRTC service. A spoken turn runs on the profile's
  `voice_chat` model route (the selected chat model is used where that route
  follows it), and a turn after a cut-off reply carries Hermes' `interrupted`
  note; the app adds nothing else to the words.
- The iOS app declares `audio` and `voip` in `UIBackgroundModes`. `audio` keeps
  an active conversation running; CallKit requires `voip` to start a call. There
  is still no PushKit registration, incoming call, or microphone use before
  native audio activation. Calls are excluded from Recents.

Protocol reference: NousResearch/hermes-agent, commit
`e6cf2a9b1e8f98d40408b09a9a55993c8459b4b4`,
`hermes_cli/web_routers/audio.py`.

Ordinary voice-message playback pauses before CallKit starts and cannot change
the audio session while a call owns it, including background pause and disposal.
It can be resumed explicitly after the call ends.

## What changed for the iOS call

The call shipped first without these rules. This version changes it:

- **Consent:** every call needs the "Send what I say automatically" switch.
- **Stop phrases:** with no profile list "hang up", "end call" and "end the
  call" stay and more are added; a profile list replaces them, so a profile
  that sets one loses the shipped phrases unless it lists them.
- **Transcription failure** drops the turn and listens instead of ending the
  call; two in a row end it.
- **Speech failure:** a fallback after a failure before audio, "finished" after
  audio, and an ended call only when the fallback fails, replace ending the
  call in both cases.
- **Availability:** the Voice model row joins the readiness checks (a warning
  never blocks), and a GPT-Live profile gets a note.
- **Barge-in:** an echo no longer kills the reply, speech during an approval is
  ignored, and a route change no longer cancels a pending approval.
- **Also visible:** the five-minute idle end, capture pausing while Waiting for
  you, silent drops of invented transcripts, tones and haptics, the
  Hands-free strip, and a turn spoken while a reply runs being dropped
  ("Hermes is still answering. Nothing was sent.") instead of ending the call.
- **Echo guard:** it now runs on iOS too, with the exact rule and timing above
  (before, the call had none). Speech that began during the reply or within
  1.5 s after it and is the reply read back is dropped silently; an answer that
  adds words of its own, or that begins later, is sent.
- **Telemetry:** the reason `voice_hang_up` is now `stop_phrase`; `background`,
  `idle`, `transcription` and `focus_lost` are new.
- **Strings:** the call views read from the ARB files (English and German).

- **Voice model route and `interrupted` note:** a spoken turn is sent with
  `voice_turn`, so Hermes runs it on the profile's `voice_chat` model route
  instead of only the chat's model, and after a cut-off reply `interrupted`
  adds a note to the model's message. "No hidden system instructions" no longer
  holds literally for calls: the note is Hermes' own, and the app adds none.
- **Sending** now lasts until `prompt.submit` is written, and End during the
  session resume sends nothing (before, a prompt could still go out after End).
- **Refusals** say "Hermes is still answering. Nothing was sent." (only when
  that is the reason), "Your queued messages are paused. Nothing was sent."
  (queued messages wait for you and no reply runs) or "Couldn't send. Nothing was sent." and the call goes
  on; a lost session or profile ends it. A stop phrase Hermes catches ends the
  call (`voice_stopped`).

- **Last turn and Speak replies:** under the hint the call screen shows the
  last turn as two plain lines, You (what was sent) and Hermes (the reply as it
  streams, as far as it is spoken). The caption of a turn being sent replaces
  them, and a stopped call shows none. The words live only in the open call:
  the call drops them when it ends, App Lock covers them like the rest of the
  screen, and they never reach a log, breadcrumb or span. A "Speak replies"
  switch under the controls is on at the start of every call and never stored.
  Off, the call opens no speech socket and holds no `tts-lease`, the listening
  hint reads "Replies are not spoken. The answer will be in the chat.", the soft
  tick at submit is the confirmation, and the Hermes line says "Reply is in the
  chat" when the reply is done. Turning it off during a reply stops the voice
  at once and the rest of that reply stays in the chat; turning it on speaks
  from the next reply. The `voice_call.turn` outcome for an unspoken reply is
  `in_chat`.
- **`tts-lease`:** while the call is open and Speak replies is on, the app
  holds `POST /api/audio/tts-lease` under a random `app:conversation:<uuid>`
  name (it holds no server, profile or chat name) so the profile's speech
  provider is warm for the first reply. A failure is ignored. It is released
  once on the teardown step after the audio session and focus, or when Speak
  replies is switched off, and never taken while it is off. A release that fails is retried once; a missed release keeps a local speech model loaded until the server restarts.

## Telemetry

With telemetry on, a finished readiness check logs `voice_call.readiness`
(each check's status and, for a check that threw, its error kind such as
`timeout`, `http_502` or `upgrade_403`). A call logs `voice_call.connected`
when CallKit activates its audio and exactly one `voice_call.ended` with
`outcome` (ended or failed), `reason` (`hang_up`, `stop_phrase`, `app`,
`app_failure`, `prepare`, `native_start`, `connect`, `microphone_stalled`,
`interrupted`, `focus_lost`, `native_error`, `speech`, `turn`, `mute`,
`background`, `idle`, `transcription`, `voice_stopped`), the failing `step` (`transcribe`,
`speech_open`, `agent`, `speech`, `speech_fallback`), `error_type` (also
`session_reclaimed` and `profile_not_confirmed` for a turn the chat refused
that ends the call), whether
it ever connected, and buckets of turns, fallbacks, speech retries and
duration. A failed open of a reply's speech socket (a 5xx on the ticket or
the upgrade, or a socket error; never a timeout, 401, 403, 404 or 405) is
retried once after half a second, without resending anything; if that fails
too, the one-piece speech fallback speaks the reply as before.

Each reply the call sent also logs one `voice_call.turn` with the bucketed
time of each stage (`<0.5s`, `0.5-1s`, `1-2s`, `2-5s`, `5-10s`, `10-30s`,
`>30s`, or `none` for a stage that never ran): `transcription`, `speech_open`
and, counted from the moment `prompt.submit` is written, `first_text`,
`first_audio` and `reply_complete`, plus `device_speech` and `fallback`
(flags) and `outcome` (`spoken`, `in_chat`, `interrupted`, `failed`). Raw durations,
text and ids are never recorded. A turn the chat refused or withdrew before the write, or that Hermes answered at once (`queued`, `steered`, `redirected`, `voice_stopped`), logs no `voice_call.turn`.
A native failure's `voice_call.ended` carries `step` set to the native code
(`start_request`, `start_action`, `activation_timeout`, `audio_start`,
`audio_reset`, `provider_reset`, `action_timeout`, `end_request`, `detached`),
and for `start_request` an `error_type` of `callkit_<n>`, where n is CallKit's
fixed request-transaction error number. Each
`/api/audio/speak-stream` socket is traced like the gateway's. Nothing spoken,
transcribed or replied, and no URL, ticket or id, is recorded.

## CarPlay

The integration uses system call controls and car audio routing. There is no
separate Hermes CarPlay icon or template scene in this change. Apple's
voice-based conversational CarPlay category requires approval for
`com.apple.developer.carplay-voice-based-conversation` (iOS 26.4), a capability
on the App ID and updated provisioning. No unapproved entitlement is added.

References: [CallKit](https://developer.apple.com/documentation/callkit),
[CarPlay](https://developer.apple.com/carplay/),
[requesting entitlements](https://developer.apple.com/documentation/carplay/requesting-carplay-entitlements).

## Physical iPhone validation (iOS)

Dart tests cover segmentation, chat ownership, protocol framing, native speaker
drain, mute, end, route reset and late results. CI builds the native iOS plugin.
Real device validation is still required for:

1. Start a call, deny microphone permission, then enable permission and retry.
2. Speak two turns; confirm no speaker echo is submitted as another user turn.
3. Talk over Hermes; confirm the old audio stops and the new turn follows it.
4. Show chat and handle an approval; verify the normal approval policy applies.
5. Lock/unlock and background/foreground during listening and speaking; confirm
   one CallKit call persists, with system mute and hang-up remaining effective.
6. Test receiver, speaker, Bluetooth HFP and car routes, including connecting and
   disconnecting a route during speech. Reconfigured audio should return to
   listening; the discarded turn may need repeating.
7. Interrupt with a phone call; sign out; switch chat/profile; end during
   permission or transcription. Confirm the microphone indicator clears and
   no late transcript is sent.
8. The Swift side of `pauseCapture`, `resumeCapture`, `stopCapture` and the
   `capturePaused` event (`packages/hermes_calls`): pause during Waiting for
   you and while a tone plays, resume after it, and see "microphone paused"
   in the strip.
9. The three tones on CallKit's shared audio graph (loudness, no clipping, not
   heard back as speech) and the haptics.
10. End during every phase and confirm the microphone indicator clears at
    once; the strip over the system's lock and App Lock cover.

## Device checks for Android and desktop: all UNVERIFIED

Nothing below has been run on a device. CI proves that it compiles (Linux was
built here; Android, macOS, Windows and iOS are built by CI) and the Dart tests
prove the state machine against fake recorder, player and audio-session seams.

0. Owner decision, after the checks below: flip `kPortableCallsDefault` to
   `true` so calls are on by default on Android, macOS, Windows and Linux.
   Until then the switch stays off.
1. UNVERIFIED, Android: echo on the phone's loudspeaker with echo cancellation
   on and the voice-communication output; whether SoLoud's output really is the
   voice-communication stream. This decides whether barge-in is turned on.
2. UNVERIFIED, Android: playback volume and routing in the in-communication
   mode, the speaker switch, a Bluetooth headset, and unplugging a headset
   during speech (route reset).
3. UNVERIFIED, Android: focus loss from a phone call and from another media app
   (permanent and transient end the call, ducking does not), and the call ending
   when the app goes to the background or the screen locks.
4. UNVERIFIED, Windows and Linux: whether the Flutter embedders report `hidden`
   and `paused` when the window is minimised, so the call ends. If they do not,
   the call goes on until the idle limit.
5. UNVERIFIED, macOS: a call with the built-in microphone and speakers and with
   headphones, and the microphone indicator clearing on End.
6. UNVERIFIED, Windows and Linux: microphone capture and sound output (Linux
   needs PulseAudio or ALSA), a missing device failing the start cleanly.
7. UNVERIFIED, every portable platform: no self-hearing through the 400 ms tail
   after the reply and the tones (the echo guard is the second line).
8. UNVERIFIED: VoiceOver (iOS, macOS) and TalkBack (Android) announcing each
   state and operating the orb, Mute and End.
9. UNVERIFIED, macOS: Flutter derives `hidden` from window occlusion, so moving
   to another Space or covering the windows fully may report `hidden` and end
   the call more often than the footer ("hide or minimise") promises.
10. UNVERIFIED, iOS (unchanged from before): speaker barge-in and an incoming
   call.
