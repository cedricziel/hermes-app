# Proposal

## Why

A person who runs their own Hermes has no way to look after it from the app. When the bots on Telegram go quiet, a scheduled task never runs, or the disk fills up, the app shows nothing: the server version sits in Connection details and that is all. To find out what is wrong, update Hermes, or restart the messaging gateway, they have to reach a computer and open the web dashboard or a terminal. Hermes already exposes everything needed for the common cases over the dashboard's REST API, so the app can offer one place, **Server**, to see whether the server is healthy and fix the usual problems from a phone.

Roadmap item 4.7.

## What Changes

A new **Server** screen, reached from the account menu (iPhone, iPad, Android, Windows, Linux) and from a **Server** row in the Mac sidebar, with six parts:

- **Status.** One sentence at the top says whether the server is fine ("Everything looks good") or what needs attention ("The messaging gateway is off", "Disk almost full: 1.2 GB free", "Hermes can't read its session store"), with the one action that fixes it when there is one. Below: the Hermes version and release date, the messaging gateway's state and how many channels are connected, disk and memory pressure, and the session store. Read from `GET /api/status?profile=`. The account button (and the Mac sidebar row) shows a small "needs attention" mark when the server has a problem, so the screen is not buried.
- **Updates.** "Up to date" or "Update available · 12 changes" from `GET /api/hermes/update/check`, with the change list, **Update Hermes**, and, on installs the dashboard cannot update (Docker, Nix, APT, desktop app, managed hosting), Hermes' own guidance and the command to copy. Updating asks first, says that Hermes restarts and replies in progress stop, then follows the update through `POST /api/hermes/update`, `GET /api/actions/hermes-update/status`, the restart (`GET /api/health` until it answers from the new build) and the update receipt (`GET /api/hermes/update/receipt`). Progress lives above the screen: it survives leaving the screen and app restarts, and a thin banner across the app says "Hermes is restarting. Chats continue when it's back." while the server is down.
- **Messaging gateway.** **Restart gateway** (or **Start gateway** when it is off) through `POST /api/gateway/restart|start?profile=`, with an honest confirmation: chats in this app keep running; messaging channels and scheduled tasks pause; on a shared gateway, every listed profile's bots reconnect. Progress is shown in the row until the gateway reports running again.
- **Logs.** The last 200 lines (up to 500) of the Agent, Errors or Gateway log from `GET /api/logs`, newest first, with a level filter (All, Warnings and errors, Errors) and a search. Log text is shown only while the page is on screen: never cached, never logged, hidden in the app switcher and under App Lock.
- **Server check.** Runs Hermes' doctor (`POST /api/ops/doctor?profile=`, then `GET /api/actions/doctor/status`) and shows the result as problems, warnings and passed checks, with Hermes' own list of things to fix.
- **Usage.** Tokens or estimated cost per day for the last 7, 30 or 90 days as a bar chart with a table alternative, and a per-model breakdown, from `GET /api/analytics/usage?days=&profile=`.

Each part hides itself when the server does not offer its route (404), without an error.

Delivery: five PRs in order (see tasks.md):

1. `feat(server-care): read server status, updates, logs, checks and usage` (repository, parsers, fixtures, contract test; no UI).
2. `feat(server-care): add the Server screen with status, updates and usage` (catalog first, then the screen and its navigation entries).
3. `feat(server-care): restart and start the messaging gateway`.
4. `feat(server-care): update Hermes from the app`.
5. `feat(server-care): read logs and run the server check`.

## Non-goals

- Restarting the dashboard itself. Hermes has no route for it that a remote client may use (`/api/health/retirement` is the desktop's token-gated hand-over), and the app's chats run in the dashboard process, so "restart" here always means the messaging gateway.
- Stopping the gateway, draining it (`/api/gateway/drain`), migrating to one shared gateway (`/api/gateway/migrate`). Rare, and a phone is the wrong place for them.
- `hermes doctor --fix`. The dashboard route runs the read-only check only.
- Security audit (`/api/ops/security-audit`), backups and their download (`/api/ops/backup`), import, checkpoints and their pruning, hooks, debug share, prompt-size and dump. Later versions (see design.md, "Later").
- Host details from `GET /api/system/stats` (CPU, uptime, OS) and `GET /api/sessions/stats`. `/api/status` already carries the disk and memory pressure the first version needs.
- Per-model analytics with provider and capabilities (`/api/analytics/models`), skill and tool usage, auxiliary task cost.
- Nous subscription and top-up bars (`usage.bars`), which the chat's billing surfaces already cover; `insights.get` and `machine.facts` (desktop first-run facts).
- A live-tailing log view, log download or share, the Desktop and GUI logs.
- Notifications about server health or a finished update while the app is closed. Hermes has no push channel, and a background run would need to poll the server for it.
- Role checks. Hermes has no roles: anyone signed in to the dashboard may do all of this, as in the web dashboard.

## Capabilities

### New Capabilities

- `server-care`: the Server screen, its entry points and attention mark, server status, update check and update run, gateway restart and start, logs, the server check, usage, and how each part behaves on an old server, under App Lock, on sign-out and on a profile switch.

### Modified Capabilities

None. The Server entries are new rows beside the existing ones; Connection details keeps its place and its menu command.

## Impact

- Code: new `lib/src/server_care/` (repository on the generated client, lenient parsers for status, update check, receipt, action status, logs, doctor output and usage; `ServerCareController` for status and attention; `GatewayRestart` and `HermesUpdateRun` owned by `AppShell`; `ServerLogsController`, `ServerCheckController`, `UsageController`), plain-model widgets in `lib/src/server_care/widgets/`, Widgetbook use cases in `widgetbook/server_care_use_cases.dart`, the account menu (`thread_sidebar.dart`), the Mac sidebar destination (`app_shell.dart`, `mac_source_list.dart`), and a shell-level restart banner.
- Backend: no new route. Every route is in `openapi/hermes-agent.openapi.json` without a response schema, so the generated methods return untyped JSON that the repository parses leniently. No regeneration needed. Verified against Hermes `d923a5eb` (0.22.2, the revision `openapi/HERMES_REF` pins).
- Native: Android sets `FLAG_SECURE` while the Logs or Server check page is on screen (see design.md, open question 1, for plugin or channel). No iOS, macOS, Windows or Linux project change.
- Dependencies: none planned. The bar chart is drawn in-repo (design.md explains why).
- Security and privacy: logs and doctor output can hold file paths, host names, message excerpts and anything a tool printed. They are held in memory only while their page needs them, never written to disk, preferences, telemetry, notifications, widgets or the surface snapshot, blanked when the app leaves the foreground on a phone, protected from Android screenshots and the recents thumbnail, and dropped on App Lock, sign-out, server change and profile switch. Copying all shown log lines asks first. The update's action id and start time are kept in shared preferences under the account key (no secret) so a running update can be followed after an app restart. No token handling changes.
- Observability: spans `server_care.status.fetch`, `server_care.update.check`, `server_care.update`, `server_care.gateway`, `server_care.logs.fetch`, `server_care.check`, `server_care.usage.fetch` for work that crosses the network; log events `server_care.update_finished`, `server_care.gateway_finished`, `server_care.check_finished` and `server_care.unsupported` for outcomes worth counting; breadcrumbs `server_care.opened`, `server_care.update.confirmed`, `server_care.gateway.confirmed`, `server_care.logs.opened`, `server_care.check.started`, `server_care.usage.opened` for user steps before a crash. Fixed names, enums, counts and buckets only: never log lines, search text, doctor output, commands, profile names, model names, action ids or URLs.
