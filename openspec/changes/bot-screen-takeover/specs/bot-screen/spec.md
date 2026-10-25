# Spec Delta

## ADDED Requirements

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

## MODIFIED Requirements

### Requirement: Watch-only viewer

The viewer SHALL NOT send KeyEvent, PointerEvent or ClientCutText messages unless this device holds the lease, and SHALL never send SetDesktopSize. While watching, gestures and clicks in the viewer SHALL only zoom and pan the picture.

#### Scenario: The user taps the picture while watching

- **WHEN** the user taps or clicks inside the live picture without control
- **THEN** no input message is sent on the stream

#### Scenario: The user taps the picture in control

- **WHEN** this device holds the lease and the user taps the picture in Touch mode
- **THEN** the app sends a primary click at the mapped point

### Requirement: Closing the viewer with Escape

While the viewer is shown as a view over the window and this device does not hold control, pressing Escape SHALL close it. While this device holds control, Escape SHALL go to the screen and the viewer SHALL close only through its Close button or the reserved close key (⌘. on macOS, F8 on Windows and Linux), handing control back.

#### Scenario: Escape while watching

- **WHEN** the viewer covers the window, the user watches and presses Escape
- **THEN** the viewer closes and the stream closes with 1000

#### Scenario: Escape in control

- **WHEN** the user in control presses Escape
- **THEN** the screen receives Escape and the viewer stays open

### Requirement: Closing the stream when not visible

While watching, the app SHALL close the stream when the viewer closes, when the app is not in the resumed state, when App Lock covers the app, on sign-out and on a change of the chat's profile, and SHALL observe again and reconnect when the viewer becomes visible again. While this device holds control, moving the app out of the resumed state SHALL close the stream with 4100 so the server keeps the lease, and a cover by App Lock or the inactive state SHALL close it with 4100 only if it lasts more than 2 seconds; on return the viewer SHALL reconnect and keep control. Sign-out, a profile change and Change Server SHALL release the lease before closing. Because an attached viewer keeps the server from stopping an idle screen, the app SHALL NOT keep a stream open for a viewer that is not visible beyond these rules.

#### Scenario: The user fetches the code from another app

- **WHEN** the user in control switches to the messages app and back
- **THEN** the stream closed with 4100, and the viewer reconnects with the user still in control

#### Scenario: A glance at the notification shade

- **WHEN** the user in control pulls down the notification shade for a second
- **THEN** the stream stays open

#### Scenario: The app goes to the background while watching

- **WHEN** the user leaves the app with the viewer open and no control
- **THEN** the stream is closed and reopened when the user returns
