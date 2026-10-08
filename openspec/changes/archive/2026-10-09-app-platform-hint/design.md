# Design

## Platforms

All app platforms (iOS, Android, macOS, Windows, Linux). No native, entitlement or manifest change. watchOS is not affected.

## Backend contract

Hermes reads `platform_hints.<source>` from a profile's config when it builds the agent (`agent/agent_init.py`), as `{replace|append}` or a bare string (`agent/system_prompt.py`). `PUT /api/config` deep-merges the body over the file on disk (`hermes_cli/web_routers/config_env.py`), so a body with one key changes only that key. `include_defaults=false` returns only saved values. `platform_hints` defaults to `{}`, and no Hermes version seen so far filters it on save.

## Shape

- `PlatformHintRepository` (generated client): `list profiles`, `read(profile)` returning a `HintState` (`missing`, `outdated`, `current`, `foreign`), `write(profile)`.
- `PlatformHintOffer` (`ChangeNotifier`): runs the check, holds the profiles that need the hint and the write progress, and stores the per-server "don't ask again" flag (`platform-hint.declined.<server>` in `SharedPreferencesAsync`).
- `PlatformHintPrompt`: a plain-model widget (profile names, update flag, text, busy, failed profiles, callbacks), built in Widgetbook first. `showPlatformHintPrompt` picks dialog or sheet with `isWideLayout`, like `showMcpCommandReview`.
- `AppShell` starts the check from `initState`, which runs after sign-in and on a start with a saved session, and only in the main engine (conversation windows do not build `AppShell`).

## Invariants touched

- API layering: all calls go through the generated client (`authController.api!.raw`).
- Telemetry: breadcrumbs only, through the existing `Breadcrumbs`; no text, names or addresses.
- Tests use `FakeHermesServer` for the config and profile routes.
