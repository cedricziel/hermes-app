## Context

See proposal.md for the presentation mismatch. Both detail callers select a plugin, open a modal only on compact layouts, and clear selection when it closes. SheetHost follows controller state and dismisses when a selected plugin disappears. Existing PluginDetail and CatalogTab catalog cases cover their content.

## Goals / Non-Goals

Reuse current content and controller behavior inside the established desktop route. Keep the mobile route's explicit drag handle and scroll settings. No new widget, layout, backend behavior, or MCP caller is introduced.

## Decisions

On macOS, pass the current SheetHost builder to showAdaptiveSheet. Keep the existing showModalBottomSheet options elsewhere because the shared helper does not expose the existing mobile drag-handle setting. Regular-width details remain panes and never reach either modal call.

Keep controller busy states and detail disappearance behavior unchanged. Dismissing a pending install continues to leave the operation running and its outcome reported by the mounted Catalog tab. Selection clearing remains after the awaited modal completes.

This changes compact macOS presentation. iOS, Android, Windows, and Linux keep their established route behavior; watchOS is unaffected. No entitlements, manifests, or Xcode files change. Managed API clients and fixed plugin action telemetry remain untouched; no spans, events, breadcrumbs, or attributes are added and no telemetry gains user content.

## Risks / Trade-offs

The route must preserve detail updates and asynchronous outcomes, so focused tests use the real controllers and generated clients over FakeHermesServer. Shared helper tests already cover desktop themes and route mechanics. Existing catalog components are reused, so no component cases or design component port is needed.

Native presentation remains unverified. The shared verify-in-app isolation rules apply before any native fixture launch. This bounded change introduces no new verification workflow or stale project skill.
