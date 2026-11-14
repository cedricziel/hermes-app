# Tasks

Ordered. Catalog widgets first (`component-catalog` skill), then logic, then wiring. Five PRs, each reviewable alone; the new platforms and the extras stay hidden until their PR.

1. `feat(voice): call widgets in the catalog` (group 1)
2. `feat(voice): consent, safe stopping and teardown for the iOS call` (groups 2 to 4, 7: includes the tones, the docs and the migration)
3. `feat(chat): voice turn flags and outcomes` (group 5)
4. `feat(voice): voice calls on Android and desktop` (groups 6 and 8)
5. `feat(voice): turn list, speak-replies switch and tones` (group 9; can be cut without weakening the safety rules)

No OpenAPI or OpenRPC change. Never hand-edit `packages/hermes_api`. Strings go to `lib/l10n/arb/app_en.arb` and `app_de.arb` under the voice anchor, read with `context.l10n`.

## 1. Catalog widgets (plain models, no controller)

- [ ] 1.1 `VoiceOrb` (`lib/src/voice/widgets/voice_orb.dart`): states connecting, listening, muted, sending, thinking, speaking, waiting, stopped; `amplitude`; reduce-motion static; `onTap` ("Interrupt the assistant") non-null only while speaking. Tests and use cases for each state, both themes, text 1x and 2x.
- [ ] 1.2 `HandsFreeStrip` (open, paused, muted, opening; End action): used in the shell and the call view. Use cases, phone and desktop width, 2x text (drops its second half).
- [ ] 1.3 Extend `VoiceCallView`: orb, state word with icon, caption, `VoiceCallNotice`, controls (Speaker on iOS and Android only), the "Waiting for you in the chat" text and the Sending hint "Hermes is getting your words ready. End or mute now to cancel." Existing `test/voice/calls/voice_call_view_test.dart` stays green.
- [ ] 1.4 Extend `VoiceCallSetupView` (scrolling body, consent row and Start call pinned at the bottom) with `VoiceConsentRow`, the GPT-Live note, the `voice_chat` and audio output rows, "Use dictation instead", "The call ends if you leave Hermes." on Android and "The call ends if you hide or minimise Hermes." on desktop.
- [ ] 1.5 Move the existing call views' strings to ARB (en, de) with the new ones; the states of the canvas as use cases in `widgetbook/voice_call_use_cases.dart` at phone and 480 pt width, except state 13 (speak replies off) and the turn list, which come with PR 5; `test/widgetbook_test.dart` passes, one run at a time.

## 2. Consent, stopping, teardown (TDD, iOS call first)

