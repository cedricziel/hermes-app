# Spec Delta

## ADDED Requirements

### Requirement: Pointer events

When asked to send pointer input, the app SHALL send RFB PointerEvent messages with framebuffer coordinates clamped to the screen and a button mask of primary (1), middle (2) and secondary (4). It SHALL send each scroll-wheel notch as a press and release of button 4 (up) or 5 (down), and horizontal scrolling as button 6 (left) or 7 (right), keeping any held buttons.

#### Scenario: Scrolling a page

- **WHEN** the user in control scrolls down three notches over the picture
- **THEN** the app sends three press-and-release pairs of button 5 at the pointer's position

#### Scenario: A position past the edge

- **WHEN** a pointer position falls outside the screen
- **THEN** the coordinates sent are clamped to the screen's edge

### Requirement: Key events

When asked to send keys, the app SHALL send RFB KeyEvent messages with X11 keysyms, a press and a release for each key: the standard keysyms for non-printing keys (Escape, Tab, Return, BackSpace, Delete, Insert, Home, End, Page Up, Page Down, arrows, F1–F12 and the Shift, Control, Alt, Super and Caps Lock keys), Latin-1 characters as their code point, and any other character as the X11 Unicode keysym (0x01000000 plus the code point).

#### Scenario: Typing a character outside Latin-1

- **WHEN** the user in control types "€"
- **THEN** the app sends keysym 0x010020AC pressed and released

### Requirement: Mapping positions on the picture

A position on the picture SHALL map to the framebuffer pixel shown under it at any zoom and pan. In trackpad use, movement SHALL move a pointer relative to its last position by the distance moved divided by the current zoom.

#### Scenario: Tapping a zoomed picture

- **WHEN** the picture is zoomed to 2× and panned, and a position over a button is mapped
- **THEN** the framebuffer coordinates are those of that button

### Requirement: Clipboard text to the screen

When asked to send clipboard text, the app SHALL send it as a ClientCutText message in Latin-1 of at most 256 KiB. Text containing a character outside Latin-1, or longer than 256 KiB, SHALL be refused with an error saying why, and nothing SHALL be sent; the app SHALL NOT replace characters it cannot encode.

#### Scenario: Pasting text with an emoji

- **WHEN** the text to send contains a character outside Latin-1
- **THEN** nothing is sent and the caller is told the text cannot be pasted

## MODIFIED Requirements

### Requirement: Client messages

On the stream the app SHALL send only the handshake, SetPixelFormat, SetEncodings and FramebufferUpdateRequest messages, and, when the viewer asks for input, PointerEvent, KeyEvent and ClientCutText. It SHALL NOT send SetDesktopSize or QEMU extended key messages.

#### Scenario: A whole watch-only session

- **WHEN** a stream runs from handshake to close and the viewer never asks for input
- **THEN** no KeyEvent, PointerEvent, ClientCutText or SetDesktopSize message was sent

#### Scenario: Input requested

- **WHEN** the viewer asks to send a click
- **THEN** the app sends PointerEvent messages and never SetDesktopSize
