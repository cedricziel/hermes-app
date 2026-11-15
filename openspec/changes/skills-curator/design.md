# Design

## Context

Read in the Hermes source at `d923a5eb` (`openapi/HERMES_REF`, `/tmp/h/hermes-agent`): `hermes_cli/web_routers/status.py` (curator routes), `web_routers/_common.py` (`destructive_profile`, `config_scoped_to_thread`), `web_server_gateway.py` (`_spawn_hermes_action`, `_ACTION_LOG_FILES`), `web_routers/actions.py` (action status), `agent/curator.py`, `agent/curator_backup.py`, `tools/skill_usage.py`, `hermes_cli/curator.py`, `gateway/run.py`. The routes were then run against a throwaway Hermes at the same revision (task 2.1, answers in `test/skills/curator_fixtures.dart`); where that differs from the reading, the text below says "Recorded".

Platforms: iOS, iPadOS, Android, macOS, Windows, Linux. Not watchOS. No native, entitlement or manifest change. Auth: all routes need the dashboard sign-in; Hermes has no roles.

Invariants touched: explicit `profile`; generated client only; a lost answer is never "done"; privacy rules.

## Server surface

No route has a response schema; the generated methods return untyped JSON.

### `GET /api/curator?profile=` (`status.py::get_curator_status`)

Returns exactly: `enabled` (bool, default true), `paused` (bool), `interval_hours` (int, default 168), `last_run_at` (ISO string or null), `min_idle_hours`, `stale_after_days` (default 14), `archive_after_days` (default 30). Each field is read with `_safe_call` and is null on failure. Recorded: all seven fields come back; `last_run_at` is an ISO time with microseconds and an offset (`2026-11-15T03:37:52.300226+00:00`), `min_idle_hours` is a float (`2.0`), and an unnamed or blank `profile` answers for the dashboard's own profile. There is **no** summary, report path, run count, next-run time or counts: those live in `.curator_state` (`curator.py::load_state`) but the route drops them. "Next run" can only be estimated as `last_run_at + interval_hours` when not paused, and the scheduler also needs the gateway (below), so the app does not show it. 500 `"Curator unavailable: <exc>"` on GET if the module fails to import. Recorded (the import forced to fail): the same PUT answers 500 with a plain-text body `Internal Server Error`, not a JSON detail, and a run still starts, since it only spawns a child. Unknown profile: `_config_profile_scope` calls `_resolve_profile_dir`: 400 for an invalid name, 404 `"Profile '<n>' does not exist."` (recorded on GET and PUT; both details echo the name, so the app reads only the status and the `Profile '` prefix and shows no server text).

**A 404 is ambiguous.** On GET and PUT, a 404 whose detail starts `Profile '` means the profile is gone; a 404 with `No such API endpoint: /api/...` (or `{"error":...}` when headless) means the server has no curator route; a PUT or POST to a missing route can be 405, because the SPA catch-all handles GET only. Only the route-missing cases hide the section; a missing profile shows "This profile no longer exists" and reloads the profile list; 400 on an invalid name shows a generic error; 500 "Curator unavailable" shows "The server's curator could not load" with Try again.

### `PUT /api/curator/paused?profile=` (`status.py::set_curator_paused`)

Body `CuratorPause {paused: bool}` (`web_models.py`); a missing or non-bool body is FastAPI's 422. Writes `skills/.curator_state` for the profile and answers `{"ok": true, "paused": <bool>}`. Recorded: a body without `paused` is 422, but `"paused": "yes"` is coerced to true, so the app reads the `paused` the answer carries and never assumes the one it sent. The profile is optional here (not a destructive route).

### `POST /api/curator/run?profile=` (`status.py::run_curator`)

