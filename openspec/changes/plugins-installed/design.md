## Context

See `proposal.md` for the motivation and `specs/plugins/spec.md` for the behaviour.

What is there today:

- The chat sidebar (`chat/widgets/thread_sidebar.dart`) has optional footer rows for Profiles and Bots. `ChatScreen` builds the rows only when it has the repository and pushes a full `MaterialPageRoute`. Plugins follows that pattern.
- `HermesProfilesRepository` and `HermesBotsRepository` show how untyped routes are read: take `response.data`, match `{'rows': [...]}` with a Dart pattern, skip rows that don't fit, and build an immutable model. The generated client has methods for all six routes, all returning `Response<Object>`:
  `getPluginsHubApiDashboardPluginsHubGet`, `postAgentPluginEnableApiDashboardAgentPluginsNameEnablePost`, `…DisablePost`, `…UpdatePost`, `deleteAgentPluginApiDashboardAgentPluginsNameDelete` and `postPluginVisibilityApiDashboardPluginsNameVisibilityPost` (body `PluginVisibilityBody`).
- `kanban/hermes_plugins_repository.dart` only asks `GET /api/dashboard/plugins`, which the server filters to enabled, activated and not-hidden dashboard plugins. `AppShell` owns that check (`_detect`). This change does not touch it.
- Against a real 0.21.1 backend the hub's `plugins` list held 57 agent plugins, all bundled (platform adapters, providers, browser and web backends and so on) with none installed by the user. Kanban and Achievements were not among them: they are dashboard-only extensions, listed under `orphan_dashboard_plugins` with a label, version, tab and `has_api`, but no status, hidden flag or update and remove flags (see decision 5).
- The Hermes routes were read in the installed 0.21.1 source: `dashboard_ui.py` (handlers) and `web_server_dashboard.py` (`_merged_plugins_hub`). The hub row is built there; the fields the app reads are listed in the spec.

**Platforms:** iOS, Android, macOS, Windows, Linux (the screen is plain Flutter). watchOS unaffected. No native entitlement, manifest or Xcode change.

**Invariants touched:** the API layering rule (all calls through `authController.api!.raw`, none hand-rolled) and the telemetry rule (opt-in, never breaks the app). Auth is not touched: the calls ride on the managed `Dio`, so token refresh and the session-token header work as they do for every other route. Concurrent 401s are handled there, not here.

## Goals / Non-Goals

**Goals:**

- A Plugins screen that is as easy to test and change as `ProfilesScreen` and `BotsScreen`.
- Room for parts 2 and 3 (Catalog and Providers tabs) without reshaping what part 1 builds.

**Non-Goals:**

- Sharing state with `AppShell`'s Kanban check.
- Optimistic updates. The server is the source of truth and the writes are rare; the UI waits.

## Decisions

### 1. Repository and models under `lib/src/plugins/`, separate from `kanban/hermes_plugins_repository.dart`

`HermesPluginManagerRepository` (hub read + five writes) and `InstalledPlugin` in `lib/src/plugins/`. The Kanban check stays where it is.

- _Why:_ the two answer different questions. The Kanban check needs a tiny answer and must fail to "off". The manager needs the whole row and must surface failures. Sharing one class would make each option fight the other.
- _Alternative:_ extend `HermesPluginsRepository`. Rejected: it would change a class the Kanban tests and `AppShell` depend on for no gain.

### 2. Lenient parsing into an immutable `InstalledPlugin`

Same style as profiles: skip rows without a non-empty string `name`, default every other field, no exceptions for shape. `path` is not read at all, so it cannot leak into the UI or telemetry.

- _Unknown `runtime_status`_ becomes `inactive`; the enum has a fallback so a future server value cannot crash the list.

### 3. Mutations return a small result, not an exception per case

Each write returns a `PluginActionResult` (`ok`, `unchanged`, `message`). The repository reads the server's `detail` from a `DioException` with a 4xx answer; anything else has no message. The screen shows `message ?? fallback`.

- _Why:_ the screen has to tell "refused, here's why" from "couldn't reach the server" without inspecting Dio types, and tests can drive both by setting a route's status in `FakeHermesServer`.
- The generated client puts the `name` path argument into the URL as it is, without encoding it. The repository therefore encodes the name with `Uri.encodeComponent` before it calls the client, so a space or `#` cannot cut the path short. Nested names (`a/b`) go out as `a%2Fb`, which the server's ASGI stack decodes before routing, so its `{name:path}` routes match. Tests guard both.

### 4. One screen, one controller, detail as a shared widget

