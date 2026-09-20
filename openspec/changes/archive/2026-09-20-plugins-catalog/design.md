## Context

See `proposal.md` for the motivation and `specs/plugins/spec.md` for the behaviour. Part 1 (`lib/src/plugins/`) is merged: `HermesPluginManagerRepository`, `PluginsController`, `PluginsScreen`, `PluginDetail`, and the tag widgets.

- The screen today is one list with an app bar and no tabs. `_body(wide)` builds the list and `_SheetHost`/the pane show the details.
- The generated client has `getPluginsCatalogApiDashboardPluginsCatalogGet` and `postAgentPluginInstallApiDashboardAgentPluginsInstallPost(agentPluginInstallBody: AgentPluginInstallBody(identifier, force, enable, catalogName))`. `identifier` is required by the model, so a catalog install sends an empty one.
- The catalog was read from a real Hermes 0.21.1: 194 entries (4 `official`, the rest `community`), descriptions up to 761 characters, 59 entries declaring tools, 38 declaring env vars, 17 naming platforms, `requires_hermes` values such as `>=0.20`, `removed` empty. The install route answers `{ok, plugin_name, warnings, missing_env, enabled}` and, when it refuses (including a failed safety scan and the removed list), a 400 whose `detail` is one summary line; the scan's findings are in the handler's result but the route drops them.
- The authenticated Dio in `AuthController` has a 30 s receive timeout, and an install is a `git clone` plus a scan on the server.

**Platforms:** iOS, Android, macOS, Windows, Linux. No native change; `url_launcher` is already a dependency.

**Invariants touched:** API layering (all through `authController.api!.raw`) and telemetry (opt-in, never breaks the app, and here also must not carry a typed URL).

## Goals / Non-Goals

**Goals:**

- Keep part 1's screen working as it is, as the first tab.
- Make the one unreviewed-code path (Git URL) hard to hit by accident and leak nothing.

**Non-Goals:**

- Joining the catalog to the hub (see the proposal's non-goals).
- Raising the app-wide HTTP timeout. Only the slow install is handled.

## Decisions

### 1. Tabs are `TabBarView` pages that stay alive, the catalog page loads on first build

`PluginsScreen` becomes a `DefaultTabController` with the tab row under the app bar. Its two pages mix in `AutomaticKeepAliveClientMixin` so search text, scroll and selection survive a tab switch. `TabBarView` builds a page only when it is first shown, so the catalog controller is created and `load()` runs in that page's `initState`: no request before the tab is opened, without extra flags.

- *Alternative:* `IndexedStack` with a manual "opened" flag as `AppShell` does for Kanban. Rejected: more state to hold for the same result.
- The list, master-detail and sheet logic from part 1 is moved into `_InstalledTab` unchanged. The catalog tab repeats the pattern with its own controller rather than generalising over two item types; the two lists differ enough (search, states) that a shared abstraction would be guesswork.

### 2. Repository returns plain results, never throws for install outcomes

`HermesPluginManagerRepository` gets `loadCatalog()` (throws `PluginsUnsupported` on 404, like `load()`), `installFromCatalog(name, {enable})` and `installFromSource(identifier, {enable, force})`. Both installs return a `PluginInstallResult` with `ok`, `pluginName`, `warnings`, `missingEnv`, `message` (the server's `detail` for a 4xx) and `timedOut`. A receive timeout is `timedOut: true` and not an error: the server may well finish.

- The catalog name and identifier go in the body, not the path, so no encoding concern (part 1's name encoding is for path segments).
- `warnings` and `missing_env` are read as lists of non-empty strings; anything else is dropped.

### 3. `CatalogController` owns list, search, install state and telemetry

Holds entries, the search text (filter applied in a getter over the loaded list; 194 entries need no index or debounce), the failure state, the selected entry, and the set of names with an install running. After a successful or timed-out install it calls `onInstalled`, which `PluginsScreen` wires to `PluginsController.refresh()`, and reloads its own list.

- Telemetry: `plugins.install.<outcome>` with `plugin.name` (the catalog name) for a catalog install; `plugins.install_custom.<outcome>` with no attributes for a Git URL install. `timedOut` is logged as outcome `timeout`. The typed identifier never reaches the controller's event code.

### 4. The Git URL dialog owns the typed text and hands back only a result

`GitInstallDialog` is a stateful dialog with its own `TextEditingController`, disposed on close. It calls a callback `install(identifier, enable, force)` and shows progress; on completion it pops with the `PluginInstallResult` and the caller reports the outcome. The identifier is trimmed in the dialog and passed by value; it is not stored in a field of any longer-lived object, not put in an event, and not in an error message (`PluginInstallResult.message` is the server's `detail`, which never echoes the request).

- Install enabled = trimmed text non-empty && trust checkbox ticked. `force` sits in a collapsed `ExpansionTile`.
- *Alternative:* a plain confirm dialog instead of a checkbox. Kept the checkbox: it needs a deliberate action per install and is easy to test.

### 5. One outcome reporter for both installs

`reportInstall(context, result)` shows the snackbar ("Installed X", the server's reason, "Could not install this plugin", or the slow-install text), then the warnings (a second snackbar, or appended lines), then the `missing_env` dialog. One function, so a catalog install and a Git URL install cannot drift apart.

### 6. The Catalog tab shows update state but does not update

The catalog's `installed`/`update_available` are shown as chips. Updating stays on the Installed tab (`can_update_git`), for the reason in the proposal.

## Risks / Trade-offs

- **Installing the wrong or hostile code from a phone** → catalog installs are pinned and the server enforces its removed list and safety scan; the Git URL path is fenced by a notice, a checkbox and the server's own warnings. The decision that a phone may install at all was the user's.
- **Slow installs** → handled as "still installing" (decision 2), not as a failure. Consequence: the user may tap Install again after a timeout; the server answers "already installed" and the reason is shown.
- **A 194-row list** → a plain `ListView.builder`; search is a linear scan.
- **Catalog freshness** → the server refreshes the catalog live from the docs site and falls back to its shipped copy; the app just shows what it is given.
- **`requires_hermes` is a string like `>=0.20`** → shown as text, not compared: the app does not know the server's version and the server checks it on install.

## Migration Plan

None. New tab and dialogs; nothing stored. Rollback is a revert. An older server shows "not available" in the tab.
