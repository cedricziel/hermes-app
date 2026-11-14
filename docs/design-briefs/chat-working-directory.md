# Design brief: working directory and projects for a chat

Change: `openspec/changes/chat-working-directory`. Read its `design.md` for the server facts and `specs/chat-working-directory/spec.md` for the behaviour. This brief covers the look.

The person's job: **know which folder on my server the agent will work in, and point it at the right one, before it touches anything.** Hermes edits files and runs commands in that folder, so a wrong one is a real mistake. Everything below serves that, and nothing more.

Words to use: "folder", "on your server", "project", "chat". Not "cwd", "workspace", "working directory", "root", "worktree", "repository", "session". The path is always shown as "<path> · on your server", never as a file on the phone.

## Design (done)

Claude Design canvas "Hermes: Working directory", built on the Hermes App design system: https://claude.ai/artifact/JypA8yLhwweV9b6uZA2jpp (private; ask its owner for access). 100 artboards in 13 rows, each with its decision in a note under it, plus the eight base screens they are made from: the new-chat row (server default, project, recent folder, home folder, looking up, offline, long names, old server); the open chat's folder line (folder and branch, no branch, mismatch notice, offline, while replying); details (normal, home folder, replying, offline, old server); the picker (ready, more than eight rows, search, no match, loading, empty, projects failed, offline, unknown profile, browsing locked, More menu, scanning, found, nothing new, scan too slow); Browse (a level, `/`, opening, empty, not allowed, outside the boundary, missing, connection lost); Type a path (suggestions, relative path, checking, check too slow, missing, not allowed, 30 suggestions, no suggestions, server cannot check, found); changing an existing chat's folder (picker with Current, confirmation, changing, changed, header after, refused, server error, lost answer, could not confirm); the chat list by folder (none, one, many, long and clashing names); dark; the largest accessibility text; Android; iPad; Mac (new chat, open chat, row menu, row menu while replying, picker, browse, type, details with the path selected, confirmation, after a move, conversation window, long folder names). Where this brief and the canvas differ, the sections below have been brought in line with the canvas.

Decisions taken in the design pass:

