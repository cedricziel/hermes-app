# Proposal

## Why

The agent writes files on the server: reports, code, images, exports. Today the app shows a file only when the agent attaches it to a reply with a `MEDIA:` path (`chat-media`). A report the agent saved but did not attach, a folder of generated images or the code it just changed cannot be seen from the phone, so the user has to ask the agent to attach each one, or open the dashboard in a browser.

Hermes already has the routes for this. Its own desktop app uses `GET /api/fs/list` for its remote folder picker and `GET /api/fs/read-text` for its preview pane. The app already downloads server files for attachments with `GET /api/files/download`, stages them in `MediaStore`, and opens, saves, previews (Quick Look) and drags them out. This change adds the missing piece: a way to browse.

## What Changes

- A **Files** page for a chat, opened from the chat (no new top-level tab): a row "Files" under "This session" in the Activity panel, an item in the chat header's menu, and View > Show Files on the Mac. It lists the chat's working folder, folders first, with the folder name and a path bar to go back up.
- A file opens a **preview**: text and code (with colours), Markdown (rendered, with a "Source" toggle), images, and PDF. Anything else, and anything the app cannot preview, shows its name, type and size with **Save** and **Open with…**.
- **Save** writes the file to the device (the system's save dialog); **Share** hands it to the share sheet on iOS and Android; **Open with…** uses the system's app. On the Mac the same file is a Quick Look target and drags out to Finder through the existing code.
- Files download to disk in a stream, never into memory, with progress and a Cancel; a file over 50 MB asks before it downloads.
- Hidden files (names starting with a dot) are hidden until the user chooses "Show hidden files". A file that may hold secrets (`.env`, keys, tokens, `.npmrc`, `.netrc` …) asks before it is previewed and is never previewed automatically.
- The page appears only when the server has the `/api/fs` routes; on an older server the entry is absent, not an error.
- Sign-out, App Lock and a server change drop the lists, and delete the downloaded files (existing `MediaStore.clear()`).

Non-goals (deliberately not in this change; each is a follow-up change, see design.md "Later"):

- Uploading a file from the device into the working folder.
- Deleting, renaming, moving or creating folders.
- Editing a file (`POST /api/fs/write-text`).
- Browsing outside the chat's working folder and its git root (the server would allow it; the app does not offer it).
- Searching file names or contents.
- "Files changed in this chat". The server has no list of them; deriving one from tool calls is a later change.
- A top-level Files tab, or a profile-wide files area (Hermes has none: the only profile-scoped root is the profile's working folder).
- Video and audio playback from the browser, and in-app PDF rendering. PDFs open in Quick Look (iOS, macOS) or the system viewer.
- Any new server route. Nothing here needs one.

## Capabilities

### New Capabilities

- `server-files`: reading a chat's working folder and files from the server, the browser and preview, saving and sharing, secrets and size handling, availability on old servers, and clearing on lock and sign-out.

### Modified Capabilities

None as spec deltas: the change reuses `chat-media`, `chat-attachments` and `mac-quick-look` behaviour and adds to them without changing what they require. It adds a streaming `MediaStore.stageDownload` and a path-based save, and the Quick Look panel also closes when App Lock locks (stated in `server-files`; the `mac-quick-look` spec says only sign-out, and task 3.3 files a follow-up delta for it).

## Impact

- Code: `chat/hermes_chat_repository.dart` and `ChatThread` (a `cwd` field), new `lib/src/files/` (repository, `ServerPath`, controller, models, `widgets/`), `lib/src/chat/media/media_store.dart` (a streaming `stageDownload`), `lib/src/api/hermes_api_client.dart` (only if the generated client cannot stream; see design.md), entry points in `chat/widgets/chat_header.dart`, `chat/activity/widgets/activity_panel.dart` and `macos/menu_layout.dart`, Widgetbook use cases, `design/web` if it mirrors the Activity panel.
- Dependencies: one syntax highlighter for code colours (task 4.1) and `share_plus` for Share (task 3.4), each chosen under the repo's pub.dev rule. No PDF or SVG package: PDFs open in the platform viewer and SVG shows as text.
- Backend: no new route and no server change. Uses `GET /api/fs/list`, `GET /api/fs/read-text`, `GET /api/fs/download`, `GET /api/fs/default-cwd`, `GET /api/fs/git-root`, and the session's stored `cwd` from `GET /api/sessions`.
- Delivery: four PRs (see tasks.md).
- Security and privacy: file names and contents are the user's own server data. They stay in memory and in the existing `MediaStore` cache (deleted on sign-out, swept after 24 h, now also dropped on App Lock close of the preview). The session goes in the request header, never in a URL (`?token=` is not used). The client never builds a server path by joining strings, sends only absolute paths the server itself returned, and applies its own secret-name check because the server skips it on SSH workspaces. No new storage of credentials.
- Observability: spans `files.list` (`outcome`, `entries` bucket), `files.preview` (`kind`, `size` bucket, `outcome`) and `files.download` (`size` bucket, `outcome` done | cancelled | failed | too_large) because each crosses the network; log events `files.unsupported` (once per connection) and `files.list_failed` / `files.download_failed` (`kind`) to count failures; breadcrumbs `files.opened` (`source`), `files.preview.opened` (`kind`), `files.saved` (`action` save | share | open), `files.secret.warned` and `files.hidden.toggled`. Fixed words and counts only; never a path, name, folder, profile or file content.
