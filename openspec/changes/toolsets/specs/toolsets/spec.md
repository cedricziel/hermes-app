## ADDED Requirements

### Requirement: Tools availability

The app SHALL show the Tools entry only while the connected server answers `GET /api/tools/toolsets`. It SHALL read that answer on connect and on app resume, and SHALL keep it as the Tools screen's first data. A `404` or `405` SHALL hide the entry without any message. A network failure or a `5xx` SHALL keep the previous answer and SHALL NOT show an error on its own.

#### Scenario: Server offers toolsets

- **WHEN** the list answers with rows
- **THEN** "Tools" appears after "MCP servers" in the chat sidebar and the drawer's More section, and as a section on the Mac Profiles page

#### Scenario: Old server

- **WHEN** the list answers `404`
- **THEN** no Tools entry, section or message appears anywhere

#### Scenario: Server goes away while the screen is open

- **WHEN** the screen is open and a read answers `404`
- **THEN** it shows "This server doesn't offer tools settings" with Back, and no error banner

#### Scenario: Offline on connect

- **WHEN** the first read fails with a network error
- **THEN** the entry stays hidden, nothing is shown, and the next resume reads again

### Requirement: Tools list

The Tools screen SHALL show the profile's toolsets in the settings kit (`SettingsScaffold`, `GroupedListView`), titled "Tools" with the subtitle "<profile> · <N> on", grouped "Needs setup" (`configured` false), "On" and "Off", omitting empty groups. Each row SHALL show the name, one plain sentence of what it lets Hermes do, its tool count and a switch. The app SHALL ignore the server's `available` field and keep the server's order inside a group.

#### Scenario: Grouped list

- **WHEN** the server lists `web` (on, not configured), `terminal` (on, configured), `video_gen` (off, configured)
- **THEN** "Needs setup" holds Web, "On" holds Terminal, "Off" holds Video generation

#### Scenario: On but not configured

- **WHEN** a toolset is on and `configured` is false
- **THEN** its row sits under "Needs setup", the switch shows on, the row shows the line "Needs setup" with a warning icon, and the detail's state line reads "On · needs setup"

#### Scenario: Sentence and order

- **WHEN** a row has a built-in name
- **THEN** it shows the app's own sentence, not the server's `description`, and a "Needs setup" row adds the line "Needs setup"

#### Scenario: Risk line

- **WHEN** a row's toolset is in the risk table at either level
- **THEN** the row shows "Can change things" with a shield icon under its sentence, and a toolset outside the table shows no such line

#### Scenario: Row and switch are separate targets

- **WHEN** the user taps a row's text
- **THEN** the detail opens and the switch does not change; tapping the switch changes it and does not open the detail

#### Scenario: Unknown toolset from a plugin

- **WHEN** the list has a toolset the app does not know
- **THEN** it shows the server's label and description, no risk text, and is switched like any other

#### Scenario: Unreadable rows

- **WHEN** some rows lack a name or have non-boolean flags
- **THEN** the unreadable rows are skipped, the others use `false` for a flag that is not a boolean, and `tools.parse_lenient` records the skipped count

#### Scenario: Empty list

- **WHEN** the server answers an empty list
- **THEN** the screen says "This profile has no tools to set up" with no action

#### Scenario: Loading and failure

- **WHEN** the list is loading
- **THEN** the screen shows a labelled progress state "Loading tools…"
- **WHEN** it fails with something other than 404/405
- **THEN** it shows "Couldn't load tools" with Try again, and rows already shown stay

### Requirement: Detail

Selecting a row SHALL open its detail, as a pane beside the list at 900 points or wider and as a pushed page below, showing in order: name, sentence and switch; the state line; what it lets Hermes do (risky toolsets); Set up; where it applies; and a collapsed "What's inside (N)".

#### Scenario: Setup needed opens in place

- **WHEN** the detail of a toolset that needs setup opens
- **THEN** the Set up section is open under the header and the risk note, there is no separate "Set up" button, and the key form's Save is the only filled button

