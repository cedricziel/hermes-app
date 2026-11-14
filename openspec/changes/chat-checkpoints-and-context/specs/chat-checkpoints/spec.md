# Spec Delta

## ADDED Requirements

### Requirement: File checkpoints row

The app SHALL list File checkpoints under "For reference" when `rollback.list` answers `enabled: true`, with the count. When it answers `enabled: false` and the chat ran an edit tool call, the row SHALL say they are off and explain. Otherwise, and on method-not-found, no row SHALL be drawn. The list SHALL load when the panel opens, after a turn while it is open, after a restore and on resume, never on a timer, and SHALL add no other surface.

#### Scenario: Checkpoints on

- **WHEN** the panel opens and the server lists three checkpoints
- **THEN** the row reads "File checkpoints · 3"

#### Scenario: Checkpoints off, chat changed files

- **WHEN** `enabled` is false and the chat holds an edit tool call
- **THEN** the row reads "File checkpoints are off" and opening it says "File checkpoints are off on your Hermes server. To use them, turn on `checkpoints.enabled` in its config."

#### Scenario: Checkpoints off, no edits

- **WHEN** `enabled` is false and the chat has changed no files
- **THEN** no row is drawn

#### Scenario: Old server

- **WHEN** `rollback.list` answers method-not-found
- **THEN** no row is drawn and no error is shown

#### Scenario: Empty list

- **WHEN** `enabled` is true and the list is empty
- **THEN** the page says "No checkpoints yet for this chat's folder. Hermes makes one just before it first edits a file in a turn."

#### Scenario: Loading

- **WHEN** the list is being read
- **THEN** the page shows skeleton rows labelled "Loading checkpoints…"

#### Scenario: Disconnected

- **WHEN** the connection closes while the page is open
- **THEN** the list stays, marked "Not up to date", and Restore actions are disabled

#### Scenario: Stored chat without a live session

- **WHEN** a chat was opened from history and nothing was sent
- **THEN** the row reads "File checkpoints" with "Not checked yet" under it, and only opening it resumes the session and lists

#### Scenario: List fails

- **WHEN** the request fails or times out
- **THEN** the row says "Couldn't read checkpoints" and opening it offers Try again

### Requirement: Checkpoint list

The checkpoint page SHALL list checkpoints newest first, each with a plain sentence from its reason and a relative time with the exact time for assistive technology. Rows SHALL NOT show a file count: `rollback.list` sends none and each diff read is costly, so the count appears only on the Changes page of a checkpoint the user opens. A command or file name from the reason SHALL NOT be shown. The page SHALL say checkpoints belong to the chat's folder and are shared by every chat in it.

#### Scenario: Reasons

- **WHEN** the server lists `before patch`, `before terminal: rm -rf build` and `pre-rollback snapshot (restoring to 1a2b3c4d)`
- **THEN** the rows read "Before editing a file", "Before a terminal command" and "Before a restore", and the command text appears nowhere

#### Scenario: Unknown time

- **WHEN** a checkpoint's timestamp is missing or unparseable
- **THEN** its time reads "Unknown time" and it is not shown as new

#### Scenario: Shared folder

- **WHEN** the page opens
- **THEN** it says "Checkpoints belong to this chat's folder, so other chats in it see them too."

### Requirement: Changes view

"See changes" SHALL request `rollback.diff` with the full hash and show the file list first, from `stat`, then one file's diff at a time in the tool-call diff body. A diff cut at 4,000 characters, or a file in `stat` without a section, SHALL say so while still offering Restore this file. An empty answer for a listed checkpoint SHALL read as unreadable, not as no changes. `rendered` SHALL be ignored and diff text held in memory only.

#### Scenario: Three files

- **WHEN** `stat` lists three files and `diff` holds all three sections
- **THEN** the list shows three rows and choosing one shows only its diff

#### Scenario: Large change

- **WHEN** the diff text is exactly 4,000 characters long and `stat` lists ten files
- **THEN** the files without a section say "Hermes cut this diff short" and the list still shows ten files

#### Scenario: Diff unreadable

- **WHEN** the server answers empty `stat` and `diff` for a listed checkpoint
- **THEN** the page says "Couldn't read the changes. Try again." and does not say nothing changed

#### Scenario: Workspace not covered

- **WHEN** the server answers 5022 with the container-backend text
- **THEN** the page says "Checkpoints don't cover this chat's workspace."

#### Scenario: Narrow screen

- **WHEN** the panel is a phone sheet
- **THEN** the file list and the single-file diff are separate pushed pages and the diff scrolls horizontally without wrapping lines

### Requirement: Restore one file

"Restore this file…" SHALL send `rollback.restore` with the full hash and a relative path read from `stat`. Its confirmation SHALL say which file goes back and to when, that changes made since, by the user or Hermes, are overwritten, that Hermes tries to save the current version first, that another chat in this folder can change it again, and that the chat is unchanged. It SHALL be allowed while the agent works, with a warning. A path not read back exactly from `stat` SHALL NOT be offered.

