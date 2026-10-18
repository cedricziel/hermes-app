# Recording an audio attachment

Touch and hold the composer's Send button to record a voice message. The same
button works with an empty draft or existing text. Release to attach the audio;
release never submits the message. A subsequent short tap sends the text and
attachments through the normal send/queue path. The voice chip can be removed.
The existing Dictate button still inserts speech-to-text into the draft.

Capture uses the existing cross-platform `record` plugin and a separate recorder
from dictation. Audio stays local until Send: 16 kHz mono PCM in a WAV file,
limited to five minutes (9.6 MB PCM). Recordings shorter than 200 ms are discarded.
Permission denial and capture/storage errors keep the text and other attachments.
If permission is granted after the finger was released, capture does not start.

The composer shows elapsed time and Release to attach while recording. Pointer
cancellation, changing the thread/profile, leaving Chat, backgrounding, signing out,
and starting a system call cancel capture. CallKit waits for recording cleanup
before taking audio. A screen reader can invoke the Send button's long-press
action to start and activate Attach voice message to finish without holding.
Voice messages require no server dictation provider; the audio is attached as
`audio/wav`, rather than silently transcribed on the client.

Temporary files live in an app-owned temporary directory until the chat screen
is disposed. This also keeps locally sent messages playable and allows the
existing durable queue to copy attachments before sending. Files are removed
when the screen closes; normal downloaded media caching is unchanged.

The Widgetbook composer includes idle, preparing, recording, attaching and
attached states. React ChatComposer mirrors these visual states using plain
props; it does not access the microphone. Flutter workflow tests capture the
actual composer on an iPhone viewport in light and dark.

Physical device checks remain necessary: first-use permission prompts, cancelling
system prompts, real input levels/recording quality, background/lock behavior,
VoiceOver, CallKit transitions, and sending to Hermes with its configured audio
handling. Desktop, iPad and Android use the same recorder/gesture path; this is
not a live call or dictation session.