#### Scenario: Order of the detail

- **WHEN** a toolset needs setup and is risky
- **THEN** the detail shows header, state line "On · needs setup", the risk note, the Set up section ("Change setup" when `configured` is true and the toolset has providers), where it applies, and the collapsed tool names

#### Scenario: Wide window

- **WHEN** the window is 900 points wide or more
- **THEN** the list is on the left, the first toolset's detail on the right, and selecting a row changes the detail

#### Scenario: Narrow window

- **WHEN** the window is narrower than 900 points
- **THEN** selecting a row pushes the detail as a page and Back returns to the list with the same scroll position

#### Scenario: Where it applies

- **WHEN** a toolset's `platform` is `cli`
- **THEN** the detail says "Used in your chats in this app and in the terminal"
- **WHEN** it is another platform
- **THEN** it says "Used in <platform label> chats only"

### Requirement: Switching a toolset

Switching a toolset SHALL send `PUT /api/tools/toolsets/{name}` with `enabled` and the profile, show the new state at once, and read the list again when the answer arrives. A refused or failed write SHALL restore the last confirmed state with "Couldn't change <name>. Try again.". A write whose answer is lost SHALL read the list again and SHALL NOT be sent again. Only one write per toolset SHALL be in flight.

#### Scenario: Switch on succeeds

- **WHEN** the user switches Web search on and the server answers ok
- **THEN** the row moves to On (or Needs setup), the note about the next chat shows, and the list was read again

#### Scenario: Write in flight

- **WHEN** the user flips a switch and the answer has not arrived
- **THEN** the switch shows the new position, is disabled with a small progress beside it, and the row stays in its group until the list is read again

#### Scenario: Failure shown on the row

- **WHEN** a write is refused or fails
- **THEN** the message shows as an error line on the row that was flipped, not only in a banner

#### Scenario: Effect on chats

- **WHEN** a change succeeded
- **THEN** the screen says "Applies from your next chat. A chat that is already open keeps the tools it started with."

#### Scenario: Refused

- **WHEN** the server answers `400`
- **THEN** the switch returns to its old position and the message shows

#### Scenario: Lost answer

- **WHEN** the connection drops after the request left
- **THEN** the row says "May have changed. Checking…", the list is read again, and the final state is the server's

#### Scenario: Double tap

- **WHEN** the user taps a switch twice quickly
- **THEN** the second change waits for the first answer

#### Scenario: Toolset vanished

- **WHEN** the write is refused with `400` "Unknown toolset" and the list read afterwards no longer holds it
- **THEN** "That tool is no longer on this server" shows and the detail selection moves to the first row

#### Scenario: Profile deleted

- **WHEN** a read or write answers `404` "Profile … does not exist"
- **THEN** the screen says "This profile no longer exists", the profile list is read again, and the Tools entry is NOT hidden

#### Scenario: Offline after opening

- **WHEN** a read or write fails with a network error
- **THEN** the screen says "You're offline." with Try again, switches return to their last confirmed state, and nothing is resent by itself

#### Scenario: Not allowed

- **WHEN** a write answers `401` or `403`
- **THEN** the message "You can't change tools on this server." shows and the switch returns

#### Scenario: Install started by the switch

- **WHEN** switching a toolset on answers `post_setup_started`
- **THEN** the screen says "Hermes started an installer on your server" and follows it as described in toolset-setup, without claiming which provider it is for

### Requirement: Confirming risky toolsets

Switching on `terminal`, `code_execution`, `computer_use` or `browser` SHALL first ask, every time, with a title "Let Hermes <do the thing>?", the sentence of what it lets Hermes do, "It applies to <profile>. You can switch it off again here.", Cancel (the default) and "Switch on". Cancel SHALL send nothing and leave the switch off. Switching off SHALL NOT ask. `file`, `cronjob`, `delegation` and `discord_admin` SHALL show their sentence in the row and the detail without asking.

#### Scenario: Terminal on

