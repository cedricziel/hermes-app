## ADDED Requirements

### Requirement: Files page for a chat

The app SHALL offer a Files page for a chat from the Activity panel's "This session" section, the chat header's menu and, on macOS, View > Show Files, and SHALL NOT add a top-level tab. The page SHALL list the chat's working folder (the stored session's `cwd`, else `GET /api/fs/default-cwd`) with the chat's profile as `profile` on every request except the availability probe (see Old servers), folders first, with a path bar and an Up action.

#### Scenario: Open from a chat

- **WHEN** the user opens Files from the Activity panel of a chat whose stored `cwd` is `/srv/project`
- **THEN** the page lists `/srv/project` using `GET /api/fs/list?path=/srv/project&profile=…`, folders first, titled "project"

#### Scenario: New chat without a session

- **WHEN** the user opens Files in a new chat that has not been sent yet
- **THEN** the page lists the folder `GET /api/fs/default-cwd` returned

#### Scenario: Go into a folder and back

- **WHEN** the user taps the folder "reports" and then taps Up
- **THEN** the page lists `reports` using the path the server returned for that entry, and then lists its parent again

#### Scenario: Symlink to a folder

- **WHEN** an entry is listed with `isDirectory: false` and opening it answers 400 ("Path points to a directory", or "Only regular files can be read" on SSH)
- **THEN** the page tries it once as a folder, and shows "This folder is outside this chat's folder." without further requests when its path is not within the highest folder

#### Scenario: Resolved start

- **WHEN** the stored `cwd` is `/tmp/p` and the server lists entries under `/private/tmp/p`
- **THEN** the entries are shown, because the highest folder is the one the server resolved

#### Scenario: Full path

- **WHEN** the user opens the page's … menu in `/srv/projects/hermes-report/reports/2026`
- **THEN** its first line is that full path, not a button, followed by Copy path, Show hidden files (checked when on), Refresh and About this list

#### Scenario: Mac menu command

- **WHEN** a Mac user presses ⇧⌘F in a chat on a server with the routes
- **THEN** View > Show Files opens the Files page of that chat

#### Scenario: Local profile without its own folder

- **WHEN** a new chat on a local profile gets the dashboard's folder from `default-cwd`
- **THEN** the page says "Working folder of the server" above the list

### Requirement: Highest folder

The page SHALL NOT go above the chat's git root (`GET /api/fs/git-root`), or above the working folder when there is none, and Up SHALL be disabled there. The client SHALL check, by whole path components, that every path lies within that folder before requesting it, SHALL send only absolute paths the server returned, and SHALL NOT build a path by joining strings.

#### Scenario: At the git root

- **WHEN** the page shows the git root of the project
- **THEN** Up is disabled and the path bar starts at that folder

#### Scenario: A path outside

- **WHEN** an answer contains an entry whose path is not within the highest folder
- **THEN** the entry is not requested and not offered

#### Scenario: No git root

- **WHEN** the working folder is not inside a git repository
- **THEN** the working folder is the highest folder

#### Scenario: Look-alike folder

- **WHEN** the highest folder is `/srv/app` and an entry's path is `/srv/app-secrets/key`
- **THEN** the path is treated as outside

### Requirement: Hidden files and secrets

Names starting with a dot SHALL be hidden until the user turns on "Show hidden files", for that visit only. A file whose name looks like a secret (the list in design.md, matched case-insensitively) SHALL be listed with a lock icon and the words "May contain secrets", and SHALL ask, in an alert titled with the file's name, "This file may contain passwords or keys. Continue anyway?" with "Cancel" (the default) and "Continue" before any request for its content: before a preview, Save, Share and Open with…, on every profile, because Hermes skips its own check for text previews on an SSH workspace. Nothing SHALL be requested by focus, hover or selection alone.

#### Scenario: Secret-looking names

- **WHEN** the folder holds `.env`, `.envrc`, `.netrc`, `.npmrc`, `.pypirc`, `.git-credentials`, `credentials.json`, `key.pem`, `id_rsa`, `vault.kdbx`, `api_token.txt`, `.htpasswd`, `.pgpass`, `AuthKey.p8`, `release.jks`, `upload.keystore`, `office.ovpn`, `terraform.tfstate`, `prod.tfvars`, `kubeconfig`, `.docker/config.json` or a file under `.ssh/`, in any letter case
- **THEN** each is treated as secret-looking

#### Scenario: Hidden files off

- **WHEN** the folder contains `.gitignore` and `notes.md` and Show hidden files is off
- **THEN** only `notes.md` is listed

#### Scenario: Secret file

