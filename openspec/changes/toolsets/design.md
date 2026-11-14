## Context

Hermes keeps, per profile, a list of enabled toolsets (`platform_toolsets.<platform>` in the profile's `config.yaml`). A toolset is a named group of tools: `terminal` holds `terminal` and `process`, `web` holds `web_search` and `web_extract`. The dashboard has routes to read the list, switch a toolset, and finish its setup. The app uses none of them yet; it only shows tool calls (`ToolCall`, `ToolCallGroup`) in a chat.

Everything below was read in the Hermes source at the revision the contracts are pinned to (`openapi/HERMES_REF`, `d923a5eb`): `hermes_cli/web_routers/tools.py` (the REST routes), `hermes_cli/web_models.py` (request bodies), `hermes_cli/tools_config.py`, `tools_config_providers.py` and `tools_config_post_setup.py` (the toolset catalog, provider rows, readiness and install keys), `tools/computer_use/permissions.py` (the computer-use status), `hermes_cli/web_routers/actions.py` (action status) and `tui_gateway/methods_tools.py` plus `tui_gateway/server.py` (the gateway methods). Examples below are built from those functions' return statements; Task 1.1 replaces them with recorded fixtures from a throwaway backend.

## Goals / Non-Goals

**Goals**

- Show every toolset of a profile with its state and say, in one plain sentence each, what it lets the agent do.
- Switch a toolset on or off, with a confirmation for the ones that run commands or control a computer.
- Complete a toolset's setup from the app: provider, keys, install step, model, terminal backend, computer-use permission.
- Look and behave like Skills, Plugins, MCP servers and Helper models.
- Make the difference between a tool, a skill, a plugin and an MCP server clear to someone who never read Hermes' docs.

**Non-goals**

- See proposal.md. In short: no per-chat tool changes, no single-tool switches, no server file editing, no managed-provider sign-in, no Bot Screen rebuild, no server change.

## Server surface

Every route sits under the dashboard origin and goes through the app's authenticated `Dio`. All of them are in `openapi/hermes-agent.openapi.json` (`getToolsetsApiToolsToolsetsGet` and its siblings in `packages/hermes_api`), none has a response schema, so each returns untyped JSON and the repository parses it. All routes except the action status ones take `profile`: GET routes as a query parameter, writes as a query parameter or in the body (the server uses `body.profile or query profile`). The app sends the chat profile explicitly on every call and never relies on the server's launch profile.

Errors are HTTP errors with `{"detail": "<text>"}`. `400` is a refused value (unknown toolset — Hermes answers 400, not 404, for a toolset it does not list — unknown provider, unknown env key, unknown model, blank value) and its text is Hermes' own wording; `500` is a failed spawn; a missing route is `404` or `405`; a body that does not validate is `422`. An invalid profile name is `400` and a profile that no longer exists is `404` "Profile '…' does not exist" (`web_server_profiles.py`), which is NOT "no Tools on this server": the repository tells the two apart by the detail text and answers `ToolsProfileGone`, and the app then re-reads the profile list instead of hiding Tools.

### `GET /api/tools/toolsets?profile=` — list

Returns a bare JSON array, one object per configurable toolset (built-ins plus plugin toolsets, appended):

```json
[
  {
    "name": "web",
    "label": "Web Search & Scraping",
    "description": "web_search, web_extract",
    "platform": "cli",
    "platform_label": "CLI",
    "enabled": true,
    "available": true,
    "configured": false,
    "tools": ["web_extract", "web_search"]
  }
]
```

- `enabled` is whether the name is in the profile's list for the toolset's `platform`. `available` is a copy of `enabled`; it does not say the toolset can work. The app ignores it.
- `configured` is the "needs setup" signal: `false` means no provider of the toolset has what it needs (a key, a sign-in, an installed driver). Toolsets with no provider matrix (file, todo, session search) report `true` when their required env vars, if any, are set. `stt` is config-only: its switch is `stt.enabled`, not a list entry.
- `platform` is `cli` for nearly everything. A toolset restricted to another platform (the Discord ones) reports that platform and `platform_label`; switching it writes that platform's list. The app's chats read the `cli` list (`_load_enabled_toolsets` in `tui_gateway/server.py` reads `platform_toolsets.cli`), so for `cli` toolsets this list is the one app chats use.
- `label` has its leading emoji stripped; plugin toolsets are labelled with a plug emoji server-side, also stripped. `description` is usually a list of tool names and sometimes a sentence, so the app writes its own sentence for the built-ins it knows and falls back to `description` only for a toolset it does not know.
- `tools` is the resolved tool names; it may be empty when resolution fails.
- Row order is the server's catalog order. The app keeps it inside each group.

### `PUT /api/tools/toolsets/{name}` — switch

Body `{"enabled": true, "profile": null}`. Answer `{"ok": true, "name": "computer_use", "platform": "cli", "enabled": true, "post_setup_started": "cua_driver"}`. `400 "Unknown toolset: <name>"` for a name outside the list. Writes `platform_toolsets.<platform>` through Hermes' own helper (the CLI uses the same). A switch **on** also looks for a provider whose install step is not satisfied (the cua-driver binary is missing, for example) and, if found, starts that step in the background and names it in `post_setup_started`. That is the same long action as the post-setup route below. The pending-install check looks at **every** visible provider of the toolset, not the one the user picked, and the answer carries no `pid`, so the app cannot tell that run from another client's. The switch writes config only: it does not touch running chats (see "When a change takes effect").

### `GET /api/tools/toolsets/{name}/config?profile=` — provider matrix

```json
{
  "name": "web",
  "has_category": true,
  "active_provider": "Firecrawl",
  "providers": [
    {
      "name": "Firecrawl",
      "badge": "paid",
      "tag": "Search and extract",
      "env_vars": [
        {
          "key": "FIRECRAWL_API_KEY",
          "prompt": "Firecrawl API key",
          "url": "https://…",
          "default": null,
          "is_set": false
        }
      ],
      "post_setup": null,
      "requires_nous_auth": false,
      "managed_nous_feature": null,
      "is_active": true,
      "status": "needs_keys"
    }
  ]
}
```

- `has_category: false` (file, todo and the like) means nothing to set up here.
- `status` per provider is one of `ready`, `needs_keys`, `needs_auth` (a sign-in on the server, such as the Nous Portal or Codex), `needs_setup` (an install step has not run). The app treats an unknown value as "needs setup" and shows it plainly.
- `env_vars[].is_set` reports presence only; the route never returns a value.
- `web` adds `web_backend` and `capabilities` (`search`, `extract`) per row and the top-level `active_search_backend`, `active_extract_backend`, `search_via_nous`, `extract_via_nous`. `tts` rows carry `tts_provider`.
- The matrix is computed with fresh entitlement reads, so it can take a second or more; the app shows a labelled progress state.

### `PUT /api/tools/toolsets/{name}/provider` — pick a provider

Body `{"provider": "Firecrawl", "capability": null, "profile": null}`. Answer `{"ok": true, "name": "web", "provider": "Firecrawl"}`, plus `"capability"` when sent, plus `"needs_nous_auth": true, "feature": "<slug>"` for a managed (Nous Portal) row whose account is not entitled: Hermes wrote the config, but the row will not work until someone signs in on the server. `capability` (`search` or `extract`) is valid for `web` only (`400` otherwise).

### `PUT /api/tools/toolsets/{name}/env` — keys

Body `{"env": {"FIRECRAWL_API_KEY": "…"}, "profile": null}`. Answer `{"ok": true, "name": "web", "saved": ["FIRECRAWL_API_KEY"], "skipped": [], "is_set": {"FIRECRAWL_API_KEY": true}}`. Keys must belong to a visible provider of that toolset (`400 "Unknown env var(s) for toolset …"` otherwise); a blank value is skipped, not cleared (`skipped`), so the app cannot remove a key through this route and says so. Values are trimmed and written to the profile's `.env`. The answer never echoes a value.

### `GET /api/tools/toolsets/{name}/models?provider=&profile=` and `PUT …/model`

Only `image_gen` and `video_gen` have catalogs. Others answer `{"name", "has_models": false, "models": [], "current": null, "default": null}`. With a catalog: `{"name": "image_gen", "has_models": true, "provider": "…", "plugin": "…", "models": [{"id", "display", "speed", "strengths", "price"}], "current": "…", "default": "…"}`. `PUT` takes `{"model": "<id>", "provider": null, "profile": null}` and answers `{"ok": true, "name", "model", "plugin"}`; `400` for an unknown model or when no model-capable backend is active. `price` and `speed` are free text from the server and are shown as given.

### `POST /api/tools/toolsets/{name}/post-setup` — install step

Body `{"key": "cua_driver", "profile": null}`; `key` comes from a provider row's `post_setup`. `400` for a key Hermes does not list. It spawns `hermes tools post-setup <key>` on the server and answers `{"ok": true, "pid": 123, "name": "tools-post-setup", "key": "cua_driver"}`. Progress is `GET /api/actions/tools-post-setup/status?lines=` → `{"name", "running", "exit_code", "pid", "lines": [...]}`; the status routes take no `profile`. `tools-post-setup` has **one** log and process slot for the whole dashboard, shared by every profile, toolset and the switch's own install, and the spawn route does not refuse a second run. The log is appended to, so old lines can show. `running: false` with `exit_code: null` is a normal state (the dashboard restarted or another run replaced the slot) and means "can't tell". The app runs one at a time per connection and treats any end it cannot tie to its own start as unknown. The step installs software and may download from the internet, so the app asks first.

### `GET /api/tools/terminal/backends?profile=` and `PUT /api/tools/terminal/backend`

`{"active": "local", "backends": [{"name": "docker", "label": "Docker", "description": "…", "active": false, "status": "needs_setup", "detail": "Docker CLI not found — install Docker Desktop, docker-ce, or Podman."}]}`; `status` is `ready`, `needs_setup` or `unavailable`, and a probe failure is a status, never an error. The probes run on the server (the Docker probe times out at 2 s). `detail` is server text, often naming a setting in `config.yaml` or an env var. `PUT` takes `{"backend": "docker", "profile": null}`, answers `{"ok": true, "backend": "docker"}`, and accepts a backend that still needs setup (Hermes shows guidance instead of blocking). `400` for a name outside the rows. Plugins can add rows, so the list is read, not assumed.

### `GET /api/tools/computer-use/status?profile=`

```json
{
  "platform": "darwin",
  "platform_supported": true,
  "installed": true,
  "version": "…",
  "ready": false,
  "can_grant": true,
  "checks": [{ "label": "…", "status": "…", "message": "…" }],
  "source": null,
  "error": null,
  "accessibility": true,
  "screen_recording": false,
  "screen_recording_capturable": null
}
```

`platform` is the **server's** platform. `can_grant` is true on any macOS server using the default driver, even with the driver missing; then the permission fields are `null`, so "Allow access" needs `installed: true` and a permission that is exactly `false`. `ready` is the single signal: on macOS both permissions, elsewhere the driver's health; `null` means unknown (binary missing or probe failed). `can_grant` is true only on a macOS server using the default driver. Another selected driver reports `installed: true`, `can_grant: false`, and its own readiness.

### `POST /api/tools/computer-use/permissions/grant`

`400 "Computer Use permission grants are a macOS concept."` when the server is not macOS; otherwise it spawns the grant as the `computer-use-grant` action (`{"ok": true, "pid", "name": "computer-use-grant"}`), polled at `GET /api/actions/computer-use-grant/status`. The permission dialog opens on the **server's** screen. Someone at that computer has to approve it.

### Gateway methods (`/api/ws`)

None of these is used by this change. Read from `tui_gateway/methods_tools.py` and `server.py`:

| Method                        | Takes                                          | What it does                                                                                                                                     | Why not here                                                                                                  |
| ----------------------------- | ---------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------- |
| `toolsets.list`, `tools.list` | `session_id` (optional)                        | Rows `{name, description, tool_count, enabled[, tools]}` from the registry; `enabled` is the live session's set, or, with no session, the launch profile's configured set | Names every registered toolset including ones the Settings screens do not offer, no `profile`, no setup state |
| `tools.show`                  | `session_id`                                   | The tools the session's agent would have, grouped by toolset, with a one-line description each                                                   | Session view; useful for a later "tools in this chat"                                                         |
| `tools.configure`             | `session_id`, `action` enable/disable, `names` | Writes the `cli` list, also MCP `server:tool` names, and **resets the session's agent**; `4009` while a turn runs, `4017/4018` for bad input     | Resets a chat; takes no `profile` (the session decides); cannot reach other platforms' lists                  |
| `reload.env`                  | none                                           | Re-reads the launch home's `.env` for the dashboard process, answers `{"updated": n}`                                                            | Not profile-scoped                                                                                            |
| `reload.mcp`                  | `session_id`, `confirm`                        | Reconnects MCP servers; invalidates the prompt cache and answers `confirm_required` first                                                        | MCP servers are their own screen                                                                              |

### When a change takes effect

The REST writes change `config.yaml` and `.env` only; they do not reach into running sessions (only `tools.configure` resets a session's agent, and `reload.mcp` refreshes live sessions). A new chat reads the list when its agent is built (`_load_enabled_toolsets`). So the app says "Applies from your next chat. A chat that is already open keeps the tools it started with." Task 1.1 confirms this on a throwaway backend, including that `session.resume` of an old chat builds a fresh list; if a resumed chat turns out to keep the old list, the sentence says "new chats and chats you reopen" only after the check. Three things can override the list: an operator's `HERMES_TUI_TOOLSETS` pin, the coding-workspace posture, and the agent's `disabled_toolsets` plus a surface fold-in (`server.py`); the save path reconciles the disabled list when a toolset is switched on. `stt` has no platform list (its switch is `stt.enabled`), so "next chat" is checked for it separately in Task 1.1. The app cannot see either; this is a known limit (see Risks).

## Decisions

**REST only.** The Tools screen works for any profile without a chat, and every REST route except the action status ones takes `profile`. The gateway methods act on a live session or the launch profile, so they cannot show or change another profile's tools. This also keeps a switch from resetting a chat in progress.

**Where it lives.** Sidebar action "Tools" after "MCP servers" and before "Helper models" (`AppIcons` wrench, designer's choice), in the drawer's More section on phone, hidden when the server has no `/api/tools/toolsets`. On macOS the sidebar keeps no per-profile management rows, so Tools is a section on the Profiles page like Memory and Messaging, with the count read lazily ("5 of 12 on"), each opening `ToolsScreen` for that profile. The screen shows the chat's profile (or the one picked on the Profiles page) in its subtitle, "profile · 5 on", like the siblings.

**Availability probe.** `ToolsAvailability` (owned by `AppShell`, like the Kanban and Schedules checks) reads `GET /api/tools/toolsets` once on connect and on resume and keeps the rows as the screen's first data. `404`/`405` means no Tools row and no message; a network error or `5xx` keeps the previous answer, or hides the row when there was none, and logs outcome `unreachable`, no banner. The probe reads the profile the chat shows. It seeds only that profile's screen; a screen opened for another profile (the Mac Profiles page) reads its own list on open.

**Repository.** `HermesToolsRepository` (`lib/src/tools/`) wraps `authController.api!.raw` and parses leniently: a row without a string `name` is skipped and counted; `enabled` and `configured` default to false when they are not booleans; `tools` keeps the strings it finds. It returns a sealed `ToolsResult<T>` (`ToolsOk`, `ToolsUnsupported` for 404/405, `ToolsRefused(detail)` for 400, `ToolsFailed(kind)` for the rest), never an exception, like `BotScreenResult`. Writes return the Hermes answer's parsed fields. `forProfile(name)` binds the profile like `HermesPluginManagerRepository.forProfile`. A lost answer to a write is `ToolsFailed.unknownOutcome`; the controller reads the list again and never resends.

**Controllers.** `ToolsController` holds the list, the loading and error state, the selected toolset, one write at a time per toolset (a switch tapped twice waits), optimistic switch with rollback to the last confirmed value, and rereads the list after every write; late answers for another profile or a disposed controller are dropped. `ToolsetSetupController` (one per open detail) holds the provider matrix, the selected provider, the key fields, the model catalog and the install follow; `TerminalBackendsController` and `ComputerUseController` hold their screens' state. Switching a toolset on that returns `post_setup_started` shows "Hermes started an installer on your server" and follows the shared status log read-only, ending in "Checking…" and a config re-read, never in "Installed" from the log alone.

**Risk table.** A small table in `lib/src/tools/toolset_risk.dart`, keyed by built-in toolset name, gives each a plain sentence and a level; a name not in the table has no risk text and no confirmation, and shows the server's description.

| Toolset          | Level   | What the screen says it lets Hermes do                       |
| ---------------- | ------- | ------------------------------------------------------------ |
| `terminal`       | confirm | Run commands on the machine where Hermes runs.               |
| `code_execution` | confirm | Write and run programs on that machine.                      |
| `computer_use`   | confirm | See the screen of a desktop and move its mouse and keyboard. |
| `file`           | explain | Read, create and change files on that machine.               |
| `browser` | confirm | Open web pages, click and type in them; Hermes may also install a browser on the server. |
| `cronjob`        | explain | Create tasks that run later without you.                     |
| `delegation`     | explain | Start helper agents that work on their own.                  |
| `discord_admin`  | explain | Manage a Discord server's channels and roles.                |

"Confirm" levels ask before switching on (a switch can start an installer for any provider of the toolset, and the answer names none); "explain" levels show the sentence in the row and detail but do not ask; everything else shows neither. The table is the one place to extend, and a test pins that every name in it is a name the server's catalog uses (Task 1.1 records the catalog).

**Safety confirmations.** Switching on a "confirm" toolset opens the platform's alert (a dialog on Mac and wide windows, the iOS/Material alert elsewhere; `confirmDestructive`-style helper) titled "Let Hermes run commands?", body the risk sentence plus "It applies to <profile>. You can switch it off again here.", actions Cancel (default) and "Switch on". It asks every time it is switched on, not once. Switching off never asks. Choosing the Local terminal backend asks "Run commands directly on your server?" with "Commands will run on the same machine as Hermes, not in a container." Starting an install step asks "Install on your server?" with "Hermes will run an installer on the server. It may download software." Starting the macOS permission grant asks "Allow access on the server's Mac?" with "A permission window will open on the computer that runs Hermes. Someone there has to approve it." Each confirmation says exactly what will happen and can be cancelled; none is a one-tap undoable surprise.

**Setup flow, per toolset.** The detail's "Set up" section is shown when `configured` is false, and under "Change setup" when it is true and the toolset has a provider matrix. It reads `/config` when the section is first opened.

1. **Provider.** Radio rows: name, `tag`, `badge`, and a status chip: Ready, Needs a key, Needs a sign-in on the server, Needs install. The active one is marked. Picking one sends `/provider`. A `needs_nous_auth` answer becomes the inline note "This needs a sign-in to Nous Portal on your server. The app can't do that for you." For `web`, an "Advanced" row "Use different providers for search and extract" shows two pickers that send `capability`; most people never open it.
2. **Keys.** For the selected provider's `env_vars`: a masked field per key labelled with `prompt` (falling back to the key text), a "Get a key" link from `url` that opens in the external browser, and "Already set" when `is_set`, with "Replace" revealing the field. Blank fields are not sent. Save sends only typed fields to `/env`, then clears them whatever the outcome.
3. **Install.** When the selected provider has `post_setup`, an "Install on server" button is the main action if its status is `needs_setup`, and sits under "Advanced" as "Run the install step again" otherwise (a provider with keys never reports `needs_setup`, so its status cannot be trusted); an "Install on server" button after the confirmation sends `/post-setup` and follows `/api/actions/tools-post-setup/status` every 2 s: the last 6 log lines, a Done / Failed result from `exit_code`, and it survives leaving the screen because `ToolsAvailability`-level state (`ToolsetInstalls`, owned by `AppShell` and keyed by connection) holds it, like `BotScreenInstalls`. 22 minutes without an end reads as "unknown" and the setup is read again.
4. **Model** (`image_gen`, `video_gen`). A "Model" row opens a list sheet (`display`, `speed`, `strengths`, `price`, the default marked); a pick sends `/model`.
5. **Done.** After every write the list and the config are read again; the state line becomes "Ready" or says what is still missing. A provider the app cannot complete (sign-in, a setting in `config.yaml`) says so and names nothing the user has to guess.

**Terminal: where commands run.** The Terminal detail has a "Where commands run" section. It lists the backends with their label, description, a status chip and, for a backend that is not ready, Hermes' `detail` text under "From Hermes:". The active backend is marked. Choosing a backend that needs setup is allowed (Hermes allows it) and the row says "Commands will fail until this is set up on your server." The app does not offer to edit SSH hosts, Docker or Modal settings.

**Computer use.** The Computer use detail adds a "Readiness" section from `/computer-use/status`: platform supported, driver installed (with Install on server when the toolset's provider offers `post_setup`), permissions (Accessibility, Screen recording) on a macOS server, the `checks` list under "Details", and `error` text when present. "Allow access" (only when `can_grant`, `installed` and a permission is exactly `false`) asks first, starts the grant and follows `/api/actions/computer-use-grant/status`; the result is re-read from `/computer-use/status`. A non-macOS server shows no permission rows. "Open the bot's screen" appears when the profile's Bot Screen reports it is offered (`BotScreenController` state not unsupported), calls `ChatScreen`'s `_openViewer('tools')` through a callback given to the screen (new source slug `tools`), and does nothing else; the viewer, lease and takeover are the Bot Screen's.

**The difference, in words.** One sentence each, shown in a "What's the difference?" sheet (popover on Mac, sheet elsewhere) opened from the Tools screen's footer and from a one-line link in the footers of Skills, Plugins, MCP servers and Helper models:

- Tools: what Hermes can do by itself, such as run commands, search the web or make images. You switch them on or off here.
- Skills: written instructions Hermes follows for a kind of job.
- Plugins: add-ons installed on the server. Some bring their own tools.
- MCP servers: outside programs or services that give Hermes extra tools.

**Hidden on an old server.** `ToolsUnsupported` removes the sidebar action, the drawer entry and the Profiles section; a screen already open on a server that loses the route shows "This server doesn't offer tools settings" with Back, not an error. The Computer use and terminal sections hide when their own routes answer 404/405, independent of the toolsets list. A write refused with `400 Unknown toolset` reads the list again and, when the toolset is gone, shows "That tool is no longer on this server"; a `404` naming a profile shows "This profile no longer exists" and reads the profile list.

**Secrets.** Key values live only in the setup controller's `TextEditingController`s. They are sent once in the `/env` body, then cleared and the controllers' text replaced whatever the outcome, as in `McpInstallController`. They never enter a log, span, breadcrumb, exception text, route argument or `toString`. Fields are obscured with autocorrect, suggestions, keyboard learning and autofill off. The text is also cleared when the app goes to the background or inactive, when App Lock covers the app, on profile switch, sign-out and server change, and the controller is disposed with its screen. Nothing is written to preferences or secure storage. The confirmations and status lines contain no key names or values. The server's `prompt`, `detail` and log lines are shown to the user but never logged; the install log lines, like the Bot Screen's, are shown and not recorded.

**Telemetry.** Spans: `tools.list` (`count`, `outcome`), `tools.toggle` (`toolset` as a slug from the fixed built-in list, else `other`; `enabled`; `outcome`), `tools.setup` (`step`: provider, env, post_setup, model; `outcome`; `keys` as a count), `tools.terminal_backend` (`outcome`), `tools.computer_use` (`action`: status, grant; `outcome`). Logs: `tools.toggled` (`toolset` slug, `enabled`, `outcome`), `tools.setup_outcome` (`step`, `outcome`), `tools.parse_lenient` (`skipped` count). Breadcrumbs: `tools.opened` (`count`), `tools.toggled` (`toolset` slug, `state`), `tools.risk_confirmed` (`toolset` slug, `confirmed`), `tools.setup.step` (`step`). Never profile names, provider names, key names or values, models, URLs, log lines, or Hermes' text. `outcome` is one of ok, refused, failed, unknown, unsupported.

**Accessibility.** Rows and detail follow the settings kit's 44 pt / 48 dp targets and scale to the largest text size by wrapping, never by cutting a sentence. The switch has the label "<toolset>, <state>", status chips carry text and an icon, not colour alone, and the risk sentence is part of the row's semantics. A confirmation announces its title; the install and grant progress is a live region; reduced motion removes the progress animation. The list and detail pane have a defined focus order (list, then detail) and Mac keyboard handling like Plugins.

## Risks / Trade-offs

- **The toggle may not reach a chat that is already open.** The copy says so, and Task 1.1 checks it. If Hermes starts refreshing live sessions on a config change, the sentence becomes shorter.
- **An operator pin or the coding posture can override the list.** The app cannot read either; a toolset can be On and still absent in a chat. Mitigation: the copy says "On for this profile", not "Hermes will have it"; Activity and the chat's own tool cards stay the source of truth. Reported if it shows up in real use.
- **`available` is misleading.** It equals `enabled`; ignoring it is deliberate and pinned by a contract test so a later server that fills it in is noticed.
- **The install action has one shared slot** (`computer-use-grant` has its own). Another client or profile can overwrite the log the app follows, and a switch-started install carries no pid. The app reads `/computer-use/status` or the config again for the result, and treats a log that is not its own as "unknown", never as success.
- **Risk table can go stale.** A new built-in toolset has no confirmation until the table is updated. A check in the real-backend contract test lists the server's catalog and fails when a name appears that the table and the "no risk" list both lack, so a new one gets decided.
- **Server text is shown as written.** `detail`, `prompt`, `tag` and log lines come from Hermes and may mention server paths or settings. They are shown, never logged.

## Migration Plan

No data, no setting and no stored state is added. Rollout is by the server: a server without the routes shows no Tools. The change ships in six PRs (tasks.md). Rolling back removes the entries; nothing else depends on them.

## Open Questions

1. **Does a toggle reach open chats?** Recommendation: assume not, say "next chat", verify in Task 1.1.
2. **Confirm "browser" and "file"?** Recommendation: explain, do not ask; they are the defaults most people expect. Revisit if the owner wants a stricter line.
3. **Sections by state or by kind?** Recommendation: Needs setup, On, Off. The user's question is "what works", not "what category".
4. **Show the tool names of a group?** Recommendation: yes, under "What's inside" in the detail only; they match the names on tool cards in a chat.
5. **Should switching on a toolset that needs setup be blocked?** Recommendation: no, Hermes allows it. The row says "On · needs setup" and the detail opens at the Set up section.
6. **Remove a saved key?** Not possible through the route (blank is skipped). Recommendation: say "To remove a key, edit it on your server" and leave it.
7. **Tools in a chat (`tools.show`).** Recommendation: a follow-up change that adds "Tools in this chat" to the Activity panel; not part of this one.
