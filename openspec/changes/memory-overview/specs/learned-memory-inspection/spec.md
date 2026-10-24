## MODIFIED Requirements

### Requirement: Profile-scoped memory list

The app SHALL load Memory through authenticated `GET /api/learning/graph?profile=<selected-profile>` and show entries from `nodes` whose `kind` is `memory`, grouped by the memory file they belong to as the memory-overview spec describes. Required node fields SHALL include non-empty `id`, `kind`, and display `label`; `memorySource` SHALL distinguish memory and user-profile entries when supplied. A malformed response SHALL not be presented as an empty list. Skill entries SHALL not appear in this destination.

#### Scenario: Profile memory entries

- **WHEN** the graph contains memory and skill nodes
- **THEN** the screen shows only memory nodes, each under the tab of its supplied source
- **AND** IDs remain opaque server values, never constructed from list positions

#### Scenario: Empty memory

- **WHEN** a valid graph has no memory nodes
- **THEN** each tab says "Nothing remembered yet" and that the user can tell Hermes in a chat to remember something
