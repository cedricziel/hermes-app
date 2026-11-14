# Design brief: Files (change `server-files`)

For the visual design pass. Read `openspec/changes/server-files/design.md` for what the server gives us. This brief says what each screen is for, what to show first, what to reuse and the exact words. Copy is plain, sentence case, and never uses Hermes' internal words (`cwd`, `managed`, `fs`, `read-text`).

## Design (done)

Claude Design canvas "Hermes: Server files", built on the Hermes App design system: https://claude.ai/artifact/LdWtNMYN1ZhCzZwDJCHXYg (private; ask its owner for access). 59 artboards: entry points (chat menu, Activity "This session", Mac View menu); the folder on iPhone (top, nested, empty, empty with hidden files, hidden files and secrets, long names, the 2,000 cap, the server's folder, page menu, About this list); folder loading and failures (loading, unreachable, offline after a listing, gone, no permission, fixed-folder server, workspace down, link outside); the folder in dark, at the largest text, on Android (light, dark), iPad and Mac; previews by type (text, code, Markdown rendered and source, image, PDF, other file, truncated, too large) and the code palette; download, size and secret questions, saved, incomplete; the five file failures; previews in dark, at the largest text, on Android (with menu, size sheet, secret dialog), iPad, Mac and the Mac size alert. Where this brief and the canvas differ, the sections above have been brought in line with the canvas.

Decisions taken in the design pass:

- Path bar (`FilePathBar`): a strip under the bar (phones) or under the toolbar (iPad, Mac). Ancestors are link-coloured text buttons, the current folder is semibold and not a button, chevrons separate them. A segment longer than 24 characters is elided in the middle. A long path shows its end, with a fade at the start; it scrolls back. Wide layouts start the strip with an Up button (⌘↑ on the Mac), disabled at the highest folder. Targets 44 pt (Apple touch), 48 dp (Material), 28 pt (Mac).
- Full path: the first line of the … menu is the full path (an info row, not a button), followed by Copy path. On the Mac each segment's tooltip is its full path.
- Page menu order: full path, Copy path, divider, Show hidden files (checkmark when on), Refresh, About this list. About this list is an alert with OK.
- File row (`FileRow`): type icon (folders filled in the link colour, files outlined in the muted colour), name up to two lines then elided in the middle keeping the extension, folders end with a chevron, files have none. Secret-looking files: a lock glyph after the name and the line "May contain secrets". Heights: 44 pt iPhone and iPad, 56 dp Android, 32 pt Mac. One `GroupedSection`, folders first, then files, both sorted case-insensitively as the server sends them.
- Loading: eight still skeleton rows (no shimmer, so reduced motion needs no variant) under a spinner and "Loading folder…".
- Offline: on first open, the `StateMessage` "Can't reach your Hermes server." with Try again. A refresh that fails after a listing keeps the list under a warning banner, "Can't reach your Hermes server." / "This list may be out of date." with Try again, so files already downloaded still open.
- Folder failures: Gone has Up (Try again at the highest folder); no permission has Up; the fixed-folder server has no action; workspace down has Try again; a link outside the folder has Go back. All are `StateMessage`s with an icon, never colour alone.
- The server's folder for a new chat: the shared neutral note (the one planned as `ActivityInfoNote`; Files reuses it and adds none of its own) above the list. The truncated-text note uses the same note with a text button.
- Preview on phones: the bar title is the file's name elided in the middle (the full name is in the details view and the screen-reader label), the subtitle "type · size". Content views (text, code, Markdown, image, PDF) carry Share and Save in the bar on iPhone and Save, Share, ⋮ on Android; Reload is pull down on touch and the menu elsewhere.
- Preview pane on iPad and Mac (`FilePreviewHeader`): a 44 pt (Mac 32 pt) tile with the type icon, which is the drag-out handle on the Mac, the name in two lines, "type · size", then the actions: Share, Save, … on iPad (44 pt); Quick Look, Save, … on the Mac (32 pt).
- Details view (`FileDetailsView`, PDF, other file, too large): a 56 pt icon, the name (wrapping), "type · size", an optional note line, then one filled button (Open for a PDF, Save otherwise) and outlined secondaries stacked at full width (at most 320 pt).
- Downloads (`FileDownloadProgress`): a `BusyBar` with a value, "Downloading… 14 of 30 MB" and a text Cancel; without a length a spinner, "Downloaded 12 MB" and Cancel. Both are live regions.
- Saved: after the system save dialog a snack bar "Saved export.zip." Share and Open with… show nothing afterwards; the system sheet is their answer.
- Questions: the size question is a bottom sheet on phones (the sentence, Cancel as text, Download filled) and an alert on iPad and the Mac (the sentence as the title, Download the default). The secret question is an alert titled with the file's name; Cancel is the default; on Android a Material dialog with two text buttons, Cancel first.
- Code colours: six proposed tokens, `--h-code-keyword`, `-string`, `-comment`, `-number`, `-function`, `-type`, light #a626a4, #0b6e2f, #5f6670, #a3480b, #1d4ed8, #8a5a00 and dark #e08ef0, #7ee2a8, #a1a1aa, #fdba74, #93c5fd, #fcd34d. Each is at least 5.2:1 on `--h-bg` and `--h-surface-high` in its theme; comments are italic as well. Text and code use 13 pt monospace (12 pt Mac), 20 pt lines, wrapping without a hanging indent.
- Markdown: Rendered / Source is the page's segmented control (`SettingsScaffold` tabs on phones, a centred compact control in the pane).
- Image: fitted with a 16 pt margin; the checkerboard is drawn only inside the picture's bounds; the page background follows the theme.
- Entry points: "Files" (folder icon) leads the chat's … menu, above a divider and the thread actions. The Activity row is a `GroupedRow` with the folder icon, "Files", the folder's name as value and a chevron.

