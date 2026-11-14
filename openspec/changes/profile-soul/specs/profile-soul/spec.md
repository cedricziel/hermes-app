# Spec Delta

## Purpose

Lets the user read and change a profile's SOUL.md, the text that defines the agent's personality, from the app, with a clear question before it is replaced and an honest result when the answer is lost.

## ADDED Requirements

### Requirement: Backend contract

The feature SHALL use only `GET /api/profiles/{name}/soul` and `PUT /api/profiles/{name}/soul` (body `{"content": string}`), verified at Hermes `d923a5eb`, through the generated client. The profile name is in the path, no `profile` query exists, and the routes act on that profile's own SOUL.md whether or not it is the dashboard's or the active profile.

#### Scenario: Another profile

- **WHEN** the chat's profile is not the dashboard's own profile and the user opens Personality
- **THEN** the requests name the chat's profile in the path and read and write that profile's file

#### Scenario: Old server

- **WHEN** the server answers 404 whose detail does not start with "Profile '", or answers 405
- **THEN** the Personality entries are hidden for the rest of the connection, and an open screen shows only the neutral "This server doesn't offer personality settings." with Back

### Requirement: Entry points

The app SHALL open Personality from a row after Memory in the chat sidebar (the chat's profile) and from a section after Memory on the Mac Profiles page (the selected profile). It SHALL never use the server's active profile.

#### Scenario: Phone

- **WHEN** the user opens the sidebar row while chatting with profile "work"
- **THEN** the screen titled with that profile opens and reads "work"'s file

### Requirement: Showing the text

The screen SHALL show the server's text in an editor, or an empty editor with "No personality set yet" when `exists` is false, and SHALL show loading, offline, not-found and failed states, with Try again for offline and failed and Back for not-found.

#### Scenario: File missing versus empty

- **WHEN** the answer is `exists: false`, or `exists: true` with empty content
- **THEN** both show an empty editor, and the empty file adds "Hermes uses its default personality while this is empty"

#### Scenario: Profile gone

- **WHEN** the server answers 404 "Profile '<name>' does not exist."
- **THEN** the screen shows "This profile no longer exists" with no editor

### Requirement: Editing never saves by itself

Text SHALL change nothing on the server until the user confirms a save. The text SHALL stay only in screen state: never in preferences, drafts, logs or telemetry, and dropped on sign-out, server change and App Lock at once, with no grace period. Leaving with unsaved changes SHALL ask first, defaulting to Keep editing.

#### Scenario: Leaving with changes

- **WHEN** the user edits and then goes back
- **THEN** "Discard changes?" is asked with Keep editing as the default, and nothing is sent either way

### Requirement: Save is confirmed

Save SHALL ask before sending, with Cancel as the default: it replaces the whole file, new chats use it and running chats usually keep the old text (Bot Chats may pick it up). Empty text SHALL say Hermes will use its default personality.

#### Scenario: Cancel

- **WHEN** the user presses Save and then Cancel
- **THEN** no request is sent and the text stays in the editor

#### Scenario: Empty text

- **WHEN** the editor is empty and the user presses Save
- **THEN** the question says Hermes will use its default personality, and Replace sends `content: ""`

### Requirement: Changed-on-server check

Before a confirmed save the app SHALL read the file again and send only when it equals what the screen last loaded or saved. Otherwise it SHALL send nothing and offer Show server's version, Keep editing (default) and Replace anyway. A failed check SHALL send nothing, and the check read and the PUT SHALL each give up after 10 s.

#### Scenario: Someone else saved

- **WHEN** the file changed on the server after the screen loaded and the user confirms Save
- **THEN** no PUT is sent until the user chooses Replace anyway

#### Scenario: Check fails

- **WHEN** the second read fails or times out
- **THEN** nothing is sent, the error is shown with Try again, and the text stays

### Requirement: A lost answer is not a save

If the save's answer is lost or lacks `ok: true`, the app SHALL say the save could not be confirmed, keep the text, resend nothing and not show Saved. A user-tapped Check SHALL read the file and report Saved only when the file exists and equals the text that was sent.

#### Scenario: Timeout on save

- **WHEN** the PUT times out
- **THEN** "Couldn't confirm the save" is shown with Check, and Save asks again before any new request

#### Scenario: Check finds it saved

- **WHEN** the user taps Check and the server's text equals the text that was sent
- **THEN** the screen shows Saved and treats the sent text as the loaded text; later edits stay unsaved

### Requirement: Size guidance

The app SHALL show a character count, note from 20,000 characters that Hermes may shorten long text, and SHALL NOT lock or block editing or saving at any length: Hermes has no fixed ceiling, since an explicit `context_file_max_chars` overrides the dynamic cap.

#### Scenario: Long text

- **WHEN** the text passes 20,000 characters, or 500,000
- **THEN** a note appears and the editor and Save stay available

### Requirement: Privacy and observability

The feature SHALL record spans `profile_soul.fetch` and `profile_soul.save`, the log event `profile_soul.saved` and breadcrumbs `profile_soul.opened` and `profile_soul.save.confirmed`, carrying only fixed names, outcomes, flags and length buckets. Errors SHALL show a fixed message, not the response body.

#### Scenario: Nothing user-written is recorded

- **WHEN** the user saves text and a profile named "work-secret-bot"
- **THEN** no span, log or breadcrumb contains the text, the name or an error body
