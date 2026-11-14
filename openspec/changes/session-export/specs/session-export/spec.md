# Spec Delta

## Purpose

Lets a user save one chat from a self-hosted Hermes as the server's own JSON export, through the system save sheet.

## ADDED Requirements

### Requirement: Backend contract

The feature SHALL use only `GET /api/sessions/{session_id}/export?profile=`, verified at Hermes `d923a5eb`. It answers one JSON object (the session row plus `messages`, every stored row with its `active` and `compacted` flags) and does not set `Content-Disposition`.

#### Scenario: One request

- **WHEN** the user exports a chat
- **THEN** the app sends one export request, with the chat's profile, and no other request for the file

#### Scenario: Server without the route

- **WHEN** the server answers 404 whose detail is neither `Session not found` nor starting `Profile '`, or answers 405
- **THEN** the app says this server cannot export chats and offers no retry

### Requirement: Entry points

The app SHALL offer "Export chat as JSON…" for a chat the server holds, next to Copy Transcript, in the chat header menu, the Mac sidebar row menu, the Mac toolbar "…" menu (compact windows), the Chat menu of the Mac and iPad menu bars and the conversation window menu. It SHALL NOT offer it for a local or mock chat or one without a known profile.

#### Scenario: Server chat

- **WHEN** the user opens the menu of a chat listed by the server
- **THEN** the action is offered in every place that offers Copy Transcript

#### Scenario: Local chat

- **WHEN** the chat is not on the server
- **THEN** the action is absent and Copy Transcript is unchanged

### Requirement: Explicit profile

The request SHALL carry the profile the chat was listed under, never the server's active profile.

#### Scenario: Chat of another profile

- **WHEN** the user exports a chat of profile B while the dashboard runs as A
- **THEN** the request carries `profile=B`, and a 404 `Profile '...' does not exist.` is shown as a profile problem, not as a missing chat

### Requirement: Confirmation first

The app SHALL ask before requesting anything. The dialog says the file holds this session as Hermes stored it, including the system prompt and tool output, and may contain secrets. Its default button SHALL be Cancel.

#### Scenario: Cancel

- **WHEN** the user presses Cancel, Escape or outside the dialog
- **THEN** no request is sent and nothing is saved

#### Scenario: Confirm

- **WHEN** the user presses Export
- **THEN** progress shows "Preparing the export…" with Cancel

### Requirement: Complete file or nothing

The app SHALL offer the save sheet only for bytes that decode to a JSON object with a string `id` and a list `messages`, and SHALL save the server's bytes unchanged.

#### Scenario: Truncated stream

- **WHEN** the connection ends early or the body is not that object
- **THEN** the app says the export was incomplete, nothing is offered for saving, and nothing is resent

#### Scenario: Saved bytes

- **WHEN** the user saves
- **THEN** the file holds the bytes received, named from the chat title with `.json`

### Requirement: Lost answer and failures

A timeout or dropped connection SHALL NOT read as saved, and the app SHALL NOT resend. Each failure (not found, unsupported, profile 404, invalid profile name 400, unreadable store 503, timeout, incomplete, offline, any other error) SHALL have its own message. Try again SHALL ask the user to confirm again.

#### Scenario: Timeout

- **WHEN** the export takes longer than five minutes in total, or Hermes sends no byte for 30 seconds
- **THEN** the message says nothing was saved, and Try again repeats the confirmation

#### Scenario: Chat gone

- **WHEN** the server answers 404 `Session not found`
- **THEN** the message says the chat is no longer on the server

### Requirement: Decode errors stay out of reports

A `FormatException` from decoding the body embeds part of the file. The app SHALL catch it and SHALL NOT pass it, its message, the body or any part of it to the crash reporter, logs, breadcrumbs, spans or user-visible errors; the outcome is only `incomplete`.

#### Scenario: Corrupt body

- **WHEN** the body is not valid JSON
- **THEN** the failure is reported as `incomplete` with no decoder message, and no body text appears in any report

### Requirement: System save sheet only

The file SHALL leave the app only through the platform save sheet the user completes. The app SHALL NOT write it silently, copy it to the clipboard, stage it in the media cache or keep it after the sheet closes; the platform plugin's own temporary export copy is deleted when the sheet returns.

#### Scenario: Cancelled sheet

- **WHEN** the user cancels the save sheet
- **THEN** nothing is written, no error is shown, and the bytes are dropped

#### Scenario: Saved

- **WHEN** the sheet returns a location
- **THEN** a snack bar says the chat was saved, without the path

### Requirement: Lifecycle

The app SHALL cancel the fetch and drop the bytes when the user cancels, switches profile or server, signs out, or App Lock locks.

#### Scenario: App Lock

- **WHEN** App Lock locks during the download
- **THEN** the request is cancelled and the save sheet is not shown after unlocking

### Requirement: Privacy and observability

The feature SHALL record the span `session_export.fetch`, the log event `session_export.failed` and the breadcrumbs `session_export.started`, `.saved` and `.cancelled` with fixed names, outcome and bucketed counts only. None SHALL hold a title, id, profile, file name, path or content.

#### Scenario: Failed export

- **WHEN** an export fails
- **THEN** the log event carries the failure kind and no request URL, id or body
