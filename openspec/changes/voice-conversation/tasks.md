# Tasks

This change lands after `voice-dictation`, as three stacked PRs of about 500 changed lines each:

1. `feat(voice): speak replies through Hermes` (groups 1 and 2)
2. `feat(voice): run the voice conversation loop` (group 3)
3. `feat(chat): voice calls from the composer` (groups 4 to 6)

The toggle stays hidden until PR 3. No OpenAPI change: every REST route is already in the generated client.

## 1. Availability and send flags

- [ ] 1.1 Write failing tests for `VoiceAvailability` against `FakeHermesServer`. Cover:
  - usable speech-to-text and text-to-speech with `voice_chat` following a set main model;
  - a pinned `voice_chat` model;
  - `tts.reason` set to `no credentials`;
  - no `voice_chat` task;
  - an empty `main.model`;
  - 404 from either route.

  Then build `lib/src/voice/voice_availability.dart` until the tests pass.

- [ ] 1.2 Write failing transport tests: `send(voiceTurn: true, interrupted: true)` puts both flags into `prompt.submit`, a typed send puts in neither, and `{"voice_stopped": true}` becomes its own submit outcome. Extend `ChatTransport.send`, `HermesGatewayTransport`, `FakeChatTransport` and `ChatController.send` until they pass.

## 2. Speech playback

- [ ] 2.1 Add `flutter_soloud` and `audio_session` to `pubspec.yaml`. Verify that `flutter build macos --debug` and CI's Linux build still pass, adding `libasound2-dev` to the CI Linux job if needed.
- [ ] 2.2 Write failing tests for `SpeechSession` with a fake socket and a fake `SpeechPlayer`:
  - text frames hold only the new suffix, and `done` goes out at the end;
  - the player opens at the `start` rate, and an odd trailing byte carries over;
  - `end` finishes the session, and `stop` sends `stop` and stops the player;
  - `fallback`, or a failure before any audio, calls `POST /api/audio/speak` and plays the data URL;
  - a failure after audio has started counts as finished.

  Then build `lib/src/voice/speech_session.dart` and the SoLoud-backed `SpeechPlayer` until the tests pass.

## 3. Conversation loop

- [ ] 3.1 Write failing unit tests for `VoiceActivity` on synthetic PCM:
  - noise-floor calibration;
  - speech start;
  - the end of a turn after the configured pause;
  - the 60 s cap;
  - the barge-in window, with its raised trigger and grace period.

  Then build `lib/src/voice/voice_activity.dart`.

- [ ] 3.2 Write failing unit tests for the stop-phrase matcher (NFKC, punctuation, the leading-address prefixes, the built-in list, a profile list, an empty list) and the echo guard (ratio 0.6, sliding window). Then build both in `lib/src/voice/`.
- [ ] 3.3 Write failing tests for `VoiceConversationController` with `FakeChatTransport`, a fake recorder, a fake transcriber and a fake speech session:
  - a full turn sent with `voiceTurn`;
  - silence not sent;
  - a stop phrase ends the call;
  - a reply streamed into speech, with its sealed prose included;
  - "Speak replies" off;
  - a tap interrupts, stops the reply, and sends the next turn with `interrupted`;
  - barge-in on iOS/Android only, with the echo ignored;
  - two microphone failures end the call;
  - leases held and released;
  - `voice_stopped` ends the call.

  Then build the controller until the tests pass.

- [ ] 3.4 Add the breadcrumbs `voice.conversation.started|ended` (`reason`), `voice.turn.sent` (`interrupted`) and `voice.speech.fallback` through `Breadcrumbs`, with a test that no text reaches the trail.

## 4. Call screen in the catalog

- [ ] 4.1 Write failing widget tests for `VoiceOrb` (the five states and amplitude scaling) and `VoiceCallScreen`:
  - the caption and hint for each mode;
  - the last two turns;
  - the mute and End controls;
  - the orb enabled only while speaking, with the label "Interrupt the assistant";
  - the recording indicator;
  - the GPT-Live note.

  Then build them in `lib/src/voice/widgets/`.

- [ ] 4.2 Add Widgetbook use cases for the orb in each state and palette, and for the call screen in each mode at phone and desktop width. Verify that `test/widgetbook_test.dart` passes in both themes.
- [ ] 4.3 Write failing `ChatComposer` tests for the Start voice toggle: shown only with a `VoiceAvailability` that allows it, placed beside the dictation microphone, and labelled "End voice" during a call. Add its Widgetbook use case.

## 5. Wiring and platforms

- [ ] 5.1 Write a failing chat-screen test: the toggle shows when both voice routes answer as compatible, a call opens the call screen, sends a spoken turn into the thread, and leaves the turns in the thread after End. Wire the controller, the availability checks (including a refresh after Helper models saves) and the lifecycle (background, profile switch, opening another chat) into `ChatScreen` until the test passes.
- [ ] 5.2 Configure `audio_session` for calls on iOS and Android, and add `MODIFY_AUDIO_SETTINGS` to the Android manifest. Add `libasound2 | libasound2t64` to the `.deb` `Depends` in `scripts/package-linux.sh`. Verify by building iOS (simulator), Android (debug APK) and the Linux package.
- [ ] 5.3 Add a voice-call step to the chat workflow test, using fake audio seams, and check its screenshots (workflow-screenshots skill).

## 6. Docs and verification

- [ ] 6.1 Add contract checks to `test/real_backend_contract_test.dart`: the `/api/model/auxiliary` `voice_chat` row, the `voice-live/status` shape, and `speak-stream` returning `start` and PCM for a short text. Put the last one behind `HERMES_DEV_MODEL_CALLS`.
- [ ] 6.2 Update `CLAUDE.md` (the Voice paragraph) and the `verify-in-app` skill. Cover how to run a call against the dev backend: Edge text-to-speech needs ffmpeg on the host, local Whisper speech-to-text, and the microphone permission. Add a `voice-device-check` note to the skill for the iOS echo and barge-in check.
- [ ] 6.3 Run `dart format --output=none --set-exit-if-changed .`, `flutter analyze` and `flutter test`. Hold a call in the running macOS app against `scripts/dev-backend.sh` with the `verify-in-app` skill. Check barge-in on an iPhone with the speaker on.
