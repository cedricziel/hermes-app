# Tasks

Design (done): canvas published, local render reviewed

Canvas: https://claude.ai/artifact/8VcVpSes4wZroG9K1ejGFJ (private; ask its owner for access). 13 boards: `read_file`, `write_file`, link previews, gallery, table and sources row on iPhone, light; tool views and sources on Mac, light; sources on Mac, light; tool views and sources on Android; tool views on iPhone, dark; sources on iPhone, dark; tool views and sources on Mac, dark; the largest text size. Checked in a local render, not in the claude.ai viewer. The brief is `docs/design-briefs/tool-views-and-sources.md`.

Five implementation PRs after a contract PR, each under about 500 changed lines, one Dart PR at a time. The catalog comes first in each (`component-catalog` skill): the widget is a plain model with use cases in both themes, phone and desktop, before the registry entry or any screen wiring.

## 0. PR 0 - `test(chat): record the tool result shapes the views read`

- [ ] 0.1 Record, against `scripts/dev-backend.sh` (never the real `~/.hermes`) on Hermes `d923a5eb`, the result bodies of `read_file` (a short file, an offset read, a missing file with `similar_files`, a repeated read for the dedup stub), `write_file` (a new file, a lint error, a refusal), `search_files` (one to four matches, five or more so it densifies, none, truncated) with the scripted model of `test/real_backend_contract_test.dart`, and add them as fixtures with the revision noted. Browser, image and vision tools need a browser or a provider and are recorded only if the verify environment has them, `browser_vision` included with whether its `screenshot_path` is servable by `/api/media` or `/api/files/download`; otherwise the design.md "Server surface" rows stay marked as read from source. Update the "Unknown" list in design.md with what the recording settles (spill text, `write_file` diff, `search_files` densify, compaction of tool rows in history). Acceptance: the fixtures decode, and a test asserts each key the views read.

## 1. PR 1 - `feat(chat): code view for read_file and write_file`

Files: `lib/src/chat/widgets/code_tool_body.dart` (`CodeToolBody`, plain model: path, language, rows, meta line, notes, state), `lib/src/chat/read_file_result.dart` and `write_file_result.dart` (pure parsers from a `ToolCall`, no widget), two entries in `tool_call_bodies.dart`, strings in `app_en.arb` / `app_de.arb` under the chat area anchor.

Catalog use cases (`widgetbook/code_tool_body_use_cases.dart`): read complete, read at an offset, read cut short, read missing with similar files, binary, image, running, write preparing (header only), write running (content shown, "Writing…"), write complete verified, write with lint error, write refused, unexpected shape (the fallback), a long path, a wrapped long line, 2,000 lines, German, largest text; iPhone, Android, Mac, light and dark.

