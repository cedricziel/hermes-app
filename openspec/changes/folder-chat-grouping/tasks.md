## 1. Folder data and preferences

- [x] 1.1 Write failing tests, then parse session folder metadata, group pinned and unassigned chats, disambiguate paths, and persist grouping and disclosure preferences safely.

## 2. Adaptive list controls

- [x] 2.1 Add Widgetbook cases for the grouping menu and section headers before screen integration; cover Apple platforms, long labels, and collapsed headers.
- [x] 2.2 Write failing widget tests, then integrate the compact menu and folder sections while preserving search, selection, and paging. No telemetry or API regeneration needed.

## 3. Verification

- [ ] 3.1 Run dart format, flutter analyze, flutter test, strict spec validation, and the isolated verify-in-app loop; inspect real renders. Review existing verification skills for stale guidance. Commit as feat(chat): add folder grouping to chat lists.
