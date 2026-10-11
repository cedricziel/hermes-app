## Decisions

Use GroupedDialog, labelled source input, a grouped warning row, checkbox acknowledgement and grouped enable/force switches. Keep force under the existing Advanced disclosure and preserve all installer callbacks. Extend the shared field with optional suggestion control, defaulting to its previous behavior. Platforms: iOS, Android, macOS, Windows, Linux; no watchOS or native changes. No API, auth, storage or telemetry changes.

## Verification

Existing installation tests protect trust, whitespace validation, busy behavior and flags. Inspect platform renders and catalog; run formatting, analysis and OpenSpec validation. Publish only after the preceding PR merges.

Forty-three installer/catalog behavior tests passed, including mandatory trust, trimmed source, default flags, force disclosure, busy dismissal and private-address handling. Fourteen catalog/workflow cases passed, plus explicit macOS and iOS source-install renders. Renders were inspected; analysis and strict validation passed. Whole-row flag toggling is retained.
