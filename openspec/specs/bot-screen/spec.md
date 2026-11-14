# bot-screen Specification

## Purpose
Shows a profile's own Linux desktop (Hermes' Bot Screen, which `computer_use` drives) in the app: its state and still frames over the gateway, a card in the Activity panel, a preview in the transcript, a live viewer over the display stream, taking over and handing back control, and installing the desktop packages on the server.

## Requirements

### Requirement: Backend contract for the screen's state

The app SHALL read a profile's screen over the authenticated gateway socket (`/api/ws`) with `display.status`, `display.start` and `display.thumbnail`, and SHALL send `profile` on every call: the profile the screen is shown for, or `default` when that is the server's default profile. It SHALL rely only on these result fields: `supported`, `installed`, `missing`, `running`, `geometry`, `placement`, `install_command`, `blocker`, `memory_available_mb`, `lease` (`holder` of `agent` or `human`, `viewer_hash`, `reason`, `epoch`) and `profile_key` for status and start, and `data_url` and `suppressed` for the thumbnail. It SHALL treat a missing optional field as unknown rather than failing. The contract is the one in the pinned `openrpc/hermes-gateway.openrpc.json`, first shipped in Hermes v2026.9.24. A gateway that answers `display.status` with method-not-found SHALL be treated as having no screen feature.

#### Scenario: An older server

- **WHEN** `display.status` answers method-not-found
- **THEN** the app offers no Bot Screen for that connection and the chat works as before

#### Scenario: A chat on the default profile

- **WHEN** the screen is read for a chat that shows the server's default profile
- **THEN** each display call carries `profile: "default"`

### Requirement: Following the screen's state

The app SHALL follow the `display.status` and `display.lease` broadcasts on the gateway connection, applying only those whose `profile_key` matches the profile's. Because broadcasts are lost while the connection is down and lease changes made by other server processes are not broadcast, the app SHALL read `display.status` again when a surface starts showing the screen, after the gateway connection was lost while the screen is shown, when the app returns to the foreground while the screen is shown, and with every 10th frame request.

#### Scenario: A broadcast for another profile

- **WHEN** a `display.lease` broadcast arrives whose `profile_key` is not the profile's
- **THEN** nothing the app shows changes

#### Scenario: A takeover from another process

- **WHEN** a person takes control through a process that does not broadcast it
- **THEN** the app learns it at the latest with the 10th frame request after it

### Requirement: Still frames

While at least one surface showing the screen asks for frames, the screen is running, and the app is in the foreground and not covered by App Lock, the app SHALL request a frame with `display.thumbnail` every 3 seconds with at most one request in flight, and SHALL stop when any of these no longer holds. When a thumbnail answers `data_url: null` with `suppressed`, or a lease with `holder: human` arrives, the app SHALL drop the frame it holds. When the screen stops, the app SHALL drop the frame.

#### Scenario: A person takes control elsewhere

- **WHEN** the next thumbnail answers `suppressed: "human_has_control"`
- **THEN** the app holds no frame and reports that someone else is in control

#### Scenario: Nothing asks for frames

- **WHEN** no surface showing the screen is visible
- **THEN** no `display.thumbnail` request is sent

### Requirement: Display calls leave the chat connection alone

A display call that gets no answer within 10 seconds SHALL fail on its own without closing the shared gateway connection, so running replies and other requests on that connection continue.

#### Scenario: A slow screenshot during a reply

- **WHEN** `display.thumbnail` times out while a reply streams on the same connection
- **THEN** the reply keeps streaming and the next frame request goes over the same connection

### Requirement: Answers that arrive too late

The app SHALL discard a display answer that arrives after App Lock covered the app, after the screen's surface switched to another profile, or after the user signed out.

#### Scenario: App Lock during a frame request

- **WHEN** App Lock covers the app while a thumbnail request is in flight
- **THEN** its answer is dropped and no frame is held when the app is unlocked

### Requirement: Frame privacy

The app SHALL keep frames in memory only and SHALL NOT write them to disk, logs or telemetry. It SHALL drop held frames on App Lock, sign-out and a change of profile. It SHALL NOT log or export the install command, the blocker text or `profile_key`.

#### Scenario: Telemetry is on

