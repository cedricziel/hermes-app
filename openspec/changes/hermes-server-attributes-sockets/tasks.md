Starts after `hermes-server-attributes-http` is merged. Two PRs: one upstream, then one here (`feat(telemetry): describe the Hermes server on socket and feature telemetry`, about 350 lines with tests).

## 1. Upstream: flutter-otel (`feat(messaging)`)

- [ ] 1.1 In `cedricziel/flutter-otel`, failing test that `MessagingConnectionTracer(attributes: {...})` puts the map on upgrade, request and event spans, with a span's own attributes winning on a clash, and that `KanbanEventsTracer`-style subclasses can pass it through; then add the parameter
- [ ] 1.2 Document it in the package README, merge, and let release-please publish `dart_otel_instrumentation_messaging`

## 2. App: dependency (`build(deps)`)

- [ ] 2.1 Bump `dart_otel_instrumentation_messaging` to the release; telemetry and gateway tests stay green

## 3. App: tracers per socket

- [ ] 3.1 Failing test: `Telemetry.forConnection(...).gatewayTracer()` and `.kanbanTracer()` return new tracers whose spans carry the map, and null when telemetry is off; then implement them and pass `KanbanEventsTracer`'s attributes through
- [ ] 3.2 Failing test: two gateway sockets opened from the same connection each link their request spans to their own upgrade span; then give each transport its own tracer
- [ ] 3.3 Failing test: `HermesRepositories` built for a connection exposes that connection's telemetry, and a later connection's repositories expose the new one; then capture it in `forAuth`

## 4. App: screens and controllers

- [ ] 4.1 Failing test through the fake gateway channel and the in-memory exporter: with repositories for a connection, `ChatScreen`'s socket upgrade, `prompt.submit send` and `message.complete receive` spans carry `hermes.*`, and `gateway.reconnect` does on its log record but not its breadcrumb; then build the transport from `repositories.telemetry`. Same for `AppShell`'s transport
- [ ] 4.2 Failing test: the Kanban upgrade and `claimed receive` spans and `kanban.events.reconnect` carry `hermes.*`; then wire `KanbanScreen`
- [ ] 4.3 Failing tests: a `plugins.*` event from the plugins, catalog and providers controllers and a `skills.job` event carry `hermes.*`; then pass `repositories.telemetry.events` from `PluginsScreen` and `SkillsScreen`
- [ ] 4.4 Failing test: a watch bridge event has no `hermes.*`; keep it on the root logger
- [ ] 4.5 Remove the process-wide tracer providers from `lib/main.dart`

## 5. Docs and skills

- [ ] 5.1 Update the Telemetry paragraph in `CLAUDE.md` (tracers per socket, events from the repositories)
- [ ] 5.2 Add gateway and Kanban queries by `hermes.version` to the `observability` skill

## 6. Verify

- [ ] 6.1 `dart format --output=none --set-exit-if-changed .`, `flutter analyze`, and the targeted telemetry, gateway, Kanban, plugins and skills tests; CI runs the full suite
- [ ] 6.2 `verify-in-app` against `scripts/dev-backend.sh` with a loopback OTLP collector: chat, open Kanban, enable a plugin, and check the exported spans and logs
- [ ] 6.3 `openspec validate hermes-server-attributes-sockets`
