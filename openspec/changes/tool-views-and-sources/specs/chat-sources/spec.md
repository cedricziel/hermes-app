# Spec Delta

## Purpose

Shows the pages a reply drew on as a row of sources under the reply, built from the turn's web search and browsing results.

## ADDED Requirements

### Requirement: Source collection

The app SHALL collect sources from the turn's `web_search` hits, `web_extract` results without an error and `browser_navigate` results that succeeded, over the assistant messages since the last user message. Opened pages SHALL come before search hits, each group in the order first seen. Other browser tools SHALL add nothing.

#### Scenario: Search then open

- **WHEN** a turn runs `web_search` with five hits and then `web_extract` on the second
- **THEN** the second hit comes first and the other four follow in order

#### Scenario: Reload from history

- **WHEN** the chat is opened from history and the turn is several assistant rows
- **THEN** the row shows the sources of all of them under the reply

### Requirement: De-duplication

Sources SHALL be unique by a normal form of the address: scheme and host lower-cased, a default port, a root trailing slash and the fragment dropped, the query kept. Only `http` and `https` addresses without embedded credentials SHALL count. The first title seen SHALL win, and a missing title SHALL be the host.

#### Scenario: Same page twice

- **WHEN** `https://Example.com/a#intro` and `https://example.com/a` are both found
- **THEN** one source shows, with the first title

#### Scenario: Credentials

- **WHEN** an address is `https://user:secret@example.com/`
- **THEN** it is not a source

### Requirement: When the row shows

The row SHALL appear under the reply's text, above its actions, once the reply is finished, stopped or ended in an error, and SHALL NOT appear while it streams. A turn with no source SHALL have no row and no placeholder.

#### Scenario: Streaming

- **WHEN** the reply is still arriving and a search has returned
- **THEN** no sources row shows yet

#### Scenario: No browsing

- **WHEN** the turn ran no web search or browsing
- **THEN** no row shows

### Requirement: Chips

Each source SHALL be a chip with a monogram tile, the title on one line and the host on one line, as a button of 44 pt on iOS and 48 dp elsewhere on touch, and 32 pt on a Mac. Three chips SHALL show on a phone and four on a desktop, with a "+N more" chip that expands the row in place and "Show fewer" that folds it. The row SHALL be named "Sources, N".

#### Scenario: Seven sources on a phone

- **WHEN** a turn has seven sources
- **THEN** three chips and "+4 more" show, and "+4 more" shows all seven with "Show fewer"

#### Scenario: Long title

- **WHEN** a title is longer than the chip
- **THEN** the title ends in an ellipsis and the host stays whole

### Requirement: Opening a source

A tap on a chip SHALL open its address in the system browser. A long press or secondary click SHALL offer Open in browser and Copy link. The app SHALL NOT request a favicon or any resource of the source's host to draw the row.

#### Scenario: Tap

- **WHEN** the user taps a chip
- **THEN** the address opens in the system browser and no other request is made

### Requirement: Untrusted titles

A source's title SHALL pass the hidden-character and well-formed-text rules and be cut at 120 characters. No address, title or host SHALL reach a breadcrumb, span or log.

#### Scenario: Bidirectional override

- **WHEN** a title holds a right-to-left override character
- **THEN** the character is drawn as a visible placeholder
