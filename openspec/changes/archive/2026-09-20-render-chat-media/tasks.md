## 1. Verify the premise

- [x] 1.1 Read Hermes' prompt builder for the `tui` and `desktop` sources and record whether the model emits `MEDIA:` tags in the sessions this app creates, and what a source change would affect; do not change the source in this PR (recorded in design.md, Risks)
- [x] 1.2 Confirm against the dev backend, without a model call, that `/api/media` and `/api/files/download` answer as the design says (the contract test in 5.2 does, and it ran green against Hermes 0.21.1)

## 2. Parsing and model

- [x] 2.1 Add `extractMedia` (visible text plus attachments, partial trailing tag held back) with tests for ordering, relative paths, streaming and tag-only messages
- [x] 2.2 Use it in `chat_message_mapper.dart` with ids `id-media-N`

## 3. Fetching

- [x] 3.1 Add the media fetch interface and its Hermes implementation: image via `/api/media` with the download route as fallback; file via the download route as bytes; error mapping per the spec
- [x] 3.2 Add `MediaStore` with an image cache, download deduplication, a file cache directory and `clear()`; add `AuthController.signedOut` and call `clear()` from it
- [x] 3.3 Add fake server routes for both endpoints (`onMedia`, `onDownload`, `onDownloadFailure` in `test/support/fake_hermes_server.dart`) and a fake for the system actions

## 4. UI

- [x] 4.1 Image thumbnail with placeholder and failure state; full-screen viewer with zoom, save and close
- [x] 4.2 File card: download state, open with `open_file`, save with the file picker's save dialog, error messages and retry
- [x] 4.3 Attachments restored from history use the same widgets

## 5. Verification and specs

- [x] 5.1 Widget tests for every scenario in the spec
- [x] 5.2 Extend `test/real_backend_contract_test.dart` for both endpoints
- [x] 5.3 Try it in the running macOS app against the dev backend with a seeded file and image (verify-in-app skill); no model calls
- [x] 5.4 Archive this change so the specs update
