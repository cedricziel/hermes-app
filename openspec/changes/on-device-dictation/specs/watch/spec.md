# Spec Delta

## ADDED Requirements

### Requirement: Watch voice messages

The system SHALL let the user record a voice message of up to 30 seconds on the watch and send what was heard in it as the next message. The watch SHALL send the recording to the phone as a `transcribe` request. While the phone's Dictation setting uses the on-device recognizer, the phone SHALL transcribe the recording with it in the device language, and the recording SHALL NOT reach the Hermes server. When the Dictation setting is Hermes, or the on-device recognizer cannot transcribe the recording (the language has no on-device recognition, its model is not installed, or recognition fails), the phone SHALL send the recording to the active profile's speech-to-text provider. When nothing was heard, the watch SHALL report that no speech was heard and SHALL send nothing.

#### Scenario: Transcribed on the phone

- **WHEN** the phone's Dictation setting is "On this device", the model for the device language is installed, and the user records "Remind me to call Sam" on the watch
- **THEN** the watch sends "Remind me to call Sam" and the Hermes server receives no `/api/audio/` request

#### Scenario: Model not installed

- **WHEN** the phone's Dictation setting is "On this device" but the model for the device language is not installed
- **THEN** the phone sends the recording to the active profile's speech-to-text provider

#### Scenario: Hermes engine chosen

- **WHEN** the phone's Dictation setting is "Hermes"
- **THEN** the phone sends the recording to the active profile's speech-to-text provider without trying the on-device recognizer

#### Scenario: Phone app woken by the watch

- **WHEN** the watch's request starts the phone app before it has read the saved Dictation setting
- **THEN** the phone reads the setting first and transcribes with the engine it names

## MODIFIED Requirements

### Requirement: Relay through the phone

The system SHALL let the watch app read and send chats by asking the paired phone, which holds the signed-in session and the connection to the Hermes dashboard. The watch SHALL NOT hold tokens or the server address. The phone SHALL serve the watch from whoever is signed in on the phone at that moment. A request is a `threads`, `messages`, `send` or `transcribe` operation, and the answer is either success or one of the error codes in "Watch errors". The relay SHALL exist on iOS only.

#### Scenario: Signed out on the phone

- **WHEN** the watch asks for anything while nobody is signed in on the phone
- **THEN** the phone answers `signed_out` and the watch tells the user to sign in on the iPhone first

#### Scenario: Unknown or malformed request

- **WHEN** the phone gets an operation it does not know, or one missing what it needs (a `messages` request without a thread id, a `send` with blank text, a `transcribe` without audio)
- **THEN** it answers `bad_request`

### Requirement: Watch relay diagnostics

When iPhone telemetry is enabled, the system SHALL export `watch.request.started` and `watch.request.completed` events for each request received by the Dart relay. Both events SHALL include the operation and current phone authentication state. The completion event SHALL include the result code and elapsed milliseconds, and for a transcribed voice message the engine that transcribed it (`device` or `hermes`). Unknown operations SHALL be recorded as `unknown`. Events SHALL NOT include message text, audio, locale, thread identifiers, tokens, or request payloads. A telemetry failure SHALL NOT prevent the relay from replying.

The watch SHALL write local Apple logs for activation, reachability changes, request starts, reply results, and delivery failures. The native iPhone relay SHALL write local Apple logs for activation, background-task expiry, a missing Dart handler, and invalid Dart replies. These local logs SHALL NOT contain request payloads or exception messages.

When the phone cannot read its saved session from secure storage, it SHALL export `auth.session.read_failed` through its configured event logger, with the exception type only. The stored session SHALL remain untouched.

#### Scenario: Signed-out relay reply

- **WHEN** the phone answers a watch request with `signed_out` while telemetry is enabled
- **THEN** the completion event records `signed_out`, the phone authentication state, and elapsed milliseconds

#### Scenario: Voice message transcribed on the phone

- **WHEN** the phone transcribes a watch voice message with the on-device recognizer while telemetry is enabled
- **THEN** the completion event records `transcribe`, `ok` and the engine `device`, without the text or the audio

#### Scenario: Secure storage unavailable

- **WHEN** secure storage throws while the phone restores its session
- **THEN** the phone records `auth.session.read_failed` without token contents or exception details

#### Scenario: Watch cannot deliver a request

- **WHEN** WatchConnectivity fails to deliver a request to the phone
- **THEN** the watch writes a local delivery-failure log with the operation and numeric error code
