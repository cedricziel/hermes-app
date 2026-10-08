## Context

See proposal.md for why. Today (`lib/main.dart:42-54`) one `DioOTelInterceptor` instance is built at start-up and handed to `AuthController(interceptors: [...])`, which adds it to every Dio it builds through `_plainDio` (`auth_controller.dart:694`): the `/api/status` probe, the token client, the page-token client and the authenticated client. One `AppEventLogger` (`telemetry.events()`: a `BreadcrumbTrail` wrapped around a log-backed logger) is handed in as `events`.

In `connect()` the controller probes `/api/status`, assigns `_status` (`:217`) and only then builds the authenticated and token clients (`:227-229`). `_status` is not reset when a connect starts, and `signOut()` and session expiry keep `_status`, `_dio` and `_api` (`:425-437`); only `changeServer()` clears them (`:443-467`). So "the connection" in this design is the span from one successful probe to the next connect or Change Server.

`HermesStatus.fromJson` uses `jsonField`/`jsonFieldOrNull`, which throw `FormatException` on a wrong type (`json_fields.dart:14`), and `connect()` turns that into a connection error (`:208-212`). `DioOTelInterceptor.privacy` (dart_otel_instrumentation_dio 0.1.2) already takes a fixed `attributes` map, merged under each span's and record's own attributes.

## Goals / Non-Goals

**Goals:**

- Each piece of telemetry carries the attributes of the connection that produced it, never a neighbour's.
- No change to the connect flow's outcome for any status answer.
- No upstream change.

**Non-Goals:**

- Refreshing attributes during a connection (no re-probe, so nothing to refresh).
- Sockets and feature controllers (`hermes-server-attributes-sockets`).

## Decisions

### 1. Fixed attributes per connection, not resource, global or callback

A server is a peer, not the producer, and can change at runtime, so resource attributes are wrong. A process-wide setter or callback would tag a request with whatever server is current when the span is made, not the one it was sent to: a request in flight across a switch, or `auth.connect.failed` for a new address while the old status is still held, would get the wrong server. A callback reading a controller field has the same flaw.

Instead the controller builds one immutable attribute map when the probe succeeds, and builds that connection's instruments with it: the interceptor for its clients, and its event logger. A Dio keeps the interceptor it was built with, so a request stays with its connection even after the next one starts. The only thing to refresh is the status, and every refresh is a new connect that builds new clients anyway, so a callback buys nothing.

### 2. Lenient extraction apart from `HermesStatus`'s strict fields

`hermesServerAttributes(Map<String, dynamic> json)` in `lib/src/telemetry/hermes_server_attributes.dart` reads only the ten fields, each with a type check that yields nothing instead of throwing, and computes the profile count (skipped for `gateway_mode` = `unknown`). `HermesStatus.fromJson` calls it and keeps the result as `serverAttributes`; the fields the connect flow depends on keep their strict parsing. Reading only named fields means paths, PIDs and profile names from an ungated server cannot slip in.

### 3. `Telemetry` builds instruments for a connection

`Telemetry` gains `forConnection(Map<String, Object> attributes)`, returning the interceptor and event logger for a connection (or none and the no-op logger when telemetry is off). The no-connection pair (empty map) is used for the probe and for events before the status is known.

The event logger is `breadcrumbs.asAppEventLogger(scoped(appEventLogger(log), attributes))`: the breadcrumb trail sees only what the caller passed, and only the exported log record gets the merged map. `server.connected` is logged with `{'hermes.version': ...}` as its own attribute, so its breadcrumb carries the version and its log record carries everything. This keeps crash records small (40 breadcrumbs × 10 pairs otherwise) and free of a previous server's `install_id`.

### 4. `AuthController` owns the current connection's instruments

`AuthController` takes `Telemetry`'s connection factory instead of `interceptors` and `events`. It holds `_connectionTelemetry`:

- reset to the no-connection instruments at the start of `connect()` and in `changeServer()`;
- replaced right after `_status` is assigned, before the authenticated and token clients are built, followed by `server.connected`;
- left alone by `signOut()` and session expiry, which keep the connection.

`_events` reads `_connectionTelemetry` at call time, so an event is described by the connection current when it happens. The probe Dio uses the no-connection interceptor. `TokenStore` keeps the plain logger: its event (`auth.session.read_failed`) is about local storage, not the server.

Tests construct `AuthController` without telemetry as today; the factory parameter defaults to "no telemetry".

## Platforms

All; Dart only. No entitlement, manifest or Xcode change. Conversation windows on macOS have no telemetry.

## Invariants touched

- **Telemetry must never break the app:** extraction never throws; a malformed field drops one attribute.
- **API layering:** no new REST call; `/api/status` stays hand-written because the spec has no response schema for it.
- **Tests against `FakeHermesServer`:** connect-path tests use a fake `/api/status` answer and the in-memory log and span exporters already used in `test/telemetry_test.dart`.
- **Auth:** the connect, sign-out and refresh paths change only in which logger and interceptor they use; their outcomes do not change.

## Risks / Trade-offs

- [`hermes.install_id` is high-cardinality] → It is an attribute, never part of a span name or metric label: storage cost only, one value per server.
- [Health attributes go stale in a long session] → Specified as "at connect"; any reconnect refreshes them.
- [Swapping `interceptors`/`events` for a factory touches every test that builds `AuthController`] → Defaults keep existing call sites compiling; only telemetry tests pass a factory.
- [The status fields are not in the OpenAPI spec (no response schema)] → The real-backend contract test asserts their types against a live Hermes.

## Migration Plan

No data migration. Rollback is reverting the PR.
