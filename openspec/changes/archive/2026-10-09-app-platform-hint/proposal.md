# Proposal

## Why

Since the app names itself as the session source (`hermes_app`), Hermes no longer tells the agent it runs in a terminal. It tells it nothing, because Hermes has no prompt hint for a source it does not know. The agent therefore does not know that this app renders Markdown or that a `MEDIA:/absolute/path` tag becomes an attachment the user can open. Hermes lets an operator set a hint for any source in a profile's `config.yaml` (`platform_hints.<source>`), and `PUT /api/config` deep-merges a partial update into that file, so the app can add its own hint. It writes to the user's server, so it asks first.

## What Changes

- After sign-in and on every app start, the app reads each profile's saved config and works out whether the profile needs the app's hint: it has none, or it has an older text this app wrote. A hint someone else wrote is left alone.
- When at least one profile needs it, the app asks once with a dialog (a bottom sheet on a compact layout): what the hint does, which profiles get it, and the exact text. The user can add it, put it off until the next start, or turn the question off for this server.
- Adding writes only `platform_hints.hermes_app` to each profile that needs it, through `PUT /api/config`. A profile that fails is reported and can be retried; the others keep their hint.

## Capabilities

### New Capabilities

- `app-platform-hint`: the app's prompt hint on the Hermes server, when it is offered and what is written.

### Modified Capabilities

None.

## Non-goals

- Writing the hint without asking.
- Editing or removing a hint the app did not write, or offering an editor for the text.
- Changing a session that is already running: Hermes reads the hint when it builds a session.
- A hint for Hermes' own CLI, TUI or desktop app, which use other sources.

## Security and privacy impact

The app writes one key to the server's profile configs, only after the user agrees, with the session it already has. A per-server "don't ask again" flag is kept in shared preferences, keyed by the server address. No token, transcript or config value is stored.

## Telemetry

Breadcrumbs only, no exported log record: `platform_hint.offered` (`profiles`: count, `update`: flag) and `platform_hint.answered` (`outcome`: `added`, `later`, `never`, `failed`). No profile names, server addresses or hint text.

## Impact

- New `lib/src/platform_hint/` (repository, controller, dialog widget), Widgetbook use cases, `AppShell` wiring.
- Backend contract: `GET /api/config?profile=&include_defaults=false`, `PUT /api/config?profile=`, `GET /api/profiles`. All exist in the generated client.
