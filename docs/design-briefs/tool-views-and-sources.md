# Design brief: tool views and the sources row (change `tool-views-and-sources`)

For the catalog and screen work of #460 (new tool views) and #461 (sources). Read `openspec/changes/tool-views-and-sources/design.md` for the server facts, every state and the decisions with their reasons; this brief says what each piece is for, what to reuse and the exact words.

## Design (done)

Claude Design canvas "Hermes: Tool views and sources", built on the Hermes App design system: https://claude.ai/artifact/8VcVpSes4wZroG9K1ejGFJ (private; ask its owner for access). 13 artboards in three rows:

- iPhone, light: 1 `read_file` (complete, cut short, missing with similar files, binary, running, unexpected shape); 2 `write_file` (preparing, running, complete and verified, lint problem, refused, no content); 3 link previews (`browser_navigate` plain, with a bot warning, failed; `web_extract` with three pages one unreadable; another scheme; running); 4 image gallery (generating, loaded after a tap, failed, a grid of nine with loaded, unloaded, failed and not-secure tiles, a screenshot with its analysis); 5 table (search matches, 50 of 212 with the lower-bound note, eight of eleven columns, no matches, running, nested value); 6 sources row (collapsed, expanded, one source, streaming, stopped, none).
- Mac and Android, light: 7 the views in the 720 pt column; 8 the sources row on a Mac (one-line chips, the right-click menu, a narrow window); 9 the views and a sources row on Android.
- Dark and the largest text: 10 views on iPhone, dark; 11 sources on iPhone, dark (with a focused chip and the press menu); 12 views and sources on a Mac, dark; 13 the largest text size, drawn at 2x.

Where this brief and the canvas differ, the sections below follow the canvas except where "Corrections" says otherwise.

Decisions taken in the design pass (reasons are in design.md):