Corrections where this brief did not work:

- Mac toolbar: `SettingsScaffold`'s Mac toolbar has no slot for the path bar, and its buttons cannot show an on state, so the path bar moved to a strip under the toolbar and Show hidden files is a checked item in the … menu.
- Mac selection: the system accent clashed with every other list in the app; rows use the design system's selected fill.
- iPhone bar: Save, Share and a menu with Open with… and Reload left the centred title about 110 pt. On iOS Open with… is the share sheet anyway, so the bar keeps Share and Save, and Reload is pull down.
- 413: the brief gave both "This file is too large to open here." and "shows as an other file with Save". Merged: the details view with that sentence as its note line, Save filled, Share (phones) and Open with… (Android, desktop).
- Empty with hidden files: "Show" alone is unclear out of context; the action reads "Show hidden files".
- Largest text: a single long word in a name (for example "api_token.txt" beside its lock) breaks inside the word, since nothing else fits; the canvas `Button` keeps its 15 pt label while the app's buttons scale.

Copy added by the design: "Copy path"; "Show hidden files" (empty-state action); "This chat's folder is outside it." (fixed-folder server); "The machine this profile works on didn't answer." (workspace down); "Go back" (link outside); "This list may be out of date." (offline banner); "This chat hasn't started yet, so Hermes shows the server's own folder. After your first message it shows this chat's folder." (under "Working folder of the server"); "To get one, ask the agent to attach it to a reply." (About this list); "Saved <name>."; "The file may be incomplete." with "The connection dropped while it downloaded. Nothing was kept."; Mac tooltips "Up (⌘↑)", "Quick Look (Space)", "Drag to Finder"; type words "Plain text", "Log", "Database", "File" for files without a better name.

## The job

"The agent just wrote something on the server. I want to find it, look at it, and keep a copy on this device." Everything that does not serve that is cut: no editing, no upload, no delete, no search in this change.

## What to reuse

