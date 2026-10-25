# Spec Delta

## ADDED Requirements

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

When an install the app started asks for the sudo password, the app SHALL show a masked password field naming the dashboard's host, with Install and Cancel, wherever the user is in the app. Install SHALL answer with the typed password once; Cancel or dismissal SHALL answer an empty value. The app SHALL NOT store the password, offer to save it, log it or send it anywhere but that answer, SHALL turn off autocorrect, suggestions, keyboard learning and autofill for the field, and SHALL clear the field after answering. When the install ends before the user answers, the prompt SHALL close.

#### Scenario: The user enters the password

- **WHEN** the server asks for the sudo password and the user types it and presses Install
- **THEN** the app answers the request with that value once and the field is cleared

#### Scenario: The user left the chat

- **WHEN** the user started the install, opened Kanban, and the server then asks for the password
- **THEN** the password prompt appears over Kanban

#### Scenario: The user cancels

- **WHEN** the user cancels the password question
- **THEN** the app answers an empty value and the card says the install was cancelled when done arrives with -1

### Requirement: Install results

`display.install.done` SHALL end the Installing state: code 0 shows the state from its `status`; -1 says the install was cancelled; -2 says the server has no sudo and shows the status' install command with Copy to run by hand; any other code says the install failed with the last log lines and offers Install on Server again. Because the done broadcast can be missed, the app SHALL read `display.status` while an install runs when the app returns to the foreground and after the gateway connection was lost, SHALL end Installing when the status reports the packages installed, and SHALL end it after 20 minutes without done, saying the install may still be running.

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

## MODIFIED Requirements

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