#### Scenario: Restore succeeds

- **WHEN** the user confirms and the server answers `success: true`
- **THEN** the app says "Restored 1 file", re-lists checkpoints, says so if a new "Before a restore" checkpoint was added, and leaves the chat unchanged

#### Scenario: Restore during a reply

- **WHEN** the chat is replying
- **THEN** the action is available and the confirmation adds the warning

#### Scenario: Stale checkpoint

- **WHEN** the answer is `success: false` "Checkpoint not found"
- **THEN** the app says "That checkpoint is gone." and re-lists

#### Scenario: Name that cannot be restored alone

- **WHEN** a file's name contains `[`, `]`, `*`, `?`, `\`, `:` or starts with `-`
- **THEN** Restore this file is not offered for it and the page points to Restore all files

#### Scenario: Workspace not covered on restore

- **WHEN** the answer is `success: false` with the container-backend text
- **THEN** the app says "Checkpoints don't cover this chat's workspace."

#### Scenario: Server refuses

- **WHEN** the answer is `success: false` with a nested-repository error
- **THEN** the app says "This checkpoint includes a project inside the folder that Hermes didn't capture, so it can't restore it." and nothing is claimed as restored

### Requirement: Restore all files

"Restore all files…" SHALL send `rollback.restore` without `file_path` and be disabled while the chat replies. Its destructive confirmation SHALL state how many files differ, that changes since are overwritten, that later files stay, that Hermes tries to save the current state first, which files no checkpoint holds, that another chat here can change them again, and that it also removes the last message and answers. Focus SHALL be Cancel. The chat SHALL be re-read after it.

#### Scenario: Restore all succeeds

- **WHEN** the user confirms and the server answers `success: true` with `history_removed: 3`
- **THEN** the chat reloads without its last message and answers, the composer holds that message, and the panel lists a new "Before a restore" first if one was added

#### Scenario: Backgrounded or switched during a restore

- **WHEN** the app is backgrounded or the user opens another chat while a restore is in flight
- **THEN** the request is not cancelled, and its result and a re-read land in the original chat's panel

#### Scenario: A queued prompt

- **WHEN** the app's send queue holds a prompt as a restore starts
- **THEN** the queue is held until the restore settles

#### Scenario: Restore during compression

- **WHEN** the server answers 4009 with the text of a running compress ("a /compress is running")
- **THEN** the app says "Hermes is compressing this chat. Try again when it's done." and nothing changes

#### Scenario: History rewind fails

- **WHEN** the server answers 5021 whose text starts with `checkpoint restored, but session history rewind failed`
- **THEN** the app says "Files were restored, but the chat couldn't be rewound. Your messages are unchanged.", re-reads the chat and the list, and leaves the composer unchanged

#### Scenario: Other 5021 errors

- **WHEN** the server answers 5021 with any other text (every exception maps to 5021)
- **THEN** the app says "Hermes couldn't restore the files. Some may have changed.", re-lists checkpoints and re-reads the chat, and never says nothing changed

#### Scenario: Restore failed part-way

- **WHEN** the answer is `success: false` with an error starting "Restore failed:" (it comes after the safety checkpoint and during the checkout)
- **THEN** the app says "Hermes couldn't restore the files. Some may have changed." and re-lists checkpoints; it never says "Nothing changed."

#### Scenario: Busy

- **WHEN** the server answers 4009 while a reply runs
- **THEN** the app says "Wait for the reply to finish, then try again." and nothing changes

#### Scenario: Answer lost

- **WHEN** no answer arrives within 90 seconds or the connection drops
- **THEN** the app says "Hermes didn't answer. The files may have been restored.", re-lists checkpoints and re-reads the chat, and does not send the request again

#### Scenario: Stale session

- **WHEN** the server answers 4001
- **THEN** the app re-establishes the chat's session as it does for a send and asks the user to try again; it never retries the restore by itself

#### Scenario: The confirmation shows what is removed

- **WHEN** the Restore all files confirmation opens and the chat's last prompt is "Split the token refresh out"
- **THEN** it quotes that message, says it goes back into the message box unsent if it is the one removed, says "Another chat working in this folder can change these files again.", and its buttons are Cancel (the default) and a red outlined "Restore all files", not a filled button

#### Scenario: Where the panel goes after a restore

- **WHEN** a Restore all files succeeds from the Changes page
- **THEN** the panel returns to the re-read checkpoint list with the outcome note on top, and after a Restore this file it returns to the re-read Changes page with "Restored 1 file"

#### Scenario: Undoing a restore

- **WHEN** the user restores all files from the "Before a restore" checkpoint
- **THEN** the same confirmation, including the last-message warning, is shown, and restoring a single file from it carries no chat warning

### Requirement: A full restore holds Send

Because the server checks for a running reply before it restores and then rewinds whatever user turn is last, the app SHALL disable Send and hold its queue from the moment Restore all files is confirmed until the restore settles.

#### Scenario: Send is held during a full restore

