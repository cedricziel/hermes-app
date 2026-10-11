## Decisions

Extract plain editor and sign-in presentation widgets before wiring. Use GroupedMetrics for editor borders and spacing, GroupedSection/GroupedRow for statuses and actions, and scrollable sign-in content. Preserve all editor input protections, command review, polling, address filtering and cancellation. Platforms: iOS, macOS, Android, Windows and Linux. No watchOS, native, API, auth, storage or telemetry changes.

## Verification

Run editor/sign-in behavior tests, catalog checks, native screenshot workflows, isolated live inspection, formatting, analysis and strict validation.

Seventy-three focused editor/sign-in behavior tests passed. Ninety-six new standalone catalog cases passed, followed by 228 combined editor/sign-in/catalog checks. Twelve explicit iOS/macOS workflow cases passed, including sign-in failure/expiry, JSON validation/refusal/discard/review and configuration load failure; renders were inspected. The editor retains its original 13-point code font. Analysis and strict validation passed. Live macOS configuration editing was inspected against the verified throwaway backend: invalid JSON disabled Save and leaving prompted to discard unsaved edits. No configuration was saved. Provider sign-in was exercised with the fake server in tests and native workflows, not with a real provider account. Verification processes were stopped. The project verification skill now explains raising the targeted native window when automation clicks leave the UI unchanged.
