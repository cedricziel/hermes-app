# Design brief: Voice conversation

Change: `openspec/changes/voice-conversation/`. Read its design.md for the facts, the state machine and the platform matrix; this brief is what the visual design pass needs and what it decided.

## Design (done)

Claude Design canvas "Hermes: Voice conversation", built on the Hermes App design system: https://claude.ai/artifact/BYc6MeZNbgJG89JfrREzNa (private; ask its owner for access). 26 call-screen states on 11 boards, drawn once on a shared `VoiceCall` component and laid out in rows:

- Start (iPhone): 1 consent off (Start disabled), 2 consent on, 3 GPT-Live note, 4 speech or voice model not set up, 5 microphone blocked.
- In the call (iPhone): 6 connecting, 7 listening, 8 muted, 9 sending, 10 thinking, 11 speaking.
- Special: 12 waiting for you (approval stays in the chat), 13 speak replies off, 14 transcription failed, 15 route changed.
- Stopped: 16 interrupted by a phone call, 17 left the app, 18 nobody spoke for 5 minutes, 19 ended by the user or a stop phrase, 20 speech failed.
- Dark and largest text: 21 to 23 dark (start, listening, speaking), 24 to 26 at 2x text (start, sending, stopped).
- Mac: consent as a 480 pt dialog over the chat, speaking with the microphone paused (dark), stopped after idle.
- Android: start, listening, stopped on leaving the app.
- Chat header: call offered, call running with the Hands-free strip and End, call not offered.

Decisions taken in the design pass:

- **One orb, five jobs.** A 112 pt circle (surface-high, 2 pt foreground ring) holding a 48 pt icon per state: spinner, mic, struck mic, up arrow, three dots, speaker, chat bubble, stop square. Two rings behind it scale with the input or output level (amplitude 0-1) and are static under reduce-motion. The orb is the interrupt button only while speaking ("Interrupt the assistant"); in every other state it is not a target.
- **Words and icons carry state.** The state word (22 pt semibold, `role=status`) sits under the orb with a one-line hint. Colour is never the only signal: the recording dot is next to the words "Hands-free on", muted is a grey dot plus "microphone muted", problems use the warning triangle plus a word.
- **The Hands-free strip** is a pill under the top bar: dot, "Hands-free on", "· microphone open | paused | muted | opening". It is also in the chat header when the call screen is closed, with a 44 pt End action, so a running microphone is never out of sight. At 2x text it keeps the dot and "Hands-free on" and drops the second half.
- **Sending is its own state** (up arrow, the words in italics, "End or mute now to cancel"). It is the last moment to cancel by End or mute; after the submit the reply belongs to the chat.
- **Consent sits in a bordered card** above the checks: the sentence about what happens, then the `SwitchRow` "Send what I say automatically" with the subtitle "Off again for the next call". Start call is the filled button and stays disabled until the switch is on; "Use dictation instead" is the text button under it. Not-ready screens have no consent row to act on, only the fix actions.
- **Controls**: Mute, Speaker (iOS and Android only) and End call as 56 pt circles with a label under each (44 pt minimum met); End is the filled dark circle, never red. The Mac dialog drops Speaker. "Speak replies" is a `SwitchRow` under the controls; with it off the hint reads "Replies are not spoken. The answer will be in the chat."
- **Last two turns** are two plain lines (You, Hermes), not bubbles, under the hint. The live caption of a turn being sent replaces them.
- **Stopped** shows the orb with a stop square (or a check after a plain End), the word "Stopped" and one notice card; "Back to chat" is filled, "Start a new call" outlined. The strip is gone because the microphone is closed.
- **Notices**: an info or warning icon, a bold sentence, then muted detail. Copy below.
- **Desktop**: a 480 pt dialog centred over the dimmed chat from 760 pt; no sheet on the Mac; Escape ends the call. While Hermes speaks the strip says "microphone paused" and the hint tells the user to tap the orb.
- **Large text**: the start screen's body must scroll, with the consent switch and Start call pinned at the bottom (the canvas shows the overflow at 2x; library controls do not scale on the canvas, so check them in the catalog).

Corrections where this brief or the first draft did not work:

- The first draft's composer toggle and orb-first call screen are replaced by the shipped header button and call page (design.md, "What exists").
- 1.25 s pause became the shipped 0.9 s; "end on background" became "iOS keeps running, others end".
- "Sending" needed a state of its own so End and mute have a visible last moment.
- At 2x text the Hands-free strip wrapped to three lines; it now drops its second half.

Copy added by the design:

