## Purpose

Defines gateway-driven list refresh in the Hermes app so users can inspect backend-reported activity without changing the agent protocol.

## ADDED Requirements

### Requirement: Change signals invalidate the appropriate data

The app SHALL route sessions.changed to stored thread refresh, cron.changed to schedules, platforms.changed to messaging status, and pairing.changed to the active pairing status check. Because these signals carry no resource identity, it SHALL invalidate the relevant data under the existing connection and profile scope without interpreting an empty payload as a session event. Signals for disposed or superseded connections SHALL have no effect.

#### Scenario: A connection broadcasts cron.changed without a session ID

- **WHEN** Schedules is visible
- **THEN** the current schedules scope is refreshed through its existing repository

### Requirement: Refresh work is coalesced and respects visibility

The app SHALL coalesce signals received during an in-flight refresh into at most one follow-up refresh. Inactive destinations SHALL mark data dirty and refresh when next activated rather than continuously load. Existing foreground refresh and polling SHALL remain as recovery when no socket is open or signals are missed. Late responses from previous profiles or connections SHALL not overwrite current data.

#### Scenario: A burst arrives while a list is loading

- **WHEN** several change signals arrive
- **THEN** one follow-up refresh runs and the final data belongs to the active scope

### Requirement: Refresh does not overwrite user edits

The app SHALL refresh read models without clearing drafts, resetting filters, discarding selection, or overwriting pending local mutations. Pairing invalidation SHALL poll only an active known pairing through its existing status API. Refresh failure SHALL retain prior data and expose the existing failure state with retry. Change signals SHALL not produce operating-system notifications.

#### Scenario: External platform status changes while a setup form is edited

- **WHEN** platforms.changed arrives
- **THEN** the platform list refreshes and unsaved setup fields remain intact


Stored-thread refresh SHALL preserve selected, queued, local, in-flight, followed, and queue-busy thread objects, including protected enqueue, prepare, dispatch, restoration, and removal work. Absence from a page with `hasMore` SHALL NOT establish unavailability. Proven absence from a complete current-scope list SHALL retain protected prompts in their original conversation namespace and pause sending through the existing queue availability marker. It SHALL NOT delete ciphertext, retire watches, rebind conversation IDs, or drain a queue.

A fresh row in a verified list or an explicit successful lookup of the same conversation SHALL clear its matching unavailable marker and only the fixed missing-target queue error. Other protected-storage errors SHALL remain. Restoring availability SHALL NOT submit a prompt; recovered work still requires explicit review.


Protected queue dispatch SHALL recheck current availability after attachment reads, after persistence, and at the guarded request's final pre-byte boundary. A proven denial before any prompt frame is sent SHALL restore only that attempt's exact local claim to queued. Availability loss after bytes are sent SHALL NOT prove an unsent outcome or trigger automatic rollback. Known positive acceptance SHALL still insert and settle the reply under its unchanged confirmed owner, while other queued work stays paused.


A durable queue that becomes unavailable SHALL retain an explicit review barrier after positive availability proof, including when the foreground turn subsequently settles. Aborted protected preparation SHALL release its busy indicator in the bound chat UI. Neither a stale queue action nor metadata recovery SHALL replace the missing-target reason with a generic preparation error; genuine storage failures SHALL remain visible.

#### Scenario: A complete list omits a target while protected preparation is pending

- **WHEN** the omitted thread is no longer selected and its protected queue preparation or restoration has not finished
- **THEN** the same thread object and conversation identity remain retained and sending stays unavailable

#### Scenario: Positive list proof restores a retained queue target

- **WHEN** a fresh current-scope repository list contains the original conversation again
- **THEN** its review controls become available without submitting any queued prompt, while unlisted ciphertext remains retained

### Requirement: Existing backend contract and compatibility

The app SHALL use the existing dashboard `/api/ws` JSON-RPC contract for sessions.changed, cron.changed, platforms.changed, pairing.changed; existing session and REST list methods. The current pinned contract SHALL be Hermes Agent commit `71d34bad1045610252eda02ee79549436896e784`, recorded in `openrpc/HERMES_REF`. Commit `167e9fdb84248cd0fff80762dc57b6a914b6e930` SHALL remain the retained earlier fixture baseline; its change-signal schema matches; a minimum semantic release containing every required field is not established. Older backends SHALL keep ordinary chat usable when these optional events or methods are absent. Unsupported actions SHALL be unavailable, and malformed optional payloads SHALL not break the event stream. No backend route, protocol extension, or token-storage change SHALL be required.

Stored sessions SHALL refresh through the existing `HermesChatRepository` generated-client `GET /api/sessions` read. The existing `session.list` RPC contract remains unchanged; this capability adds no RPC list method. Existing REST reads are `GET /api/cron/jobs?profile=<scope>` returning a job array; `GET /api/messaging/platforms?profile=<profile>` returning `{platforms: [...]}` with required row identity `id` and `name`; and `GET /api/messaging/telegram/onboarding/{pairing_id}` returning pairing `status` plus optional `bot_username` and `owner_user_id`. These reads reuse the current repositories and generated client. No new route is introduced.

The event shapes are:

- `sessions.changed`: `ChangeSignalPayload`, no required payload fields.
- `cron.changed`: `ChangeSignalPayload`, no required payload fields.
- `platforms.changed`: `ChangeSignalPayload`, no required payload fields.
- `pairing.changed`: `ChangeSignalPayload`, no required payload fields.

#### Scenario: Optional capability is absent

- **WHEN** an older backend omits this capability or refuses an optional method as unsupported
- **THEN** ordinary chat remains usable and the app reports unavailable functionality without inventing state or submitting speculative requests