- **WHEN** the user taps `.env.local` with hidden files shown
- **THEN** the question appears as an alert titled ".env.local" with Cancel as the default, and nothing is requested until the user chooses Continue; Cancel requests nothing

#### Scenario: Secret file saved

- **WHEN** the user chooses Save, Share or Open with… on `id_rsa`
- **THEN** the same question is asked first, and nothing is downloaded until Continue

#### Scenario: Server refuses

- **WHEN** the user chooses Continue and Hermes answers 403 "Access to sensitive files is not allowed"
- **THEN** the page says "Hermes doesn't share this file."

### Requirement: Text, code and Markdown preview

A text file (a known extension, or a `language` the server names) SHALL be read with `GET /api/fs/read-text` and shown monospace, selectable and wrapped, with its size from `byteSize`. A `binary` file SHALL be treated as an other file. A `truncated` file SHALL say so and offer "Download full file". Code SHALL be coloured by the server's `language` when the app has a grammar, plain otherwise; Markdown SHALL be rendered with a Source toggle. Preview text SHALL NOT be logged.

#### Scenario: Python file

- **WHEN** the user opens `app.py` and the server answers `language: "python"`, `byteSize: 1834`, `truncated: false`
- **THEN** the code is shown with Python colours and the header says "1.8 KB"

#### Scenario: Large text

- **WHEN** `read-text` answers `truncated: true` for a 3.2 MB log
- **THEN** the view shows the first part, "Showing the first 512 KB of 3.2 MB." and Download full file

#### Scenario: Markdown

- **WHEN** the user opens `report.md`
- **THEN** it is rendered, and the Source toggle shows the Markdown text

#### Scenario: Binary after all

- **WHEN** a file named `data.txt` comes back with `binary: true`
- **THEN** it is shown as an other file with Save and Open with…

### Requirement: Inert Markdown and markup

A rendered Markdown file SHALL NOT fetch anything from the network: an image element SHALL show its alt text, or "Image not loaded" when it has none. A link SHALL open only after a confirmation that names its host ("Open example.com?" with Cancel and Open), through the app's link handler (`markdown_links.dart`). Relative links and relative images SHALL be inert. HTML in Markdown, and HTML and SVG files, SHALL be shown as text, never as active content.

#### Scenario: Remote image in Markdown

- **WHEN** `report.md` contains `![chart](https://example.com/c.png)`
- **THEN** the rendered view shows "chart" in place of the image and no request is made to example.com

#### Scenario: Link in Markdown

- **WHEN** the user taps a link to `https://example.com/page` in a rendered file
- **THEN** a confirmation names "example.com" and the link opens only after Open

#### Scenario: Relative link

- **WHEN** a rendered file links to `./notes.md` or shows `![](img/a.png)`
- **THEN** the link does nothing and the image shows its alt text or "Image not loaded"

#### Scenario: HTML file

- **WHEN** the user opens `page.html` or `logo.svg`
- **THEN** its source is shown as text and nothing in it runs or loads

### Requirement: Image and PDF preview

An image file (png, jpg, jpeg, gif, webp, bmp, svg) SHALL be downloaded to the cache and shown with pinch and pan, decoded at the size drawn. A PDF SHALL be downloaded and opened in Quick Look on iOS and macOS, and in the system's viewer elsewhere; its preview screen SHALL show the name, "PDF document", the size and the primary action Open. A file that finished downloading SHALL NOT download again until sign-out or App Lock unless the user chooses Reload, except on an SSH workspace, where it downloads again on each open.

#### Scenario: SVG

- **WHEN** the user opens `logo.svg`
- **THEN** its text is shown with the Source view, since the app has no SVG renderer

#### Scenario: Image

- **WHEN** the user opens `chart.png`
- **THEN** a progress indicator shows while it downloads, then the picture appears and can be pinched

#### Scenario: PDF on iPhone

- **WHEN** the user taps Open on `report.pdf`
- **THEN** it opens in Quick Look

#### Scenario: Reload

- **WHEN** the user chooses Reload on a file the agent has rewritten
- **THEN** the cached copy is deleted and the file downloads again

### Requirement: Refresh and Reload without a gesture

Refreshing the folder and reloading a file SHALL each have a path that is not a gesture on every platform: Refresh in the folder's … menu (and the Mac toolbar, ⌘R), Reload in the preview's menu. Pull to refresh SHALL be an extra on touch, never the only way.

#### Scenario: Reload on iPhone

- **WHEN** the user opens the preview's … menu on an iPhone
- **THEN** it offers Reload, under a first line with the file's full name

### Requirement: Other files

