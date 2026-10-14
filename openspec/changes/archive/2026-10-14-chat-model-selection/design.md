## Context

See proposal.md for the motivation. The composer is flutter_chat_ui's `Composer`, which has a `topWidget` slot above the text field and no row below it. Model choice in Hermes is either profile-wide (`POST /api/model/set`, config file, new sessions only) or per session (`session.create` overrides, `config.set` with a `session_id`). The chat already opens every send with `session.create` or `session.resume` in `HermesGatewayTransport.send`.

## Goals / Non-Goals

**Goals:**

- A per-chat choice that never touches the profile's config.
- A pill and picker that later changes (Kanban, schedules, profiles) reuse by passing in their own option list.

**Non-Goals:**

- A custom composer. The pill goes into `topWidget` for now.

## Decisions

- **Per session, not `/api/model/set`.** Writing the config would change every future chat of the profile and needs a new session to take effect. The session overrides act at once and stay in the chat. Alternative rejected: a profile-wide setting behind the pill.
- **Choice travels on `ChatTransport.send`.** `send` gains an optional model choice. The gateway transport sends it on `session.create`, or calls `config.set` after `session.resume` when it differs from the last choice it applied to that thread. The transport remembers what it applied per thread, so a repeat send makes no extra calls. Alternative rejected: a separate `setModel` call from the screen, which would need a live session the screen does not have for an idle thread.
- **Effort levels are fixed, not per model.** Hermes deliberately does not forward `supported_efforts` ("it under-reports levels that work"), and reports only `reasoning` and `can_disable_reasoning` per model. The picker offers Hermes' `VALID_REASONING_EFFORTS`, plus Off when the model can disable reasoning.
- **Widgets take plain models.** `ComposerModelPill` and the picker take the option list, the selection and callbacks, with no repository, so Kanban can feed them its own `/api/plugins/kanban/model-options` list later.
- **Hide on failure.** A chat without the pill still works; an error banner for an optional control would be noise.

Platforms: all (iOS, Android, macOS, Windows, Linux). No native, entitlement, manifest or Xcode project change. watchOS is unaffected: watch sends carry no choice.

Invariants touched: API layering. The options request goes through `authController.api!.raw` (`DefaultApi.getModelOptionsApiModelOptionsGet`), and `packages/hermes_api` is not edited. Tests drive `FakeHermesServer` and the fake gateway socket.

## Risks / Trade-offs

- [The per-thread "last applied" record is lost when the app restarts, and the server keeps the session's override] → The pill then shows the profile's model while the server session may still run the earlier choice. Acceptable for this step; a later change can read the model from the `session.resume` answer.
- [An incoherent model and provider pair] → `session.create` answers -32602 and the send fails visibly; the picker only offers pairs from the server's own list, so this needs a stale list.
- [Effort offered for a model that ignores it] → Hermes treats the dial as a no-op on such models.
