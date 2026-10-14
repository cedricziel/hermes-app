# Tasks

One PR, `feat(watch): add quick replies and double tap to a chat`. No API routes change.

## 1. Spec

- [x] 1.1 Write this change and commit it on its own.

## 2. Implementation

- [x] 2.1 Core already refuses a send while sending or loading and trims text (existing `ConversationModelTests`); confirm with `swift test` that nothing needs to change there.
- [x] 2.2 Add the quick-reply chips to `ConversationView.swift`, disabled while busy and hidden while recording.
- [x] 2.3 Add `handGestureShortcut(.primaryAction)` to the microphone and "Stop and send" buttons.

## 3. Docs and verify

- [x] 3.1 Update the watch line in CLAUDE.md.
- [x] 3.2 Verify: `swift test` in `ios/HermesWatch`, the `xcodebuild` compile check of the watch target, a simulator screenshot of a chat with the chips, `dart format`, `flutter analyze`.
