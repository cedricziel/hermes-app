# Tasks

Ordered. Catalog widgets first (`component-catalog` skill), then logic, then wiring. Five PRs, each reviewable alone; the new platforms and the extras stay hidden until their PR.

1. `feat(voice): call widgets in the catalog` (group 1)
2. `feat(voice): consent, safe stopping and teardown for the iOS call` (groups 2 to 4, 7: includes the docs and the migration)
3. `feat(chat): voice turn flags and outcomes` (group 5)
4. `feat(voice): voice calls on Android and desktop` (groups 6 and 8)
5. `feat(voice): turn list, speak-replies switch and tones` (group 9; can be cut without weakening the safety rules)

No OpenAPI or OpenRPC change. Never hand-edit `packages/hermes_api`. Strings go to `lib/l10n/arb/app_en.arb` and `app_de.arb` under the voice anchor, read with `context.l10n`.

## 1. Catalog widgets (plain models, no controller)

- [ ] 1.1 `VoiceOrb` (`lib/src/voice/widgets/voice_orb.dart`): states connecting, listening, muted, sending, thinking, speaking, waiting, stopped; `amplitude`; reduce-motion static; `onTap` ("Interrupt the assistant") non-null only while speaking. Tests and use cases for each state, both themes, text 1x and 2x.
- [ ] 1.2 `HandsFreeStrip` (open, paused, muted, opening; End action): used in the shell and the call view. Use cases, phone and desktop width, 2x text (drops its second half).
- [ ] 1.3 Extend `VoiceCallView`: orb, state word with icon, caption, `VoiceCallNotice`, controls (Speaker on iOS and Android only), the "Waiting for you in the chat" text and the Sending hint "Hermes is getting your words ready. End or mute now to cancel." Existing `test/voice/calls/voice_call_view_test.dart` stays green.
- [ ] 1.4 Extend `VoiceCallSetupView` (scrolling body, consent row and Start call pinned at the bottom) with `VoiceConsentRow`, the GPT-Live note, the `voice_chat` and audio output rows, "Use dictation instead", and "The call ends if you leave Hermes" on Android and desktop.
- [ ] 1.5 Move the existing call views' strings to ARB (en, de) with the new ones; the 26 states of the canvas as use cases in `widgetbook/voice_call_use_cases.dart` at phone and 480 pt width; `test/widgetbook_test.dart` passes, one run at a time.

## 2. Consent, stopping, teardown (TDD, iOS call first)

- [ ] 2.1 Failing tests: `VoiceCall` with `consented: false` never starts capture; the setup switch starts off on every open and after "Start a new call", Start is disabled until it is on, nothing is stored. Implement.
- [ ] 2.2 Failing tests for Sending: it ends at `submit`; End or mute before it sends nothing, including a mute during the speech-socket wait (`muted` and the epoch re-checked right before `agent.reply`); after submit End stops this turn's reply. Implement.
- [ ] 2.3 Failing tests: transcription failure drops the turn with the notice and listens; two in a row end the call; a success resets; hallucination transcripts ("Thank you.", "Bye", repeats) and empty ones are dropped silently. Port `is_whisper_hallucination`. Implement.
- [ ] 2.4 Failing unit tests for the stop-phrase matcher (lowercase, trimmed punctuation, leading addresses, built-in list including "end the call", `["stop"]` treated as unset, another profile list honoured, empty list off) and the `silence_duration` rule (3.0 unset, clamp 0.5 to 3 s). Implement; replaces the hang-up regex. Migration note in the PR.
- [ ] 2.5 Failing tests for Waiting for you: onset while `attention` interrupts nothing and sends nothing, capture pauses and resumes when the request closes; the stall watchdog is suspended while capture is paused by design (desktop playback, waiting, mute) and still fires when capture truly stalls. Implement.
- [ ] 2.6 Failing tests for barge-in: onset stops playback and the speech socket only; the reply is stopped (`agent.interrupt`) only when a real turn is about to be submitted; an echo, empty or hallucinated transcript leaves the reply running in the chat. Implement.
- [ ] 2.7 Failing tests for the idle limit (fake clock: 5 minutes without speech and reply), and background or hidden ending the call except on iOS. Implement.
- [ ] 2.8 Add `CallBridge.stopCapture`. Failing tests for teardown order on every exit path (End, stop phrase, deactivated, error, sign-out, profile change, chat change, idle, dispose): capture first, each step with a 2 s timeout, a throw or hang skips nothing, runs once; End during a pending start closes capture on resolve. Implement.
- [ ] 2.9 Telemetry: reasons stop_phrase, background, idle, transcription, focus_lost added; `voice_call.consent` breadcrumb; a test that no text reaches events or breadcrumbs.

## 3. Shell strip and entry

