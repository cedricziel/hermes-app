## Context

Sending goes through `ChatTransport.send`, and the gateway transport does `session.create` or `session.resume` and then `prompt.submit` on one websocket. Attachments today live only in the chat screen as `SharedFile`s and are turned into a "names only" line of text. Checked against a live Hermes 0.21.1 backend:

- `image.attach_bytes {session_id, content_base64, filename}` queues an image on the session; the next `prompt.submit` takes the whole queue and sends it as image parts. Cap 25 MB decoded. Errors: 4016 unsupported extension, 4017 bad base64, 4018 too large, 4001 unknown session.
- `file.attach {session_id, name, data_url}` stages any file in the session workspace and returns `ref_text` (`@file:<path>`), which the agent reads from the prompt text.
- User rows are stored as text plus `@image:<abs path>` lines; a native-vision turn comes back from `GET /api/sessions/{id}/messages` with `content` as a list of `text` and `image_url` parts. `hermes_chat_repository.dart` casts `content` to `String` and would throw on that.

## Goals / Non-Goals

**Goals:**
- Attachments reach the agent with no extra round trip for the user.
- Sent and reloaded messages look the same.

**Non-Goals:**
- Upload progress bars, resumable uploads, or an upload before the user presses send.

## Decisions

- **Gateway attach RPCs, not `POST /api/files/upload-stream`.** The upload route needs an absolute server path, and the client cannot know `HERMES_HOME`, the session directory or a locked root. The attach RPCs pick the location, return the reference the agent needs, and ride the socket that is already open. Alternative: upload-stream to a guessed path plus a `[User attached file: <path>]` line; rejected as fragile.
- **Attach inside `send`.** `ChatTransport.send` gains `List<OutgoingAttachment> attachments` (name, kind, a `Future<Uint8List> Function()` reader, mime type). After the session is created or resumed and before `prompt.submit`, the transport attaches each one and appends the `ref_text` values to the text. One place owns the session lifecycle, and a failed attach ends the stream with an error the existing error path shows. Alternative: a separate uploader called from the screen; rejected because it needs a session before send and duplicates session handling.
- **Read bytes late.** Files are read only when sent, not when picked, so a large pick costs nothing until it is used, and the size check uses `File.length()`.
- **Failure cleanup.** If a later attachment fails after images were queued, the transport calls `image.detach` for those it queued, best effort, so the next send does not carry them.
- **Model.** `ChatAttachment {name, kind (image or file), path, remotePath, size}` lives on `ChatMessage.attachments`. The mapper emits one message per attachment before the text: `flutter_chat_core`'s `ImageMessage` and `FileMessage` where the package builder fits, and a custom builder otherwise. `path` is the device path of a file the user picked, used for the local thumbnail; `remotePath` is the server path read from history, used later by `render-chat-media`.
- **History parsing.** A pure function turns a stored row's `content` (string or list) into text plus attachments. Lines that consist only of `@image:<path>`, `@file:<path>` or `[User attached file: <path>]` become attachments; anything else stays text. A reloaded image with no local file shows its name in a card until `render-chat-media` can fetch it, except that inline `image_url` data URLs are decoded and shown.
- **Old servers.** JSON-RPC method-not-found maps to one friendly message; there is no names-only fallback, so a user never believes a file was read when it was not.

Platforms: all; no native change. Invariants: authentication and token handling untouched; the new calls go over the existing gateway socket.

## Risks / Trade-offs

- Base64 over the websocket costs 33% more bytes and holds the file in memory once. The 25 MB cap bounds it; a streaming path would need a server change.
- Images the server rejects as images (for example HEIC) fall back to `file.attach`, so the model may not see them as pixels; the agent still gets the file.
- Stored `@file:` references are relative to the session workspace, so a reloaded file card cannot be downloaded without more information; `render-chat-media` deals with downloads for absolute paths only.
