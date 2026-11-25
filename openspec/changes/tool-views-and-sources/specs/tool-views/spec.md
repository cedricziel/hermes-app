# Spec Delta

## Purpose

Gives an opened tool call card a view of its own for file reads and writes, opened pages, images and lists of rows, each as a registry entry, with the generic input and result as the fallback.

## ADDED Requirements

### Requirement: Registry entries

Each view SHALL be one `ToolBodyEntry` in `standardToolBodyEntries`, tried after the diff and the existing named views. The table entry, which serves any tool, SHALL come last. A view SHALL return no body for a result that is not the shape it expects, and the card SHALL then show its generic input and result.

#### Scenario: Unexpected shape

- **WHEN** a `read_file` result has no `content` text, or a content row that does not read `LINE|text`
- **THEN** the card shows its generic input and result and nothing throws

#### Scenario: A tool with its own view

- **WHEN** a `terminal` call returns a list of flat rows
- **THEN** the terminal view shows it, not the table

### Requirement: Code view

For `read_file` and `write_file` the card SHALL show the path with its start elided, the language from the path's extension, the code with a line gutter that is not selectable, and a Copy action that copies the text Hermes returned without the gutter. It SHALL give the numbers the result carries, so a read at an offset starts at that line.

#### Scenario: A read at an offset

- **WHEN** a `read_file` call with `offset` 2001 returns rows starting `2001|`
- **THEN** the gutter starts at 2001 and Copy copies the text after each bar

#### Scenario: Cut short

- **WHEN** the result has `truncated` true and no `truncated_by`
- **THEN** a warning note with an icon says which lines were shown and where the next read starts, without mentioning a character limit

#### Scenario: Cut by the size limit

- **WHEN** the result has `truncated_by` `bytes` and a `next_offset`
- **THEN** the note also says the server stopped at its size limit

#### Scenario: A repeated read

- **WHEN** the result is the dedup stub with `content_returned` false
- **THEN** the card shows the path and a note that Hermes did not read the file again

#### Scenario: A file with Windows line endings

- **WHEN** every row ends with a carriage return
- **THEN** the code view shows and Copy keeps the text as returned

#### Scenario: An empty file

- **WHEN** the result is `{content: "", hint}`
- **THEN** the card shows the path and "This file is empty.", not a blank code box

#### Scenario: A document

- **WHEN** the result has `extracted_document` true
- **THEN** a note says the text was taken from the document, it draws plain, and Copy copies the extracted text

#### Scenario: Masked secrets

- **WHEN** the content holds the prefix `«redacted`, as `«redacted:ghp_…»` or `«redacted-secret»`, or `[REDACTED PRIVATE KEY]`
- **THEN** a note says Hermes may have hidden passwords or keys in this text, and Copy copies it as returned

#### Scenario: A long line

- **WHEN** the result has `truncated_lines` true
- **THEN** a note says some long lines were cut by Hermes, and Copy copies them as returned

### Requirement: Write outcome

A `write_file` card SHALL show the content as sent, coloured as soon as the call runs, and a note for each outcome the result reports: bytes written, verified on disk, a lint error with its output, diagnostics, a warning. It SHALL NOT report a created folder, which Hermes' `dirs_created` does not tell. A refused write SHALL say "Not written." with the server's text and still show what was tried.

#### Scenario: Refused

- **WHEN** the result carries `error`
- **THEN** the card says "Not written.", shows the error text and shows the content under "What Hermes tried to write"

#### Scenario: Preparing and running

- **WHEN** the call is still preparing, the model has named the tool and sent no arguments
- **THEN** the card shows only its header, and once the call runs the path and the coloured content show under "Writing…"

### Requirement: Binary and image reads

A `read_file` result with `is_binary` or `is_image` true SHALL show the path and a note with Hermes' description and the size, even when it also carries `error`. It SHALL NOT draw, copy or log any base64 content.

#### Scenario: An ordinary read

- **WHEN** a result has `truncated`, `is_binary`, `is_image` and `not_found` all false
- **THEN** the card shows the code with no note about truncation or a binary file

#### Scenario: A binary file

- **WHEN** the result is `{is_binary: true, file_size, error}`
- **THEN** the card shows "Not a text file.", Hermes' description and the size, and no content

