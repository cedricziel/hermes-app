# Design brief: chat checkpoints and context

For the visual design pass of the OpenSpec change `chat-checkpoints-and-context`. Everything lives inside the chat's Activity panel (phone: detent sheet; iPad, wide windows and Mac: the docked inspector). No new screen, no new tab. Reuse: `ActivityPanel` section and row styles, `DisclosureTile`, `GroupedList`/`GroupedRow`, `showAdaptiveSheet` (sheet on phone, dialog on Mac and wide), `ToolDiffBody`, the Session usage card's type, `PillSegmentedControl` not needed. Pages push inside the panel with a Back button (Mac: also ⌘[).

Voice: plain words, sentence case, no server terms (no "checkpoint hash", "compaction", "cwd"). "Files" and "folder" are fine.

## 1. Context row (Activity panel › This session, first)

**Job:** see at a glance how full the chat is, without being nagged.
**Hierarchy:** percentage, then bar, then "about 124k of 200k". State word "Nearly full" only from 80%.
**Layout:** one row, 56 pt tall minimum; label "Context" left, "62%" right; bar below full width (4 pt, rounded); caption under the bar. Row wraps to more lines at large text.
**States:** unknown (row absent); under 80% (neutral); 80–94% ("Nearly full", warm accent on the percentage and bar); 95%+ (stronger accent, still no motion, no icon pulse); estimated ("about" before numbers); stale ("Not up to date", muted, chevron stays); compressing (bar replaced by "Compressing the conversation…" with a thin indeterminate progress, reduced motion = static dots).
**Suggestion (85%+, idle, once):** an extra line under the caption: "Nearly full. Compress to make room?" with text buttons "Compress…" and "Not now". Never a banner, never a dot elsewhere.
**Meaning not by colour alone:** percentage text, state word, bar label.
**Platform:** iPhone sheet full width; iPad/Mac inspector 320–360 pt wide, same row; Android Material 3 list item with a linear progress indicator.

## 2. Context details (pushed page, title "Context")

**Job:** understand what fills the context and, if wanted, make room.
**Order:** summary line ("62% full · about 124k of 200k tokens · estimated"), model name (muted), then "What's in it" list, then a single "Compress conversation…" button row.
**What's in it:** one row per category, largest first: name left, "about 61k" right, a thin proportional bar under each (decorative). Names: System prompt, Tools, Rules files, Skills, MCP servers, Sub-agents, Memory, Conversation. Footer: "These numbers are estimates."
**States:** loading (known total + three skeleton rows, "Reading what fills the context…"); breakdown failed ("Couldn't read what fills the context." + "Try again"); unsupported (total and compress only); disconnected (values muted, buttons disabled, "Not up to date"); App Lock (page unreachable).
**Primary action:** Compress conversation… (the only button; filled on phone, default on Mac). Disabled with a caption "Wait for the reply to finish." while the chat replies.

## 3. Compress confirmation (adaptive sheet / dialog)

Title: "Compress this conversation?"
Body (short list, four lines):
- "Older messages are replaced by a short summary. Recent messages and your instructions stay."
- "A helper model writes the summary and uses tokens on your account."
- "This can't be undone."
- "The chat reloads and shows the summary where the older messages were."
Advanced (collapsed, "Advanced"): field "Focus on" with helper "Keep details about…" (one line, optional).
Buttons: "Cancel" (default, left/secondary), "Compress" (primary, not red). Mac dialog: Return = Cancel? No: Return = Compress only when focus is on the button; default button is Cancel. 
In flight: the sheet closes; the Now section shows "Compressing the conversation…".
Results (inline note in the panel and a divider line in the transcript, muted, centered): "Conversation compressed · 42 → 9 messages". Other results: "There isn't enough to compress yet." / "Compressing wouldn't make this chat smaller." / "Hermes couldn't write the summary, so nothing changed." (+ "Try again") / "Wait for the reply to finish, then try again." / "Hermes is already compressing this chat." / "Hermes didn't answer. The conversation may have been compressed."

## 4. File checkpoints row (This session)

**Job:** know there is a way back for file changes, and open it.
Row: "File checkpoints · 3", chevron. Subtitle "Restore files Hermes changed" (one line).
States: on (count); off with edits ("File checkpoints are off", subtitle "Tap to see how to turn them on"); loading (count placeholder); failed ("Couldn't read checkpoints"); absent otherwise.

## 5. Checkpoint page (title "File checkpoints")

**Job:** pick a point in time to look at or go back to.
Header note (muted, 2 lines): "Checkpoints belong to this chat's folder, so other chats in it see them too."
List newest first; a row: sentence ("Before editing a file", "Before a terminal command", "Before a restore", "Checkpoint"), time right ("12 min ago"), second line once read "3 files differ now". Row action: tap opens the changes; trailing "…" menu (Mac: right-click too): "See changes", "Restore all files…" (destructive text).
Empty: icon-less text, "No checkpoints yet for this chat's folder. Hermes makes one just before it first edits a file in a turn."
Off: "File checkpoints are off on your Hermes server. To use them, turn on `checkpoints.enabled` in its config." (code span, selectable, no link).
Unreadable: "Couldn't read checkpoints." + Try again. Container: "Checkpoints don't cover this chat's workspace."
Skeleton: four rows with the label "Loading checkpoints…".
Pull to refresh on phone only; a "Refresh" bar action on Mac/desktop.

## 6. Changes (pushed page, title "Changes since <time>")

**Job:** see which files would change if you went back.
File list first: path (name bold, folder muted, middle-truncated so the extension stays), "+12 −3" right, chevron. Sticky footer on phone: total "5 files" and button "Restore all files…" (destructive text button, not filled).
Cut-short banner (only when detected, muted, inline): "Hermes only sends the first part of a large diff. The file list is complete."
States: loading ("Reading the changes…"), unreadable ("Couldn't read the changes. Try again."), no changes ("No changes since this checkpoint."), container refusal.

## 7. One file (pushed page, title = file name)

**Job:** read what would change and restore just this file.
Content: heading "Changes in <file>", "12 added, 3 removed" (muted); the diff in `ToolDiffBody` full width, monospace, horizontal scroll, no wrapping, selectable; `+`/`−` marks stay. Binary: "This file isn't text, so there is no preview." Cut: "Hermes cut this diff short." 
Primary action (bottom bar on phone, toolbar on Mac): "Restore this file…". Previous/next file arrows in the toolbar (⌥↑/⌥↓ on Mac) so a user can walk the list.

## 8. Confirmations (adaptive; destructive in red; default Cancel)

**Restore this file** — title "Restore this file?" Body: "<file> goes back to how it was <12 min ago>, before <editing a file>. Changes you made to it since will be overwritten. Hermes saves the current version first, so you can go back. Your chat isn't changed." While the agent works add: "Hermes is working in this folder right now. It may change the file again." Buttons: Cancel, "Restore file".
**Restore all files** — title "Restore all files?" Body: "Files in this folder go back to how they were <12 min ago>, before <editing a file>. 5 files differ now. Changes you made to them since will be overwritten. Files Hermes created after that stay where they are. Hermes saves the current state first." Then a bold, separated line: "This also removes your last message and Hermes' answers after it from this chat." and under it muted: "Chats don't track which message a checkpoint belongs to, so only your last message is removed, whichever checkpoint you pick. Other chats in this folder aren't changed, but they see the restored files." Buttons: Cancel (default), "Restore all files" (red). Disabled entry while replying: "Wait for the reply to finish."
When the number is unknown: "Some files differ now."
Results: "Restored 3 files" (panel note), transcript divider "Restored 3 files · removed your last message", composer filled with the removed message and a one-line hint above it, "Your last message is back in the box." Panel note: "Hermes saved the previous state as the top checkpoint, ‘Before a restore’." Errors: "Files were restored, but the chat couldn't be rewound. Your messages are unchanged." / "Hermes didn't answer. The files may have been restored." / "This checkpoint includes a project inside the folder that Hermes didn't capture, so it can't restore it." / generic "Hermes couldn't restore the files."

## Differences by form factor

- **iPhone:** detent sheet; pages push; confirmations are bottom sheets; sticky bottom action on Changes and One file; swipe-back works.
- **iPad / wide Android / Windows / Linux:** docked inspector (≥760 pt); same pages; confirmations are dialogs; the file list and the diff may sit side by side when the inspector is 900 pt or wider (list left 300 pt, diff right).
- **Mac:** inspector with Back and ⌘[; toolbar actions in the shared Mac toolbar; Chat menu has "Compress Conversation…" (disabled unless idle); right-click on a checkpoint row for its menu; keyboard: Return opens, ⌥↑/⌥↓ steps through files, Escape goes back; no bottom sheets.
- **Android:** Material 3 list items and linear progress; dialogs for confirmations on tablets, bottom sheets on phones.

## Accessibility (design checks)

Targets 44/48; the largest text size shows full percentages and file extensions; contrast AA both themes; additions and removals marked by characters; the bar is decorative with a label; reduced motion removes the compressing animation; screen reader order: label, percentage, state, action; destructive buttons announced as such; focus returns to the opened row.
