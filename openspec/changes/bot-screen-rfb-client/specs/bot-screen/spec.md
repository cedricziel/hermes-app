# Spec Delta

## ADDED Requirements

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

On the stream the app SHALL send only the handshake, SetPixelFormat, SetEncodings and FramebufferUpdateRequest messages.

#### Scenario: A whole session

- **WHEN** a stream runs from handshake to close
- **THEN** no KeyEvent, PointerEvent, ClientCutText or SetDesktopSize message was sent

### Requirement: Server messages the app ignores

The app SHALL read past Bell, SetColourMapEntries and ServerCutText messages, the latter in both its classic and its extended (negative length) form, and SHALL discard ServerCutText content without showing, storing or logging it. Any other server message type SHALL end the stream with a protocol failure.

#### Scenario: The agent copies a password on its desktop

- **WHEN** the server sends ServerCutText
- **THEN** the app discards it and nothing of it is shown, stored or logged
