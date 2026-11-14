# Spec Delta

## Purpose

Lets a person see Hermes' skill curator from the Skills screen, pause and resume its scheduled passes, and start a pass knowingly.

## ADDED Requirements

### Requirement: Backend contract

The feature SHALL use only `GET /api/curator?profile=`, `PUT /api/curator/paused?profile=` (body `{"paused": bool}`), `POST /api/curator/run?profile=` and `GET /api/actions/curator-run/status?lines=`, verified at Hermes `d923a5eb`, through the generated client, and parse responses leniently. It SHALL hide the section only when a 404 or 405 says the route is missing (detail `No such API endpoint` or an `error` body), never for a 404 whose detail starts `Profile '`.

#### Scenario: Old server

- **WHEN** `GET /api/curator` answers 404
- **THEN** the Skills screen shows no curator section and no error

#### Scenario: Missing profile

- **WHEN** a request answers 404 with detail `Profile 'x' does not exist.`
- **THEN** the section says the profile no longer exists and is not hidden as an old server

#### Scenario: Curator unavailable or invalid

- **WHEN** GET or PUT answers 500 `Curator unavailable: ...` or 400
- **THEN** the section shows an error with Try again and changes no switch

#### Scenario: Odd response

- **WHEN** a field is missing or has an unexpected type
- **THEN** it is shown as unknown and the rest is used

### Requirement: Explicit profile

Every curator request SHALL carry the profile the Skills screen shows. The app SHALL never send an unnamed run, because Hermes refuses it with 400 while one backend serves several profiles.

#### Scenario: Switching profile

- **WHEN** the user changes the profile on the Skills screen
- **THEN** status is read again for that profile, and a run or pause in progress for the old one is not shown against the new one

#### Scenario: Profile deleted before a run

- **WHEN** the POST answers 500 whose detail contains `404: Profile '`
- **THEN** the app says the profile no longer exists and that nothing started, not a spawn failure

#### Scenario: Refused as unnamed

- **WHEN** Hermes answers 400 that the run "requires an explicit profile"
- **THEN** the app shows that nothing started and offers Try again

### Requirement: Status

The section SHALL show whether the curator is on (`enabled`), paused (`paused`), when it last ran (`last_run_at`, relative with the exact time on tap), the interval (`interval_hours`) and the stale and archive thresholds (`stale_after_days`, `archive_after_days`), and SHALL show "Hasn't run yet" when `last_run_at` is null. It SHALL NOT invent a summary, a count or a report: the route returns none.

#### Scenario: Never run

- **WHEN** `last_run_at` is null
- **THEN** the section says it has not run and that the first scheduled pass waits one interval

#### Scenario: Off in config

- **WHEN** `enabled` is false
- **THEN** the section says it is off in the server's config, shows no Pause switch and no Run now

### Requirement: Pause and resume

The Pause switch SHALL send `PUT /api/curator/paused` with the new value and show the value Hermes answers (`paused`). It needs no confirmation. The section SHALL say that pausing stops scheduled passes only and that Run now still works.

#### Scenario: Pause

- **WHEN** the user turns the switch on and Hermes answers `{"ok": true, "paused": true}`
- **THEN** the section shows Paused

#### Scenario: Lost answer

- **WHEN** the request times out or the connection drops
- **THEN** the switch returns to its last known value, the section says it could not tell whether it changed, status is read again, and nothing is resent automatically

### Requirement: Run needs a confirmation

Run now SHALL open a confirmation whose default button is Cancel. It SHALL say that a pass may archive unused skills recorded as agent-made, may also include bundled skills when `curator.prune_builtins` is on, may merge and rewrite skills when `curator.consolidate` is on, skips pinned and hub-installed skills, keeps archived skills, and that the app cannot undo a pass.

#### Scenario: Cancel is the default

- **WHEN** the confirmation opens
- **THEN** Cancel has the default focus and Return or the system back action cancels, and no request is sent

#### Scenario: Consolidation unknown

- **WHEN** the config value `curator.consolidate` is false, true or cannot be read
- **THEN** the text says "archives unused skills only", "may also merge and rewrite skills", or the second, respectively; an unreadable `curator.prune_builtins` adds "may include bundled skills"

#### Scenario: Undo is not offered

- **WHEN** the confirmation is shown
- **THEN** it says to restore an archived skill with `hermes curator restore <name>` on the server and offers Copy for the command, and the app has no undo control

### Requirement: Following a run

After the user confirms, the app SHALL send `POST /api/curator/run?profile=`, then poll `GET /api/actions/curator-run/status?lines=2000` until `running` is false, and show the lines after the latest start header. It SHALL treat exit code 0 as finished, a non-zero code as failed (showing Hermes' last line), and a null code as unknown.

#### Scenario: Finished

- **WHEN** the status says `running: false, exit_code: 0`
- **THEN** the app shows Hermes' output lines and reads the status again for the new last run time

#### Scenario: Failed

- **WHEN** the exit code is 1 (for example "curator: disabled via config")
- **THEN** the app shows Failed with that line and starts nothing again

#### Scenario: Spawn failure

- **WHEN** the POST answers 500 "Failed to run curator: …"
- **THEN** the app shows that nothing started, with Hermes' text, and a Try again that needs a new confirmation

### Requirement: One run at a time, no resend

While a run is shown as running, Run now SHALL be disabled, because Hermes does not guard against a second concurrent run. A lost answer to the POST SHALL read "We couldn't tell if it started" with a Check status action and SHALL never be resent automatically.

#### Scenario: Lost answer

- **WHEN** the POST times out
- **THEN** no new POST is sent; Check status reads `last_run_at` and the action status, and a new run needs a new confirmation

### Requirement: Shared action log

The action log is per server, not per profile, so the app SHALL show output only for a run this app started and SHALL say when the lines may belong to another profile's run.

#### Scenario: Opening the screen

- **WHEN** the section opens and this app started no run
- **THEN** it shows the last run time only, not the log lines

### Requirement: Privacy and observability

Skill names and output lines SHALL stay on screen only: never written to logs, spans, breadcrumbs, preferences, the surface snapshot or the clipboard (except the restore command the user copies), and blanked under App Lock. Telemetry SHALL carry only the names, flags and counts in the proposal.

#### Scenario: Telemetry content

- **WHEN** a run finishes
- **THEN** the span and log event hold the outcome and counts and no skill name, line or profile

### Requirement: Strings

Every user-visible string SHALL be in the ARB files (`app_en.arb`, `app_de.arb`) under the skills area, and read with `context.l10n`.

#### Scenario: German

- **WHEN** the app language is German
- **THEN** the section, the confirmation and the results read in German
