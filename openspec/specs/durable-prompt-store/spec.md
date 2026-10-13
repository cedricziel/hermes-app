# Durable prompt store Specification

## Purpose

Protect locally unsent prompts and their attachments through app interruption, without changing backend queue ownership or submitting work.

## Requirements

### Requirement: Durable queue records

The app SHALL retain local queued records in FIFO order under the exact server, account, profile, and conversation identity. Each record SHALL retain a stable local identity, submission state, submitted text, optional display text, and attachment metadata. A committed record SHALL survive restart and profile switch. No record SHALL become visible under a different identity. The store SHALL NOT submit prompts or depend on a backend route.

#### Scenario: Restart and profile isolation

- **WHEN** committed records exist for the same session ID in two profiles and the app restarts
- **THEN** each profile reads only its own records, in their original order

#### Scenario: Different server or account

- **WHEN** the app opens another server or signs in as another account
- **THEN** records from the former identity are not returned

### Requirement: Protected payload and retained attachments

Prompt text, display text, attachment names, and attachment bytes SHALL be encrypted with integrity protection in app-private storage. The encryption key SHALL remain in OS secure storage. Queue payloads SHALL NOT enter preferences, shared snapshots, search indexes, backups, or telemetry. Committing an attachment SHALL retain an app-owned copy so removal of the original file does not damage recovery. The store SHALL retain existing attachment-size limits and reject incomplete commits without removing the preceding valid state.

#### Scenario: Temporary file disappears

- **WHEN** an attachment is committed and the original temporary file is removed
- **THEN** the recovered record still reads the original attachment bytes

#### Scenario: Copy or durable write fails

- **WHEN** an attachment copy or final commit fails
- **THEN** the operation reports failure and previously committed records remain readable

### Requirement: Crash-safe submission state

The store SHALL durably distinguish unsent records from records whose submission started. Submission-started records SHALL remain uncertain after interruption until an explicit acceptance result, user discard, or proven failure before network submission resolves them. Only the dispatcher holding the exact local claim SHALL restore a claimed record to unsent after that proven failure. An uncertain record without a claim SHALL NOT reset to unsent. A successfully accepted record SHALL no longer be eligible for automatic submission, including when its backend status is queued. Completing acceptance SHALL remove its stored payload and unused attachments. State writes SHALL be atomic and serialized for the same identity.

#### Scenario: Interrupted submission

- **WHEN** submission-started state is committed and the process stops before an acceptance result is saved
- **THEN** recovery returns an uncertain record rather than an unsent record

#### Scenario: Dispatch claim isolation

- **WHEN** a record already carries an uncertain submission claim
- **THEN** a second dispatcher cannot acquire that record
- **AND** a failure reported by a different or missing claim does not reset it to unsent

#### Scenario: Accepted prompt

- **WHEN** acceptance is committed and the app restarts
- **THEN** the accepted record is not returned as work eligible to send

### Requirement: Unavailable storage and deletion

Locked or temporarily unavailable secure storage SHALL report unavailable without deleting records or signing the user out. Corrupt records SHALL be isolated and reported without losing other valid records. Sign-out, explicit server removal, and conversation deletion SHALL delete corresponding payloads and attachment copies. Profile switching SHALL retain records. Failed deletion SHALL prevent those records from becoming visible to a later account and SHALL retry cleanup when storage becomes available.

#### Scenario: Key unavailable

- **WHEN** the device cannot read the queue key
- **THEN** no queue payload is exposed and durable records remain untouched

#### Scenario: Corrupt record beside valid records

- **WHEN** one record fails integrity verification
- **THEN** that record is excluded with a corruption outcome and other valid records remain recoverable

#### Scenario: Sign-out cleanup

- **WHEN** the user signs out
- **THEN** records for that account are deleted or made inaccessible pending cleanup

### Requirement: Backend independence

The store SHALL require no new Hermes route, RPC field, or minimum Hermes version beyond the app's existing supported backend. It SHALL NOT represent a backend-accepted prompt as an unsent local prompt.

#### Scenario: Existing backend

- **WHEN** the app uses its current supported backend without queue-specific capabilities
- **THEN** local queue storage works without a queue API request
