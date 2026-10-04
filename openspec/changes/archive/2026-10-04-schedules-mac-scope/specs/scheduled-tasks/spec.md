## MODIFIED Requirements

### Requirement: Profile scope and filters

The system SHALL start with the jobs of the sticky active profile and offer "All profiles", "Failing" and "Paused" as filters. With all profiles chosen, rows SHALL name their profile. The active profile SHALL be read from `GET /api/profiles/active`; when the server has no such route the list SHALL be unscoped, and when the request fails otherwise the list SHALL NOT load unscoped: it SHALL show the load error. Filters SHALL combine with the profile choice. The scope the user picks SHALL be kept across launches and used for the first list of the next launch; a scope widened by the app to show a job just saved in another profile SHALL NOT be kept.

#### Scenario: Default scope

- **WHEN** the active profile is `work` and the list opens
- **THEN** the request carries `profile=work` and only its jobs are shown

#### Scenario: All profiles

- **WHEN** the user chooses "All profiles"
- **THEN** the request carries `profile=all` and each row names its profile

#### Scenario: Scope kept across launches

- **WHEN** the user chose "All profiles" and the app is launched again
- **THEN** the first job request carries `profile=all`

#### Scenario: Failing filter

- **WHEN** the user chooses "Failing"
- **THEN** only jobs whose last run failed, or that are in the error state, are shown

#### Scenario: Active profile lookup fails

- **WHEN** reading the active profile fails with something other than 404
- **THEN** no job request is made unscoped and the list shows the load error

## ADDED Requirements

### Requirement: Mac window layout

On macOS the system SHALL show Schedules under the Mac toolbar, titled "Schedules" with the number of listed jobs under it, and holding a "This profile | All profiles" segmented control for the scope, Refresh, and New Schedule. The filter bar SHALL then offer only Failing and Paused. From 560 points of content width the list SHALL sit beside the selected job's detail, 340 points wide from 760 points of content and 250 below. Each job SHALL be a row of its own, the selected one marked, and a right click on a row SHALL offer its actions. The detail SHALL show the job's title and schedule with its next run, Edit and Run now, a failure card when the last run failed or could not be delivered, the job's settings and prompt, and its recent runs, each opening its chat; Pause or Resume, Mute Notifications and Delete SHALL be in a "…" menu. An empty list of the active profile SHALL say "No schedules in this profile". Other platforms SHALL keep their layout.

#### Scenario: Scope in the toolbar

- **WHEN** the user picks "All profiles" in the toolbar on macOS
- **THEN** every profile's jobs are listed, each with a profile chip, and the subtitle counts them

#### Scenario: Compact window

- **WHEN** the content is 680 points wide on macOS
- **THEN** a 250 point list sits beside the selected job's detail

#### Scenario: Failure card

- **WHEN** the selected job's last run failed
- **THEN** the detail shows a "Failed" card with the reason and when it ran, and a job whose last run succeeded shows none

#### Scenario: Other platforms

- **WHEN** Schedules is shown on iOS or Android
- **THEN** it keeps its app bar, profile chips and layout
