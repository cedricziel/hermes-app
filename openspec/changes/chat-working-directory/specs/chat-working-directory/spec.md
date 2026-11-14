## ADDED Requirements

### Requirement: Chat working directory is visible

The system SHALL show where a chat runs: the folder name, its full path labelled "on your server", the git branch when known, and the Hermes project name when the folder belongs to one. A new chat SHALL show it in a row above the composer before the first message; an open chat, under the header title with details on a tap. Paths SHALL stay server paths. With no folder data the display SHALL be absent, not an error.

#### Scenario: New chat shows the default

- **GIVEN** the profile's `default_cwd` is `/home/me/code/demo`
- **WHEN** the user opens a new chat
- **THEN** a row above the composer reads "Runs in demo", "/home/me/code/demo · on your server" and "Server default"

#### Scenario: Open chat shows folder and branch

- **GIVEN** a chat row with `cwd` `/home/me/code/demo/api`, `git_branch` `main`
- **WHEN** the chat is open
- **THEN** the header shows "api · main", and a tap shows the full path "on your server"

#### Scenario: Repository root differs from the working directory

- **GIVEN** `git_repo_root` is `/home/me/code/demo` and `cwd` is `/home/me/code/demo/api`
- **THEN** the header names `api`, while the chat list still groups under `demo`

#### Scenario: Project shown

- **GIVEN** a non-archived project has the folder `/home/me/code/demo`
- **WHEN** a chat runs in `/home/me/code/demo/api`
- **THEN** the details show the project's name; with two matching projects the one with the longest matching folder is shown

#### Scenario: Archived project ignored

- **WHEN** the only matching project is archived
- **THEN** no project is shown

#### Scenario: Home folder note

- **GIVEN** the chat's folder equals the server's home or `/`
- **THEN** the row and details add "This is your server's home folder, which holds many projects."

#### Scenario: No data

- **WHEN** the row has no `cwd` and the workspace routes answer 404
- **THEN** no folder row or line appears and nothing reads as an error

#### Scenario: Chat list rows from other sessions lists

- **WHEN** a chat is known only from `session.list` or `session.active_list` (no folder fields)
- **THEN** the line appears once the chat's REST row or `session.create`/`resume` info supplies the folder

### Requirement: Folder picker for a new chat

The system SHALL let the user pick a new chat's folder before the first message from one list read from `GET /api/chat/workspaces` for the chat's profile each time it opens: Server default, Projects (one row per folder, primary first), Recent (known repositories not under a project folder, newest first), then "Browse folders on your server" and "Type a path". Picking SHALL set the draft's folder in memory and send nothing.

#### Scenario: Pick a project folder

- **WHEN** the user opens the picker and taps the project "Demo"
- **THEN** the picker closes, the composer row reads "Runs in demo" with the project name, and no request is sent yet

#### Scenario: Project with several folders

- **WHEN** a project has folders `/a/web` and `/a/api`
- **THEN** both appear as rows under the project name and either is selectable in one tap

#### Scenario: Recent excludes project folders

- **WHEN** a discovered repo's root equals a project folder
- **THEN** it appears under Projects only

#### Scenario: Empty lists

- **WHEN** there are no projects and no repositories
- **THEN** the picker says "No projects or recent folders yet. Browse your server or type a path." and offers both

#### Scenario: Loading

- **WHEN** the catalog is loading
- **THEN** the Server default row is usable at once and the other sections show a labelled skeleton

#### Scenario: Catalog fails but browsing works

- **WHEN** `GET /api/chat/workspaces` fails with a server or network error
- **THEN** the picker says "Couldn't load your projects. You can still browse or type a path." with Try again, and Browse and Type remain

#### Scenario: Old server

- **WHEN** `GET /api/chat/workspaces` answers 404
- **THEN** the picker is not offered, the row shows no change control, and the chat starts in the server's default as today

#### Scenario: Offline

- **WHEN** the device is offline
- **THEN** the picker shows "You're offline. Connect to choose a folder on your server." with the Server default row still selected

#### Scenario: Profile switch

- **GIVEN** a folder was picked for profile A
- **WHEN** the user switches the new chat to profile B
- **THEN** the pick is cleared and the row shows B's default folder and projects

#### Scenario: Search

- **WHEN** more than eight project and recent rows exist
- **THEN** a search field filters them on the device

#### Scenario: Rescan

- **GIVEN** the server reports `scan_enabled`
- **WHEN** the user taps "Look for projects on your server" and the scan finds none
- **THEN** the list is unchanged and says "No new folders found."

#### Scenario: Rescan finds folders

