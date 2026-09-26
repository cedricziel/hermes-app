## Context

See proposal.md. The composer already has a profile-scoped options repository (`HermesModelsRepository`) and a picker (`showModelPicker`/`ModelPicker`) that reports every tap through `onChanged` and is used by the chat pill. `/api/model/auxiliary` and `/api/model/set` exist in the generated client (`getAuxiliaryModelsApiModelAuxiliaryGet`, `setModelAssignmentApiModelSetPost` with `ModelAssignment`) but have no response schema.

Server facts (hermes_cli/web_routers/models.py, web_server_config.py at `HERMES_REF`):

- Slots come from `_AUX_TASK_SLOTS` (vision, compression, skills_hub, approval, mcp, title_generation, review, triage_specifier, kanban_decomposer, profile_describer, curator). A slot on `provider: auto` uses the main model; the dashboard labels it "auto (use main model)".
- Both routes take `?profile=` and scope reads and writes to it.
- `/api/model/set` writes `config.yaml` and "applies to **new** sessions only".
- An expensive model answers `{"ok": false, "confirm_required": true, "confirm_message"}` with status 200 until resent with `confirm_expensive_model: true`.
- Resetting one slot: `provider: "auto"`, `model: ""` for that task (`__reset__` resets every slot, which this change does not offer).

## Goals / Non-Goals

**Goals:**

- Reuse the picker and the options repository; the chat pill keeps working unchanged.
- A plain-model list widget that the next change extends with the MoA slots.

**Non-Goals:**

- Custom endpoints per slot and a "reset all" action.

## Decisions

- **Entry in the sidebar's More section.** It holds every server-side setting of the profile (Profiles, Skills, Bots, Plugins, MCP servers). `lib/src/settings/` and the Account menu hold device settings (appearance, notifications, app lock, about), so a server config screen there would mix the two. The screen file still lives in `lib/src/settings/` next to the other settings.
- **The chat's profile.** The screen acts on `ChatController.profile`, the same profile the composer pill reads options for, so a helper model is set on the profile the user is chatting with.
- **Save when the picker closes.** The picker reports each tap (model, then effort); saving each would post twice and could race. The screen keeps the last pick and posts once after `showModelPicker` returns, only when it differs from the slot. Alternative rejected: an explicit Save button in the picker, which would change the chat pill's behaviour.
- **Picker generalisation.** `ModelPicker` and `showModelPicker` gain an optional `title` and an optional `defaultLabel`; with a label, an entry above the providers reports through its own `onDefault` callback, so `onChanged` keeps its non-null type. The pill passes no label.
- **Lenient parsing.** Rows without a string `task` are skipped; a missing `main` leaves the "same as main" text without a model name.

Platforms: all (iOS, Android, macOS, Windows, Linux). No native, entitlement, manifest or Xcode change. watchOS unaffected.

Invariants touched: API layering. Calls go through the generated `DefaultApi`; `packages/hermes_api` is not edited. Tests drive `FakeHermesServer`.

## Risks / Trade-offs

- [A slot's effort cannot be cleared] → `ModelAssignment.reasoning_effort` is generated with `includeIfNull: false`, so "no effort" omits the key and Hermes leaves the old override. The picker keeps the previous effort when the new model accepts one, so this only leaves a stale level on a model that ignores it, or on a slot switched to auto. A later regeneration could send `null`.
- [The picker lists only authenticated providers] → a slot pinned to a provider the server no longer reports is still shown, but cannot be re-picked; "Same as main model" always works.
- [Profile changes while the screen is open] → the screen keeps the profile it opened with.