A file that is neither text, an image nor a PDF SHALL show its name, its type, its size (once the headers are known) and the actions Save (the one filled action), Open with… on Android, macOS, Windows and Linux, and Share on iOS and Android. On iOS the share sheet stands in for Open with…. The app SHALL NOT download it before one of those actions is chosen.

#### Scenario: Archive

- **WHEN** the user opens `export.zip`
- **THEN** the page shows the name, "ZIP archive" and Save with Share on iPhone, Save with Open with… and Share on Android, or Save with Open with… on a Mac, and no download has started

### Requirement: Save, share and open

Save SHALL open the system's save dialog with the file's name, as the file cards do. Share SHALL open the share sheet on iOS and Android. Open with… SHALL open the file with the system's app. All three SHALL use a file staged through `MediaStore` and SHALL NOT read it into memory. On macOS a file row and the preview's file SHALL be Quick Look targets (Space) and SHALL drag out to Finder through the existing drag-out code.

#### Scenario: Save

- **WHEN** the user chooses Save on `export.zip`
- **THEN** the file downloads, then the save dialog opens with "export.zip"

#### Scenario: Saved

- **WHEN** the save dialog for `export.zip` closes with a destination
- **THEN** a snack bar says "Saved export.zip."; after Share or Open with… nothing more is shown

#### Scenario: Quick Look on a Mac

- **WHEN** the user selects a file row and presses Space
- **THEN** the system Quick Look panel shows the file

#### Scenario: Drag out

- **WHEN** the user drags a file row from the Mac window into Finder
- **THEN** the file is copied there, downloaded first if needed

### Requirement: Streamed, cancellable downloads

A download SHALL be written to disk as a stream, never held whole in memory, SHALL show progress and a Cancel action, and SHALL never leave a partial file that can be previewed or opened. Leaving the page, signing out or changing server SHALL cancel it. When the response headers give 50 MB or more, the app SHALL cancel and ask before downloading.

#### Scenario: Progress and cancel

- **WHEN** a 30 MB image is downloading and the user taps Cancel
- **THEN** the request ends, the partial file is deleted and the preview returns to the file's details without an error

#### Scenario: Large file

- **WHEN** the headers of `video.mov` say 212 MB
- **THEN** the app asks "This file is 212 MB. Download it anyway?" (a bottom sheet on phones, an alert on iPad and desktop, Download the default) and downloads only after Download

#### Scenario: Incomplete SSH download

- **WHEN** an SSH download ends with zero bytes for a file whose size was known to be above zero, or with a connection error
- **THEN** it is a failure, the partial file is deleted and it is not cached as complete

#### Scenario: Session ends mid-download

- **WHEN** the session expires and refresh fails during a download
- **THEN** the download is cancelled, the partial file deleted and the app's normal sign-in flow takes over

#### Scenario: Refresh during a download

- **WHEN** the user refreshes the folder while a file downloads
- **THEN** the download continues

#### Scenario: Unknown length

- **WHEN** the server sends no `Content-Length` (an SSH workspace)
- **THEN** the progress reads "Downloaded 12 MB" without a bar and Cancel works

#### Scenario: Leave the page

- **WHEN** the user goes back while a file is downloading
- **THEN** the download is cancelled and its partial file deleted

### Requirement: Empty, loading and failure states

The page SHALL show a labelled loading state, an empty state with the one action that helps, and in-place failures with a way forward; the exact words are in the scenarios. A listing answered with HTTP 200 and `error` SHALL be a failure, not an empty folder. Refresh (pull to refresh on touch, ⌘R on a Mac) SHALL list again and keep the selection if the file still exists.

#### Scenario: Empty folder

- **WHEN** the folder has no entries
- **THEN** the page says "Nothing here yet. Files the agent writes in this folder appear here." with Refresh, and adds "Hidden files are not shown." with the action Show hidden files (instead of Refresh) when hidden files exist

#### Scenario: Loading

- **WHEN** a folder is loading
- **THEN** the page shows "Loading folder…"

#### Scenario: Folder failures

- **WHEN** the folder cannot be read
- **THEN** the page says "Can't reach your Hermes server." with Try again, "This folder no longer exists." with Up, "Hermes can't read this folder." (EACCES or 403), or on a locked deployment "Hermes only shares files from a fixed folder on this server."

#### Scenario: File failures

- **WHEN** a file cannot be read
- **THEN** the page says, by status, 403 "Hermes doesn't share this file.", 404 "This file no longer exists.", 409 (from `read-text` or `download`) "This file is open in a database right now. Try again in a moment.", 400 "This item can't be opened as a file.", otherwise "Couldn't open this file." with Try again