- **WHEN** a scan finds three new folders
- **THEN** they appear under Recent and the picker says "Found 3 new folders."

#### Scenario: Offline row

- **WHEN** the device goes offline with a known folder
- **THEN** the row keeps the folder and its subtitle says "Offline"

#### Scenario: Looking up the default

- **WHEN** the catalog is still loading on a new chat
- **THEN** the row says "Looking up your folder…" with a skeleton path and is not tappable

#### Scenario: Profile switch with the picker open

- **WHEN** the recipient's profile changes while the picker is open
- **THEN** the picker closes and the row shows the new profile's default

### Requirement: Browse and type a folder

Browse SHALL list only the folders of one server directory at a time from `GET /api/fs/list` with a breadcrumb, a way up and "Use this folder"; a 200 with `error` fails that level and an HTTP 403 hides Browse. Type a path SHALL offer a field labelled "Folder on your server" with folder suggestions from `complete.path` (latest answer only) and enable "Use this folder" only for a path that lists without `error`. Neither SHALL offer a device picker or create folders.

#### Scenario: Navigate down and up

- **WHEN** the user opens `code` and then taps "up"
- **THEN** the listing returns to the parent and the breadcrumb follows

#### Scenario: Empty folder

- **WHEN** a folder has no subfolders
- **THEN** the list says "No folders here." and "Use this folder" stays available

#### Scenario: Unreadable folder

- **WHEN** a level answers 200 with `error: "EACCES"`
- **THEN** that level says "Couldn't open this folder. Hermes isn't allowed to read it." and the previous level stays reachable

#### Scenario: Locked server

- **WHEN** the first `fs/list` read answers 403 "Path is outside the managed read boundary"
- **THEN** Browse is hidden for the visit and Type still works with `complete.path`

#### Scenario: One forbidden level

- **WHEN** a later level answers `EACCES`, or a 403 whose detail is not the managed read boundary
- **THEN** that level says "Couldn't open this folder. Hermes isn't allowed to read it.", Browse stays available and "Use" stays enabled for the folder being shown

#### Scenario: Later level outside the boundary

- **WHEN** a later level answers 403 "Path is outside the managed read boundary"
- **THEN** that level says "This folder is outside what this server lets you browse", offers the way back, disables "Use" for it, and Browse stays available for the visit

#### Scenario: Use names the folder

- **WHEN** Browse shows the folder `code`
- **THEN** its action reads "Use “code”", and it is disabled only while the level is missing or outside the boundary

#### Scenario: Connection lost while browsing

- **WHEN** a level answers 503
- **THEN** it says "Couldn't open this folder." with Try again

#### Scenario: Symlinked folder

- **WHEN** a folder is a symlink to a directory and so is listed as a file
- **THEN** it is not shown in Browse, and typing its path still works

#### Scenario: Typed suggestions

- **WHEN** the user types `/home/me/co` and suggestions arrive for an earlier text after ones for the current text
- **THEN** only the current text's suggestions are shown

#### Scenario: Relative path

- **WHEN** the typed text does not start with `/` or `~`
- **THEN** "Use this folder" is disabled and the field says "Start with / or ~"

#### Scenario: Many files hide folders

- **WHEN** Hermes returns 30 suggestions
- **THEN** the list says "Keep typing to narrow the list." and Browse remains the way to see every folder

#### Scenario: Suggestion text

- **WHEN** the user types an absolute path and taps a suggestion
- **THEN** the field becomes the typed directory plus the suggestion's name and "/", whatever relative text Hermes returned

#### Scenario: Typed path does not exist

- **WHEN** the typed path lists with `ENOENT`
- **THEN** "Use this folder" is disabled and the field says "This folder doesn't exist on your server."

#### Scenario: Hidden names

- **WHEN** the server withholds some folders
- **THEN** folders the server withholds (`node_modules`, `.git`, secret names) do not appear and no message claims they are missing

### Requirement: The chat is created in the chosen folder

A new chat's first send with a picked folder SHALL put `cwd` and `cwd_explicit: true` on `session.create`; with no pick neither. Resume, the quick panel, Ask Hermes, the watch, notifications and links SHALL send none. After creation the folder, branch and project SHALL come from the session's `info`, and a reported folder that differs from the pick SHALL show a notice and log `workspace.cwd_mismatch`.

#### Scenario: Picked folder sent

- **WHEN** the user picked `/home/me/code/other` and sends a message
- **THEN** `session.create` has `cwd: "/home/me/code/other"` and `cwd_explicit: true`, and the header shows `other`

#### Scenario: No pick

