## MODIFIED Requirements

### Requirement: Background jobs

The system SHALL treat install, uninstall and update as jobs that run on the server, show their progress, and refresh the installed list when they end. On macOS the status view SHALL use a centered desktop dialog at every window width, with the shared restrained motion and reduced-motion policy. Other platforms SHALL retain their existing bottom-sheet presentation. The view SHALL remain readable and dismissible in small windows and at increased text scale.

The existing install/uninstall/update routes and action-status polling contract SHALL remain unchanged. Job status continues to use the server’s running, exit_code, pid, and lines fields; this presentation change SHALL require no minimum Hermes Agent version change.

#### Scenario: Job progress

- **WHEN** a job has been started
- **THEN** the status view shows a progress indicator and the last lines of the job's log, refreshed until the job stops

#### Scenario: Job succeeds

- **WHEN** the job ends with exit code 0
- **THEN** the status view says it is done, the Installed list reloads, and the hub cards for that skill show "Installed"

#### Scenario: Job fails

- **WHEN** the job ends with another exit code
- **THEN** the status view says it failed and shows the log tail, and the Installed list reloads anyway

#### Scenario: Running in the background

- **WHEN** the user closes the status view while the job runs
- **THEN** the job continues, the page shows a small "Installing…" indicator, and the result is reported when it ends

#### Scenario: One job at a time

- **WHEN** a job is running
- **THEN** starting another install, uninstall or update is disabled until it ends

#### Scenario: Progress cannot be read

- **WHEN** the job's status cannot be read repeatedly
- **THEN** the status view says the state is unknown and offers to refresh the Installed list, and it does not claim success

#### Scenario: Compact macOS job status

- **WHEN** a Skills job status view opens in a compact Mac window
- **THEN** it uses a centered desktop dialog and its log content can scroll without hiding the dismissal control

#### Scenario: Retained mobile presentation

- **WHEN** a Skills job status view opens on another platform
- **THEN** its existing bottom-sheet presentation and background execution behavior remain intact

