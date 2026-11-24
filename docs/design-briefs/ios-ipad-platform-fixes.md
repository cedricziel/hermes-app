# Design brief: iPhone and iPad platform fixes

No openspec change exists for this pass. These are audit fixes, not a feature, so there is no `design.md` to read. The sources are the iPad audit (roadmap F.187) and the cross-platform audit (F.188), plus the findings named below (B2, B3, B4, D2, D3, D7, D10). Each item is the smallest visual change that removes the finding. Nothing here is a redesign.

## Design (done)

Claude Design canvas "Hermes: iPhone and iPad platform fixes", built on the Hermes App design system: https://claude.ai/artifact/L8ftqQwyuNLYauMAcJRga7 (private; ask its owner for access). 35 artboards (one overview plus 34) in eight rows, each row an item with its state today (orange sticky) and the decision (gray sticky):

- B3, attach menu and skill job status: iPad before (stretched bottom sheet), iPad after (420 pt dialog), skill job status on iPad (520 pt dialog), phone (unchanged bottom sheet), Mac with one origin (file picker opens at once).
- B4, "Set up a model": iPad before (about 920 pt), iPad after (Apple alert), Material desktop after (560 pt cap), iPhone after.
- B2, chat-row actions on iPad: before (full-width action sheet), after on long press (popover at the row), after on secondary click (menu at the pointer), iPhone (unchanged action sheet).
- D2, GroupedDialog header at large text: before at x2.0, after at x2.0, after at x3.1, default size (unchanged). All 320 pt wide.
- D3, large-text overflows at 320 pt x2.0, before and after each: skill job sheet, MCP JSON editor, Kanban card meta row, checkpoints page.
- D7, chat list pull to refresh on iPhone: before, pulling, refresh failed.
- D10, Kanban on iPhone: before, after.
- Memory confirmations: delete before, delete on iOS, leave on iOS (dark), delete on Android.

Where this brief and the canvas differ, "Corrections after the pass" below lists the differences; the decisions are the ones in this brief.

Decisions taken in the design pass (each bullet is one decision; code references are to `main`):

B3, attach menu and skill job status:

- Width: `showAdaptiveSheet` switches on `isWideLayout` (`lib/src/theme/breakpoints.dart`): 900 pt on every platform, and 700 pt only on a full-screen iPad (iOS chrome, shortest side at least 600 pt). Above the switch both are dialogs, 420 pt for the attach menu and 520 pt for the skill job status. Android, Windows and Linux at 800 pt keep the sheet. The 700/900 rule is F.187, not F.160.
- Phone: keeps the bottom sheet. Today's sheets set `showDragHandle: true` (`attachment_surface.dart` ~36, `skill_job_sheet.dart` ~36); the sheet branch of `showAdaptiveSheet` (`adaptive_sheet.dart` ~25-30) does not, and sets `isScrollControlled` and `useSafeArea`. Decision: keep the handle, so `showAdaptiveSheet` gets a `showDragHandle` option that the two call sites pass.
- Content, rows and copy do not change. Photo Library, Take Photo and Files keep their rows.
- One origin only (Mac and desktop: Files): `+` opens the file picker directly and shows no menu. This single origin also satisfies the macOS brief's no-bottom-sheets rule. iPhone and iPad keep the menu.
- Skill job status: `SkillJobSheet` scrolls its details only on macOS (`skill_job_sheet.dart` ~55, 104-112). In an iPad dialog it must scroll too; this is folded into D3.

B4 ("Set up a model"):

- `showModelSetup` (`lib/src/models/widgets/model_setup_dialog.dart`) uses `showAppDialog` with `AppAlertDialog` instead of a raw `AlertDialog`. On Apple it is the platform alert (270 pt, one action, "Check again" as the default); on Material it is capped at 560 pt like every other `AppAlertDialog`.
- Title, text and the button come from `app_en.arb` and `app_de.arb` under the `@@x-area-models` anchor.
- The command is a plain `SelectableText` today; it becomes a monospace selectable line in the alert content. The canvas alert has no content slot, so it shows the command inside the message.

B2, chat-row actions on iPad:

