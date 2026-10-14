## Decisions

The editor already accepts plain text and save callbacks, so its existing standalone catalog cases can cover each platform directly. Use SettingsScaffold with a form action and cancellation, GroupedSection/GroupedTextFieldRow for metadata and GroupedSegmentedRow for Edit/Preview. Retain the borderless code editor, markup toolbar and UndoHistoryController. Platforms: iOS, macOS, Android, Windows and Linux. No watchOS, native, API, auth or telemetry changes.

## Verification

Run editor/navigation behavior tests, catalog cases, native creation/error/discard workflow renders, isolated live inspection, formatting, analysis and strict validation.

Thirty-six standalone editor catalog cases and the save/dismissal regression test passed. Six explicit iOS/macOS creation workflows passed, covering name/category, formatting, preview, save refusals, unreachable saves, discard and successful creation; light/dark renders were inspected. Live macOS editing/preview, blank-name Save gating and unsaved discard prompting were checked against the verified throwaway backend. No skill was saved. Verification processes stopped. The React design copy uses matching adaptive scaffolding and grouped controls; its build/typecheck passed. Analysis and strict validation passed. Verification guidance now covers refreshing the native app binding after window resizing.
