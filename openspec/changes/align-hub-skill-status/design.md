## Decisions

Extract the plain scan presentation and finding rows for standalone catalog cases before screen wiring. Use SettingsScaffold, GroupedListView, grouped scan/footer/content surfaces and shared Markdown panel. Preserve controller operations and pinned install actions, including explicit ask confirmation and blocked/unknown policy behavior. Platforms: iOS, macOS, Android, Windows and Linux; no watchOS, native, API, auth or telemetry changes.

## Verification

Run hub/controller behavior tests, catalog cases, native scan-policy/error workflows and visual inspection, an isolated live UI check, design build, formatting, analysis and strict validation.