- **The row, not a chip.** `WorkingDirectoryRow` is a full-width row above the composer card (surface-high fill, 12 pt corners, 48 pt minimum; 36 pt on a Mac): folder icon, "Runs in **demo**", a branch chip (branch glyph, monospace name, hairline pill), one tag ("Server default" outlined while nothing is picked, else the project name, tinted), then "<path> · on your server" with the path cut in the middle and the suffix always shown, and a chevron. The whole row is one button. A composer chip (`ComposerSelectorChip`) cannot hold a path and two tags at 44 pt, so the brief's chip is not used.
- **Looking up ends.** "Looking up your folder…" (spinner, skeleton path, not a button) lasts at most 10 s; then the row reads "Runs in the server's default folder" without a path and becomes tappable. The picker's "Loading projects…" skeleton also ends after 10 s, in the "Couldn't load your projects." banner.
- **Header line.** The open chat's title gets a second line, folder icon, "api · main" and a small chevron; the whole title area (44 pt) is the target. At accessibility text sizes the line leaves the bar and becomes a full-width row directly under it, so the bar keeps one line of title.
- **Details.** "Working folder": rows Folder, Path (full, wraps, monospace, "· on your server", selectable, and shown selected on the Mac where ⌘C copies it), Branch and Project (each left out when unknown); an outlined "Change folder…" (it only opens the picker); the footnote. A disabled button always has its reason under it, with an icon, linked as its description: "Wait for the reply to finish.", "You're offline.", "Changing the folder…", "Checking the folder…". A server without the move shows no button. A conversation window shows the details from its own toolbar folder button, with no button and the footnote "To change it, use the main window."
- **Picker.** `SettingsScaffold` inside `showAdaptiveSheet`: Cancel (iOS) or close X (Material) leads, "Choose a folder" over "On your server", More (holding "Look for projects on your server" only when `scan_enabled`). Sections: Server default (its project name joins the meta, "Server default · Demo"), Projects (project name as title, folder label as meta, path as subtitle), Recent (chat count as meta), "Somewhere else" (Browse, Type). Rows are `GroupedChoiceRow`, so iOS and the Mac show a trailing check and Material a radio. On the Mac the dialog adds a Cancel button at its foot, because the Mac bar has no Cancel; iPad and wide Android keep the bar's. Search stays a filter: Server default and "Somewhere else" never disappear, and "No projects or folders match “…”" names the query.
- **Offline picker.** A neutral `Banner` (the shared Banner's neutral tone), Server default selected, Browse and Type shown disabled.
- **Scan.** While scanning a `BusyBar` sits under the bar and the list stays usable; found folders join Recent with the meta "New"; the outcome is a toast ("Found 3 new folders.", "No new folders found."). No answer in 10 s: the bar stops and the toast says "Couldn't finish looking for projects. Try again."; the list keeps what it had and nothing is requested again by itself.
- **The three meanings of a 403.** (1) Permission: EACCES (a 200 with `error`, or an SSH profile's 403) on any level says "Couldn't open this folder" / "Hermes isn't allowed to read it." and keeps "Use" enabled for that folder. (2) The managed boundary on a later level (going up past the allowed root) says "This folder is outside what this server lets you browse" / "Go back up, or type a path instead." with "Use" disabled; Browse stays for the visit. (3) The boundary on the first read hides Browse for the visit and the "Somewhere else" footer says "This server only lets you browse its own folders. Choose a project or type a path." The app tells (2) and (3) apart from (1) by the detail text "outside the managed read boundary".
- **Browse.** Pushed inside the sheet with a back button labelled "Choose"; breadcrumb under the bar (collapses to "… / me / code" on a phone; every segment at least 44 pt, 28 pt on the Mac); "Back up one folder" with the parent's name as subtitle (absent at `/`); folder rows; a pinned filled "Use “code”" that names the current folder (disabled only for a missing level or one outside the boundary). Opening a level shows skeleton rows and "Opening code…"; after 10 s it becomes "Couldn't open this folder" with Try again.
- **Type a path.** One outlined monospace field, "Folder on your server". Errors sit under the field in the error style; information ("No folders start with this.", "Folder found.", the locked-server note) in the helper style. "Checking…" lasts at most 10 s, then "Couldn't check this folder." with "Check again"; "Use this folder" stays disabled and nothing is resent by itself.
- **Confirmation.** `showConfirmDialog`: title, body, then a blank line and "<path> · on your server". Apple: Cancel bold and default, "Change folder" plain. Material: two text buttons, Cancel first. Never filled and never red: nothing is deleted, but the agent will act somewhere else.
- **Move outcomes** live in the details as a `Banner` above the rows: neutral "Changing the folder to other…" with a spinner on the Folder row; success "Folder changed to other" / "New messages run there. Earlier messages and files stay where they were."; error "That folder doesn't exist on your server." / "This chat still runs in api." (4017); error "Couldn't change the folder." with Try again (5007, the server said no, so a second send is the person's own); neutral "Couldn't change the folder. Checking…" for a lost answer while the row is re-read; after 10 s without that answer, warning "Couldn't confirm the change" / "This chat may already run in other. Check again before you change it." with "Check again" (a re-read), and "Change folder…" enabled again. Nothing is ever resent by the app.
- **Current folder.** In a move the chat's folder is a checked row whose meta ends in "Current"; when it is in no list it is added at the top of Projects (or of Recent, with no project).
- **Mismatch notice.** `FolderMismatchNotice` sits once between the first prompt and its reply: a bordered surface card, warning icon, the first sentence bold, the explanation, and a text button "Choose another folder". Not tinted, not dismissible.
- **Mac.** A titled toolbar button (folder icon, folder name, chevron; 28 pt; tooltip with the path) before New Chat opens the picker as a dialog on a new chat and the details on an open chat. "Change Folder…" sits after "Rename…" in the thread and sidebar row menus; while that chat replies it is shown disabled (menus keep their shape), and it is hidden only when the server lacks the move.
- **Chat list.** The folder grouping stays by repository root, as `chat-folder-grouping` has it; grouping the list by project needs the project tree, which this change leaves out. A header that shows a path (two folders with one basename) is cut in the middle, like every path in this feature.
- **Largest text.** Designed at iOS AX5 (body 53 pt, footnote 44 pt) with no cap: the row's name wraps, chips stack, paths wrap in full instead of being cut, "on your server" takes its own line, detail rows stack label over value, and the sheets scroll.

Corrections where this brief did not work:

- Screen 1: a full-width row instead of a `ComposerSelectorChip` (see above). The confirmation is `showConfirmDialog` (`AppAlertDialog`), the repository's name for what this brief calls `AdaptiveDialog`.
- Screen 3: the picker leads with Cancel (iOS) or a close X (Material), the platform's way to leave a sheet, rather than an unnamed "Close button". The scan's empty outcome is "No new folders found.", as the spec has it, not "No new repositories found." ("repository" is a word this feature avoids).
- Screen 4: "Use this folder" names the folder ("Use “code”") and is disabled for a missing level or one outside the boundary; "always enabled" would offer a folder that cannot be used.
- Screen 6: "Change folder" is a plain action, neither the filled primary nor red; Cancel is the default.
- Thread list: the Mac menu item is disabled while the chat replies (as the brief said) and hidden only on an old server.

Copy added by the design: "Somewhere else" (section header), "Server default · Demo" (meta), "Current" and "New" (row meta), "Runs in the server's default folder", "Opening code…", "This folder is outside what this server lets you browse", "Go back up, or type a path instead.", "It may have been moved or deleted. Go back up one folder.", "Check your connection, then try again.", "No projects or folders match “zzz”", "Pick another profile for this chat.", "No folders start with this.", "Folder found.", "This server doesn't let the app check folders. If Hermes starts somewhere else, the chat says so.", "Couldn't check this folder." with "Check again", "Couldn't finish looking for projects. Try again.", "Changing the folder to other…", "New messages wait until this is done.", "Folder changed to other", "New messages run there. Earlier messages and files stay where they were.", "This chat still runs in api.", "Hermes didn't answer, so the app is reading which folder this chat uses now. Nothing is sent again.", "Couldn't confirm the change", "This chat may already run in other. Check again before you change it.", "Changing the folder…", "Checking the folder…", "Hermes runs commands and edits files in this folder. To change it, use the main window."

## Components to reuse

`showAdaptiveSheet` (sheet on phone, dialog on Mac and wide windows), `GroupedListView` / `GroupedSection` / `GroupedRow` and `GroupedChoiceRow` (selection rows with a check), `SettingsSearchField`, `StateMessage` (loading, empty, error), the shared `Banner` (neutral, success, warning and error tones), `BusyBar`, `LoadingSkeleton`, `MacToolbar` buttons, `showConfirmDialog` for the confirmation, `AdaptivePopupMenuButton` for the thread menu item, `ProfileAvatar` is not used here. Folder icon from `app_icons.dart` (add a folder and a git-branch glyph if missing; they must work in both themes and at 2.0 text scale).

## Screen 1: the folder row on a new chat

Purpose: show the folder the first message will run in, and make changing it one tap.

- Content hierarchy: (1) folder name, bold, "Runs in demo"; (2) "/home/me/code/demo · on your server", secondary text, middle-truncated; (3) branch chip "main" when known; (4) "Server default" tag while nothing was picked; project name tag ("Demo") when the folder belongs to one; (5) a chevron.
- Position: directly above the composer card, full width of the composer, one row, 44 pt minimum, so it is seen before typing. On a phone with the keyboard open it stays above the composer.
- The home-folder case adds a second line in the warning colour with an icon (not colour alone): "This is your server's home folder, which holds many projects."
- States: server default (tag "Server default"); picked (tag shows the project name or nothing); loading the default ("Looking up your folder…", skeleton path); unsupported or unknown (row hidden); offline (row keeps the last known folder, subtitle "Offline"); mismatch afterwards is a transcript notice (screen 6), not the row.
- Primary action: tap to open the picker. While the lookup runs the row says "Looking up your folder…" and is not tappable. No destructive action.
- Differences: iPhone full-width row above the composer. iPad and desktop width: same row aligned to the composer's column. Mac: the same row, and the folder also appears as a toolbar button (folder icon + name) that opens the picker as a dialog.

## Screen 2: the folder line and details in an open chat

Purpose: always know where this chat runs.

- Header: a second line under the chat title, secondary text, "demo · main" (folder name, branch). Tap opens details. Not shown when no folder data exists.
- Details (sheet on phone, popover-sized dialog on iPad and Mac): title "Working folder"; rows: Folder (name), Path ("/home/me/code/demo/api · on your server", selectable text, full length, wraps), Branch, Project (name, only when one matches); primary button "Change folder…" (disabled with the reason "Wait for the reply to finish" while a reply runs; hidden when the server cannot move chats); a footnote "Hermes runs commands and edits files in this folder."
- Differences: phone and compact-width iPad: bottom sheet, medium detent; wide windows and Mac: dialog from the toolbar button. A conversation window shows these details without "Change folder…".

## Screen 3: the picker

Purpose: choose a folder with the fewest taps; typing is the last resort.

- Title "Choose a folder"; subtitle "On your server". Cancel (iOS) or close X (Material) leads; on the Mac a Cancel button at the dialog's foot; no Done (a tap on a row picks and closes).
- Order: Server default row (folder name, path, "Server default", check when selected); section "Projects" (project name as the row title, folder label or last path segment as the subtitle, primary folder first, a check on the selected one); section "Recent" (folder name, path, "12 chats"); then a section with two rows: "Browse folders on your server" and "Type a path".
- Search field at the top only when more than eight rows exist: placeholder "Search projects and folders".
- Trailing action in the bar: "Look for projects on your server" as an overflow item (only when the server can scan), result toast "No new folders found." or "Found N new folders."; no answer in 10 s: "Couldn't finish looking for projects. Try again."
- Empty: "No projects or recent folders yet. Browse your server or type a path." with the two rows below it.
- Loading: Server default row live, the other sections as labelled skeleton rows ("Loading projects…").
- Partial failure: banner "Couldn't load your projects. You can still browse or type a path." with "Try again".
- Offline: banner "You're offline. Connect to choose a folder on your server."; Server default selected.
- Unknown profile: "This profile no longer exists on your server."
- Differences: phone sheet full height with large detent; iPad/Mac/desktop dialog 480 pt wide, list scrolls, search field focused on open on desktop and Mac, Return picks the focused row, Escape closes. Android: Material 3 sheet.

## Screen 4: browse folders on your server

Purpose: find a folder by walking down from a known place.

- Title "Browse folders"; breadcrumb under it (tappable segments, scrolls to the end; on a phone it collapses to "… / code / demo"); list of folders only (folder icon, name, chevron); a "Back up one folder" row at the top except at "/"; bottom primary button "Use “<folder>”" naming the current folder; enabled except for a missing level or one outside the boundary.
- States: loading (skeleton rows, "Opening <folder>…" announced), empty ("No folders here."), unreadable ("Couldn't open this folder. Hermes isn't allowed to read it."), missing ("This folder doesn't exist on your server."), generic error ("Couldn't open this folder." with Try again), locked server: the Browse row on screen 3 is not shown, and the message "This server only lets you browse its own folders. Choose a project or type a path." appears there.
- Never shown: a create-folder action, a file list, a device picker.
- Differences: phone pushes within the sheet with a back button; desktop and Mac keep the breadcrumb and list in the dialog with arrow-key navigation and Return to open.

## Screen 5: type a path

Purpose: the fallback when the folder is not listed.

- Title "Type a path"; one text field labelled "Folder on your server", placeholder "/home/you/code/project"; monospace, URL keyboard, autocorrect and capitalization off; clear button.
- Suggestions list under the field (folder icon, display name, path) updating as the user types; tapping one fills the field with it and a trailing "/" so the next level appears.
- Text must start with / or ~ (otherwise "Start with / or ~"); when 30 suggestions came back show "Keep typing to narrow the list." under them. Primary button "Use this folder": disabled until the path exists; field message while checking "Checking…", when missing "This folder doesn't exist on your server.", when unreadable "Hermes isn't allowed to read this folder."
- Differences: phone keyboard-aware sheet, the primary button sits above the keyboard; desktop: Tab moves field, suggestions, button; Down arrow enters the suggestions.

## Screen 6: change the folder of an existing chat

- Reuses the picker with the current folder marked "Current".
- Confirmation after a pick: title "Change the folder for this chat?"; body "Hermes will use <folder name> for new messages. Earlier messages and files stay where they are, and nothing is moved or copied."; the path "<path> · on your server" under the body; actions "Cancel" (default focus, bold on Apple) and "Change folder" (a plain action: not filled, not red; on Android both are text buttons, Cancel first). Phone: an alert on iOS, a dialog on Android; Mac: a sheet-style dialog.
- Failure messages in the same sheet: "That folder doesn't exist on your server." and "Couldn't change the folder." with Try again; lost answer "Couldn't change the folder. Checking…" then the result, or after 10 s without it "Couldn't confirm the change" with "Check again"; nothing is resent. The failures show in the details sheet (Design (done), Move outcomes).

## Screen 7: transcript notice when Hermes used another folder

- A system notice row in the transcript, warning icon plus text, not dismissible by colour alone: "Hermes started in api instead of other. The folder may not exist on your server, or this profile may use its own folder." One action: "Choose another folder". Appears once, at the point where the chat was created.

## Thread list and Mac sidebar

- The folder grouping headers use the same folder labels as the header line. Mac thread and sidebar row menus gain "Change Folder…" (disabled while the chat replies; hidden when unsupported). No new sidebar destination in this change.

## Accessibility and motion

- All targets 44 pt (48 dp). Screen reader label for the row and line ("Folder: …", not "working directory"): "Folder: demo, /home/me/code/demo on your server, branch main, button". Selected rows say "selected". Contrast AA in both themes; the home-folder note and mismatch notice use an icon plus text. Text scales to the largest size: names wrap to two lines, the path middle-truncates with the full path in details. Reduced motion: no slide, no breadcrumb scrolling animation.
