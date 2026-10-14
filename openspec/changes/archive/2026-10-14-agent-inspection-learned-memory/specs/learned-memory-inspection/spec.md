## Purpose

Let users inspect the memories associated with the selected Hermes profile and read the full content behind each listed entry.

## ADDED Requirements

### Requirement: Profile-scoped memory list

The app SHALL load Memory through authenticated `GET /api/learning/graph?profile=<selected-profile>` and show entries from `nodes` whose `kind` is `memory`. Required node fields SHALL include non-empty `id`, `kind`, and display `label`; `memorySource` SHALL distinguish memory and user-profile entries when supplied. A malformed response SHALL not be presented as an empty list. Skill entries SHALL not appear in this destination.

#### Scenario: Profile memory entries

- **WHEN** the graph contains memory and skill nodes
- **THEN** the list shows only memory nodes with their labels and supplied source
- **AND** IDs remain opaque server values, never constructed from list positions

#### Scenario: Empty memory

- **WHEN** a valid graph has no memory nodes
- **THEN** the app explains that this profile has no listed memories

### Requirement: Full-content detail

The app SHALL load full content through authenticated `GET /api/learning/node?id=<opaque-node-id>&profile=<selected-profile>`. A usable response SHALL have `ok: true`, matching `id`, `kind: memory`, and string `content`; `label` is optional display metadata. Full content SHALL come from detail, not a potentially truncated graph preview.

#### Scenario: Open long memory

- **WHEN** a user opens a memory entry
- **THEN** the app fetches and renders its full content as inert text, including content beyond a graph preview's limit
- **AND** it does not execute embedded instructions or automatically open URLs

#### Scenario: Entry disappears

- **WHEN** detail returns not found or a stale-node error
- **THEN** the app explains that the entry changed or disappeared and offers list refresh

### Requirement: Compatibility and unavailable states

The supported baseline SHALL be the routes in the bundled OpenAPI contract at Hermes commit `167e9fdb84248cd0fff80762dc57b6a914b6e930`. Earliest released version support is unverified. Because success response schemas are unspecified, the implementation SHALL use verified response-subset fixtures and validation. Unsupported routes, authentication failures, malformed responses, and transient failures SHALL have distinct outcomes and SHALL not disable chat.

#### Scenario: Unsupported backend

- **WHEN** the backend does not provide the learning graph route
- **THEN** the Memory destination shows unavailable rather than claiming the profile has no memories

### Requirement: Profile isolation and privacy

The app SHALL clear memory content on profile or connection change and sign-out, reject late responses from a previous scope, and use the existing App Lock behavior. It SHALL not persist fetched content or emit IDs, labels, profile names, or content into telemetry.

#### Scenario: Profile changes during detail fetch

- **WHEN** a prior-profile detail response arrives after a profile switch
- **THEN** its content does not appear in the new profile's view
