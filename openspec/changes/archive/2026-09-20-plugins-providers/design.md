## Context

See `proposal.md` and `specs/plugins/spec.md`. Parts 1 and 2 are merged: `HermesPluginManagerRepository` (hub read, plugin actions, catalog, installs), `PluginsController`, `CatalogController`, `PluginsScreen` with two tabs (`TabBarView`, keep-alive pages, lazy load in the page's `initState`).

Read from a real Hermes 0.21.1 hub: `providers` = `{memory_provider: "", memory_options: [8 rows], context_engine: "compressor", context_options: []}`. Each memory option has `name`, `description`, `available`, `configured`, `status` (`ready`, `needs_config` or `unavailable`) and `setup` (`pip_dependencies`, `external_dependencies: [{name, install, check}]`, `required_env`, `dependencies_installed`). On a fresh server only `holographic` was ready. The context engine list was empty. `PUT /api/dashboard/plugin-providers` writes `config.yaml`; for a memory provider it checks readiness and answers 400 "Memory provider 'x' is not ready (needs config). Configure it in the dashboard first."; `""`, `built-in`, `builtin` and `none` all mean built-in. The context engine name is not validated by the route.

**Platforms:** all five app platforms; no native change. **Invariants touched:** API layering and telemetry only.

## Goals / Non-Goals

**Goals:** a third tab that follows the pattern of the first two; a picker that cannot offer what the server would refuse.

**Non-Goals:** setting a provider up (see the proposal).

## Decisions

### 1. The providers come from the same hub route, through their own repository call

`loadProviders()` calls `getPluginsHubApiDashboardPluginsHubGet` and reads only `providers`; `load()` (part 1) keeps reading only `plugins`. The two tabs load independently and lazily. The server caches the hub for a few seconds and invalidates it on every write, so a second request is cheap, and neither tab depends on the other's load.

- *Alternative:* one shared hub load feeding both. Rejected: it would tie the Providers tab's failure and refresh behaviour to the Installed tab's.

### 2. `ProvidersController` keeps server state and the user's draft apart

It holds the last `ProviderSettings` from the server and a draft (`memoryChoice`, `contextChoice`). `dirty` is true when a draft differs from the server value; Save sends only differing fields. A successful save reloads and resets the draft to the server value; a refresh does the same; a refused save keeps the draft.

- The memory choice is a string where the empty string is built-in, matching the server's own convention, so no separate flag is needed and the PUT body needs no translation.

### 3. Not-ready providers cannot be picked, but stay readable

A `RadioListTile` per option, disabled unless the status is `ready` or it is the one in use (so the user can see and keep the current one even when it has gone unavailable). Below a disabled option, an expandable "What it needs" lists `required_env` names, external tools (name and install command with a copy button), and pip packages. The server does not expose a form for provider setup, so the app shows requirements and stops there.

- Copy uses `Clipboard.setData` like the plugin login command in part 1, and only when tapped.
- *Alternative:* let the user pick a not-ready provider and show the server's refusal. Rejected: the refusal is known in advance; offering it is a dead end.

### 4. The context engine list may be empty

When `context_options` is empty the tab shows the engine in use as text with the note, not a one-item radio group. When the engine in use is missing from a non-empty list, it is added as the first option so the current state is always visible and selectable.

### 5. Telemetry through `AppEventLogger`, only changed fields

`plugins.providers.save.<outcome>`, with `memory.provider` (the name, or `builtin`) and `context.engine` only when that field was sent. Names come from the server's own lists.

## Risks / Trade-offs

- **Switching memory provider moves where memory is stored, and conversations already stored are not migrated by this app.** → The tab says the change applies to new chats; what the server does with existing memory is its own behaviour, unchanged from the dashboard.
- **`config.yaml` is global** → the tab makes no claim about per-profile settings.
- **A status the app does not know** (a newer server) → reads as Unavailable, which disables the option rather than offering something the server may refuse.
- **The context engine name is not validated by the server** → the app only offers names the server listed (or the current one), so it cannot send an arbitrary name.

## Migration Plan

None: a new tab, nothing stored. Rollback is a revert. An older server shows "not available".
