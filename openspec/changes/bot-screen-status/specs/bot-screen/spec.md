# Spec Delta

## ADDED Requirements

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