- Page chrome: `SettingsScaffold` (iOS 44 pt bar, Mac `MacToolbar`, Material 56 dp bar) and `GroupedListView` / `GroupedRow` for the list; metrics from `GroupedMetrics.of(context)`.
- Wide layout: list beside detail, as Plugins and Memory proposals do (900 pt; 700 pt on iPad).
- Image: the chat's `image_viewer.dart` pinch and pan. Markdown: the chat's Markdown view. File actions: the actions of the attachment cards (Save, Open with…, Share), Quick Look on the Mac (`quick_look_target.dart`), drag out.
- Adaptive dialogs and sheets: `adaptive_sheet.dart`, `adaptive_dialog.dart` (alert on Mac, bottom sheet only on phones). `StateMessage` for empty and error bodies.
- The Activity panel row pattern ("This session" rows).
- New pieces to design: the path bar, the file row, the preview header, the download progress, the code view's colours (light and dark, AA contrast).

## Entry points

- **Activity panel, "This session"**: row "Files", value is the folder's name (for example "project"), chevron. iPhone: tapping closes the sheet and pushes the page. Mac and iPad: the inspector stays, the page opens in the main area.
- **Chat header menu**: item "Files" (icon: folder).
- **Mac menu bar**: View > Show Files, ⇧⌘F (free in `menu_layout.dart`; ⌃⌘F stays the system's full screen).
- Not shown at all on a server that does not support it.

## Screen 1: Folder

**Purpose:** find the file the agent wrote.

**Hierarchy:** (1) the list of this folder; (2) where I am (path bar); (3) how to go up.

- Title: the folder's name. Subtitle: the profile's name and the count, "work · 14 items". On the Mac the toolbar holds Back, Refresh (⌘R) and the … menu (with Show hidden files as a checked item); the path bar sits in a strip under the toolbar.
- **Path bar**: a horizontal row of segments from the highest folder to here (`project › reports › 2026`), each a button; the last is not tappable; scrolls and keeps the current segment visible; long segment names elide in the middle. On phones it sits under the title; on the Mac in the toolbar.
- **Row** (`FileRow`, 44 pt minimum): icon by type (folder, text, code, image, PDF, archive, generic), name (up to two lines, middle elision keeps the extension), no size or date (the server does not send them). Folders end with a chevron. A secret-looking file has a lock icon after the name and the hint "May contain secrets" as its subtitle. iOS: no swipe actions in this change. Mac: hover shows nothing extra; selection uses the design system's selected-row fill, as Plugins and Skills do.
- **Menu** (…): Show hidden files (checkmark when on), Refresh.
- Pull to refresh on touch; Up is the Back control on phones (back to the previous folder) and an Up button in the path bar on wide layouts.
- Primary action: open the row. There is no second primary action on this screen.

**States and copy**

- Loading: skeleton rows and the label "Loading folder…".
- Empty: icon folder, title "Nothing here yet", body "Files the agent writes in this folder appear here.", action "Refresh". If hidden files exist: body adds "Hidden files are not shown." and the action "Show hidden files".
- Long list: after 2,000 rows a footer "Showing the first 2,000 of 5,310."
- Unreachable: "Can't reach your Hermes server." action "Try again".
- Folder gone: "This folder no longer exists." action "Up".
- No permission: "Hermes can't read this folder."
- Workspace down (503): "Can't reach this profile's workspace." action "Try again"
- Outside folder: "This folder is outside this chat's folder."
- Fixed-folder deployment: "Hermes only shares files from a fixed folder on this server."
- Offline: same as unreachable; files already downloaded still open.

**Platform differences**

- iPhone: full page, Back returns to the previous folder, then to the chat. Large title off (the path bar needs the room).
- iPad (700 pt and up) and desktop (900 pt and up): list on the left, preview on the right; with nothing selected the right pane says "Select a file to preview it." (also a spec scenario)
- Mac: Mac toolbar, keyboard (arrows, Enter to open, ⌘↑ up, Space Quick Look, ⌘R refresh), rows are Quick Look targets and drag out to Finder.
- Android: Material bar, system back goes up one folder, then closes the page.

## Screen 2: Preview

**Purpose:** see what is in the file, or get it onto this device.

**Hierarchy:** (1) the content; (2) the file's name and size; (3) Save and Share.

Header: name (two lines at most, extension kept), then "Python · 1.8 KB" (type word, size; size appears once known). Actions in the bar or toolbar: on iPhone Share and Save (Open with… is the share sheet there, and Reload is pull down); on Android Save, Share and ⋮ (Open with…, Reload); in the iPad pane Share, Save and … (Open with…, Reload); on the Mac Quick Look, Save and … (Open with…, Reload). The page menu also has "About this list" (why build folders and config.yaml are missing). Save is the one primary action (filled on the other-file screen).

By kind:

- **Text and code**: monospace, selectable, wrapping on, no line numbers; code coloured, in both themes at AA contrast. Truncated: a note bar above the text, "Showing the first 512 KB of 3.2 MB." with the action "Download full file".
- **Markdown**: rendered, with a segmented control Rendered / Source.
- **Image**: fitted, pinch and pan, double tap to zoom; a checkerboard under transparency; background follows the theme.
- **PDF**: no inline render. Centered document icon, name, "PDF document · 2.4 MB", primary button "Open". On iOS and Mac it opens Quick Look; on others the system viewer.
- **Other file**: icon by type, name, "ZIP archive" (no size until the user presses an action), primary "Save", secondary "Open with…" (Android and desktop) and, on phones, "Share". On iPhone that is Save and Share only. Nothing downloads until one is pressed.

**States and copy**

- Downloading: progress bar with "Downloading… 14 of 30 MB" and a Cancel button. Unknown length: no bar, "Downloaded 12 MB". Respects reduced motion (no animated shimmer).
- Size question (alert on Mac and iPad, bottom sheet on phones): the sentence "This file is 212 MB. Download it anyway?" (the alert's title; the sheet's text), buttons "Cancel" and "Download" (the default).
- Secret question (alert on all): title the file's name, message "This file may contain passwords or keys. Show it anyway?", buttons "Cancel" (the default) and "Show"; on Android two text buttons, Cancel first. Cancel leaves the list as it was.
- Failures (in the content area, with an icon and one action): "Hermes doesn't share this file.", "This file no longer exists.", "This file is open in a database right now. Try again in a moment." (action "Try again"), "This item can't be opened as a file.", "Couldn't open this file." (action "Try again"). "This file is too large to open here." is not a failure view: it is the note line of the other-file details (see Design (done)).
- Cancelled: back to the file's details with no error text.

**Platform differences**

- iPhone: pushed full page; Share and Save as icons in the nav bar; the title is the name elided in the middle, the subtitle "Python · 1.8 KB".
- iPad and desktop: the pane beside the list; actions in its header.
- Mac: Space opens Quick Look from the list; the preview file can be dragged out from its header icon; Save opens the Mac save panel; no bottom sheets, only alerts.
- Android: Material top bar; Save opens the system document picker; Share opens the share sheet.

## Accessibility (design for it from the first frame)

- Targets 44 pt (Apple) and 48 dp (Android); rows and path-bar segments included.
- Row speech: "<name>, folder" or "<name>, file", plus "may contain secrets". The lock is decoration plus text, never colour alone.
- Largest accessibility text size: names wrap to two lines, the path bar scrolls, the header stacks name above type and size, buttons go full width.
- Contrast AA in both themes, including every colour of the code palette (check keyword, string, comment, number against both backgrounds).
- Focus order on desktop: path bar, list, preview header, preview content.
- Progress and failures are announced as live regions.

## Deliverables from the design pass

Widgetbook use cases for every state above, both themes, at phone, iPad and desktop width and at the largest text size; the code palette for light and dark; the row, path bar and preview header as plain-model widgets in `lib/src/files/widgets/`.
