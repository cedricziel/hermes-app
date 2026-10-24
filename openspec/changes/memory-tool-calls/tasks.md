# Tasks

One PR, `feat(chat): show memory saves, approvals and full memory in the tool card`, about 500 changed lines with tests. Can land in parallel with `memory-settings` and `memory-navigation`, after `memory-overview`.

## 1. Parsing

- [x] 1.1 (written from the documented shapes, not recorded: no `hermes` on the build machine) Record `tool.complete` frames of the `memory` tool (saved, staged, full, other error; `replace` and `patch`; `operations`) and the `/memory approve` and `/memory reject` answers (success, partial with "Failed:", unknown id) from Hermes `71d34bad` as fixtures, with the revision noted.
- [x] 1.2 Write failing tests for `MemoryToolOutcome.of`: the four outcomes, `replace` and `patch` alike, an invalid `pending_id` or unparsable `usage` falls back to the generic body, the percentage and X/Y numbers are read, + and − lines per action and per operation. Then implement it.
- [x] 1.3 Write failing tests for the decision-answer parser in `lib/src/memory/memory_decisions.dart`: approved, failed for this id with its reason, failed for another id only, rejected, anything else is a failure with the whole text. Then implement it.

## 2. Widgets

- [x] 2.1 Add Widgetbook use cases for `MemoryToolBody` (saved with and without percentage, staged idle, running, saved, rejected, failed with reason, unreachable, staged without actions, full) and for `ReviewSummaryNote` with the Memory link, in both themes at phone and desktop width. Build them as plain-model widgets.
- [x] 2.2 Write failing widget tests for the texts and buttons of each state. Then make them pass.

## 3. Wiring

- [x] 3.1 Write a failing test that `toolCallBody` returns `MemoryToolBody` for `memory` calls, and that a full call's card shows the warning status, not failed. Then add the case and the status rule.
- [x] 3.2 Write failing `MemoryDecisions` tests with `FakeChatTransport`: approve and reject send the right command with the chat's thread id and profile, one at a time per id, the state follows the answer, a transport error is unreachable, no actions without a stored thread id, state dropped when the thread closes. Then implement it and provide it from `chat_thread_bindings.dart`.
- [x] 3.3 Write a failing test that the review note shows "Memory" when the profile is known and opens `MemoryDestination` for it. Then wire it in `chat_builders.dart`.
- [x] 3.4 Write a failing test that a decision records `memory.proposals.decide` with `choice`, `surface: tool_card` and `outcome`, logs `memory.proposal_decided`, and a tap adds `memory.tool_card.decide`, none with ids or text. Then add them.
- [x] 3.5 Update `CLAUDE.md` (Chat: tool call bodies, the memory card and its actions) and the `verify-in-app` skill with how to make Hermes stage a write on the dev backend (`memory.write_approval: true`).

## 4. Verify

- [x] 4.1 Run `/simplify` on the diff.
- [x] 4.2 Run `dart format --output=none --set-exit-if-changed .`, `flutter analyze` and `flutter test`, all passing.
- [ ] 4.3 Use `verify-in-app` against `scripts/dev-backend.sh` (scripted model or a paid one with `HERMES_DEV_MODEL_CALLS=1`): a save shows Saved with the percentage; with "Ask before saving" on, a write shows Waiting, Approve saves it (the entry appears on the Memory screen) and Reject drops it; a proposal staged in a chat is approved after the chat is reopened; a nearly full file shows the full warning; the review note's Memory link opens the chat's profile.
