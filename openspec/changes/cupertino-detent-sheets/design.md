# Design

## Context

Read in the code at the base commit of this branch.

- `showAdaptiveSheet` (`lib/src/widgets/adaptive_sheet.dart:10-37`): macOS opens `showAppDialog` with a `Dialog`; `isWideLayout` opens `showDialog`; otherwise `showModalBottomSheet` with `isScrollControlled: true`, `useSafeArea: true`, `showDragHandle`, and `constraints` from `maxSheetHeightFraction` (`:41-53`, keeping the theme's 640 dp width cap).
- Call sites that set `showDragHandle`: attach menu (`attachment_surface.dart:54`) and skill job status (`skill_job_sheet.dart:25`). The others have no handle.
- Sheets size themselves: the provider flow wraps its builder in a `SizedBox` of 94% of the height (`provider_flow.dart:76-82`) and the model picker caps at 75% (`model_picker.dart:118-121`). Neither can be told "medium".
- Kanban: `showKanbanDetentSheet` and `KanbanDetentSheet` (`kanban_task_sheet.dart:16-30` and `:48`, the grabber at `:112-121`) are the iOS behaviour for one sheet: `DraggableScrollableSheet(initialChildSize: 0.5, minChildSize: 0, snap: true, snapSizes: [0.5, 1])`, a transparent route with the surface drawn by the sheet, a 12 pt radius and `hermesOverlayEdge`, the grabber `Container` 36 x 5 in a 17 pt band (`kKanbanGrabberBand`), and the content's scroll controller handed in through the builder. On Android `showKanbanTask` uses a plain sheet at 92% (`kanban_task_panel.dart:82-88`). `test/kanban_task_sheet_test.dart` pins: grabber 36 x 5, opens at half, a fling up reaches over 90%, a fling down dismisses, and iPad and Mac get a centred form sheet.
- Dismiss guards in sheets today: only the app prompt hint has one, `PopScope(canPop: !offer.busy)` (`show_platform_hint_prompt.dart`). Toolset setup (`toolset_setup_panel.dart:245-290`) and MCP install (`mcp_catalog_screen.dart:61-75`) capture their sheet route to close it on completion, but have no pop guard: a swipe or barrier tap closes them while they work. Adding `PopScope(canPop: !busy)` to both is new behaviour in this change (tasks B.4). Busy means a request is in flight (the install POST, a setup write). A background build that the MCP install sheet polls is not busy: the `mcp-catalog` spec lets the user close the sheet while it builds, and that stays.
- Material's default drag handle is found in tests by the type name `_DragHandle` (`test/adaptive_attach_and_skill_sheet_test.dart:13-15`).
- `style.dialog` already bans raw dialogs and sheets outside the shared helpers and names `showAdaptiveSheet` as the replacement (`test/architecture/style_ratchet_test.dart:60-65`); its baseline in `test/architecture/baseline/style.yaml` holds the five raw sheets among others.
- `cupertino_ui` 1.1.7 `showCupertinoSheet` (`sheet.dart:184-203`) is a full-height iOS page sheet with a drag-to-dismiss flag. It has no detents and no grabber.

## Options

- **A. Promote Kanban's in-repo `DraggableScrollableSheet` into `showAdaptiveSheet`. (Recommended default.)** Already shipping and tested, no dependency. Known weak spot of `DraggableScrollableSheet`: keyboard insets and nested scroll; the spike (A.2) must show those two work.
- **B. A package, `smooth_sheets`.** Active (1.3.2, 2026-11-16), mature on pub.dev, built for detents and nested scroll. It adds a dependency, a second route type next to `showModalBottomSheet`, and its keyboard and `PopScope` behaviour is unread here. Choose it only if the spike shows A fails on keyboard, nested scroll or `PopScope`.
- **C. `showCupertinoSheet` for `large` and A for the rest.** Gives the native presenter-scaling look for forms, with two sheet implementations. Rejected for the first version: the scaled presenter interacts with the one root navigator and App Lock's cover, and the look is a design pass question.
- **D. Native `UISheetPresentationController`.** Needs a platform view to host Flutter content; far too much for sheets that are mostly forms.
- **E. Do nothing.** iPhone keeps Material sheets, and Kanban stays the only sheet that feels like iOS.

## Decisions

1. **Three profiles, not a list of fractions.** `fit`, `mediumLarge`, `large` (proposal). A free `snapSizes` argument would let each call site invent its own; three names can be tested once and checked at every call site by a guard.
2. **Assignments** are in the proposal's table. The rule behind it: a sheet that confirms or asks is `fit`; a sheet whose content is a list or a detail that grows is `mediumLarge`; a sheet that is a flow with text fields or several steps is `large`, because the keyboard would take it to large anyway.
3. **The grabber** is the Kanban pill. For `fit` sheets it is drawn too, so every iOS sheet looks the same and swipe-down always works; the in-content Close stays. A design pass decision may hide it on `fit`.
4. **A guard.** An architecture rule `arch.sheets.detents` scans `lib/` for `showAdaptiveSheet(` and fails when a call does not pass `detents:`, with a message naming the three profiles. It lands in PR B with the assignments, so a new sheet cannot skip the choice. PR B also passes a profile at the two macOS branches of the plugin detail (`installed_tab.dart:53`, `catalog_tab.dart:66`), where it is ignored, so the guard holds before PR C. Of the five raw `showModalBottomSheet` sheets, Kanban's task sheet moves in PR A (task A.6) and the other four in PR C (task C.2); each leaves `style.dialog`'s baseline in the PR that moves it (the ratchet makes that a required edit).
5. **Wide and iPad.** Unchanged: `isWideLayout` is true from 700 on a full-screen iPad, so an iPad keeps its dialog. A Split View iPad at 507 pt gets the iPhone sheet.
6. **The sheet is a route on the root navigator**, as today, so `PushedRoutes` and `ConnectionPageCloser` close it on sign-out and server change, and App Lock covers it.

## Platforms

iOS only for the new look, on an iOS layout that is not expanded (`isWideLayout` false: an iPhone, an iPad in Split View or Slide Over). Android, macOS, Windows and Linux are unchanged. watchOS has no sheets here. No native, entitlement or Xcode change.

## Invariants touched

- **App Lock.** Sheets are on the root navigator inside the `AppLockGate` subtree (`lib/src/app.dart:197`, `app_lock_gate.dart:37`). A sheet that is open when the lock covers the app stays hidden and is not focusable. No change.
- **Privacy.** Sheets show what they show today: a command the user must read before saving (`McpCommandReview`), keys being typed (toolset setup), a file name and size. None of it goes to a breadcrumb, span or log; this change records nothing.
- **Confirmations are never auto-confirmed.** Dismissal by swipe or barrier returns null, which every confirmation call site already treats as cancel (for example `compress_flow.dart:42`, `restore_flow.dart`). A test per confirmation family asserts this.
- **Never resent / lost answers.** Restore and compress go out only after a confirmation (`CLAUDE.md`, Chat). A sheet that dismisses itself mid-send must not cancel the request: dismissal while busy is refused through `PopScope`.
- **Touch targets.** The grabber band is a drag area, not a button. Every sheet keeps a 44 pt Close, Cancel or Done in its content. The accessibility actions on the grabber are the non-gesture way to resize.
- **Status is not colour alone.** The grabber is a shape. Nothing in a sheet's chrome carries status.
- **Telemetry.** None added.

## Risks

| Risk                                                                     | Rule                      | Mitigation                                                                                                                    |
| ------------------------------------------------------------------------ | ------------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| A swipe dismisses a sheet during a busy operation                        | never resent, lost answer | Dismiss goes through `Navigator.maybePop`; tests with `PopScope(canPop: false)` for platform hint, restore and toolset setup. |
| The keyboard covers a field in a `mediumLarge` or `large` sheet          | usability                 | Focus moves to large; test with `viewInsets`. Spike A.2 covers it.                                                            |
| A `fit` confirmation at 2.0 text is cut by medium                        | large text                | Opens at the content's height up to large, and scrolls; test at 320 x 568, scale 2.0 and 3.1.                                 |
| A list inside a `mediumLarge` sheet fights the sheet's drag              | nested scroll             | The scroll controller scope; test: dragging the list at its top edge moves the sheet, dragging it elsewhere scrolls it.       |
| iPad Split View and landscape phone get a medium sheet that is too short | layout                    | Under 500 pt of height every sheet is large; test 852 x 393.                                                                  |
| Kanban's existing sheet regresses when its code is replaced              | regression                | Its test file stays and passes against the shared implementation before the old code is deleted.                              |
| Two sessions edit `adaptive_sheet.dart`                                  | process                   | PR A is the style session's alone; PR B starts from its merge.                                                                |
| The grabber is the only affordance for VoiceOver users                   | accessibility             | Increase and decrease actions on the grabber; Close stays in content.                                                         |

## Acceptance checks

- **Catalog** (first, PR A): for each profile, a sheet on iPhone 393 x 852 at rest, with a list, with a text field and the keyboard up, at 320 x 568 with scale 2.0 and 3.1, and in landscape 852 x 393; light and dark; plus the unchanged pair on Android, iPad (dialog) and Mac (dialog).
- **Widget tests** (mirror `test/kanban_task_sheet_test.dart`): detent heights (medium is half of the height under the safe inset, large is the full height), fling up and down, dismiss below the lowest detent, the grabber's size and accessibility actions, `PopScope(canPop: false)` snaps back, a text field's focus goes to large, a short content opens at its own height, landscape is large only, Android still shows the Material sheet with `_DragHandle` when asked, wide and macOS still show a `Dialog`.
- **Per call site** (PR B): a test table asserting the profile of each sheet, driven from the same list the guard reads, and the cancel path (swipe-down returns null and nothing is sent) for each confirmation.
- **Guard:** `arch.sheets.detents` fails on a `showAdaptiveSheet(` without `detents:`; revert the argument at one site and watch it fail.
- **Spec scenarios:** `specs/adaptive-sheets/spec.md`.
- **Workflow screenshots:** rerun `test/workflows/` as iPhone and look at the sheets.

## Design pass

The pass ran; its canvas and per-artboard decisions are in `docs/design-briefs/cupertino-detent-sheets.md`. It confirms decision 3 (the grabber on every iOS sheet, `fit` included), medium at half the height under the safe inset, no presenter scaling for `large` (option C stays rejected) and the proposal's profile table. One build note: sheet actions stay at least 44 pt, which the iOS theme already gives (`lib/src/theme/hermes_theme.dart:147-149`); task A.7 guards it.

## Open questions for the design pass

See `docs/design-briefs/cupertino-detent-sheets.md`.
