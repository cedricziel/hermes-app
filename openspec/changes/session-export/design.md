# Design

## Server surface

Verified in the Hermes source at `d923a5eb` (`openapi/HERMES_REF`), read only. The `hermes` command is not installed in this environment, so no response was recorded (see "Not verified").

- **Route.** `GET /api/sessions/{session_id}/export?profile=` in `hermes_cli/web_routers/sessions.py: export_session_endpoint`. Registered on `manage_router` (`web_server.py` line 1067); the usual dashboard auth applies (`web_server.py: auth_middleware`, or the OAuth gate). The OpenAPI entry has no response schema (`{}`), only 200 and 422.
- **Parameters.** `session_id` is an exact id or an unambiguous prefix (`hermes_state_sessions.py: resolve_session_id`; two matches resolve to none). `profile` is optional. Omitted, the process's own `state.db` is read (`web_server_sessions.py: _session_db_path_for_profile`). Named, it goes through `web_server_cron.py: _cron_profile_home`: 400 with the validation message for a bad name, 404 `Profile '<name>' does not exist.` for an unknown one. A 404 is ambiguous: a detail starting `Profile '` is a missing profile, `Session not found` a missing chat, and any other 404 (e.g. `No such API endpoint: ...`) or a 405 means the server lacks the route. The route is read only (`read_only=True`); `get_session` first drains queued token counts.
- **Response.** `StreamingResponse`, `media_type="application/json"`. No `Content-Disposition`, and no `Content-Length` is set, so the total is unknown while it downloads. The web page names the file itself, `session-<id>.json` (`web/src/pages/SessionsPage.tsx: handleExport`). The body is one compact object: every column of the `sessions` row (`get_session`; `system_prompt` and `tool_names` resolved, `model_config`, `origin_json`, `user_id`, `chat_id`, `cwd`, `git_repo_root`, billing and token counts, `title`) with `"messages":[ ... ]` appended.
- **Messages.** Read in keyset pages of 500 with `include_inactive=True`: every stored row of that session, including rows after a rewind (`active` 0) and rows archived by in-place compaction (`compacted` 1), each with its flags. Per row: `role`, `content` (a string, or a list for multimodal parts), `tool_calls`, `tool_call_id`, `tool_name`, `reasoning`, `reasoning_content`, `reasoning_details`, `api_content`, `display_metadata`, `token_count`, `timestamp` (`hermes_state_messages.py: get_messages`, `_row_to_message_dict`; `display_identity` and `display_order` are dropped). It is one session, not the compression lineage: parent sessions are not included (`export_session_lineage` is not used here), whereas `/messages` includes ancestors. There is no `timings` key, unlike `SessionDB.export_session`.
- **Size.** No cap and no truncation; memory on the server is bounded by the page size, not by the transcript. The test `tests/hermes_cli/test_web_server.py: test_export_session_streams_bounded_message_pages` covers 501 rows in two pages.
- **Errors.** 404 `Session not found` (unknown id, ambiguous prefix; `sessions.py: _NOT_FOUND`); 503 `Session store is corrupt ...` (`_resolve_session_id`); 401 `Unauthorized`; 422 from FastAPI. The first byte is sent only after the session row is read, so those are real statuses. A failure while streaming the pages happens after status 200: the body just stops, as truncated JSON.
- **Secrets.** Nothing is redacted on this route. The CLI's `/save ... redact` option is not reachable over HTTP (`hermes_cli/session_export.py`). The system prompt, tool results and arguments can hold keys.
- **Import.** `POST /api/sessions/import` takes a session export (JSON or JSONL; `sessions.py: import_sessions_endpoint`). Noted, not used.
- **Markdown.** `hermes_cli/session_export_md.py` renders Markdown for the CLI; no route serves it.

## What the app has

- `ThreadAction` and `runThreadAction` (`lib/src/chat/widgets/thread_actions_menu.dart`) are the one place every chat menu goes through: sidebar row (Mac `macThreadMenuItems`; off the Mac `ThreadActionsButton` shows Copy transcript only with `includeCopyTranscript`, which only the header sets, and touch rows have the swipe sheet of Rename, Pin, Archive, Delete), chat header, Mac toolbar "…" (`mac_chat_toolbar.dart`), conversation window (`conversation_windows_menu.dart`) and the Mac Chat menu (`MacCommand.copyTranscript` in `menu_layout.dart`, handler in `chat_screen_navigation.dart`). A new `ThreadAction.exportJson` reaches all of them.
- Saving: `MediaActions.save(name, bytes)` is `FilePicker.saveFile` (`lib/src/chat/media/media_actions.dart`, also `kanban_files.dart`). `file_picker` 13.3.3 shows NSSavePanel on macOS, the save dialog on Windows and Linux, the Files export sheet on iOS and the system "create document" picker on Android, and returns null on cancel.
- Not present: `share_plus` (Server files plans it, `openspec/changes/server-files` task 3.4), a Share action, any `Content-Disposition` handling.
- Text export that exists: `threadTranscript`, `threadMarkdown`, `threadExportFileName` (`lib/src/chat/thread_export.dart`): visible turns only.
- Generated client: `exportSessionEndpointApiSessionsSessionIdExportGet` (`packages/hermes_api`, `default_api.dart`) takes `sessionId`, `profile`, `headers`, `extra`; it returns `Response<Object>`.

## Decisions

1. **Raw JSON only.** It is the one thing the server gives that the app cannot make: reasoning, tool calls, rewound and compacted rows, the system prompt and costs. A device-made Markdown would repeat Copy Transcript and the Mac drag-out. A "Save transcript as Markdown…" using `threadMarkdown` and `saveFile` is a small separate change, left out here.
2. **Save, not Share.** The existing save path is used on every platform. A Share action waits for `share_plus` from Server files; this change does not add the package.
3. **Hand-written byte fetch.** The generated method can return the JSON (Dio decodes `application/json` to a `Map`), so this is a choice, not a necessity. It would decode a possibly very large body into maps and re-encode it: several times the memory, and not the server's bytes. `HermesApiClient._getBytes` (`fetchKanbanAttachment`, `fetchManagedFile`) already asks for bytes with a 5-minute total deadline (`requestDeadlineExtra`). It has no `CancelToken` and no progress callback, so `fetchSessionExport(id, profile)` either extends `_getBytes` with both (an optional `cancelToken` and `onProgress(received)`, which the existing callers leave out) or follows the `downloadFsFile` pattern; it does not stage bytes in a file, so the first is simpler. The id is percent-encoded (the generated method puts it into the path as is). Timeouts: the managed `Dio` has `receiveTimeout` 30 s, which covers the headers and the gap between two chunks (`request_timeout.dart`); `_getBytes` only adds the 5-minute total. The fetch keeps both: no byte for 30 s is `lost`, a stall after bytes arrived is `incomplete` (the progress callback says whether any byte came), and five minutes in total ends it the same way. Passing `receiveTimeoutExtra(5 min)` instead would wait five minutes on a silent server; recommended against (owner decision: 30 s of silence stays). A reviewer who prefers the generated call can swap it; the rest of the design does not change.
4. **Confirm first.** One dialog, Cancel the default, before anything is requested, because the file may hold secrets. It is not a destructive action, but the file leaves the app's protection.
5. **Validate before saving.** A `jsonDecode` `FormatException` embeds a slice of the source text (file content), so it is caught where it is thrown and mapped to `incomplete`; neither it nor the body reaches the crash reporter, logs or any message. A streamed 200 can stop short. The bytes are decoded (`jsonDecode`, in an isolate above 1 MB); the root must be an object with a string `id` and a list `messages`, or nothing is offered for saving. A dropped connection is the same failure. Nothing is retried.
6. **Memory only.** The app never stages the bytes in `MediaStore`, so no cache rule applies. They are dropped when the save returns, the user cancels, the profile or server changes, the user signs out, or App Lock locks (the fetch is cancelled). One copy is the plugin's: on iOS `file_picker_darwin` writes a temporary file before showing the save sheet (`IOSFilePickerHandler.saveFile`), which `MediaActions.save` never clears. The app calls `FilePicker.clearTemporaryFiles()` when the sheet returns (saved or cancelled) and on App Lock and sign-out. App Lock while the native sheet is open: the app cannot dismiss it, so a user who finishes after unlocking gets the file written (accepted limit), and no snack bar shows for a save that returns after a lock.
7. **Profile.** The profile the chat was listed under (`ThreadHousekeeping.profile`) is sent explicitly. A chat without one is not offered (`housekeeping == null` or a null profile hides the item); local and mock chats never are.
8. **File name.** `threadExportFileName`'s rules with `.json`. The name stays on the device and goes to no telemetry.

## Known limit

A chat the server compressed into a new session exports only its current session. The file says so only through its `parent_session_id`. The confirmation does not claim "the whole chat"; it says "this session as Hermes stored it".

## Platforms

All six clients use `saveFile`. macOS needs the user-selected read-write entitlement the Kanban save already uses; no native change. watchOS: none.

## Invariants touched

Auth: the request goes through the managed `Dio`, so a 401 follows the existing refresh path and never signs the user out on its own. Telemetry never breaks the app; every call is guarded. Generated client: see decision 3.

## Observability

- `session_export.fetch` span (`ChatTelemetry`/feature span helper, in the repository): `outcome`, one snake_case vocabulary equal to the failure kinds: `ready`, `cancelled`, `gone`, `unsupported`, `profile_missing`, `profile_invalid`, `unreadable`, `lost`, `incomplete`, `offline`, `failed`, `bytes_bucket`, `messages_bucket`, `hermes.*`. The messages count is read from the decoded root.
- `session_export.failed` through `AppEventLogger` with `reason` only, the same failure-kind names.
- Breadcrumbs `session_export.started`, `.saved`, `.cancelled`, from the controller.
- None carries a title, id, profile, file name, path or any file content.

## Design pass

Design: brief reviewed, canvas pending (publish quota, resumes after 2026-11-15 00:00 UTC)

Brief: `docs/design-briefs/session-export.md` (no Claude Design canvas yet; written from the design system README and the repo). Decisions that change behaviour:

- One modal alert (`AppAlertDialog`) in three phases, confirm, progress, failure, with no screen and no sheet. It never shows the chat's title, so App Lock has nothing to blank.
- Progress cannot be dismissed by Escape, the back gesture or a tap outside, only by Cancel (`PopScope(canPop: phase != progress)` in the alert); the confirmation can, except by a tap outside on iOS, where the barrier is not dismissible. Cancel and Close are `isDefault: true, filledOnMaterial: false`.
- One export at a time: while one runs, the row is disabled in every menu. The Mac and iPad menu bars keep the item and disable it for a chat without a profile (open question 1 of the brief; the other menus omit the row). Entry points: the header menu on every platform; the Mac sidebar row menu, the Mac toolbar "…" (compact windows only), the Chat menu (Mac and iPad) and the conversation window. The non-Mac sidebar row menu and the touch swipe sheet do not offer Copy transcript, so they do not offer Export for now (owner decision); the header menu is the entry off the Mac, and the two can get it later together with Copy transcript.
- After 10 s without the first byte the progress alert adds "Still waiting for Hermes." This is the one exception to the 10-second lost-answer rule; 30 s without a byte (the managed `Dio` `receiveTimeout`) ends as `lost`, a stall after bytes as `incomplete`, and the total stays five minutes (owner decision: 30 s of silence stays). A "Downloaded 12 MB" line, in the wording of `FileDownloadProgress`, shows the bytes received (kept by the owner).
- Menu placement after the local render review: the Export row sits directly after Copy Transcript in the Mac and iPad Chat menu (Find…, Pin, Rename…, Copy Transcript, Export Chat as JSON…, Archive, Delete…) and in the header menu (Copy transcript, Export chat as JSON…, then Rename, Pin, Archive, Delete). The Apple failure buttons are Close left, Try again right, and stack at large text and in German.
- A timeout is `lost` ("Couldn't confirm the export"); a connection that drops after bytes arrived is `incomplete`. Try again returns to the confirmation, never to a request.
- Failure kinds are one enum of nine shared by the widget and the controller: `gone`, `unsupported`, `profileMissing` (404), `profileInvalid` (400), `unreadable`, `lost`, `incomplete`, `offline` and `failed` (any other status, such as 500, 502, 504, 413, 422, or an unexpected error; Try again). The widget picks the 404 or 400 copy from the kind alone.
- A saved file shows the snack bar "Chat saved" (no path); a cancelled save sheet shows nothing.

## Not verified

No response was captured; headers and real bodies, the size of a long chat, whether an image part embeds data or a path, the exact 404/405 text on older servers, and `saveFile` on a physical iPhone and in the macOS sandbox are unchecked.