Acceptance tests (written first): `test/read_file_result_test.dart` (an ordinary read with `truncated`, `is_binary`, `is_image` and `not_found` all false shows code and no note, a JSON text in `result` with a null `resultData` is decoded, a gutter per row, the offset's numbers, a row that fails the pattern returns null, `is_binary` wins over `error`, `base64_content` never in the model, `truncated` without `truncated_by` has no character sentence, `truncated_lines` gives the long-line note, `dirs_created` shows nothing, `extracted_document` gives the note and plain text, content with `«redacted:ghp_…»` or `«redacted-secret»` or `[REDACTED PRIVATE KEY]` (with a gap in the numbers) gets the masked-text note and a bare `***` does not, a row ending in `\r` and a row holding U+2028 still parse, an empty `content` gives "This file is empty."), `test/code_tool_body_test.dart` (Copy copies the text without numbers, notes carry an icon and a word, the gutter is not selectable, a refused write shows what was tried), `test/tool_call_card_test.dart` (the registry serves `read_file` and `write_file`, a malformed result falls back and does not throw, the diff entry still wins for a call with a diff). Revert-the-fix: drop the gutter-pattern check and the malformed test fails.

- [x] 1.1 Catalog first: `CodeToolBody` as a plain model with every use case above, in both themes, phone and desktop (`widgetbook/code_tool_body_use_cases.dart`). The preparing state is the card's own header, because the registry builds no body for a call still being written (the card header already says "Preparing…").
- [x] 1.2 The pure parsers `read_file_result.dart` and `write_file_result.dart`.
- [x] 1.3 The two registry entries and the strings in `app_en.arb` and `app_de.arb`.
- [x] 1.4 The acceptance tests above, built from fixtures read from the Hermes source at `d923a5eb` (`test/support/code_tool_fixtures.dart`), not recorded; PR 0 replaces them with recorded ones.

## 2. PR 2 - `feat(chat): link preview cards for pages the agent opened`

Files: `lib/src/chat/widgets/link_preview_card.dart` (`LinkPreviewCard`, plain model: title, host and path, excerpt, state, `onOpen`), `lib/src/chat/page_link.dart` (pure: address checks, host and path split, monogram letter, scheme and credentials rules; shared with PR 5), `link_tool_bodies` entries for `browser_navigate` and `web_extract`, strings.

Catalog use cases (`widgetbook/link_preview_use_cases.dart`): page, page with a warning note, failed, running, three pages one unreadable, long title, long address, no spaces in a title, another scheme, credentials in the address, snapshot disclosure open; Apple, Material, Mac; light, dark; largest text.

- [x] 2.1 Catalog first: `LinkPreviewCard` as a plain model with every use case above (`widgetbook/link_preview_use_cases.dart`), in both themes.
- [x] 2.2 The pure address rules `page_link.dart`.
- [x] 2.3 The registry entries for `browser_navigate` and `web_extract` (`widgets/link_tool_bodies.dart`) and the strings in `app_en.arb` and `app_de.arb`.
- [x] 2.4 The acceptance tests and the `arch.chat-network-image` guard below, built from fixtures read from the Hermes source at `d923a5eb` (`test/support/link_tool_fixtures.dart`), not recorded; PR 0 replaces them with recorded ones.

Acceptance tests: `test/page_link_test.dart` (only `http` and `https` open, credentials make an address not open and never show, host and path split, an IDN host), `test/link_preview_card_test.dart` (a tap calls `onOpen` with the address, a failed page has no tap), and a test with a fake HTTP client or `HttpOverrides` that rendering the card makes no request, and that the press menu of an address with credentials, or of a non-web address, has neither Open in browser nor a Copy link that carries the credentials. Add an `arch.*` guard in `test/architecture/` that fails on `Image.network` or `NetworkImage` under `lib/src/chat/` outside the gallery's loader, naming that loader as the replacement (the mechanical check for "no request without a tap"; the baseline starts empty).

## 3. PR 3 - `feat(chat): image gallery for found and generated images`

Files: `lib/src/chat/widgets/tool_image_gallery.dart` and `tool_image_tile.dart` (plain models: source (server path or address), alt, size, host, load state), `lib/src/chat/tool_image_loader.dart` (the one place a remote image is requested: `https` only, 10 MB and 15 s bounds, no credentials, decoded at tile size, held in memory only (its keys evicted from `PaintingBinding.imageCache` too) and dropped on sign-out, a server change and App Lock, outcome to a breadcrumb), entries for `browser_get_images`, `image_generate`, `browser_vision`, strings.

Catalog use cases (`widgetbook/tool_image_gallery_use_cases.dart`): one image large, generating skeleton, failed, a grid of nine with loaded, unloaded, failed, not-secure and too-large tiles, "Show all", small images hidden, no alt text, long alt text, a screenshot with the analysis; phone, tablet and desktop widths; light and dark; largest text; reduced motion.

Acceptance tests: `test/tool_image_gallery_test.dart` (the 32 px rule and a size of 0 kept, six tiles then "Show all", rendering makes no request except the media-store fetch of a server path, `http` never loads, a tap loads once, a failed load is offered again by a tap and not retried alone, a screenshot path and an absolute path in an `image_generate` result go through `MediaStore`, and a path the server refuses is "Couldn't load"), `test/tool_image_loader_test.dart` (size and time bounds with a fake adapter and a fake clock, no `Authorization` header sent, a redirect to `http` is not followed, the loader's cache and its keys in `PaintingBinding.imageCache` are empty after sign-out, a server change and an App Lock cover, nothing written to disk, and opening a remote image uses the in-memory viewer, never `stageBytes`). The new guard of PR 2 is the check that no other call site requests an image. Add the image-load flow to `test/privacy/telemetry_sentinel_test.dart` with a sentinel in the address, host and alt text, which must appear in no breadcrumb, span, log or print.

- [x] 3.1 Catalog first: `ToolImageGallery` and `ToolImageTile` as plain models with every use case above, in both themes, at phone, tablet and desktop widths (`widgetbook/tool_image_gallery_use_cases.dart`).
- [x] 3.2 `tool_image_loader.dart`, provided where sign-out and App Lock reach it (`app_lock_providers.dart`; a conversation window has its own), and the `raw-dio` allowlist entry for it.
- [x] 3.3 The entries for `browser_get_images`, `image_generate` and `browser_vision` (`widgets/tool_image_bodies.dart`) and the strings in `app_en.arb` and `app_de.arb`.
- [x] 3.4 The acceptance tests and the sentinel flow above, built from fixtures read from the Hermes source at `d923a5eb` (`test/support/image_tool_fixtures.dart`), not recorded; PR 0 replaces them with recorded ones. A server screenshot opens in `ImageViewerPage` with Save, not Quick Look on iOS.

## 4. PR 4 - `feat(chat): table for a result that is a list of rows`

Files: `lib/src/chat/widgets/tool_rows_table.dart` (plain model: columns, rows, summary, notes), `lib/src/chat/rows_result.dart` (pure: the flat-rows predicate, the column order, the `search_files` mapping from `matches` and from the path-grouped `matches_text`), the last registry entry, strings.

Catalog use cases (`widgetbook/tool_rows_table_use_cases.dart`): search matches, 50 rows and "Show 50 more", the 500 cap, eight columns and "+3 more columns", nulls and booleans, numbers, a long cell, wide enough to scroll on a phone, fits on a desktop, empty ("No matches"), truncated search with the lower-bound note, a nested value (the fallback), running; light and dark; largest text.

Acceptance tests: `test/rows_result_test.dart` (a list of flat maps is a table, a nested value is not, an empty list is not, a map with one large list of maps is, a path-grouped `matches_text` of 12 matches becomes 12 rows, a block with a stray line or another `matches_format` is not a table, a hit whose content holds `\r` or U+2028 still parses, `{total_count: 0}` is "No matches", `[]` from another tool is not a table, `_omitted` gives the held-back note, `_warning` and `_hint` show as notes, a `files` or `counts` answer falls back, `matches` with three rows is, the first row orders the columns), `test/tool_rows_table_test.dart` (the header stays while rows scroll, numbers right-aligned, a screen reader gets row and column names, Copy row copies JSON), `test/tool_call_card_test.dart` (the table entry is last, a `terminal` call keeps the terminal view, and a `browser_get_images` or `web_extract` call whose own view declines a list of flat rows falls back to the generic view, not the table).

## 5. PR 5 - `feat(chat): sources row under a reply`

Files: `lib/src/chat/sources/turn_sources.dart` (pure: collect from a turn's calls, opened before search hits, normal form, de-duplication; reuses the `web_search` parse and `page_link.dart`), `lib/src/chat/widgets/sources_row.dart` (plain model: sources, expanded, callbacks), the wiring where the reply's text is drawn (`chat_message_mapper.dart` and the message builder in `chat_builders.dart`), strings, breadcrumbs `chat.sources.expanded` and `chat.sources.opened`.

Catalog use cases (`widgetbook/sources_row_use_cases.dart`): one source, three, seven collapsed and expanded, long titles, a bare host, a title with a bidirectional override, a row under a stopped reply, Apple, Material, Mac, a narrow Mac window, light and dark, largest text, with the press menu open.

Acceptance tests: `test/turn_sources_test.dart` (opened pages first, search hits after, de-duplication across `Example.com/a#x` and `example.com/a`, credentials excluded, other schemes excluded, `browser_snapshot` adds nothing, an errored `web_extract` page adds nothing, the first title wins), a history test with the repository mapping that a turn of three assistant rows shows one row with all their sources and that a reload equals the live turn, `test/sources_row_test.dart` (a tap opens the address and makes no other request, "+N more" expands in place, the host is never elided before the title, no row for no sources and none while streaming). Add the sources row's flow (expand and open, with a sentinel in a title, host and address) to `test/privacy/telemetry_sentinel_test.dart`. Revert-the-fix: collect over one message only and the history test fails.

## Not verified

The slices are built from a canvas and source reading. Each needs `scripts/verify.sh app` or `verify-in-app` against a throwaway Hermes with a scripted model for the file and search tools; the browser, image and vision views are verified on a device with a real browser tool and an image provider, or are listed under "Not verified on a device" in their PRs.