Calls `destructive_profile`: an omitted profile is accepted only on a single-profile backend, otherwise 400 `"POST /api/curator/run requires an explicit profile: this backend serves several profiles, so an unnamed target would act on the wrong profile's data."` Then `_spawn_action(["curator","run"], "curator-run", ...)` spawns `hermes -p <profile> curator run` detached and answers `{"ok": true, "pid": <int>, "name": "curator-run"}`. A bad or deleted profile is **500**, not 404: `_spawn_action` wraps `_profile_cli_args` in `try/except Exception`, so its HTTPException becomes `"Failed to run curator: 404: Profile 'x' does not exist."`; a spawn failure has the same 500 shape. Recorded: an invalid name is also 500, `Failed to run curator: 400: '<n>' is not a valid profile name...`, which the app reads as refused with nothing started; a deleted profile is `Failed to run curator: 404: Profile '<n>' does not exist.`; a spawn failure (forced by making the action log path a directory) is `Failed to run curator: [Errno 21] Is a directory: '<server path>'`, so its text holds a server path and is never shown. A 500 that does not start with `Failed to run curator: ` (a proxy's, a crash) or a 502 to 504 may have followed the spawn, so it reads as a lost answer. The app tells them apart by the `404: Profile '` text inside the detail (profile gone) versus anything else (spawn failure). Nothing guards a second run: each POST starts a new process and replaces the tracked handle, and `_cmd_run` takes no run claim (only the scheduled path does, `curator.py::_claim_run`).

### `GET /api/actions/curator-run/status?lines=` (`actions.py::get_action_status`)

`curator-run` is in `_ACTION_LOG_FILES`, so it shares the shape server-care documents: `{"name","running","exit_code","pid","lines"}`; `lines` is the tail (1 to 2000, default 200; the app asks for `lines=2000` so the `=== curator-run started` header is still inside the tail of a long run) of one append-only log `action-curator-run.log`, each run starting with an empty line and `=== curator-run started <time> ===`. Recorded: the time is `YYYY-MM-DD HH:MM:SS` in the server's local time with no zone and no action id; right after the POST the tail is just `["", header]` with `running: true`; the exit code is 0 or 1; after a dashboard restart the lines stay, `running` is false and `exit_code` and `pid` are null; the log is shared, so another profile's status shows the earlier runs above the latest header; a `lines` of 0 or 2001 is clamped, not refused. The log is per dashboard, not per profile. The log is a file, so it survives a dashboard restart; the process handle does not (then `exit_code` may be null). The app reuses `ActionStatus` and `CareAction` from `lib/src/server_care/` and adds only the `curator-run` name; it does not copy the poller.

### What a run does (`hermes_cli/curator.py::_cmd_run`, `agent/curator.py::run_curator_review`)

The child runs synchronously with no flags: so no dry run and no `--consolidate`. It prints `curator: running review pass...` and exits 1 with `curator: disabled via config` when `curator.enabled` is false. Recorded: a disabled pass prints only `curator: disabled via config; enable with `curator.enabled: true`` (no "running review pass" line), exits 1 and leaves `last_run_at` alone; a pass that runs ignores `paused` (it ran on a paused profile, which stayed paused) and sets `last_run_at`. Otherwise:

1. **Prune** (`apply_automatic_transitions`): for skills recorded as `created_by: agent`, by last activity: past `stale_after_days` becomes stale; past `archive_after_days` is moved into `skills/.archive/` (`skill_usage.archive_skill`). That marker is set when the agent creates a skill and by `hermes curator adopt`, so it can sit on a skill a person wrote. With `curator.prune_builtins` true (default false) bundled skills are managed too (`skill_usage.curated_report`). Pinned skills, skills used by a cron job and hub-installed skills are skipped. Never deleted ("never delete, only archive", module docstring).
2. **Consolidate**, only when config `curator.consolidate` is true (default false): a forked agent on the helper model may pin, archive, merge and **rewrite** skills with `skill_manage`, after a whole-tree snapshot (`curator_backup.snapshot_skills`, reason `pre-curator-run`). It may also rewrite scheduled-task skill references (`_rewrite_cron_refs`).
3. Recorded output of a prune-only pass (the dash in the second line is an em dash): `curator: running review pass...`, `curator: consolidation is off — running prune-only (deterministic stale/archive). Pass --consolidate or set `curator.consolidate: true` to enable the LLM merge pass.`, `curator: auto: 1 marked stale, 1 archived; llm: skipped (consolidation off)` (or `no changes`) and `auto: checked=2 stale=1 archived=1 reactivated=0`. So an `archived=N` line exists, with the prune step's count only. With `curator.consolidate: true` the "consolidation is off" line is gone and `curator: snapshot created (<stamp>Z)` is printed, even when `llm: skipped (no candidates)`. An agent-made skill 100 days idle went to `skills/.archive/` and one 20 days idle only went stale. Then it writes `logs/curator/<stamp>/REPORT.md` and `run.json` and sets `last_report_path` in the state. **No route serves these files**: `GET /api/logs` reads only the names in `hermes_cli/logs.py::LOG_FILES`, which has no curator report. `--dry-run` skips transitions and asks the fork for a report only, but only the command line passes it.

Undo: archives are recoverable only with `hermes curator restore <skill>`, single steps with `hermes curator rollback <ledger id>`, and snapshots with `hermes curator rollback` (`hermes_cli/curator.py::_cmd_restore`, `_cmd_rollback`). No REST route exposes restore, rollback, list-archived or the ledger (grep of `hermes_cli/web_routers/` and `web_server*.py`).

### Gateway and scheduling

Scheduled passes go through `maybe_run_curator`, gated by `should_run_now` (enabled, not paused, `last_run_at` older than `interval_hours`; the first observation only seeds `last_run_at`). Three callers: the messaging gateway's housekeeping tick (`gateway/run.py::_housekeeping_curator`, every 60 s, per served profile), the CLI at session start, and the dashboard itself: `web_server.py`'s lifespan starts `_auto_archive_ticker_loop` (`web_server_sessions.py`), hourly after a 90 s delay, whose `_maybe_run_skill_maintenance` runs `maybe_run_curator` for the dashboard's own profile when no gateway is running for it, no chat is running and the chat has been idle for `min_idle_hours`. So a scheduled pass can start without the gateway and without the app, and for a profile other than the one the Skills screen shows only if that profile has a gateway. `hermes curator run` ignores `paused` (`_cmd_run` never reads it), hence "Run now still works".

## Client architecture

- `lib/src/skills/curator/curator_status.dart`: `CuratorStatus.parse(Object?)`, never throws.
- `lib/src/skills/curator/hermes_curator_repository.dart`: three methods through `authController.api!.raw`; a call answers a result type, never throws. Run and pause are never retried.
- `lib/src/skills/curator/curator_controller.dart`: state per profile (idle, running, finished, failed, unknown); polls `curator-run` status every 2 s, backs off to 5 s, stops after 15 minutes ("Still running on the server" with Check status); one run at a time.
- `lib/src/skills/widgets/`: `CuratorSection` and `CuratorRunConfirmation`, plain models and callbacks, Widgetbook first. The run progress is the extended `GroupedActionRow` inside the section, not a widget of its own.
- The confirmation reads `curator.consolidate` and `curator.prune_builtins` from `GET /api/config?profile=` (already used by the memory and MCP repositories), leniently (recorded: a top-level `curator` map with booleans `consolidate` and `prune_builtins`); unreadable means the "may also merge and rewrite" and "may include bundled skills" wording.
- Entry: a section at the top of the installed-skills list in `SkillsScreen` (`lib/src/skills/skills_screen.dart`), for the profile it shows. No new screen, no new route.

## Observability

| Signal | Where | Attributes |
| --- | --- | --- |
| span `skills_curator.run` | `CuratorController`, POST to end | `outcome` (done, failed, unknown, timed_out), `trigger_lost` |
| log `skills_curator.run_finished` | `CuratorController` | `outcome`, `archived` (the number parsed from Hermes' `archived=N` line; absent when no such line is found) |
| breadcrumb `skills_curator.run.confirmed` | confirmation | none |
| breadcrumb `skills_curator.paused` | switch | `paused` |

Spans carry the connection's `hermes.*` attributes. None holds a skill name, output line, profile or action id.

## Decisions and alternatives

- **Section on Skills, not a screen.** It has a status line and two actions.
- **Confirmation copy is hedged, not absolute.** It says "skills recorded as agent-made" and never "never touches bundled skills": it names bundled skills only as skipped unless the server's `curator.prune_builtins` is on, which the app reads with `curator.consolidate`.
- **Run needs a confirmation with Cancel default, pause does not.** A pass moves files on the server and the app has no undo; pause is one switch back.
- **No next-run time and no report.** The route returns neither; guessing would mislead. Output lines are shown only for a run this app started, because the log is shared by all profiles.
- **Run never offered when `enabled` is false:** the child would only exit 1.
- **No dry run.** Not reachable through the route.

## Design pass

Status: Design (done): canvas published, local render reviewed.

The brief is `docs/design-briefs/skills-curator.md`; the design record is written, the canvas is published and its local render was reviewed. The canvas is https://claude.ai/artifact/Bo238NP1GGXUdeDW888tLJ (private; ask its owner for access). It holds 19 boards and one parametric page, in these rows: the section (4 boards: idle, never run / paused / off in config / unknown fields, loading / refreshing / pass already running, status read fails); the pause switch (1); the run confirmation (2: three wordings on the phone sheet, Android / largest text / dark); Run now (2: running / progress lost / still running, not started / lost answer / Check status results); the output tile (1); the Skills screen states (1); dark, largest text and German (3); Mac (3: page, confirmation dialog, running and finished); Android (1); wide, iPad landscape (1). The design system README was not read for the brief (the decisions come from the merged briefs and the existing widgets). What the render checked and what it did not is in the brief's "Local render review". Decisions that change behaviour:

- The section shows on the Installed tab only while no search text or filter is active (decided by the owner), or on the only list when the server has no hub.
- Output lines are shown only when a run ends, not while it goes, in a closed "Show output" tile (last 30 lines, not selectable, a footnote that the log is shared by every profile). They are blank under App Lock and while the app is inactive on a phone.
- A run's result stays until the next run or until the person leaves the list (closes the screen or switches profile); no Dismiss button (decided).
- The restore command is `hermes curator restore <name> -p <profile>` with both placeholders left for the person to fill in and a line telling them to add their profile; no profile name goes to the clipboard (decided).
- The installed skills list is read again when a run ends, because archived skills leave it.
- Following a run stops when the screen closes; the pass keeps going on the server. Reopening shows the last run time only, plus one read of the action status's `running` flag (no lines): while it is true Run now is disabled with "A pass is running on this server" and a Check status action. Check status that finds a run restarts polling with a new 15-minute limit. Confirming a run reads the action status once more before the POST (a pass running then means no POST; the header read becomes the baseline for the finish proof).
- Every request that gets no answer within 10 s, or whose connection drops after it was sent, ends in "Couldn't confirm" wording (a lost answer to a pause or run, never "Can't reach Hermes", which is only for a request that never left the device); only reads (status, action status) are repeated, by Try again or Check status. Polling that fails for 10 s shows "Couldn't confirm how the pass is going."
- The result never says "nothing changed": Hermes' output does carry counts (per the Hermes source `auto: checked=N stale=N archived=N reactivated=N`, `curator: auto: ... | no changes; llm: ...`), but lines can be missing or reworded and a consolidating pass can change more than its prune counts show. "The pass finished" shows only when `running` is false and the log has a start header after this app's POST: a newer `last_run_at` alone reads "A pass started at <time>" and, unless `running` is false, "Couldn't confirm it finished", because Hermes saves `last_run_at` right after the prune step, before consolidation.
- "Last ran" reads "Last pass or first check" with a footnote, because Hermes also sets `last_run_at` the first time it sees a profile (first-seen seeding), without a pass.
- `enabled` null counts as on; any other unknown field reads "Unknown".
- Run now is a `GroupedActionRow`, disabled while a pass is running or may be running (running, elsewhere, lost answer, progress lost, 15 minutes, stopped, unconfirmed check) until a read shows `running` false; after a pass ended it returns as "Run again"; the confirmation is an adaptive sheet with Cancel first and default, and Run now outlined, not red, not filled.

Client additions: `OutputLinesTile` extracted from `UpdateDetailsDisclosure` (`update_step_list.dart`; it has no line cap, footnote or blank mode today, and the lines are not selectable); `GroupedActionRow` moves to `lib/src/widgets/` and is extended (a subtitle slot, a neutral line with a Check status button, a "Run again" label, a Mac leading spinner while working, wrapping lines and a stacked mode at large text); a new `AppIcons.wifiOff` for the offline banner; the confirmation body scrolls with its buttons pinned; the open output box is capped (320 pt or 40 percent of the window) with an inner scroll and shows "Hidden while the app is locked or away" when blanked; blanking output while the app is inactive on a phone is new (no helper exists; App Lock blanking is free via `AppLockGate`). Status codes: PUT 400, 422 and 500 are section errors with Try again; PUT 404 `Profile '` adds a pause state (the switch stays, the profile list reloads). The section sits above the `StateMessage` in the Skills screen's empty and failed states, above the spinner while loading, and is hidden when skills are unsupported; a server with no hub has no tabs.

## Risks

- [Output lines include skill names] -> shown on screen only, under App Lock blanking.
- [A scheduled pass runs on its own, from the gateway or the dashboard ticker] -> the section says passes also start by themselves; the status is read again when a run ends.
- [Another client runs a pass at once] -> the log may mix; the app says lines may belong to another run.
- [`paused` does not stop Run now] -> stated in the section.

## Open questions

1. Ask Hermes to return `last_run_summary`, `last_report_path` and `run_count` from `GET /api/curator` and to expose restore and rollback. Recommendation: raise upstream; until then the app shows only what it can. Show last run's report when it exists. (The restore command's profile is decided: see Design pass.)
2. Should Run now be offered at all while consolidation is on? Recommendation: yes with the stronger wording; revisit when restore exists.
