## Purpose

Defines how the app shows files Hermes returns in its replies, and attachments restored from history, and how the user opens and keeps them.

## ADDED Requirements

### Requirement: Media tags become attachments

The system SHALL read each `MEDIA:<absolute path>` tag in an assistant message, remove it from the visible text, and show the file it names as an attachment after the text, in the order the tags appear. A path named twice SHALL show once. Only tags whose path is absolute SHALL be read, and none inside code; other text SHALL be left as written. While a reply is streaming, a tag that has not finished arriving SHALL NOT be shown as text. A message that is only tags SHALL show only attachments.

#### Scenario: Image tag

- **WHEN** the reply reads "Here you go MEDIA:/home/u/.hermes/images/a.png"
- **THEN** the message shows "Here you go" and an image attachment named "a.png", and the tag is not visible

#### Scenario: Two files

- **WHEN** a reply names two files in two tags
- **THEN** two attachments show in that order

#### Scenario: Streaming

- **WHEN** the reply has streamed "see MEDIA:/ho" so far
- **THEN** the visible text is "see" and no attachment shows yet

#### Scenario: Relative path

- **WHEN** a reply contains "MEDIA:notes.txt"
- **THEN** it is shown as text, not as an attachment

### Requirement: Images are shown inline

The system SHALL show an image attachment as a thumbnail in the transcript, fetched with the user's session. Tapping it SHALL open it full screen where it can be zoomed and saved, and closing it SHALL return to the chat. While it loads the thumbnail SHALL show a placeholder.

#### Scenario: Open an image

- **WHEN** the user taps an image attachment
- **THEN** a full-screen viewer shows it and can be closed

### Requirement: Files download on demand

The system SHALL show any other file as a card with its name, which downloads the file when tapped, shows that it is downloading, and then opens it with the system's app for that type. The card SHALL offer to save it. A file SHALL be downloaded at most once until the app signs out.

#### Scenario: Open a document

- **WHEN** the user taps a card for "report.pdf"
- **THEN** the card shows it is downloading, and the file then opens in the system's PDF viewer

#### Scenario: Open again

- **WHEN** the user taps the same card again
- **THEN** it opens without downloading again

#### Scenario: Save

- **WHEN** the user chooses save on a file card
- **THEN** the system's save dialog opens with the file's name, and the file is not opened

### Requirement: Fetch failures are explained

When a file cannot be fetched the card SHALL say why and stay in the transcript: "This file is no longer available." when it is missing, "This file can't be opened from here." when the server refuses the path, "This file is too large to download." when it is over the server's limit, and "Could not download the file. Tap to try again." for anything else, where a tap tries again. A file whose path is not absolute SHALL show its name without a download action.

#### Scenario: Missing file

- **WHEN** the server answers that the file does not exist
- **THEN** the card reads "This file is no longer available."

#### Scenario: Retry

- **WHEN** a download fails because the connection dropped and the user taps the card
- **THEN** the download starts again

### Requirement: Restored attachments use the same display

Attachments restored from history that carry an absolute server path SHALL be shown, fetched and opened as the requirements above describe. Attachments without one SHALL show their name.

#### Scenario: Reloaded image

- **WHEN** a thread is loaded whose earlier message had an image attached
- **THEN** the message shows the image as a thumbnail

### Requirement: Cached media is removed on sign-out

The system SHALL delete every file it downloaded or cached for media when the user signs out, the server is removed, or the server rejects the session's refresh token. Requests that race to refresh the token SHALL NOT delete anything.

#### Scenario: Sign out

- **WHEN** the user signs out after opening a downloaded file
- **THEN** the downloaded file is no longer on disk

#### Scenario: Requests race to refresh

- **WHEN** two requests get a 401 at once and the session is refreshed
- **THEN** downloaded files are kept
