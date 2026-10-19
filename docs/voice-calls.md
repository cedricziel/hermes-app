# Native iOS voice conversations

Open a chat and tap **Start voice call**. A readiness screen checks microphone
access, the selected speech-recognition engine, Hermes speech configuration,
and the authenticated voice connection before starting CallKit. It does not
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

After the checks pass, Hermes presents its own voice view.
**Show chat** minimizes that view without ending the call; the header's phone
button returns to it. System mute, audio route and hang-up controls belong to
CallKit from the start. Backgrounding or locking the phone does not create a
second call or reconnect the conversation. Ending the call releases native
audio before waiting for remote cancellation.

Calls use the selected chat/profile and its normal model and tools. Speech
recognition follows the Dictation setting, including on-device recognition and
its existing fallback for unsupported languages. Missing on-device language
models must be installed in Dictation settings. Configure text-to-speech on
Hermes as well. The server must offer `/api/audio/speak-stream`.

A pause of roughly 900 ms sends an utterance; each utterance is limited to one
minute. Talking over a reply cancels its playback and asks Hermes to stop that
turn before another is submitted. “Hang up” or “End the call” ends the call.
Approvals and clarification cards remain in the chat and require the existing
user interaction; they are never automatically approved by voice. Changing
chat, profile or signed-in account ends the call. A system audio interruption
ends the call; a route reconfiguration discards the current voice turn and
resumes listening on the new route.

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
- This is Hermes' chained STT → agent → TTS conversation, not the separately
  configured GPT-Live/WebRTC service. Prompt text is not augmented with hidden
  system instructions, and the normal selected model remains in use.
- `UIBackgroundModes=audio` keeps an active conversation running. There is no
  PushKit registration, incoming-call simulation, or microphone use before
  native audio activation. Calls are excluded from Recents.

Protocol reference: NousResearch/hermes-agent, commit
`e6cf2a9b1e8f98d40408b09a9a55993c8459b4b4`,
`hermes_cli/web_routers/audio.py`.

Ordinary voice-message playback pauses before CallKit starts and cannot change
the audio session while a call owns it, including background pause and disposal.
It can be resumed explicitly after the call ends.

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
