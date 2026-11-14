# Spec Delta

## Purpose

Lets the owner of a self-hosted Hermes link a WhatsApp account to the messaging gateway from the app: the server starts its WhatsApp bridge, the app shows the QR code, and finishing saves the setup to the chat's profile.

## ADDED Requirements

### Requirement: Backend contract

The feature SHALL use only `POST /api/messaging/whatsapp/onboarding/start`, `GET` and `DELETE /api/messaging/whatsapp/onboarding/{pairing_id}` and `POST .../{pairing_id}/apply?profile=`, verified at Hermes `d923a5eb`, through the generated client, and SHALL read the untyped responses leniently.

#### Scenario: Unknown fields and statuses

- **WHEN** a response holds an unknown `status` or lacks an optional field
- **THEN** an unknown status is shown as "Working..." and a missing field is treated as unknown

#### Scenario: Old server

- **WHEN** start answers 404 or 405
- **THEN** the screen says "This server cannot link WhatsApp from the app" and nothing is retried

### Requirement: Entry and explicit start

The setup form of the WhatsApp platform SHALL show a "Link WhatsApp" button above the manual fields, and no other platform SHALL show it. Nothing SHALL be sent until the user presses Start.

#### Scenario: Opening does not start

- **WHEN** the user opens the pairing screen
- **THEN** only the mode and allowed-numbers fields and Start are shown, and no request has been sent

#### Scenario: Start carries the profile

- **WHEN** the user presses Start in a chat of profile `work`
- **THEN** the start body holds `mode`, `allowed_users` and `profile: work`

#### Scenario: Numbers are checked

- **WHEN** an allowed number holds letters
- **THEN** the screen asks for digits with an optional leading + separated by commas, and nothing is sent

### Requirement: Progress and polling

After start the screen SHALL poll the status every 2 seconds while it is on screen and the app is in front, and SHALL show the stage: Installing, Starting, Waiting for a scan, Linked. Polling SHALL stop on a final status and when the screen closes.

#### Scenario: Server installs packages

- **WHEN** the status is `installing`
- **THEN** the screen says the server is preparing WhatsApp and that this can take a few minutes, with Cancel

#### Scenario: App in background

- **WHEN** the app leaves the foreground
- **THEN** polling pauses, the QR is hidden and polling resumes on return

### Requirement: QR code

When `qr_payload` is present the screen SHALL render it as a QR code with the time left until `expires_at` and the steps "WhatsApp, Settings, Linked devices, Link a device". A new payload SHALL replace the old one at once. The payload SHALL be treated as a secret.

#### Scenario: Code rotates

- **WHEN** a poll returns a different `qr_payload`
- **THEN** the shown code changes to it without a reload

#### Scenario: No copy or log

- **WHEN** the code is shown
- **THEN** the screen offers no copy or share action, and the payload is in no log, span, breadcrumb, preference or clipboard

#### Scenario: Hidden on lock

- **WHEN** App Lock locks, or the lifecycle leaves `resumed`
- **THEN** the code is replaced by "Hidden" and returns when the app is unlocked and in front

### Requirement: Handset flow

On a handset the screen SHALL first say the QR must be scanned by the phone that has the WhatsApp account, so it must be opened on another device, and SHALL show the code only after the user taps "Show QR code". Tablets and computers SHALL show the code at once.

#### Scenario: Phone

- **WHEN** the screen shows a QR on a phone
- **THEN** the notice and "Show QR code" appear first, and the code appears only after the tap

#### Scenario: Mac

- **WHEN** the same status arrives on a Mac
- **THEN** the code is shown without a tap

### Requirement: Final states

The screen SHALL end polling and say so for `connected`, `error`, `expired` (also HTTP 410), `cancelled` and an unknown id (404), with Start again for all but `connected`. The server's `error` text SHALL be shown to the user only.

#### Scenario: Expired

- **WHEN** a poll answers 410 or the status is `expired`
- **THEN** the screen says the code expired and offers Start again, which asks for a new pairing

#### Scenario: Superseded

- **WHEN** the status is `cancelled` and the user did not cancel
- **THEN** the screen says another setup replaced this one

#### Scenario: Already linked

- **WHEN** start returns `connected` with no QR
- **THEN** the screen says "Already linked" with the account name and number the server gave, and no QR is shown

### Requirement: Finish asks first

Finish SHALL be offered only on `connected`. It SHALL ask "Save the WhatsApp setup and restart the messaging gateway? Conversations on messaging channels will be interrupted." with Cancel as the default and "Save and restart", and only then call apply with the chat's `profile` in the query and the body.

#### Scenario: Saved

- **WHEN** the user confirms and apply returns `ok`
- **THEN** the screens close to the refreshed platform list, and when `needs_restart` is true a notice says to restart the gateway from Server

#### Scenario: Refused

- **WHEN** apply answers 400, 404, 409 or 500 with a `detail`
- **THEN** the screen shows that text and stays, and apply is not repeated by itself

### Requirement: Lost answers

A start or apply whose answer is lost SHALL NOT read as done, and neither SHALL be resent automatically. After a lost start the user SHALL be able to Start again. After a lost apply the user SHALL be able to Check, which reads the platform list, and SHALL NOT be shown Finish again.

#### Scenario: Lost apply

- **WHEN** the connection drops while apply is in flight
- **THEN** the screen says "Could not confirm the setup was saved." with Check, and no second apply is sent

### Requirement: Leaving cancels

Leaving the screen before Finish SHALL send `DELETE` for a live pairing, best effort, once, and SHALL ignore its failure. A cancel does not unlink an account that already connected, and the screen SHALL NOT claim it does.

#### Scenario: Back while waiting

- **WHEN** the user leaves while the status is `waiting`
- **THEN** one `DELETE` is sent, and the QR and id are dropped from memory

### Requirement: Privacy

Breadcrumbs, logs and spans SHALL hold fixed names, counts and outcomes only. The QR payload, pairing id, account name and number, allowed numbers, the server's error text and the profile name SHALL appear in none of them.

#### Scenario: Request span

- **WHEN** a status poll is traced
- **THEN** the span's route is the template, with no pairing id
