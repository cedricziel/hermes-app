## Context

`attach-files-in-chat` adds `ChatAttachment` (name, kind, device path, server path, size) on `ChatMessage.attachments` and a pure parser for history rows. This change reuses that model for the agent's own files and adds a way to fetch bytes from the server. Verified against a live Hermes 0.21.1 backend:

- `GET /api/media?path=<abs>` returns `{"data_url": "data:image/png;base64,..."}`; it needs the header or bearer (not `?token=`), an image extension, a resolved path under Hermes' `images`, `screenshots` or `cache` directories (else 403), at most 25 MB (else 413), and 404 when missing.
- `GET /api/files/download?path=<abs>` streams raw bytes with `Content-Disposition: attachment`, up to 100 MB, header, bearer or `?token=`; sensitive names (`.env`, `config.yaml`, `auth.json`) are 403.
- Reply text is stored and streamed verbatim: `MEDIA:/abs/path` stays in the text of `message.delta` and `message.complete`. There is no structured media field.
- The agent's prompt for sessions with source `tui` (the default for `session.create`) says MEDIA tags are not intercepted, so the model may not emit them there; the `desktop` source's prompt tells it to write `MEDIA:/absolute/path`.

## Goals / Non-Goals

**Goals:**
- One display path for agent files, and for attachments restored from history.
- Nothing about a fetch failure breaks a message.

**Non-Goals:**
- Changing which sessions or sources the app creates unless the first task shows it is needed and safe.

## Decisions

- **Parse at mapping time, not at storage.** `ChatMessage.content` keeps the raw text so streaming and history stay simple; a pure `extractMedia(content)` returns visible text plus attachments and is used by the mapper. Tags are only read from whole tokens, and a trailing partial `MEDIA:` token is held back while streaming. Ids derive from the message id (`id-media-N`) so the chat controller can match them across updates.
- **Images: `/api/media` first, download route second.** Images under Hermes' media directories arrive as data URLs; images elsewhere (403) fall back to the download route and are decoded from bytes. Alternative: always the download route; rejected because it is a bigger transfer and no cheaper to implement, but it stays as the fallback.
- **Files: download route to the cache directory, then open.** Bytes stream to `<cache>/media/<hash of server path>/<name>` with the bearer header, so memory stays flat. The app never puts the token in a URL. Alternative: hand the download URL with `?token=` to the system; rejected because the token would leak into URLs, browser history and logs.
- **Calls through the generated client.** `getMedia` and the download route go through `authController.api!.raw`; if the generated method cannot stream to a file, the download uses the same managed `Dio` with `download`, so 401 refresh handling still applies. No hand-rolled client.
- **Plugins.** `open_file` opens a file with the system app on iOS, Android, macOS, Windows and Linux; `open_filex` was rejected because it is mobile only. `share_plus` shares and saves; 13.x does not resolve against our pinned `win32`, so it is pinned to `^12.0.2`. The image viewer is a plain `InteractiveViewer` route, since the zoom package on pub.dev has had no release since 2024.
- **State.** A small `MediaStore` (ChangeNotifier, provided next to the auth controller) owns an in-memory image cache with a size bound, the download futures keyed by server path (so two taps download once), and `clear()` for sign-out. It depends on an interface with a fake in `test/support/`.
- **Source.** First task: read Hermes' prompt builder and confirm what `tui` tells the model, and whether `session.create {source:'desktop'}` changes the session's listing or other behaviour. If a source change is needed it is a separate, spec'd decision and is not done in this change; the result is recorded in the PR.

Platforms: all five. Android needs no FileProvider entry for files in the app cache. macOS needs no extra entitlement (`network.client` is present). watchOS is not affected. Invariants: bearer auth and refresh go through the managed `Dio`; tokens never appear in URLs; telemetry untouched.

## Risks / Trade-offs

- If the model never writes `MEDIA:` tags in this app's sessions, part of this change shows only for history and user attachments; the parser is still correct and harmless.
- A path the server allows but this user has no right to read gets a 403 card, which is the right outcome.
- The cache can grow with use; it is cleared on sign-out only. A size-bound eviction is future work.
