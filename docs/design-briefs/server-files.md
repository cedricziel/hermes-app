# Design brief: Files (change `server-files`)

For the visual design pass. Read `openspec/changes/server-files/design.md` for what the server gives us. This brief says what each screen is for, what to show first, what to reuse and the exact words. Copy is plain, sentence case, and never uses Hermes' internal words (`cwd`, `managed`, `fs`, `read-text`).

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
- **Mac menu bar**: View > Show Files (chord to be chosen so it does not collide with `menu_layout.dart`).
- Not shown at all on a server that does not support it.

## Screen 1: Folder

**Purpose:** find the file the agent wrote.

**Hierarchy:** (1) the list of this folder; (2) where I am (path bar); (3) how to go up.

- Title: the folder's name. Subtitle: the profile's name and the count, "work · 14 items". On the Mac the toolbar holds Back, the path bar, Refresh and a Show hidden files toggle.
- **Path bar**: a horizontal row of segments from the highest folder to here (`project › reports › 2026`), each a button; the last is not tappable; scrolls and keeps the current segment visible; long segment names elide in the middle. On phones it sits under the title; on the Mac in the toolbar.
- **Row** (`FileRow`, 44 pt minimum): icon by type (folder, text, code, image, PDF, archive, generic), name (up to two lines, middle elision keeps the extension), no size or date (the server does not send them). Folders end with a chevron. A secret-looking file has a lock icon after the name and the hint "May contain secrets" as its subtitle. iOS: no swipe actions in this change. Mac: hover shows nothing extra; selection is the system selection colour.
- **Menu** (…): Show hidden files (checkmark when on), Refresh.
- Pull to refresh on touch; Up is the Back control on phones (back to the previous folder) and an Up button in the path bar on wide layouts.
- Primary action: open the row. There is no second primary action on this screen.

**States and copy**

- Loading: skeleton rows and the label "Loading folder…".
- Empty: icon folder, title "Nothing here yet", body "Files the agent writes in this folder appear here.", action "Refresh". If hidden files exist: body adds "Hidden files are not shown." and the action "Show hidden files".
- Long list: after 2,000 rows a footer "Showing the first 2,000 of 5,310."
- Unreachable: "Can't reach your Hermes server." action "Try again".
- Folder gone: "This folder no longer exists." action "Go up".
- No permission: "Hermes can't read this folder."
- Fixed-folder deployment: "Hermes only shares files from a fixed folder on this server."
- Offline: same as unreachable; files already downloaded still open.

**Platform differences**

- iPhone: full page, Back returns to the previous folder, then to the chat. Large title off (the path bar needs the room).
- iPad (700 pt and up) and desktop (900 pt and up): list on the left, preview on the right; with nothing selected the right pane says "Select a file to preview it."
- Mac: Mac toolbar, keyboard (arrows, Enter to open, ⌘↑ up, Space Quick Look, ⌘R refresh), rows are Quick Look targets and drag out to Finder.
- Android: Material bar, system back goes up one folder, then closes the page.

## Screen 2: Preview

**Purpose:** see what is in the file, or get it onto this device.

**Hierarchy:** (1) the content; (2) the file's name and size; (3) Save and Share.

Header: name (two lines at most, extension kept), then "Python · 1.8 KB" (type word, size; size appears once known). Actions in the bar or toolbar: Save, Share (iOS and Android only), and a menu with Open with…, Reload, and Copy name. Save is the one primary action (filled on the other-file screen).

By kind:

- **Text and code**: monospace, selectable, wrapping on, no line numbers; code coloured, in both themes at AA contrast. Truncated: a note bar above the text, "Showing the first 512 KB of 3.2 MB." with the action "Download full file".
- **Markdown**: rendered, with a segmented control Rendered / Source.
- **Image**: fitted, pinch and pan, double tap to zoom; a checkerboard under transparency; background follows the theme.
- **PDF**: no inline render. Centered document icon, name, "PDF document · 2.4 MB", primary button "Open". On iOS and Mac it opens Quick Look; on others the system viewer.
- **Other file**: icon by type, name, "ZIP archive · 12 MB" (size once the headers are known; before that "Checking size…"), primary "Save", secondary "Open with…" and, on phones, "Share". Nothing downloads until one is pressed.

**States and copy**

- Downloading: progress bar with "Downloading… 14 of 30 MB" and a Cancel button. Unknown length: no bar, "Downloaded 12 MB". Respects reduced motion (no animated shimmer).
- Size question (alert on Mac and iPad, bottom sheet on phones): title "Download this file?", body "This file is 212 MB.", buttons "Download" and "Cancel".
- Secret question (alert on all): title "Show this file?", body "This file may contain passwords or keys.", buttons "Show" and "Cancel". Cancel leaves the list as it was.
- Failures (in the content area, with an icon and one action): "Hermes doesn't share this file.", "This file no longer exists.", "This file is in use by Hermes right now. Try again in a moment." (action "Try again"), "This file is too large to open here.", "This isn't a regular file.", "Couldn't open this file." (action "Try again").
- Cancelled: back to the file's details with no error text.

**Platform differences**

- iPhone: pushed full page; actions in the nav bar (Share, Save as icons with labels in the menu).
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
