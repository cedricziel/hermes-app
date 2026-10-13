## Why

Desktop users can go Back from detail pages but cannot reopen a safe detail with Forward. Add a bounded history for the workers page while retaining dismissal guards and the shared detail stack.

## What Changes

- Add opt-in immutable workers history targets, guarded desktop Back/Forward, mouse side buttons, and macOS View > Forward (Cmd+]).
- Keep peer section switches outside history and clear the Forward branch on a new section or committed external navigation.
- Pause commands under authentication, App Lock, or Handoff gates; clear history on explicit departure or changed owner.
- Revalidate the Kanban plugin and board before reconstructing workers from current repositories.

## Capabilities

### New Capabilities

### Modified Capabilities

- `navigation`: bounded desktop detail history with guarded Back and read-only workers reconstruction.

## Impact

Root app navigation, Mac commands/menu, auxiliary-window overrides, root navigation queue, and workers push. Existing generated Kanban GET APIs remain unchanged. Non-goals: history for editors, actions, other detail routes, peer sections, mobile gestures, and trackpad navigation. No native project changes.

Security and privacy: history stays in memory, stores only a board slug, and clears when its owner departs. No token or secure-storage changes.

Observability: fixed navigation breadcrumbs for Back/Forward outcomes; no user content, board slug, owner, or server attributes. Existing HTTP telemetry records availability reads.
