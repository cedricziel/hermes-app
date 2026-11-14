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
- **THEN** the row reads "File checkpoints · Tap to check" and only a tap resumes the session and lists

#### Scenario: List fails

- **WHEN** the request fails or times out
- **THEN** the row says "Couldn't read checkpoints" and opening it offers Try again

### Requirement: Checkpoint list

The checkpoint page SHALL list checkpoints newest first, each with a plain sentence from its reason, a relative time with the exact time for assistive technology, and, once read, how many files differ now. A command or file name from the reason SHALL NOT be shown. The page SHALL say checkpoints belong to the chat's folder and are shared by every chat in it.

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

"Restore this file…" SHALL send `rollback.restore` with the full hash and a relative path read from `stat`. Its confirmation SHALL say which file goes back and to when, that later changes to it are overwritten, that Hermes saves the current version first and that the chat is unchanged. It SHALL be allowed while the agent works, with a warning. A path not read back exactly from `stat` SHALL NOT be offered.

#### Scenario: Restore succeeds

- **WHEN** the user confirms and the server answers `success: true`
- **THEN** the app says "Restored 1 file", re-lists checkpoints so "Before a restore" appears at the top, and leaves the chat unchanged

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

"Restore all files…" SHALL send `rollback.restore` without `file_path` and be disabled while the chat replies. Its destructive confirmation SHALL state how many files differ, that later changes are overwritten, that files Hermes created after stay, that Hermes saves the current state first, and that it also removes the chat's last message and answers whichever checkpoint is chosen. Focus SHALL be Cancel. On success the chat SHALL be re-read and the removed message put unsent in the composer.

#### Scenario: Restore all succeeds

- **WHEN** the user confirms and the server answers `success: true` with `history_removed: 3`
- **THEN** the chat reloads without its last message and answers, the composer holds that message, and the panel lists "Before a restore" first

#### Scenario: Nothing removed from the chat

- **WHEN** the server answers `success: true` with `history_removed: 0`
- **THEN** the line reads "Restored N files", the composer is unchanged and no message is claimed removed

#### Scenario: Previous state not saved

- **WHEN** after a successful restore the re-listed top checkpoint is not "Before a restore"
- **THEN** the note says "Hermes couldn't save the previous state first."

#### Scenario: Backgrounded or switched during a restore

- **WHEN** the app is backgrounded or the user opens another chat while a restore is in flight
- **THEN** the request is not cancelled, and its result and a re-read land in the original chat's panel

#### Scenario: A queued prompt

- **WHEN** the app's send queue holds a prompt as a restore starts
- **THEN** the queue is held until the restore settles

#### Scenario: Restore during compression

- **WHEN** the server answers 4009 because a compression runs
- **THEN** the app says "Wait for the reply to finish, then try again."

#### Scenario: History rewind fails

- **WHEN** the server answers 5021 `checkpoint restored, but session history rewind failed`
- **THEN** the app says "Files were restored, but the chat couldn't be rewound. Your messages are unchanged." and re-reads the chat

#### Scenario: Busy

- **WHEN** the server answers 4009
- **THEN** the app says "Wait for the reply to finish, then try again." and nothing changes

#### Scenario: Answer lost

- **WHEN** no answer arrives within 90 seconds or the connection drops
- **THEN** the app says "Hermes didn't answer. The files may have been restored.", re-lists checkpoints and re-reads the chat, and does not send the request again

#### Scenario: Stale session

- **WHEN** the server answers 4001
- **THEN** the app re-establishes the chat's session as it does for a send and asks the user to try again; it never retries the restore by itself

#### Scenario: Undoing a restore

- **WHEN** the user restores all files from the "Before a restore" checkpoint
- **THEN** the same confirmation, including the last-message warning, is shown, and restoring a single file from it carries no chat warning

### Requirement: Checkpoints respect isolation and privacy

Checkpoint data SHALL be requested only for a confirmed runtime session and never create or resume one. Answers SHALL be dropped after a thread, profile or connection change; lists, diffs and results SHALL be cleared on sign-out, switch, close and App Lock, when only a count shows and restore is disabled. Telemetry SHALL hold outcomes and buckets only, never names, paths, commands, diffs, hashes or reasons.

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

### Requirement: Checkpoint accessibility

Rows, file entries and buttons SHALL have 44 pt or 48 dp targets and WCAG AA contrast in both themes. Diff additions and removals SHALL be distinguishable by their `+` and `-` marks, not colour alone. Text SHALL scale to the largest accessibility size without hiding the file name's extension or a count. Outcomes SHALL be announced once in fixed words without file names. The destructive button SHALL expose its destructive role; focus SHALL return to the originating row.

#### Scenario: Screen reader on a file

- **WHEN** a screen reader reads a file row
- **THEN** it hears the file name, "12 lines added, 3 removed" and the Restore action

#### Scenario: Keyboard on Mac and desktop

- **WHEN** a user tabs through the checkpoint page
- **THEN** focus follows list order, Return opens the changes, and Escape or ⌘[ goes back