- **WHEN** the user sends without picking
- **THEN** `session.create` has no `cwd` and no `cwd_explicit` and the header shows the folder Hermes reports

#### Scenario: Server fell back

- **WHEN** the picked folder was deleted meanwhile and the server answers `info.cwd` `/home/me`
- **THEN** the header shows `me` and the notice "Hermes started in me instead of <picked folder>. The folder may not exist on your server, or this profile may use its own folder." appears once

#### Scenario: Older server rejects the flag

- **WHEN** `session.create` answers error 4000 mentioning `cwd_explicit`
- **THEN** the create is retried once without it, the chat is created, and a differing folder shows the notice

#### Scenario: Quick panel and links

- **WHEN** a chat starts from the quick panel, Ask Hermes, the watch, a notification or a link
- **THEN** `session.create` carries no `cwd`

#### Scenario: Reply continues

- **WHEN** the notice is shown
- **THEN** the reply still streams normally and the notice does not block the composer

#### Scenario: Resume

- **WHEN** an existing chat is resumed
- **THEN** no `cwd` is sent

### Requirement: Change the folder of an existing chat

The system SHALL offer "Change folder…" for a stored chat that is not replying, on a server that answers `session.workspace.move`, and on the Mac in the thread menu as "Change Folder…". After picking it SHALL confirm, then send the move once with the stored id, folder and profile, show the answer's folder and regroup the chat in the list with selection kept. It SHALL NOT be offered while replying, for a Bot Chat registry, or for an unopened chat of another profile.

#### Scenario: Move

- **WHEN** the user picks `/home/me/code/other` and confirms
- **THEN** the move is sent once, the header reads `other`, and the chat appears under that folder in Folder grouping

#### Scenario: Cancel

- **WHEN** the user cancels the confirmation
- **THEN** nothing is sent and the folder is unchanged

#### Scenario: Folder missing

- **WHEN** the server answers error 4017
- **THEN** the sheet says "That folder doesn't exist on your server." and the folder is unchanged

#### Scenario: Lost answer

- **WHEN** the connection drops before the answer
- **THEN** the app says "Couldn't change the folder. Checking…", re-reads the chat's row, shows whichever folder it holds, and does not resend

#### Scenario: Server error

- **WHEN** the server answers `5007`
- **THEN** the chat keeps its folder and the user sees "Couldn't change the folder." with Try again

#### Scenario: Replying

- **WHEN** a reply is running
- **THEN** "Change folder…" is disabled, "Wait for the reply to finish." is shown next to it and read as its description, and on the Mac the menu's "Change Folder…" is shown disabled rather than hidden

#### Scenario: Confirmation actions

- **WHEN** the confirmation is shown
- **THEN** Cancel is the default action, "Change folder" is neither filled nor red, and on Android both are text buttons with Cancel first

#### Scenario: Current folder not in a list

- **WHEN** the chat's folder is neither a project folder nor a recent folder
- **THEN** the picker adds it, checked and marked "Current", at the top of Projects when a project matches it and of Recent otherwise

#### Scenario: Old server

- **WHEN** the move answers method not found
- **THEN** "Change folder…" is hidden for the connection

#### Scenario: Current folder marked

- **WHEN** the picker opens for an existing chat
- **THEN** the chat's current folder is marked "Current"

#### Scenario: Relative or missing path on a move

- **WHEN** the typed move target does not start with `/` or `~`
- **THEN** it is refused on the device before any request

#### Scenario: Mac thread menu

- **WHEN** the user opens a stored chat's menu on the Mac while it is not replying
- **THEN** "Change Folder…" is offered and opens the picker dialog

#### Scenario: Conversation window

- **WHEN** a chat is open in a conversation window
- **THEN** the window shows the folder line and details but offers no change

#### Scenario: Another window

- **WHEN** the chat is also open in a conversation window
- **THEN** that window shows the new folder when it next reloads (when it becomes key)

### Requirement: Every waiting state ends

Every state that waits on the server SHALL end within 10 s of its request, measured on a monotonic clock, in a state that says what happened and offers the action again, and the system SHALL NOT resend anything by itself. An answer that arrives later SHALL still update the screen.

#### Scenario: Default folder lookup

- **WHEN** the row has shown "Looking up your folder…" for 10 s
- **THEN** it reads "Runs in the server's default folder" without a path and opens the picker on a tap

#### Scenario: Picker catalog

- **WHEN** the picker's projects have been loading for 10 s
- **THEN** it shows "Couldn't load your projects. You can still browse or type a path." with Try again

#### Scenario: Browse level

