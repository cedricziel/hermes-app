# Spec Delta

## MODIFIED Requirements

### Requirement: Watching for runs

The system SHALL check the server's jobs for every profile with `GET /api/cron/jobs?profile=all` when the app comes to the foreground and every minute while it is in front, whatever destination is open, for as long as the cron routes answer, notifications are on and the scheduled task setting is on. While the app is in the background it SHALL NOT poll; on iOS and Android it SHALL make the same check, under the same conditions, during the background runs the system grants (see the background-refresh and background-refresh-alerts specs). The last run time seen for each job SHALL be kept on the device and shared by the foreground and background checks, so a run is announced at most once; the first check on a device, or after the scheduled task setting is turned on, SHALL only record the run times. When the Schedules destination is in front and the app is in front, a run SHALL update the list instead of posting a notification.

#### Scenario: On another destination

- **WHEN** the user is in the chat and a job runs
- **THEN** the next check posts its notification

#### Scenario: Schedules in front

- **WHEN** the Schedules destination is selected and a job runs
- **THEN** the row updates and no notification is posted

#### Scenario: Background

- **WHEN** the app is in the background and the system grants no background run
- **THEN** no jobs request is made

#### Scenario: Background run

- **WHEN** a job fails while the app is in the background and the system grants a background run
- **THEN** the run posts the job's "Failed" notification

#### Scenario: Announced once

- **WHEN** a background run announced a job's run and the user then opens the app
- **THEN** the check in front does not announce that run again
