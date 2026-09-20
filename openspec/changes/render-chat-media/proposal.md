## Why

Hermes sends files back by writing `MEDIA:<path>` in its reply: screenshots, generated images, documents, speech audio. The app shows that as literal text, and a file the user attached in an earlier session shows only as a name. Users cannot see or keep what the agent made.

## What Changes

- Read `MEDIA:<absolute path>` tags out of assistant messages, hide them from the visible text, and show each as an attachment after the text.
- Show images inline and open them full screen with zoom. Show any other file as a card that downloads on tap and opens in the system's app, with a share and save action.
- Show attachments restored from history, which carry a server path, the same way.
- Say plainly when a file cannot be fetched (gone, not allowed, too large), instead of showing a broken bubble.
- Delete downloaded and cached media when the user signs out.

Non-goals: playing audio or video inside the app (they open in the system player), browsing the server's files, editing or deleting server files, and downloading files whose only known path is relative to the session workspace.

## Capabilities

### New Capabilities
- `chat-media`: how files the agent returns, and attachments restored from history, are shown, opened and saved.

### Modified Capabilities

## Impact

- New dependencies `open_file` (open a downloaded file in the system app, all five platforms) and `share_plus` (share or save, pinned to 12.x because 13.x needs a newer `win32` than `flutter_secure_storage` allows).
- Backend contract: `GET /api/media?path=` (image data URL; image extensions under Hermes' image, screenshot and cache directories; 25 MB) and `GET /api/files/download?path=` (any file up to 100 MB; header or bearer auth), both with absolute paths.
- Security and privacy: files are fetched with the existing bearer token and stored under the app's cache directory only, never in secure storage or preferences. The `?token=` query form is not used, so the token stays out of URLs and logs. The cache is deleted on sign-out. File names and paths are never put in telemetry.
- Telemetry: none.
- Depends on `attach-files-in-chat` (its `ChatAttachment` model and history parser).
