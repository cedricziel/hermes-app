## ADDED Requirements

### Requirement: Provider choice

The Set up section SHALL read `GET /api/tools/toolsets/{name}/config` when first opened and list the providers as radio rows with name, tag, badge and a status chip, marking the active one. Picking one SHALL send `PUT …/provider`. `has_category: false` SHALL show "Nothing to set up".

#### Scenario: Status chips

- **WHEN** a provider's status is `ready`, `needs_keys`, `needs_auth` or `needs_setup`
- **THEN** its chip reads Ready, Needs a key, Needs a sign-in on the server, or Needs install

#### Scenario: Pick a provider

- **WHEN** the user picks Firecrawl
- **THEN** the provider is sent, the matrix and the list are read again, and Firecrawl shows as selected

#### Scenario: Managed provider without a Nous sign-in

- **WHEN** the provider answer has `needs_nous_auth: true`
- **THEN** the row shows "This needs a sign-in to Nous Portal on your server. The app can't do that for you." and no key field

#### Scenario: Separate search and extract

- **WHEN** the user opens Advanced on Web and picks a different provider for extract
- **THEN** the request carries `capability: extract` and the search choice is unchanged

#### Scenario: Refused provider

- **WHEN** the server answers `400`
- **THEN** the old selection stays and Hermes' sentence shows

#### Scenario: Matrix loading and failure

- **WHEN** the matrix is loading
- **THEN** a labelled progress state "Loading setup…" shows
- **WHEN** it fails
- **THEN** "Couldn't load setup" with Try again shows, and the switch still works

#### Scenario: Unknown status

- **WHEN** a provider's status is not one of the four known ones
- **THEN** its chip says "Needs setup"

### Requirement: Keys

For the selected provider each env var SHALL be a masked field labelled with its `prompt`, with "Already set" when `is_set` and a "Get a key" link from `url`. Save SHALL send only non-blank values to `PUT …/env`, clear every field after the request whether it succeeded or not, and read the config again. Key values SHALL NOT be logged, put in telemetry, exception text or `toString`, or written to storage.

#### Scenario: Field behaviour

- **WHEN** a key field is shown
- **THEN** it disables autocorrect, suggestions, keyboard learning and autofill, offers no control that shows the typed value, and says "Saved on your server for <profile>. The app doesn't keep it."

#### Scenario: Characters typed

- **WHEN** the user types or pastes into a key field
- **THEN** a line under it says "<N> characters entered" (announced to screen readers, never stored or logged), and the line goes when the field is cleared

#### Scenario: Never shown in the app switcher

- **WHEN** the app switcher or a system snapshot captures the app with a key field on screen
- **THEN** the snapshot shows no key field content, because the field is cleared when the app becomes inactive, before the snapshot is taken

#### Scenario: Cleared on leaving

- **WHEN** the app goes to the background or inactive, App Lock engages, the profile changes, the user signs out or the server changes
- **THEN** every typed key is cleared

#### Scenario: Save a key

- **WHEN** the user types a key and saves
- **THEN** the request carries only that key, the field is empty afterwards, and the row shows "Already set"

#### Scenario: Failure clears too

- **WHEN** the save fails
- **THEN** the field has been cleared (as after every save), the message says "Couldn't save the key. Type it again.", and Save stays disabled until something is typed

#### Scenario: Blank is not sent

- **WHEN** the user leaves a field blank and saves another
- **THEN** only the other key is sent

#### Scenario: Remove a key

- **WHEN** the user wants a saved key gone
- **THEN** the screen says "To remove a key, edit it on your server." and offers no remove action

#### Scenario: Backgrounded with text typed

- **WHEN** the app goes to the background with a key typed
- **THEN** the field is empty when the app returns

#### Scenario: Lost answer

- **WHEN** the answer to a save is lost
- **THEN** the screen says "May have saved. Checking…", reads the config, and never sends the key again by itself

#### Scenario: Checking cannot finish

- **WHEN** that read fails, the app goes offline, or 10 seconds pass without an answer
- **THEN** "Checking…" ends, the key shows its last known state ("Already set" or the empty field), and the screen says "Couldn't confirm. Pull to refresh."

#### Scenario: Nothing recorded

