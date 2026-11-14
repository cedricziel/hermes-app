# Proposal

## Why

Hermes groups what the agent can do into toolsets: terminal, files, web, browser, computer use, image generation, speech and so on. Each one is on or off per profile, and some need setup first (a search provider, an API key, a terminal backend, a driver installed on the server). The app shows tool calls in a chat, but nowhere can the user see which tools a profile has, why one is unavailable, or switch one on. A user who asks "search the web" and gets "that tool isn't available" has to leave the app and edit the server.

The same screens exist for Skills, Plugins, MCP servers and Helper models. Tools are the missing fifth, and they are the one that decides whether the agent may run commands or control a computer, so the app should be the place where that is shown plainly and chosen on purpose.

## What Changes

- A **Tools** screen per profile, reached from the chat sidebar next to MCP servers (phone and tablet), and from a Tools section on the Mac Profiles page. It uses `SettingsScaffold` and `GroupedListView` like Skills, Plugins, MCP servers and Helper models.
- The list is grouped Needs setup, On, Off. Each row has a plain name, one sentence about what it lets Hermes do, a switch, and a state ("5 tools", "On · needs setup").
- Switching a toolset on or off writes the profile's tool list. Switching on **Terminal**, **Code execution** or **Computer use** first says what it lets the agent do and asks. Switching off never asks. The result is checked by reading the list again; a lost answer is "may have happened" and is never resent.
- A detail (a pane from 900 pt, a pushed page below) with what the toolset lets Hermes do, its state, a **Set up** section when it needs one, where it applies, and the tools it holds.
- **Set up**, for the toolsets that have a provider matrix (web, browser, image and video generation, speech, vision and others): pick a provider, add its keys, run the provider's install step on the server when it has one, and pick a model for image and video generation. Keys follow the MCP install panel: masked, only in screen state, cleared after the request, never logged.
- **Where commands run** for Terminal: the terminal backends with Hermes' own health probe (ready, needs setup, unavailable), and a choice between them. Choosing Local asks first.
- **Computer use** shows Hermes' readiness for it (driver installed, macOS permissions) and, on a macOS server, "Allow access", which starts Hermes' permission grant. The Bot Screen stays where it is; Computer use links to it when the profile has one.
- A short "What's the difference?" explanation of tools, skills, plugins and MCP servers on the Tools screen, and the same one-line link added to the footers of the four sibling screens.
- A server without `/api/tools/toolsets` has no Tools row, and no error.

Not in this change:

- Per-chat tool changes (`tools.configure`, `tools.list`, `tools.show`, `toolsets.list` act on a live session and are left alone; see design.md).
- Individual tool switches inside a toolset, and the MCP "server:tool" toggles. Skills, plugins and MCP servers keep their own screens.
- Toolsets of other chat platforms as a general editor. A toolset that Hermes ties to another platform (for example Discord) is listed and switched like the others, and the screen says which chats it applies to; no per-platform matrix.
- Editing `config.yaml`, SSH hosts, Docker settings or any server file. When a backend needs those, the app shows Hermes' own hint and nothing more.
- Signing in to Nous Portal, Codex or xAI for a managed provider. Hermes' dashboard has no inline login for them either; the app says it needs a sign-in on the server.
- Rebuilding the Bot Screen. Computer use links to it.
- Any change to Hermes.

## Capabilities

### New Capabilities

- `toolsets`: the Tools screen, its availability on a server, the list and detail, switching toolsets, the safety confirmations, the explanation, navigation, profile scope, App Lock and sign-out.
- `toolset-setup`: provider choice, keys, install steps, models, terminal backends and Computer use readiness and permission.

### Modified Capabilities

None. The cross-links on Skills, Plugins, MCP servers and Helper models are specified as requirements of `toolsets`.

## Impact

- Code: new `lib/src/tools/` (repository over the generated `authController.api!.raw` client with lenient parsing, controllers, screens), plain-model widgets in `lib/src/tools/widgets/`, one sidebar action and drawer entry (`chat_screen_layout.dart`, `thread_sidebar.dart`), a section on `mac_profiles_page.dart`, a footer line on the four sibling screens, Widgetbook use cases, a contract-test group.
- Backend: no new route and no server change. REST: `GET/PUT /api/tools/toolsets…`, `/api/tools/terminal/…`, `/api/tools/computer-use/…`, and `GET /api/actions/{name}/status` for the two long steps. All of them are in the pinned OpenAPI file, so the generated client is used; only the untyped answers are parsed by hand.
- Delivery: five PRs (see tasks.md).
- Security and privacy: API keys typed here reach the server once and live nowhere else. Switching on a command or computer-control toolset is confirmed. Setup text from Hermes is shown but never logged. See design.md "Secrets".
- Observability: spans `tools.list`, `tools.toggle`, `tools.setup`, `tools.terminal_backend`, `tools.computer_use`; log events `tools.toggled`, `tools.setup_outcome`, `tools.parse_lenient`; breadcrumbs `tools.opened`, `tools.toggled`, `tools.risk_confirmed`, `tools.setup.step`. Counts, outcomes and a fixed list of built-in toolset slugs only; never profile names, provider names, key names, values, server text or URLs.
