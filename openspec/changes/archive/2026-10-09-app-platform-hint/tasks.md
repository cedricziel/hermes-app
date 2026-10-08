# Tasks

## 1. Repository (`feat(chat)`)

- [x] 1.1 Write failing tests against `FakeHermesServer`: missing, outdated, current, foreign and unreadable configs; the write body holds only `platform_hints.hermes_app.replace`
- [x] 1.2 Implement `PlatformHintRepository` and the hint text with its list of earlier texts

## 2. Prompt widget in the catalog

- [x] 2.1 Build `PlatformHintPrompt` as a plain-model widget with use cases: one profile, several, update, adding, partial failure; light and dark, phone and desktop
- [x] 2.2 `flutter test test/widgetbook_test.dart` and an accessibility test for the buttons and the text disclosure

## 3. Offer and wiring

- [x] 3.1 Write failing tests for `PlatformHintOffer`: no prompt when nothing is needed or declined; later, never and add outcomes; retry writes only failed profiles
- [x] 3.2 Implement it and start it from `AppShell`; add the breadcrumbs named in the proposal

## 4. Housekeeping and verify

- [x] 4.1 Add the feature to CLAUDE.md; `verify-in-app` corrected: full-screen `screencapture -x` also needs Screen Recording, and a profile is created with the CLI (the profiles route needs the page token)
- [x] 4.2 `dart format .`, `flutter analyze`, `flutter test`, then verify-in-app against `scripts/dev-backend.sh`: the prompt appears on a fresh backend, Add writes the key, a restart does not ask again