- Trigger: at the iPad layout (touch, 700 pt and up) a long press or a secondary click opens a popover menu instead of a `CupertinoActionSheet`. A phone keeps the action sheet and the swipe actions.
- Component: Flutter has no touch `Menu`. Use `CupertinoMenuAnchor` (cupertino_ui). It takes an open position and flips at the screen edges; it is 262 pt wide on screens of 768 pt and up, 250 pt below.
- Placement, long press: the anchor opens at the row's trailing edge, its top edge level with the row. Placement, secondary click: the corner is at the pointer, from `onSecondaryTapUp`. Both flip left or up when they would leave the screen.
- Items: Rename, Pin or Unpin, Archive, a divider, Delete in red, 44 pt rows. The labels are hard-coded in `thread_actions_menu.dart` and `swipeable_thread_row.dart` (~33-45) today and get ARB keys.
- Wiring: `AdaptiveMenuController.open(at:)` ignores `at` on iOS (`adaptive_popup_menu_button.dart` ~116-123), and the iOS thread row has no `ThreadActionsButton` (`inlineButton = housekeeping != null && !touch`, `thread_sidebar.dart` ~523; `onLongPress` and `onSecondaryTap` are wired only when `inlineButton`). So this needs a new row-level menu wrapper; the touch row cannot reuse the button's controller.
- Delete: today's confirmation is `showConfirmDialog(destructive: true)` with a filled, default confirm (`runThreadAction`, `thread_actions_menu.dart` ~280-287; Bot Chat retire at ~266-271), which breaks the no-filled-destructive rule. This menu's Delete goes through `showDestructiveConfirm` (`adaptive_dialog.dart` ~251): Cancel is the default and Delete is red text. The sweep of the other raw dialogs belongs to the style session.
- Accessible name: "Chat actions for <title>" (`thread_actions_menu.dart` ~168).
- The doc comment at `thread_sidebar.dart` ~50 says the menu opens from a secondary click; iOS has none today. Fix it with the wrapper.
- Overlap: Android brief E7 also touches `_ThreadRow` and `ThreadActionsButton`; the two PRs must be sequenced.

D2 (GroupedDialog header at large text):

- `GroupedDialog._Title` (`lib/src/widgets/grouped_dialog.dart` ~121) is shared by the iOS and macOS chrome. When title and Done do not fit on one line, Done takes its own 44 pt row, right-aligned, and the title wraps under it, centred. The header grows; nothing is cut.
- VoiceOver reads the title first, then Done, although Done is above it on screen.
- At the default size the header is unchanged (title centred, Done on the same line). Checked at x2.0 and x3.1 on 320 pt.

D3 (large-text overflows):

- Skill job sheet, phone: `showModalBottomSheet` gets `isScrollControlled` and a height cap of 90% of the screen (`skill_job_sheet.dart` ~34-38), and the details scroll on every platform, so Close is reachable.
- MCP JSON editor: warning, editor and messages scroll as one page.
- Kanban card meta row: `Wrap` already wraps the items (`kanban_card.dart` ~71). Only `_Meta`'s `Text(label)` (~151) has no flex or overflow handling. Decision: the label wraps, so a long assignee shows in full; nothing is ellipsized, which matches the Accessibility section.
- Checkpoints page: rows already stack and scroll (`restore_all_bar.dart`, `checkpoint_row.dart` with `titleMaxLines: null`, scrolling list bodies), and a row has a "..." menu, not a Restore button. The element that overflowed in the audit is the body `Column` of `checkpoints_page.dart` (~173), +241 px at 320 pt x2.0. Decision: it scrolls as one page.

D7 (chat list pull to refresh):

- Scope: Apple touch layouts (the iPhone drawer and the iPad sidebar list share one widget). It re-reads the first page of chats and nothing else (not the open chat, not other lists). Mac and Material are unchanged; Android's chat list has no refresh either, a known gap and out of scope.
- Control: the app has no `CupertinoSliverRefreshControl`; every pull to refresh uses `RefreshIndicator.adaptive` (`files_screen.dart` ~507). Use that too.
- Controller: `ChatController.refreshThreadList()` (~947-974) reads at least `max(50, loaded count)` rows, merges title, pin, updatedAt and unread, never reports failure (a catch goes to `reportBug`), and returns at once when `threadListInvalidationBlocked`, setting `_listRefreshPending`. The error banner needs a new result or state on the controller, for example a refresh outcome the list watches.
- While the refresh is deferred the spinner stays until the deferred read has run and settled; it does not end at once as a success.
- Failure: the list stays, and an `AppBanner` (error tone) under the header says "Couldn't refresh your chats." with "Pull down to try again."; no automatic retry.

D10 (Kanban New task button on iPhone):

- The extended button shows on every non-Mac platform (`kanban_screen.dart` ~254-260), so the 88 pt bottom padding (button 56, gap 16, margin 16) applies wherever it shows, not only on iPhone. Reuse `NewChatFab.listBottomPadding` (`new_chat_fab.dart` ~11) or a shared constant. The lists are at `kanban_screen.dart` ~497-530.
- The button stays extended; there is no collapse on scroll (fewer moving parts, and the label stays readable).

Memory confirmations (`memory_screen.dart` ~92-140; both are raw `AlertDialog` today):

