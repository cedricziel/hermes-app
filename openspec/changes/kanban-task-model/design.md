## Context

See proposal.md. The chat change (`chat-model-selection`) added `ComposerModelPill`, `ModelPicker`/`showModelPicker` and `ModelOptions` in `lib/src/models/`, taking plain option lists so other features can feed their own. The Kanban plugin's options route has the same `slug`/`models` rows as `/api/model/options` but names a provider `label` (not `name`) and sends no `capabilities` or current model. The create handler passes `CreateTaskBody` straight to `kanban_db.create_task`, which validates the pair (a provider without a model is refused) and normalises the effort.

## Goals / Non-Goals

**Goals:**

- Reuse the chat's pill and picker, unchanged for the chat, with one optional addition.
- Send what the dashboard would: the pair from the list, or a bare model name.

**Non-Goals:**

- Editing an existing task (next change).

## Decisions

- **Parse with `ModelOptions.fromJson`.** It already skips junk rows; it learns to read `label` when `name` is absent. With no capabilities every model reasons and cannot turn it off, so the picker offers `minimal` to `ultra`. Alternative rejected: a Kanban-only options type, which would duplicate the parser and the picker's input.
- **The default entry is an optional callback.** The shared `ModelPicker`/`showModelPicker` take `onUseDefault` (from the base branch): the picker lists "Use the profile's default" first, checked when nothing is selected, and closes when it is picked. `ComposerModelPill` takes the same optional callback, passes it on, and says "Profile default" instead of "Choose a model" with no choice. The chat passes nothing, so its behaviour and tests are unchanged. Alternative rejected: a nullable value on `onChanged`, which would change the chat's call sites.
- **Options load in the form, not the board controller.** Only the form needs them in this change; a failure maps to an empty list, which shows the text field, as in the dashboard.
- **The repository takes a `ModelChoice?` or a free-text model.** `createTask` gains `ModelChoice? model` and `String? modelName`; the form sends one or the other.

Platforms: all (iOS, Android, macOS, Windows, Linux). No native, entitlement, manifest or Xcode project change.

Invariants touched: API layering. Both calls go through the generated client (`modelOptionsApiPluginsKanbanModelOptionsGet`, `createTaskApiPluginsKanbanTasksPost`); `packages/hermes_api` is not edited. Tests run against `FakeHermesServer`.

## Risks / Trade-offs

- [A plugin older than the fields ignores them] → Pydantic drops unknown fields, so the task is created on the profile default. The options route would be missing too, so the user sees the text field; the contract test pins the shape against the CI Hermes.
- [A stale list offers a pair the server now refuses] → the plugin answers 400 with a reason, which the form already shows while staying open.