- **WHEN** a frame is fetched
- **THEN** telemetry records the outcome and a size bucket, and no image data, path or profile name

### Requirement: Bot screen card in the Activity panel

The app SHALL list a Bot screen card in the Activity panel's Now section, as Working activity, for the open chat's profile while its screen is running, or while it is not running and the open chat has a `computer_use` tool call. It SHALL list none when the server has no screen feature, and SHALL add nothing for the screen to the strip above the transcript. The running card SHALL say who is in control: Hermes (`holder: agent`), you (`holder: human` and `viewer_hash` matches a viewer id this app holds), or someone else (any other `holder: human`). This relies on the `display.*` methods of Hermes v2026.9.24 or later.

#### Scenario: Hermes is using its screen

- **WHEN** the chat's profile has a running screen and the agent holds the lease
- **THEN** Now lists the Bot screen card with a frame and "Hermes is in control", and the strip shows nothing for it

#### Scenario: A chat that never used the screen

- **WHEN** the profile's screen is not running and the open chat has no `computer_use` tool call
- **THEN** no Bot screen card is listed

### Requirement: Card states

The card SHALL show exactly one of these states, chosen in this order:

- **Not offered** when `supported` is false: Hermes uses the server's own display (macOS or Windows host); no action.
- **Installing** while an install the app started runs for the profile: the latest log lines, a spinner and that the install keeps going if the card is closed.
- **Not installed** when `installed` is false: when `placement` is `gateway`, the server's `install_command` in monospace with a Copy action when present, Install on Server when a command is present, and the last install's result when there was one (could not start, cancelled, no sudo with the command, failed with the last log lines, may still be running); otherwise, that the sandbox image of this profile's terminal backend needs the desktop stack, with no command and no install action.
- **Blocked** when `blocker` is present: the blocker text as a warning, with the available memory when `memory_available_mb` is present.
- **Starting** while a Start Screen request is in flight.
- **Off** when `running` is false: the screen starts by itself when Hermes needs it, with a **Start Screen** action and, after a failed start, the failure's message.
- **Error** when the screen's state or frame could not be read (a display error or a timeout): "Couldn't read the screen" with Try Again.
- **Running** otherwise: the latest frame, or, when a person holds control or the frame is suppressed, no picture and a line naming who is in control: "You're in control" when the lease names this device, otherwise "Someone else is in control".

#### Scenario: The user starts the screen

- **WHEN** the card shows Off and the user presses Start Screen
- **THEN** the app sends `display.start` for the profile, shows Starting until it answers, then shows the running card

#### Scenario: Start fails

- **WHEN** `display.start` answers an error
- **THEN** the card returns to Off with the error's message and the chat is unaffected

#### Scenario: A sandboxed profile without the desktop

- **WHEN** status reports `installed: false` and `placement` is not `gateway`
- **THEN** the card says the sandbox image needs the desktop stack and shows no install command and no Install on Server

#### Scenario: A gateway host without the desktop

- **WHEN** status reports `installed: false`, `placement: gateway` and an install command
- **THEN** the card shows the command with Copy and Install on Server

#### Scenario: A macOS server

- **WHEN** `display.status` answers `supported: false`
- **THEN** the card says Hermes uses the server's own display and offers no action

### Requirement: When the card refreshes

The card SHALL ask for frames only while the app is in the foreground and resumed, the Activity panel shows the card, App Lock does not cover the app, and, on macOS, a window of the app is on screen. When any of these stops holding, the app SHALL stop requesting frames and the card SHALL drop the frame it shows.

#### Scenario: The panel closes

- **WHEN** the user closes the Activity panel
- **THEN** no further `display.thumbnail` request is sent for the card

#### Scenario: The Mac window is closed

- **WHEN** the user closes the main window on macOS while the app keeps running
- **THEN** frame requests stop until a window is on screen again

### Requirement: Enlarging the card's picture

The running card SHALL offer an Enlarge action when there is a viewer to open, and tapping or clicking its picture SHALL do the same: both open the screen viewer for the profile. Without a viewer it SHALL show no Enlarge action.

#### Scenario: Enlarge from the Activity panel

- **WHEN** the user presses Enlarge on the running card
- **THEN** the viewer opens and starts the live stream