#### Scenario: Error code in a 200

- **WHEN** `GET /api/fs/list` answers 200 with `{"entries": [], "error": "EACCES"}`
- **THEN** the page shows "Hermes can't read this folder.", not an empty folder

#### Scenario: Workspace down

- **WHEN** a profile's SSH workspace answers 503
- **THEN** the page says "Can't reach this profile's workspace." with Try again

#### Scenario: Git root fails

- **WHEN** `git-root` fails or answers null
- **THEN** the working folder is the highest folder

#### Scenario: Large folder

- **WHEN** a folder has 5,310 entries
- **THEN** the first 2,000 are shown with "Showing the first 2,000 of 5,310."

#### Scenario: Nothing selected

- **WHEN** the wide layout has no file selected
- **THEN** the preview pane says "Select a file to preview it."

#### Scenario: Too large for text preview

- **WHEN** `read-text` answers 413
- **THEN** the file shows as an other file with the note "This file is too large to open here." and Save

#### Scenario: Hidden by Hermes

- **WHEN** the user opens the page menu's About this list
- **THEN** it says Hermes leaves out build folders, config.yaml and similar files, and that Show hidden files shows names starting with a dot but not these

#### Scenario: Offline

- **WHEN** the device has no network when the page opens
- **THEN** "Can't reach your Hermes server." and Try again appear, and a file already downloaded still opens

#### Scenario: Refresh fails after a listing

- **WHEN** a folder was listed and a later refresh cannot reach the server
- **THEN** the list stays under a banner "Can't reach your Hermes server." / "This list may be out of date." with Try again, and a file already downloaded still opens

#### Scenario: Missing folder on an SSH workspace

- **WHEN** `GET /api/fs/list` answers 404 for a folder on an SSH workspace
- **THEN** the page says "This folder no longer exists.", as for a 200 with ENOENT

#### Scenario: Folder or profile not accepted

- **WHEN** `GET /api/fs/list` answers 400, or a profile-scoped call answers 400 (invalid profile name) or 404 "Profile '…' does not exist."
- **THEN** the page says "Hermes can't open this folder." with "The server didn't accept this folder or this chat's profile." and no action

#### Scenario: Gone at the top

- **WHEN** the highest folder answers ENOENT
- **THEN** "This folder no longer exists." offers Try again instead of Up

#### Scenario: Late answer

- **WHEN** the user opens folder B while folder A is still loading and A answers last
- **THEN** the page shows B

### Requirement: Old servers

Files SHALL appear only when the server has the `/api/fs` routes. The first `GET /api/fs/default-cwd` of a connection, sent without `profile` (a missing profile also answers 404), SHALL decide: a 404 or 405 means unsupported, and the Files row, menu item and menu command SHALL NOT be shown and no error SHALL be shown. The result SHALL be logged once per connection. Any other failure SHALL NOT hide the feature.

#### Scenario: Server without the routes

- **WHEN** `default-cwd` answers 404
- **THEN** the Activity panel has no Files row, the header menu has no Files item and the Mac menu item is disabled and hidden

#### Scenario: Temporary failure

- **WHEN** `default-cwd` fails with a timeout
- **THEN** the Files row is shown and opening it shows "Can't reach your Hermes server."

### Requirement: Profile and connection scope

The page SHALL belong to one chat and one profile. Switching the chat's profile, opening another chat, a server change, sign-out or an expired session SHALL close the page, cancel its requests and downloads, drop its lists and discard late answers. The path bar, listing and preview of one profile SHALL NOT appear for another.

#### Scenario: Profile switch

- **WHEN** the user switches the chat to another profile while Files is open
- **THEN** the page closes and its requests are cancelled

#### Scenario: Sign out

- **WHEN** the user signs out while a file downloads
- **THEN** the download is cancelled and the staged files are deleted

### Requirement: App Lock and cached files

While App Lock covers the app, no file name, list or preview SHALL be visible, and the Quick Look panel opened from Files SHALL close. Files downloaded for Files SHALL live in the `MediaStore` cache in the application cache directory (not indexed by Spotlight, not backed up) under the sanitizing rule of other downloads. A file fetched after the secret question SHALL be deleted when its preview closes. All Files downloads SHALL be deleted on sign-out and when App Lock locks; other cached files are removed by the 24-hour sweep at launch, as today. Names from the server SHALL NOT be able to leave the cache folder.

#### Scenario: Lock while previewing

- **WHEN** App Lock locks the app while a file is open in Quick Look
- **THEN** the panel closes and the lock screen is shown

#### Scenario: Lock mid-download

