# Design brief: working directory and projects for a chat

Change: `openspec/changes/chat-working-directory`. Read its `design.md` for the server facts and `specs/chat-working-directory/spec.md` for the behaviour. This brief covers the look.

The person's job: **know which folder on my server the agent will work in, and point it at the right one, before it touches anything.** Hermes edits files and runs commands in that folder, so a wrong one is a real mistake. Everything below serves that, and nothing more.

Words to use: "folder", "on your server", "project", "chat". Not "cwd", "workspace", "root", "worktree", "repo root", "session". The path is always shown as "<path> · on your server", never as a file on the phone.

## Components to reuse

`showAdaptiveSheet` (sheet on phone, dialog on Mac and wide windows), `GroupedListView` / `GroupedSection` / `GroupedRow` and `GroupedChoiceRow` (selection rows with a check), `SettingsSearchField`, `StateMessage` (loading, empty, error), `ComposerSelectorChip` (the model pill's shape, for the composer row), `MacToolbar` buttons, `AdaptiveDialog` for the confirmation, `AdaptivePopupMenuButton` for the thread menu item, `ProfileAvatar` is not used here. Folder icon from `app_icons.dart` (add a folder and a git-branch glyph if missing; they must work in both themes and at 2.0 text scale).

## Screen 1: the folder row on a new chat

Purpose: show the folder the first message will run in, and make changing it one tap.

- Content hierarchy: (1) folder name, bold, "Runs in demo"; (2) "/home/me/code/demo · on your server", secondary text, middle-truncated; (3) branch chip "main" when known; (4) "Server default" tag while nothing was picked; project name tag ("Demo") when the folder belongs to one; (5) a chevron.
- Position: directly above the composer card, full width of the composer, one row, 44 pt minimum, so it is seen before typing. On a phone with the keyboard open it stays above the composer.
- The home-folder case adds a second line in the warning colour with an icon (not colour alone): "This is your server's home folder, which holds many projects."
- States: server default (tag "Server default"); picked (tag shows the project name or nothing); loading the default ("Looking up your folder…", skeleton path); unsupported or unknown (row hidden); offline (row keeps the last known folder, subtitle "Offline"); mismatch afterwards is a transcript notice (screen 6), not the row.
- Primary action: tap to open the picker. No destructive action.
- Differences: iPhone full-width row above the composer. iPad and desktop width: same row aligned to the composer's column. Mac: the same row, and the folder also appears as a toolbar button (folder icon + name) that opens the picker as a dialog.

## Screen 2: the folder line and details in an open chat

Purpose: always know where this chat runs.

- Header: a second line under the chat title, secondary text, "demo · main" (folder name, branch). Tap opens details. Not shown when no folder data exists.
- Details (sheet on phone, popover-sized dialog on iPad and Mac): title "Working folder"; rows: Folder (name), Path ("/home/me/code/demo/api · on your server", selectable text, full length, wraps), Branch, Project (name, only when one matches); primary button "Change folder…" (disabled with the reason "Wait for the reply to finish" while a reply runs; hidden when the server cannot move chats); a footnote "Hermes runs commands and edits files in this folder."
- Differences: phone bottom sheet, medium detent; Mac dialog from the toolbar button; iPad dialog.

## Screen 3: the picker

Purpose: choose a folder with the fewest taps; typing is the last resort.

- Title "Choose a folder"; subtitle "On your server". Close button, no Done (a tap on a row picks and closes).
- Order: Server default row (folder name, path, "Server default", check when selected); section "Projects" (project name as the row title, folder label or last path segment as the subtitle, primary folder first, a check on the selected one); section "Recent" (folder name, path, "12 chats"); then a section with two rows: "Browse folders on your server" and "Type a path".
- Search field at the top only when more than eight rows exist: placeholder "Search projects and folders".
- Trailing action in the bar: "Look for repositories on your server" as an overflow item (only when the server can scan), result toast "No new repositories found." or "Found N new folders."
- Empty: "No projects or recent folders yet. Browse your server or type a path." with the two rows below it.
- Loading: Server default row live, the other sections as labelled skeleton rows ("Loading projects…").
- Partial failure: banner "Couldn't load your projects. You can still browse or type a path." with "Try again".
- Offline: banner "You're offline. Connect to choose a folder on your server."; Server default selected.
- Unknown profile: "This profile no longer exists on your server."
- Differences: phone sheet full height with large detent; iPad/Mac/desktop dialog 480 pt wide, list scrolls, search field focused on open on desktop and Mac, Return picks the focused row, Escape closes. Android: Material 3 sheet.

## Screen 4: browse folders on your server

Purpose: find a folder by walking down from a known place.

- Title "Browse folders"; breadcrumb under it (tappable segments, scrolls to the end; on a phone it collapses to "… / code / demo"); list of folders only (folder icon, name, chevron); a "Back up one folder" row at the top except at "/"; bottom primary button "Use this folder" showing the current folder's name; it is always enabled.
- States: loading (skeleton rows, "Opening <folder>…" announced), empty ("No folders here."), unreadable ("Couldn't open this folder. Hermes isn't allowed to read it."), missing ("This folder doesn't exist on your server."), generic error ("Couldn't open this folder." with Try again), locked server: the Browse row on screen 3 is not shown, and the message "This server only lets you browse its own folders. Choose a project or type a path." appears there.
- Never shown: a create-folder action, a file list, a device picker.
- Differences: phone pushes within the sheet with a back button; desktop and Mac keep the breadcrumb and list in the dialog with arrow-key navigation and Return to open.

## Screen 5: type a path

Purpose: the fallback when the folder is not listed.

- Title "Type a path"; one text field labelled "Folder on your server", placeholder "/home/you/code/project"; monospace, URL keyboard, autocorrect and capitalization off; clear button.
- Suggestions list under the field (folder icon, display name, path) updating as the user types; tapping one fills the field with it and a trailing "/" so the next level appears.
- Primary button "Use this folder": disabled until the path exists; field message while checking "Checking…", when missing "This folder doesn't exist on your server.", when unreadable "Hermes isn't allowed to read this folder."
- Differences: phone keyboard-aware sheet, the primary button sits above the keyboard; desktop: Tab moves field, suggestions, button; Down arrow enters the suggestions.

## Screen 6: change the folder of an existing chat

- Reuses the picker with the current folder marked "Current".
- Confirmation after a pick: title "Change the folder for this chat?"; body "Hermes will use <folder name> for new messages. Earlier messages and files stay where they are, and nothing is moved or copied."; the path "<path> · on your server" under the body; actions "Change folder" (the primary, not red, since nothing is deleted) and "Cancel" (default focus). Phone: an alert on iOS, a dialog on Android; Mac: a sheet-style dialog.
- Failure messages in the same sheet: "That folder doesn't exist on your server." and "Couldn't change the folder." with Try again; lost answer "Couldn't change the folder. Checking…" then the result.

## Screen 7: transcript notice when Hermes used another folder

- A system notice row in the transcript, warning icon plus text, not dismissible by colour alone: "Hermes started in api instead of other. The folder you chose may not exist on your server." Actions: "Choose another folder". Appears once, at the point where the chat was created.

## Thread list and Mac sidebar

- The folder grouping headers use the same folder labels as the header line. Mac thread and sidebar row menus gain "Change Working Directory…" (disabled while the chat replies; hidden when unsupported). No new sidebar destination in this change.

## Accessibility and motion

- All targets 44 pt (48 dp). Screen reader label for the row and line: "Working directory: demo, /home/me/code/demo on your server, branch main, button". Selected rows say "selected". Contrast AA in both themes; the home-folder note and mismatch notice use an icon plus text. Text scales to the largest size: names wrap to two lines, the path middle-truncates with the full path in details. Reduced motion: no slide, no breadcrumb scrolling animation.
