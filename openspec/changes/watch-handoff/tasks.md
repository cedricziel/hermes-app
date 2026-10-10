# Tasks

One PR, `feat(watch): hand a watch chat off to the iPhone or Mac`. No API routes change.

## 1. Spec

- [x] 1.1 Write this change and commit it on its own.

## 2. Phone

- [x] 2.1 Test first: `threads` answer carries `serverUrl`, `profile`, `sessionId`; left out without a server or profile.
- [x] 2.2 Add the `serverUrl` callback to `WatchRequestHandler` and wire it in `handlerFor`.

## 3. Watch

- [x] 3.1 Core: `HandoffTarget` with the activity payload, decoded from the `threads` answer, kept on `ThreadSummary` and `ConversationModel`. Swift tests for the payload and the decode.
- [x] 3.2 `ConversationView` advertises the activity while the chat is open (`userActivity`).
- [x] 3.3 `HandoffType.xcconfig`, `ios/HermesWatch/Info.plist`, project settings.

## 4. Docs and verify

- [x] 4.1 Update the watch spec sentence and CLAUDE.md.
- [x] 4.2 Verify: `swift test`, the `xcodebuild` compile check, the built Info.plist, `dart format`, `flutter analyze`, the touched Dart tests.