- Delete: `showDestructiveConfirm`. The label stays "Delete permanently" (ARB key `memoryDeleteConfirmAction`, as in PR #1136), with Cancel as the default. On Apple, Delete is red text; on Material, two text buttons, Cancel first, Delete in the error colour.
- Leave: `showConfirmDialog` or `AppAlertDialog` with "Keep draft" as the default and "Discard and leave" as destructive text, not filled, as PR #1136 does.
- Stacking: `AppAlertDialog` cannot force it. The Cupertino alert auto-stacks when the labels do not fit side by side, which "Discard and leave" does.
- Never a filled black confirm button.

## Who and why

People on an iPad or an iPhone who hit a screen that looks like a stretched phone screen, a raw Material dialog or text that collides at a large text size. The audit findings are fixes to rules the app already has (adaptive sheets and dialogs, the platform alert idiom, honouring the text size, no filled destructive button).

## Kit to reuse

`showAdaptiveSheet` and `AdaptiveSheet`, `AppAlertDialog` and `AppDialogAction`, `showDestructiveConfirm`, `GroupedDialog` and its grouped rows, `SkillJobSheet`, `KanbanCard`, `AppBanner`, `LoadingSkeleton`, `RefreshIndicator.adaptive`.

New components needed: one row-level touch menu wrapper for B2, built on `CupertinoMenuAnchor`, with an open position for long press and secondary click. Plus a `showDragHandle` option on `showAdaptiveSheet` (B3) and a refresh outcome on `ChatController` (D7).

## Accessibility

- Touch targets stay at 44 pt (Done in the large-text header, popover rows).
- Large text: nothing is capped or cut. Overflow scrolls or wraps (D2, D3).
- The pull to refresh failure is an error line with an icon and words, not colour alone; the refreshing state is announced as "Refreshing chats".
- Destructive actions are red text with a word, and Cancel or Keep draft is the default.
- The popover has the accessible name "Chat actions for <title>"; it closes on Escape and on a tap outside.

## Platform differences

- iPhone: phone sheets and the action sheet stay; D2, D3, D7, D10 and the confirmations apply.
- iPad (touch, full screen, 700 pt and up): dialogs for the attach menu and skill job status, the popover for chat rows, the platform alert for "Set up a model".
- Mac and desktop: dialogs as before (Material desktop switches at 900 pt); a single origin opens the file picker directly. Mac chat rows keep their right-click menu.
- Android, Windows, Linux: Material alerts capped at 560 pt, text buttons for confirmations; no pull to refresh change; the attach menu and skill job status keep the sheet below 900 pt.

## Corrections where this brief did not work

- Large text is simulated on the canvas by laying the content out in a box 1/2.0 (or 1/3.1) of 320 pt wide and zooming it, so padding and targets scale too. It is a close look, not a pixel match.
- The "before" states of the D3 items cannot be rendered by the kit, which already wraps; they are drawn as markup with Flutter's yellow and black overflow stripes where the content is cut.
- The kit's `AlertDialog` has no content slot, so the "Set up a model" command is part of the message on the canvas.
- The kit's `Sheet` dialog looks the same on every platform (Material), so the iPad dialogs for B3 are the kit's `Sheet` with Apple grouped rows inside.

## Corrections after the pass

Where a decision differs from the canvas:

- B2: the canvas labels the popover the kit's touch `Menu`, 250 pt. In Flutter it is `CupertinoMenuAnchor`, 262 pt at 768 pt and up, 250 pt below, so use the Flutter widths.
- B2: the canvas does not draw the Delete confirmation; it uses `showDestructiveConfirm`.
- B3: the canvas shows the dialog from 700 pt on every platform. In code it is 700 pt on a full-screen iPad and 900 pt elsewhere.
- B4: the canvas shows the command in the message; the code puts it in a monospace content line.
- D3: the canvas ellipsizes a long Kanban assignee; the decision is to wrap it. The canvas checkpoints row shows a Restore button; the real row has a "..." menu, and the page body scrolls instead.
- D7: the canvas shows a Cupertino refresh control; the code uses `RefreshIndicator.adaptive`.
- Memory: the canvas can show stacked buttons on Apple; stacking is automatic, not forced.

## Copy added by the design

Every new string needs English and German in `app_en.arb` and `app_de.arb`, under its area anchor.

| English                                                | German                                               | Area anchor                      |
| ------------------------------------------------------ | ---------------------------------------------------- | -------------------------------- |
| Couldn't refresh your chats.                           | Chats konnten nicht aktualisiert werden.             | `@@x-area-chat` (thread list)    |
| Pull down to try again.                                | Zum erneuten Versuch nach unten ziehen.              | `@@x-area-chat` (thread list)    |
| Refreshing chats                                       | Chats werden aktualisiert                            | `@@x-area-chat` (thread list)    |
| Attach                                                 | Anhängen                                             | `@@x-area-chat/attachments`      |
| Photo Library, Take Photo, Files (hard-coded today)    | Fotomediathek, Foto aufnehmen, Dateien               | `@@x-area-chat/attachments`      |
| Rename, Pin, Unpin, Archive, Delete (hard-coded today) | Umbenennen, Anheften, Loslösen, Archivieren, Löschen | `@@x-area-chat` (thread actions) |

The "Set up a model" alert text is the existing English text moved under `@@x-area-models` with a German translation. The memory dialogs keep their current wording ("Leave this memory?", "Permanently delete this memory?", "Keep draft", "Discard and leave", "Cancel", "Delete permanently"); they move into the ARB files under `@@x-area-memory` (PR #1136 keeps the key `memoryDeleteConfirmAction`).

## Not confirmed

- The popover's exact offset from the row (the canvas uses 0 horizontally and 0 vertically) is a starting point for the catalog use case.
- The 700 pt iPad cut-over and the 900 pt general one are F.187 and `lib/src/theme/breakpoints.dart`; whether the iPad rule should also apply to Material at 700 pt is not decided here.
