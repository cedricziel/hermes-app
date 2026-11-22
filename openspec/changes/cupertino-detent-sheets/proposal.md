# Proposal

**Owner decides:** whether iPhone sheets get iOS medium and large detents and a grabber through the shared `showAdaptiveSheet` (the build of which belongs to the style session), which detent each of the 22 sheets uses, and how a `large` sheet looks: over a scrim with the presenter left as it is (recommended by the design pass), or as a native page sheet through `showCupertinoSheet` with the presenter scaled and peeking above it.

Audit item D6 (roadmap F.231). The premise is half true; see "Why".

## Why

On iPhone a sheet is a Material bottom sheet with no detents. `showAdaptiveSheet` (`lib/src/widgets/adaptive_sheet.dart:10-37`) opens a dialog on macOS and on wide layouts, and otherwise calls `showModalBottomSheet` with `isScrollControlled`, `useSafeArea`, an optional Material drag handle (`showDragHandle`, off by default) and an optional height cap. It has 19 call sites in 19 files: 17 sheets, plus the macOS branches of the plugin detail (`plugins/installed_tab.dart:53`, `catalog_tab.dart:66`), whose other platforms use a raw sheet. Five more sheets call `showModalBottomSheet` directly (`lib/src/models/widgets/model_picker.dart:112`, `lib/src/kanban/widgets/task_panel/kanban_task_sheet.dart:21`, `lib/src/kanban/widgets/kanban_task_panel.dart:82` on Android, `lib/src/plugins/installed_tab.dart:55` and `catalog_tab.dart:68`). The audit's "about 30" is 22 in the code today.

What is already done: **Kanban's task sheet has the iOS behaviour.** `showKanbanDetentSheet` (`kanban_task_sheet.dart:16-30`) is a `DraggableScrollableSheet` that opens at half height (`initialChildSize: 0.5`), snaps to half and full (`snapSizes: [0.5, 1]`), drops when swiped below half, and draws a 36 x 5 grabber (`:46-100`). `test/kanban_task_sheet_test.dart` pins it on iPhone, iPad and Mac. That is the prototype of this change. It is private to Kanban's helper, which the chat's Activity panel also calls (`chat/chat_screen_navigation.dart:91`, with its own `DraggableScrollableController` to grow it); no other sheet can have it.

`cupertino_ui` 1.1.7 has `showCupertinoSheet` (`sheet.dart`), but it is a full-height page sheet only: the file has no detent or grabber code.

## What Changes

On iPhone and other compact iOS layouts, `showAdaptiveSheet` takes a `detents` argument and draws an iOS sheet: rounded top corners, a grabber, and the chosen detents. Nothing changes for Android, macOS, iPad or any wide layout.

Three detent profiles:

| Profile       | Behaviour                                                                  | Used for                                    |
| ------------- | -------------------------------------------------------------------------- | ------------------------------------------- |
| `fit`         | Opens at its content's height, capped at large. No medium stop of its own. | Confirmations and short menus               |
| `mediumLarge` | Opens at half height, drags to large, swipes down to dismiss.              | Lists, pickers and details that scroll      |
| `large`       | Opens at large only; the grabber stays and swipe-down dismisses.           | Multi-step forms and flows with text fields |

Which sheet uses which (the table is the contract for the second PR):

| Profile       | Sheets (call site)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| ------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `fit`         | attach menu (`chat/attachments/attachment_surface.dart:51`), restore confirmation (`chat/checkpoints/pages/restore_flow.dart:85`), compress (`chat/context/pages/compress_flow.dart:37`), curator run (`skills/curator/curator_run_sheet.dart:34`), MCP command review (`mcp/mcp_command_review.dart:17`), Bot Screen takeover (`bot_screen/viewer/bot_screen_viewer.dart:163`), app prompt hint (`platform_hint/show_platform_hint_prompt.dart:18`), soul changed (`profiles/soul/widgets/soul_changed_sheet.dart:261`), file size question (`files/widgets/files_questions.dart:31`), "What's the difference?" (`tools/widgets/tools_difference_sheet.dart:122`) |
| `mediumLarge` | model picker (`models/widgets/model_picker.dart:112`), toolset model list (`tools/widgets/toolset_model_sheet.dart:142`), folder picker (`workspaces/ui/workspace_picker_sheet.dart:42`), working folder details (`workspaces/ui/workspace_flows.dart:65`), skill job status (`skills/skill_job_sheet.dart:23`), plugin detail (`plugins/installed_tab.dart:53` and `:55`, `catalog_tab.dart:66` and `:68`; the macOS branch passes the profile too, where it is ignored, so the guard holds), Kanban task and the chat's Activity panel (already, through Kanban's helper)                                                                                                                                                                                                                                                     |
| `large`       | provider connect and sign-in forms (`providers/provider_flow.dart:55-82`), toolset setup (`tools/toolset_setup_panel.dart:245`), MCP install (`mcp/mcp_catalog_screen.dart:61`)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |

