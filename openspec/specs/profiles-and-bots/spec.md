# Profiles and Bots Specification

## Purpose

Hermes can run several profiles, each with its own sessions, and can run as a bot on messaging platforms such as Telegram. This spec covers the two screens the chat sidebar links to: Profiles, where the user picks the profile the chat shows, and Bots, where the user switches messaging platforms on or off, enters their credentials, and pairs a Telegram bot. It describes the behaviour of the code as it is today.

## Requirements

### Requirement: Profile list

The system SHALL list the profiles of the connected dashboard, marking the active one, and SHALL offer a Retry when loading fails.

#### Scenario: Profiles are listed

- **WHEN** the Profiles screen opens
- **THEN** a progress indicator shows while loading, then each profile appears with its display name (or its name when it has none), a subtitle of its description, model and "N skills" joined by " · ", and an "Active" chip on the profile the dashboard reports as active

#### Scenario: Rows that do not fit are skipped

- **WHEN** a profile row has no non-empty string name
- **THEN** that row is left out

#### Scenario: Loading fails

- **WHEN** loading the profiles fails
- **THEN** the screen shows "Could not load profiles" with a Retry button that loads them again

#### Scenario: Entry point

- **WHEN** the chat sidebar has a profiles repository
- **THEN** it shows a Profiles entry that opens this screen, and the entry is not shown otherwise

### Requirement: Switching profile

The system SHALL let the user choose a profile, SHALL make it the dashboard's active (sticky default) profile when it is not already, and SHALL move the chat to that profile's threads.

#### Scenario: Choosing another profile

- **WHEN** the user taps a profile that is not active
- **THEN** the dashboard is asked to make it the active profile, the chat reloads its thread list for that profile, and the list of profiles is refreshed

#### Scenario: Choosing the active profile when the chat shows another

- **WHEN** the user taps the active profile while the chat shows a different one
- **THEN** no request to change the active profile is sent, and the chat reloads its thread list for the tapped profile

#### Scenario: Choosing the profile already in use

- **WHEN** the user taps the profile that is both active and shown in the chat
- **THEN** nothing is sent and the chat is not reloaded

#### Scenario: Switch is rejected

- **WHEN** the dashboard refuses the change of active profile
- **THEN** the user is told "Could not switch profile", the old profile stays active, and the chat is not changed

#### Scenario: The chat and the CLI default differ

- **WHEN** the profile shown in the chat differs from the active profile (for example after `hermes profile use` on the server)
- **THEN** a notice "The chat shows X. The CLI default is Y." is shown at the top of the list
- **AND** when the chat has no profile of its own, the profile the dashboard is scoped to is taken as the one shown

### Requirement: Chat scoped to a profile

The system SHALL read and change sessions for the profile the chat shows, since a session id is only unique within one profile.

#### Scenario: Threads of the active profile

- **WHEN** the chat opens
- **THEN** it asks the dashboard for its active profile and lists the sessions of that profile, and reads a session's messages from that same profile

#### Scenario: Active profile unknown

- **WHEN** the active profile cannot be read
- **THEN** the chat asks for sessions without naming a profile, leaving the choice to the dashboard

#### Scenario: Switching discards cached transcripts

- **WHEN** the chat switches profile
- **THEN** it shows the new profile's threads, and a session id that exists in both profiles shows the new profile's transcript

### Requirement: Bot list

The system SHALL list the messaging platforms of the connected dashboard with a switch to turn each on or off.

#### Scenario: Platforms are listed

- **WHEN** the Bots screen opens
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

- **WHEN** the user switches a bot on or off
- **THEN** the new enabled state is sent and the list is reloaded to show the state the dashboard now reports
- **AND WHEN** the dashboard refuses
- **THEN** the bot stays as it was and the user is told "Could not update this bot"

#### Scenario: Loading fails

- **WHEN** loading the platforms fails
- **THEN** the screen shows "Could not load bots" with a Retry button that loads them again

#### Scenario: Rows that do not fit are skipped

- **WHEN** a platform row lacks a string `id` or `name`, or the response is not the expected envelope
- **THEN** that row is left out, and an unexpected body yields no bots

#### Scenario: Entry point

- **WHEN** the chat sidebar has a bots repository
- **THEN** it shows a Bots entry that opens this screen, and the entry is not shown otherwise

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
- **THEN** the form closes and the bot list reloads, where the bot no longer says "Needs setup"

#### Scenario: Save is refused

