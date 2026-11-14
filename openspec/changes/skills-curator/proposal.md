# Proposal

## Why

Hermes keeps the skills its agent wrote tidy with a background "curator": it marks unused skills stale and, after a while, archives them. It runs by itself once a week (started by the gateway or by the dashboard's own hourly check), or when a person asks. Today the app can say nothing about it. Someone whose skill list suddenly lost entries cannot tell why, cannot stop the curator, and cannot start it, without a terminal on the server.

Roadmap item 4.8 (the skills curator).

## What Changes

A **Skill curator** section on the Skills screen, for the profile the screen shows:

- **Status.** On or off, paused or active, "Last pass or first check 3 days ago" (or "Hasn't run yet"; Hermes also sets that time when it first sees a profile), the interval, and the thresholds ("Marked stale after 14 days, archived after 30"). From `GET /api/curator?profile=`.
- **Pause and Resume.** A switch, `PUT /api/curator/paused?profile=`. Reversible, so no confirmation. It stops the scheduled passes only; Run now still works.
- **Run now.** Asks first. The sheet says what a pass may do (archive skills recorded as agent-made that nobody used, include bundled skills if the server's `prune_builtins` is on, and, if consolidation is on, merge and rewrite skills), that archived skills are kept, and that the app cannot undo it. Cancel is the default. It then follows the run (`POST /api/curator/run?profile=`, `GET /api/actions/curator-run/status`) and shows Hermes' own output lines when it ends.

Hidden when the server has no curator route (a route-missing 404, told apart from a missing profile by the detail text).

Two PRs, catalog first (see tasks.md): `feat(skills): add the skill curator widgets to the catalog`, then `feat(skills): see, pause and run the skill curator`.

## Non-goals

- Undo. Hermes has no route to restore an archived skill or roll back a pass (only the `hermes curator` command line does); the app says so and shows the command to copy.
- A preview run. `--dry-run` exists only on the command line; the route starts no flags.
- Pinning, adopting, purging or listing archived skills, the curator's helper model (it is in Settings, Helper models) and its config keys.
- Reading Hermes' per-run report files: no route serves them.

## Security and privacy impact

No new credential. Skill names and run output are shown on screen only: never cached, logged, put in telemetry or the surface snapshot, and blanked under App Lock. Nothing is sent but the profile and the pause flag.

## Observability

- Span `skills_curator.run` (start to end of a run): `outcome`, `trigger_lost` (flag). Fits: it crosses a boundary and takes minutes.
- Log event `skills_curator.run_finished`: `outcome` (done, failed, unknown), `archived` (the count parsed from Hermes' `archived=N` line, absent when not found). For counting failed runs.
- Breadcrumbs `skills_curator.run.confirmed`, `skills_curator.paused` (`paused`): the user steps that explain a later archive.
- No profile, skill name or output text in any of them.

## Design pass

Screens and states for the later design pass:

- Skills screen, curator section (phone, iPad, Mac) - loading, never run, ran, paused, off in config, no route (hidden), offline, curator could not load, profile gone, dark, large text, German. Its place in each Skills screen state: above the list, above the empty and failed messages, hidden when skills are unsupported.
- Run confirmation (adaptive sheet: bottom sheet on phones, dialog on iPad, wide windows and every Mac width; Cancel the default) - prune-only, consolidating and unknown-config wording, large text, dark.
- Run progress and result - running (live region), finished ("The pass finished" only with proof, never "nothing changed"), failed with Hermes' full line, lost answer ("We couldn't tell if it started"), a pass already running on the server (Run now disabled), long output lines (not selectable), dark, large text.