Behaviour of every iOS sheet:

- The grabber is the Kanban one (36 x 5, a 17 pt band). For `mediumLarge` it is an accessibility control that moves between detents (increase and decrease actions); VoiceOver's escape gesture dismisses a sheet as any route.
- Every sheet keeps an explicit Close, Cancel or Done in its content. The grabber is never the only way out.
- A swipe-down or a tap on the barrier goes through the route's `PopScope`, so a busy sheet (a running install, a restore in flight) snaps back instead of closing. MCP install and toolset setup have no pop guard today; this change gives them `PopScope(canPop: !busy)`, which is new behaviour. Busy means a request is in flight; a background MCP build being polled is not busy, so the sheet still closes while it builds, as the `mcp-catalog` spec says.
- A text field taking focus moves the sheet to large.
- At large text, or with the keyboard up, a sheet whose content is taller than medium opens at large. Content is never clipped by a detent.
- On a landscape phone (available height under 500 pt) every sheet is large.

## The contract the style session implements

The build of the shared `showAdaptiveSheet` belongs to the style session (roadmap H.3). It implements this and nothing else of this change:

```dart
enum SheetDetents { fit, mediumLarge, large }

Future<T?> showAdaptiveSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  double maxWidth = 520,
  bool showDragHandle = false,
  double? maxSheetHeightFraction,
  SheetDetents detents = SheetDetents.fit,
});
```

1. **Scope.** `detents` takes effect only on iOS chrome below the wide breakpoint. macOS keeps the dialog, wide layouts keep the dialog, Android keeps `showModalBottomSheet` with `showDragHandle` and `maxSheetHeightFraction` as today, and `detents` is ignored there.
2. **Default.** `fit`, which matches today's geometry (a scroll-controlled sheet that is as tall as its content, up to the screen), plus the grabber and the iOS corners. A caller that passes nothing changes only in those two ways.
3. **Geometry.** Medium is half of the height below the top safe inset. Large is that full height. Both are fractions of the route's own box, as in `KanbanDetentSheet`.
4. **Scroll.** The sheet gives its content a scroll controller through `AdaptiveSheetScope.scrollControllerOf(context)`. Content that scrolls passes it to its list so a drag on the list moves the sheet at the top edge. Content that does not scroll drags from the grabber band only.
5. **Dismiss.** A drag below the lowest detent and a barrier tap call `Navigator.maybePop`, never `pop`.
6. **Keyboard.** Focus in a text field moves the sheet to large and keeps the field visible.
7. **Result.** The returned value is what the content pops, unchanged.
8. **Kanban.** `showKanbanDetentSheet` becomes a call to `showAdaptiveSheet(detents: SheetDetents.mediumLarge)` and `KanbanDetentSheet` is deleted; the keys `kanbanTaskSheet` and `kanbanTaskGrabber` stay for the tests, or the tests move with the code.
9. **Catalog and tests.** The use cases and tests listed in tasks.md PR A.

## Non-goals

- Android, macOS, Windows, Linux and iPad. A wide layout keeps its dialog.
- Action sheets (`showCupertinoModalPopup`, `app_action_sheet.dart`) and pickers (`adaptive_pickers.dart`): they are already iOS native in form.
- Changing what any sheet says or does, or its copy.
- A native `UISheetPresentationController` through a platform view.
- Resizing a sheet from content (live detent changes after open) beyond the keyboard rule.
- The Provider connect flow on Android, which stays a full-screen dialog.

## Capabilities

### New Capabilities

- `adaptive-sheets`: how a sheet is presented on iPhone (profiles, grabber, dismissal, keyboard, large text, landscape), and that other platforms are unchanged.

### Modified Capabilities

None.

## Impact

- Code: `lib/src/widgets/adaptive_sheet.dart` (style session); the 19 call sites and the five raw ones (this change); `lib/src/kanban/widgets/task_panel/kanban_task_sheet.dart` and `kanban_task_panel.dart`; `widgetbook/adaptive_use_cases.dart:65`. Tests: `test/adaptive_attach_and_skill_sheet_test.dart`, `test/kanban_task_sheet_test.dart` and new ones.
- Backend: none. Native: none.
- Dependencies: none planned. `smooth_sheets` 1.3.2 (published 2026-11-16, 160 of 160 pub points, all six platforms, Flutter 3.44 or newer, this repo pins 3.47.9) was found on pub.dev and its API was not read here; the style session's spike (task A.2) decides between it and promoting Kanban's in-repo sheet, per the dependencies rule in `CLAUDE.md`. `modal_bottom_sheet` was last published in 2024 and is not considered.
- Security and privacy: None. Sheets hold what they hold today (a command to review, keys being typed). They sit on the root navigator, so App Lock's cover hides them. No sheet content reaches a breadcrumb, span or log.
- Observability: None. A sheet's presentation is not work that takes time or an outcome; each flow keeps the telemetry it has.
- Delivery: PR A (style session), PR B and PR C (see tasks.md).
