## Context

See proposal.md. The Profiles screen (`lib/src/profiles/profiles_screen.dart`) builds its rows inline, and tapping a row switches profile. `chat-model-selection` added `ModelPicker`/`showModelPicker` (model and effort, reporting every pick at once and staying open) and a profile-scoped `HermesModelsRepository`. Hermes has two routes that write a main model: `POST /api/model/set?profile=` (scope `main`), which the dashboard's Models page uses and which may answer `confirm_required` for an expensive model, and `PUT /api/profiles/{name}/model`, which the dashboard's Profiles page uses. Both write `model.provider` and `model.default` through the same validation; neither writes a main reasoning effort.

## Goals / Non-Goals

**Goals:**

- Change a profile's default from the row it is listed on, without making it active.
- Reuse the picker without changing how the chat pill behaves.

**Non-Goals:**

- A profile detail screen or a create-profile flow.

## Decisions

- **`PUT /api/profiles/{name}/model`, not `POST /api/model/set`.** It is what the dashboard's Profiles page, the screen this one mirrors, calls. It validates in the target profile's secret scope, has no confirmation round trip, and takes the profile in the path. `POST /api/model/set` would add only the expensive-model confirmation; its `reasoning_effort` applies to auxiliary slots, so it gives no effort for the main model either. Alternative rejected: `/api/model/set` for its effort field, which does not apply here.
- **Picker option instead of a second picker.** `ModelPicker` and `showModelPicker` gain `withEffort` (default true), `title` (default "Model") and an optional `note`. Without effort the picker hides the effort levels, reports picks without an effort, and `showModelPicker` closes on a pick, since there is nothing further to choose. The chat pill passes nothing new and keeps its behaviour.
- **Options loaded per profile on demand.** The button loads `GET /api/model/options?profile=<name>` when tapped, so the picker lists what that profile can use and checks its real current model (`provider` and `model` from that answer), not the list row's model id alone.
- **Encode the name.** The generated client puts `{name}` into the path unencoded, so the repository percent-encodes it, as `lib/src/plugins/` does.
- **Row widget.** The row moves to `lib/src/profiles/widgets/profile_tile.dart`, taking a `HermesProfile`, whether it is active, and two callbacks, so the catalog can show it.

Platforms: all (iOS, Android, macOS, Windows, Linux). No native, entitlement, manifest or Xcode project change. watchOS is unaffected.

Invariants touched: API layering. Both calls go through the generated client (`updateProfileModelEndpointApiProfilesNameModelPut`, `getModelOptionsApiModelOptionsGet`); `packages/hermes_api` is not edited. Tests drive `FakeHermesServer`.

## Risks / Trade-offs

- [A profile with no credentials of its own lists no provider] → "Could not load models" is shown. The server lists what that profile's scope can use, which is the set it would validate against.
- [No expensive-model warning] → Same as the dashboard's Profiles page; the model list is the server's own.
