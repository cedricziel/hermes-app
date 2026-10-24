# Tasks

One PR, `feat(memory): show memory per file with its fill level`, about 500 changed lines with tests.

## 1. Data

- [x] 1.1 Record the graph card subset (fields that link a card to its node, `body` and its 1200-character cut) and the `memory.*_char_limit` config keys from Hermes `71d34bad` in `test/memory/memory_fixtures.dart`, with the revision noted.
- [x] 1.2 Write failing `MemoryRepository` tests against `FakeHermesServer`: entries carry their text from the card; a body of 1200 characters or more, or an unmatched node, is completed from `GET /api/learning/node`; a detail that fails marks the tab's count as a lower bound; limits are read from `GET /api/config?profile=` when positive integers; a failing config read leaves the list intact and the limits unknown. Then implement it with the generated client.
- [x] 1.3 Write failing pure tests for the counting: `Σ runes + 3·(n−1)`, 0 for none, non-BMP characters count once, the editor's "left" and "over" values, and the 95% threshold. Then implement it in `lib/src/memory/memory_usage.dart`.
- [x] 1.4 Write failing `MemoryController` tests: entries split by `memorySource` (`profile` → About you, `memory` and unknown → Agent notes), position K of N within a tab, tab state cleared with the rest on sign-out and profile change, late responses of an old scope ignored. Then implement it.

## 2. Widgets

- [x] 2.1 Add Widgetbook use cases for `MemoryFillBar` (normal, ≥95% warning, no limit known, lower bound), `MemoryEntryList` (entries, empty with the hint) and `MemoryEntryEditor` (header, characters left, over the limit, "Used from the next chat"), in both themes at phone and desktop width. Build the widgets as plain-model widgets in `lib/src/memory/widgets/`.
- [x] 2.2 Write failing widget tests for the texts: "912 of 1,375 characters", entry count, the warning sentence, "Nothing remembered yet", "Entry 2 of 4 in About you (USER.md)", "N left in About you". Then make them pass.

## 3. Screen

- [x] 3.1 Write a failing `MemoryScreen` test: two tabs, About you first and selected, each with its bar and list; opening an entry shows the editor with its header; edit and delete still follow the mutation rules (existing tests keep passing). Then wire the widgets into `MemoryScreen` through `SettingsScaffold` tabs.
- [x] 3.2 Write a failing test that the config read records a `memory.fetch` span with `operation: limits`, a failure logs `memory.fetch_failed` with that operation, and switching tab adds a `memory.tab` breadcrumb with only the tab name. Then add them.
- [x] 3.3 Update `CLAUDE.md` if it describes the Memory screen, and the `verify-in-app` skill if a step to seed memory files on the dev backend is missing.

## 4. Verify

- [x] 4.1 Run `/simplify` on the diff.
- [x] 4.2 Run `dart format --output=none --set-exit-if-changed .`, `flutter analyze` and `flutter test`, all passing.
- [x] 4.3 (macOS, Hermes `d923a5eb`, 2026-10-24: "94 of 1,375 characters" matched the tool's "6% — 94/1,375 chars"; 2,109 of 2,200 showed "Full" and its warning; an edit took Agent notes to 1,620 and the file on disk; the work profile's empty Agent notes showed "Nothing remembered yet") Use `verify-in-app` against `scripts/dev-backend.sh` with seeded MEMORY.md and USER.md: the counts match the usage Hermes' memory tool reports after a save in a chat, a nearly full file shows the warning, an edit updates the count, and an empty profile shows the empty state.
