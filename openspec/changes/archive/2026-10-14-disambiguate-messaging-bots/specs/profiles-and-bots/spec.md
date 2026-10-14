## MODIFIED Requirements

### Requirement: Bot list

The system SHALL list the messaging platforms of the connected dashboard with a switch to turn each on or off.

#### Scenario: Platforms are listed

- **WHEN** the Messaging screen opens
- **THEN** a progress indicator shows while loading, then each platform appears with its name, its description, and a switch reflecting whether it is enabled

#### Scenario: Needs setup

- **WHEN** a platform lacks a credential it requires
- **THEN** its row shows "Needs setup" and its switch cannot be turned on

#### Scenario: Enabled bot that lost its credential

- **WHEN** a platform is enabled but lacks a credential it requires
- **THEN** its row shows "Needs setup" and its switch can still be turned off

#### Scenario: Reported error

- **WHEN** a platform reports an error message
- **THEN** the message is shown in its row

#### Scenario: Switching a bot

- **WHEN** the user switches a platform on or off
- **THEN** the new enabled state is sent and the list is reloaded to show the state the dashboard now reports
- **AND WHEN** the dashboard refuses
- **THEN** the platform stays as it was and the user is told "Could not update this messaging platform"

#### Scenario: Loading fails

- **WHEN** loading the platforms fails
- **THEN** the screen shows "Could not load messaging platforms" with a Retry button that loads them again

#### Scenario: Rows that do not fit are skipped

- **WHEN** a platform row lacks a string `id` or `name`, or the response is not the expected envelope
- **THEN** that row is left out, and an unexpected body yields no platforms

#### Scenario: Entry point

- **WHEN** the chat sidebar has a messaging connection
- **THEN** it shows a Messaging entry that opens this screen, and the entry is not shown otherwise

### Requirement: Bot setup form

The system SHALL let the user open a platform to enter the credentials and settings it reads from its environment, without ever showing a stored value.

#### Scenario: One field per setting

- **WHEN** the user opens a platform
- **THEN** the "Set up <name>" form shows a field per setting, labelled with the setting's prompt (or its key), with its help text (or description) below it, and settings marked advanced are kept in an "Advanced" section that is collapsed unless a required advanced setting is not yet set

#### Scenario: Secrets stay hidden

- **WHEN** a setting is a password
- **THEN** its field hides what is typed
- **AND WHEN** a setting already has a value on the dashboard
- **THEN** the field shows "Set (<redacted value>). Leave blank to keep it." and never the value itself

#### Scenario: Required values

- **WHEN** a required setting has no value on the dashboard and its field is empty
- **THEN** saving is blocked with "Required"
- **AND WHEN** a required setting is already set
- **THEN** it need not be entered again

#### Scenario: Saving sends only what changed

- **WHEN** the user saves
- **THEN** only the non-blank (trimmed) values are sent, together with the keys marked to clear, and the platform's enabled state is left as it was
- **AND WHEN** nothing was entered and nothing is marked to clear
- **THEN** the form closes without a request

#### Scenario: Clearing a value

- **WHEN** a setting is set and not required, and the user taps its clear control
- **THEN** the field is emptied, marked "Will be cleared" and sent in the keys to clear on save
- **AND WHEN** the user taps it again
- **THEN** the setting is kept after all

#### Scenario: Save succeeds

- **WHEN** the dashboard accepts the setup
- **THEN** the form closes and the platform list reloads, where the platform no longer says "Needs setup"

#### Scenario: Save is refused

- **WHEN** the dashboard answers with status 400, 404, 409, 410 or 502 and a `detail` text
- **THEN** the form stays open and shows that text
- **AND WHEN** the failure is of any other kind
- **THEN** the form stays open and shows "Could not save the setup"

#### Scenario: Nothing to set up

- **WHEN** a platform has no settings
- **THEN** the screen says "Nothing to set up for this messaging platform."

### Requirement: Skills entry in the sidebar

The system SHALL show a Skills entry in the chat sidebar beside Profiles and Messaging when the chat has a dashboard connection, opening the Skills page (see the `skills` capability).

#### Scenario: Entry is shown

- **WHEN** the chat sidebar has a connection to the dashboard
- **THEN** it shows a Skills entry that opens the Skills page

#### Scenario: Entry is hidden

- **WHEN** the chat has no dashboard connection
- **THEN** the sidebar does not show a Skills entry

## ADDED Requirements

### Requirement: Messaging terminology

The system SHALL label generic messaging-platform management as “Messaging” and reserve the unqualified destination “Bots” for Bot Mode agents. Platform-specific bot names and credential labels SHALL remain accurate.

#### Scenario: Messaging entry explains its purpose

- **WHEN** the user opens Messaging
- **THEN** the screen explains “Connect Hermes to Telegram, Discord, and other messaging platforms.”
- **AND** existing setup and Telegram pairing continue to use `/api/messaging/platforms` and `/api/messaging/telegram/onboarding/*`, with their existing response shapes and no increase in the minimum supported Hermes version
