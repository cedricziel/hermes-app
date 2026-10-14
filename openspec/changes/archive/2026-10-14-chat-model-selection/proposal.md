## Why

The chat composer has no way to choose the model or the reasoning effort. The only way to use a different model is to change the profile's default on the server, which then affects every new chat. Hermes already accepts both per chat: `session.create` takes a model, provider and effort for that session alone, and `config.set` changes them on a running session. The Hermes dashboard and desktop app expose this from their composers; the app does not.

## What Changes

- The composer shows a small pill with the chat's model and, when the model reasons, its effort in a dimmer colour (for example "claude-opus-4 · Medium").
- Tapping the pill opens a picker: the models of every provider the server reports as authenticated, grouped by provider, with the current one checked, and the effort levels below when the selected model takes one. It is a bottom sheet below 900 logical pixels and a dialog at 900 or wider.
- A choice made in a new chat goes out with `session.create`. A choice made in an existing chat goes out with `config.set` on that session before the next prompt, and only when it differs from what was last applied there.
- With no choice made, the pill shows the profile's current model and nothing extra is sent.
- The model list is loaded per profile when the chat opens and again when the profile changes. When it cannot be loaded or no provider is ready, the pill is hidden.
- The unwired model picker preview from #281 is replaced by the new pill and picker, and its unused widgets and use cases are removed.

This is the first change of a stack. Later changes, each with its own proposal: the composer's layout with the pill in a bottom row, Kanban task creation, the Kanban task panel and bulk edit, the schedule job form, profile default models, and the helper model settings.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `chat`: the composer offers a per-chat model and effort choice, and sending carries it to the gateway.

## Impact

- Code: `lib/src/models/` (options parsing, repository, pill and picker widgets), `lib/src/chat/chat_transport.dart` and `gateway/hermes_gateway_transport.dart` (a model choice on `send`), `lib/src/chat/chat_screen.dart` and `widgets/chat_composer_builder.dart`, `test/support/fake_chat_transport.dart`.
- Widgetbook: new use cases for the pill and picker; the #281 preview use cases are removed.
- API: `GET /api/model/options` through the generated client. No change to `openapi/` or `packages/hermes_api`.
- Contract test: `test/real_backend_contract_test.dart` checks the options shape.

## Non-goals

- Changing the profile's default model. The choice never writes the server's config; that belongs to the profile default model change.
- Setting up a provider or entering an API key. Providers that are not authenticated are not listed.
- Fast mode (`fast` / service tier), which Hermes also accepts per session.
- Remembering the choice across app restarts, or carrying it from one chat to the next.
- The Claude-style composer layout; the pill sits above the text field until that change lands.

## Security and privacy impact

None. The options answer carries provider slugs, names and model ids, never credentials. Nothing is stored.

## Telemetry

None beyond the existing HTTP and gateway spans, which already cover the options request and the extra `config.set` calls.
