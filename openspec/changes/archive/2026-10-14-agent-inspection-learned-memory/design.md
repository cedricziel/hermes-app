## Context

No dedicated memory UI exists in `lib`. `GET /api/memory` is provider status, not memory content. Existing generated methods `getLearningGraphApiLearningGraphGet` and `getLearningNodeApiLearningNodeGet` return `Response<Object>` because the OpenAPI success schemas are empty. See proposal.md for motivation.

`agent/learning_graph.py::build_learning_graph`, `agent/learning_mutations.py::node_detail`, and the learning routes in `hermes_cli/web_routers/status.py` were checked at bundled Hermes revision `167e9fdb84248cd0fff80762dc57b6a914b6e930`. Fixtures in `test/memory/memory_fixtures.dart` record that baseline. The app parses verified response subsets without changing server schemas.

## Goals / Non-Goals

Goals: one profile-scoped list and detail that the mutation follow-up can reuse.

Non-goals: visual graph layout, learned-skill management, disk caching, provider setup, and new backend routes.

## Decisions

Add a small Memory settings destination using existing grouped-list and disclosure conventions. Keep profile and connection generation with every pending read. Use `authController.api!.raw` generated operations and validate the returned Object in a small app-owned parser. Do not edit generated client files or invent schemas for empty response definitions.

Consume `nodes` and only the fields required by the spec. Ignore graph edges, clusters, statistics, and unknown fields. Detail requires `ok`, matching opaque `id`, `kind`, and `content`. Retain IDs supplied by the server. No filesystem paths or list indexes substitute for identity. Unsupported or malformed shapes fail visibly rather than creating a false empty state.

Keep content in scoped in-memory state and render inert text. Clear it on scope changes and sign-out. Reuse existing App Lock boundaries. Auth secure-storage and concurrent-401 invariants remain unchanged. No duplicate Dio client or cookie authentication.

Affected platforms: iOS, Android, macOS, Windows, and Linux. watchOS is unchanged. No native entitlements, manifests, or Xcode changes.

Record `memory.fetch` span at the generated-client read boundary with fixed operation `list` or `detail`, outcome, and inherited `hermes.*` connection attributes. Record `memory.fetch_failed` through AppEventLogger with fixed category. Record `memory.open` through Breadcrumbs at list/detail navigation with fixed kind. No user content, IDs, labels, profile names, or response bodies enter these signals. Telemetry remains opt-in and failure-tolerant.

## Risks / Trade-offs

- REST response schemas are unspecified. Verify exact pinned success and error fixtures before wiring UI; keep runtime validation.
- Memory node IDs can become stale. Refresh the list and require another selection rather than rebinding by position.
- Graph responses include preview bodies. Read only the nodes needed by the UI and avoid retaining unused response fields.

## Migration Plan

No server or stored-data migration. Add the destination, then ship memory mutations as a separate dependent PR. Rollback removes the destination without changing memories.
