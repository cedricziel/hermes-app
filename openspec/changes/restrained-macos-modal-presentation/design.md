## Context

The shared sheet helper is width-only. Common confirmations use SDK adaptive dialog routes; the installed Cupertino alert action renderer handles pointer/semantics activation without keyboard focus. Existing page motion is already restrained on macOS.

## Goals / Non-Goals

Goals: desktop presentation for the two shared-sheet callers at every Mac width; stationary short dialog motion; reduced-motion content; keyboard action focus/activation and safe dismissal. Preserve caller themes, route results, busy guards, and existing non-macOS presentation.

Non-goals: other feature modal migrations, authentication/navigation retention, native AppKit replacements, new backend behavior.

## Decisions

Introduce a shared dialog entry point. On macOS push a RawDialogRoute with captured caller themes, safe-area content, a closed keyboard traversal loop, and a 150 ms fade without translation or scaling. Reduced motion shows content immediately. Dismissible dialogs support Escape and barrier cancellation; PopScope still governs dismissal. Common confirmations use this entry point; macOS adaptive sheets use it regardless of width. Other sheet/dialog paths retain their existing SDK choices.

Add a macOS-only focus/activation wrapper around the existing Cupertino alert action renderer. Support both ActivateIntent and ButtonActivateIntent, skip disabled actions, show a focus outline, and reject activation after the dialog ceases to be current. Do not automatically focus a destructive action. Keep pointer semantics and iOS rendering intact.

Add a catalog use case before caller wiring. Test rendered bounds and effective opacity through transitions, confirmation results, keyboard focus/activation, busy dismissal refusal, captured themes, and unchanged mobile layout choices.

Platforms: macOS presentation and keyboard behavior change. iOS, Android, Windows, Linux, and watchOS keep existing behavior. No native entitlement, manifest, Xcode, dependency, or protocol change.

Project invariants: confirmation does not dispatch backend work automatically, busy guards cannot be bypassed, no tokens or preferences are touched, and no generated API client is changed. Observability: none; this local presentation change adds no span, log event, breadcrumb, or user-content attribute.

## Risks / Trade-offs

Escape/barrier cancellation becomes available for shared macOS confirmations and returns false. Cupertino pointer-action integration must remain intact when adding focus. Native interaction must not be claimed from widget or browser-catalog checks; record native-control limitations.

## Verification record

The pre-change regression run failed six macOS cases while five compatibility controls passed. The focused dialog suite passed 19 tests, followed by a passing reverse-motion regression, including retained callback safety, keyboard focus and activation, motion, reduced motion, busy dismissal, theme capture, and mobile layout/results. The final modal, caller, and complete component-catalog suite passed 4,318 tests; scoped analysis and strict change validation passed. The web catalog built successfully and its synthetic macOS sheet example rendered as a centered dialog in the compact preview under light and dark themes; the Close action dismissed it. These browser checks do not verify native macOS keyboard or accessibility behavior. Native verification remains open because the native control tool previously stalled and could not reliably bind the isolated fixture.

The React AlertDialog and Sheet design counterparts need a design port. No client storage, backend, or native configuration was used by the browser catalog check.
