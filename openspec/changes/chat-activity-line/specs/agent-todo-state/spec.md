# Spec Delta

## MODIFIED Requirements

### Requirement: Todo snapshots replace the current plan

The app SHALL keep one read-only todo snapshot per owning server, profile, and session. todo.updated SHALL replace the snapshot when revision is newer, ignore older or repeated revisions within the same runtime generation, and clear the plan when todos is empty. The app SHALL show the plan's completed and total count as a counter of the activity line while a task is open, and the supported task entries in the Activity panel's Plan section. It SHALL NOT merge old tasks into a replacement.

#### Scenario: A stale todo update is replayed

- **WHEN** revision 5 follows an already accepted revision 6
- **THEN** revision 6 remains visible without duplicate tasks

#### Scenario: Every task is completed

- **WHEN** a snapshot reports all tasks completed
- **THEN** the activity line drops the plan counter and the Activity panel still lists the completed plan
