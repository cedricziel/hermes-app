## Context

See proposal.md. The job form (`JobFormScreen`, `JobFormController`, `JobDraft`) keeps `model` and `provider` as two strings and sends them as-is: absent on create when empty, and on edit only when changed, where an empty string clears them. Hermes (`hermes_cli/web_routers/cron.py`, `cron/jobs.py`) strips both and stores an empty value as null, and reports them back on the job as a string or null. A job can hold a model without a provider (older jobs, or a model set on the CLI). `ModelPicker` and `showModelPicker` from `chat-model-selection` take plain models and always offer effort.

## Goals / Non-Goals

**Goals:**

- One picker for chat and jobs, with effort and a default entry as options.
- A saved value is never lost by opening the form.

**Non-Goals:**

- A text escape hatch for models the server does not list.

## Decisions

- **Draft stays two strings.** The picker's result is written into `JobDraft.model` and `JobDraft.provider`; `toCreate` and `diff` are unchanged, so "only what changed" and "empty clears" keep working and an untouched unlisted value is never sent. Alternative rejected: a `ModelChoice?` on the draft, which cannot hold a model without a provider.
- **Picker options, not a second picker.** `ModelPicker` gets `showEffort` (default true) and an optional `onUseDefault` callback; when set, a "Use the profile's default" entry comes first and is checked while nothing is selected. The chat pill passes neither and is unchanged.
- **A plain-model field widget.** `JobModelField` in `lib/src/schedules/widgets/` takes the options (nullable), model, provider and callbacks, so the catalog can show every state. It marks a saved pair the options do not list as not in the server's list.
- **Options loaded by the form controller.** `JobFormController.loadModels` takes the models repository (the screen passes `HermesRepositories.maybeOf(context)?.models`) and loads for the draft's profile; a failure reads as null, as in the chat. Changing the profile of a new job reloads it, and a load that finishes after a newer one is dropped.

Platforms: all (iOS, Android, macOS, Windows, Linux). No native, entitlement, manifest or Xcode project change. watchOS is unaffected.

Invariants touched: API layering. The options request uses the existing `HermesModelsRepository` over the generated client. Tests drive `FakeHermesServer`.

## Risks / Trade-offs

- [The list is per profile, but a job edited from "all profiles" belongs to its own profile] → The controller loads for the job's `profile`, which the job JSON carries.
- [A model picked for one profile, then the profile switched on a new job] → The pick is kept and shown as not in the list if the new profile lacks it; the user sees it before saving.
- [A custom provider's model can no longer be typed] → Accepted (non-goal); existing values are kept.
