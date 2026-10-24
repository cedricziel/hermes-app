# Design

## Context

Facts about Hermes this design relies on, verified at Hermes `71d34bad` (routes in the bundled contract, `openapi/HERMES_REF`):

- `GET /api/config?profile=` returns the profile's config, defaults included unless `include_defaults=false`. `PUT /api/config?profile=` with `ConfigUpdate {config, profile}` deep-merges `config` into the saved file, so a body holding one key changes only that key.
- Keys and defaults: `memory.memory_enabled` (true), `memory.user_profile_enabled` (true), `memory.write_approval` (false), `memory.nudge_interval` (10 user turns, 0 = off), `display.memory_notifications` (`"off"`, `"on"`, `"verbose"`; default `"on"`).
- When they take effect: `memory.write_approval` is read at every write, so it applies at once, in open chats too. The others are read when a session starts.
- `GET /api/memory?profile=` → `{active, providers: [{name, description, available, configured, status, setup}], builtin_files: {memory, user}}`. `active` is `""` for the built-in store. `status` is `ready`, `needs_config`, `unavailable` or `missing`; a configured provider that is no longer installed reports `missing`. `builtin_files` are byte sizes.
- `POST /api/memory/reset?profile=` with `{target: memory | user | all}` → `{ok, deleted: [file names]}`. It requires an explicit profile on a multi-profile server, deletes the files, leaves open chats with their snapshot, and does not clear pending proposals.

The Plugins screen already shows the providers (Providers tab) for a profile through `HermesPluginManagerRepository.forProfile`, but always opens on Installed.

Platforms: iOS, iPadOS, Android, macOS, Windows, Linux. No native, entitlement, manifest or Xcode project change.

## Goals / Non-Goals

**Goals:**

- Every memory setting the dashboard exposes per profile, with its real effect time stated.
- A failed write never leaves the screen showing a value the server does not have.

**Non-Goals:**

- Provider selection here, limits as settings, undo.

## Decisions

**Read once, write one key.** The screen reads `GET /api/config?profile=` (defaults included) when it opens and after a reset. A change sends `PUT /api/config?profile=` with only the changed leaf, for example `{"config": {"memory": {"write_approval": true}}, "profile": "<profile>"}`, never the whole config, so a concurrent edit of another key survives. Values are read leniently: a missing or ill-typed key shows the documented default and is marked unverified in tests, not as an error. An unreadable config hides the Learning section's controls behind a retry row; Storage and Reset stay usable.

**Optimistic with revert.** The switch or value moves at once; one write per key is in flight at a time, and a change made meanwhile is sent after it with the latest value. On a refusal or transport failure the row goes back to the last value the server confirmed and a banner says "Couldn't change <setting>. Try again." The app does not re-read the whole config after a write; a later open does.

**Value mapping.** Review chats: 0 → Off, 5, 10, 20 → "After every N messages"; any other server value shows as "After every N messages" and is offered as a fourth choice so it is not lost. Memory updates in chat: `off` → Off, `on` → Short note, `verbose` → With details; an unknown value shows as it is and is kept until the user picks another.

**Caption.** Under the section: "Ask before saving applies right away, the rest from the next chat."

**Provider row.** From `GET /api/memory?profile=`: `active == ""` → "Built-in · MEMORY.md and USER.md"; otherwise the provider's `name` from `providers` (its `description` as subtitle). When the active provider's `status` is `missing`, an error banner above the row titled "Memory provider is missing": "<name> is no longer installed on the server. Hermes falls back to the built-in files until you pick another provider." `needs_config` and `unavailable` add a warning line. A failed read shows the row with "Couldn't read the memory provider" and a retry. A tap opens `PluginsScreen(initialTab: providers)` for the same profile through `HermesPluginManagerRepository.forProfile`.

**Reset.** "Reset memory…" opens an adaptive alert titled "Reset memory?" ("Hermes forgets what you pick, on the server, for the <profile> profile. This can't be undone."; the footnote "Erases the files on the server. Open chats keep what they started with. This can't be undone." sits under the button) and the actions Reset agent notes (`memory`), Reset about you (`user`), Reset both (`all`), all destructive, and Cancel. It always sends `profile` as the query value; the app never relies on the server's default profile. Success requires `ok: true`; the screen then reads the graph and config again (via the `memory-overview` controller) and says "Reset <what>. New chats start without it." A refusal shows the server's `detail` when it is a string; a lost response says the reset may have happened and re-reads the list, never repeats the request.

**Widgets.** `MemoryLearningSection`, `MemoryStorageSection` and the reset alert content as plain-model widgets in `lib/src/memory/widgets/`, catalogued first. On the screen they sit below the tabs' lists (phone) or in a settings column (desktop width), as `GroupedSection`s with `GroupedSwitchRow` and value rows.

**Invariants touched.** API layering: `getConfigApiConfigGet`, `updateConfigApiConfigPut`, `getMemoryStatusApiMemoryGet`, `resetMemoryApiMemoryResetPost`; no spec or client change. Auth: a 401 goes through the existing refresh; no sign-out from here. Privacy: nothing is persisted; the provider name is server configuration, shown but not logged.

**Observability.**

- Span `memory.settings.fetch` around the config read, from the settings repository, with `hermes.*` attributes and `outcome`.
- Span `memory.settings.write` with `key` (one of `user_profile_enabled`, `memory_enabled`, `write_approval`, `nudge_interval`, `memory_notifications`) and `outcome`.
- Span `memory.status.fetch` around `GET /api/memory`, with `outcome` and `provider_status` (`builtin`, `ready`, `needs_config`, `unavailable`, `missing`).
- Span `memory.reset` with `target` (`memory`, `user`, `all`) and `outcome`.
- Log `memory.setting_changed` (`key`, `outcome`: `saved` | `refused` | `failed`) after each write.
- Log `memory.reset_outcome` (`target`, `outcome`: `reset` | `refused` | `uncertain`, `deleted`: count).
- Breadcrumbs `memory.setting_toggled` (`key`) and `memory.reset_confirmed` (`target`), from the controller.

None carries memory text, provider names, file names, ids or profile names.

## Risks / Trade-offs

- [A setting is changed on the server while the screen is open] → the screen shows the older value until it is opened again; a write still sends only its own key, so nothing else is overwritten.
- [The user expects "Keep agent notes" off to erase notes] → the subtitle says it stops reading and writing them; Reset is the way to erase.
- [Reset leaves pending proposals that may re-add old text when approved] → the alert stays short; the proposals inbox (`memory-proposals`) shows each proposal's text before anything is approved.

## Migration Plan

None. Nothing is stored on the device.
