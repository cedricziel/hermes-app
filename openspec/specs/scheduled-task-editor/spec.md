# scheduled-task-editor Specification

## Purpose
Describes how the app creates and changes scheduled tasks: the gallery of blueprints, the blueprint form, the form for a custom task and for editing, how "when" is chosen and written, how delivery targets are offered, and which backend routes it relies on.

## Requirements

### Requirement: New task gallery

The system SHALL offer a "New" action on the Schedules list that opens a gallery with a "Custom task" card and the blueprints of the profile new jobs go to, from `GET /api/cron/blueprints?profile=<profile>`. Each blueprint card SHALL show its title, description and its schedule in words (`scheduleHuman`). The gallery SHALL have a search field matching titles, descriptions and tags, and one chip per category the blueprints carry. A blueprint the app cannot render SHALL be skipped. When the blueprints cannot be loaded, the gallery SHALL still offer "Custom task" and say the templates are unavailable.

#### Scenario: Gallery opens

- **WHEN** the user taps "New" and the server lists blueprints
- **THEN** a "Custom task" card and a card for each blueprint are shown

#### Scenario: Blueprints of the profile

- **WHEN** new jobs go to the profile "work"
- **THEN** the blueprints are requested with `profile=work`, so the blueprints of that profile's plugins are offered

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

The system SHALL let the user create a job from "Custom task" with `POST /api/cron/jobs?profile=<profile>`, and change one from its detail with `PUT /api/cron/jobs/{id}?profile=<profile>`. The form SHALL have a name, a prompt, "when", "deliver to", a profile (creating only), "start paused" (creating only), and an Advanced section with skills, model, a pre-run script, jobs to take context from, and a working directory. Skills and context-from entries are typed as names separated by commas or lines. On edit, the request SHALL carry only the fields the user changed, and SHALL leave every other field of the job as the server has it. A job SHALL NOT be saved without a schedule, nor without a prompt, a skill or a script. Empty optional text SHALL be sent as absent on create and as cleared on edit.

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

- **WHEN** the user empties the working directory of a job that had one
- **THEN** the update request clears the working directory

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

The system SHALL offer the targets of the job's profile from `GET /api/cron/delivery-targets?profile=<profile>` for "deliver to", and load them again when the user picks another profile for a new job, keeping only the answer for the profile picked last. It SHALL put the implicit local target first, and SHALL warn under a target whose `home_target_set` is false that no home channel is set on the server. A job whose stored target is not in the list SHALL keep it as an extra choice. When the list cannot be loaded the field SHALL offer local only, and an edited job SHALL keep its stored target.

#### Scenario: No home channel

- **WHEN** the user picks a platform listed with `home_target_set: false`
- **THEN** a warning says no home channel is set on the server, and saving is still allowed

#### Scenario: Stored target not listed

- **WHEN** a job delivers to a platform the server no longer lists
- **THEN** that target stays selectable and is shown as unavailable

#### Scenario: Targets of the profile picked

- **WHEN** the user creating a job switches its profile from "work" to "home"
- **THEN** the targets are requested again with `profile=home` and those of "home" are offered

### Requirement: Leaving the form

The system SHALL ask before closing a form with changes that were not saved, and SHALL keep the form open, with its values, while a save is in progress or after it failed. It SHALL NOT allow a second save while one is in progress.

#### Scenario: Unsaved changes

- **WHEN** the user changed a field and closes the form
- **THEN** a confirmation asks whether to discard the changes

#### Scenario: Double tap on save

- **WHEN** the user taps Save twice quickly
- **THEN** one request is sent

### Requirement: Job model

The system SHALL let the user choose a job's model from the models of the job's profile, loaded with `GET /api/model/options?profile=<profile>` (the same answer and lenient parsing as the chat's model list), grouped by provider, with a "Use the profile's default" entry first and no reasoning-effort choice. Picking a model SHALL set the job's `model` to its id and `provider` to its provider slug; the default entry SHALL leave both empty, which on create sends neither and on edit sends both as empty strings, which Hermes stores as cleared. The field SHALL show the job's model and provider, or that the profile's default is used. A saved model that the list does not offer, including one saved without a provider, SHALL stay shown, be marked as not in the server's list, and SHALL NOT be changed or cleared unless the user picks another entry. When the list cannot be loaded, the field SHALL still show the saved value and the picker SHALL offer only the default entry. The model list for a new job SHALL follow the profile chosen in the form. The minimum Hermes version is 0.21.4.

#### Scenario: Pick a model on create

- **WHEN** the user picks `claude-opus-4` from the provider `anthropic` and saves a new job
- **THEN** the create request carries `model: claude-opus-4` and `provider: anthropic`

#### Scenario: Profile default

- **WHEN** the user creates a job without choosing a model
- **THEN** the create request carries neither a model nor a provider

#### Scenario: Back to the default on edit

- **WHEN** the user picks "Use the profile's default" for a job that had a model and saves
- **THEN** the update request carries `model` and `provider` as empty strings

#### Scenario: Model not in the list

- **WHEN** a job's saved model is not offered by the server and the user changes only its name
- **THEN** the field shows the saved model as not in the server's list, and the update request carries the name and no model or provider

#### Scenario: No effort for jobs

- **WHEN** the user opens the picker from the job form and picks a model that reasons
- **THEN** no reasoning-effort choice is shown

#### Scenario: List unavailable

- **WHEN** `GET /api/model/options` fails
- **THEN** the field still shows the saved model, and the picker offers only "Use the profile's default"

### Requirement: Scheduled-job forms respect session activity

The custom and edit scheduled-job forms SHALL retain entered values while verified session activity is suspended. While suspended, the app SHALL NOT start reads for delivery targets or model options, or start a job save. A metadata read already in flight when activity is suspended SHALL NOT update the form. When the same verified session becomes active again, the app MAY reload metadata but SHALL NOT submit a save automatically.

A save already sent before activity was suspended cannot be recalled. If its result arrives after the activity epoch has changed, the app SHALL keep the form open with its entered values and SHALL NOT treat that result as a saved job for navigation. The existing backend routes remain `GET /api/cron/delivery-targets?profile=<profile>`, `GET /api/model/options?profile=<profile>`, `POST /api/cron/jobs?profile=<profile>`, and `PUT /api/cron/jobs/{id}?profile=<profile>`; no response or minimum Hermes version change is required.

#### Scenario: Metadata requests wait for active session
- **WHEN** the job form is opened while verified session activity is suspended
- **THEN** it retains its values and starts no delivery-target or model-option request
- **WHEN** the same verified session becomes active
- **THEN** the form may load delivery targets and model options

#### Scenario: Stale metadata reply is discarded
- **WHEN** a delivery-target or model-option request is in flight as session activity is suspended
- **THEN** its reply does not update the form
- **WHEN** the same verified session becomes active again
- **THEN** the form may issue a fresh metadata read

#### Scenario: Save is not replayed after recovery
- **WHEN** a save is attempted while activity is suspended
- **THEN** no job-save request is sent
- **WHEN** a save sent during active activity returns after that activity epoch ended
- **THEN** the form stays open with its values and does not navigate as though the job were saved
- **THEN** recovery does not send another save without a new user action
