## Context

See proposal.md. Builds on `helper-model-settings` (the helper models screen, the list widget, the picker's title and default entry).

Server facts (hermes_cli/web_routers/models.py, moa_config.py, web_models.py at `HERMES_REF`):

- `GET /api/model/moa` returns `normalize_moa_config`: `default_preset`, `active_preset`, `presets` (each with `reference_models`, `aggregator`, temperatures, `reference_timeout`, `degraded_reference_policy`, `fanout`, `enabled`), a flattened copy of the default preset, and `privacy_filter`.
- `PUT /api/model/moa` takes `MoaConfigPayload`; with `presets` it replaces all presets, and `validate_moa_payload` rejects (422) an incomplete slot, a preset without a complete advisor, or a `moa` provider inside a preset.
- Both routes take `?profile=`.
- The runtime re-reads the preset when `config.yaml` changes (`agent/moa_loop.py`, keyed by the file signature), so a change applies from the next MoA turn, not only to new chats.

## Goals / Non-Goals

**Goals:**

- Change one MoA slot without losing anything else in the MoA config.

**Non-Goals:**

- Preset management and the non-model MoA settings.

## Decisions

- **Round-trip the config as read.** The app keeps the whole `GET` answer and changes only the one slot in `presets[default_preset]`, then builds the generated `MoaConfigPayload` from it with `fromJson`. Alternative rejected: a typed model of every MoA field in the app, which would silently drop any field Hermes adds later.
- **One MoA save at a time.** Every PUT carries the whole config, so a second save built before the first returns would undo it. The MoA rows are disabled while a save runs.
- **No default entry for MoA.** Hermes rejects an empty slot at write time, so the picker offers models only, and hides the virtual `moa` provider, which Hermes rejects inside a preset.
- **Section left out on failure**, like the composer pill: MoA is optional and the task slots are still useful.

Platforms: all (iOS, Android, macOS, Windows, Linux). No native, entitlement, manifest or Xcode change. watchOS unaffected.

Invariants touched: API layering. Calls go through the generated `DefaultApi` and `MoaConfigPayload`; `packages/hermes_api` is not edited. Tests drive `FakeHermesServer`.

## Risks / Trade-offs

- [`privacy_filter` is reset by any PUT] → `MoaConfigPayload` does not declare it, and the handler merges the normalized payload (with `privacy_filter: ""`) over the stored section, so a PUT from any client turns the filter off. This is a server issue, reported with the PR; the app cannot send the field through the generated client.
- [A config the generated `fromJson` cannot read] → the save fails with the usual error message and nothing is sent; reading stays lenient.
- [The screen's text says changes apply to new chats] → MoA applies sooner; the text stays true enough for a settings screen and is not repeated per section.