`PluginsScreen` owns a `PluginsController` (`ChangeNotifier`, like `ThemeController`) that holds the list, the load state and the `busy` set of plugin names with a call in flight. `PluginDetail` is one widget shown either in `showModalBottomSheet` or in a pane, chosen by `LayoutBuilder` at 900 logical pixels (same constant as `ChatScreen` and `AppShell`).

- _Why a controller and not `setState` like `ProfilesScreen`:_ the detail (in a sheet, so a separate route subtree) and the list must both react to the same reload and the same busy state. A controller both can listen to is simpler than passing callbacks through a modal route.
- _Sheet content follows the list:_ the sheet reads the plugin from the controller by name on each rebuild, and pops itself when the name is gone (spec: "Selected plugin is gone").
- _Tabs:_ part 1 renders the Installed list without a tab bar. Parts 2 and 3 add a `TabBar` around it. Building the tab bar now would show two dead tabs.

### 5. Only agent plugins are listed; dashboard-only extensions are left out

The screen shows the hub's `plugins` list and ignores `orphan_dashboard_plugins`. The enable, disable, update and remove routes look a plugin up among agent plugins and answer "not installed" for a name that is only a dashboard extension, and the orphan rows carry none of the flags the screen needs. Showing them would mean rows with no working action.

- *Consequence:* the app's Kanban tab and the Plugins screen do not interact. Kanban's presence comes from `GET /api/dashboard/plugins`, which the screen never changes (hiding or disabling an agent plugin cannot remove Kanban).
- *Earlier plan, dropped:* the first draft listed `kanban` in this screen, warned on its hide switch and re-checked the Kanban tab on leaving. Reading the live hub showed `kanban` is not a row, so that would have been dead code. It is removed, and the `kanban` spec is not modified.
- *Alternative:* list the orphans read-only with a "Dashboard" tag and a hide switch. Deferred: the hub does not say whether an orphan is hidden, so the state would have to be inferred from `GET /api/dashboard/plugins`, and hiding Kanban would then need the app's Kanban check to follow. That is a change of its own.

### 6. Hide switch is the plain dashboard toggle

`POST /api/dashboard/plugins/{name}/visibility` writes `dashboard.hidden_plugins`, and the agent-plugin rows carry `user_hidden`. The switch says it only affects the web dashboard.

### 7. Update pill and sidebar badge are not in this change

The hub has no "update available"; the catalog route has it, keyed by catalog name, and no field on a hub row says which catalog entry it came from (in the installed source the link is a `.hermes-catalog.json` file on the server). So any match would be by name and wrong for plugins whose names differ from their catalog names. `plugins-catalog` reads the catalog route anyway and decides then, possibly with a name match plus a caveat.

- The Update button uses `can_update_git`, which the hub does provide. The server answers `unchanged` when nothing moved, which tells the user the outcome after the fact.

### 8. Telemetry through `AppEventLogger`

Add `Provider<AppEventLogger>` in `main.dart` next to the tracer provider, read it in `PluginsScreen` with the no-op logger as fallback. Events: `plugins.<action>.<outcome>` with `plugin.name`. Requests need nothing: the Dio interceptor already traces them.

## Risks / Trade-offs

- **Removing or disabling the wrong plugin from a phone** → Remove needs a confirm that names the plugin. Enable/disable are one switch and reversible.
- **Hub route is `session protected` and cached for a short time on the server** (a burst-collapsing cache, invalidated on every mutation). A reload right after a change shows the new state because every write route invalidates it; the contract test checks this against a real backend.
- **The real list is long and mostly bundled internals** (57 rows on a fresh server, almost all Inactive). Version 1 shows them in the server's order, like the dashboard does. A search field or grouping can follow, and the catalog change adds a search field that could be reused.
- **A stale sheet after a refresh removes the plugin** → the sheet closes itself (decision 4).
- **Untyped routes can change shape** → lenient parsing plus the contract test in `real_backend_contract_test.dart`, which runs in CI against the pinned Hermes.
- **"Applies to new chats" is an assumption.** Enabling only writes `config.yaml` (`dashboard_set_agent_plugin_enabled`); how a running agent picks it up was not verified. The wording is deliberately soft, and the real-backend check in the tasks should confirm it or the copy changes.
- **Trust:** enabling a plugin lets its code run with full access on the server, and updating one pulls new code from the source it was installed from. The dashboard already allows both to a signed-in user, and the app adds no extra confirmation for them; Remove is confirmed. If that is too permissive for a phone, a confirm on enable and update is a small addition.

## Migration Plan

None. A new screen and one new sidebar row; nothing stored. Rollback is reverting the change. On an older server the screen says the list is not available, and no other screen changes.