- **WHEN** the user confirms Restore all files
- **THEN** Send is disabled and new prompts are held from that moment until the restore settles (success, failure or a lost answer), so the server cannot rewind a turn the user sent meanwhile

### Requirement: Restore outcomes say only what is known

Outcomes SHALL say "Restored N files" only when N was read from this checkpoint's changes since the last turn ended, and "Files restored" otherwise. A new "Before a restore" checkpoint SHALL be claimed only when the re-read list holds a new hash whose reason ends with the restored hash's first eight characters. The quoted message SHALL go into the composer only when the re-read chat no longer holds it.

#### Scenario: Nothing removed from the chat

- **WHEN** the server answers `success: true` with `history_removed: 0`
- **THEN** the line reads "Restored N files" (or "Files restored" when N is not known), the composer is unchanged and no message is claimed removed

#### Scenario: Previous state not saved

- **WHEN** after a successful restore the re-read list holds no hash that was not there before whose reason ends "restoring to" and the first eight characters of the restored hash (the server ignores whether that safety checkpoint was taken, and takes none when the folder is unchanged since the newest checkpoint)
- **THEN** the note says "No new “Before a restore” checkpoint was added.", and an older "Before a restore" row at the top is not taken as the new one

#### Scenario: The quoted message is still there

- **WHEN** a full restore succeeds but the re-read chat still holds the message the confirmation quoted
- **THEN** the composer is left as it was and the note says "Files restored. Your last message in this app wasn't the one removed."

### Requirement: Checkpoints respect isolation and privacy

Checkpoint data SHALL be requested only for a confirmed runtime session and never create or resume one. Answers SHALL be dropped after a thread, profile or connection change; lists, diffs and results SHALL be cleared on sign-out, switch, close and App Lock, when only a count shows and restore is disabled.

#### Scenario: Profile switch during a diff read

- **WHEN** a diff answer arrives after the user switched chats
- **THEN** it is dropped

#### Scenario: App Lock

- **WHEN** App Lock covers the app with a diff open
- **THEN** the diff is dropped, the row shows only "N checkpoints" and Restore is disabled

#### Scenario: Sign-out

- **WHEN** the user signs out
- **THEN** all checkpoint state is discarded

#### Scenario: Conversation window and quick panel

- **WHEN** a chat is open in a conversation window or the quick panel
- **THEN** no checkpoint row or Mac menu action is offered there

### Requirement: Checkpoint data stays out of records and other surfaces

Telemetry, breadcrumbs and log events SHALL hold fixed names, outcomes and buckets only, never file names, paths, commands, diffs, hashes, reasons, the quoted message or server error text. Exceptions raised for crash reports SHALL carry fixed kinds, never server text. Checkpoint data SHALL NOT reach notifications, the surface snapshot, the watch or Spotlight. A diff SHALL stay selectable, with no Share and no Copy all action.

#### Scenario: A failed restore is reported

- **WHEN** a restore fails with a server error that quotes a path
- **THEN** the span, breadcrumb and any crash report carry only the outcome kind, and no notification, widget, watch complication or Spotlight entry mentions it

#### Scenario: Copying from a diff

- **WHEN** the user selects lines in a diff
- **THEN** they can copy the selection, and the page offers no Share or Copy all action

### Requirement: Checkpoint accessibility

Rows, file entries and buttons SHALL have 44 pt targets on iPhone and iPad, 28 pt pointer targets on the Mac and 48 dp on Android, and WCAG AA contrast in both themes. Diff additions and removals SHALL be distinguishable by their `+` and `-` marks. Text SHALL scale to the largest size without hiding a file extension or a count. Outcomes SHALL be announced once, politely, in fixed words without file names. The destructive button SHALL expose its role; focus SHALL return to the originating row.

#### Scenario: Screen reader on a file

- **WHEN** a screen reader reads a file row
- **THEN** it hears the file name, "12 lines added, 3 removed" and the Restore action

#### Scenario: Long file names

- **WHEN** a changed file's name is wider than the row at any text size
- **THEN** the name wraps to more lines instead of being cut, so its extension and the "+N −N" counts stay visible

#### Scenario: Keyboard on Mac and desktop

- **WHEN** a user tabs through the checkpoint page
- **THEN** focus follows list order, Return opens the changes, and Escape or ⌘[ goes back

### Requirement: Checkpoint pages refresh and confirmations fit large text

The checkpoint and Changes pages SHALL have a Refresh button on every platform; pull to refresh is extra, never the only way. At the largest text size the confirmations' body SHALL scroll, their buttons SHALL stack, and the quoted message SHALL be capped at a few lines with a fade.

#### Scenario: Refresh on iPhone

- **WHEN** the checkpoint page is open on an iPhone
- **THEN** a Refresh button is in the bar, and pulling down also refreshes

#### Scenario: Restore all files at the largest text size

- **WHEN** the Restore all files confirmation opens at the largest text size
- **THEN** its body scrolls, Cancel and Restore all files stack full width, and a long quoted message is cut after a few lines with a fade
