# Spec Delta

## ADDED Requirements

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
- **Not installed** when `installed` is false: when `placement` is `gateway`, the server's `install_command` in monospace with a Copy action when present; otherwise, that the sandbox image of this profile's terminal backend needs the desktop stack, with no command.
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
- **THEN** the card says the sandbox image needs the desktop stack and shows no install command

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

The running card SHALL have an Enlarge action only when there is a viewer to open; until then it SHALL show none.

#### Scenario: No viewer yet

- **WHEN** the card shows a running screen and no viewer is available
- **THEN** the card offers no Enlarge action

### Requirement: Surfaces without the card

The app SHALL NOT show the Bot screen card or request frames in a Mac conversation window or in the quick panel.

#### Scenario: A chat in its own window

- **WHEN** a chat whose profile's screen runs is open in a Mac conversation window
- **THEN** that window shows no Bot screen card and sends no `display.thumbnail` request