- Start: "Ready to call", "Talk to Hermes without using your hands. Your microphone is closed until you start.", "Hermes sends each thing you say after a pause, without you pressing send. It can use its tools to act on it.", "Send what I say automatically", "Off again for the next call", "Turn on the switch to start. Nothing is recorded until you do.", "You can end the call at any moment.", "The call ends if you leave Hermes." (Android and desktop), "The call ends if you hide or minimise Hermes." (desktop call page).
- GPT-Live: "This profile uses GPT-Live on the web. This app uses the standard voice chat: it listens, sends, then speaks."
- Checks: "Voice model · The voice chat model follows your main model." and "Hermes speech · Your server has no text-to-speech provider with credentials."
- States: "Connecting…", "Listening", "Muted", "Sending", "Thinking", "Speaking", "Waiting for you", "Stopped", "Call ended"; hints "Speak, then pause. Hermes sends what you said.", "Nothing is captured or sent. Unmute to talk.", "Sending what you said. End or mute now to cancel.", "Hermes is working on your request.", "Tap the orb, or just talk, to interrupt.", "Microphone paused while Hermes speaks. Tap the orb to interrupt.", "Hermes asks to approve a command. Answer in the chat; saying yes does not approve it."
- Notices: "Couldn't hear that. Nothing was sent.", "Audio route changed. Please repeat if needed. Nothing was sent.", "The call was interrupted. Another call or app took the audio. The microphone is closed. Your earlier turns are in the chat.", "The call ended. You left Hermes, so the microphone was closed. Your turns are in the chat.", "No one spoke for 5 minutes. The microphone is closed.", "The microphone is closed. Every turn of this call is in the chat.", "Hermes could not speak this reply. Check your speech provider on the server. The reply is in the chat."
- Tones (no copy): rising on listening, a soft tick on sent, falling on stopped.

What the canvas could not show: the tones, haptics, screen-reader announcements and reduce-motion; they are in design.md and need a device.

## Who and why

Someone who wants to talk to their agent while their hands are busy: walking, cooking, driving a desk chair across the room. They are on a phone most of the time and on a Mac or Android less often. They trust the app with the microphone only as far as it is clear when it is open and what it sends. The design leans on three facts: sending is automatic, so consent is per call; the microphone is the sensitive part, so it is always visible and always closeable; the agent can act, so approvals never go through voice.

## Shared kit (reuse, do not invent)

- Start screen: the shipped `VoiceCallSetupView` (checks, actions), extended. `SwitchRow` equivalent: the app's `GroupedSwitchRow` / adaptive switch.
- Call page: the shipped `VoiceCallView`, extended. Buttons: the filled, outlined and text buttons; `NamedIconButton` for the 44 pt header and End actions.
- Dialog at 760 pt or wider: `showAdaptiveSheet` (dialog on wide windows and every Mac width; no bottom sheets on the Mac).
- Icons from `AppIcons`; status icon plus word, never colour alone.
- Settled rules from the design-pass skill apply: no filled destructive button (End is filled neutral), target sizes, honour text size with no cap.

## Catalog widgets (plain models, no controller)

1. `VoiceOrb`: `state`, `amplitude`, `onTap` (non-null only while speaking), `reduceMotion`.
2. `HandsFreeStrip`: `microphone` (open, paused, muted, opening), `onEnd` (null on the call page).
3. `VoiceCallView` (extended): orb, state word and icon, hint, caption, `VoiceTurnList`, controls, "Speak replies" switch, `VoiceCallNotice` slot.
4. `VoiceTurnList`: the last two turns.
5. `VoiceCallNotice`: icon, title, detail; info and warning tones.
6. `VoiceConsentRow`: the card with the sentence and the switch; used by `VoiceCallSetupView` (extended with the voice model row, the GPT-Live note, the platform footer).
7. Use cases: every one of the 26 states above, phone and 480 pt desktop width, light and dark, text scale 1x and 2x, plus the chat header's three states.

## Navigation

- Entry: the chat header's "Start voice call" (phone icon) on every platform that passes availability; "Return to call" while one runs. No composer toggle.
- Phone: full-screen route (shipped), "Show chat" leaves it without ending the call. Wide: 480 pt dialog. Mac: window-modal dialog, Escape ends.
- End returns to the chat; the thread holds every turn.

## Accessibility

- State word is a live region; screen readers announce "Hermes is speaking" and the notices.
- All targets 44 pt (48 dp) or more on touch, 28 pt on the Mac.
- Reduce-motion: static rings. Largest text: scrolling body, pinned consent and Start.
- Tones and haptics are the second channel, never the only one.

## Differences by platform

See design.md's table. Visible differences: Speaker control (iOS, Android), "microphone paused" while speaking (macOS, Windows, Linux), the leave-the-app footer (Android, desktop), the system call UI (iOS).
