## Why

Show in Main Window and scheduled-run chat handoffs currently mutate the chat request before unconditionally removing pushed routes. They can bypass an editor's dismissal guard.

## What Changes

- Queue the complete target request and Chat selection behind the existing root dismissal guard.
- Preserve the newest handoff while the editor stays open and while App Lock covers the app.
- Revalidate protected authorization and owner generation before any queued external action is delivered.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `navigation`: Protect main-window chat handoffs from auxiliary windows and scheduled runs.

## Impact

AppShell and its widget tests change; no backend methods, response shapes, dependencies, or minimum Hermes version change. Existing target validation remains in the chat-opening flow.

Non-goals: bot creation/menu/intent entry points, retained authentication navigators, desktop Forward, and native presentation changes. Those remain in the full backlog.

Security and privacy: defer target/profile/composer mutation until the main guard authorizes departure. No credential or storage changes.

Observability: retain existing navigation breadcrumbs; no new payload or signal is necessary for reuse of the established queue.
