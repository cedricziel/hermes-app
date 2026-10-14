## MODIFIED Requirements

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

## ADDED Requirements

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
