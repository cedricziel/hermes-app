## Context

`scheduled-tasks-monitor` provides the list, the detail, `HermesCronRepository` and `SchedulesController`. The server has one job engine: blueprints and the plain form both end in `cron.jobs.create_job`, and the blueprint route fills and validates the slots itself (`cron/blueprint_catalog.py`). Edits go through `PUT` with a free-form `updates` dict that the dashboard adapter normalizes (`web_routers/cron.py`). See proposal.md for scope.

## Goals / Non-Goals

**Goals:**
- Blueprint forms are rendered from the server's slot schema, so a new blueprint on the server needs no app release.
- The schedule picker and the stored schedule round-trip.

**Non-Goals:**
- Validating cron expressions or scripts on the phone.

## Decisions

**Blueprints go through `instantiate`, not through client-side prompt building.** The server owns the templates, the schedule and the prompt, and rejects unknown slots. Alternative: fetch the catalog and build a create request ourselves. Rejected: it would copy server logic that changes with each Hermes release.

**A schedule codec, tested as data.** `ScheduleSpec` (Every, Daily, Weekly, Once, Cron) has `toSchedule()` and `ScheduleSpec.fromJob(stored)`; `nextRuns(now, count)` serves the preview for the four simple forms. The stored `schedule` is `{kind: interval|cron|once, minutes|expr|run_at, display}`. Only interval, `M H * * *` and `M H * * <days>` map back to a picker mode; everything else is Cron with the text kept, so no job is ever rewritten by opening it. Interval writes always use `every <n><unit>`; a bare `30m` is avoided because the server's own documentation is ambiguous about whether it repeats.

**No preview for raw cron.** A correct cron evaluator is a dependency or a page of code, and the server already computes `next_run_at` on save. Alternative: pub.dev `cron_parser`. Rejected for now; the preview matters for the four forms people use, and the list shows the true next run after saving.

**Edit sends a diff.** The controller keeps the job as loaded and builds `updates` from fields that differ. That keeps fields the form does not know (`base_url`, `enabled_toolsets`, `failure_deliver`, `attach_to_session`) intact, which sending the whole job back would risk. Cleared optional text is sent as an empty string, which the adapter normalizes to null.

**Errors stay on the form.** 400 and 422 carry a `detail` string; a 422 from `instantiate` names the slot in its text, matched against the slot names. Anything else is shown as a form-level message.

**Platforms:** all. The date and time pickers are Material's, so no new plugin. Times are local; `Once` is sent with its offset so the server does not have to guess the phone's zone.

**Invariants touched:** API layering (generated client only); no route hand-written.

## Risks / Trade-offs

- [The blueprint slot types grow beyond the four known] → Unknown slot types render as a text field and the server validates the value.
- [A `once` schedule sent in local time with an offset is misread] → Covered by a test that sends the offset form; the contract test creates and deletes one job.
- [Edit-by-diff misses a concurrent change] → The detail reloads first; last write wins, as on the dashboard.
