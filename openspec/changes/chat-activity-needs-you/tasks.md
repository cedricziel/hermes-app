# Tasks

One PR, `feat(chat): dock items that need you above the composer`, aiming at ~500 changed lines (the body extraction is a separate `refactor(chat)` commit in it). Depends on `chat-activity-panel`.

## 1. Extract card bodies

- [ ] 1.1 Extract the details parts of `BillingVerificationCard` and `ConnectorOperationCard` into body widgets the cards still use; verify the existing card and transport tests pass unchanged.

## 2. Catalog first

- [ ] 2.1 Build `NeedsYouDock` from plain models with Widgetbook use cases: billing (valid and invalid URL), connector with one and three targets and a deadline, reclaimed session, "1 of 3" paging, phone and desktop width, Apple and Material, both themes; verify `flutter test test/widgetbook_test.dart` passes.
- [ ] 2.2 Add the waiting marker to the `ActivityButton` use cases (0, 1, 3 waiting); verify the catalog test passes.

## 3. Queue

- [ ] 3.1 Write failing unit tests for `NeedsYouQueue`: oldest first across sources; a settling operation leaves and the next takes its slot; connection-wide operations never enter; App Lock clearing billing details removes the item; a scope retirement empties the queue.
- [ ] 3.2 Implement `NeedsYouQueue` and verify 3.1 passes.

## 4. Wiring

- [ ] 4.1 Write failing widget tests: the dock sits directly above the composer and moves with it; transcript bottom padding includes the dock; Needs-you entries are no longer drawn above the transcript; the quick panel shows the dock and grows to fit; a conversation window shows its own chat's items only.
- [ ] 4.2 Place the dock through `buildChatComposer`, remove Needs-you entries from `ChatThreadView`'s strip, size the quick panel for it, and verify 4.1 and the existing billing, connector and session-state tests (updated for the new location) pass.
- [ ] 4.3 Write a failing test that a new item is announced once by kind and never with its code, URL or reason, and that the Activity button label counts waiting items; implement and verify it passes.

## 5. Observability

- [ ] 5.1 Write a failing test with a recording `Breadcrumbs` that a new front item records `chat.activity.needs_you.shown` with `kind` and `count` and paging records `chat.activity.needs_you.paged` with `count`, nothing else; implement and verify it passes.

## 6. Docs and skills

- [ ] 6.1 Update the Chat and quick panel paragraphs of `CLAUDE.md`, and add a Needs-you step to the chat workflow test; check the screenshots per the `workflow-screenshots` skill.

## 7. Verify

- [ ] 7.1 Run `dart format --output=none --set-exit-if-changed .`, `flutter analyze` and `flutter test`, all clean.
- [ ] 7.2 Run the `verify-in-app` loop on macOS against a dev backend: trigger a reclaim (open the same session from a second client) and confirm the Reopen card docks above the composer; screenshot it.
