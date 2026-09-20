## Why

The Hermes dashboard has a Plugins page: it shows what is installed, turns plugins on and off, updates and removes them. The app has nothing like it. The only plugin it knows about is Kanban, and it only asks whether that one is on. To manage plugins, a user has to open the web dashboard or SSH to the server.

This is part 1 of three changes that add plugin management to the app under one `plugins` capability. Part 1 covers everything about plugins that are already on the server. Part 2 (`plugins-catalog`) adds the catalog and installing. Part 3 (`plugins-providers`) adds the memory provider and context engine pickers.

## What Changes

- Add a **Plugins** row to the chat sidebar footer, next to Profiles and Bots. It opens a full Plugins screen.
- The Plugins screen has an **Installed** tab that lists every plugin on the server (from `GET /api/dashboard/plugins/hub`). Each row is an agent plugin (the kind the server can enable, disable, update and remove). It shows name, version, description and a status chip (Enabled, Disabled or Inactive). A row can also carry Bundled, "Needs login" and, for a plugin on the server's removed list, Removed tags with the reason.
- Tapping a row opens a **detail view**: a bottom sheet below 900 logical pixels, a side pane at 900 or wider. It has:
  - an Enabled switch (`enable` / `disable`),
  - Update (only for plugins the server marks as updatable; the server answers whether anything changed),
  - Remove, behind a confirm dialog (only for plugins the server says it can remove),
  - a "Hide from dashboard sidebar" switch,
  - the copyable login command for a plugin whose tools need a login.
- The Catalog and Providers tabs are not built here. The screen shows only the Installed tab until parts 2 and 3 land. The tab row appears when the second tab exists.
- Refresh the plugin list on open, on pull-to-refresh, and after every change.
- Add tests against `FakeHermesServer`, plus contract checks in `real_backend_contract_test.dart`.

## Capabilities

### New Capabilities

- `plugins`: the Plugins screen and its Installed tab. How the screen is reached, how installed plugins are listed and described, how a plugin is enabled, disabled, updated, removed and hidden, and which backend routes it relies on. Parts 2 and 3 add requirements to this same capability.

### Modified Capabilities

None.

## Impact

- **Code:** a new `lib/src/plugins/` folder (repository, models, screen, detail view); one new row in `lib/src/chat/widgets/thread_sidebar.dart` and its wiring in `chat_screen.dart`. No change to auth, chat transport or the generated client.
- **API:** reads `GET /api/dashboard/plugins/hub` and calls `POST /api/dashboard/agent-plugins/{name}/enable|disable|update`, `DELETE /api/dashboard/agent-plugins/{name}` and `POST /api/dashboard/plugins/{name}/visibility` through `authController.api!.raw`. None of these routes has a response schema in the spec, so the app parses them by hand. Minimum Hermes version: 0.21.1, where all six routes exist. On an older server the row opens a "not supported by this server" page rather than an error.
- **Dependencies:** none. No new package, no native project change, no platform entitlement.
- **Platforms:** iOS, Android, macOS, Windows, Linux. The watchOS app is untouched.

## Non-goals

- Browsing the catalog and installing (catalog or Git URL). All of that is `plugins-catalog`.
- Telling the user an update is waiting: an "Update available" pill on a row and a count on the sidebar entry. That fact only exists in the catalog route, which names entries by catalog name and never by the plugin's own name, so the two cannot be matched reliably yet. `plugins-catalog` reads that route and revisits it.
- The memory provider and context engine pickers. That is `plugins-providers`.
- Running a plugin's login command. The app shows the command and lets the user copy it; the user runs it on the server.
- Showing or running a plugin's own web UI. Kanban keeps its native screens; nothing new is built for Achievements or others.
- Editing a plugin's settings, environment variables or files.
- Dashboard-only extensions such as Kanban and Achievements. The server lists them apart from agent plugins (`orphan_dashboard_plugins`), with no enabled state, no hidden flag and no update or remove flags, and the enable, disable, update and remove routes do not apply to them. Showing them, and what hiding one means for the app's Kanban tab, needs its own change.
- Changing which plugins are enabled for a single chat. Enabling and disabling is server-wide.

## Security and privacy impact

Enabling, updating and removing a plugin changes what code the server runs, so these are privileged actions:

- Every call goes through the managed `Dio` from `authController.api!.raw`, so it carries the same bearer token, or the `X-Hermes-Session-Token` on a server without the auth gate. No token is stored or logged by this change, and nothing is written to preferences.
- Remove is destructive and asks for confirmation. Enabling and updating change what code runs on the server (an update pulls new code from the plugin's own source), but the dashboard already lets a signed-in user do both, so the app asks for no extra confirm. Installing from an unreviewed source, which is a new source, is part 2 and gets a warning there.
- The login command shown for a plugin comes from the server. The app only displays and copies it; it never runs it. It is put on the clipboard only when the user taps copy.
- Plugin paths on the server (`path` in the hub response) are never shown or sent to telemetry.

## Telemetry

Emitted through flutter_otel, and nothing when telemetry is off:

- Every request is already traced by the app's Dio interceptor (the privacy variant, which records no bodies). The plugin routes need no extra span.
- One app event per user action, in the style of `auth.sign_in.<outcome>`: `plugins.enable.<outcome>`, `plugins.disable.<outcome>`, `plugins.update.<outcome>`, `plugins.remove.<outcome>` and `plugins.hide.<outcome>`, where outcome is `ok`, `unchanged` (update only) or `error`. Attributes: `plugin.name`, the name the server reported. No paths, no descriptions, no error bodies.
- Logging never breaks the screen: the logger is a no-op when telemetry is off, and its failures are swallowed.