- **WHEN** the dashboard answers with status 400, 404, 409, 410 or 502 and a `detail` text
- **THEN** the form stays open and shows that text
- **AND WHEN** the failure is of any other kind
- **THEN** the form stays open and shows "Could not save the setup"

#### Scenario: Nothing to set up

- **WHEN** a platform has no settings
- **THEN** the screen says "Nothing to set up for this bot."

### Requirement: Telegram pairing

The system SHALL offer to pair a Telegram bot without the user creating one by hand, on the Telegram platform only: the dashboard's setup service makes a bot, the user claims it by opening a link in Telegram, and then names the Telegram accounts allowed to talk to it. The bot's token SHALL go from the setup service to the dashboard and never to the app.

#### Scenario: Offered for Telegram only

- **WHEN** the setup form of the Telegram platform opens
- **THEN** a "Set up with Telegram" button is shown above the manual fields
- **AND** other platforms do not show it

#### Scenario: Pairing starts

- **WHEN** the pairing screen opens
- **THEN** the dashboard is asked to start a pairing, and the screen shows the link to open, an "Open Telegram" button that opens it in an external app, a "Copy link" button, and "Waiting for you in Telegram"

#### Scenario: Waiting for the claim

- **WHEN** the pairing has started
- **THEN** its status is polled every 3 seconds while the bot is not yet claimed, and polling stops when the screen is left

#### Scenario: Claimed

- **WHEN** the status reports the bot as ready
- **THEN** the screen names the bot (`@username`, when known), and offers a field "Allowed Telegram user IDs" prefilled with the claiming account's numeric user id when Telegram reported one

#### Scenario: Allowed users are validated

- **WHEN** the user finishes with no user id
- **THEN** the screen asks for "at least one Telegram user ID"
- **AND WHEN** an entry is not numeric
- **THEN** it asks for numeric IDs separated by commas, and nothing is sent

#### Scenario: Finishing

- **WHEN** the user finishes with valid comma-separated ids
- **THEN** the ids are sent to apply the pairing, the dashboard saves the token and the ids and switches Telegram on, and the screens close back to the refreshed bot list

#### Scenario: Apply is refused

- **WHEN** applying fails with an explained refusal (status 400, 404, 409, 410 or 502 with a `detail`)
- **THEN** the form stays and shows the reason
- **AND WHEN** it fails otherwise
- **THEN** the form stays and shows "Could not save the setup"

#### Scenario: Pairing cannot start or has expired

- **WHEN** starting the pairing or polling its status fails
- **THEN** the screen shows the dashboard's reason when it gave one, or "Could not reach the Telegram setup", with a "Start again" button that cancels the old pairing and starts a new one

#### Scenario: Incomplete start response

- **WHEN** the start response lacks a pairing id or a link
- **THEN** it is treated as a failure

#### Scenario: Leaving cancels the pairing

- **WHEN** the user leaves the screen before applying
- **THEN** the pairing is cancelled on the dashboard, best effort, and a failure to cancel is ignored

### Requirement: Backend contract

The system SHALL use the following dashboard routes for profiles and bots, and SHALL parse their untyped responses leniently.

#### Scenario: Profile routes

- **WHEN** the app reads or switches profiles
- **THEN** it uses `GET /api/profiles` (envelope `profiles`; per row `name`, `display_name`, `description`, `model`, `provider`, `is_default`, `skill_count`, `gateway_running`), `GET /api/profiles/active` (`active`, `current`) and `POST /api/profiles/active` (body `name`)

#### Scenario: Bot routes

- **WHEN** the app reads or changes messaging platforms
- **THEN** it uses `GET /api/messaging/platforms` (envelope `platforms`; per row `id`, `name`, `description`, `enabled`, `configured`, `state`, `error_message`, `env_vars` with `key`, `prompt`, `description`, `help`, `required`, `is_set`, `redacted_value`, `is_password`, `advanced`) and `PUT /api/messaging/platforms/{id}` (body `enabled`, or `env` and `clear_env`)

#### Scenario: Telegram routes

- **WHEN** the app pairs a Telegram bot
- **THEN** it uses `POST /api/messaging/telegram/onboarding/start` (response `pairing_id`, `deep_link`), `GET /api/messaging/telegram/onboarding/{pairing_id}` (response `status`, where `ready` means claimed, plus `bot_username` and `owner_user_id`), `POST /api/messaging/telegram/onboarding/{pairing_id}/apply` (body `allowed_user_ids`) and `DELETE /api/messaging/telegram/onboarding/{pairing_id}`
