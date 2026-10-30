# Spec Delta

## ADDED Requirements

### Requirement: Backend contract for watching

To watch a screen the app SHALL call `display.observe` with `profile` on the gateway socket and use its `ticket`, `path` and `viewer_id`, opening the display stream with the ticket within its 30 seconds. When `display.observe` fails, the app SHALL read `display.status` to decide between showing that the screen is off and showing an error, since the failure carries no machine-readable reason. `display.observe` first ships in Hermes v2026.9.24.

#### Scenario: Watching a running screen

- **WHEN** the user opens the viewer for a profile whose screen runs
- **THEN** the app observes, opens the stream with the ticket, completes the handshake and draws the picture as updates arrive

#### Scenario: Observe fails on a stopped screen

- **WHEN** `display.observe` fails and the following status says the screen is not running
- **THEN** the viewer shows that the screen is off with Start Screen

### Requirement: Stream endings

The viewer SHALL handle the end of a stream as follows: a close the app sent (1000) needs nothing; 4000 SHALL observe again and reconnect as a watcher; 4001 SHALL show that the screen is off without retrying; a close the server sent with 1000 or 1001 and no error SHALL read `display.status` and show that the screen is off when it is not running (the bridge closes this way when the screen stops), and otherwise be treated like any other ending; 4401 SHALL observe again once and show an error if the next stream also ends with 4401; 1003 SHALL show a protocol error without retrying; an upgrade refused with HTTP 403 SHALL show that viewing is not allowed without retrying. Any other ending SHALL reopen the stream with a fresh ticket using full-jitter backoff from 300 ms to 15 s, at most 5 attempts, after which the viewer shows that the screen cannot be reached with Try Again.

#### Scenario: The ticket was spent

- **WHEN** the stream closes with 4401
- **THEN** the app observes once more and reconnects with the new ticket

#### Scenario: The screen stops while watched

- **WHEN** the stream closes with 4001, or with 1000 while the status says the screen is not running
- **THEN** the viewer shows that the screen is off and does not reconnect

#### Scenario: The phone loses Wi-Fi briefly

- **WHEN** the stream drops abnormally and the network returns within the attempts
- **THEN** the viewer reconnects and the picture resumes without the user doing anything

### Requirement: A stream that goes quiet

The display socket SHALL ping every 15 seconds and give up connecting after 10, so that a link that went half-open ends the stream and is handled as any abnormal ending, and a proxy does not close the link of a screen that sends nothing.

#### Scenario: The link goes half-open

- **WHEN** the server stops answering without closing the socket
- **THEN** the stream ends and the viewer reconnects with backoff

### Requirement: Viewer presentation

On a phone (shortest side under 600 pt, in either orientation) the viewer SHALL be a full-screen page that follows the device orientation and supports pinch to zoom and pan. On a larger window it SHALL be a view covering the whole window, closed by its Close button. Both SHALL be routes on the root navigator, so that a dialog or page opened later is drawn above the viewer, the chat below does not act on keys or menu commands, and Back closes it; Escape SHALL close either. The picture SHALL keep clear of system insets, and on macOS the header SHALL leave room for the traffic lights and move the window. The header SHALL name the profile and who is in control, following the lease. While connecting or reconnecting the viewer SHALL say so over the last picture, dimmed.

#### Scenario: A phone in landscape

- **WHEN** the user turns the phone while the viewer is open
- **THEN** the picture fills the new width, keeping its aspect ratio

#### Scenario: A wide window

- **WHEN** the user opens the viewer in a window 1200 pt wide
- **THEN** the viewer covers the whole window, not a side panel

### Requirement: Someone else in control

While a person other than this device holds control (`holder: human` with a `viewer_hash` that matches no viewer id this app holds), the viewer SHALL show no picture and say that someone else is in control, keeping the stream open, and SHALL show the picture again when control returns to Hermes.

#### Scenario: A person takes over from another device

- **WHEN** the lease reports another person as holder while the user watches
- **THEN** the picture is blanked and the viewer says someone else is in control

### Requirement: Watch-only viewer

The viewer SHALL NOT send KeyEvent, PointerEvent, ClientCutText or SetDesktopSize messages. Gestures and clicks in the viewer SHALL only zoom and pan the picture.

#### Scenario: The user taps the picture

- **WHEN** the user taps or clicks inside the live picture
- **THEN** no input message is sent on the stream

### Requirement: Closing the viewer with Escape

While the viewer is shown as a view over the window, pressing Escape SHALL close it.

#### Scenario: Escape on a desktop

- **WHEN** the viewer covers the window and the user presses Escape
- **THEN** the viewer closes and the stream closes with 1000

### Requirement: Closing the stream when not visible

The app SHALL close the stream when the viewer closes, when the app is not in front (on a phone, not resumed; on a desktop, hidden or paused, or with no window), when App Lock covers the app, when another route covers the viewer, when the chat leaves the screen, on sign-out and on a change of the chat's profile, and SHALL observe again and reconnect when the viewer becomes visible again. A desktop window that is merely inactive keeps its stream. Because an attached viewer counts as use on the server and can keep a changing screen from its idle stop, the app SHALL NOT keep a stream open for a viewer that is not visible.

#### Scenario: The app goes to the background

- **WHEN** the user leaves the app with the viewer open
- **THEN** the stream is closed and reopened when the user returns

### Requirement: Live stream privacy

The app SHALL keep the framebuffer in memory only, SHALL NOT log, store or send to telemetry the ticket, the stream URL, the viewer id or any picture data, and SHALL drop the framebuffer when the viewer closes.

#### Scenario: Telemetry is on

- **WHEN** a stream ends
- **THEN** the recorded span carries outcome, close code, encodings and a size bucket, and no ticket, URL, viewer id or pixels

## MODIFIED Requirements

### Requirement: Opening the screen from the preview

Tapping or clicking the transcript preview SHALL open the screen viewer for the chat's profile: a full-screen page on a phone, a view covering the window elsewhere.

#### Scenario: The user taps the preview on a phone

- **WHEN** the user taps the preview
- **THEN** the viewer opens as a full-screen page and starts the live stream

#### Scenario: The user clicks the preview on a desktop

- **WHEN** the user clicks the preview in a window 1200 pt wide
- **THEN** the viewer opens over the whole window

### Requirement: Enlarging the card's picture

The running card SHALL offer an Enlarge action, and tapping or clicking its picture SHALL do the same: both open the screen viewer for the profile.

#### Scenario: Enlarge from the Activity panel

- **WHEN** the user presses Enlarge on the running card
- **THEN** the viewer opens and starts the live stream
