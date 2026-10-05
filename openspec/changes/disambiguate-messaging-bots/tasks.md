## 1. Vocabulary and catalog

- [x] 1.1 Start with failing navigation and messaging-screen tests for the “Messaging” destination, explanatory copy, and generic failure messages; retain platform-specific Telegram and credential terminology.
- [x] 1.2 Update messaging Widgetbook use cases and extract a plain-model introduction widget if necessary; verify phone/desktop and light/dark states before screen integration.

## 2. Integration

- [x] 2.1 Rename the internal messaging feature, models, repository, screens, and callbacks; update repository composition and callers without compatibility aliases. This pure refactor retains existing generated `/api/messaging/*` calls.
- [x] 2.2 Wire the new labels and explanatory copy into navigation, setup, and error states; update management workflows, README, and CLAUDE.md. Keep this PR near 500 changed lines (`refactor(messaging)`).
- [x] 2.3 Confirm there is no new telemetry and no API schema/client regeneration required; preserve redaction and server-side Telegram token handling.

## 3. Verification

- [x] 3.1 Review `.claude/skills/` for stale messaging names and amend affected instructions; create a new skill only if implementation reveals a repeated workflow.
- [ ] 3.2 Run `dart format`, `flutter analyze`, `flutter test`, the component catalog and management screenshot workflows; inspect their images and complete the verify-in-app loop against an isolated Hermes home before marking the change done.
