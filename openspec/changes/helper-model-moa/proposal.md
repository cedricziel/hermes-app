## Why

Hermes' mixture of agents (MoA) asks several advisor models and lets an aggregator model write the answer. Which models play those parts is set per profile in `config.yaml` or the web dashboard; the helper models screen from `helper-model-settings` does not show them yet.

## What Changes

- The helper models screen gains a "Mixture of agents" section below the task slots, read from `GET /api/model/moa?profile=`.
- It shows the default preset's slots, one row each: "Advisor 1", "Advisor 2", … for the reference models and "Aggregator", each with its model, provider, effort, and "off" for a disabled advisor. A preset other than `default` is named in the section header.
- Tapping a row opens the shared model picker (without "Same as main model", and without Hermes' virtual `moa` provider, which a preset may not contain). Closing it with a new pick saves the whole MoA config with `PUT /api/model/moa?profile=`, changing only that slot.
- While a MoA save runs, the MoA rows are disabled, so two saves cannot overwrite each other.
- When the MoA config cannot be read, the section is left out and the task slots still work.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `model-settings` (introduced by `helper-model-settings`): the helper models screen also shows and changes the MoA slots.

## Impact

- Code: `lib/src/models/` (MoA parsing and the repository calls), `lib/src/settings/helper_models_screen.dart` and `widgets/helper_model_list.dart`.
- Widgetbook: the list use cases gain the MoA section.
- API: `GET` and `PUT /api/model/moa` through the generated client (`MoaConfigPayload`). No change to `openapi/` or `packages/hermes_api`.
- Contract test: `test/real_backend_contract_test.dart` checks the MoA shape.

## Non-goals

- Adding or removing advisors, creating, renaming or switching presets, and editing temperatures, timeouts, fan-out or the privacy filter. They are sent back as the server reported them.
- Presets other than the default one.

## Security and privacy impact

None. The MoA config holds provider slugs and model ids, no keys, and nothing is stored on the device.

## Telemetry

None beyond the existing HTTP spans.
