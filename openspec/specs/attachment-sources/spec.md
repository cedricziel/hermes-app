# attachment-sources Specification

## Purpose
Defines where a user can add chat attachments from on each platform. Every source produces the same pending attachment that the composer lists above the input.
## Requirements
### Requirement: Attach control

The composer SHALL show an attach control. Choosing files from it SHALL open the system file picker and allow several files at once. On iOS and Android the control SHALL also offer the photo library and the camera. On macOS, Windows and Linux it SHALL NOT offer the camera. Picking nothing, or cancelling, SHALL change nothing.

#### Scenario: Pick files

- **WHEN** the user chooses files from the attach control and picks two files
- **THEN** two attachments appear above the input, each with its name

#### Scenario: Camera is mobile only

- **WHEN** the attach control opens on macOS
- **THEN** it offers files but not the camera

#### Scenario: Cancel

- **WHEN** the user cancels the system picker
- **THEN** the composer and its attachments are unchanged

### Requirement: Drag and drop

On macOS, Windows and Linux the chat SHALL accept files dropped onto it and add them as attachments. While files are dragged over the chat it SHALL show that it will accept them. Dropped folders SHALL be ignored.

#### Scenario: Drop files

- **WHEN** the user drops a file onto the chat
- **THEN** it appears as an attachment above the input

#### Scenario: Drop indicator

- **WHEN** files are dragged over the chat and then leave it
- **THEN** the drop indicator shows while they are over the chat and disappears when they leave

### Requirement: Paste

On macOS, Windows and Linux, pasting in the composer SHALL attach an image or files that are on the clipboard. When the clipboard holds neither, the paste SHALL insert text as usual. A pasted image SHALL be named with a timestamp and a `.png` extension.

#### Scenario: Paste an image

- **WHEN** the clipboard holds an image and the user pastes in the composer
- **THEN** an image attachment appears and no text is inserted

#### Scenario: Paste text

- **WHEN** the clipboard holds only text and the user pastes
- **THEN** the text is inserted into the composer and nothing is attached

### Requirement: Permissions

The app SHALL ask for camera access only when the user chooses the camera, and SHALL NOT ask for photo library access to read the library. When camera access is denied, the app SHALL say so and leave the composer unchanged.

#### Scenario: Camera denied

- **WHEN** the user chooses the camera and denies access
- **THEN** a message says the camera is not available and nothing is attached

