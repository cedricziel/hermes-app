## Context

See proposal.md. `kanban-task-model` added `KanbanRepository.loadModelOptions`, the pill's `onUseDefault`; the shared `ModelPicker`/`showModelPicker` (base branch) list "Use the profile's default" first and close when it is picked, and the create fields. The plugin's PATCH and bulk bodies treat `null` as "not sent" and have explicit `clear_model_override` / `clear_reasoning_effort` flags; the model and the effort are independent columns, so clearing one never resets the other. The task JSON (`_task_dict`, an `asdict` of the task) carries `model_override`, `provider_override` and `reasoning_effort`.

## Goals / Non-Goals

**Goals:**

- One request per picker visit, sent only when something changed.
- Show an effort-only override (set by bulk edit or the CLI) instead of hiding it behind "Profile default".

**Non-Goals:**

- A second, effort-only control on the panel.

## Decisions

- **The panel's section is a plain row, not the composer pill.** The pill names a `ModelChoice`, which needs a model; a task can have an effort without one. `KanbanTaskFields` shows a row with the label built from the task, and reports a tap. The panel opens `showModelPicker` itself. Alternative rejected: widening `ModelChoice` to allow no model, which would ripple into the chat.
- **Apply when the picker closes.** `showModelPicker` reports each tap; the panel keeps the last pick and awaits the sheet or dialog, then calls `KanbanTaskController.setModel` once. Alternative rejected: a PATCH per tap, which would send two writes for "model, then effort" and reload the task under the open picker.
- **The default entry clears both.** From the row's point of view the override is "model · effort"; going back to the default means neither. The effort alone can still be set by bulk edit.
- **A pick without effort leaves the effort alone.** The picker keeps the task's effort when switching models, so a pick with no effort means the task had none the picker knows (or had `none`, which the picker does not offer); sending `clear_reasoning_effort` there would erase a `none` set elsewhere.
- **Options load on first tap and are kept** for the panel's lifetime in `KanbanTaskController`; a failure is an empty list, which leads to the text prompt.
- **Bulk effort uses the bar's existing pick dialog**, with "Profile default" first.

Platforms: all (iOS, Android, macOS, Windows, Linux). No native, entitlement, manifest or Xcode project change.

Invariants touched: API layering. Everything goes through the generated client (`UpdateTaskBody`, `BulkTaskBody`); `packages/hermes_api` is not edited. Tests run against `FakeHermesServer`.

## Risks / Trade-offs

- [Five bulk actions on a phone-width bar] → the labels are short; the Widgetbook smoke test fails on overflow at phone width.
- [The provider of a CLI-set override is missing] → the row shows the model alone and the picker checks nothing; a pick replaces it with a full pair.
