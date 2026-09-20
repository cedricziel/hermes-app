## Why

Attached files show as chips in the composer, but only their names reach Hermes (#183), so the agent cannot read them. Users expect an attached image or document to be something the agent can actually use.

## What Changes

- On send, upload each attachment to the session before the prompt: images through the gateway's image attach call, so vision-capable models see the pixels; other files through its file attach call, with the returned `@file:` reference added to the prompt text.
- Show a sent message's attachments in the transcript as an image thumbnail or a file card with name and size, including after the thread is reloaded from history.
- Reloading history no longer fails on rows whose content is a list (native-vision turns) and reads `@image:` and `@file:` references and "[User attached file: …]" lines back as attachments.
- Refuse attachments over 25 MB up front, and say so when the server cannot take attachments or an upload fails.
- **BREAKING (behaviour):** the "names only" wording and the composer note "Only the file names are sent, not their contents." go away.

Non-goals: new attachment sources (see `add-attachment-sources`), the agent's own files in replies (see `render-chat-media`), PDF page rendering, and detaching an attachment already uploaded in an earlier turn.

## Capabilities

### New Capabilities
- `chat-attachments`: how attachments are sent with a message, shown in the transcript and restored from history.

### Modified Capabilities
- `chat`: the "Shared content" requirement no longer says files are only named.
- `sharing`: the "Shared files appear as removable attachments" requirement no longer says only names are sent.

## Impact

- Code: `ChatTransport.send` takes attachments; the gateway transport uploads them; the message model, mapper and repository learn about attachments.
- Backend contract: gateway RPC `image.attach_bytes` and `file.attach` (present in Hermes 0.21.1, checked against a live backend). Older servers answer method-not-found.
- Security and privacy: the user's chosen file contents now leave the device, to the server they signed in to, over the existing authenticated socket. Nothing is written to secure storage or telemetry, and file names and contents are never put in telemetry.
- Telemetry: none.
