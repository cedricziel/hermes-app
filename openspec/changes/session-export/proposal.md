# Proposal

## Why

A chat in the app can only leave it as text: Copy Transcript and the Mac drag-out give the visible turns as Markdown, without tool calls, reasoning, the system prompt or the rows Hermes hides after a rewind or a compaction. The dashboard's Sessions page can download one session in full as JSON (`GET /api/sessions/{id}/export`). The app does not offer it. Roadmap item 4.8 (session export).

## What Changes

An **Export chat as JSON…** action for a chat the server holds. The user chooses it, reads one confirmation (the file holds everything Hermes stored for the chat, which can include secrets), the app fetches the file, checks that it is complete JSON, and hands it to the system save panel (macOS, Windows, Linux) or Files and the Android picker (iOS, Android). The action sits in the chat header menu, the sidebar row menu, the Mac Chat menu and the conversation window's menu, next to Copy Transcript.

## Non-goals

- No import (`POST /api/sessions/import` exists; not used). No profile export and no Kanban board export.
- No device-made Markdown in this change (see design, "Decisions"). Copy Transcript stays as it is.
- No Share sheet, no `share_plus`, no copy to the clipboard, no cached copy of the file.
- No redaction and no editing of the file: it is the server's bytes.

## Security and privacy impact

The file can hold the system prompt, tool output, file paths, user and chat ids and anything the agent read. It is held in memory only until the user picks where to save it, never cached, copied, logged or sent to telemetry. The user chooses the place; nothing is written silently.

## Observability

- Span `session_export.fetch`: outcome, byte and message-count buckets, `hermes.*` attributes. A request with a duration.
- `AppEventLogger` `session_export.failed` with a failure kind: worth counting.
- Breadcrumbs `session_export.started`, `.saved`, `.cancelled`: user steps. No title, id, profile, path, name or content in any of them.

## Design pass

- Export confirmation (alert on phone and desktop, Cancel default) - default, largest text, dark.
- Export progress ("Preparing the export…", Cancel, size unknown) - loading, cancel, dark, large text, phone and desktop.
- Export failures (not found, server cannot export, profile missing, store unreadable, timed out or lost, incomplete file, offline) - one message each, Try again where it helps.
- Saved and cancelled feedback - snack bar after save; nothing after cancel.
- Menu rows ("Export Chat as JSON…") in the header menu, sidebar menu, Mac Chat menu and conversation window menu - enabled, hidden for local chats, busy.
