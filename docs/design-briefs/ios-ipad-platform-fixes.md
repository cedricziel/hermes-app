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

Where this brief and the canvas differ, the sections below have been brought in line with the canvas.

Decisions taken in the design pass:

- B3 (attach menu, skill job status): from 700 pt wide (iPad, desktop) both are shown by `showAdaptiveSheet` as a dialog, 420 pt for the attach menu and 520 pt for the skill job status; a phone keeps the bottom sheet with its drag handle. The content, rows and copy do not change. When the composer has one origin only (Mac and desktop: Files), `+` opens the file picker directly and shows no menu. iPhone and iPad keep the menu (Photo Library, Take Photo, Files).
- B4 ("Set up a model"): `AppAlertDialog` instead of a raw `AlertDialog`. On Apple it is the platform alert (270 pt, one action, "Check again" as the default); on Material it is capped at 560 pt like every other `AppAlertDialog`. Title, text and the button come from `app_en.arb` and `app_de.arb` under the models area anchor. The command stays a monospace selectable line in the alert content (the canvas alert has no content slot, so it shows the command inside the message).
- B2 (chat-row actions on iPad): at the wide layout (700 pt and up, touch) a long press or a secondary click opens a popover menu instead of a `CupertinoActionSheet`. Long press: the menu sits beside the row, its top edge level with the row and its leading edge at the row's trailing edge. Secondary click: the menu's corner is at the pointer. Both flip left or up when they would leave the screen. The menu is the kit's touch `Menu`, 250 pt wide, 44 pt rows: Rename, Pin or Unpin, Archive, a divider, Delete in red. Delete still opens the existing confirmation. A phone keeps the action sheet and the swipe actions.
- D2 (GroupedDialog header at large text): when title and Done do not fit on one line, Done takes its own 44 pt row, right-aligned, and the title wraps under it, centred. The header grows; nothing is cut. At the default size the header is unchanged (title centred, Done on the same line). Checked at x2.0 and x3.1 on 320 pt.
- D3 (large-text overflows): the skill job sheet is at most 90% of the screen and its content scrolls, so Close is reachable. The MCP JSON editor scrolls warning, editor and messages as one page. The Kanban card meta row wraps and cuts a long assignee with an ellipsis (the kit's `KanbanCard`). The checkpoints page stacks its row (text, then Restore) and the page scrolls.
- D7 (chat list pull to refresh): yes, on Apple touch layouts (the iPhone drawer and the iPad sidebar list share one widget). A Cupertino refresh control shows above the list. It re-reads the first page of chats and nothing else (not the open chat, not other lists). If the read fails, the list stays and an error `Banner` under the header says "Couldn't refresh your chats." with "Pull down to try again."; no automatic retry. Mac and Material are unchanged.
- D10 (Kanban New task button on iPhone): the list gets 88 pt of bottom padding (button 56, gap 16, margin 16), so the last card scrolls clear of the button. The button stays extended; there is no collapse on scroll (fewer moving parts, and the label stays readable).
- Memory confirmations: leave and delete use `AppAlertDialog`. On Apple: Cupertino alert; delete has Cancel as the default and Delete as red text; leave has "Keep draft" as the default and "Discard and leave" as red text, stacked (the second label is too long for side-by-side buttons). On Material: two text buttons, Cancel first, the destructive one in the error colour, neither filled. Never a filled black confirm button.

## Who and why

People on an iPad or an iPhone who hit a screen that looks like a stretched phone screen, a raw Material dialog or text that collides at a large text size. The audit findings are fixes to rules the app already has (adaptive sheets and dialogs, the platform alert idiom, honouring the text size, no filled destructive button).

## Kit to reuse

`showAdaptiveSheet` and `AdaptiveSheet`, `AppAlertDialog` and `AppDialogAction` (`filledOnMaterial: false` for destructive confirmations), `NamedPopupMenuButton` and the touch menu idiom, `GroupedDialog` and its grouped rows, `SkillJobSheet`, `KanbanCard`, `AppBanner`, `LoadingSkeleton`. New components needed: none.

## Accessibility

- Touch targets stay at 44 pt (Done in the large-text header, popover rows, Restore).
- Large text: nothing is capped or cut. Overflow scrolls or wraps (D2, D3).
- The pull to refresh failure is an error line with an icon and words, not colour alone; the refreshing state is announced as "Refreshing chats".
- Destructive actions are red text with a word, and Cancel or Keep draft is the default.
- The popover has the accessible name "Chat actions"; it closes on Escape and on a tap outside.

## Platform differences

- iPhone: phone sheets and the action sheet stay; D2, D3, D7, D10 and the confirmations apply.
- iPad (touch, 700 pt and up): dialogs for the attach menu and skill job status, the popover for chat rows, the platform alert for "Set up a model".
- Mac and desktop: dialogs as before; a single origin opens the file picker directly. Mac chat rows keep their right-click menu.
- Android, Windows, Linux: Material alerts capped at 560 pt, text buttons for confirmations; no pull to refresh change.

## Corrections where this brief did not work

- Large text is simulated on the canvas by laying the content out in a box 1/2.0 (or 1/3.1) of 320 pt wide and zooming it, so padding and targets scale too. It is a close look, not a pixel match.
- The "before" states of the D3 items cannot be rendered by the kit, which already wraps; they are drawn as markup with Flutter's yellow and black overflow stripes where the content is cut.
- The kit's `AlertDialog` has no content slot, so the "Set up a model" command is part of the message on the canvas.
- The kit's `Sheet` dialog looks the same on every platform (Material), so the iPad dialogs for B3 are the kit's `Sheet` with Apple grouped rows inside.

## Copy added by the design

"Couldn't refresh your chats." and "Pull down to try again." (D7 error banner); "Refreshing chats" (accessible name); the "Set up a model" alert text is the existing English text moved into the ARB files with a German translation; "Attach" as the title of the wide dialog. The memory dialogs keep their current wording ("Leave this memory?", "Permanently delete this memory?", "Keep draft", "Discard and leave", "Cancel", "Delete") and move into the ARB files.

## Not confirmed

- The popover's exact offset from the row (the canvas uses 0 horizontally and 0 vertically) is a starting point for the catalog use case.
- The 700 pt cut-over follows F.160; the iPad audit noted that its boundaries are 700 and 900.
