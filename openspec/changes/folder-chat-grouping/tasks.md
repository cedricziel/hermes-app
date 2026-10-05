## 1. Folder data and preferences

- [x] 1.1 Write failing tests, then parse session folder metadata, group pinned and unassigned chats, disambiguate paths, and persist grouping and disclosure preferences safely.

## 2. Adaptive list controls

- [x] 2.1 Add Widgetbook cases for the grouping menu and section headers before screen integration; cover Apple platforms, long labels, and collapsed headers.
- [x] 2.2 Write failing widget tests, then integrate the compact menu and folder sections while preserving search, selection, and paging. No telemetry or API regeneration needed.

## 3. Verification

- [x] 3.1 Run dart format, flutter analyze, flutter test, strict spec validation, and the isolated verify-in-app loop; inspect real renders. Review existing verification skills for stale guidance. Commit as feat(chat): add folder grouping to chat lists.

Validation completed on 2026-10-05: formatting, static analysis, and strict
spec validation passed. The final test run passed 4,858 tests with 96 skipped,
excluding `onboarding_workflow_test.dart`. Its phone onboarding test fails
with pending HTTP timers against the original sidebar as well.

The isolated macOS app verified grouping, header placement, selection, and
preserved disclosure state. iOS was checked with widget tests and rendered
previews. The disposable app and backend were stopped.
