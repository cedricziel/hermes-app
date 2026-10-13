## Context

HermesApp owns a stable root navigator. Shell destinations are IndexedStack peers. SettingsScaffold offers direct maybePop Back, and RootNavigationQueue guards external route unwinds. SessionActivity is not wired in production; history must use live AuthController, AppLockController, and HandoffController state.

## Goals / Non-Goals

Goals: one shared desktop detail stack and one reconstructible workers route. Non-goals: retaining disposed builders/controllers, restoring form state, preserving all route state across login, or adding native input handlers.

## Decisions

- Keep typed immutable targets in a bounded root observer. Record eligible routes only after command-initiated successful pops; programmatic completion/removal is excluded. Root commands override per-page Back and the Mac toolbar delegates to the same engine.
- Resolve workers with current repositories, plugin availability, and board existence reads before a new route push. Store only the board slug; the replayed page has no captured board controller callback. New pushes clear Forward except internal replay. Modal pushes do not clear the branch but disable Forward.
- RootNavigationQueue holds a suppression lease across its guarded unwind and invalidates history immediately before external commit. Peer changes explicitly clear history without pushing routes.
- Gate all actions synchronously and after awaited validation. Track an invalidation revision to prevent a late resolver from crossing a peer change or owner departure. Expiry pauses only when verified owner evidence matches; explicit user generation/server/owner changes clear the branch.
- Observe ConversationWindows key-window transitions and MacApp windowless events at the root. Recheck live focus after awaited validation and invalidate pending resolution when focus changes, including a brief focus switch back to main. Cancelled or disposed external queues race both the maybePop wait and the subsequent route wait, then release suppression; a new request still drains under its guard. The race handles late errors from detached maybePop work. Cancellation cannot undo a Navigator guard call already in flight or its eventual route effects. The held willPop regression is a component fixture, not a current workers-page journey.
- Desktop AdaptiveBackButton delegates to the same engine on Windows/Linux while mobile buttons keep framework dismissal.
- Listen only to PointerDownEvent mouse side-button bits. Do not register pointer-signal navigation.

## Risks / Trade-offs

- Native delivery of mouse side buttons is unverified → widget tests exercise Flutter event handling; report native check outstanding.
- Authentication UI currently replaces home content → retain only eligible descriptor history for proven same-owner expiry; full navigator/UI retention remains separate work.
- Offline validation cannot prove availability → leave the current route intact, without issuing a mutation.

Platforms: macOS menu and desktop mouse handling on macOS/Windows/Linux. iOS, Android, and watchOS retain existing navigation. No entitlements, manifests, Xcode changes, dependencies, or generated API changes. Auth owner isolation and generated API layering invariants apply.

The history engine records fixed `nav.history.back` and `nav.history.forward` breadcrumbs with outcome only. Existing HTTP spans cover the resolver reads. No new logs or attributes include content, slugs, owners, or server URLs. No new standalone UI widget is introduced, so Widgetbook additions are unnecessary. Existing skills remain applicable.
