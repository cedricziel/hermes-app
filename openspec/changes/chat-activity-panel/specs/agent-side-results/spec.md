# Spec Delta

## MODIFIED Requirements

### Requirement: Side results remain separate from the main answer

The app SHALL show background.complete and btw.complete using task_id and text, preserving optional question on a btw result. It SHALL identify the result type and expose answer details in the Activity panel without appending the result to the main assistant answer. A side completion SHALL NOT finish, restart, or fail the main turn. Side results SHALL NOT take space between the chat header and the transcript; several expanded results SHALL remain reachable by scrolling the Activity panel, leaving the conversation and composer usable.

#### Scenario: A side question completes during the main turn

- **WHEN** btw.complete arrives with answer text
- **THEN** a separate answer appears in the Activity panel and the main turn keeps streaming

#### Scenario: Expanded activity in a short chat window

- **WHEN** usage, a todo plan, and a side answer are expanded together in the Activity panel of a short window
- **THEN** details remain reachable by scrolling the panel without overflow and the chat and composer remain usable