#### Scenario: No viewer yet

- **WHEN** the card shows a running screen and no viewer is available
- **THEN** the card offers no Enlarge action

### Requirement: Surfaces without the card

The app SHALL NOT show the Bot screen card or request frames in a Mac conversation window or in the quick panel.

#### Scenario: A chat in its own window

- **WHEN** a chat whose profile's screen runs is open in a Mac conversation window
- **THEN** that window shows no Bot screen card and sends no `display.thumbnail` request

### Requirement: Preview while a turn uses computer_use

From the first `computer_use` tool call of a reply until that reply ends, and while the profile's screen is running, the app SHALL show the screen's still preview with a Live badge and the control state right under the run of tool calls that holds the reply's latest `computer_use` call, outside any card: below the group header when the run is folded into a group, otherwise below that call's card. No other run SHALL show it. Of several replies pending at once, only the newest SHALL show it. When the reply completes, fails or is stopped, the preview SHALL leave the transcript. This relies on the `display.*` methods of Hermes v2026.9.24 or later.

#### Scenario: Hermes clicks through a website

- **WHEN** a reply's `computer_use` call is running and the screen is running
- **THEN** the preview appears below that call's card, with a Live badge and "Hermes is in control"

#### Scenario: Consecutive calls fold into a group

- **WHEN** the reply's latest `computer_use` call is part of a run folded behind a group header
- **THEN** the preview appears below the group header while the group stays folded

#### Scenario: A later run

- **WHEN** an earlier run held a `computer_use` call and a later run starts another
- **THEN** only the later run shows the preview

#### Scenario: The reply ends

- **WHEN** the reply completes, fails or is stopped
- **THEN** no run shows the preview and no frame is requested for it

### Requirement: Opening the screen from the preview

Tapping or clicking the transcript preview SHALL open the screen viewer for the chat's profile: a full-screen page on a phone, a view covering the window elsewhere.

#### Scenario: The user taps the preview on a phone

- **WHEN** the user taps the preview
- **THEN** the viewer opens as a full-screen page and starts the live stream

#### Scenario: The user clicks the preview on a desktop

- **WHEN** the user clicks the preview in a window 1200 pt wide
- **THEN** the viewer opens over the whole window

#### Scenario: The inspector is already open

- **WHEN** the user clicks the preview while the inspector is open beside the chat
- **THEN** the viewer opens over the window and the inspector stays open behind it

### Requirement: Watching only what is on screen

The transcript preview SHALL ask for frames only while some part of it is on screen, under the card's refresh conditions, and SHALL NOT ask for frames while it is only built off screen.

#### Scenario: Scrolled away

- **WHEN** the user scrolls the transcript so the preview leaves the screen
- **THEN** the preview no longer asks for frames, and if nothing else on screen asks, no `display.thumbnail` request is sent

### Requirement: Display stream socket

