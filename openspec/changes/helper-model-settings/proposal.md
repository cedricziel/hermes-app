## Why

Hermes runs side jobs (vision, context compression, chat titles, approval checks, Kanban triage and more) on auxiliary "helper" models, and by default each one uses the main model. Pointing a job at a cheaper or faster model is only possible from the web dashboard or by editing `config.yaml`; the app shows no trace of these settings.

## What Changes

- A "Helper models" screen, opened from the chat sidebar's More section next to Profiles, Skills, Plugins and MCP servers.
- One row per auxiliary task the server reports, in the server's order, with a readable name and the model it runs on: "Same as main model" when the slot is on `auto`, otherwise the model id, the provider and the effort when one is set.
- Tapping a row opens the shared model picker, titled with the task, with its default entry ("Use the profile's default") at the top. Closing the picker saves the final pick with `POST /api/model/set` (`scope: auxiliary`, the task, provider, model and effort); the default entry saves `provider: auto` with an empty model.
- When Hermes asks to confirm an expensive model, the app shows its message and resends with `confirm_expensive_model` only if the user agrees.
- The screen says that changes apply to new chats, because Hermes reads these slots when a session starts.

This is the first of two stacked changes. The second, `helper-model-moa`, adds the mixture-of-agents slots (`GET` and `PUT /api/model/moa`) to the same screen.

## Capabilities

### New Capabilities

- `model-settings`: viewing and changing the profile's helper models from the app.

### Modified Capabilities

None.

## Impact

- Code: `lib/src/models/` (auxiliary slot parsing and the repository calls), a new screen and list widget under `lib/src/settings/`, the sidebar entry in `lib/src/chat/widgets/thread_sidebar.dart` and `lib/src/chat/chat_screen.dart`.
- Widgetbook: use cases for the slot list. The picker's `title` and `onUseDefault` come from `chat-model-selection` and are used as they are.
- API: `GET /api/model/auxiliary`, `POST /api/model/set` and `GET /api/model/options` through the generated client. No change to `openapi/` or `packages/hermes_api`.
- Contract test: `test/real_backend_contract_test.dart` checks the auxiliary shape.

## Non-goals

- Mixture of agents; that is the next change.
- The main model of a profile, custom endpoints (`base_url`, `api_key`) for a slot, and "reset all". A slot the server reports with a custom endpoint is shown, but the picker cannot set one.
- Clearing a slot's effort without changing its model: the generated client cannot send an explicit `null` for `reasoning_effort`.

## Security and privacy impact

None. The answers carry provider slugs, model ids and endpoint URLs, never keys, and nothing is stored on the device.

## Telemetry

None beyond the existing HTTP spans.