- **WHEN** App Lock locks the app while a file downloads
- **THEN** the download is cancelled, its partial file and every other Files download are deleted, and after unlock the file is fetched again when opened

#### Scenario: Secret file closed

- **WHEN** the user closes the preview of `.env.local` after Continue
- **THEN** its cached copy is deleted

#### Scenario: Hostile name

- **WHEN** a listing contains a file named `../../x`
- **THEN** it is staged under its safe name inside the cache folder

### Requirement: Preview covered in the app switcher

While a Files preview is on screen and the app becomes inactive, the preview SHALL be covered by a blank surface showing only the file type's icon, whether or not App Lock is on, and uncovered when the app is active again.

#### Scenario: App switcher

- **WHEN** the user opens the app switcher while `analysis.py` is shown
- **THEN** the switcher's snapshot shows a blank surface with the code icon and no file name or content

### Requirement: Layouts and platform behaviour

On a phone the list SHALL be one page with the preview pushed over it. On iPad at 700 pt and on desktop at 900 pt the list SHALL sit beside the preview. On macOS the page SHALL use the Mac toolbar and the keyboard (arrows, Enter, ⌘↑, Space, ⌘R) and SHALL NOT use a bottom sheet. Android's back SHALL go up one folder, then close the page.

#### Scenario: iPhone

- **WHEN** the user taps `app.py` on an iPhone
- **THEN** the preview is pushed over the list and Back returns to the list at the same scroll position

#### Scenario: Wide

- **WHEN** the window is 1,100 pt wide
- **THEN** selecting a file shows its preview beside the list

#### Scenario: Keyboard

- **WHEN** a Mac user selects a folder with the arrow keys and presses Enter
- **THEN** the folder opens, and ⌘↑ returns to the parent

### Requirement: Accessibility

Every touch row, action and toggle SHALL be at least 44 pt (iOS, iPadOS) or 48 dp (Android) high. On macOS, where rows are pointer targets, file rows SHALL be 32 pt and every other target at least 28 pt. Rows SHALL read as "<name>, folder" or "<name>, file" with "may contain secrets" where it applies (the text equivalent of the lock), with no meaning carried by colour or icon alone. Each path-bar segment SHALL be a keyboard-focusable button whose label is its full path. Text SHALL scale to the largest accessibility size: names wrap at word boundaries and break inside a word only when nothing else fits, and buttons scale with the text. Contrast SHALL meet WCAG AA in both themes including code colours, progress and failures SHALL be announced, and reduced motion SHALL remove the list-to-preview transition and the spinner's animation.

#### Scenario: Large text

- **WHEN** the system text size is the largest accessibility size
- **THEN** rows grow, names wrap at word boundaries (".env.local" and "api_token.txt" stay whole when the lock can move under them), buttons scale and no action is cut off

#### Scenario: Reduced motion

- **WHEN** the system asks for reduced motion
- **THEN** the preview appears without a transition and the loading and download spinners are still

#### Scenario: Dialogs and path bar

- **WHEN** the size or secret question opens, or the path bar is focused
- **THEN** the question is announced with its buttons, and each path segment is a focusable button read as its full path, for example "/srv/projects/hermes-report/reports, folder, go to"

#### Scenario: Screen reader

- **WHEN** a screen reader focuses a row for `.env`
- **THEN** it reads ".env, file, may contain secrets"

### Requirement: Observability

The feature SHALL record the spans, log events and breadcrumbs listed in design.md and SHALL NOT put a path, file or folder name, profile, `cwd`, server address or file content in any of them. Telemetry SHALL never throw into the page. Files SHALL catch request exceptions and map them to a failure kind without the request's URI, so no span, log, breadcrumb, crash report or thrown message carries the request URL or a path from its query.

#### Scenario: Failed request

- **WHEN** `GET /api/fs/read-text?path=/srv/p/.env` fails with a Dio exception
- **THEN** the page gets a failure kind, and nothing recorded or rethrown contains the URL or `/srv/p/.env`

#### Scenario: A download

- **WHEN** a download ends
- **THEN** the `files.download` span carries only `outcome`, a size bucket and `length_known`

### Requirement: No server change

The feature SHALL use only `GET /api/fs/default-cwd`, `GET /api/fs/git-root`, `GET /api/fs/list`, `GET /api/fs/read-text`, `GET /api/fs/download` and the session rows' `cwd`, with the signed-in session in the header and never in the URL. It SHALL NOT use `?token=`, `/api/files` write routes or `POST /api/fs/write-text`.

#### Scenario: Request audit

- **WHEN** a contract test records the requests of a browse, a preview and a download
- **THEN** all are GETs on the routes above and none has `token` in its query
