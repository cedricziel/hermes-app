## Why

The Plugins screen shows what is installed but cannot add anything. Hermes ships a curated catalog of 194 plugins (each pinned to a reviewed commit, with a kill list the server enforces) and lets an administrator install from any Git URL. To add a plugin today, a user has to open the web dashboard or SSH to the server.

This is part 2 of 3 under the `plugins` capability. Part 1 (`plugins-installed`) is merged; part 3 (`plugins-providers`) follows.

## What Changes

- The Plugins screen gets a tab row: **Installed** (as before) and **Catalog**. The catalog loads when its tab is first opened.
- **Catalog tab:** a search field and one row per catalog entry (from `GET /api/dashboard/plugins/catalog`) with name, tier (Official or Community), maintainer, a two-line description, a short commit chip and its state: Install, Installed, or "Update available".
- **Entry details** (bottom sheet below 900 logical pixels, pane at 900 or wider): the whole description, maintainer, tier, the Hermes version it needs, platforms, the tools, hooks and environment variables it declares, the pinned commit, a link to its docs, an "Enable after install" switch (on by default) and Install.
- **Install from the catalog** (`POST /api/dashboard/agent-plugins/install` with `catalog_name`). On success the app says what was installed, lists any environment variables the user still has to set on the server, shows the server's warnings, and reloads both lists. A refusal (for example an entry on the server's removed list, or a failed safety scan) shows the server's reason.
- **Install from a Git URL or `owner/repo`** behind a button in the Catalog tab: a dialog with a plain warning that the code is unreviewed and runs on the server with full access, an "I trust this source" checkbox that must be ticked, an "Enable after install" switch, and an "Overwrite existing (force)" switch under Advanced. The server's warnings are shown after the install.
- Tests against `FakeHermesServer` and contract cases in `real_backend_contract_test.dart` for the catalog read.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `plugins`: adds the Catalog tab, catalog installs, installs from a Git URL, and the backend contract for those routes.

## Impact

- **Code:** `lib/src/plugins/`: catalog model, repository methods (`loadCatalog`, two installs), a catalog controller, the catalog tab, its details and the Git URL dialog; the Plugins screen gains its tab row. No change to the sidebar, chat, auth or the generated client.
- **API:** reads `GET /api/dashboard/plugins/catalog` and calls `POST /api/dashboard/agent-plugins/install` (body model `AgentPluginInstallBody`, already generated) through `authController.api!.raw`. Neither has a response schema in the spec, so the responses are read by hand. Minimum Hermes version 0.21.1.
- **Dependencies:** none new (`url_launcher` is already used).
- **Platforms:** iOS, Android, macOS, Windows, Linux. watchOS untouched.

## Non-goals

- The "Update available" pill on the Installed tab and a count on the sidebar row. The catalog names an entry by its catalog name and never by the installed plugin's own name, so the two lists cannot be joined reliably. The Catalog tab shows the state for its own entries; updating still happens from the Installed tab.
- Updating from the Catalog tab. The update route wants the installed plugin's name, which the catalog does not give.
- Showing the server's removed list. The server refuses those installs and says why.
- Showing the details of a failed safety scan. The route answers only its summary line as `detail`.
- Setting a plugin's environment variables from the app. The app lists the names the user still has to set on the server.
- The memory provider and context engine pickers (`plugins-providers`).

## Security and privacy impact

Installing runs third-party code on the user's server with full access, so this is the most privileged thing the app does:

- A catalog install sends only the catalog name; the server resolves the repository and the pinned commit and enforces its removed list.
- A Git URL install sends what the user typed. It is the one place the app lets unreviewed code in, so it is fenced: a warning in plain words, a checkbox that has to be ticked before Install is enabled, and `force` hidden under Advanced. The server also flags it (`Custom (unreviewed) source`) and an insecure `http://` or `file://` URL, and the app shows those warnings.
- The typed URL is never logged, put in telemetry, saved, or kept after the dialog closes: it can carry a token (`https://user:token@host/...`).
- The call goes through the managed `Dio`, so it carries the same credentials as every other request. Nothing new is stored.
- Docs links open in the system browser, and only for `http` and `https`.

## Telemetry

- Requests are already traced by the Dio interceptor (the privacy variant, no bodies).
- One app event per install: `plugins.install.<outcome>` with `plugin.name` for a catalog install, and `plugins.install_custom.<outcome>` with no attributes for a Git URL install, so the URL never reaches telemetry. Outcome is `ok` or `error`.
