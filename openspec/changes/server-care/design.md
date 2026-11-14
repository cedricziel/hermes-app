# Design

## Context

What this design relies on was read in the Hermes source at `d923a5eb` (0.22.2, the revision `openapi/HERMES_REF` pins), at `/home/user/nousresearch/hermes-agent`: the routers `hermes_cli/web_routers/status.py`, `actions.py`, `ops.py`, `analytics.py`, the action spawner in `hermes_cli/web_server_gateway.py` and `web_server.py`, the doctor's output primitives in `hermes_cli/doctor_report.py` and `doctor.py`, the log reader in `hermes_cli/logs.py`, the update receipt in `hermes_cli/update_receipt.py` and `update_contract.py`, the auth gates in `hermes_cli/web_server.py` and `hermes_cli/dashboard_auth/`, and the web dashboard's own System, Logs and Analytics pages (`web/src/pages/SystemPage.tsx`, `LogsPage.tsx`, `AnalyticsPage.tsx`, `web/src/lib/shared-gateway.ts`). Tests read: `tests/hermes_cli/test_web_server.py` (update refusals), `test_dashboard_admin_endpoints.py` (update check), `test_web_analytics_corrupt_store.py` (the 503 store payload).

Two facts shape the whole design and differ from what the roadmap assumed:

1. **"The gateway" is the messaging gateway, not the app's chat.** `/api/ws` is served by the dashboard process (`hermes_cli/web_routers/chat_ws.py` → `tui_gateway.ws.handle_ws`), and `tui_gateway` builds the agent in that process. `hermes gateway` is a separate process that runs the messaging platforms (Telegram, Discord, …) and the cron ticker (`gateway/run.py`, `_cron_tick_profile_homes`). So restarting the gateway does not drop the app's connection and does not stop a reply in this app. It does stop conversations running on messaging channels (the default `agent.restart_drain_timeout` is 0, so they are not drained) and pauses scheduled tasks until it is back. A stuck reply in this app is fixed by Stop, which exists; this change does not pretend a gateway restart fixes it.
2. **Updating restarts the dashboard.** `hermes update` stops and relaunches the dashboard and serve processes it finds (`hermes_cli/update_serve_resume.py`, `update_serve_obligations.py`) and restarts the gateway fleet. The app's REST and socket connections drop, replies in progress in this app stop, and a manually started dashboard may not come back ("Some stopped backends could not be relaunched; restart them manually."). The update child is spawned with `start_new_session`, so it outlives the dashboard, and its outcome is written to a durable receipt that a client should read instead of inferring success from liveness (the route's own docstring, issues #81193, #87359, #91277).

Auth: every route below except `/api/status` and `/api/health` (public, `dashboard_auth/public_paths.py`) needs the dashboard sign-in. In gated mode the app's bearer token sets `request.state.session` (`dashboard_auth/middleware.py`), which also satisfies `_require_token`; in loopback mode the app sends the page token, as it does today. Hermes has no roles: anyone signed in may restart, update and read logs, as in the web dashboard.

Platforms: iOS, iPadOS, Android, macOS, Windows, Linux. Not watchOS. Native change: Android only, `FLAG_SECURE` while the Logs or Server check page is on screen (open question 1). No entitlement, `Info.plist`, manifest or Xcode project change.

## Server surface

Every route is in `openapi/hermes-agent.openapi.json` with its query parameters but **no response schema**, so the generated `DefaultApi` methods exist and return untyped JSON. The repository calls them through `authController.api!.raw` and parses leniently; nothing is hand-written and nothing is regenerated. (`/api/status` is hand-written today in `HermesApiClient.fetchStatus` for the connection probe; this feature reads it again through the generated `getStatusApiStatusGet(profile:)` because it needs `?profile=` and fields the probe model drops.)

### `GET /api/status?profile=` (public; profile optional)

Machine-level probe. With `profile`, gateway identity files are read from that profile's home. Example (fields the app reads; gated bind, so no paths or pids):

```json
{
  "version": "0.22.2",
  "release_date": "2026-11-02",
  "config_version": 31,
  "latest_config_version": 31,
  "can_update_hermes": true,
  "gateway_running": true,
  "gateway_state": "running",
  "gateway_platforms": {
    "telegram": { "state": "connected", "updated_at": "…" }
  },
  "gateway_exit_reason": null,
  "gateway_updated_at": "…",
  "gateway_heartbeat_stale_s": null,
  "gateway_shared_with": ["default", "work"],
  "active_agents": 1,
  "gateway_busy": true,
  "restart_drain_timeout": 0,
  "active_sessions": 2,
  "auth_required": true,
  "components": {
    "gateway": { "status": "ok", "state": "running" },
    "dashboard": {
      "status": "ok",
      "recent_unhandled_errors": 0,
      "last_error_at": null,
      "selftest": "ok"
    },
    "storage": { "status": "ok" },
    "platforms": { "status": "ok", "configured": 1, "connected": 1 }
  },
  "overall": "ok",
  "memory": {
    "pressure": "ok",
    "gateway_rss_mb": 410,
    "system_available_mb": 5120,
    "last_boot_suspected_oom": false
  },
  "disk": { "pressure": "elevated", "free_mb": 1210, "used_percent": 91.2 },
  "profiles": ["default", "work"],
  "gateway_mode": "multiplex"
}
```

