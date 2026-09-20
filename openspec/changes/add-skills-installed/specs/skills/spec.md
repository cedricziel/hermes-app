## Purpose

Lets the user see and manage the skills a Hermes profile has installed from the app: switch them on and off, read and edit their `SKILL.md`, create new ones, and ask the agent to delete one.

## ADDED Requirements

### Requirement: Skills entry point

The system SHALL open the Skills page from the chat sidebar when the chat has a connection to the dashboard, and SHALL start it on the profile the chat is using.

#### Scenario: Opening Skills

- **WHEN** the user taps Skills in the chat sidebar
- **THEN** the Skills page opens for the chat's current profile, and the profile chip shows that profile's name

#### Scenario: No connection

- **WHEN** the chat has no dashboard connection (for example the demo chat)
- **THEN** the sidebar does not show a Skills entry

### Requirement: Installed skills list

The system SHALL list the installed skills of the selected profile grouped by category, and SHALL offer a Retry when loading fails.

#### Scenario: Skills are listed

- **WHEN** the Skills page opens
- **THEN** a progress indicator shows while loading, then skills appear under category headers in alphabetical order, each row showing the name, a one-line description, a badge for its source (Bundled, Hub or Agent), its usage count when above zero, and an on/off switch

#### Scenario: Category is missing

- **WHEN** a skill has no category
- **THEN** it appears under an "Other" header shown last

#### Scenario: Rows that do not fit are skipped

- **WHEN** a skill row has no non-empty string name
- **THEN** that row is left out

#### Scenario: Loading fails

- **WHEN** loading the skills fails
- **THEN** the page shows "Could not load skills" with a Retry button that loads them again

#### Scenario: No skills

- **WHEN** the profile has no skills
- **THEN** the page says so instead of showing an empty list

### Requirement: Search and filter

The system SHALL let the user narrow the list by text and by source, without another request to the server.

#### Scenario: Searching

- **WHEN** the user types in the search field
- **THEN** only skills whose name, description or category contains the text, ignoring case, remain, and empty category groups are hidden

#### Scenario: Filtering by source

- **WHEN** the user selects the Hub, Bundled or Agent chip
- **THEN** only skills from that source remain

#### Scenario: Filtering by state

- **WHEN** the user selects the Enabled chip
- **THEN** only enabled skills remain

#### Scenario: Nothing matches

- **WHEN** the search and filters match no skill
- **THEN** the page says no skills match and offers to clear the filters

### Requirement: Switching a skill on or off

The system SHALL let the user switch any installed skill on or off for the selected profile, and SHALL reflect the server's answer.

#### Scenario: Switching off

- **WHEN** the user turns a skill's switch off
- **THEN** the switch changes at once, the change is sent for the selected profile, and the row is shown greyed

#### Scenario: The change fails

- **WHEN** the server rejects or cannot be reached for a switch
- **THEN** the switch returns to its previous position and a message says the skill could not be changed

#### Scenario: Selected profile is not the chat's profile

- **WHEN** the user switches a skill while another profile is selected
- **THEN** the change applies to the selected profile only and the chat's profile is untouched

### Requirement: Profile picker

The system SHALL let the user choose which profile the Skills page shows, without changing the profile the chat uses.

#### Scenario: Choosing another profile

- **WHEN** the user picks another profile from the chip
- **THEN** the list reloads for that profile and every action on the page applies to it

#### Scenario: Profiles cannot be loaded

- **WHEN** the list of profiles cannot be loaded
- **THEN** the chip is not shown as a picker and the page keeps working on the chat's profile

### Requirement: Skill detail

The system SHALL show a skill's `SKILL.md` rendered as markdown, together with its category, source, usage count and on/off switch.

#### Scenario: Opening a skill

- **WHEN** the user taps a skill row
- **THEN** a detail page loads the skill's `SKILL.md` for the selected profile and shows it rendered, with a progress indicator while loading

#### Scenario: Content cannot be loaded

- **WHEN** loading the content fails
- **THEN** the page shows "Could not load this skill" with a Retry button, and the switch still works

#### Scenario: Actions for an agent-authored skill

- **WHEN** the skill is agent-authored
- **THEN** Edit and "Ask agent to delete" are offered

#### Scenario: Actions for a bundled or hub skill

- **WHEN** the skill is bundled or from the hub
- **THEN** neither is offered, and the page says bundled skills can only be switched on or off

### Requirement: Editing SKILL.md

The system SHALL let the user rewrite an agent-authored skill's `SKILL.md` in a text editor with a rendered preview, and SHALL not lose their text if saving fails.

#### Scenario: Editing and previewing

- **WHEN** the user opens Edit
- **THEN** a monospaced editor shows the current text, and an Edit / Preview toggle shows the same text rendered

#### Scenario: Saving

- **WHEN** the user taps Save with changes
- **THEN** the whole file is sent for the selected profile, and on success the editor closes and the detail page shows the new text

#### Scenario: Saving fails

- **WHEN** the server refuses the text (for example it fails its checks) or cannot be reached
- **THEN** the editor stays open with the text unchanged and shows the server's reason when it gave one

#### Scenario: Leaving with unsaved changes

- **WHEN** the user closes the editor with unsaved changes
- **THEN** it asks whether to discard them, and leaves only when they agree

#### Scenario: Nothing changed

- **WHEN** the text equals what was loaded
- **THEN** Save is disabled and closing does not ask

### Requirement: Creating a skill

The system SHALL let the user create a new agent-authored skill from a name, an optional category and `SKILL.md` text.

#### Scenario: Creating

- **WHEN** the user taps New skill, fills in a name and text and saves
- **THEN** the skill is created for the selected profile, appears in the list, and its detail page opens

#### Scenario: The template

- **WHEN** the create editor opens
- **THEN** it starts with a `SKILL.md` template containing front matter for the name and description

#### Scenario: Name is missing

- **WHEN** the name is empty
- **THEN** Save is disabled

#### Scenario: The server refuses

- **WHEN** the server rejects the skill (for example a name that already exists)
- **THEN** the editor stays open with the entered text and shows the server's reason

### Requirement: Asking the agent to delete a skill

The system SHALL offer, for agent-authored skills only, to have the agent delete the skill, by placing a drafted message in the chat composer.

#### Scenario: Asking

- **WHEN** the user taps "Ask agent to delete" and confirms
- **THEN** the app returns to the chat and the composer holds a message asking the agent to delete that skill, which the user sends or edits

#### Scenario: Nothing is sent automatically

- **WHEN** the composer is filled this way
- **THEN** no message is sent until the user sends it, and an existing draft is kept above the new text

### Requirement: Backend contract

The system SHALL use the dashboard's skills routes and SHALL tolerate response shapes it does not recognise.

#### Scenario: Routes used

- **WHEN** the Skills page reads or changes skills
- **THEN** it uses `GET /api/skills` (rows with `name`, `description`, `category`, `enabled`, `usage`, `provenance` of `hub`, `bundled` or `agent`), `PUT /api/skills/toggle` (body `name`, `enabled`, `profile`), `GET /api/skills/content` (query `name`, `profile`; reply `content`), `PUT /api/skills/content` (body `name`, `content`, `profile`) and `POST /api/skills` (body `name`, `content`, `category`, `profile`), with the selected profile passed on every call

#### Scenario: Unknown provenance

- **WHEN** a row has a missing or unrecognised provenance
- **THEN** it is treated as bundled, so it can be switched but not edited

#### Scenario: Older server

- **WHEN** the server answers 404 for the skills list
- **THEN** the page says the connected Hermes does not support skills instead of showing an error with Retry
