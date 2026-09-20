## 1. Verify the premise

- [ ] 1.1 Read Hermes' prompt builder for the `tui` and `desktop` sources and record whether the model emits `MEDIA:` tags in the sessions this app creates, and what a source change would affect; do not change the source in this PR
- [ ] 1.2 Confirm against the dev backend, without a model call, that `/api/media` and `/api/files/download` answer as the design says using the bearer header

## 2. Parsing and model

- [ ] 2.1 Add `extractMedia` (visible text plus attachments, partial trailing tag held back) with tests for ordering, relative paths, streaming and tag-only messages
- [ ] 2.2 Use it in `chat_message_mapper.dart` with ids `id-media-N`

## 3. Fetching

- [ ] 3.1 Add the media fetch interface and its Hermes implementation: image via `/api/media` with the download route as fallback; file via the download route to the cache directory; error mapping per the spec
- [ ] 3.2 Add `MediaStore` with an image cache, download deduplication and `clear()`; call `clear()` on sign-out; add a fake for tests
- [ ] 3.3 Add the fake server routes for both endpoints

## 4. UI

- [ ] 4.1 Image thumbnail with placeholder and failure state; full-screen viewer with zoom, share and close
- [ ] 4.2 File card: download state, open with `open_file`, share and save with `share_plus`, error messages and retry
- [ ] 4.3 Attachments restored from history use the same widgets

## 5. Verification and specs

- [ ] 5.1 Widget tests for every scenario in the spec
- [ ] 5.2 Extend `test/real_backend_contract_test.dart` for both endpoints
- [ ] 5.3 Try it in the running macOS app against the dev backend with a seeded file and image (verify-in-app skill); no model calls
- [ ] 5.4 Archive this change so the specs update
