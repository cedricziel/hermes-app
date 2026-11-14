# Tasks

Ordered. Catalog widgets first (`component-catalog` skill), then logic, then wiring. Four PRs, each reviewable alone; the new platforms stay hidden until PR 4.

1. `feat(voice): call widgets in the catalog` (group 1)
2. `feat(voice): consent, stop phrases and safe teardown` (groups 2 and 3)
3. `feat(chat): voice turn flags` (group 4)
4. `feat(voice): voice calls on Android and desktop` (groups 5 and 6)

No OpenAPI or OpenRPC change. Never hand-edit `packages/hermes_api`.

## 1. Catalog widgets (plain models, no controller)

- [ ] 1.1 `VoiceOrb` (`lib/src/voice/widgets/voice_orb.dart`): states connecting, listening, muted, sending, thinking, speaking, waiting, stopped; `amplitude` 0-1; reduce-motion static; optional `onTap` with the label "Interrupt the assistant" enabled only while speaking. Widget tests for each state and the label. Use cases: each state, light and dark, text scale 1x and 2x.
- [ ] 1.2 `HandsFreeStrip`: "Hands-free on" with the recording dot, "Muted" variant, End button; used in the call view and the chat header. Use cases, both themes, phone and desktop width.
- [ ] 1.3 Extend `VoiceCallView`: orb in place of the icon tile, state word with icon, caption, `VoiceTurnList` (last two turns, user or assistant), "Speak replies" switch, Mute, Speaker (iOS and Android only), End, the notice area. New `VoiceCallNotice` (info and error: "Couldn't hear that. Nothing was sent.", "Audio route changed. Please repeat if needed.", "The call was interrupted", "Stopped: no one spoke for 5 minutes", "Waiting for you in the chat"). Existing tests in `test/voice/calls/voice_call_view_test.dart` stay green; add cases.
- [ ] 1.4 Extend `VoiceCallSetupView` (scrolling body, consent row and Start call pinned at the bottom) with `VoiceConsentRow` (switch, sentence, "Start call" disabled until on, "Use dictation instead"), the GPT-Live note, the `voice_chat` check row, and "The call ends if you leave Hermes" on Android and desktop.
- [ ] 1.5 Use cases in `widgetbook/voice_call_use_cases.dart`: every board of the canvas (see `docs/design-briefs/voice-conversation.md`), phone and desktop width (480 pt dialog), both themes, largest text. `test/widgetbook_test.dart` passes, one run at a time.

## 2. Consent and state (TDD)

- [ ] 2.1 Failing tests: `VoiceCall` with `consented: false` never calls `bridge.start` or opens capture; the setup screen's switch starts off on every open, "Start call" is disabled until it is on, nothing is stored (preferences untouched). Implement.
- [ ] 2.2 Failing tests for the Sending phase: transcribing plus submit shows Sending; End or mute during it sends nothing (fake agent records no `reply`); a turn already submitted stays and End stops its reply. Implement.
- [ ] 2.3 Failing tests: transcription failure and timeout drop the turn with the notice and listen again; two in a row end the call; a success resets the count; no text reaches events. Implement (changes the shipped end-on-first-failure).
- [ ] 2.4 Failing unit tests for the stop-phrase matcher (NFKC, punctuation, leading addresses, built-in list, profile list, empty list) and the echo guard (0.6, sliding window). Implement in `lib/src/voice/calls/`; replaces the hang-up regex.
- [ ] 2.5 Failing tests for the 5-minute idle end (fake clock), the pause from `voice.silence_duration` (3.0 means 0.9 s, clamps 0.5-3 s) and the missing-section defaults. Implement.
- [ ] 2.6 Tones (generated PCM) and haptics behind a seam; tests with a fake player and haptic recorder: tone on listening, sent, stopped; none when the bridge is not active. Live-region announcement text test.

## 3. Teardown (TDD)

- [ ] 3.1 Failing tests for the exit order on every path (End, stop phrase, deactivated, error, sign-out, profile change, chat change, idle, dispose): capture stops first; a throwing speech socket, player, audio session or lease release does not skip the next step; once only. Implement `_end`.

## 4. Voice turn flags (TDD)

- [ ] 4.1 Failing transport tests: `send(voiceTurn: true, interrupted: true)` puts both flags in `prompt.submit`; a typed send neither; `{"voice_stopped": true}` is its own outcome that ends the call. Extend `ChatTransport.send`, `HermesGatewayTransport`, `FakeChatTransport`, `ChatController.submit`; the queue and retry keep the flags. `ChatCallAgent.reply` sets them.
- [ ] 4.2 `VoiceAvailability` (`voice-config`, `voice_chat` slot, 404s, no main model, `no credentials`) against `FakeHermesServer`; re-read triggers; `_canCall` uses it and the platform list. iOS readiness gains the `voice_chat` row.

## 5. Portable bridge

- [ ] 5.1 Add `flutter_soloud` to `pubspec.yaml` (`flutter pub upgrade` rule applies). Confirm `flutter build macos --debug` and CI's Linux build; add `libasound2-dev` to the Linux job if needed.
- [ ] 5.2 `PortableCallBridge` behind `CallBridge`, with fake recorder and player seams: pcm events, mute, play at the `start` rate with the odd-byte carry, drain, stop, `deactivated` on focus loss, `audioReset` on a route change, pause capture while playing where barge-in is off. Tests first.
- [ ] 5.3 Lifecycle: background and hidden end the call except on iOS; Android `MODIFY_AUDIO_SETTINGS` and `audio_session` configuration; `.deb` `Depends` gains `libasound2 | libasound2t64` in `scripts/package-linux.sh`. Build iOS (simulator), Android (debug APK), the Linux package.
- [ ] 5.4 Header button on all platforms through `_canCall`; call dialog at 760 pt or wider, window-modal sheet on the Mac; hidden in conversation windows.

## 6. Docs and verification

- [ ] 6.1 Add a voice-call step to the chat workflow test with fake audio seams and check its screenshots (`workflow-screenshots`).
- [ ] 6.2 Contract checks in `test/real_backend_contract_test.dart`: the `voice_chat` row in `/api/model/auxiliary`, the `voice-live/status` shape, `speak-stream` `start` and PCM for a short text behind `HERMES_DEV_MODEL_CALLS`.
- [ ] 6.3 Update `docs/architecture/voice.md` (replace the "planned" sentence), `docs/voice-calls.md` (consent, failure, idle, other platforms), CLAUDE.md's Voice line only if its rules change, and the `verify-in-app` skill (a call against the dev backend: Edge speech needs ffmpeg on the host, local Whisper, microphone permission).
- [ ] 6.4 Run `dart format --output=none --set-exit-if-changed .`, `flutter analyze`, `flutter test`.
- [ ] 6.5 Device checks, recorded as not verified until done: iPhone speaker barge-in and an incoming call; Android echo, Bluetooth, focus loss and background end; Mac call with `verify-in-app`; Windows and Linux microphone and output; VoiceOver and TalkBack announcements and tones.
