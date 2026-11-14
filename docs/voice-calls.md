# Native iOS voice conversations

Open a chat and tap **Start voice call**. A readiness screen checks microphone
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

**Sending** lasts from the end of speech until the words are handed to the chat.
End or mute in that time sends nothing (a mute counts when it is requested, not
when the system confirms it). After the send the prompt stays in the chat and End
stops this turn's reply. Transcripts are filtered in one order, the first match
decides: empty, an echo of the reply just spoken (a seam until the portable
bridge ships), a Whisper invention (the filter is a port of Hermes'
`is_whisper_hallucination`: "Thank you.", "Bye", "you", "the end", subtitle
credits and short repeats; a lone "ok" counts too, as in Hermes), a stop
phrase, else it is sent. A dropped transcript says nothing.

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
call (the platform bridges for those come later).

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
  configured GPT-Live/WebRTC service. Prompt text is not augmented with hidden
  system instructions, and the normal selected model remains in use.
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
  Hands-free strip, and a turn spoken while a reply runs being dropped (a
  later change says "Hermes is still answering" instead of ending the call).
- **Telemetry:** the reason `voice_hang_up` is now `stop_phrase`; `background`,
  `idle`, `transcription` and `focus_lost` are new.
- **Strings:** the call views read from the ARB files (English and German).

Still to come with later changes: sending voice turns on the profile's
`voice_chat` model route and the `interrupted` note (which end "no hidden
instructions" for calls), calls on Android and desktop, and the turn list and
"Speak replies" switch.

## Telemetry

With telemetry on, a finished readiness check logs `voice_call.readiness`
(each check's status and, for a check that threw, its error kind such as
`timeout`, `http_502` or `upgrade_403`). A call logs `voice_call.connected`
when CallKit activates its audio and exactly one `voice_call.ended` with
`outcome` (ended or failed), `reason` (`hang_up`, `stop_phrase`, `app`,
`app_failure`, `prepare`, `native_start`, `connect`, `microphone_stalled`,
`interrupted`, `focus_lost`, `native_error`, `speech`, `turn`, `mute`,
`background`, `idle`, `transcription`), the failing `step` (`transcribe`,
`speech_open`, `agent`, `speech`, `speech_fallback`), `error_type`, whether
it ever connected, and buckets of turns, fallbacks and duration.
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

## Physical iPhone validation

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
