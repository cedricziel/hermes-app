# Proposal

## Why

An opened tool card shows a view of its own for four tools (terminal, web search, todo, memory) and a diff. Every other result is the card's raw input and result text. The files the agent reads and writes, the pages it opens, the images it finds or makes and the lists it gets back are the most common results and read worst as text (#460). When a reply is built on a web search or browsing, the only way to see what it drew on is to open each tool card (#461).

`ToolBodyRegistry` (#1378) made a new tool view one entry. This change is the design for the views that use it and for the sources row, so the build can start in the catalog.

## What Changes

- Four new tool views as registry entries, each a plain-model widget with catalog use cases first:
  - **Code view** for `read_file` and `write_file`: path header, language colours, a line gutter, Copy.
  - **Link preview** for `browser_navigate` and `web_extract`: a card per page with title, host and an excerpt.
  - **Image gallery** for `browser_get_images`, `image_generate` and `browser_vision`: tiles, one image large.
  - **Table** for a result that is a list of flat rows, and for `search_files` matches.
- A **Sources row** under a finished reply, built from the turn's `web_search`, `web_extract` and `browser_navigate` results, de-duplicated by address, shown as chips.
- Every view has its generating, running, complete, failed and unexpected-shape states. A result that is not the shape a view expects falls back to the generic input and result (already the registry's rule).

## Non-goals

- Inline citation markers inside the prose (Hermes does not emit them).
- Editing, saving or opening a file read by `read_file` (the Files page does that).
- A new view for `vision_analyze` and `video_analyze` (their result shape is not known at the pinned revision; see design.md).
- Sorting, filtering or exporting a table.
- Fetching favicons, page thumbnails or Open Graph images: the app never asks a third-party host for anything the user did not tap.
- Rewriting `WebSearchToolBody`; it keeps its own body, and the sources row reads the same parsed hits.
- A new server route. Nothing here needs one.

## Security and privacy impact

The views show text and addresses the server sent. The one new network path is a remote image the user taps to load (`https` only, size and time bounded, no credentials sent, held in memory only, never written to disk, and dropped on sign-out, a server change and when App Lock covers the app; a server screenshot goes through `MediaStore` like any `MEDIA:` file, which clears on sign-out; App Lock's `clearFileDownloads` leaves chat attachments alone, so the screenshot is unchanged by this change). Page and file text is untrusted: every string passes `wellFormedText` and the hidden-character rule of `tool_hidden_chars.dart`. A link opens only for `http` and `https` and never with embedded credentials. No server address, token or message text reaches a breadcrumb, span or log.

## Observability

Breadcrumbs only, fixed names and counts, through `Breadcrumbs`: `sources_expand` (count), `sources_open` (count of sources in the row), `tool_image_load` (outcome: `ok`, `failed`, `too_large`, `insecure`). No span: nothing here takes time that crosses a boundary except the image load, whose outcome the breadcrumb already carries. No log event: nothing here fails in a way an operator would count.

## Design pass

Claude Design canvas "Hermes: Tool views and sources": https://claude.ai/artifact/8VcVpSes4wZroG9K1ejGFJ (private; ask its owner for access). The brief is `docs/design-briefs/tool-views-and-sources.md`; the facts and states are in `design.md`.
