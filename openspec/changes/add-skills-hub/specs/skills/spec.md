## ADDED Requirements

### Requirement: Discover tab

The system SHALL offer a Discover tab on the Skills page that shows featured and official skills when the search is empty and hub search results otherwise, for the selected profile.

#### Scenario: Opening Discover

- **WHEN** the user opens the Discover tab
- **THEN** a progress indicator shows while loading, then the featured skills and the official catalog appear, each card showing the name, a one-line description, its tags, a trust badge and either an action to view it or "Installed"

#### Scenario: Searching the hub

- **WHEN** the user types a search and pauses
- **THEN** the hub is searched once for that text and the results replace the featured list, with the source chips narrowing them to one source

#### Scenario: A source times out

- **WHEN** the server reports sources that timed out
- **THEN** the results still show and a note says a source timed out, with a Retry

#### Scenario: Searching fails

- **WHEN** the search or the catalog cannot be loaded
- **THEN** the tab shows "Could not load the hub" with a Retry button

#### Scenario: Already installed

- **WHEN** a result is already installed for the selected profile
- **THEN** its card shows "Installed" and opens the installed skill's detail instead of the hub page

#### Scenario: Older server

- **WHEN** the server answers 404 for the hub routes
- **THEN** the tab says the connected Hermes does not support the skills hub

### Requirement: Hub skill preview

The system SHALL show a hub skill's description, files and `SKILL.md` before it can be installed, together with the result of the server's security scan.

#### Scenario: Opening a hub skill

- **WHEN** the user opens a hub skill
- **THEN** the page shows its name, source, trust level, file list and rendered `SKILL.md`, and runs the security scan for that skill

#### Scenario: Scan result

- **WHEN** the scan finishes
- **THEN** the page shows the verdict, the summary, the count per severity and each finding with its severity, message, and file and line

#### Scenario: Scan cannot be run

- **WHEN** the scan fails or times out
- **THEN** the page says so, offers Retry, and does not offer Install

### Requirement: Install policy

The system SHALL follow the policy the server returns with the scan and SHALL NOT let the user install past a block.

#### Scenario: Allowed

- **WHEN** the policy is `allow`
- **THEN** Install is offered and one tap starts the installation

#### Scenario: Needs confirmation

- **WHEN** the policy is `ask`
- **THEN** Install reads "Install anyway…" and opens a confirmation that lists the findings; the installation starts only when the user confirms

#### Scenario: Blocked

- **WHEN** the policy is `block`
- **THEN** Install is disabled and the page shows the reason the server gave

#### Scenario: Policy is unknown

- **WHEN** the policy is missing or not one of the three
- **THEN** it is treated as `block`

### Requirement: Background jobs

The system SHALL treat install, uninstall and update as jobs that run on the server, show their progress, and refresh the installed list when they end.

#### Scenario: Job progress

- **WHEN** a job has been started
- **THEN** a sheet shows a progress indicator and the last lines of the job's log, refreshed until the job stops

#### Scenario: Job succeeds

- **WHEN** the job ends with exit code 0
- **THEN** the sheet says it is done, the Installed list reloads, and the hub cards for that skill show "Installed"

#### Scenario: Job fails

- **WHEN** the job ends with another exit code
- **THEN** the sheet says it failed and shows the log tail, and the Installed list reloads anyway

#### Scenario: Running in the background

- **WHEN** the user closes the sheet while the job runs
- **THEN** the job continues, the page shows a small "Installing…" indicator, and the result is reported when it ends

#### Scenario: One job at a time

- **WHEN** a job is running
- **THEN** starting another install, uninstall or update is disabled until it ends

#### Scenario: Progress cannot be read

- **WHEN** the job's status cannot be read repeatedly
- **THEN** the sheet says the state is unknown and offers to refresh the Installed list, and it does not claim success

### Requirement: Uninstalling a hub skill

The system SHALL let the user uninstall a skill that came from the hub, and SHALL NOT offer it for bundled or agent-authored skills.

#### Scenario: Uninstalling

- **WHEN** the user taps Uninstall on a hub skill's detail page and confirms
- **THEN** an uninstall job is started for the selected profile and follows the same progress and result rules as an install

#### Scenario: Not a hub skill

- **WHEN** the skill is bundled or agent-authored
- **THEN** Uninstall is not offered

### Requirement: Updating hub skills

The system SHALL let the user update the installed hub skills of the selected profile in one step.

#### Scenario: Updating

- **WHEN** the user taps "Check for updates" on the Installed tab and there are hub skills
- **THEN** an update job is started for the selected profile and follows the same progress and result rules as an install

#### Scenario: No hub skills

- **WHEN** the profile has no hub skills
- **THEN** the update action is not shown

### Requirement: Hub backend contract

The system SHALL use the dashboard's hub routes and SHALL tolerate response shapes it does not recognise.

#### Scenario: Routes used

- **WHEN** the app discovers, previews, installs or updates skills
- **THEN** it uses `GET /api/skills/hub/official` (envelope `skills`, per row `name`, `description`, `identifier`, `trust_level`, `tags`, `category`, `installed`), `GET /api/skills/hub/sources` (`sources`, `featured`, `installed`), `GET /api/skills/hub/search` (query `q`, `source`, `limit`, `profile`; envelope `results`, `source_counts`, `timed_out`, `installed`), `GET /api/skills/hub/preview` (query `identifier`; reply `skill_md`, `files`), `GET /api/skills/hub/scan` (query `identifier`; reply `verdict`, `summary`, `policy`, `policy_reason`, `findings`, `severity_counts`), `POST /api/skills/hub/install`, `POST /api/skills/hub/uninstall` and `POST /api/skills/hub/update` (each replying `name`, the job name), and `GET /api/actions/{name}/status` (reply `running`, `exit_code`, `lines`), with the selected profile passed on every call

#### Scenario: Rows that do not fit

- **WHEN** a result or finding is missing its name or identifier
- **THEN** it is left out

#### Scenario: Unknown job

- **WHEN** the job status route answers 404
- **THEN** the job is treated as finished with an unknown outcome and the Installed list is reloaded
