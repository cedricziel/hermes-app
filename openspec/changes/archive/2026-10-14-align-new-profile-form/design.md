## Decisions

Reuse GroupedDialog and GroupedTextFieldRow. Add optional keyboard submission to the shared row so the profile form retains Enter-to-create. Preserve the existing name pattern and result record. Platforms: iOS, Android, macOS, Windows, Linux; no watchOS or native changes. No new API or telemetry behavior.

## Verification

Use widget tests for validation, trimmed results, cancellation and keyboard submission, and inspect platform screenshot renders. Publish only after the preceding PR merges.

Fifty-five profile, grouped-row and form behavior checks passed. Sixteen catalog/render cases passed across platform themes and viewports; formatting, analysis and OpenSpec validation passed. Backdrop dismissal retains the original adaptive policy.
