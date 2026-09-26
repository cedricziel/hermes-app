# Tasks

One PR, `feat(chat)`, under about 500 changed lines. No telemetry to add. No API route change, so no OpenAPI regeneration.

## 1. Composer card

- [x] 1.1 Write failing widget tests for `ChatComposer` (bottom row order, send enabled by text or attachments, Enter and Shift+Enter, attach callback, hint while replying), then build `lib/src/chat/widgets/chat_composer.dart` until they pass
- [x] 1.2 Add Widgetbook use cases for the composer (empty, text, with attachments, replying with queue, no pill) and verify `test/widgetbook_test.dart` passes in both themes and on phone and desktop

## 2. Wiring

- [x] 2.1 Build `ChatComposer` from `buildChatComposer` inside a `Positioned` that reports its height to `ComposerHeightNotifier`, and verify `test/chat_composer_builder_test.dart` and the chat screen tests pass, changing only finders that named the package `Composer`, its send button or the paper-clip icon
- [x] 2.2 Check the chat workflow screenshots on phone and desktop, light and dark (`workflow-screenshots` skill)

## 3. Docs and verification

- [x] 3.1 Update `CLAUDE.md`'s Chat paragraph and any stale `.claude/skills` entry
- [ ] 3.2 Run `dart format --output=none --set-exit-if-changed .`, `flutter analyze`, `flutter test`, and check the composer in the running app with the `verify-in-app` skill when `hermes` is available
