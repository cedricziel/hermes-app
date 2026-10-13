## Purpose

Defines advisor and aggregation progress in the Hermes app so users can inspect backend-reported activity without changing the agent protocol.

## Requirements

### Requirement: Advisor progress uses reported counts

The app SHALL show refs_done and refs_total from moa.progress and supported moa.phase fields, with a neutral phase label when counts are absent. moa.aggregating SHALL identify the reported aggregator. It SHALL not invent percentages, completed advisors, or failure counts when supplied counts are invalid. Main message completion SHALL end the live progress indicator.

#### Scenario: Aggregation starts after advisor progress

- **WHEN** moa.aggregating names the aggregator
- **THEN** the card shows aggregation without replacing the main answer

### Requirement: Advisor text remains reference material

moa.reference SHALL expose label and text in expandable details. When index is available, the app SHALL use it within the turn to update the advisor entry; when absent, it SHALL retain received entries using event identity without assuming labels are unique. Reference text SHALL NOT appear as the final assistant answer or be interpreted as an action.

#### Scenario: Two reference entries share a label without indices

- **WHEN** both distinct events arrive
- **THEN** both references remain available without overwriting one by label

### Requirement: Advisor state stays within its turn

The app SHALL scope progress and references to the current confirmed client, runtime, profile, and an actual foreground reply marker, deduplicate replayed event identities, and retain received references when the main answer completes. A later actual turn SHALL start a new progress card. Late progress after settlement and events between turns SHALL NOT create or reopen a card. Public reads SHALL hide cached state when current confirmed ownership is absent or differs, before subscription callbacks process the change. On truncated replay or cold start without references in durable history, details SHALL be unavailable rather than reconstructed from model configuration.

#### Scenario: The next turn uses the same advisor labels

- **WHEN** new reference events arrive
- **THEN** the previous turn details stay separate

### Requirement: Existing backend contract and compatibility

The app SHALL use the existing dashboard `/api/ws` JSON-RPC contract for moa.reference, moa.progress, moa.phase, moa.aggregating. The current pinned contract SHALL be Hermes Agent commit `71d34bad1045610252eda02ee79549436896e784`, recorded in `openrpc/HERMES_REF`. Commit `167e9fdb84248cd0fff80762dc57b6a914b6e930` SHALL remain the retained earlier fixture baseline; all four payload schemas match. A minimum semantic release containing every required field is not established. Older backends SHALL keep ordinary chat usable when these optional events or methods are absent. Unsupported actions SHALL be unavailable, and malformed optional payloads SHALL not break the event stream. No backend route, protocol extension, or token-storage change SHALL be required.

The event shapes are:

- `moa.reference`: `MoaReferencePayload`, required `label`, `text`; optional `index`, `count`.
- `moa.progress`: `MoaProgressPayload`, required `label`, `refs_done`, `refs_total`.
- `moa.phase`: `MoaPhasePayload`, required `phase`; optional `refs_done`, `refs_total`, `aggregator`.
- `moa.aggregating`: `MoaAggregatingPayload`, required `aggregator`.

#### Scenario: Optional capability is absent

- **WHEN** an older backend omits this capability or refuses an optional method as unsupported
- **THEN** ordinary chat remains usable and the app reports unavailable functionality without inventing state or submitting speculative requests


#### Scenario: A different capability observes ownership first

- **WHEN** another capability publishes a UI update after confirmed ownership changed
- **AND** the advisor subscription has not processed that change
- **THEN** public reads hide the old advisor references using the current binding proof

#### Scenario: Late progress follows main completion

- **WHEN** the main answer ends and a late advisor progress event arrives
- **THEN** it neither reopens the indicator nor creates an assistant turn

#### Scenario: A replay gap arrives after settlement

- **WHEN** the existing transport reports a replay gap while no reply is open
- **THEN** retained reference text is cleared and details are marked unavailable
- **AND** a late advisor event does not manufacture a new turn

#### Scenario: A socket is replaced

- **WHEN** the confirmed socket is lost
- **THEN** old advisor references are hidden
- **AND** existing chat recovery can show new progress with missing reference details marked unavailable
- **AND** advisor handling does not submit an extra prompt or resume request
