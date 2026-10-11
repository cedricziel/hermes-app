## Decisions

Reuse GroupedSection, GroupedTextFieldRow and GroupedSegmentedRow. Add optional secret, read-only, error and keyboard properties to the shared input with existing defaults. Isolate credential presentation in a plain component with catalog states before screen integration. Preserve command review on every submission path and clear secrets after requests. Platforms: iOS, macOS, Android, Windows and Linux; no watchOS, entitlements or native changes. No API, storage or telemetry changes.

## Verification

Run MCP behavior tests, catalog smoke tests, format, analysis and strict OpenSpec validation. Inspect native platform renders and verify against an isolated backend before publication.

Seventy-eight MCP setup/install behavior tests passed, including secret keyboard protections. Three hundred forty MCP catalog and related checks passed across themes and viewports. Eight explicit iOS/macOS creation and installation workflow cases passed; native screenshots were inspected. Formatting, analysis and strict validation passed. The live macOS app was inspected against the verified throwaway backend home: remote/command switching, persistent labels, arguments, environment rows and immediate name validation worked. Verification processes were stopped.
