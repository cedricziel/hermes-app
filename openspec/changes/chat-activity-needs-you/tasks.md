# Tasks

Two PRs, in order, each about 500 changed lines or fewer. Every behaviour task starts with a failing test. Depends on `chat-activity-panel` (archived). No OpenAPI or OpenRPC change.

## 1. PR 1: `feat(chat): dock items that need you above the composer`

- [x] 1.1 Claude Design pass: https://claude.ai/artifact/MrNWUNUAZWggxjbatmPNWM (private; ask its owner for access); decisions, corrections and copy in `docs/design-briefs/chat-activity.md` ("Design (done)"), which the widgets below follow.
- [ ] 1.2 Extract the details parts of `BillingVerificationCard` and `ConnectorOperationCard` into body widgets the cards still use (own `refactor(chat)` commit); verify the existing card and transport tests pass unchanged.
- [ ] 1.3 Build these plain-model widgets in `lib/src/chat/activity/widgets/` (models and callbacks only, no controller), each with Widgetbook use cases in `widgetbook/needs_you_dock_use_cases.dart` before any screen uses it, in both themes, at phone, iPad and desktop width, with Apple and Material chrome and at the largest text size; verify `flutter test test/widgetbook_test.dart` passes.
  - `NeedsYouDock` (`NeedsYouDockModel`: items, shown index, callbacks): header (kind icon, title, "1 of N" with Previous and Next), a scrolling body capped at 40% of the height left, action row. Use cases: billing (valid and invalid URL), connector with one and three targets and a deadline, reclaimed, restore failed, "1 of 3" and "2 of 3", answer states (sending, unconfirmed), offline, keyboard open on a small phone, every kind at the largest text size, dark.
  - Body widgets `BillingNeedsYouBody`, `ConnectorNeedsYouBody`, `ReclaimNeedsYouBody` (the extracted parts), shown inside the dock's use cases and on their own.
  - `ActivityButton` waiting marker (`waiting: int`): 0, 1 and 3 waiting, on the iOS header, the Material header and `MacChatToolbar`.
  - Reuse, do not redraw: `BusyBar` (sending), `NamedIconButton` (paging), `AdaptiveSheet`/`AdaptiveDialog` are not needed; the warning line is the row warning style of `GroupedRow`/`StateMessage` tokens, and the Copy code and Open buttons are the existing `OutlinedButton`/`FilledButton` styles of the cards.
- [ ] 1.3a Add the ARB strings for the dock, the marker and the Offline, sending and unconfirmed lines to `lib/l10n/arb/app_en.arb` and `app_de.arb` under the `@@x-area-chat/activity` anchor (`flutter gen-l10n`), read with `context.l10n`; no strings below the widget layer.
- [ ] 1.4 Write failing unit tests for `NeedsYouQueue`: oldest first across sources; a settling operation leaves and the next takes its slot; the shown slot survives a re-render; connection-wide operations never enter; a failed restore enters as `resume`; App Lock clearing billing details removes the item; a scope retirement empties the queue; going offline keeps a connector item display-only, drops a billing item, and a retirement while offline still removes it.
- [ ] 1.5 Implement `NeedsYouQueue` and verify 1.4 passes.
- [ ] 1.6 Write failing widget tests: the dock sits directly above the composer and moves with it; transcript bottom padding includes the dock; the strip is gone; the expanded quick panel shows the dock inside its fixed height and the compact one shows none; a conversation window shows its own chat's items only.
- [ ] 1.7 Place the dock through `buildChatComposer`, delete the strip, `activity()` and the parameters only it used from `ChatThreadView` (`todoPlan`, `moaProgress`, `onMoaDetails`, `processOutputs`, `onProcessOutputDetails`, and their bindings in `chat_thread_bindings.dart`), let the expanded quick panel's body scroll for it, and verify 1.6 and the existing billing, connector and session-state tests (updated for the new location) pass.
- [ ] 1.8 Write a failing test that a new item is announced once by kind and never with its code, URL, target name or reason, and that the Activity button label counts waiting items; implement and verify it passes.
- [ ] 1.9 Write a failing test with a recording `Breadcrumbs` that a new front item records `chat.activity.needs_you.shown` with `kind` and `count` and paging records `chat.activity.needs_you.paged` with `count`, nothing else; implement and verify it passes.

## 2. PR 2: `feat(chat): confirm Needs-you answers and keep items while offline`

- [ ] 2.1 Write failing `ConnectorOperationController` tests with a fake clock: a response with no result after 10 s reports `unconfirmed` and re-enables Skip and Continue; a thrown error does the same, a non-ok status reports `refused` with its own line, method-not-found stays unavailable; the 30 s transport error after the report changes nothing and logs nothing more; no second response is sent; a settlement after the report still settles the operation; the log outcome is `unconfirmed`. Then implement the bound and replace the refusal text.
- [ ] 2.2 Write failing widget tests that the dock shows "Sending your answer…" with both actions disabled, then the "Couldn't confirm your answer" line with both offered again, and leaves on a late settle.
- [ ] 2.3 Write failing tests that going offline keeps a connector item display-only (no URL, authority or timer) with Skip, Continue, Open and Reopen disabled and the Offline line, that its actions return after the reconnect replay, that billing details leave on a drop, and that retirement, deadline and App Lock still remove it. Modify `_onConnectorOwnership` to keep the display-only model while `!connected && !retired`; check whether a reclaimed or failed-restore `ChatSessionState` survives a drop and keep it display-only if it does.

## 3. Docs and skills

- [ ] 3.1 Update `docs/architecture/chat.md` (Needs-you dock, tiers, no strip; the quick panel) and the Chat and quick panel paragraphs of `CLAUDE.md` if they mention the strip; add a Needs-you step to the chat workflow test and check the screenshots per the `workflow-screenshots` skill; update the `component-catalog` skill if it lists the strip cards.

## 4. Verify

- [ ] 4.1 Run `dart format --output=none --set-exit-if-changed .`, `flutter analyze` and `flutter test`, all clean.
- [ ] 4.2 Run the `verify-in-app` loop on macOS against a dev backend: trigger a reclaim (open the same session from a second client) and confirm the Reopen card docks above the composer; stop the backend while a connector card shows and confirm the display-only Offline card; screenshot both. Billing and connector cards need a scripted server; if the dev backend cannot raise them, say so and cover them with the fake gateway tests instead.
