## Context

`add-skills-installed` adds the Skills page, a repository over the generated `DefaultApi`, and a controller that owns the selected profile. This change adds the Discover tab and the hub half of that repository. See `proposal.md` for motivation and non-goals.

Server behaviour (`hermes_cli/web_routers/skills.py` and `actions.py`, Hermes pinned in `real-backend-contract.yml`):

- Search, official, sources, preview and scan are read routes, all taking `profile`. Search is network-bound and returns `timed_out` sources instead of failing.
- Install, uninstall and update do not do the work in the request. They spawn `hermes skills install|uninstall|update` as a background process and reply `{ok, pid, name}`. Progress is read from `GET /api/actions/{name}/status`, which returns `{name, running, exit_code, pid, lines}`. The `name` is derived from the action and the skill, so it is unique per skill but reused if the same skill is installed again.
- Scan replies with `policy` of `allow`, `ask` or `block`, and `policy_reason`. Install itself runs with `--yes`, so the server does not stop an `ask` skill: the confirmation has to happen in the app.

Platforms: iOS, Android, macOS, Windows, Linux. watchOS is not affected. No native change.

## Goals / Non-Goals

**Goals:**

- Make it impossible from the app to install a skill without having seen its scan for the same identifier.
- One small job runner that install, uninstall and update all share.

**Non-Goals:**

- No queue of several jobs; one at a time.
- No persistence of a job across an app restart; the server's job keeps running, and the installed list is the source of truth when the app comes back.

## Decisions

**Scan gates install in the controller, not just the UI.** The controller's `install(identifier)` refuses unless it holds a scan for that exact identifier whose policy allows it (`allow`, or `ask` with the confirmation given). The buttons are then only a view of that state, so a future screen cannot skip the check by calling install directly. Alternative: gate only in the widget. Rejected because install runs code on the user's server and the rule should not depend on a widget being wired right.

**Unknown policy is `block`.** A server that adds a policy value or drops the field results in no install, the safe direction.

**Scan on open, not on install.** The user sees the findings while reading the skill, and the confirmation for `ask` can list them without another request. The scan costs a network call on the server, so it starts when the hub page opens and is cancelled if the page closes.

**A shared job runner.** `SkillJob` starts a job through the repository, polls the status route every 1.5 seconds with a cap on total time and consecutive read failures, and exposes state (`running`, `succeeded`, `failed`, `unknown`) and the log tail as a `ChangeNotifier`. The sheet and the small in-page indicator both listen to it, so "run in the background" only closes the sheet. Alternative: a fresh poller per screen. Rejected because closing the sheet would lose the job.

**Exit code decides the outcome.** `exit_code == 0` is success, another number is failure, and a missing job (404) or repeated read failures is `unknown`. `unknown` never claims success. Whatever the outcome, the Installed list reloads, because the server's list is the truth.

**One job at a time.** The server names jobs per action and skill, so two concurrent installs of different skills would work, but updating while installing could interleave writes to the same skill folder. The runner allows one job, which also keeps the UI simple.

**Search is debounced and cancels stale requests.** The search field waits 400 ms after the last keystroke and ignores a reply that is not for the latest text. The empty search shows the `featured` list from the sources route plus the official catalog, both loaded once per profile and kept while the tab lives.

**Installed marker uses the server's `installed` map.** Search, official and sources replies mark installed identifiers per profile. The tab reloads them after any job ends.

**Invariants touched.** All calls go through `authController.api!.raw`; no hand-written Dio. Telemetry (request tracing by the Dio interceptor, plus guarded app events) never carries identifiers, search text or logs. Auth and 401 handling are untouched: a 401 during polling is handled by the existing interceptor, and polling never signs the user out.

## Risks / Trade-offs

- [The server installs `ask` skills without stopping] → the app is the only gate for `ask`; documented in the controller and covered by tests that `install` refuses without a scan and without confirmation.
- [Scan says allow but content changes between scan and install] → the server fetches again at install time. The app cannot prevent this; the risk is the same as in the dashboard and is accepted.
- [Job name reuse makes an old finished job look like a new one] → the runner ignores a status whose `pid` differs from the one the start call returned, when both are present.
- [A failed poll while the job actually succeeded] → reported as unknown, never as success, with a refresh of the installed list so the user sees the truth.
- [Search hits third-party registries and can be slow] → debounce, a timeout note per source, and no block on the featured list.
