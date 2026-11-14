# Design

## Context

Read in the Hermes source at `d923a5eb` (`openapi/HERMES_REF`, `/tmp/h/hermes-agent`): `hermes_cli/web_routers/status.py` (curator routes), `web_routers/_common.py` (`destructive_profile`, `config_scoped_to_thread`), `web_server_gateway.py` (`_spawn_hermes_action`, `_ACTION_LOG_FILES`), `web_routers/actions.py` (action status), `agent/curator.py`, `agent/curator_backup.py`, `tools/skill_usage.py`, `hermes_cli/curator.py`, `gateway/run.py`. Nothing was run.

Platforms: iOS, iPadOS, Android, macOS, Windows, Linux. Not watchOS. No native, entitlement or manifest change. Auth: all routes need the dashboard sign-in; Hermes has no roles.

Invariants touched: explicit `profile`; generated client only; a lost answer is never "done"; privacy rules.

## Server surface

No route has a response schema; the generated methods return untyped JSON.

### `GET /api/curator?profile=` (`status.py::get_curator_status`)

Returns exactly: `enabled` (bool, default true), `paused` (bool), `interval_hours` (int, default 168), `last_run_at` (ISO string or null), `min_idle_hours`, `stale_after_days` (default 14), `archive_after_days` (default 30). Each field is read with `_safe_call` and is null on failure. There is **no** summary, report path, run count, next-run time or counts: those live in `.curator_state` (`curator.py::load_state`) but the route drops them. "Next run" can only be estimated as `last_run_at + interval_hours` when not paused, and the scheduler also needs the gateway (below), so the app does not show it. 500 `"Curator unavailable: <exc>"` if the module fails to import. Unknown profile: `_config_profile_scope` calls `_resolve_profile_dir`: 400 for an invalid name, 404 `"Profile '<n>' does not exist."`.

### `PUT /api/curator/paused?profile=` (`status.py::set_curator_paused`)

Body `CuratorPause {paused: bool}` (`web_models.py`); a missing or non-bool body is FastAPI's 422. Writes `skills/.curator_state` for the profile and answers `{"ok": true, "paused": <bool>}`. The profile is optional here (not a destructive route).

### `POST /api/curator/run?profile=` (`status.py::run_curator`)

Calls `destructive_profile`: an omitted profile is accepted only on a single-profile backend, otherwise 400 `"POST /api/curator/run requires an explicit profile: this backend serves several profiles, so an unnamed target would act on the wrong profile's data."` Then `_spawn_action(["curator","run"], "curator-run", ...)` spawns `hermes -p <profile> curator run` detached and answers `{"ok": true, "pid": <int>, "name": "curator-run"}`. A bad profile name is 400 or 404 (`_profile_cli_args`); a spawn failure is 500 `"Failed to run curator: <exc>"`. Nothing guards a second run: each POST starts a new process and replaces the tracked handle, and `_cmd_run` takes no run claim (only the scheduled path does, `curator.py::_claim_run`).

### `GET /api/actions/curator-run/status?lines=` (`actions.py::get_action_status`)

`curator-run` is in `_ACTION_LOG_FILES`, so it shares the shape server-care documents: `{"name","running","exit_code","pid","lines"}`; `lines` is the tail (1 to 2000, default 200) of one append-only log `action-curator-run.log`, each run starting with `=== curator-run started <time> ===`. The log is per dashboard, not per profile. The log is a file, so it survives a dashboard restart; the process handle does not (then `exit_code` may be null). The app reuses `ActionStatus` and `CareAction` from `lib/src/server_care/` and adds only the `curator-run` name; it does not copy the poller.

### What a run does (`hermes_cli/curator.py::_cmd_run`, `agent/curator.py::run_curator_review`)

The child runs synchronously with no flags: so no dry run and no `--consolidate`. It prints `curator: running review pass...` and exits 1 with `curator: disabled via config` when `curator.enabled` is false. Otherwise:

