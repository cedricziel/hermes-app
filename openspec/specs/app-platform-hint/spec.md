# app-platform-hint Specification

## Purpose
Tells the agent how this app renders its replies (Markdown, `MEDIA:` attachments) by adding the app's prompt hint (`platform_hints.hermes_app`) to the user's Hermes profiles, only after the user agrees.

## Requirements

### Requirement: Profiles that need the app's hint are found

After sign-in and each time the app starts with a saved session, the system SHALL read the saved configuration of every profile on the server (`GET /api/config?profile=<name>&include_defaults=false`) and treat a profile as needing the hint when `platform_hints.hermes_app` is absent, or when its `replace` text equals a text an earlier version of the app wrote. A profile whose value is anything else SHALL be treated as configured by someone else and left alone. A profile whose config cannot be read SHALL be skipped. A failure to list profiles SHALL end the check without a prompt.

#### Scenario: Fresh server

- **WHEN** no profile has `platform_hints.hermes_app`
- **THEN** every profile needs the hint

#### Scenario: Hint written by an older app

- **WHEN** a profile's `platform_hints.hermes_app.replace` equals the text an earlier app version wrote
- **THEN** that profile needs the hint, as an update

#### Scenario: Operator's own hint

- **WHEN** a profile's `platform_hints.hermes_app` holds any other value
- **THEN** that profile does not need the hint and the app never changes it

### Requirement: The user is asked before anything is written

When at least one profile needs the hint and the user has not turned the question off for this server, the system SHALL show one prompt that says what the hint does, names the profiles it would be written to, and can show the exact text. With more than one profile, each SHALL be a checkbox, ticked at first, whose state is visible and announced; only ticked profiles SHALL be written, and the add button SHALL say how many and be off while none is ticked. It SHALL be a dialog on a wide layout and a bottom sheet on a compact one. The prompt SHALL offer: add it, ask on the next start, and do not ask again for this server. Dismissing the prompt SHALL count as asking on the next start. The prompt SHALL be shown at most once per app start and only in the main window.

#### Scenario: Not now

- **WHEN** the user chooses to be asked later
- **THEN** nothing is written and the prompt comes back on the next start

#### Scenario: Don't ask again

- **WHEN** the user turns the question off
- **THEN** nothing is written and the app does not ask again for this server

#### Scenario: Nothing to do

- **WHEN** every profile already has the current hint or an operator's own
- **THEN** no prompt is shown

### Requirement: Adding writes only the app's hint key

When the user adds the hint, the system SHALL send, for each ticked profile that needs it, `PUT /api/config?profile=<name>` with a body that contains only `platform_hints.hermes_app.replace` set to the current text. While the writes run the prompt SHALL show progress and SHALL NOT be dismissed by its buttons. When every write succeeds the prompt SHALL close. When some fail, the prompt SHALL say which profiles failed and offer to retry them; the profiles that succeeded SHALL show as saved, SHALL NOT be untickable and SHALL NOT be written again.

#### Scenario: One profile left out

- **WHEN** the user unticks one of three profiles and adds
- **THEN** only the two ticked profiles are written

#### Scenario: Partial failure

- **WHEN** the write for one of two profiles fails
- **THEN** the prompt names that profile and a retry writes only that one

### Requirement: The hint describes only what the app renders

The hint text SHALL tell the agent that the user reads its replies in the Hermes app on a phone or computer, that Markdown renders (headings, lists, tables, links, code blocks), that a file is delivered with `MEDIA:/absolute/path`, images showing inline and other files as downloads, and that there are no inline HTML previews or widgets. When the text changes, the previous text SHALL be kept in the list of texts the app recognises as its own.

#### Scenario: New hint text

- **WHEN** a new app version changes the hint text
- **THEN** a profile holding the previous text is offered the update, and a profile holding an edited text is not
