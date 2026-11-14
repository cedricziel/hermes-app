# Design brief: chat checkpoints and context

For the visual design pass of the OpenSpec change `chat-checkpoints-and-context`. Everything lives inside the chat's Activity panel (phone: detent sheet; iPad, wide windows and Mac: the docked inspector). No new screen, no new tab. Reuse: `ActivityPanel` section and row styles, `DisclosureTile`, `GroupedList`/`GroupedRow`, `showAdaptiveSheet` (sheet on phone, dialog on Mac and wide), `ToolDiffBody`, the Session usage card's type, `PillSegmentedControl` not needed. Pages push inside the panel with a Back button (Mac: also ⌘[).

Voice: plain words, sentence case, no server terms (no "checkpoint hash", "compaction", "cwd"). "Files" and "folder" are fine.

## Design (done)

Claude Design canvas "Hermes: Checkpoints and context", built on the Hermes App design system: https://claude.ai/artifact/HJNnRJLyLv6uanZZCLBQyY (private; ask its owner for access). 89 artboards in ten rows: the Activity panel and Context row on iPhone (62%, 82%, 100%, suggestion, compressing, disconnected, and boards with every Context row and File checkpoints row state); Context details (loaded, loading, failed, old server, replying, 82%, over the limit, disconnected); Compress (confirmation, Focus on, refused focus, reply started, transcript line, panel note, summary failed, and a board of every compress and restore outcome); the checkpoint list (five, twenty, row menu, empty, off, loading, failed, workspace not covered, disconnected); Changes and one file (five files, cut short, loading, unreadable, nothing differs, replying; diff, cut, not text, name that can't be restored alone); restore confirmations and outcomes (all, count unknown, one file, one file while working; chat and composer after, list after, Changes after one file, no new “Before a restore”, refused, no answer, chat not rewound, failed part-way, refused while compressing, quoted message still there, Restore all files at the largest text size); dark; the largest text size; Android; iPad and Mac (inspector, Chat menu, list and diff side by side, dialogs); and the nine base screens the others reuse with inputs. Where this brief and the canvas differ, the sections below have been brought in line with the canvas.

Decisions taken in the design pass:

- Context row: "Context" left; the state word with its icon, the percentage and a chevron right; a 4 pt bar; the caption "about 124k of 200k tokens" (the unit is added; "about" only for estimates). At the largest text size the row wraps and the percentage moves under the label, whole.
- Levels: below 80% neutral; 80–94% "Nearly full" in the warning colour with a warning icon; 95–99% "Nearly full" in the error colour with an error icon; 100% or more used than the window "Full". The server clamps the percentage at 100, so "Full" is the only over-limit wording, with the real counts ("about 212k of 200k tokens").
- Nothing that removes messages or changes files is a filled button. Compress conversation… and the confirmation's Compress are outlined; Restore all files…, Restore this file… and the confirmations' Restore buttons are red outlined. In every confirmation Cancel is the default.
- Context details: full numbers with thousands separators ("about 124,000 of 200,000 tokens", "61,200"); the row keeps the short "124k". Category values drop "about"; the footer says they are tokens and estimates. Only the list fails or loads; the total and Compress stay.
- The Restore all files confirmation quotes the app's last prompt, the message the server is expected to remove, and says "If this is the message removed, it goes back into the message box, unsent." The server removes its own last user turn, so the app fills the composer only when the re-read chat no longer holds that message. From the moment Restore all files is confirmed until it settles, Send is disabled and the queue held, because the server checks for a reply before restoring and rewinds whatever user turn is last.
- After Restore all files the panel goes back to the checkpoint list, re-read, with the outcome note on top and "Before a restore" as the first row. After Restore this file it goes back to Changes, re-read, where that file has left the list.
- Outcomes are notes in the shared `Banner` (icon, bold sentence, detail, optional Try again) under This session and at the top of the page they concern, announced once, politely. Success is green, "nothing changed" outcomes use the neutral tone, "may have happened" and partial results the warning tone, failures red; the words carry the meaning on their own. Red outlined Restore buttons are the shared `DestructiveTintButton`.
- Checkpoint row: the reason is the title and the time the subtitle, so neither is cut; the trailing "…" is a 44 pt button with "See changes" and "Restore all files…" (red, last). Tapping the row opens the changes.
- iPad and Mac show the same pages in the 360 pt inspector. From 900 pt of inspector the Changes list (320 pt) and the file's diff sit side by side. The Mac Chat menu has "Compress Conversation…", enabled only while idle.
- Refresh is a bar button on every platform, iPhone included; pull to refresh is extra, never the only way. Targets: 44 pt on iPhone and iPad, 28 pt pointer targets on the Mac, 48 dp on Android.

Corrections where this brief did not work:

- The suggestion repeated the row's state word ("Nearly full. Compress to make room?" under "Nearly full"); it now reads "Compress to make room?".
- "Tap to check" and "Tap to see how to turn them on" are wrong with a mouse or keyboard; the rows read "Not checked yet" and "See how to turn them on".
- "Changes since 12 min ago" cut off in the bar; the title is "Changes" with the subtitle "Since 12 min ago · Before editing a file".
- Middle truncation of file names plus "+12 −3" at the right still cut long names on a phone; names wrap and the counts sit in the subtitle with the folder.
- The brief made Compress the filled primary action; it removes older messages from the model's view for good, so it is outlined.
- The transcript line "Conversation compressed · 42 → 9 messages · about 120k → 30k tokens" wrapped badly; the transcript keeps the messages and the panel note carries the tokens.

Copy added by the design: "Compress to make room?"; "Not checked yet"; "See how to turn them on"; "Numbers are tokens. They are estimates."; "Older messages are replaced by a short summary." (caption under Compress); "Reconnect to compress."; "Reconnect to restore files."; "Hermes usually compresses by itself before this. Compressing now makes room." (over the limit); "Focus on (optional)", "The summary keeps more about this topic.", "Write a topic, like “the database schema”. Leave out words that start with “-”, and don't start with “here”."; "If this is the message removed, it goes back into the message box, unsent."; "Another chat working in this folder can change these files again."; "Your first and latest messages stay word for word."; "Files restored"; "No new “Before a restore” checkpoint was added."; "Your last message in this app wasn't the one removed."; "Hermes is compressing this chat. Try again when it's done."; "Hermes couldn't restore the files. Some may have changed."; "5 files differ"; "Files that differ now" and "Lines added and removed since the checkpoint." (Changes); "Top of the folder"; "Not text, no preview"; "No changes since this checkpoint" with "The files in this folder are as they were 12 min ago."; "Hermes runs this chat in a separate workspace, so it keeps no checkpoints of its files."; "Newest first"; "Not up to date · reconnect to restore"; "Unknown time"; "Restored 1 file" with "Your chat isn't changed."; "Nothing changed." / "Nothing was changed." only under refusals that come before any file is touched; "The list was read again." and "The list and the chat were read again." under re-reads; "Hermes is compressing this chat in the background." with "The chat reloads when it is done."; "Hermes couldn't compress the conversation." (other failures).

## 1. Context row (Activity panel › This session, first)

**Job:** see at a glance how full the chat is, without being nagged.
**Hierarchy:** percentage, then bar, then "about 124k of 200k tokens". State word "Nearly full" (with a warning icon) only from 80%; "Full" at 100% or when the used count passes the window.
**Layout:** one row, 56 pt tall minimum; label "Context" left, "62%" right; bar below full width (4 pt, rounded); caption under the bar. Row wraps to more lines at large text.
**States:** unknown (row absent); under 80% (neutral); 80–94% ("Nearly full", warning icon, warning colour on the word, percentage and bar); 95–99% ("Nearly full", error icon and colour, still no motion, no icon pulse); 100% or over the window ("Full"); estimated ("about" before numbers); stale ("Not up to date", muted, chevron stays); compressing (bar replaced by "Compressing the conversation…" with a thin indeterminate progress, reduced motion = static dots).
**Suggestion (85%+, idle, once):** an extra line under the caption: "Compress to make room?" (the row already says "Nearly full") with text buttons "Compress…" and "Not now", each 44 pt tall. Never a banner, never a dot elsewhere.
**Meaning not by colour alone:** percentage text, state word, bar label.
**Platform:** iPhone sheet full width; iPad/Mac inspector 320–360 pt wide, same row; Android Material 3 list item with a linear progress indicator.

## 2. Context details (pushed page, title "Context")

**Job:** understand what fills the context and, if wanted, make room.
**Order:** summary ("62%" large, "full", the state word from 80%, an 8 pt bar, then "about 124,000 of 200,000 tokens" with thousands separators), model name (muted), then "What's in it" list, then a single "Compress conversation…" button row with a one-line caption under it.
**What's in it:** one row per category, largest first: name left, "61,200" right, a thin proportional bar under each (decorative). Names: System prompt, Tools, Rules files, Skills, MCP servers, Sub-agents, Memory, Conversation. Footer: "Numbers are tokens. They are estimates."
**States:** loading (known total + three skeleton rows, "Reading what fills the context…"); breakdown failed ("Couldn't read what fills the context." + "Try again"); unsupported (total and compress only); disconnected (values muted, buttons disabled, "Not up to date"); App Lock (page unreachable).
**Action:** Compress conversation… (the only button; outlined, not filled, because it removes older messages for good). Caption under it: "Older messages are replaced by a short summary."; "Wait for the reply to finish." while the chat replies (disabled); "Reconnect to compress." while disconnected (disabled).

## 3. Compress confirmation (adaptive sheet / dialog)

Title: "Compress this conversation?"
Body (short list, four lines):

- "Older messages are replaced by a short summary. Your first and latest messages stay word for word."
- "A helper model writes the summary and uses tokens on your account."
- "This can't be undone."
- "The chat reloads and shows the summary where the older messages were."
  Advanced (collapsed, "Advanced"): field "Focus on (optional)" with the hint "Keep details about…" and the helper "The summary keeps more about this topic.". A focus in which any word starts with "-", whose first word is "here" (any case), or that starts with "up to here" (Hermes reads those as commands) shows the error "Write a topic, like “the database schema”. Leave out words that start with “-”, and don't start with “here”."
  Buttons: "Cancel" (default, left), "Compress" (outlined: neither filled nor red). Mac dialog: the default button is Cancel; Return compresses only when focus is on Compress. If a reply starts while the sheet is open, Compress disables and the sheet says "Wait for the reply to finish."
  In flight: the sheet closes; the Now section shows "Compressing the conversation…".
  Results (a note in the panel and a divider line in the transcript, muted, centered): the transcript says "Conversation compressed · 42 → 9 messages"; the panel note adds the tokens, "42 → 9 messages · about 120k → 30k tokens". Other results: "There isn't enough to compress yet." / "Compressing wouldn't make this chat smaller." / "Hermes couldn't write the summary, so nothing changed." (+ "Try again") / "Wait for the reply to finish, then try again." (busy while replying) / "Hermes is compressing this chat. Try again when it's done." (busy while another compress runs) / "Hermes is already compressing this chat." (lock held) / "Hermes didn't answer. The conversation may have been compressed."

## 4. File checkpoints row (This session)

**Job:** know there is a way back for file changes, and open it.
Row: "File checkpoints · 3", chevron. Subtitle "Restore files Hermes changed" (one line).
States: on (count); stored chat with no live session ("File checkpoints", subtitle "Not checked yet"; no "Tap", which is wrong on a Mac and with a keyboard); off with edits ("File checkpoints are off", subtitle "See how to turn them on"); loading (subtitle "Loading checkpoints…" and a spinner); failed ("Couldn't read checkpoints" as the row's error line); App Lock ("3 checkpoints", not openable); absent otherwise.

## 5. Checkpoint page (title "File checkpoints")

**Job:** pick a point in time to look at or go back to.
Header note (muted, 2 lines): "Checkpoints belong to this chat's folder, so other chats in it see them too."
List newest first; a row: sentence ("Before editing a file", "Before a terminal command", "Before a restore", "Checkpoint") with the time under it ("12 min ago"; under, not at the right, so neither is cut), a 44 pt "…" button at the right, no per-row file counts (Hermes sends none and each read is costly); a count appears only on the changes page of a checkpoint the user opens. Row action: tap opens the changes; trailing "…" menu (Mac: right-click too): "See changes", "Restore all files…" (destructive text).
Empty: icon-less text, "No checkpoints yet for this chat's folder. Hermes makes one just before it first edits a file in a turn."
Off: "File checkpoints are off on your Hermes server. To use them, turn on `checkpoints.enabled` in its config." (code span, selectable, no link).
Unreadable: "Couldn't read checkpoints." + Try again. Container: "Checkpoints don't cover this chat's workspace."
Skeleton: four rows with the label "Loading checkpoints…".
A "Refresh" bar button on every platform; pull to refresh on phones as well.

## 6. Changes (pushed page, title "Changes", subtitle "Since <time> · <reason>")

**Job:** see which files would change if you went back.
File list first: the file name as the title, wrapping to more lines instead of truncating so the extension always stays; under it the folder and the counts, "src/auth · +48 −112" ("Top of the folder" for the root); chevron. Sticky footer on phone: "5 files differ" and "Restore all files…" (red outlined button, not filled), disabled with "Wait for the reply to finish." while the chat replies.
Cut-short note (only when detected): the list's section footer reads "Hermes only sends the first part of a large diff. The file list is complete.", and each file without a diff has the caption "Hermes cut this diff short".
States: loading ("Reading the changes…"), unreadable ("Couldn't read the changes. Try again."), no changes ("No changes since this checkpoint."), container refusal.

## 7. One file (pushed page, title = file name)

**Job:** read what would change and restore just this file.
Content: heading "Changes in <file>", "12 added, 3 removed" (muted); the diff in `ToolDiffBody` full width, monospace, horizontal scroll, no wrapping, selectable; `+`/`−` marks stay. Binary: "This file isn't text, so there is no preview." Cut: "Hermes cut this diff short."
Action (bottom bar on phone, bottom of the pane on Mac): "Restore this file…", a red outlined button, never filled. For a file name Hermes can't restore alone (it contains brackets, asterisks, question marks, backslashes or colons, or starts with a dash) the action is replaced by "This file's name can't be restored one at a time. Use Restore all files." Previous/next file arrows in the toolbar (⌥↑/⌥↓ on Mac) so a user can walk the list.

## 8. Confirmations (adaptive; destructive in red, outlined, never filled; default Cancel)

**Restore this file** — title "Restore this file?" Body: "<file> goes back to how it was <12 min ago>, before <editing a file>. Changes made to it since, by you or Hermes, will be overwritten. Hermes tries to save the current version first. Your chat isn't changed. Another chat working in this folder can change this file again." While the agent works add: "Hermes is working in this folder right now. It may change the file again." Buttons: Cancel, "Restore file".
**Restore all files** — title "Restore all files?" Body: "Files in this folder go back to how they were <12 min ago>, before <editing a file>." Then a list: "5 files differ now. Changes made since, by you or Hermes, will be overwritten." / "Files created after that stay where they are." / "Hermes tries to save the current state first." / ".env files, logs, node_modules, build output, caches, virtual environments, archives, videos, compiled binaries and files over 10 MB aren't in checkpoints: this leaves them as they are, and no checkpoint can bring them back." / "Another chat working in this folder can change these files again." Then a bold, separated line: "This also removes your last message and Hermes' answers after it from this chat." Under it the app's last prompt quoted in a tinted box, capped at a few lines with a fade, with "If this is the message removed, it goes back into the message box, unsent." Then muted: "Chats don't track which message a checkpoint belongs to, so only your last message is removed, whichever checkpoint you pick. Other chats in this folder keep their messages but see the restored files." Buttons: Cancel (default), "Restore all files" (red outlined). Disabled entry while replying: "Wait for the reply to finish." At the largest text size the body scrolls and the buttons stack.
When the number is unknown: "Some files differ now."
Results: "Restored 3 files" (panel note) only when the count was read from this checkpoint's changes since the last turn ended, otherwise "Files restored"; transcript divider "Restored 3 files · removed your last message" (or "Files restored · removed your last message"); composer filled with the quoted message, only when the re-read chat no longer holds it, and a one-line hint above it, "Your last message is back in the box." (otherwise the composer is left alone and the note adds "Your last message in this app wasn't the one removed."). Panel note, only when the re-read list holds a new checkpoint whose reason ends "restoring to" and the restored hash's first eight characters: "Hermes saved the previous state as the top checkpoint, ‘Before a restore’."; otherwise "No new “Before a restore” checkpoint was added." (Hermes ignores whether that save worked and makes none when nothing changed since the newest checkpoint). Errors: "Files were restored, but the chat couldn't be rewound. Your messages are unchanged." (only for the server's "checkpoint restored, but session history rewind failed"; composer unchanged) / "Hermes didn't answer. The files may have been restored." / "This checkpoint includes a project inside the folder that Hermes didn't capture, so it can't restore it. Nothing was changed." / "Hermes is compressing this chat. Try again when it's done." (busy during a compress) / "Hermes couldn't restore the files. Some may have changed." for a failed checkout and every other error, with the list re-read; never "Nothing changed." there.

## Differences by form factor

- **iPhone:** detent sheet; pages push; confirmations are bottom sheets; sticky bottom action on Changes and One file; swipe-back works.
- **iPad / wide Android / Windows / Linux:** docked inspector (≥760 pt); same pages; confirmations are dialogs; the file list and the diff may sit side by side when the inspector is 900 pt or wider (list left 300 pt, diff right).
- **Mac:** inspector with Back and ⌘[; toolbar actions in the shared Mac toolbar; Chat menu has "Compress Conversation…" (disabled unless idle); right-click on a checkpoint row for its menu; keyboard: Return opens, ⌥↑/⌥↓ steps through files, Escape goes back; no bottom sheets.
- **Android:** Material 3 list items and linear progress; dialogs for confirmations on tablets, bottom sheets on phones.

## Accessibility (design checks)

Targets 44/48; the largest text size shows full percentages and file extensions; contrast AA both themes; additions and removals marked by characters; the bar is decorative with a label; reduced motion removes the compressing animation; screen reader order: label, percentage, state, action; destructive buttons announced as such; focus returns to the opened row.
