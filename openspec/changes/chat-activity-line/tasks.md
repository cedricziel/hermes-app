# Tasks

Two PRs, in order, each about 500 changed lines or fewer. Every behaviour task starts with a failing test. Depends on `chat-activity-needs-you` (it deletes the strip). No OpenAPI or OpenRPC change.

## 1. PR 1: `feat(chat): summarize working activity`

- [x] 1.1 Claude Design pass: https://claude.ai/artifact/MrNWUNUAZWggxjbatmPNWM (private; ask its owner for access); decisions, corrections and copy in `docs/design-briefs/chat-activity.md` ("Design (done)"), which the widgets below follow.
- [x] 1.1a Add the ARB strings for the line's sentences, counters and accessible name to `app_en.arb` and `app_de.arb` under the `@@x-area-chat/activity` anchor (`flutter gen-l10n`); server text stays untranslated.
- [x] 1.2 Write failing unit tests for `WorkingSummary`: the newest sentence wins across status, process, mixture-of-agents, resume and control sources; clearing the newest falls back to the next active one; a plan with an open task and nothing else reads "Working on the plan"; counters use only reported values and are left out when unknown; the plan counter is dropped when every task is done; the Bot screen, usage and Needs-you items never feed it; nothing working yields null.
- [x] 1.3 Implement `WorkingSummary` in `lib/src/chat/activity/` and verify 1.2 passes.
- [ ] 1.4 Build these plain-model widgets in `lib/src/chat/activity/widgets/` (models and callbacks only, no controller), each with Widgetbook use cases in `widgetbook/activity_line_use_cases.dart` before any screen uses it, in both themes, at phone, iPad and desktop width, with Apple and Material chrome and at the largest text size; verify `flutter test test/widgetbook_test.dart` passes.
  - `ActivityLine` (`ActivityLineModel`: sentence, counters, busy): 44 pt Apple, 48 dp Material, progress indicator, one-line sentence with ellipsis, counter chips (plan, processes, references), two rows from text scale 1.5. Use cases: each source's sentence ("Recalled 5 memories", "Waiting for background process", "Running 2 processes", "Asking 3 models", "Combining answers", "Restoring the chat…", a goal, "Working on the plan"), with and without counters, a 90-character sentence that truncates, the largest text size, reduced motion, dark.
  - `MacToolbarSubtitle` (profile, model, status, busy): the subtitle part of `MacChatToolbar` and `ConversationWindowToolbar`. Use cases: idle, working, a long goal at a narrow window where the status truncates before profile and model, in `MacChatToolbar` and in the conversation window's toolbar.
  - Reuse, do not redraw: `MacToolbar` and its `subtitleBuilder`, `NamedIconButton` is not needed; the chips are plain markup on tokens (`ActivityCounterChip`, private to `ActivityLine`).

## 2. PR 2: `feat(chat): show working activity in one line`

- [ ] 2.1 Write failing widget tests: on phone, tablet and Material desktop the line sits below the header (above a Bot Chat banner) while something works, opens the Activity panel on tap, hides while the inspector is open and disappears when the turn settles; on macOS no line is drawn and the toolbar subtitle carries the sentence in the main window and in a conversation window independently; the quick panel shows neither.
- [ ] 2.2 Draw the line in `ChatThreadView`, pass the summary to `MacChatToolbar` from `ChatScreen` and to `ConversationWindowToolbar` from `ConversationWindowScreen`, and verify 2.1 passes.
- [ ] 2.3 Write a failing test that with a plan, a process, usage and a pending billing verification together, only the activity line sits between header and transcript, billing is docked above the composer, and the rest is in the Activity panel.
- [ ] 2.4 Write a failing `BoundActivityPanel` test that process output cards are under Now and not This session; move them; update the session-state, todo, process-output and mixture-of-agents widget tests for their panel location; verify 2.3 and the whole suite pass.
- [ ] 2.5 Write a failing test that opening the panel from the line records `chat.activity.opened` with `source: line` and nothing else new; implement and verify it passes.

## 3. Docs and skills

- [ ] 3.1 Update `docs/architecture/chat.md` (the activity paragraph: line, toolbar subtitle, process output in Now) and the Chat paragraph of `CLAUDE.md` if it needs it, the `component-catalog` skill if it lists changed cards, and refresh the chat workflow screenshots per the `workflow-screenshots` skill.
- [ ] 3.2 After this change is merged, archive the `chat-activity-*` changes in order (needs-you, line) so the `chat-activity` spec builds up correctly.

## 4. Verify

- [ ] 4.1 Run `dart format --output=none --set-exit-if-changed .`, `flutter analyze` and `flutter test`, all clean.
- [ ] 4.2 Run the `verify-in-app` loop on macOS against a dev backend with a scripted turn that recalls memory and runs a plan: confirm the toolbar subtitle shows the status, the inspector lists details, and nothing stacks above the transcript; screenshot it. Phone and Material layouts are covered by the workflow tests; say so if no device was run.
