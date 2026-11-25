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

For `read_file` and `write_file` the card SHALL show the path with its start elided, the language from the path's extension, the code with a line gutter that is not selectable, and a Copy action that copies the file's text without the gutter. It SHALL give the numbers the result carries, so a read at an offset starts at that line.

#### Scenario: A read at an offset

- **WHEN** a `read_file` call with `offset` 2001 returns rows starting `  2001|`
- **THEN** the gutter starts at 2001 and Copy copies the text after each bar

#### Scenario: Cut short

- **WHEN** the result carries `truncated` and `next_offset`
- **THEN** a warning note with an icon says where the read stopped and where the next one starts

### Requirement: Write outcome

A `write_file` card SHALL show the content as sent, coloured as soon as the call runs, and a note for each outcome the result reports: bytes written, verified on disk, a lint error with its output, diagnostics, a warning. A refused write SHALL say "Not written." with the server's text and still show what was tried.

#### Scenario: Refused

- **WHEN** the result carries `error`
- **THEN** the card says "Not written.", shows the error text and shows the content under "What Hermes tried to write"

#### Scenario: Preparing and running

- **WHEN** the call is still preparing, the model has named the tool and sent no arguments
- **THEN** the card shows only its header, and once the call runs the path and the coloured content show under "Writing…"

### Requirement: Binary and image reads

A `read_file` result that is binary or an image SHALL show the path and a note with its type, dimensions and size. It SHALL NOT draw, copy or log the base64 content.

#### Scenario: An image read

- **WHEN** the result carries `is_image` and `base64_content`
- **THEN** the card shows "Not a text file." and no picture

### Requirement: Link preview

For `browser_navigate` and `web_extract` the card SHALL show a card per page with a monogram tile, a title of at most two lines, the host and path and, for an extracted page, an excerpt. The card SHALL open the address in the system browser for `http` and `https` only, and SHALL NOT request a favicon, thumbnail or any other resource from the page's host.

#### Scenario: A page that cannot be read

- **WHEN** a `web_extract` result has `error` for one of its pages
- **THEN** that page's card has no tap and a note with an icon and "Couldn't read this page."

#### Scenario: Another scheme

- **WHEN** an address is `ftp://files.example.com/a.txt`
- **THEN** the card is not tappable and says only web addresses open from here

### Requirement: Image gallery loading

An image whose source is a server path SHALL load through the media store. An image whose source is an address SHALL load only after the user taps it, only over `https`, within 10 MB and 15 seconds, and SHALL otherwise show its alt text, size and host. A loaded remote image SHALL be held in memory only, never written to disk, and dropped on sign-out, a server change and when App Lock covers the app. Rendering a gallery SHALL make no request to any host.

#### Scenario: Not yet loaded

- **WHEN** a `browser_get_images` result lists an `https` image
- **THEN** its tile shows the alt text and the host and no request has been made

#### Scenario: Not secure

- **WHEN** the address is `http`
- **THEN** the tile says it is not secure, offers Open in browser and never loads it

### Requirement: Gallery layout

A gallery SHALL leave out images smaller than 32 px on either side and say how many it hid, keep a size of 0, show six tiles with "Show all N" for the rest, and fill two columns on a phone and more on a wider layout. One image SHALL be one tile at the aspect ratio of the call.

#### Scenario: Tracking pixels

- **WHEN** a page lists 14 images and 5 are under 32 px
- **THEN** the header says "9 images · 5 small ones hidden"

### Requirement: Table

A result that is a list of flat rows, or a map whose one large value is such a list, SHALL show as a table of at most eight columns and 50 rows at first, with a header that stays, rows of one line, numbers right-aligned and a way to show 50 more up to 500. A row with a nested value or an empty list SHALL NOT make a table.

#### Scenario: Search matches

- **WHEN** a `search_files` result has 12 `matches` of `{path, line, content}`
- **THEN** the card shows a table with the columns path, line and content and "12 matches · 3 columns"

#### Scenario: Nested value

- **WHEN** one row has an object as a value
- **THEN** the card shows its generic input and result

### Requirement: States

Every view SHALL draw its generating, running, complete, failed and unexpected-shape states, each failure with an icon and a word, never colour alone. A running state SHALL NOT use a shimmer.

#### Scenario: Running image

- **WHEN** an `image_generate` call is running
- **THEN** a dashed tile in the call's aspect ratio shows a spinner and "Generating image…"
