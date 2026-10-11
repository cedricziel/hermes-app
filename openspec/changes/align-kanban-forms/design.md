## Decisions

Reuse GroupedDialog's action footer, GroupedTextFieldRow, GroupedSwitchRow and GroupedMenuRow. Preserve whole-row switch toggling, empty-value active-profile choices, current unknown profile names, only-changed orchestration fields and board import validation. Keep server-path explanations visible as group footers. Platforms: iOS, Android, macOS, Windows, Linux; no watchOS or native changes. No new APIs or telemetry.

## Verification

Existing task, board and orchestration tests protect backend payloads and errors. Add grouped layout checks, update menu interaction tests and inspect platform workflow/catalog renders. Publish only after the preceding PR merges.

Eighty-five task, board and orchestration behavior checks passed. Fourteen existing catalog/workflow cases passed, and four additional workflows rendered all forms in explicit iOS/macOS light/dark styles. The profile-menu workflow also asserts the selected assignee reaches the backend. Renders were inspected; formatting, analysis and strict validation passed.