- **WHEN** a key is saved
- **THEN** `tools.setup` records `step: env` and a key count only

### Requirement: Install on the server

When the selected provider has `post_setup`, the screen SHALL offer an install step that asks "Install on your server?" with "Hermes will run an installer on the server. It may download software." (Cancel default), sends `POST …/post-setup` and follows `GET /api/actions/tools-post-setup/status` every 2 seconds. One install SHALL run per connection and log lines SHALL NOT be logged.


#### Scenario: Progress

- **WHEN** an install runs
- **THEN** the last six log lines show as selectable text, the screen says "You can leave this screen. The install keeps going.", and the lines keep updating after the user leaves the screen and returns

#### Scenario: Install is the main action

- **WHEN** the selected provider's status is `needs_setup`
- **THEN** "Install on server" is the filled button of the section, with "Needed before this works. The app asks first.", and no Save button is filled beside it

#### Scenario: Installer started from the list

- **WHEN** switching a toolset on from the list answers `post_setup_started`
- **THEN** the list shows a banner "<name> is on." with "Hermes started an installer on your server. Applies from your next chat." and a Show button that opens the detail's install section

#### Scenario: Install succeeds

- **WHEN** the user confirms and the status ends with exit code 0
- **THEN** the screen says "Installed", and the config is read again

#### Scenario: Install fails

- **WHEN** the exit code is not 0
- **THEN** the screen says "The install didn't finish" with the last lines and Try again

#### Scenario: Cancelled question

- **WHEN** the user cancels the question
- **THEN** nothing is sent

#### Scenario: Left and returned

- **WHEN** the user leaves the screen during an install and returns
- **THEN** the progress is still shown

#### Scenario: Never ends

- **WHEN** 22 minutes pass without an exit code
- **THEN** the screen says "Couldn't tell whether it finished" and reads the setup again

#### Scenario: Started by the switch

- **WHEN** switching a toolset on answers `post_setup_started`
- **THEN** the screen shows "Hermes started an installer on your server" with the same log, the switch having been confirmed already, and ends in "Checking…" and a config read, not in "Installed" from the log

#### Scenario: Ended with no exit code

- **WHEN** the status says `running: false` with `exit_code: null`
- **THEN** the screen says "Couldn't tell whether it finished" and reads the setup again

#### Scenario: Install or follow fails

- **WHEN** the spawn answers `400` or `500`, or reading the status fails
- **THEN** Hermes' sentence or "Couldn't follow the install. Check again." shows, and polling retries with backoff three times

#### Scenario: Provider with keys and an install step

- **WHEN** the provider has both `env_vars` and `post_setup` and reports Ready
- **THEN** "Run the install step again" is offered under Advanced

#### Scenario: Another install in progress

- **WHEN** an install is already running from this app
- **THEN** other Install buttons are disabled with "Another install is running"

### Requirement: Install button emphasis

"Install on server" SHALL be the section's filled button exactly when the provider's status is `needs_setup`, and SHALL never be filled together with Save; otherwise it SHALL sit under Advanced as "Run the install step again".

#### Scenario: Ready provider with an install step

- **WHEN** the provider reports Ready and has `post_setup`
- **THEN** no filled install button shows and Advanced offers "Run the install step again"

### Requirement: Models for image and video generation

For `image_gen` and `video_gen`, after a provider is active, a "Model" row SHALL read `GET …/models` and open a list showing each model's `display`, `speed`, `strengths` and `price` with the default marked. Picking SHALL send `PUT …/model` and read again. A toolset with `has_models: false` SHALL show no Model row.

#### Scenario: Pick a model

- **WHEN** the user picks a model
- **THEN** it is sent, the row shows it as current, and the change applies from the next chat

#### Scenario: No catalog

- **WHEN** the answer is `has_models: false`
- **THEN** no Model row shows

#### Scenario: Refused model

- **WHEN** the server answers `400`
- **THEN** the old model stays and Hermes' sentence shows

### Requirement: Where commands run

