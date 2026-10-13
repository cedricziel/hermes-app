## ADDED Requirements

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
