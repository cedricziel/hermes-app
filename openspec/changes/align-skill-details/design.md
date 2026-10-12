## Decisions

Extract controller-free grouped actions, Markdown panel and background job bar with catalog coverage before screen wiring. Reuse SettingsScaffold and GroupedListView for details. Keep controller calls, error reporting, source restrictions and confirmation dialogs intact. Platforms: iOS, macOS, Android, Windows and Linux. No watchOS, native, API, auth or telemetry changes.

## Verification

Run skill behavior tests, catalog, native workflow renders, isolated live detail inspection, design-copy build, format, analysis and strict validation.

Fifty-five skill screen/hub/chat behavior tests passed, covering source restrictions, enable controls, draft-only deletion, uninstall and job lifecycle. One hundred four catalog cases passed, including reduced motion and loading failures. Six explicit iOS/macOS job/detail workflow cases passed with native confirmations and tab selectors; renders were inspected. The live macOS bundled-skill detail displayed grouped controls/content with no edit/delete/uninstall action; no profile data was changed. Verification processes were stopped. React copies use matching grouped controls/status and build/typecheck passed. Analysis and strict validation passed. The catalog skill now documents adaptive action/tab finders.
