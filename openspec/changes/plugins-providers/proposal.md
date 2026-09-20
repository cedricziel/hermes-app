## Why

Two things the agent uses are picked among plugins: where it keeps long-term memory (a memory provider such as Honcho or Mem0) and how it compresses long conversations (a context engine). The dashboard lets the user pick both on its Plugins page. The app cannot, so changing either means opening the dashboard.

This is part 3 of 3 under the `plugins` capability. Parts 1 (installed plugins) and 2 (catalog and installs) are merged.

## What Changes

- The Plugins screen gets a third tab, **Providers**. It loads when first opened, from the `providers` object of the plugin hub (`GET /api/dashboard/plugins/hub`).
- **Memory provider:** a choice between "Built-in" (no external memory) and each provider the server knows, marked Ready, Needs setup or Unavailable. Only providers that are ready can be picked. For one that is not, the app lists what the server says it needs (environment variables, external tools with the command to install them, Python packages) so the user can set it up on the server; the app runs nothing.
- **Context engine:** a choice among the engines the server lists, or, when it lists none, the current engine and a note that no other is available.
- **Save** sends only what changed (`PUT /api/dashboard/plugin-providers`), says "Saved. Applies to new chats.", and reloads. A refusal shows the server's reason.
- Tests against `FakeHermesServer` and contract cases in `real_backend_contract_test.dart`.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `plugins`: the screen has a third tab, and gains the provider pickers and their backend contract.

## Impact

- **Code:** `lib/src/plugins/`: provider models, two repository methods, a providers controller, the providers tab; the tab row of `plugins_screen.dart` gains one tab. No change to the sidebar, chat, auth or the generated client.
- **API:** reads the `providers` object of `GET /api/dashboard/plugins/hub` (a route part 1 already uses) and calls `PUT /api/dashboard/plugin-providers` (`PluginProvidersPutBody`, already generated) through `authController.api!.raw`. The routes have no response schema, so answers are read by hand. Minimum Hermes version 0.21.1.
- **Dependencies:** none. **Platforms:** iOS, Android, macOS, Windows, Linux; watchOS untouched.

## Non-goals

- Setting up a provider: entering its API keys, installing its tools, or running any command. The app shows what is needed; the user does it on the server. (The dashboard's Bots and setup screens have forms; a memory provider's setup is different for each and not exposed as a form by the server.)
- Installing or removing memory providers or context engines: they are plugins, handled by the Installed and Catalog tabs.
- Per-provider settings beyond choosing one.
- Choosing per chat or per profile: the server setting is global.

## Security and privacy impact

- Choosing a provider changes where the agent sends conversation memory, which can be an external service. The picker only offers providers the server reports as ready, i.e. already configured on the server by its owner, and the server checks readiness again and refuses otherwise.
- Every call goes through the managed `Dio`, so it carries the same credentials as other requests. Nothing is stored.
- Install commands the server lists are shown as text and copied only when the user taps copy; the app never runs them. Environment variable names are shown, never values (the server does not send values).

## Telemetry

- Requests are already traced by the Dio interceptor (no bodies).
- One app event per save, `plugins.providers.save.<outcome>` (`ok` or `error`), with `memory.provider` and `context.engine` only for the fields that changed, holding the provider or engine name the server reported (`builtin` for Built-in). No descriptions, commands or error bodies.
