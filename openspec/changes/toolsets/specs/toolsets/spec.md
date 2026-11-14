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

#### Scenario: State line

- **WHEN** the detail opens
- **THEN** its state line reads "On", "Off", "On · needs setup" or "Off · needs setup", each with an icon as well as a colour

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

Switching a toolset SHALL send `PUT /api/tools/toolsets/{name}` with `enabled` and the profile, show the new state at once (after the question, when one is asked), and read the list again when the answer arrives. A refused or failed write SHALL restore the last confirmed state (see Write failures). A write whose answer is lost SHALL read the list again and SHALL NOT be sent again. Only one write per toolset SHALL be in flight.

#### Scenario: Switch on succeeds

- **WHEN** the user switches Web search on and the server answers ok
- **THEN** the row moves to On (or Needs setup), the note about the next chat shows, and the list was read again

#### Scenario: Write in flight

- **WHEN** the user flips a switch that needs no question and the answer has not arrived
- **THEN** the switch shows the new position, is disabled with a small progress beside it, a screen reader hears "<name>, <new state>, saving" and the switch reports itself disabled, and the row stays in its group until the list is read again

#### Scenario: Failure shown on the row

- **WHEN** a write is refused or fails, including for a network error
- **THEN** the message shows as an error line on the row that was flipped, never in a page banner, and stays until that row is switched successfully or the list is read again

#### Scenario: Effect on chats

- **WHEN** a change succeeded
- **THEN** the screen says "Applies from your next chat. A chat that is already open keeps the tools it started with."

#### Scenario: Refused

- **WHEN** the server answers `400`
- **THEN** the switch returns to its old position and the row's error line shows Hermes' own text

#### Scenario: Lost answer

- **WHEN** the connection drops after the request left
- **THEN** the row says "May have changed. Checking…", the list is read again, and the final state is the server's

#### Scenario: Checking cannot finish

- **WHEN** the read after a lost answer fails, the app goes offline, or 10 seconds pass without an answer
- **THEN** "Checking…" ends, the switch shows the last saved state, the row says "Couldn't confirm. Pull to refresh.", and nothing is sent again

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

- **WHEN** a read fails with a network error
- **THEN** a banner says "You're offline." and "Couldn't load tools. Switches show what was last saved." with Try again, the rows already shown stay, and nothing is resent by itself
- **WHEN** a write fails with a network error
- **THEN** the switch returns to its last confirmed state and the row's error line says "You're offline. Couldn't change <name>."

#### Scenario: Not allowed

- **WHEN** a write answers `401` or `403`
- **THEN** the message "You can't change tools on this server." shows and the switch returns

#### Scenario: Install started by the switch

- **WHEN** switching a toolset on answers `post_setup_started`
- **THEN** the screen says "Hermes started an installer on your server" and follows it as described in toolset-setup, without claiming which provider it is for

### Requirement: Write failures

A failed write SHALL be reported as an error line on the row that was flipped, never in a page banner: Hermes' own text for a `400`, "You can't change tools on this server." for `401` or `403`, "You're offline. Couldn't change <name>." for a network error, and "Couldn't change <name>. Try again." for anything else. The line SHALL stay until that row's next successful switch or the next read of the list.

#### Scenario: Error line lifetime

- **WHEN** a row shows an error line and the user switches that row successfully or the list is read again
- **THEN** the error line is gone

### Requirement: Unconfirmed writes

When the read after a lost answer fails, the app goes offline, or 10 seconds pass without an answer, "Checking…" SHALL end, the row SHALL show the last saved state with "Couldn't confirm. Pull to refresh." ("Couldn't confirm. Try again." with a Try again action where there is no pull to refresh), and nothing SHALL be sent again.

#### Scenario: Desktop wording

- **WHEN** a lost answer cannot be confirmed on a Mac or another desktop
- **THEN** the row says "Couldn't confirm. Try again." and its Try again reads the list again

### Requirement: Confirming risky toolsets

Switching on `terminal`, `code_execution`, `computer_use` or `browser` SHALL first ask, every time, with a title "Let Hermes <do the thing>?", a body (see Question wording), Cancel (the default) and "Switch on". Until the user confirms, the switch SHALL stay off and nothing SHALL be sent. Switching off SHALL NOT ask. `file`, `cronjob`, `delegation` and `discord_admin` SHALL NOT ask.