### Requirement: Link preview

For `browser_navigate` and `web_extract` the card SHALL show a card per page with a monogram tile, a title of at most two lines, the host and path and, for an extracted page, an excerpt. It SHALL NOT request a favicon, thumbnail or any other resource from the page's host.

#### Scenario: A page that cannot be read

- **WHEN** a `web_extract` result has `error` for one of its pages
- **THEN** that page's card has no tap and a note with an icon and "Couldn't read this page."

### Requirement: Opening a page

A page card SHALL open its address in the system browser, and offer Open in browser and Copy link in its press menu, for `http` and `https` addresses only. An address with embedded credentials SHALL show its host only, not open, and have Copy link copy it without the credentials.

#### Scenario: Credentials in the address

- **WHEN** an address is `https://user:secret@example.com/`
- **THEN** the card shows the host only, does not open, has no Open in browser in its press menu, and Copy link copies `https://example.com/`

#### Scenario: Another scheme

- **WHEN** an address is `ftp://files.example.com/a.txt`
- **THEN** the card is not tappable, has no press menu and says only web addresses open from here

### Requirement: Image gallery loading

An image whose source is a server path SHALL load through the media store. An image whose source is an address SHALL load only after the user taps it, only over `https` (a redirect to a non-`https` address is not followed), within 10 MB and 15 seconds, and SHALL otherwise show its alt text, size and host. Rendering a gallery SHALL make no request to any host other than the signed-in Hermes server.

#### Scenario: Not yet loaded

- **WHEN** a `browser_get_images` result lists an `https` image
- **THEN** its tile shows the alt text and the host and no request has been made

#### Scenario: Not secure

- **WHEN** the address is `http`
- **THEN** the tile says it is not secure, offers Open in browser and never loads it

### Requirement: Remote images in memory

A loaded remote image SHALL be held in memory only, never written to disk or staged for Quick Look or Save, and dropped, with its decoded frames, on sign-out, a server change and when App Lock covers the app. It SHALL open in the in-memory viewer.

#### Scenario: Sign-out

- **WHEN** the user signs out after loading a remote image
- **THEN** the image and its decoded frames are gone from memory and nothing was written to disk

### Requirement: Gallery layout

A gallery SHALL leave out images smaller than 32 px on either side and say how many it hid, keep a size of 0, show six tiles with "Show all N" for the rest, and fill two columns on a phone and more on a wider layout. One image SHALL be one tile at the aspect ratio of the call.

#### Scenario: Tracking pixels

- **WHEN** a page lists 14 images and 5 are under 32 px
- **THEN** the header says "9 images · 5 small ones hidden"

### Requirement: Table

A result that is a list of flat rows, or a map whose one large value is such a list, SHALL show as a table of at most eight columns and 50 rows at first, with a header that stays, rows of one line, numbers right-aligned and a way to show 50 more up to 500. A row with a nested value or an empty list SHALL NOT make a table; an empty list SHALL show the generic input and result, except a `search_files` answer with no match, which SHALL say "No matches".

#### Scenario: Search matches

- **WHEN** a `search_files` result has 12 matches as a path-grouped `matches_text` block
- **THEN** the card shows a table with the columns path, line and content and "12 matches · 3 columns"

#### Scenario: Few matches

- **WHEN** a `search_files` result has three `matches` of `{path, line, content}`
- **THEN** the same table shows

#### Scenario: A line that is not a row

- **WHEN** a `matches_text` block has a line that is neither a path line (non-empty, no leading space) nor a row of two spaces, a line number, a colon and the content
- **THEN** the card shows its generic input and result

#### Scenario: A tool with a view that declined

- **WHEN** a `browser_get_images` result is a list of flat rows but not the shape its own view reads
- **THEN** the card shows its generic input and result, not a table

#### Scenario: Nested value

- **WHEN** one row has an object as a value
- **THEN** the card shows its generic input and result

### Requirement: States

Every view SHALL draw its generating, running, complete, failed and unexpected-shape states, each failure with an icon and a word, never colour alone. A running state SHALL NOT use a shimmer.

#### Scenario: Running image

- **WHEN** an `image_generate` call is running
- **THEN** a dashed tile in the call's aspect ratio shows a spinner and "Generating image…"