- [ ] 2.1 Failing tests: `VoiceCall` with `consented: false` never starts capture; the setup switch starts off on every open and after "Start a new call", Start is disabled until it is on, nothing is stored. Implement.
- [ ] 2.2 Failing tests for Sending: it ends at `submit`; End or mute before it sends nothing, including a mute during the speech-socket wait and during the queue restore (the requested mute, set synchronously in `setMuted`, not the bridge's confirmed `muted`); after the send End stops this turn's reply. Implement.
- [ ] 2.3 Failing tests: transcription failure drops the turn with the notice and listens; two in a row end the call; a success resets. The filter order empty, echo, hallucination, stop phrase, else sent, with "Thank you.", "Bye" and repeats dropped silently, an echoed "Goodbye." not ending the call and "goodbye" ending it. Port `is_whisper_hallucination`. Implement.
- [ ] 2.4 Read the config with `include_defaults=false` (`includeDefaults: false` on the generated client). Failing unit tests for the stop-phrase matcher (lowercase, trimmed punctuation, leading addresses; the built-in list including "end the call", "hang up" and "end call" when the key is absent; a profile list, `["stop"]` included, replacing it; a string as one phrase; a malformed value giving the built-in list; only an explicit empty list off) and for `silence_duration` (used when set, clamp 0.5 to 3 s, 0.9 s when absent). Implement; replaces the hang-up regex. Migration note in the PR.
- [ ] 2.5 Failing tests for Waiting for you: onset while `attention` interrupts nothing and sends nothing, capture pauses and resumes when the request closes, and the speech detector is reset on every pause; `attention` is read from the thread (typed and server-queued replies count, not only the call's own) and tracked per call, not per epoch, so an approval raised by a reply that is still running after a barge-in pauses capture; it is re-checked right before `agent.interrupt()` and before `submit`; a turn in Sending when the approval arrives is dropped. The stall watchdog is suspended while capture is paused by design (read from `capturePaused`) and still fires on a true stall. Implement.
- [ ] 2.6 Failing tests for barge-in: onset stops playback and the speech socket only; the reply is stopped (`agent.interrupt`) only when a real turn is about to be submitted; an echo, empty or hallucinated transcript leaves the reply running in the chat; an orb tap interrupts the reply (`agent.interrupt` awaited until the session has settled) so the next turn is not refused as still answering. Implement.
- [ ] 2.7 Failing tests for the idle limit (fake clock: 5 minutes without speech and reply), and background or hidden ending the call except on iOS. Implement.
- [ ] 2.8 Extend `CallBridge` with `activated` handling, `pauseCapture`, `resumeCapture`, `stopCapture` and the `capturePaused` event (Apple bridge included; tones and Waiting for you use pause, not CallKit mute). Route change: `audioReset` drops the turn and the speech but keeps the running reply and the Waiting for you state, with a test. A teardown test for each exit in the reason list (hang_up, stop_phrase, voice_stopped, background, idle, transcription after a second failure, interrupted, focus_lost, microphone_stalled, speech after a failed fallback, mute failure, app, app_failure, turn, native_error). Unconfirmed close: a timed-out `stopCapture` shows "The call ended, but the microphone may still be open" and the strip says so, with a test. Failing tests for teardown order on every exit path (End, stop phrase, deactivated, error, sign-out, profile change, chat change, idle, dispose): capture first, each step with a 2 s timeout, a throw or hang skips nothing, runs once; End during a pending start closes capture on resolve. Implement.
- [ ] 2.9 Telemetry: reasons stop_phrase (replacing the shipped `voice_hang_up`), voice_stopped, background, idle, transcription, focus_lost added to the shipped ones (hang_up, interrupted, app, app_failure, prepare, audio_focus, native_start, native_events, connect, microphone_stalled, native_error, speech, turn, mute); `voice_call.consent` breadcrumb; a test that no text reaches events or breadcrumbs.
- [ ] 2.11 Tones (generated PCM, rising for Listening, a tick at the send, falling at stop) and haptics behind a seam, played with capture paused, tests with a fake player; the live-region announcement text test.
- [ ] 2.12 Speech failure: a failure before audio falls back once; after audio it counts as finished; a failed fallback ends the call with "Hermes could not speak this reply" and the reply stays in the chat. Tests first.
- [ ] 2.10 App Lock: it never ends a call; under it the call screen, strip and notices show no words, and the lock cover keeps a "Hands-free on" mark with End. Test.

## 3. Shell strip and entry

- [ ] 3.1 Wire `HandsFreeStrip` into the main window's shell on every screen while the microphone is open (document that a macOS conversation window or the quick panel shows none); "Show chat" and Escape leave the call screen without ending the call; End on the strip ends it. Test and workflow screenshot.
- [ ] 3.2 The start screen's checks (still iOS in this PR): reuse `VoiceSupport.textToSpeech`, add the `voice_chat` row (resolved by a named model, a followed main model, or a provider pinned without a model; a failed or 404 read is a warning), the audio output check and the `voice-live/status` read. Tests against `FakeHermesServer`: no credentials, older server 404, provider without model, GPT-Live. The `_canCall` change is task 6.5.

## 4. Docs ship with PR 2

- [ ] 4.1 Update `docs/voice-calls.md` (consent, failure and speech-failure behaviour, stop phrases, idle, Waiting for you, route change, the migration list), `docs/architecture/voice.md` (replace "planned") and CLAUDE.md's Voice line, which is already false for the shipped call. The model-route and `interrupted` paragraphs ship with PR 3 (task 5.3).

## 5. Voice turn flags and outcomes (TDD)

- [ ] 5.0 Failing tests for the queue path: `ChatController.submit(voiceTurn: true)` awaits the persisted queue restore and returns a typed refusal (busy, no longer wanted, queue restore failed, model or branch not allowed, profile not confirmed, session reclaimed) without enqueuing, including when `queuedIn(thread)` was still empty at the pre-check; it takes a still-wanted predicate (epoch, requested mute, attention, consent) re-checked after the restore and right before `_send`. Tests: End or mute during the restore sends and queues nothing; only busy says "Hermes is still answering"; a lost session ends the call. Implement in `chat_controller.dart` and `chat_controller_queues.dart` (the `_submitAfterQueueRestore` and `_submitTo` paths).
- [ ] 5.1 Failing transport tests: `send(voiceTurn: true, interrupted: true)` puts both flags in `prompt.submit`, a typed send neither, a voice turn never carries `queued`; `ChatCallAgent` refuses while a reply runs or the queue is not empty and the call shows "Hermes is still answering. Nothing was sent."; `queued`, `steered` and `redirected` answers end the wait at once with the notice for that status; `voice_stopped` for a typed and a spoken prompt leaves no placeholder and ends a running call. Implement across `ChatTransport.send`, `HermesGatewayTransport`, `FakeChatTransport`, `ChatController.submit`, `ChatCallAgent`.
- [ ] 5.2 `interrupted` has one rule: first spoken turn after the user cut off speech by tap or by speaking over it, set only when the thread is settled (no pending reply and `session.info` running false, not just `isReplying`), kept pending across a refused, dropped or echoed turn, cleared by the first submit that reaches the transport, by mute, a route change, a typed message or 120 s, because Hermes keeps a process-wide 120 s latch. Test.
- [ ] 5.3 Update `docs/voice-calls.md`: `voice_turn` runs on the `voice_chat` model route, `interrupted` adds a note to the model's message, "no hidden instructions" no longer holds. Add the upstream request (a per-session or per-turn note instead of the process-wide latch) for the orchestrator's roadmap.

## 6. Portable bridge

- [ ] 6.1 Add `flutter_soloud` pinned to `5.3.0` with the hook user-define `no_xiph_libs: true`; read its changelog and open issues; check `media_kit` again as the alternative; confirm the build no longer downloads Xiph archives in CI, the release workflows and Linux arm64; keep it out of iOS initialisation and conversation-window plugin registration; `flutter build macos --debug`; the CI Linux job and the release-please x86_64 and arm64 packages build and run (no `libasound2-dev` expected: the plugin links only `dl` and `pthread`).
- [ ] 6.2 `PortableCallBridge` behind `CallBridge` with fake recorder and player seams, tests first: `activated`; pcm events; `pauseCapture`, `resumeCapture` and the `capturePaused` event; capture open only while Listening where barge-in is off; mute; `stopCapture`; play at the `start` rate with the odd-byte carry; drain; stop; pause capture while tones or speech play and resume 400 ms after the drain (no echo cancellation); `deactivated` on Android audio-focus loss (permanent and transient, not duck); `audioReset` on a route change; cancellable start; `speaker` on Android through `audio_session`; the voice-communication playback usage on Android through `SoLoud.init(androidAAudioAttributes: AndroidAAudioAttributes.voiceCommunication, lowLatency: false)` (barge-in stays off there until 6.5 passes).
- [ ] 6.3 Echo guard (similarity 0.6, sliding window) on the first transcript after playback, every platform. Tests first.
- [ ] 6.4 Android `MODIFY_AUDIO_SETTINGS`, `audio_session` configuration. Build iOS (simulator), Android (debug APK), the Linux packages; change `Depends` in `scripts/package-linux.sh` only if 6.1 finds a missing library.
- [ ] 6.5 `_canCall` loses the iOS-only check (platform list, chat state); header button and the 480 pt dialog on all platforms (`showAdaptiveSheet`, dialog on the Mac); hidden in conversation windows. Device checks recorded as not verified until done: iPhone speaker barge-in and an incoming call; Android echo, playback stream usage, Bluetooth, focus loss and background end (decides whether Android barge-in is turned on); Windows and Linux lifecycle reporting of hidden and paused; Mac call; Windows and Linux microphone and output; VoiceOver and TalkBack.

## 7. Verification of the iOS migration

- [ ] 7.1 Contract checks in `test/real_backend_contract_test.dart`: the `voice_chat` row, `voice-live/status`, `speak-stream` `start` and PCM behind `HERMES_DEV_MODEL_CALLS`, and `GET /api/config?include_defaults=false` omitting an unset `voice.stop_phrases`.
- [ ] 7.2 Update the `verify-in-app` skill: a call against the dev backend (Edge speech needs ffmpeg on the host, local Whisper, microphone permission) and a `voice-device-check` note for echo and barge-in.
- [ ] 7.3 Run `dart format --output=none --set-exit-if-changed .`, `flutter analyze`, `flutter test`.

## 8. Voice-call step in the workflow test

- [ ] 8.1 Add a call step with fake audio seams to the chat workflow test and check its screenshots (`workflow-screenshots`).

## 9. Extras (PR 5)

- [ ] 9.1 `VoiceTurnList` (last two turns) in the call view; use cases.
- [ ] 9.2 "Speak replies" switch: logic (skips the socket and the `tts-lease`, says "Reply is in the chat"), tests, use cases.
- [ ] 9.3 The `tts-lease` warm-up (`app:conversation:<id>`, failure ignored) with its test.
- [ ] 9.4 Roadmap: each implementing PR updates the 4.11 row's status in the same PR (CLAUDE.md). This design PR leaves it to the orchestrator.
- [ ] 9.5 If this PR is cut, amend the spec in the same PR: remove the "Speak replies" sentences from "Speaking the reply" and the turn list from the call view. The tones are core and stay (task 2.11).
