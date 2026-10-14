## 1. Status record and outcomes

- [x] 1.1 Start with failing account-isolation, attempt-without-completion, stale-writer, sign-out, and storage-failure tests. Add a content-free versioned status record with generation guards and scoped cleanup.
- [x] 1.2 Start with failing completed, partial, locked, unreachable, and signed-out run tests. Wire attempt and completion recording around existing refresh outcomes without changing scheduling, auth, or background success reporting.

## 2. Mobile settings

- [x] 2.1 Start with failing presentation tests and add Widgetbook cases for first use, recent completion, incomplete attempt, permission denial, iOS refresh restriction, Android registration, and unknown capability before screen wiring.
- [x] 2.2 Start with failing settings/resume tests. Show permission and refresh capability separately, last attempt/completion and outcome, and concise best-effort delivery limits. Query existing native state without extra polling or backend requests.
- [x] 2.3 Start with failing privacy and backend-call-count tests. Verify the status payload contains only allowed fixed data, status errors cannot break work, and no new telemetry or API call is introduced.

## 3. Verify and ship

- [x] 3.1 Review project-local and legacy verification skills for changed notification-status guidance and update only stale entries. No new project skill is needed unless the verification workflow repeats. No OpenAPI regeneration is required.
- [ ] 3.2 Keep this status UI and record PR under roughly 500 changed lines with `feat(notifications): show mobile background check status`.
- [ ] 3.3 Run `dart format`, `flutter analyze`, background/settings `flutter test`, and isolated `verify-in-app`. Inspect first use, denied and unknown capabilities, partial and interrupted checks, account switching, and resume. Confirm the UI claims no delivery guarantee and creates no push registration or extra polling.
