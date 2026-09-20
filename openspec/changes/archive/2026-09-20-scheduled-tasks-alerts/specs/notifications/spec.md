## ADDED Requirements

### Requirement: Scheduled task runs

The system SHALL post a notification when a scheduled task has run since the app last saw it: one that succeeded ("Finished"), one that failed ("Failed"), and one that ran but whose delivery failed ("Result could not be delivered"). The title SHALL be the job's name, followed by its profile in brackets when it is not the sticky active profile. The body SHALL NOT include the job's prompt, its output or the server's error text. A job SHALL be judged to have run when its `last_run_at` is later than the one the app last saw for it; a job seen for the first time in this process SHALL set that baseline and post nothing, so that opening the app does not announce every past run. It SHALL replace an earlier notification for the same job. When more than five jobs have run since the last look, the system SHALL post one notification that says how many jobs ran and how many failed, in place of one each. The system SHALL NOT post for a muted job, while notifications are off, while the saved setting is loading, or while the scheduled task setting is off.

#### Scenario: Job succeeds

- **WHEN** the app is running and a job's `last_run_at` moves on with a last status of ok
- **THEN** a notification titled with the job's name and the body "Finished" is shown

#### Scenario: Job fails

- **WHEN** a job's last run failed with the error "Provider timeout"
- **THEN** the body is "Failed" and does not include the error text

#### Scenario: Delivery fails

- **WHEN** a job's last run succeeded and the server recorded a delivery error
- **THEN** the body is "Result could not be delivered"

#### Scenario: First look

- **WHEN** the app first loads jobs after starting
- **THEN** no notification is posted for runs that happened before

#### Scenario: Muted job

- **WHEN** a muted job runs
- **THEN** no notification is posted

#### Scenario: Many jobs at once

- **WHEN** seven jobs ran while the app was in the background and it returns to the foreground
- **THEN** one notification says that seven scheduled tasks ran and how many failed

#### Scenario: Job of another profile

- **WHEN** a job of profile `home` runs while `work` is the active profile
- **THEN** the title carries the name and "home"

### Requirement: Watching for runs

The system SHALL check the server's jobs for every profile with `GET /api/cron/jobs?profile=all` when the app comes to the foreground and every minute while it is in front, whatever destination is open, for as long as the cron routes answer, notifications are on and the scheduled task setting is on. It SHALL NOT check while the app is in the background. When the Schedules destination is in front and the app is in front, a run SHALL update the list instead of posting a notification.

#### Scenario: On another destination

- **WHEN** the user is in the chat and a job runs
- **THEN** the next check posts its notification

#### Scenario: Schedules in front

- **WHEN** the Schedules destination is selected and a job runs
- **THEN** the row updates and no notification is posted

#### Scenario: Background

- **WHEN** the app is in the background
- **THEN** no jobs request is made

### Requirement: Mute a scheduled task

The system SHALL let the user mute and unmute a job from its detail. The mute SHALL be kept on the phone, keyed by profile and job id, and SHALL survive restarts. A job that no longer exists SHALL have its mute forgotten the next time the list loads.

#### Scenario: Mute survives restart

- **WHEN** the user mutes a job and restarts the app
- **THEN** the job is still muted

#### Scenario: Deleted job

- **WHEN** a muted job is deleted on the server and the list loads
- **THEN** its mute is dropped

### Requirement: Scheduled task setting

The system SHALL offer a switch for scheduled task results among the notification settings, on by default, that applies only while the general notification setting is on. Turning it off SHALL stop the watching for runs, and turning it on again SHALL start from a new baseline so that runs from the time it was off are not announced.

#### Scenario: Off

- **WHEN** the user turns the switch off
- **THEN** no jobs are checked for notifications and none are posted

#### Scenario: Back on

- **WHEN** the user turns it on again after jobs ran meanwhile
- **THEN** those runs are not announced

### Requirement: Tapping a scheduled task notification

The system SHALL open the Schedules destination on the job's detail when the user taps its notification, including one that started the app. A tap for a job that no longer exists SHALL show the list with a message that the job is gone. The notification SHALL carry the job's profile with its id, and a job of another profile SHALL open under that profile.

#### Scenario: Tap while the app runs

- **WHEN** the user taps the notification of a job
- **THEN** Schedules is in front with that job's detail

#### Scenario: Job gone

- **WHEN** the tapped job was deleted
- **THEN** the list is shown with a message that the job no longer exists