- **WHEN** the user switches Terminal on
- **THEN** an alert "Let Hermes run commands?" appears saying it can "Run commands on the machine where Hermes runs."

#### Scenario: Cancelled

- **WHEN** the user cancels
- **THEN** no request is sent and the switch stays off

#### Scenario: App Lock while the question is open

- **WHEN** App Lock engages with a confirmation open
- **THEN** the question is dismissed as cancelled and nothing is sent

#### Scenario: Off needs no question

- **WHEN** the user switches Computer use off
- **THEN** the request is sent without a question

#### Scenario: Not in the table

- **WHEN** a plugin toolset is switched on
- **THEN** no question is asked

### Requirement: What the difference is

The Tools screen footer SHALL link "What's the difference?" to a short explanation, one sentence each, of tools, skills, plugins and MCP servers, as a popover on macOS and a sheet elsewhere. The footers of the Skills, Plugins, MCP servers and Helper models screens SHALL carry the same link.

#### Scenario: Open the explanation

- **WHEN** the user taps the link on any of the five screens
- **THEN** the four sentences show: "Tools: what Hermes can do by itself, such as run commands, search the web or make images. You switch them on or off here.", "Skills: written instructions Hermes follows for a kind of job.", "Plugins: add-ons installed on the server. Some bring their own tools.", "MCP servers: outside programs or services that give Hermes extra tools."

### Requirement: Profile scope

Every request SHALL send the screen's profile explicitly. The screen SHALL show the chat's profile, or the profile picked on the Mac Profiles page, and a visit SHALL NOT change the server's active profile. Answers for a profile the screen no longer shows SHALL be dropped.

#### Scenario: Another profile's tools

- **WHEN** the user opens Tools from the Profiles page for "work"
- **THEN** the requests carry `profile=work` and the subtitle names "work"

#### Scenario: Profile switch while loading

- **WHEN** the chat profile changes while a read is in flight
- **THEN** the old answer is dropped and the list is read for the new profile

### Requirement: App Lock, sign-out and server change

While App Lock covers the app, Tools SHALL be covered with the rest and secret fields SHALL be cleared. Sign-out and Change Server SHALL drop the list, the setup state and any typed keys, and SHALL stop following installs in progress.

#### Scenario: App Lock

- **WHEN** App Lock engages while a key is typed
- **THEN** the field is empty when the app is unlocked

#### Scenario: Sign-out

- **WHEN** the user signs out with Tools open
- **THEN** the screen is gone and no state survives for the next account

### Requirement: Accessibility

Rows, switches and detail controls SHALL be at least 44 points (iOS, macOS) or 48 dp (Android) high, SHALL wrap text at the largest accessibility size without cutting a sentence, and SHALL carry meaning in text as well as colour. A switch SHALL have the label "<name>, on" or "<name>, off". Progress and results SHALL be announced. Reduced motion SHALL remove animation.

#### Scenario: Large text

- **WHEN** the system text size is the largest accessibility size
- **THEN** every sentence is shown in full, no control is cut off, and each row's switch moves under its text with the state in words ("On" or "Off")

#### Scenario: Keyboard

- **WHEN** the screen is used with a keyboard
- **THEN** focus moves list then detail, Space toggles the focused switch, and on macOS ⌘[ goes back

#### Scenario: Screen reader

- **WHEN** a row is focused
- **THEN** it reads the name, the sentence, the state and whether it needs setup

### Requirement: Observability

The feature SHALL record spans `tools.list`, `tools.toggle`, `tools.setup`, `tools.terminal_backend`, `tools.computer_use`, logs `tools.toggled`, `tools.setup_outcome`, `tools.parse_lenient` and breadcrumbs `tools.opened`, `tools.toggled`, `tools.risk_confirmed`, `tools.setup.step`, with counts, outcomes and a built-in toolset slug from a fixed list (`other` for any other) only.

#### Scenario: Nothing private is recorded

- **WHEN** a toggle, a key save and an install run
- **THEN** no record contains a profile name, a provider name, a key name or value, a URL, a model or text from Hermes