The app SHALL open the live stream as a WebSocket on the dashboard's origin, using `wss` for an `https` dashboard and `ws` for `http`, at the dashboard base URL's path prefix followed by the `path` from `display.observe` (`/api/display/ws`), with the single query parameter `display_ticket` set to the ticket. It SHALL NOT put the gateway token or ticket on this socket. It SHALL apply the same certificate trust as the other dashboard sockets, including user-installed certificate authorities on Android. It SHALL exchange binary frames only, read the close code the server sends, and be able to close with a status code of its choosing. When the server refuses the upgrade (HTTP 403, the dashboard's Host/Origin policy), the app SHALL report that viewing is not allowed. No error the app records SHALL contain the stream URL or the ticket. The route first ships in Hermes v2026.9.24.

#### Scenario: A dashboard behind a path prefix

- **WHEN** the dashboard's base URL is `https://example.net/hermes`
- **THEN** the stream opens `wss://example.net/hermes/api/display/ws?display_ticket=…` with no other query parameter

#### Scenario: The server refuses the upgrade

- **WHEN** the upgrade is answered with HTTP 403
- **THEN** the app reports that viewing is not allowed, and the recorded error holds neither the URL nor the ticket

### Requirement: RFB handshake

The app SHALL speak RFB protocol version 3.8 as a client: read the server's version and fail on a version below 3.8, send `RFB 003.008`, read the security types (when the count is 0, read the reason string and fail), choose None (1) or fail when it is not offered, read the 4-byte SecurityResult and fail with its reason string when it is not 0, send ClientInit with the shared flag set, and read ServerInit.

#### Scenario: Watching a running screen

- **WHEN** the stream opens on a running screen
- **THEN** the app completes the handshake as a shared client with security type None

#### Scenario: The server offers no security type

- **WHEN** the server sends a security-type count of 0
- **THEN** the app reads the reason, ends the stream and reports a handshake failure

### Requirement: Pixel format, encodings and updates

After ServerInit the app SHALL send SetPixelFormat for 32 bits per pixel, depth 24, little-endian, true colour with red, green and blue maxima of 255 and shifts 0, 8 and 16, then SetEncodings with ZRLE (16), CopyRect (1), Raw (0) and the DesktopSize pseudo-encoding (-223) in that order, then a non-incremental FramebufferUpdateRequest for the whole screen. After each FramebufferUpdate it SHALL send an incremental request, except after an update that carried DesktopSize, after which it SHALL resize its framebuffer and send a non-incremental request for the new size.

#### Scenario: The remote desktop changes size

- **WHEN** an update carries a DesktopSize rectangle
- **THEN** the app resizes its picture and asks for the whole new screen

### Requirement: Decoding the picture

The app SHALL decode Raw, CopyRect and ZRLE rectangles. For ZRLE it SHALL keep one zlib-format (RFC 1950) inflate stream for the whole connection, feed it exactly the length-prefixed data of each ZRLE rectangle, read 3-byte compressed pixels for its pixel format, and decode the raw, solid, packed palette (2, 3–4 and 5–16 colours), plain RLE and palette RLE subencodings. Malformed or truncated data SHALL end the stream with a decode failure and SHALL NOT crash the app.

#### Scenario: ZRLE across updates

- **WHEN** two consecutive updates carry ZRLE rectangles
- **THEN** both decode from the same inflate stream

#### Scenario: A broken update

- **WHEN** an update is truncated or uses an unknown subencoding
- **THEN** the stream ends with a decode failure and the app keeps running

### Requirement: Client messages

On the stream the app SHALL send only the handshake, SetPixelFormat, SetEncodings and FramebufferUpdateRequest messages, and, when the viewer asks for input, PointerEvent, KeyEvent and ClientCutText. It SHALL NOT send SetDesktopSize or QEMU extended key messages.

#### Scenario: A whole session

- **WHEN** a stream runs from handshake to close and the viewer never asks for input
- **THEN** no KeyEvent, PointerEvent, ClientCutText or SetDesktopSize message was sent

#### Scenario: Input requested

- **WHEN** the viewer asks to send a click
- **THEN** the app sends PointerEvent messages and never SetDesktopSize

### Requirement: Server messages the app ignores

The app SHALL read past Bell, SetColourMapEntries and ServerCutText messages, the latter in both its classic and its extended (negative length) form, and SHALL discard ServerCutText content without showing, storing or logging it. Any other server message type SHALL end the stream with a protocol failure.

#### Scenario: The agent copies a password on its desktop

- **WHEN** the server sends ServerCutText
- **THEN** the app discards it and nothing of it is shown, stored or logged

### Requirement: Backend contract for installing

The app SHALL start an install with `display.install` (`profile`) and read `started`, `command` and `profile_key` from its answer; an error answer means the install did not start. It SHALL follow the `display.install.log` (`profile_key`, `line`) and `display.install.done` (`profile_key`, `code`, `status`) broadcasts for that `profile_key`. It SHALL answer the server request `display.install.sudo` (`session_id`, `profile_key`) with a `value` string, where an empty string declines. These first ship in Hermes v2026.9.24.

#### Scenario: Installing on a server where Hermes runs as root

- **WHEN** the user presses Install on Server and the server installs without asking for a password
- **THEN** the card shows the log lines while it runs and Off with Start Screen when done arrives with code 0

### Requirement: Unrequested sudo requests are refused

The app SHALL refuse a `display.install.sudo` request at once, with an error answer, unless an install it started on the same gateway connection is running for the request's `profile_key`, and SHALL show nothing for it.

#### Scenario: A sudo request nobody asked for

- **WHEN** the server sends `display.install.sudo` for a profile the app started no install for
- **THEN** the app answers with an error immediately and shows nothing

### Requirement: Install on Server

The Not installed state SHALL offer Install on Server only when `placement` is `gateway` and the server reports an install command. Pressing it SHALL start the install and show the Installing state with the latest log lines. The install SHALL keep running if the user closes the panel, leaves the chat or switches profile; the card SHALL show Installing again when reopened until the install ends. When `display.install` answers an error, the card SHALL say the install could not start, show the server's message and offer Install on Server again.

#### Scenario: Another install is already running

- **WHEN** `display.install` answers an error because an install is running
- **THEN** the card says the install could not start with the server's message

### Requirement: Sudo password

When an install the app started asks for the sudo password, the app SHALL show a masked password field naming the dashboard's host, with Install and Cancel, wherever the user is in the app. Install SHALL answer with the typed password once; Cancel or dismissal SHALL answer an empty value. The app SHALL NOT store the password, offer to save it, log it or send it anywhere but that answer, SHALL turn off autocorrect, suggestions, keyboard learning and autofill for the field, and SHALL clear the field after answering. When the install ends before the user answers, or the server withdraws the request, the prompt SHALL close; the app SHALL NOT ask while the session is gone, and on macOS SHALL bring the main window forward first. The prompt SHALL name the Hermes host and the profile.

#### Scenario: The user enters the password

- **WHEN** the server asks for the sudo password and the user types it and presses Install
- **THEN** the app answers the request with that value once and the field is cleared

#### Scenario: The user left the chat

- **WHEN** the user started the install, opened Kanban, and the server then asks for the password
- **THEN** the password prompt appears over Kanban

#### Scenario: The server withdraws the question

- **WHEN** the prompt is open and the server sends `request.cancel` for its request
- **THEN** the prompt closes and a later password request for the same install is asked again

#### Scenario: The user cancels

- **WHEN** the user cancels the password question
- **THEN** the app answers an empty value and the card says the install was cancelled when done arrives with -1

### Requirement: Install results

`display.install.done` SHALL end the Installing state: code 0 shows the state from its `status`; -1 says the install was cancelled; -2 says the server has no sudo and shows the install command without its `sudo` prefix with Copy to run by hand, and offers no Install on Server; any other code says the install failed with the last log lines and offers Install on Server again. Because the done broadcast can be missed, the app SHALL read `display.status` while an install runs when the app returns to the foreground and after the gateway connection was lost, SHALL end Installing when the status reports the packages installed, and SHALL end it after 22 minutes without done, saying the install may still be running.

#### Scenario: No sudo on the server

- **WHEN** done arrives with code -2
- **THEN** the card says there is no sudo on the server and shows the install command to run by hand

#### Scenario: The done broadcast was missed

- **WHEN** the gateway connection dropped during the install and the status read after it reports `installed: true`
- **THEN** the card leaves Installing and shows Off with Start Screen

### Requirement: Install privacy

The app SHALL NOT log or send to telemetry the password, the install command, the host or log lines.

#### Scenario: Telemetry is on during an install

- **WHEN** an install ends
- **THEN** telemetry records the outcome and whether a password was asked, and nothing else about it

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

The viewer SHALL NOT send KeyEvent, PointerEvent or ClientCutText messages unless this device holds the lease, and SHALL never send SetDesktopSize. While watching, gestures and clicks in the viewer SHALL only zoom and pan the picture.

#### Scenario: The user taps the picture

- **WHEN** the user taps or clicks inside the live picture without control
- **THEN** no input message is sent on the stream

#### Scenario: The user taps the picture in control

- **WHEN** this device holds the lease and the user taps the picture in Touch mode
- **THEN** the app sends a primary click at the mapped point

### Requirement: Closing the viewer with Escape

While the viewer is shown as a view over the window and this device does not hold control, pressing Escape SHALL close it. While this device holds control, Escape SHALL go to the screen and the viewer SHALL close only through its Close button or the reserved close key (⌘. on macOS, F8 on Windows and Linux), handing control back.

#### Scenario: Escape on a desktop

- **WHEN** the viewer covers the window, the user watches and presses Escape
- **THEN** the viewer closes and the stream closes with 1000

#### Scenario: Escape in control

- **WHEN** the user in control presses Escape
- **THEN** the screen receives Escape and the viewer stays open

### Requirement: Closing the stream when not visible

While watching, the app SHALL close the stream when the viewer closes, when the app is not in front (on a phone, not resumed; on a desktop, hidden or paused, or with no window), when App Lock covers the app, when another route covers the viewer, when the chat leaves the screen, on sign-out and on a change of the chat's profile, and SHALL observe again and reconnect when the viewer becomes visible again. A desktop window that is merely inactive keeps its stream. While this device holds control, leaving (the app no longer in front, or another route covering the viewer) SHALL close the stream with 4100 so the server keeps the lease, and a cover by App Lock or the inactive state SHALL close it with 4100 only if it lasts more than 2 seconds; on return the viewer SHALL reconnect and keep control. Sign-out, a profile change and Change Server SHALL release the lease before closing. Because an attached viewer counts as use on the server and can keep a changing screen from its idle stop, the app SHALL NOT keep a stream open for a viewer that is not visible beyond these rules.

#### Scenario: The user fetches the code from another app

- **WHEN** the user in control switches to the messages app and back
- **THEN** the stream closed with 4100, and the viewer reconnects with the user still in control

#### Scenario: A glance at the notification shade

- **WHEN** the user in control pulls down the notification shade for a second
- **THEN** the stream stays open

#### Scenario: The app goes to the background

- **WHEN** the user leaves the app with the viewer open and no control
- **THEN** the stream is closed and reopened when the user returns

### Requirement: Live stream privacy

The app SHALL keep the framebuffer in memory only, SHALL NOT log, store or send to telemetry the ticket, the stream URL, the viewer id or any picture data, and SHALL drop the framebuffer when the viewer closes.

#### Scenario: Telemetry is on

- **WHEN** a stream ends
- **THEN** the recorded span carries outcome, close code, encodings and a size bucket, and no ticket, URL, viewer id or pixels

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

### Requirement: Backend contract for control

The app SHALL take control with `display.lease.acquire` (`profile`, `viewer_id`, optional `reason`) and give it back with `display.lease.release` (`profile`, `viewer_id`), sending both on the gateway connection whose `display.observe` minted that viewer id. When that connection is gone, or the server answers with `data.code: "viewer_mismatch"`, the app SHALL observe again and retry once with the new viewer id. It SHALL treat the lease as this device's when `holder` is `human` and `viewer_hash` equals the first 12 hexadecimal digits of the SHA-256 of a viewer id this app holds, and SHALL apply the `lease` in the acquire and release answers at once rather than waiting for a broadcast. It SHALL send input only on the stream of a viewer id that holds the lease. These methods, `viewer_hash` and `force` release first ship in Hermes v2026.9.24.

#### Scenario: Taking over

- **WHEN** the user confirms Take over while watching
- **THEN** the app sends `display.lease.acquire` with its viewer id on the observing connection and, as soon as the answer's lease names this device, says "You're in control" and accepts input

#### Scenario: The connection changed

- **WHEN** acquire answers `viewer_mismatch` because the gateway connection was replaced
- **THEN** the app observes again and retries once with the new viewer id

### Requirement: Asking before taking over

Before taking over the app SHALL ask for confirmation, saying that Hermes stops using the screen until the user hands it back and that the step it is on may end and need the user to tell it to continue, that what the user types goes to the server's desktop, and that this app's previews and its viewers on other devices hide the picture meanwhile while Hermes Desktop's live viewers may still see it. The question SHALL offer not to ask again for this account.

#### Scenario: The user turned the question off

- **WHEN** the user chose not to be asked again for this account and presses Take over
- **THEN** the app takes over at once

### Requirement: Input while in control

While this device holds the lease the viewer SHALL send input:

- Touch mode (default on touch devices): a tap clicks the primary button at the tapped point, a long press clicks the secondary button, a one-finger drag moves the pointer with the primary button held, two fingers pan and pinch the picture.
- Trackpad mode: one-finger drags move the pointer relative to its position, a tap clicks at the pointer.
- With a mouse: movement, buttons and the scroll wheel over the picture as they happen, in screen coordinates.
- Hardware keys as X11 keysyms with press and release, subject to the reserved keys.
- The on-screen keyboard's committed text as key presses of the matching keysyms; text still being composed SHALL NOT be sent until it is committed.
- The key bar: Escape, Tab, Left and Right as key presses, Ctrl and Alt held for the next key, and Paste.

#### Scenario: Typing a 2FA code on a phone

- **WHEN** the user in control taps the code field on the screen and types 481 on the phone's keyboard
- **THEN** the app sends a click at the field and key presses for 4, 8 and 1

### Requirement: Reserved keys on computers

While this device holds control and the picture has keyboard focus:

- On macOS, ⌘V SHALL run Paste; ⌘Q, ⌘W, ⌘H, ⌘M and ⌘Tab SHALL go to the app and the system, not the screen; ⌘. SHALL close the viewer; any other ⌘ chord SHALL be sent with Control in place of Command; Escape SHALL go to the screen.
- On Windows and Linux, Ctrl+V SHALL run Paste; F8 SHALL close the viewer and the viewer SHALL offer a Send F8 action; Alt+Tab, Alt+F4 and Super chords SHALL go to the system; every other key, Escape included, SHALL go to the screen.

#### Scenario: Select all on a Mac

- **WHEN** the user in control presses ⌘A over the picture
- **THEN** the screen receives Control+A

#### Scenario: Quitting while in control

- **WHEN** the user in control presses ⌘Q
- **THEN** the key is not sent to the screen and the app handles it

### Requirement: Pasting

Paste SHALL send the device clipboard's text to the screen's clipboard, press Control+V on the screen, and shortly afterwards clear the screen's clipboard. Text that cannot be sent (outside Latin-1, or over 256 KiB) SHALL be refused with a message and nothing sent.

#### Scenario: Pasting a password

- **WHEN** the user in control presses Paste with text on the device clipboard
- **THEN** the screen's clipboard receives the text, Control+V is pressed, and the screen's clipboard is emptied shortly after

#### Scenario: Text with an emoji

- **WHEN** the clipboard text contains a character outside Latin-1
- **THEN** the app says the text cannot be pasted to the screen and sends nothing

### Requirement: Handing back

Hand Back SHALL send `display.lease.release` with the viewer id and return the viewer to watching. Closing the viewer while in control SHALL hand back. Signing out, switching the chat's profile and Change Server SHALL hand back before the stream closes.

#### Scenario: The user closes the viewer

- **WHEN** the user closes the viewer while in control
- **THEN** control returns to Hermes

### Requirement: Handing back a stranded lease

When a person holds the lease under a viewer id this app does not hold, the card and the viewer SHALL offer Hand back to Hermes. After a confirmation saying that whoever uses the screen loses control, the app SHALL send `display.lease.release` with `force: true` and no viewer id.

#### Scenario: The app restarted while in control

- **WHEN** the user relaunches the app after quitting it while in control
- **THEN** the card shows that someone is in control with Hand back to Hermes, and confirming returns control to Hermes

### Requirement: Losing control

When the stream closes with 4000, or the lease names another holder while this device was in control, the viewer SHALL stop sending input, return to watching and say that someone else took control. When the viewer reconnects on a new gateway connection and the lease still names a viewer id this app held, the app SHALL acquire the lease with its new viewer id without asking.

#### Scenario: Another device takes over

- **WHEN** the user's laptop takes over while the phone is in control
- **THEN** the phone's viewer returns to watching and says someone else took control

#### Scenario: The gateway reconnects mid-login

- **WHEN** the gateway connection is replaced while the user is in control
- **THEN** the viewer observes again, finds the lease under its earlier id and takes it with the new id, and the user stays in control

### Requirement: Input privacy

The app SHALL NOT log, store or send to telemetry typed text, pasted text, key names, pointer coordinates or viewer ids. The field that receives the on-screen keyboard SHALL have autocorrect, suggestions, smart quotes, smart dashes and keyboard learning turned off and use a password keyboard type.

#### Scenario: Telemetry is on while typing

- **WHEN** the user types a password in control
- **THEN** telemetry records at most a bucketed count of input events