1. **Prune** (`apply_automatic_transitions`): for skills the agent created (`created_by: agent`), by last activity: past `stale_after_days` becomes stale; past `archive_after_days` is moved into `skills/.archive/` (`skill_usage.archive_skill`). Pinned skills, skills used by a cron job, hub-installed and bundled skills (unless `curator.prune_builtins`) are skipped. Never deleted ("never delete, only archive", module docstring).
2. **Consolidate**, only when config `curator.consolidate` is true (default false): a forked agent on the helper model may pin, archive, merge and **rewrite** skills with `skill_manage`, after a whole-tree snapshot (`curator_backup.snapshot_skills`, reason `pre-curator-run`). It may also rewrite scheduled-task skill references (`_rewrite_cron_refs`).
3. Writes `logs/curator/<stamp>/REPORT.md` and `run.json` and sets `last_report_path` in the state. **No route serves these files**: `GET /api/logs` reads only the names in `hermes_cli/logs.py::LOG_FILES`, which has no curator report. `--dry-run` skips transitions and asks the fork for a report only, but only the command line passes it.

Undo: archives are recoverable only with `hermes curator restore <skill>`, single steps with `hermes curator rollback <ledger id>`, and snapshots with `hermes curator rollback` (`hermes_cli/curator.py::_cmd_restore`, `_cmd_rollback`). No REST route exposes restore, rollback, list-archived or the ledger (grep of `hermes_cli/web_routers/` and `web_server*.py`).

### Gateway and scheduling

Scheduled passes are started by the messaging gateway's housekeeping tick (`gateway/run.py::_housekeeping_curator`, every 60 s, per served profile) and by the CLI at session start (`cli_tui_runtime_mixin.py`), through `maybe_run_curator`, gated by `should_run_now`: enabled, not paused, `last_run_at` older than `interval_hours`. The first observation only seeds `last_run_at` ("deferred first run"). The dashboard process itself starts none, so with the gateway stopped nothing runs on schedule (the app's chat does not start one either). `hermes curator run` ignores `paused` (`_cmd_run` never reads it), hence "Run now still works".

## Client architecture

- `lib/src/skills/curator/curator_status.dart`: `CuratorStatus.parse(Object?)`, never throws.
- `lib/src/skills/curator/hermes_curator_repository.dart`: three methods through `authController.api!.raw`; a call answers a result type, never throws. Run and pause are never retried.
- `lib/src/skills/curator/curator_controller.dart`: state per profile (idle, running, finished, failed, unknown); polls `curator-run` status every 2 s, backs off to 5 s, stops after 15 minutes ("Still running on the server" with Check status); one run at a time.
- `lib/src/skills/widgets/`: `CuratorSection`, `CuratorRunConfirmation`, `CuratorRunProgress`, plain models and callbacks, Widgetbook first.
- The confirmation reads `curator.consolidate` from `GET /api/config?profile=` (already used by the memory and MCP repositories), leniently; unreadable means the "may also merge and rewrite" wording.
- Entry: a section at the top of the installed-skills list in `SkillsScreen` (`lib/src/skills/skills_screen.dart`), for the profile it shows. No new screen, no new route.

## Observability

| Signal | Where | Attributes |
| --- | --- | --- |
| span `skills_curator.run` | `CuratorController`, POST to end | `outcome` (done, failed, unknown, timed_out), `trigger_lost` |
| log `skills_curator.run_finished` | `CuratorController` | `outcome`, `archived_lines` (count of output lines naming an archive) |
| breadcrumb `skills_curator.run.confirmed` | confirmation | none |
| breadcrumb `skills_curator.paused` | switch | `paused` |

Spans carry the connection's `hermes.*` attributes. None holds a skill name, output line, profile or action id.

## Decisions and alternatives

- **Section on Skills, not a screen.** It has a status line and two actions.
- **Run needs a confirmation with Cancel default, pause does not.** A pass moves files on the server and the app has no undo; pause is one switch back.
- **No next-run time and no report.** The route returns neither; guessing would mislead. Output lines are shown only for a run this app started, because the log is shared by all profiles.
- **Run never offered when `enabled` is false:** the child would only exit 1.
- **No dry run.** Not reachable through the route.

## Risks

- [Output lines include skill names] -> shown on screen only, under App Lock blanking.
- [Another client runs a pass at once] -> the log may mix; the app says lines may belong to another run.
- [`paused` does not stop Run now] -> stated in the section.

## Open questions

1. Ask Hermes to return `last_run_summary`, `last_report_path` and `run_count` from `GET /api/curator` and to expose restore. Recommendation: raise upstream; until then the app shows only what it can. Show last run's report when it exists.
2. Should Run now be offered at all while consolidation is on? Recommendation: yes with the stronger wording; revisit when restore exists.
