## Context

See proposal.md for motivation. `KanbanBoardController.active` governs visibility and intentionally keeps an already-due event refetch. Its existing generation invalidates board restarts but does not cover authentication suspension, board-list loads or mutation continuations.

## Goals / Non-Goals

Add a controller-only activity boundary that retains the current snapshot and selection. The owner decides whether a renewed identity can reuse the controller and disposes it on explicit departure. This change does not wire owners, screens, task controllers or forms.

## Decisions

- Accept `ValueListenable<bool>? activity`; omission preserves existing callers. Keep `active` as the visibility policy. Combining both would break hidden-board refetch behavior.
- Read the listenable's live value for every protected dispatch and result. Increment the existing board generation on every delivered activity notification, even if nested delivery leaves the final value unchanged. The generation fences both board changes and activity changes. Cached state alone permits earlier listeners to dispatch while paused; transition-only epochs miss nested false-to-true notifications.
- Pause synchronously cancels timers, detaches stream references and closes the channel before awaiting subscription cleanup. Fence reads, stream connection results, event callbacks, reconnect callbacks, writes and follow-up refreshes with the generation. Recheck after notifications before dispatch.
- Keep a newly created subscription local until post-listen activity and channel ownership checks succeed. If a synchronous listen callback suspends and resumes activity or visibility, cancel that retired subscription without replacing the resumed stream. Event and retry callbacks also check channel ownership, so visibility can retain its existing refetch policy without changing the generation.
- Resume reads the board list and snapshot afresh. Keep local board/filter/status/selection state; a fresh snapshot may remove selected ids that no longer exist. Do not retry mutations.
- Mutation futures reject with `StateError('Kanban activity suspended')` on inactive entry or when activity changed before completion. The existing void dispatcher API must not return successful completion that its caller turns into a success snackbar.
- Continue using the generated API through `KanbanRepository` and test it through `FakeHermesServer`. No backend route, model or minimum-version change is needed. No auth token or secure-storage change is needed.

Affected platforms are iOS, Android, macOS, Windows and Linux. watchOS does not own this board controller. No native entitlement, manifest or Xcode changes are needed.

Observability adds no span, log event or breadcrumb. Existing HTTP instrumentation and `kanban.events.reconnect` in the board controller retain their existing attributes; no user content is added. Session suspension reasons remain the owner's responsibility.

## Risks / Trade-offs

- Already-dispatched mutations may succeed remotely while suspended. Fresh resume reads reconcile them; the controller cannot safely undo them.
- Mutation suspension uses a fixed error and performs no rollback. Owner/UI fencing must suppress outdated action errors after authentication loss.
- Tests establish the component boundary. Native connection and retained-owner UI verification belong to integration and remain explicitly pending.

## Migration Plan

The optional parameter allows this component change to ship without owner wiring. Integration supplies its session activity signal. Rollback removes that argument and restores the existing always-active behavior.