- **WHEN** a Browse level has shown "Opening <folder>…" for 10 s
- **THEN** it says "Couldn't open this folder." with Try again

#### Scenario: Typed path check

- **WHEN** "Checking…" has shown for 10 s
- **THEN** the field says "Couldn't check this folder." with "Check again" and "Use this folder" stays disabled

#### Scenario: Scan

- **WHEN** "Look for projects on your server" has had no answer for 10 s
- **THEN** the progress stops, the list keeps what it had, and the picker says "Couldn't finish looking for projects. Try again."

#### Scenario: Lost move answer

- **WHEN** the re-read after a lost move answer has had no answer for 10 s
- **THEN** the details say "Couldn't confirm the change" with "Check again", which only re-reads the chat's row, "Change folder…" is offered again, and the move was sent exactly once

#### Scenario: Late answer

- **WHEN** an answer arrives after its wait has ended
- **THEN** the screen shows that answer instead of the timed-out state

### Requirement: Safety and privacy of paths

Paths, folder names, project names and branches SHALL be held in memory only: never in preferences, secure storage, the surface snapshot, Spotlight, Handoff, widgets, the watch bridge, notifications, drag-out, spans, logs or breadcrumbs. Telemetry SHALL carry only fixed names and outcomes. Sign-out and Change Server SHALL clear the draft choice and catalog, and App Lock SHALL close an open picker and drop its state.

#### Scenario: Sign-out

- **WHEN** the user signs out with a folder picked
- **THEN** the draft choice and catalog are gone for the next account

#### Scenario: Change Server

- **WHEN** the user changes the server
- **THEN** the draft choice and cached catalog are cleared

#### Scenario: App Lock

- **WHEN** App Lock covers the app while the picker or a move confirmation is open
- **THEN** it is closed, nothing is sent, and reopening shows a fresh list

#### Scenario: Telemetry

- **WHEN** a folder is picked and a chat is moved
- **THEN** the records hold only the fixed names and outcomes above

#### Scenario: Surfaces

- **WHEN** a chat has a folder, project and branch
- **THEN** the surface snapshot, Spotlight items, notifications and the watch status contain no folder, project or branch

### Requirement: Accessibility and platform conventions

Rows and controls SHALL be at least 44 pt (48 dp) with screen-reader labels naming folder, path "on your server" and branch, a selected state, no meaning by colour alone, text that scales to the largest accessibility size, and no motion under reduced motion. The picker SHALL be a bottom sheet on phones, a dialog on wide layouts (iPad in a wide window, desktop) and the Mac (never a bottom sheet there), with a defined keyboard order.

#### Scenario: Large text

- **WHEN** the system text size is at its largest accessibility setting
- **THEN** no text is capped, the row wraps the folder name, stacks its tags, wraps the path in full and puts "on your server" on its own line, and the full path remains in the details sheet

#### Scenario: Header line at large text

- **WHEN** the text size is an accessibility size
- **THEN** the folder line leaves the header bar and is shown as a full-width row directly under it, with the same target and label

#### Scenario: Details at large text

- **WHEN** the details sheet is shown at an accessibility size
- **THEN** each row stacks its label over its value and the sheet scrolls to "Change folder…"

#### Scenario: Disabled reason

- **WHEN** "Change folder…" is disabled
- **THEN** its reason ("Wait for the reply to finish.", "You're offline.", "Changing the folder…" or "Checking the folder…") is shown next to it with an icon and exposed as its description

#### Scenario: Paths cut in the middle

- **WHEN** a path does not fit on one line in the row, a picker row or a folder section header
- **THEN** it is cut in the middle, "· on your server" stays visible where it is shown, and the semantics label carries the full path

#### Scenario: Screen reader

- **WHEN** focus lands on the row
- **THEN** it reads "Folder: demo, /home/me/code/demo on your server, branch main, button"

#### Scenario: Keyboard on the Mac

- **WHEN** the dialog opens
- **THEN** focus is in the search field (or, with no search field, on the first row), Down moves through rows, Return picks and Escape closes

### Requirement: Profile scope

Every workspace, listing, completion and move request SHALL name the chat's profile explicitly. The picker for a new chat SHALL use the selected recipient's profile; an existing chat's picker SHALL use that chat's profile. The system SHALL NOT change the server's active profile or CLI default.

#### Scenario: Request scoping

- **WHEN** a chat of profile "work" opens the picker
- **THEN** `GET /api/chat/workspaces` carries `profile=work`

#### Scenario: Unknown profile

- **WHEN** the server answers 404 for the profile
- **THEN** the picker says "This profile no longer exists on your server." and offers no folders
