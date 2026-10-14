# Tasks

One PR, `feat(chat): fold working activity into one line`, aiming at ~500 changed lines (much of it deletions). Depends on `chat-activity-needs-you`.

## 1. Summary model

- [ ] 1.1 Write failing unit tests for `WorkingSummary`: newest sentence wins across status, process, mixture-of-agents, resume and control sources; clearing the newest falls back to the next active one; counters use only reported values and are left out when unknown; the plan counter is dropped when every task is done; nothing working yields null.
- [ ] 1.2 Implement `WorkingSummary` in `lib/src/chat/activity/` and verify 1.1 passes.

## 2. Catalog first

- [ ] 2.1 Build `ActivityLine` from the model with Widgetbook use cases: sentence only, sentence with plan/process/references counters, a long sentence that truncates; Apple and Material; phone and desktop width; both themes. Verify `flutter test test/widgetbook_test.dart` passes.
- [ ] 2.2 Add `MacChatToolbar` use cases with and without a status, including a long goal at a narrow width where the status truncates before profile and model; verify the catalog test passes.

## 3. Wiring

- [ ] 3.1 Write failing widget tests: on phone, tablet and Material desktop the line sits below the header while something works, opens the Activity panel on tap, and disappears when the turn settles; on macOS no line is drawn and the toolbar subtitle carries the sentence in the main window and in a conversation window independently; the quick panel shows neither.
- [ ] 3.2 Draw the line in `ChatThreadView`, pass the summary to `MacChatToolbar` from `ChatScreen` and `ConversationWindowScreen`, and verify 3.1 passes.

## 4. Remove the strip

- [ ] 4.1 Write a failing widget test that with a plan, a process, usage and a pending billing verification together, only the activity line sits between header and transcript, billing is docked above the composer, and the rest is in the Activity panel.
- [ ] 4.2 Remove the strip and its parameters from `ChatThreadView`, move them to the panel source in `chat_thread_bindings.dart`, delete strip-only wrappers, update the session-state, todo, process-output and mixture-of-agents widget tests for their panel location, and verify 4.1 and the whole suite pass.

## 5. Observability

- [ ] 5.1 Write a failing test that opening the panel from the line records `chat.activity.opened` with `source: line`; implement and verify it passes.

## 6. Docs and skills

- [ ] 6.1 Update the Chat paragraph of `CLAUDE.md` (activity line, toolbar subtitle, no strip) and the `component-catalog` skill if it lists the removed strip cards; refresh the chat workflow screenshots and check them per the `workflow-screenshots` skill.
- [ ] 6.2 After this change is merged, archive the four `chat-activity-*` changes in order (quiet, panel, needs-you, line) so the `chat-activity` spec builds up correctly.

## 7. Verify

- [ ] 7.1 Run `dart format --output=none --set-exit-if-changed .`, `flutter analyze` and `flutter test`, all clean.
- [ ] 7.2 Run the `verify-in-app` loop on macOS against a dev backend with a scripted turn that recalls memory and runs a plan: confirm the toolbar subtitle shows the status, the inspector lists details, and nothing stacks above the transcript; screenshot it.
