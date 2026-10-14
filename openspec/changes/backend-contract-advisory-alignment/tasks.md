## 1. Provenance resolution

- [x] 1.1 Write failing script tests for matching SHAs, mismatched SHAs, missing files, malformed values, and trailing newlines; implement a small provenance resolver using both committed `HERMES_REF` files.
- [x] 1.2 Write a failing workflow configuration check showing the backend download and web cache use the resolver output, then replace the independent workflow pin while keeping the workflow advisory and outside `Analyze & test`.

## 2. Update workflow consistency

- [x] 2.1 Write a failing regression test for provenance-only changes opening an update PR; include both provenance files in change detection without regenerating the Dart client when OpenAPI JSON is unchanged.
- [x] 2.2 Write a failing regression check for a JSON contract update preserving matching provenance and existing generation/classification checks, then verify that path still works.

## 3. Coverage and documentation

- [x] 3.1 Write a failing check for the CI summary's resolved SHA, setup/test outcomes, and disabled paid-provider and pairing flags; add the bounded summary. No application telemetry is needed for this tooling-only change.
- [x] 3.2 Run existing scripted-model scenarios against a fresh isolated backend with paid-provider flags unset; correct the workflow description to distinguish free scripted turns from skipped paid scenarios.
- [x] 3.3 Update `CLAUDE.md` and the project verification skill only where the hard-coded revision or advisory workflow instructions become stale. Preserve isolated-home, credential, and cleanup rules; add no new skill for this one-off tooling change.

## 4. Verification

- [x] 4.1 Run script tests, `dart format --output=none --set-exit-if-changed .`, `flutter analyze`, and `flutter test`; run the aligned advisory workflow and inspect its summary and cleanup. No UI verification is needed because runtime UI and connection behavior are unchanged. Keep one reviewable `ci(api)` PR around 500 changed lines or fewer, and leave required checks unchanged.
