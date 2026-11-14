# Spec Delta

## ADDED Requirements

### Requirement: Context and file checkpoints are reference activity

The Activity panel SHALL list the Context row and the File checkpoints row under "For reference" (This session). A compression or a restore in flight SHALL be listed under Now as working for its duration and SHALL settle into a reference note. Neither feature SHALL produce a Needs-you item, an Activity button marker, a strip line or a notification. Both SHALL draw nothing where their controllers are not provided (conversation windows, the quick panel) and where the server lacks the feature.

#### Scenario: Compressing

- **WHEN** a compression is in flight
- **THEN** Now lists "Compressing the conversation…" and the Activity button shows no marker

#### Scenario: Restore finishes

- **WHEN** a restore finishes
- **THEN** Now drops its line and This session shows "Restored N files" as a note

#### Scenario: Nearly full context

- **WHEN** the context is 97% full
- **THEN** the Needs-you tier and the Activity button are unchanged