`gateway_state` is `running`, `starting`, `degraded`, `draining`, `stopped` or `startup_failed` (a `degraded` with `gateway_running: false` is a watchdog exit). `components.storage.reason: "corrupt"` marks an unreadable session store. `memory` and `disk` are `{"pressure": "unknown"}` when they cannot be read, and absent on older servers. Errors: an unknown `profile` answers 404 from `_resolve_profile_dir`.

### `GET /api/health` (public, no parameters)

`{"ok": true, "version": "0.22.2", "displayVersion": "0.22.2", "commit": "d923a5eb…", "auth_required": true}`. `commit` is the code the process booted from (cached at import), so a changed commit proves the dashboard restarted on new code. Used only to follow an update's restart.

`/api/health/idle` and `/api/host/identity` are token-gated diagnostics for the desktop's backend hand-over ("never a retirement permit"); they say nothing a person can act on and are not used.

### `GET /api/hermes/update/check?force=&profile=`

Cached for 24 h server-side; `force=true` busts the cache (the web dashboard's "Check for updates"). The app does not send `profile` (the update is server-wide). Shapes, from the route and `test_dashboard_admin_endpoints.py`:

```json
{
  "install_method": "git",
  "current_version": "0.22.2",
  "behind": 12,
  "update_available": true,
  "can_apply": true,
  "update_command": "hermes update",
  "message": null,
  "commits": [
    { "sha": "1a2b3c4", "summary": "Fix …", "author": "…", "at": 1762000000 }
  ]
}
```

- `behind`: commits behind; `0` up to date; `-1` unknown count; `null` the check could not run (`message`: "Couldn't reach the update source — try again later.").
- `rollback_to` and a message "This build is newer than stable release v…. Updating moves it back to that release." when applying would move back.
- `can_apply` is true only for `git`. `docker`, `apt`, `nix`, `nixos`, `unknown` carry `message` and/or `update_command`. A desktop-app build answers `install_method: "desktop-app"`; a managed host `install_method: "managed-runtime"` with `update_command: ""` and "Hermes updates are managed outside this dashboard in containerized environments." `commits` (at most 20) only for a git install that is behind.
- `/api/status.can_update_hermes: false` also means managed externally.

### `POST /api/hermes/update` (no parameters)

Spawns `hermes update` detached, with a fresh 32-hex `HERMES_ACTION_ID`. Answers:

- Started: `{"ok": true, "pid": 12345, "name": "hermes-update", "action_id": "<32 hex>"}`.
- Already running: `{"ok": true, "pid": …, "name": "hermes-update", "already_running": true, "action_id": "…"}`.
- Refused (HTTP 200): `{"ok": false, "pid": null, "name": "hermes-update", "error": "<code>", "message": "…", "update_command": "…"}` with `error` one of `commit-build`, `dashboard_update_managed_externally`, `docker_update_unsupported`, `apt_update_required`, `nix_update_unsupported`, `update_not_in_place`.
- Spawn failure: HTTP 500 `{"detail": "Failed to start update…"}`.

### `GET /api/actions/{name}/status?lines=` (`name`: `hermes-update`, `gateway-restart`, `gateway-start`, `doctor`)

`{"name": "doctor", "running": false, "exit_code": 1, "pid": 4321, "lines": ["…"]}`. `lines` is the tail (1 to 2000) of an append-only log for that action name; every run starts with a header `=== <name> started <YYYY-MM-DD HH:MM:SS>[ <action id>] ===`, so a client takes the lines after the last header. The registry is per dashboard process and not per profile. For `hermes-update` it adds `action_id` (the completed run's, from the root `update.log`) and `receipt` (the compact summary below). Unknown name: 404. After the dashboard restarted, the in-memory process handle is gone and `running` is false; `exit_code` then comes from the durable markers or the receipt, or is `null`.

### `GET /api/hermes/update/receipt`

`{"receipt": {…full…}, "summary": {"outcome": "success", "started_at": "…", "finished_at": "…", "action_id": "<32 hex>", "pre_sha": "…", "post_sha": "…", "post_version": "0.23.0", "fleet_states": ["verified"], "followups": [{"step": "…", "reason": "…"}], "user_action": null}}`. `outcome` is `running`, `success`, `partial` (committed, but the user still has to act: `user_action {step, reason}` or `followups`), `failed`, `refused` or `interrupted`. HTTP 404 with `detail` "No update receipt found…" when no update ran since receipts landed. The receipt is root-wide: the app credits it only when `summary.action_id` equals the action id it started.

### `POST /api/gateway/restart?profile=` and `POST /api/gateway/start?profile=`

Restart runs `hermes [-p <profile>] gateway restart`; a live restart child, or one spawned for the same profile within 10 s, is reused (#89034). Answer: `{"ok": true, "pid": 4321, "name": "gateway-restart"}`. HTTP 500 with `detail` when spawning fails, including "gateway restart already in progress for another profile" and the system-service message "…requires root, and passwordless sudo is unavailable for the dashboard user. Run 'sudo hermes gateway restart' on the host…". Start answers the same shape with `name: "gateway-start"`, and HTTP 409 with an explanation when the profile is carried by the shared gateway and has none of its own. Completion rule (the web dashboard and desktop agree): the child exiting 0, or still running when a bounded poll ends (in an install without a service manager the child becomes the gateway and never exits), is success; a non-zero exit is failure, with the action log's tail as the reason. Whether the gateway is really back is then read from `/api/status`.

### `GET /api/logs?file=&lines=&level=&component=&search=&profile=`

`{"file": "agent", "lines": ["2026-11-14 09:12:03,114 INFO [sess_ab12] gateway.run: …", "…"]}`, oldest first. `file`: `agent`, `errors`, `gateway`, `gui`, `desktop`, `update` (unknown → 400). `lines` capped at 500. `level`: minimum level (`DEBUG`, `INFO`, `WARNING`, `ERROR`, `CRITICAL`; `ALL` or empty = none). `component`: `gateway`, `agent`, `tools`, `cli`, `cron`, `gui` (unknown → 400). `search`: case-insensitive substring over the last 2000 lines. A missing file answers `lines: []`. Lines follow `%(asctime)s %(levelname)s%(session_tag)s %(name)s: %(message)s` and pass through Hermes' `RedactingFormatter`, which masks known secret shapes but not message text, paths or personal data.

### `POST /api/ops/doctor?profile=`

Spawns `hermes [-p <profile>] doctor` (no `--fix`) as action `doctor`: `{"ok": true, "pid": …, "name": "doctor"}`; HTTP 500 on spawn failure. Output (plain text when not a TTY; the app strips ANSI escapes anyway):

```text
◆ Configuration
  ✓ config.yaml found
  ⚠ Config version 30 is behind 31 (run 'hermes config migrate')
    → Older keys still work
◆ Messaging
  ✗ Telegram token rejected (401)
────────────────────────────────────────────────────────────
  Found 2 issue(s) to address:

  1. Re-run 'hermes setup telegram'
  2. …
```

or "All checks passed! 🎉". Exit code 0 when there is nothing to address, 1 otherwise. The ASCII banner at the top is skipped.

### `GET /api/analytics/usage?days=&profile=`

`days` 1 to 365 (422 otherwise). Read-only from the profile's `state.db`. Example (model ids replaced by placeholders):

```json
{
  "daily": [{"day": "2026-11-12", "input_tokens": 812000, "output_tokens": 64000,
             "cache_read_tokens": 410000, "reasoning_tokens": 12000,
             "estimated_cost": 1.20, "actual_cost": 0, "sessions": 9, "api_calls": 41}],
  "by_model": [{"model": "<model id>", "input_tokens": 790000, "output_tokens": 60000,
                "estimated_cost": 1.16, "sessions": 8, "api_calls": 38}],
  "by_task": [],
  "totals": {"total_input": 812000, "total_output": 64000, "total_cache_read": 410000,
             "total_reasoning": 12000, "total_estimated_cost": 1.20, "total_actual_cost": 0,
             "total_sessions": 9, "total_api_calls": 41},
  "period_days": 30, "skills": {…}, "tools": {…}
}
```

`day` is the server's local calendar day of each session's start; days without sessions are absent. Costs are US dollars (`estimated_cost_usd`, `actual_cost_usd` columns). `sessions` counts every session: app chats, messaging conversations and scheduled-task runs. An unreadable store answers HTTP 503 with `detail` `{…, "path": "…"}` (`corrupt_store_as_status`); the path is never shown or logged.

### Considered and left for later

| Surface                                                                       | Why not now                                                                                                                                            |
| ----------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `GET /api/system/stats`                                                       | CPU, load, uptime, OS, hostname. `/api/status` already has the disk and memory pressure a person can act on. A "Machine" detail page later.            |
| `POST /api/gateway/stop`, `/api/gateway/drain`, `/api/gateway/migrate[/plan]` | Rare, disruptive, and better done at the server.                                                                                                       |
| `POST /api/ops/security-audit`                                                | Same action pattern as doctor; its output needs its own reading. Second version.                                                                       |
| `POST /api/ops/backup`, `GET /api/ops/backup/download`                        | A backup zip holds every secret of the profile; saving it on a phone needs its own design (where it goes, Files/Share, deletion). Later, deliberately. |
| `GET /api/ops/checkpoints`, `POST …/prune`                                    | Disk reclaim; follows naturally from "Disk almost full" in a later version.                                                                            |
| `POST /api/ops/config-migrate`                                                | When `config_version < latest_config_version`; later, with the doctor's "fix" story.                                                                   |
| `GET /api/analytics/models`                                                   | Provider, cache and capability detail per model.                                                                                                       |
| `GET /api/sessions/stats`, `/api/egress/status`                               | Counts and proxy text with no action attached.                                                                                                         |
| `insights.get`, `machine.facts`, `usage.bars` (gateway)                       | Session counts only; desktop first-run facts; Nous billing bars, already covered by the chat's billing surfaces.                                       |

## Client architecture

All new code lives in `lib/src/server_care/`.

**Repository.** `ServerCareRepository(HermesApiClient api)` wraps the generated calls above and returns sealed results, never throwing to callers:

- `sealed class CareResult<T>`: `CareOk<T>(value)`, `CareUnsupported` (HTTP 404 without the receipt's "No update receipt" detail, 405, or a non-JSON body: the route is missing on this server), `CareFailed(kind, {message})` with `kind` one of `offline` (connection error or timeout), `unauthorized` (401/403 after the auth interceptor gave up), `refused` (4xx with Hermes' `detail`), `server` (5xx), `unreadable` (JSON that cannot be read at all). `message` is Hermes' `detail` when it is a string; shown, never logged.
- Parsers in `server_status.dart`, `update_check.dart`, `update_receipt.dart`, `action_status.dart`, `log_line.dart`, `doctor_report.dart`, `usage_report.dart`: lenient, never throw, missing or ill-typed fields become null or an empty list, unknown enum strings are kept as `other(raw)`.
- `DoctorReport.parse(lines)`: take lines after the last `=== doctor started` header; drop ANSI escapes and the box banner; `◆ <title>` starts a section; `✓`, `⚠`, `✗` start an item (passed, warning, problem) whose text is split from a trailing detail where the server put two spaces (best effort; the whole line is kept otherwise); a `→` line is a note under the previous item; after "Found N issue(s) to address:" numbered lines are fixes; "All checks passed" sets `allPassed`. Anything else is kept as raw text in its section and counted as unknown.
- `LogLine.parse(raw)`: `^(\S+ \S+) (DEBUG|INFO|WARNING|ERROR|CRITICAL)(?: \[[^\]]*\])? (\S+): (.*)$` → time, level, source, message; a line that does not match (a traceback line) is a continuation of the line before it and keeps its raw text.
- `UsageReport.parse(json, days, today)`: fills every missing day of the window with zeros so the chart has one bar per day; sums `input_tokens + output_tokens` as "tokens"; keeps `cache_read_tokens` and `reasoning_tokens` for the totals.

**Controllers.**

- `ServerCareController` (one per connection, provided by `AppShell`): holds the latest `ServerStatus` for the chat's profile and derives `Attention` (below). Reads on Server screen open, on refresh, when the app resumes (at most every 5 minutes otherwise), after a restart or update finishes, and on a profile switch. Feeds the attention mark. Cleared on sign-out and server change.
- `GatewayRestart` (owned by `AppShell`, one at a time): `idle → starting → waiting (child running) → returning (status polled every 2 s until gateway_running and state running/degraded, at most 90 s) → done | failed(reason) | slow (not back after 90 s)`. Polls `/api/actions/gateway-restart|start/status?lines=40` every 1.5 s for at most 30 s. It never resends `POST /api/gateway/restart` or `/start`: when the answer to it is lost (timeout or connection drop), the run moves to `waiting` and reads the action status and `/api/status`; a child that is running now hands over to the usual wait, and the gateway coming back running settles it (for a restart only after it was seen not running, because the old gateway is running at the start), and 90 s after the press without either it ends as `slow`. A bare 502, 503 or 504 on the POST (no `detail`) is a lost answer too. The run is bound to the profile the person confirmed; if the chat's profile changes while the confirmation is open, nothing is sent with Try again, which asks again before sending. **When `done` may be claimed.** For a start: the gateway reads running (state running or degraded). For a restart the old gateway is running when the run starts, so running alone proves nothing: `done` needs the gateway to have been read not running at some point after the press (the status is read beside the action every 1.5 s while the child runs) or the child to have exited 0 (the command itself finished, so a service manager restarted it). A child still running with the old gateway never seen down (the gap between two reads was missed, or the child is a stale one) is not claimed as done: after 90 s it ends `slow` with Try again. A restart without a service manager, where the child becomes the gateway and never exits, is `done` once the gateway was seen down and runs again, and otherwise `slow`; that is the price of not claiming a restart that may not have happened. The action is read beside the gateway until the child ended (at most the 90 s): exit 0 of the run's own child counts as finished, a non-zero exit fails the run with the log's last lines. A lost answer follows the same rule except that only a child this run saw running is adopted (the action may still hold an earlier run's answer), and its exit 0 does not count as proof (the action registry is per dashboard, so the child may belong to another profile's run); its non-zero exit still fails the run, an asymmetry on purpose: a missed failure leaves the person waiting with no reason, while a wrongly attributed one (two profiles acting at once on one dashboard) only shows that dashboard's own log text to the same person. A lost restart is therefore `done` only after the gateway was read not running; if the answer is declared lost late, the down gap has usually passed and the run ends `slow`, which is the price of not claiming a restart that may not have happened. Exit 0 alone can claim `done` before the new gateway rewrote its state when the backend's status is stale; the status carries no pid or start time to check that against During a run the headline reads "Restarting the messaging gateway…" (or Starting) with no button, instead of keeping the sentence it had: with the gateway rows of the Attention table suppressed while busy, the old sentence would be a healthy one that is not true yet.
- `HermesUpdateRun` (owned by `AppShell`, survives leaving the screen; persisted, see "Update run").
- `ServerLogsController` (owned by the Logs page, disposed with it).
- `ServerCheckController` (owned by `AppShell` so a check keeps running when the page is left; result kept in memory until sign-out, server change or profile switch).
- `UsageController` (owned by the Usage page; keeps the last window and metric choice for the app run).

**Attention** (`ServerStatus` → the headline, first match wins):

| Condition                                                                      | Headline                                                   | Action          |
| ------------------------------------------------------------------------------ | ---------------------------------------------------------- | --------------- |
| status read failed (`offline`)                                                 | "Can't reach Hermes"                                       | Try again       |
| `components.storage.reason == corrupt` or storage not ok                       | "Hermes can't read its session store"                      | Run a check     |
| `gateway_state == startup_failed`, or `degraded` with `gateway_running: false` | "The messaging gateway stopped with an error"              | Restart gateway |
| `gateway_heartbeat_stale_s` not null                                           | "The messaging gateway isn't responding"                   | Restart gateway |
| gateway not running and `components.platforms.configured > 0`                  | "The messaging gateway is off"                             | Start gateway   |
| `disk.pressure` `critical`                                                     | "Disk almost full: <free> free"                            | —               |
| `memory.last_boot_suspected_oom`                                               | "Hermes restarted unexpectedly, probably out of memory"    | Show logs       |
| `gateway_state == degraded` (running) or platforms connected < configured      | "<n> of <m> messaging channels are offline"                | Show logs       |
| `memory.pressure` `critical`, `disk.pressure` `elevated`                       | "Memory is low" / "Disk space is getting low: <free> free" | —               |
| otherwise                                                                      | "Everything looks good"                                    | —               |

Only rows above the disk-elevated line count as "needs attention" for the mark on the account button and the Mac sidebar. A stopped gateway with no messaging channels configured is neutral ("Off · Scheduled tasks and messaging channels need it"), not attention (open question 2).

**Update run.** `HermesUpdateRun` phases:

1. `confirming`: the confirmation counts the replies running in this app (from `ChatController`'s replying threads) and `active_agents` from the status.
2. `starting`: read `/api/health` (keep `commit` and `version` as "before"), then `POST /api/hermes/update`. `ok: false` → `refused(message, command)`. `already_running` → adopt its `action_id`. Save `{actionId, startedAt, versionBefore, commitBefore}` in shared preferences under `hermes.server_care.update.v1.<accountKeyFor(server, user)>`.
3. `updating`: poll `/api/actions/hermes-update/status?lines=60` every 2 s; keep the last lines in memory for "Show details". `running: false` with `exit_code` non-zero and no dashboard restart → read the receipt → `failed`. A connection error moves to `restarting`. `running: false` with `exit_code` 0 while `/api/health` still answers with the commit from before (the dashboard was not restarted, or a manually started serve was not relaunched: "Some stopped backends could not be relaunched; restart them manually.", `update_serve_resume.py`) → read the receipt; when it reports `success` or `partial` for this action, the phase is `staleServer`: "Hermes updated, but the server is still running the old version. Restart Hermes on the server to finish." with the version before and the receipt's `post_version`, and Check again (re-reads `/api/health`; a new commit moves to `finished`). The banner is not shown in this phase.
4. `restarting`: poll `/api/health` with backoff (1 s doubling to 10 s) for up to 15 minutes. The thin app banner shows. Only an HTTP 200 whose body is JSON with `ok: true` counts as an answer: a reverse proxy in front of Hermes (Caddy, nginx, Tailscale serve) answers 502, 503 or 504, often with an HTML page, while the backend is down, and those count as still restarting. An answer with a different `commit` (or a different `version`), or any valid answer after the dashboard had been unreachable, moves to `verifying`. Health answering with the same commit while the action status says still running stays in `updating`.
5. `verifying`: `GET /api/hermes/update/receipt`, retried for up to 60 s while `outcome` is `running` or the receipt names another action. Then `finished(outcome)`: `success` ("Hermes is up to date · 0.23.0"), `partial` ("Hermes updated, with one thing left to do", showing `user_action.reason` or each follow-up's reason), `failed`/`interrupted` ("The update didn't finish", with the last log lines behind Show details and the version that is running now), `refused`. A 404 receipt or one that never names this action → `unknown` ("Hermes is back, but the app can't confirm the update. Version now: 0.23.0.").
6. `notBack`: after 15 minutes without an answer: "Hermes hasn't come back yet. If you started it by hand, it may need to be started again on the server." with Keep waiting and Dismiss.

**Time and suspension.** Dart timers stop while iOS suspends the app, so every poll above (update, gateway restart, server check, status) restarts at once when the app resumes instead of waiting for its interval. The 15-minute `restarting` window and the 1-hour resume window are measured in wall-clock time from the saved start time, not by counting polls, so a long suspension lands in `notBack` or a fresh read of the action status and receipt, never in a success the app did not read from the receipt. Only the update survives the app being killed (its record is saved); a gateway restart or a server check in flight when the app is killed is not resumed: on the next launch the status is read as usual and the check page shows no result.

On finish (any phase) the app asks `AuthController` to probe `/api/status` again (the existing connect path that rebuilds the connection's telemetry attributes and re-checks Kanban and Schedules), refreshes `ServerCareController`, and deletes the saved record. On launch, a saved record younger than 1 hour resumes at `updating` (the action status and receipt tell where it is); an older one is read once at `verifying` and then dropped. Sign-out and server change drop the record and stop polling. The run never resends `POST /api/hermes/update`: a lost answer to it is "may have started" and is resolved by reading the action status, which reports `already_running` on a second press anyway.

The banner (`ServerRestartBanner`, under the shell's toolbar, above every destination, not in conversation windows or the quick panel) shows only while `restarting` or `verifying`: "Hermes is restarting after the update. Chats continue when it's back." After `finished(success)` it says "Hermes 0.23.0 is ready" for 6 s (no timeout under reduced motion: stays until dismissed). Tapping it opens the Update page.

**Gateway restart confirmation.** Text built from the status: "Chats in this app keep running." always; "Messaging channels and scheduled tasks pause until it's back." always; "<n> conversations on messaging channels are running now and will stop." when `active_agents > 0`; "This gateway is shared: the bots of <profiles> reconnect too." when `gateway_shared_with` has two or more names (profile names come from the server's own list and are shown, never logged).

**Navigation.**

- iPhone, Android phones: account menu item "Server" between "Connection details" and "About", with a dot and the label "Server · needs attention" when the status says so. The account button's semantics label becomes "Account, server needs attention". The Server screen is a pushed `SettingsScaffold` page; its sub-pages (Update, Logs, Server check, Usage) push on top.
- iPad and wide Android, Windows, Linux: same account menu entry in the sidebar footer. The Server screen at 900 points or wider (700 on iPad) shows the overview list beside the selected sub-page (the Plugins pattern); narrower, sub-pages push.
- macOS: a "Server" destination row in the sidebar after Profiles, with a caption ("Needs attention", "Updating…", "Restarting…", or nothing). Its page uses the Mac toolbar with a Refresh button; sub-pages push inside the destination with Back and ⌘[ (the `SettingsScaffold` rule). No bottom sheets: confirmations are the restrained Mac alert. The menu bar is unchanged in the first version.
- Profile scope: the profile-scoped parts (status's gateway, logs, the check, usage) use the chat's current profile (`ChatProfiles`, never the server's active profile), shown in the subtitle ("work · 2 profiles"). The Usage and Logs pages offer a profile menu when the server has more than one profile. Update and the receipt are server-wide.

**Privacy of logs and check output.**

- Held only in the page's controller (logs) or the shell's check controller (the parsed report), never written to disk, preferences, the surface snapshot, notifications, widgets, Spotlight, Handoff or telemetry. Not added to `Breadcrumbs`.
- Logs are dropped when the Logs page is closed, when App Lock covers the app, on sign-out, server change and profile switch, and are re-read on return. The check report is dropped on App Lock lock, sign-out, server change and profile switch.
- On iOS and Android phones the Logs and Server check pages draw a blank surface while the app is `inactive` or `hidden`, so the app switcher snapshot holds no text (the Bot Screen viewer does the same). On Android the window also gets `FLAG_SECURE` while either page is on screen, which also blocks screenshots there (open question 1). macOS, Windows and Linux take no app-switcher snapshot.
- Text is selectable, so a person can copy a line through the system menu without a warning; that is deliberate (copying one line to look it up is the common case). The warning applies only to "Copy shown lines", which copies everything shown and asks first: "Logs can contain private details, like messages and file paths. Anyone you paste them to can read them."
- Search text is sent to the server in the query and kept only in the field.

**Usage chart.** A vertical bar chart, one bar per day, because each value is a discrete daily sum (a line would suggest continuity between days and hides that a zero day had no use). One series in the accent colour, so nothing depends on telling colours apart; a metric switch (Tokens, Estimated cost) instead of stacking. Y axis: three gridlines with labels in the metric's unit ("400K tokens"; for cost "$0.60", "$1.20", "$1.80", always two decimals); X axis: the first day of each week (7 and 30 days) or month (90 days), dropped entirely at accessibility text sizes. Hover a bar, or press and drag across the chart (the nearest bar is selected), to show its value in a label above the chart; arrow keys move between bars on desktop. The 7- and 30-day windows fit the width, so a bar can be narrower than 44 pt and is reached by dragging, the arrow keys, its semantics node or the table; only the 90-day window scrolls sideways, with 44 pt (48 dp) tap targets, opening at the newest day. Semantics: the chart is one node labelled "Tokens per day, last 30 days. Total 8.4 million. Highest 1.2 million on 5 November." with each bar a child node "12 November: 812 thousand tokens, 9 conversations" in date order; a "Show as table" switch replaces the chart with a list of the same rows. Drawn in-repo with `CustomPaint` (about 200 lines, with tests): the app has no chart library, the chart is one simple form, and a hand-drawn one gives full control of semantics, text scaling and reduced motion (no grow animation then). Open question 4 records the alternative.

Cost is always the estimate (`estimated_cost`), labelled "Estimated cost (USD)", so every bar uses one basis; when `total_actual_cost > 0`, the totals add "Billed: $x". Days are the server's calendar days, said in the footer ("Days follow the server's time zone. Conversations count chats, messaging and scheduled tasks."). By model: a list sorted by tokens, each row "<model> · 7.7M tokens · $10.80 · 98 conversations · 92%" (the 30-day example: 7.7M of 8.4M tokens), with a decorative proportion bar excluded from semantics.

**Failure and empty states** (exact copy in the design brief): every part has loading (skeleton rows with a label for screen readers), empty, offline, unsupported (the part is hidden, and a hidden part is not an error), refused (Hermes' message), and server error (Try again). A 503 on usage says the session store needs repair and offers Run a check.

**Old servers.** Each part is hidden on `CareUnsupported` for its route; the Server screen keeps the parts the server offers, and with none of the optional ones it still shows status and the version. Missing `components`, `memory`, `disk`, `gateway_shared_with`, `commits` or `receipt` fields are treated as unknown, not as problems. `server_care.unsupported` is logged once per part per connection.

**Visual design.** The Claude Design canvas is https://claude.ai/artifact/7AKZUSYGPHvvmU97dAWrAx (Hermes App design system). Its decisions, the brief's corrections and the added copy are in `docs/design-briefs/server-care.md` under "Design (done)"; that section wins over older wording in the brief. The decisions settled there: an available update is not attention; the 30-day chart fits a phone and is picked by press and drag, only 90 days scrolls; gridlines 400K / 800K / 1.2M with one consistent set of example numbers; "Server" sits after "Connection details" and before "About"; a row value wider than half the row moves to the subtitle.

## Invariants touched

- API layering: all calls go through the generated client; no hand-rolled Dio call, no regeneration (every route is already in the spec).
- Auth: a 401 during the update's restart must not sign the user out: `/api/health` is public, and the update run makes no authenticated call while `restarting`. Concurrent 401s after the restart go through the existing refresh path. Whether the bearer session survives the dashboard restart is checked on a device (task 7.3); if it does not, the user lands on sign-in, which is the existing expiry path, and the saved update record is read after sign-in.
- Loopback mode (no sign-in): the page token (`X-Hermes-Session-Token`) is minted per dashboard process, so it changes when the update restarts the dashboard. The first authenticated call after the restart (the receipt read) gets a 401, and the existing page-token interceptor (`lib/src/auth/page_token.dart`) re-reads the token once and retries. The update run treats that retry as normal, and a second 401 as `unauthorized`, not as a failed update.
- Telemetry never breaks the app and never carries user content (below).
- Tests run the real generated client against `FakeHermesServer`.

## Observability

Spans carry the connection's `hermes.*` attributes. None of the attributes below holds text, a version string the user did not see in telemetry already, a profile, a model id, a command, an action id, a URL or a path.

| Signal                                                                                                                                                                                     | Where                                    | Attributes                                                                                                                                                                                                             |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ---------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| span `server_care.status.fetch`                                                                                                                                                            | `ServerCareRepository.status`            | `outcome` (ok, unsupported, offline, refused, server, unreadable), `attention` (the headline's slug: none, offline, storage, gateway_failed, gateway_stale, gateway_off, disk, oom, channels, memory)                  |
| span `server_care.update.check`                                                                                                                                                            | `ServerCareRepository.checkUpdate`       | `outcome`, `forced`, `update_available`, `can_apply`, `install_method` (git, docker, apt, nix, nixos, desktop_app, managed_runtime, unknown, other)                                                                    |
| span `server_care.update`                                                                                                                                                                  | `HermesUpdateRun`, from start to finish  | `outcome` (success, partial, stale_server, failed, interrupted, refused, unknown, not_back, cancelled), `phase_reached`, `came_back` (bool), `duration` bucket (<1m, 1-3m, 3-10m, >10m), `resumed_after_launch` (bool) |
| span `server_care.gateway`                                                                                                                                                                 | `GatewayRestart`                         | `verb` (restart, start), `outcome` (back, failed, slow, refused), `shared` (bool), `duration` bucket                                                                                                                   |
| span `server_care.logs.fetch`                                                                                                                                                              | `ServerCareRepository.logs`              | `file` (agent, errors, gateway), `level` (all, warning, error), `filtered` (bool: a search was sent), `lines` bucket (0, 1-50, 51-200, >200), `outcome`                                                                |
| span `server_care.check`                                                                                                                                                                   | `ServerCheckController`                  | `outcome` (done, failed, timeout), `problems`, `warnings`, `unknown_lines` (counts)                                                                                                                                    |
| span `server_care.usage.fetch`                                                                                                                                                             | `ServerCareRepository.usage`             | `days` (7, 30, 90), `outcome` (ok, empty, store_unreadable, …)                                                                                                                                                         |
| log `server_care.update_finished`                                                                                                                                                          | `HermesUpdateRun`                        | `outcome`, `came_back`, `duration` bucket                                                                                                                                                                              |
| log `server_care.gateway_finished`                                                                                                                                                         | `GatewayRestart`                         | `verb`, `outcome`                                                                                                                                                                                                      |
| log `server_care.check_finished`                                                                                                                                                           | `ServerCheckController`                  | `problems`, `warnings`, `outcome`                                                                                                                                                                                      |
| log `server_care.unsupported`                                                                                                                                                              | repository, once per part per connection | `part` (status, update, gateway, logs, check, usage)                                                                                                                                                                   |
| breadcrumb `server_care.opened`                                                                                                                                                            | Server screen                            | `source` (menu, sidebar, banner, attention)                                                                                                                                                                            |
| breadcrumbs `server_care.update.confirmed`, `server_care.gateway.confirmed` (`verb`), `server_care.logs.opened` (`file`), `server_care.check.started`, `server_care.usage.opened` (`days`) | the pages                                | as listed                                                                                                                                                                                                              |

## Decisions and alternatives

- **One Server screen, not a new main tab.** Server care is occasional work; a tab would crowd Chat, Bots, Kanban and Schedules. The attention mark on the account button brings the person there when it matters.
- **Connection details stays.** Folding it into Server would change the `macos-menu-bar`, `ipad-keyboard-commands` and `chat` specs for little gain; Server links to it at the bottom instead. A later change can merge them.
- **No gateway Stop.** A phone user who wants the bots silent can stop them per channel in Messaging.
- **Polling, not events.** Hermes has no event for action progress or gateway state on `/api/ws`; the web dashboard polls too.
- **Update follows the receipt, not liveness.** Hermes' own guidance after three incidents.

## Risks / Trade-offs

- [The dashboard does not come back after an update, for example when started by hand] → `notBack` says so plainly after 15 minutes and keeps the record; nothing else in the app can fix it.
- [The bearer session does not survive the restart] → the existing expiry path; the update record is keyed by account and read after sign-in.
- [Another client runs doctor or restart at the same time; the action log is per dashboard, not per profile] → the check reads after the last header and may show the other run's output; acceptable and rare.
- [Logs show secrets Hermes' redaction missed] → the privacy rules above, and the copy confirmation.
- [Polling during restart costs requests] → `/api/health` is the lightest route; backoff to 10 s; stops at 15 minutes.
- [Restart children on a system service need passwordless sudo] → Hermes' 500 message is shown as is; it names the command to run on the host.

## Migration Plan

None. One shared-preferences key per account for a running update, deleted when the update is resolved, on sign-out and on server change.

## Open questions

1. **How to set Android `FLAG_SECURE`.** Recommendation: per the Dependencies rule, check pub.dev first (`screen_protector`, `no_screenshot` and similar: maintenance, publisher, open issues); if none is mature, add one method `setSecure(bool)` to the app's existing Android method channel in `MainActivity`. Either way, set it only while the Logs or Server check page is on screen.
   **Decided.** The app's own method channel `hermes_app/secure_window` (`setSecure(bool)` in `MainActivity`), held by reference count in `SecureWindow`. `screen_protector` (1.5.3, verified publisher inteniquetic.com, Android and iOS, 326 likes) and `no_screenshot` (2.0.1, verified publisher flutterplaza.com, six platforms, 297 likes) are both maintained, but each brings native code on iOS and its own Android lifecycle handling for a change that is one `addFlags`/`clearFlags` call; the design promises an Android-only native change, and neither documents that it uses plain `FLAG_SECURE`. On iOS nothing native is added: the page is replaced by a blank surface while the app is inactive or hidden.
2. **Is a stopped gateway a problem when no messaging channel is configured?** Scheduled tasks also need it. Recommendation: neutral "Off" with the explanation and Start gateway, not an attention mark, unless channels are configured; revisit if the app learns whether cron jobs exist (the Schedules tab already knows; a later version can count enabled jobs).
3. **Should a finished update notify when the app is in the background?** Recommendation: not in the first version; iOS suspends the app long before an update finishes, so only Android and the Mac could do it, and the banner and the Server row say it on return.
4. **Chart library or in-repo chart?** Recommendation: in-repo `CustomPaint`, as above. If later versions need line, stacked or interactive range charts, evaluate `fl_chart` then.
5. **Default log file.** Recommendation: Errors first (short, and what a person in trouble wants), with Agent and Gateway one tap away.
6. **Ask before every gateway restart?** Recommendation: yes. It stops messaging conversations without draining (Hermes' default drain timeout is 0), so a one-tap restart is too easy to regret.