- [ ] 3.1 Wire `HandsFreeStrip` into the app shell on every screen while the microphone is open; "Show chat" and Escape leave the call screen without ending the call; End on the strip ends it. Test and workflow screenshot.
- [ ] 3.2 `_canCall` loses the iOS-only check (platform list, chat state); the start screen's checks hold the rest, reusing `VoiceSupport.textToSpeech`, the `voice_chat` row (warning on a failed or 404 read), the audio output check and the `voice-live/status` read. Tests against `FakeHermesServer`: no credentials, older server 404, GPT-Live.

## 4. Docs ship with PR 2

- [ ] 4.1 Update `docs/voice-calls.md` (consent, model route and `interrupted` note, failure and speech-failure behaviour, stop phrases, idle, other platforms), `docs/architecture/voice.md` (replace "planned"), and CLAUDE.md's Voice line, which is already false for the shipped call.

## 5. Voice turn flags and outcomes (TDD)

- [ ] 5.1 Failing transport tests: `send(voiceTurn: true, interrupted: true)` puts both flags in `prompt.submit`, a typed send neither, a voice turn never carries `queued`; `ChatCallAgent` refuses while a reply runs or the queue is not empty and the call shows "Hermes is still answering. Nothing was sent."; `queued`, `steered` and `redirected` answers end the wait at once with "Hermes was busy. Your words are in the chat."; `voice_stopped` for a typed and a spoken prompt leaves no placeholder and ends a running call. Implement across `ChatTransport.send`, `HermesGatewayTransport`, `FakeChatTransport`, `ChatController.submit`, `ChatCallAgent`.
- [ ] 5.2 `interrupted` has one rule: first spoken turn after the user cut off speech by tap or by speaking over it, cleared once sent. Test.

## 6. Portable bridge

- [ ] 6.1 Add `flutter_soloud` to `pubspec.yaml`; re-check open issues and the alternatives; keep it out of iOS initialisation and conversation-window plugin registration; `flutter build macos --debug`; CI's Linux job and the release-please Linux packages (x86_64, arm64) build, adding `libasound2-dev` if needed.
- [ ] 6.2 `PortableCallBridge` behind `CallBridge` with fake recorder and player seams, tests first: pcm events; mute; `stopCapture`; play at the `start` rate with the odd-byte carry; drain; stop; pause capture while tones or speech play and resume 400 ms after the drain (no echo cancellation); `deactivated` on Android audio-focus loss (permanent and transient, not duck); `audioReset` on a route change; cancellable start; `speaker` on Android through `audio_session`.
- [ ] 6.3 Echo guard (similarity 0.6, sliding window) on the first transcript after playback, every platform. Tests first.
- [ ] 6.4 Android `MODIFY_AUDIO_SETTINGS`, `audio_session` configuration; the Linux package `Depends` gains `libasound2 | libasound2t64` in `scripts/package-linux.sh`. Build iOS (simulator), Android (debug APK), the Linux package.
- [ ] 6.5 Header button and the 480 pt dialog on all platforms (`showAdaptiveSheet`, dialog on the Mac); hidden in conversation windows. Device checks recorded as not verified until done: iPhone speaker barge-in and an incoming call; Android echo, Bluetooth, focus loss and background end (decides whether barge-in stays on by default); Mac call; Windows and Linux microphone and output; VoiceOver and TalkBack.

## 7. Verification of the iOS migration

- [ ] 7.1 Contract checks in `test/real_backend_contract_test.dart`: the `voice_chat` row, `voice-live/status`, `speak-stream` `start` and PCM behind `HERMES_DEV_MODEL_CALLS`, and `GET /api/config` returning `["stop"]` for an unset `voice.stop_phrases`.
- [ ] 7.2 Update the `verify-in-app` skill: a call against the dev backend (Edge speech needs ffmpeg on the host, local Whisper, microphone permission) and a `voice-device-check` note for echo and barge-in.
- [ ] 7.3 Run `dart format --output=none --set-exit-if-changed .`, `flutter analyze`, `flutter test`.

## 8. Voice-call step in the workflow test

- [ ] 8.1 Add a call step with fake audio seams to the chat workflow test and check its screenshots (`workflow-screenshots`).

## 9. Extras (PR 5)

- [ ] 9.1 `VoiceTurnList` (last two turns) in the call view; use cases.
- [ ] 9.2 "Speak replies" switch: logic (skips the socket and the `tts-lease`, says "Reply is in the chat"), tests, use cases.
- [ ] 9.3 Tones (generated PCM) and haptics behind a seam, played with capture paused, tests with a fake player; live-region announcement text test; the `tts-lease` warm-up (`app:conversation:<id>`, failure ignored) with its test.
- [ ] 9.4 Roadmap: move the 4.11 row and its status with each merged PR (done by the orchestrator).
