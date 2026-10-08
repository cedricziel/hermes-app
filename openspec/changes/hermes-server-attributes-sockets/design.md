## Context

See proposal.md for why. Builds on `hermes-server-attributes-http`, which gives `AuthController` a per-connection attribute map and `Telemetry.forConnection` (interceptor and event logger for a connection).

Today `lib/main.dart:75-77` provides one `MessagingConnectionTracer` (gateway), one `KanbanEventsTracer` and the root `AppEventLogger` process-wide. `ChatScreen` (`chat_screen.dart:211`) and `AppShell` (`app_shell.dart:124`) each open their own gateway socket with the same tracer, and the tracer remembers a single connection span (`_connection`, overwritten in `connecting`, dart_otel_instrumentation_messaging 0.1.1), so the later socket's upgrade wins for both sockets' links. `KanbanScreen` (`kanban_screen.dart:101-109`) reads the shared Kanban tracer and the root logger. `MessagingConnectionTracer` has no attributes parameter. `HermesRepositories.forAuth` builds a new set whenever `auth.api` changes, which happens once per connect.

## Goals / Non-Goals

**Goals:**

- Socket spans and feature events carry the attributes of the connection they belong to.
- One tracer per socket, so links are right.

**Non-Goals:**

- Changing span names, routes, allowlists or the link model.

## Decisions

### 1. Upstream: a fixed `attributes` map on `MessagingConnectionTracer`

Matches `DioOTelInterceptor`'s existing fixed `attributes`: merged under each span's own attributes, on upgrade, request and event spans. Passed through by subclasses (`KanbanEventsTracer`). A fixed map, not a callback: a socket belongs to one connection for its whole life, and a new connection opens new sockets.

### 2. Tracers are built per socket from the connection

`Telemetry.forConnection` (from the first change) also returns `gatewayTracer()` and `kanbanTracer()` factories, each returning a new tracer with the connection's attributes, or null when telemetry is off. The process-wide tracer providers in `main.dart` go away.

### 3. The connection's telemetry travels with `HermesRepositories`

`HermesRepositories.forAuth` already rebuilds exactly when the connection changes. It captures `auth.connectionTelemetry` into a `telemetry` field at construction. Screens read the tracer factories and event logger from there instead of the root providers: `ChatScreen`, `AppShell` and `KanbanScreen` call the factory once per transport or board; `PluginsScreen`, `SkillsScreen` and the catalog and providers controllers take `repositories.telemetry.events`. A widget without repositories (tests, the Widgetbook catalog) falls back to no tracer and the no-op logger, as now.

Alternative considered: a `ProxyProvider<AuthController, ConnectionTelemetry>` of its own. Equivalent, but one more provider to keep in step with `HermesRepositories`, which already has the right lifetime.

### 4. What stays on the root logger

`WatchBridge` is created once at start-up (`main.dart:122`) and outlives connections; its events (watch requests) are about the watch link, not a server. `TokenStore` logs local storage failures. Both keep the root logger.

## Platforms

All; Dart only. No entitlement, manifest or Xcode change.

## Invariants touched

- **Telemetry must never break the app:** merging a fixed map adds no failure mode; the existing `_guard` wrappers in the tracer still apply.
- **Tests against `FakeHermesServer`:** gateway tests use the existing fake channel and in-memory span exporter.

## Risks / Trade-offs

- [Cross-repo sequencing: the app part waits for the flutter-otel release] → The upstream PR is small and first; release-please publishes it.
- [Moving tracers out of the root providers touches three screens and their tests] → Screens fall back to no tracer when repositories are absent, so widget tests that don't care keep passing; tests that check spans pass repositories with telemetry.
- [Before this change, link targets could be wrong for two concurrent sockets; after, they change] → Intended; called out in the spec.

## Migration Plan

No data migration. Rollback is reverting the app PR; the upstream parameter is optional and can stay.