The Terminal detail SHALL show "Where commands run" from `GET /api/tools/terminal/backends`: each backend with label, description, a status chip (Ready, Needs setup, Can't be used) and the active one marked. Choosing one SHALL send `PUT /api/tools/terminal/backend`. The app SHALL NOT edit any backend setting.

#### Scenario: Needs setup is selectable

- **WHEN** the user picks a backend whose status is not ready
- **THEN** it is sent and the row says "Commands will fail until this is set up on your server."

#### Scenario: Pick Docker

- **WHEN** the user picks Docker and it is ready
- **THEN** it is sent and marked active

#### Scenario: Pick Local

- **WHEN** the user picks Local
- **THEN** the question shows and nothing is sent until the user confirms

#### Scenario: Needs setup

- **WHEN** a backend's status is `needs_setup` with a detail
- **THEN** the detail shows under "From Hermes:" and the note about failing commands shows when it is picked

#### Scenario: Old server

- **WHEN** the backends route answers `404`
- **THEN** the section is not shown and the rest of the detail is unaffected

#### Scenario: Probe slow or failed

- **WHEN** the read is loading
- **THEN** a labelled progress state shows
- **WHEN** it fails
- **THEN** "Couldn't read where commands run" with Try again shows

### Requirement: Confirming the Local backend

Choosing `local` SHALL first ask "Run commands directly on your server?" with "Commands will run on the same machine as Hermes, with full access to that machine's files, not in a container." (Cancel default, "Use local").

#### Scenario: Local cancelled

- **WHEN** the user cancels the Local question
- **THEN** nothing is sent and the previous backend stays marked

### Requirement: Computer use readiness and permission

The Computer use detail SHALL show "Readiness" from `GET /api/tools/computer-use/status`: platform supported, driver installed, ready (unknown when `ready` is null), on a macOS server Accessibility and Screen recording, `checks` under "Details", and `error` text.

#### Scenario: Link to the Bot Screen

- **WHEN** the profile's Bot Screen is offered
- **THEN** "Open the bot's screen" shows and opens the existing viewer; it is absent otherwise

#### Scenario: Driver missing on a Mac server

- **WHEN** `can_grant` is true but `installed` is false and the permissions are null
- **THEN** "Allow access" is not offered and Install on server is

#### Scenario: Status read fails

- **WHEN** the status or models read fails with something other than 404/405
- **THEN** that section says "Couldn't read this. Try again." and the rest of the detail works

#### Scenario: macOS server missing screen recording

- **WHEN** the status has `accessibility: true`, `screen_recording: false`, `can_grant: true`
- **THEN** Accessibility shows "Allowed", Screen recording "Not allowed", and "Allow access" is offered

#### Scenario: Grant fails

- **WHEN** the grant spawn answers `400` or `500`
- **THEN** Hermes' sentence shows and nothing is followed

#### Scenario: Grant ends

- **WHEN** the grant action ends
- **THEN** the status is read again and the rows reflect it

#### Scenario: Linux server

- **WHEN** `platform` is `linux` and `can_grant` is false
- **THEN** only driver and readiness rows show

#### Scenario: Unknown readiness

- **WHEN** `ready` is null
- **THEN** it reads "Couldn't tell" with the `error` text if any

#### Scenario: Grant refused

- **WHEN** the grant answers `400`
- **THEN** Hermes' sentence shows and no progress is followed

#### Scenario: Old server

- **WHEN** the status route answers `404`
- **THEN** the Readiness section is not shown

### Requirement: Allowing access on a Mac server

When `can_grant` and `installed` are true and a permission is exactly `false`, the Computer use detail SHALL offer "Allow access". It SHALL ask "Allow access on the server's Mac?" with "A permission window will open on the computer that runs Hermes. Someone there has to approve it." (Cancel default), send `POST …/permissions/grant`, follow `GET /api/actions/computer-use-grant/status`, and read the status again at the end.

#### Scenario: Confirm and follow

- **WHEN** the user confirms
- **THEN** the grant is sent, progress shows, and at the end the readiness rows are read again

#### Scenario: Cancelled

- **WHEN** the user cancels the question
- **THEN** nothing is sent

### Requirement: Effect and honesty

After any setup write the screen SHALL say "Applies from your next chat." The screen SHALL NOT claim a toolset works until Hermes reports it configured, and SHALL show the server's own wording for a refusal.

#### Scenario: Not yet ready

- **WHEN** a key is saved but the provider still reports `needs_setup`
- **THEN** the state line says what is still missing rather than "Ready"
