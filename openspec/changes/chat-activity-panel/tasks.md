# Tasks

One PR, `feat(chat): add the Activity panel`, aiming at ~500 changed lines (the inspector refactor is a separate `refactor(kanban)` commit in it). Depends on `chat-activity-quiet`.

## 1. Shared inspector

- [x] 1.1 Move `KanbanInspectorLayout` to `lib/src/widgets/inspector_layout.dart` as `InspectorLayout` (same 760 pt rule, overlay below, Escape and tap-outside to close) and switch the Kanban board to it; verify the existing Kanban inspector tests pass unchanged.

## 2. Catalog first

- [x] 2.1 Build `ActivityPanel` (sections Now, Plan, This session; empty sections left out; "No activity for this chat") from plain models in `lib/src/chat/activity/widgets/`, with Widgetbook use cases for: all sections, plan only, session only, empty; phone and desktop width; Apple and Material; both themes. Verify `flutter test test/widgetbook_test.dart` passes.
- [x] 2.2 Add an `ActivityButton` use case (closed, open) for the chat header and the Mac toolbar; verify the catalog test passes.

## 3. Panel content

- [x] 3.1 Write failing tests for `ActivityPanelSource`: it builds the three sections from the controllers by tier, lists Verify billing access under This session while offered, drops it after method-not-found, and never mixes chats after a switch.
- [x] 3.2 Implement `ActivityPanelSource` and verify 3.1 passes.

## 4. Placement and wiring

- [x] 4.1 Write failing widget tests: on an iPhone layout the Activity button opens a medium-detent sheet; on Android a modal bottom sheet; at 1200 pt the inspector docks beside the chat and stays open across a chat switch; at 700 pt it draws over the chat and Escape closes it.
- [x] 4.2 Wire the button into `ChatHeader` and `MacChatToolbar`, the inspector into `ChatScreen` and `ConversationWindowScreen`, and nothing into `QuickPanelScreen`; verify 4.1 passes.
- [x] 4.3 Write a failing test in `test/macos/mac_menu_bar_test.dart` that View > Inspector is enabled with a chat open and toggles the key conversation window's inspector only; offer `MacCommand.toggleInspector` from the chat's `MacCommandScope`; verify it passes.

## 5. Reference tier leaves the strip

- [x] 5.1 Write failing widget tests: usage, a side answer, a keyed notice, the session acknowledgement, a settled connector operation and the idle billing row draw nothing above the transcript and appear under This session; a ttl notice that expired is not listed.
- [x] 5.2 Filter reference-tier entries out of `ChatThreadView`'s strip and verify 5.1 and the existing side-result, notice and usage tests (updated for the new location) pass.

## 6. Observability

- [x] 6.1 Write a failing test with a recording `Breadcrumbs` that opening from the button and from the menu records `chat.activity.opened` with `surface` and `source`, and closing records `chat.activity.closed`, with no other attributes; implement and verify it passes.

## 7. Docs and skills

- [x] 7.1 Update the Chat and macOS menu bar paragraphs of `CLAUDE.md` (Activity panel, View > Inspector in chat) and the workflow test for chat (`test/workflows/`) with an Activity panel step; verify the workflow screenshots look right per the `workflow-screenshots` skill.

## 8. Verify

- [x] 8.1 Run `dart format --output=none --set-exit-if-changed .`, `flutter analyze` and `flutter test`, all clean.
- [ ] 8.2 Run the `verify-in-app` loop on macOS: open a chat, toggle the inspector with the toolbar button and ⌥⌘I, resize below 760 pt, and screenshot each state.
