## Purpose

Describes how the app creates and changes scheduled tasks: the gallery of blueprints, the blueprint form, the form for a custom task and for editing, how "when" is chosen and written, how delivery targets are offered, and which backend routes it relies on.

## ADDED Requirements

### Requirement: New task gallery

The system SHALL offer a "New" action on the Schedules list that opens a gallery with a "Custom task" card and the server's blueprints from `GET /api/cron/blueprints`. Each blueprint card SHALL show its title, description and its schedule in words (`scheduleHuman`). The gallery SHALL have a search field matching titles, descriptions and tags, and one chip per category the blueprints carry. A blueprint the app cannot render SHALL be skipped. When the blueprints cannot be loaded, the gallery SHALL still offer "Custom task" and say the templates are unavailable.

#### Scenario: Gallery opens

- **WHEN** the user taps "New" and the server lists blueprints
- **THEN** a "Custom task" card and a card for each blueprint are shown

#### Scenario: Search

- **WHEN** the user types "news"
- **THEN** only blueprints whose title, description or tags contain it are shown

#### Scenario: Category

- **WHEN** the user picks the category "daily"
- **THEN** only daily blueprints are shown

#### Scenario: Blueprints unavailable

- **WHEN** the blueprint request fails
- **THEN** "Custom task" is still offered and a note says the templates could not be loaded

### Requirement: Blueprint form

The system SHALL build a form from the slots of the chosen blueprint: a `time` slot as a time picker, an `enum` slot as a choice from its options (or free text when the slot is not strict), a `text` slot as a text field and a `weekdays` slot as a choice of the presets and single days the slot lists. Slots start at their default; an optional slot MAY be left empty and a required one SHALL NOT. The form SHALL send the filled values with `POST /api/cron/blueprints/instantiate?profile=<profile>`, for the profile the user is creating in, and on success show the new job. A 422 answer SHALL be shown against the slot it names, or on the form when it names none, and the values SHALL stay.

#### Scenario: Defaults

- **WHEN** the user opens "Morning briefing"
- **THEN** its time slot shows 08:00 and its delivery slot shows its default

#### Scenario: Created

- **WHEN** the user fills the form and saves and the server accepts
- **THEN** the job appears in the list and its detail is shown

#### Scenario: Slot refused

- **WHEN** the server answers 422 naming a slot
- **THEN** the message is shown under that slot and the entered values are kept

### Requirement: Job form

The system SHALL let the user create a job from "Custom task" with `POST /api/cron/jobs?profile=<profile>`, and change one from its detail with `PUT /api/cron/jobs/{id}?profile=<profile>`. The form SHALL have a name, a prompt, "when", "deliver to", a profile (creating only), "start paused" (creating only), and an Advanced section with skills, model, provider, a pre-run script, jobs to take context from, and a working directory. Skills and context-from entries are typed as names separated by commas or lines. On edit, the request SHALL carry only the fields the user changed, and SHALL leave every other field of the job as the server has it. A job SHALL NOT be saved without a schedule, nor without a prompt, a skill or a script. Empty optional text SHALL be sent as absent on create and as cleared on edit.

#### Scenario: Create

- **WHEN** the user enters a prompt, chooses "Every 6 hours" and saves
- **THEN** a create request with that prompt and the schedule `every 6h` is sent for the chosen profile

#### Scenario: Edit sends changes only

- **WHEN** the user changes only the prompt of an existing job
- **THEN** the update request carries the prompt and nothing else

#### Scenario: Nothing to run

- **WHEN** the prompt, skills and script are all empty
- **THEN** the form refuses to save and says a task needs a prompt, a skill or a script

#### Scenario: Clearing a field on edit

- **WHEN** the user empties the model field of a job that had one
- **THEN** the update request clears the model

#### Scenario: Server refuses

- **WHEN** the server answers 400 with a reason, for example a script outside the profile's scripts folder
- **THEN** the reason is shown on the form, the values stay and nothing is closed

### Requirement: Choosing when

The system SHALL offer Every, Daily, Weekly, Once and Cron for "when", and SHALL write the schedule the server reads: Every as `every <n><unit>` with minutes, hours or days; Daily as a five-field expression `<minute> <hour> * * *`; Weekly as `<minute> <hour> * * <days>` with the chosen days as numbers, at least one day chosen; Once as the chosen local date and time in ISO 8601 with its UTC offset, which SHALL NOT be in the past; and Cron as the text the user typed, trimmed and not empty. Every SHALL take a whole number of one or more. For Every, Daily, Weekly and Once the form SHALL preview the next runs; for Cron it SHALL NOT, and the server's answer decides.

#### Scenario: Every

- **WHEN** the user chooses Every, 6 and hours
- **THEN** the schedule written is `every 6h`

#### Scenario: Daily

- **WHEN** the user chooses Daily at 08:30
- **THEN** the schedule written is `30 8 * * *`

#### Scenario: Weekly

- **WHEN** the user chooses Monday and Thursday at 09:00
- **THEN** the schedule written is `0 9 * * 1,4`

#### Scenario: Once in the past

- **WHEN** the chosen date and time have passed
- **THEN** the form refuses to save and says the time is in the past

#### Scenario: No weekday

- **WHEN** Weekly is chosen with no day
- **THEN** the form refuses to save

#### Scenario: Preview

- **WHEN** the user sets Daily at 08:30
- **THEN** the form lists the next three run times

### Requirement: Editing shows the job's own schedule

The system SHALL open an existing job with "when" set from its stored schedule: an `interval` of whole minutes, hours or days as Every, a `cron` expression that is exactly a daily or weekly one as Daily or Weekly, a `once` as Once, and anything else as Cron with the stored expression as text. Saving without touching "when" SHALL NOT send a schedule.

#### Scenario: Interval job

- **WHEN** a job has the interval schedule of 360 minutes
- **THEN** the form shows Every, 6, hours

#### Scenario: Unusual expression

- **WHEN** a job's cron expression is `*/7 9-17 * * 1-5`
- **THEN** the form shows Cron with that text

#### Scenario: Schedule untouched

- **WHEN** the user edits only the name and saves
- **THEN** no schedule is sent

### Requirement: Delivery targets

The system SHALL offer the targets from `GET /api/cron/delivery-targets` for "deliver to", the implicit local target first, and SHALL warn under a target whose `home_target_set` is false that no home channel is set on the server. A job whose stored target is not in the list SHALL keep it as an extra choice. When the list cannot be loaded the field SHALL offer local only, and an edited job SHALL keep its stored target.

#### Scenario: No home channel

- **WHEN** the user picks a platform listed with `home_target_set: false`
- **THEN** a warning says no home channel is set on the server, and saving is still allowed

#### Scenario: Stored target not listed

- **WHEN** a job delivers to a platform the server no longer lists
- **THEN** that target stays selectable and is shown as unavailable

### Requirement: Leaving the form

The system SHALL ask before closing a form with changes that were not saved, and SHALL keep the form open, with its values, while a save is in progress or after it failed. It SHALL NOT allow a second save while one is in progress.

#### Scenario: Unsaved changes

- **WHEN** the user changed a field and closes the form
- **THEN** a confirmation asks whether to discard the changes

#### Scenario: Double tap on save

- **WHEN** the user taps Save twice quickly
- **THEN** one request is sent