- Code view: path header (start elided), language tag, a non-selectable per-line gutter taken from the `LINE|text` rows, Copy that copies the text Hermes returned without numbers (a line Hermes cut stays cut, with a note). A write shows its content as sent, coloured as soon as it runs (the arguments arrive whole); while it only prepares, the header is all there is. Outcome notes are an icon and a word. A refused write still shows what was tried. A binary or image read shows only a note, never its content.
- Link preview: a monogram tile, never a favicon (a favicon request would tell a third-party host that the user's agent visited it, untapped). One card is one button that opens the system browser for `http` and `https` only. The page snapshot stays reachable in a collapsed "Page snapshot" disclosure, because a registry body replaces the generic result.
- Gallery: a server screenshot loads at once through `MediaStore`; an image address loads only on a tap, over `https`, within 10 MB and 15 s, held in memory only and dropped on sign-out, a server change and App Lock. Small images (under 32 px) are hidden and counted. Six tiles show, "Show all N" opens the rest. One image is one large tile. Generating is a dashed skeleton with a spinner and a `BusyBar`, no shimmer.
- Table: only for flat rows; eight columns, 50 rows and "Show 50 more" up to 500; the header stays; numbers right-aligned; null is an em dash; a long press or secondary click copies a row. The entry is last in the registry, so it never takes a tool with a view of its own.
- Sources: chips (monogram, title, host), not a list, below the finished reply and above its actions. Opened pages first, then search hits. Three on a phone, four on a desktop, "+N more" expands in place. A Mac chip is one line at 32 pt. The row never shows while the reply streams, and not at all without sources.

Corrections where the first proposal or this brief did not work:

- The gutter was first drawn as one column beside the text, which misaligns when a line wraps. The canvas still draws it so; the widget builds one row per source line, the number on its first visual row.
- On a Mac the one-line chip first shrank the host and the title together ("widgetb..."). The host is the trust signal, so the title gives way first; fixed in the canvas.
- On a 390 pt phone two chips per row cut a title near 22 characters (see board 6). That is accepted because the host stays whole and the full title is the chip's screen-reader label; the catalog decides whether a phone is better served by one full-width chip per row, and records it here.
- Review against the Hermes source found four wrong first guesses: `truncated` only means the read ended before the end of the file (the 100,000-character sentence is for `truncated_by: bytes`); Hermes cuts lines over 2,000 characters, so Copy copies what Hermes returned and a note says so; `dirs_created` is true for almost every write, so "Created the folder" is gone; `image_generate` can answer a server path, which loads through `MediaStore` like a screenshot.
- A second source check found that Hermes sends `search_files` with five or more matches as a lossless path-grouped text block, not a list, so the table reads that block back into rows (and shows a `matches` list for one to four); and that a binary `read_file` answers `{is_binary, file_size, error}` with no mime type or dimensions, so the binary note quotes Hermes' own description (board 1 was changed to match).
- The first table example named an invented tool. No tool other than `search_files` is known to answer flat rows at this revision, so the example is labelled "any tool whose result is a list of flat rows".
- The canvas draws the shared `ToolCallCard` and the design system's controls unscaled at the largest size, so board 13 is hand-scaled and indicative only.

Copy added by the design: "Cut short. Lines 1–2,000 of 5,320. The next read starts at line 2,001."; "The server stopped at its size limit."; "Some long lines were cut by Hermes."; "Hermes may have hidden passwords or keys in this text."; "This file is empty."; "Nothing at these lines."; "Text taken from the document."; "N results were held back by Hermes."; "Couldn't read this file."; "Similar files"; "Not a text file."; "The content is never shown here."; "Lines 1–9 of 400"; "Wrote 312 bytes. Checked on disk."; "Syntax check found a problem."; "Not written."; "What Hermes tried to write"; "Opening…"; "Reading…"; "Writing…"; "Searching…"; "86 interactive elements on the page"; "This page may block automated visitors."; "Couldn't open this page."; "Couldn't read this page."; "Not opened: only web addresses open from here"; "Page snapshot"; "Open in browser"; "Copy link"; "Copy row"; "Generating image…"; "Tap to load · cdn.example.com"; "Not secure. Open in browser"; "Couldn't load"; "Tap to try again"; "Too large to load here. Open in browser"; "No image made."; "N images · M small ones hidden"; "Load all"; "Show all N"; "What Hermes saw"; "N matches · M columns"; "Showing 50 of 212 matches"; "Show 50 more"; "Showing the first 500 of N"; "The search stopped early. There are at least N matches."; "+N more columns"; "No matches"; "Sources · 7"; "Source"; "+N more"; "Show fewer"; "Stopped".

## Who and why

Someone reading what their Hermes did: what it read, what it wrote, which pages it opened, what it found. The views make those results readable as what they are (code, a page, a picture, a list) instead of JSON. The sources row answers "what did this answer draw on" without opening tool cards. Voice: plain words, no protocol terms (`persisted-output`, `base64_content`, `next_offset` never reach the screen).

## Shared kit (reuse, do not invent)

`ToolBodyFrame` and `ToolBodyRegistry`, `ToolValueView` / `ToolValuePanel` (colour, hidden characters, Copy), `toolValueLanguage` and the Files palette, `BusyBar`, `NamedIconButton`, `StateMessage` for empty states, `DisclosureTile` (the "Page snapshot" and "Raw result" disclosures), `RowActions` and `showRingMenu` (the long-press and right-click menu), `AppBanner` for the warning notes where a note stands alone, `MediaStore` and `ImageViewerPage` (Quick Look on Apple, for server images only), `launchUrl` with `LaunchMode.externalApplication`, `wellFormedText` and `tool_hidden_chars.dart`, `AppIcons`, tokens only (`--h-warning`, `--h-error`, `--h-success`, `--h-surface-high`, `--h-code-*`). Status is an icon plus a word, never colour alone. Targets are 44 pt, 48 dp, 28 pt on a Mac.

## Widgets for the catalog (plain models, no controller)

| Widget                              | Model                                                        | Use cases                                                                                                                                                    | Closest existing                        |
| ----------------------------------- | ------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------ | --------------------------------------- |
| `CodeToolBody`                      | path, language, rows (number, text), meta line, notes, state | read complete, offset, cut short, missing, binary, image, running; write preparing, running, verified, lint, refused; fallback; long path, wrapped line, 2,000 lines | `ToolValueView`, `TerminalToolBody`     |
| `LinkPreviewCard`                   | title, host and path, excerpt, state, `onOpen`               | page, warning, failed, running, three pages one unreadable, long title, other scheme, credentials                                                            | `WebSearchToolBody` rows                |
| `ToolImageGallery`, `ToolImageTile` | source, alt, size, host, load state                          | one large, generating, failed, grid of nine in every tile state, show all, small hidden, screenshot with analysis                                            | `FilePreviews` image, attachment views  |
| `ToolRowsTable`                     | columns, rows, summary, notes                                | search matches, 50 and "Show 50 more", 500 cap, eight columns, nulls, numbers, empty, truncated, nested value, running                                       | none (Tag, grouped rows are not tables) |
| `SourcesRow`, `SourceChip`          | sources, expanded, callbacks                                 | one, three, seven collapsed and expanded, long titles, override character, stopped reply, narrow Mac window, press menu                                      | `Chip`-like attachment chips            |

New components needed (from the canvas, all token markup): code body with a gutter and the outcome note line, link card with a monogram tile, image tile with its states, table with a sticky header, source chip and its row. The press menu is not new: it is `showRingMenu` and `RowActions` (the canvas draws it by hand). The design system has `Tag`, `Chip`, `Banner` and `StateMessage`, which the canvas used where they fit; it has no table, no gallery tile and no card with a tile and two text lines.

## Differences by platform

iOS: 44 pt chips and tiles, a press menu from a long press, the in-memory viewer for an opened remote image (no Quick Look or Save: they need a staged file). Android: 48 dp targets, Material icons, the same layout and wording. macOS: 32 pt chips on one line, 28 pt Copy and rows, a right-click menu, four tiles across, the same in-memory viewer for a remote image (Quick Look and Save only for a server screenshot, as for chat images). Windows and Linux: Material look at 48 dp, the Mac's right-click menu. Not offered on the watch, in notifications or in the quick panel's compact reply.

## What was not checked

The claude.ai viewer, real devices, VoiceOver and TalkBack output, the Mac secondary-click menu, a remote image on a slow link, and the largest text size in the real widgets (the canvas is hand-scaled). Against a live backend: every tool shape is from source (design.md "Server surface"), so PR 0 records them first. Not every board was re-rendered after the last small edits: boards 5, 8 and 12 were re-published after the render (the invented tool name, the Mac chip host) and not looked at again.

Rendered locally in headless Chrome on a throwaway server of the canvas files: all 13 boards, looked at as contact sheets for boards 1 to 6 and board 12 in full.