#### Scenario: Terminal on

- **WHEN** the user switches Terminal on
- **THEN** an alert "Let Hermes run commands?" appears saying it can "Run commands on the machine where Hermes runs."

#### Scenario: Question wording

- **WHEN** a confirm-level question shows for the profile "work"
- **THEN** its body is the sentence of what the toolset lets Hermes do, then "It applies to the profile "work".", then "Switching it off stops new commands. It doesn't undo what they did." ("actions" in place of "commands" for Browser and Computer use)

#### Scenario: Cancelled

- **WHEN** the user cancels
- **THEN** no request is sent and the switch stays off

#### Scenario: Switch waits for the answer to the question

- **WHEN** the question is open
- **THEN** the switch still shows off, nothing has been sent, and the saving state starts only after "Switch on"


#### Scenario: App Lock while the question is open

- **WHEN** App Lock engages with a confirmation open
- **THEN** the question is dismissed as cancelled and nothing is sent

#### Scenario: Off needs no question

- **WHEN** the user switches Computer use off
- **THEN** the request is sent without a question

#### Scenario: Not in the table

- **WHEN** a plugin toolset without an install step is switched on
- **THEN** no question is asked

### Requirement: Confirming installs

Switching on a toolset with a provider that has an install step (`post_setup`, from its provider matrix) SHALL ask before sending, since the switch can start that install. A confirm-level toolset SHALL add a sentence to its own question; any other SHALL ask "Install on your server?" with "Switching <name> on may run an installer on the server. It may download software.", Cancel (the default) and "Switch on".

#### Scenario: Computer use with a driver to install

- **WHEN** the user switches Computer use on and its driver provider has an install step
- **THEN** the question adds "It may also install a driver on the server."

#### Scenario: Other toolset with an install step

- **WHEN** a toolset outside the risk table has a provider with an install step
- **THEN** switching it on asks "Install on your server?" first and sends nothing until "Switch on"

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

Rows, switches and detail controls SHALL be at least 44 points (iOS) or 48 dp (Android) high (Mac: see Mac pointer targets), SHALL wrap text at the largest accessibility size without cutting a sentence, and SHALL carry meaning in text as well as colour. A switch SHALL have the label "<name>, on" or "<name>, off". Progress and results SHALL be announced. Reduced motion SHALL remove animation.

#### Scenario: Large text

- **WHEN** the system text size is the largest accessibility size
- **THEN** every sentence is shown in full, no control is cut off, each row's switch moves under its text with the state in words ("On" or "Off"), and in the detail header the switch moves under the name with the state line beside it

#### Scenario: Keyboard

- **WHEN** the screen is used with a keyboard
- **THEN** focus moves list then detail, Space toggles the focused switch, and on macOS ⌘[ goes back

#### Scenario: Screen reader

- **WHEN** a row is focused
- **THEN** it reads the name, the sentence, "Can change things" when the row has the risk line, the state and whether it needs setup
- **WHEN** the detail's risk note is focused
- **THEN** it reads as one element: its title, then its sentence

### Requirement: Mac pointer targets

On macOS, where the pointer is the input, targets SHALL follow the app's Mac sizes (grouped rows 40 points, toolbar buttons and sidebar rows 28 points) and none SHALL be smaller than 28 points.

#### Scenario: Mac rows

- **WHEN** the Tools screen is shown on a Mac
- **THEN** its rows are at least 40 points high and its smallest buttons at least 28 points

### Requirement: Observability

The feature SHALL record spans `tools.list`, `tools.toggle`, `tools.setup`, `tools.terminal_backend`, `tools.computer_use`, logs `tools.toggled`, `tools.setup_outcome`, `tools.parse_lenient` and breadcrumbs `tools.opened`, `tools.toggled`, `tools.risk_confirmed`, `tools.setup.step`, with counts, outcomes and a built-in toolset slug from a fixed list (`other` for any other) only.

#### Scenario: Nothing private is recorded

- **WHEN** a toggle, a key save and an install run
- **THEN** no record contains a profile name, a provider name, a key name or value, a URL, a model or text from Hermes
