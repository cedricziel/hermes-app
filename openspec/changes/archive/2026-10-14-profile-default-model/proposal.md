## Why

The Profiles screen shows each profile's model but cannot change it. To give a profile another default model the user has to edit its config on the server or open the Hermes web dashboard. The per-chat pill (`chat-model-selection`) covers one chat; this change covers the profile's own default, which every chat started afterwards uses.

## What Changes

- Each row on the Profiles screen gets a "Change default model" button.
- It loads the models that profile can use (`GET /api/model/options?profile=<name>`) and opens the existing model picker, titled "Default model", with the profile's current model checked and a note that new chats use it and open chats keep theirs. No effort levels are offered; picking a model closes the picker.
- The pick is saved with `PUT /api/profiles/{name}/model` (`{provider, model}`), the route the Hermes dashboard's own Profiles page uses. On success the list reloads and a message names the new default; on failure the old model stays and the user is told.
- The model picker gains an option to hide the effort levels and close on a pick, and an optional title and note. The chat pill keeps its current behaviour.
- The profile row is pulled out of the screen into its own widget so it has catalog use cases.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `profiles-and-bots`: the profile list gains a way to change a profile's default model.

## Impact

- Code: `lib/src/profiles/` (repository, screen, a new row widget), `lib/src/models/widgets/model_picker.dart`.
- Widgetbook: use cases for the profile row and the picker without effort.
- API: `PUT /api/profiles/{name}/model` and `GET /api/model/options` through the generated client. No change to `openapi/` or `packages/hermes_api`.
- Contract test: `test/real_backend_contract_test.dart` checks the answer of the model update.

## Non-goals

- Choosing a model when creating a profile. The app has no create-profile flow; `ProfileCreate` accepts `provider` and `model`, and that flow can pass them once it exists.
- A default reasoning effort. Neither `PUT /api/profiles/{name}/model` nor the main scope of `POST /api/model/set` takes one (`ModelAssignment.reasoning_effort` is for auxiliary slots only).
- The expensive-model confirmation that `POST /api/model/set` asks for; the profile route does not ask.
- Auxiliary and helper models, and setting up providers or keys.

## Security and privacy impact

None. Only a provider slug and a model id are sent; no credential is read, sent or stored.

## Telemetry

None beyond the existing HTTP spans, which cover both requests.
