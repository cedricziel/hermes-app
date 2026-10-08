## Why

`hermes-server-attributes-http` describes the connected Hermes server on HTTP requests and the connection controller's events. The chat gateway and Kanban sockets, and the events the gateway transport and feature controllers log (`gateway.reconnect`, `gateway.turn_settled`, `kanban.events.reconnect`, `plugins.*`, `skills.job`), still say nothing about it. Those are where stalls and reconnect storms show up, and where knowing the Hermes version matters most.

Depends on `hermes-server-attributes-http`, which introduces the per-connection attribute set and `Telemetry.forConnection`.

## What Changes

- Upstream in `cedricziel/flutter-otel`: `MessagingConnectionTracer` takes an optional fixed `attributes` map, merged under every span's own attributes (upgrade, request and event spans), as `DioOTelInterceptor` already does. A minor release of `dart_otel_instrumentation_messaging`; the app bumps to it.
- Each gateway and Kanban socket gets a tracer of its own, built with the attributes of the connection it was opened on. Today one tracer is shared process-wide, and the chat screen's and the shell's sockets overwrite each other's remembered connection span, so request and event spans can link to the wrong socket.
- The gateway transport, the Kanban board, and the plugin, catalog, provider and skills-hub controllers log their app events through the connection's event logger, so their log records carry the server's `hermes.*` attributes.
- The watch bridge and the token store keep the plain logger: the bridge outlives connections, and the token store's event is about local storage.

## Non-goals

- No new spans, events or attribute names; only the set from `hermes-server-attributes-http`.
- No change to what the socket spans record otherwise (names, routes, allowlists, links).
- No `hermes.*` on breadcrumbs.

## Security and privacy impact

The same `hermes.*` set as `hermes-server-attributes-http`, now also on socket spans and feature events. Nothing new is read from the server, and nothing about sockets beyond what is recorded today. Tokens and secure storage: none touched.

## Telemetry emitted

No new spans or events. Existing ones gain the connection's `hermes.*` attributes:

- gateway socket: the `/api/ws` upgrade span, `<method> send` request spans and `<event> receive` event spans;
- Kanban socket: the `/api/plugins/kanban/events` upgrade span and `<kind> receive` event spans;
- app events: `gateway.reconnect`, `gateway.turn_settled`, `gateway.event_unmapped`, `kanban.events.reconnect`, `plugins.*`, `skills.job`.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `telemetry`: the requirement that telemetry carries the connected server's attributes is extended to the gateway and Kanban sockets and the feature controllers' events, and socket request and event spans link to their own socket's upgrade span.

## Impact

- `cedricziel/flutter-otel`: `dart_otel_instrumentation_messaging` (additive parameter).
- `pubspec.yaml`/`pubspec.lock`: bump `dart_otel_instrumentation_messaging`.
- `lib/src/telemetry/telemetry.dart`: gateway and Kanban tracer factories taking a connection's attributes.
- `lib/src/api/hermes_repositories.dart`: carries the connection's telemetry, captured when the repositories are built for that connection.
- `lib/main.dart`, `lib/src/chat/chat_screen.dart`, `lib/src/shell/app_shell.dart`, `lib/src/kanban/kanban_screen.dart`, `lib/src/plugins/plugins_screen.dart`, `lib/src/skills/skills_screen.dart`: build tracers per socket and read the event logger from the repositories.
- `openspec/specs/telemetry/spec.md`: synced on archive.
