# Spec Delta

## MODIFIED Requirements

### Requirement: Resume restores available plan state

The app SHALL seed the current plan from session.resume.todo_state and then apply later revisions from the same runtime. A new runtime generation SHALL reset revision comparison. Missing todo_state on a newly adopted binding SHALL mean unavailable rather than prove that no plan exists. An unavailable plan SHALL draw nothing: the app SHALL NOT show an "unavailable" plan row, and SHALL NOT present it as an empty plan. A missing or older resume snapshot SHALL preserve a newer live plan already accepted on the same confirmed connection, runtime, and profile binding. A truncated replay SHALL use the existing resume state refresh instead of reconstructing tasks from tool prose.

#### Scenario: The runtime restarts with a lower revision

- **WHEN** resume supplies the new generation snapshot
- **THEN** the restored plan is accepted and comparison restarts for that generation

#### Scenario: A same-binding resume omits plan state

- **WHEN** a live revision 6 has already been accepted and a resume on that same confirmed binding omits todo_state
- **THEN** revision 6 remains visible

#### Scenario: A chat never received plan state

- **WHEN** a chat is attached, resume omits todo_state and no todo.updated has arrived
- **THEN** no plan row is drawn
- **AND** a later todo.updated with tasks shows the plan
