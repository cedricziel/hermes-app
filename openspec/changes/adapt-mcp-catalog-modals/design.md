## Context

See proposal.md for the presentation mismatch. McpCatalogScreen opens an uninstalled entry through one compact modal caller. Installed entries already use server pages; regular-width entries use panes. McpInstallPanel owns field and button busy states, clears credentials, and stops local build polling on disposal.

## Goals / Non-Goals

Reuse the current panel and callback ownership through the established modal route. Keep current mobile options, wide panes, and server-build dismissal intact. No panel, controller, authorization, or backend changes.

## Decisions

Replace the compact call with showAdaptiveSheet<void>. Its mobile branch already uses the same scroll-controlled safe-area options, so an additional platform branch is unnecessary. Preserve onInstalled and onGone checks of the builder context's mounted/current route before popping it. A completed install still reports its result and offers the installed server; a disposed panel cannot navigate later.

Busy controls remain disabled while requests or server builds run. The modal remains dismissible as before; disposal stops polling without cancelling the remote build. Existing catalog and install panel cases are reused because no visual component changes.

Compact macOS presentation changes. iOS, Android, Windows, and Linux retain their existing route policy, and watchOS is unaffected. No native entitlements, manifests, or Xcode files change. Generated-client layering, credential storage, and existing telemetry are unchanged. No new spans, log events, breadcrumbs, or attributes are added; no telemetry gains user content.

## Risks / Trade-offs

Desktop route ownership must not pop the underlying catalog on late results, so focused tests use real generated clients and held install futures. Native keyboard, presentation, and accessibility verification remain unavailable until an isolated fixture is used under the shared verify-in-app rules.

`design/web/src/components/McpCatalogScreen/McpCatalogScreen.tsx` needs a design port. That counterpart is outside this bounded Flutter caller migration; publication planning must retain the follow-up. No project skill becomes stale and no new workflow skill is required.
