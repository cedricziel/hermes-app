## 1. Reasoning

- [x] 1.1 Read `reasoning.delta` and `reasoning.available` in the gateway transport, `reasoning` on session message rows, and fold them into `ChatMessage.reasoning`
- [x] 1.2 Map it to a reasoning message before the tool calls, hide the thinking dots once it shows, and render it as a folded `ReasoningBlock`

## 2. Reply actions

- [x] 2.1 Flag a streaming text so no bar shows under it
- [x] 2.2 Add `MessageActions` (Copy, Try again) under finished assistant replies, with Try again on the latest reply only
- [x] 2.3 Send the last prompt again from the chat screen without touching the composer

## 3. Verify

- [x] 3.1 Tests for the events, the reply fold, the mapper, the repository, the block and the bar; format, analyze and the full suite pass
