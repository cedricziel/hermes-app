## Why

Plugin details still open as mobile bottom sheets in narrow macOS windows. They need the shared restrained desktop dialog presentation while keeping the existing detail content and actions.

## What Changes

- Open Installed and Catalog plugin details through the shared adaptive dialog policy on compact macOS layouts.
- Preserve mobile bottom sheets and wide details panes.
- Keep dismissal selection cleanup, detail disappearance, disabled busy actions, and asynchronous action results intact.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `plugins`: Use desktop dialogs for compact macOS plugin details.

## Impact

Only the Installed and Catalog detail presentation callers, focused widget tests, and this change's artifacts are affected. Existing components and their catalog cases are reused. No backend contract, dependencies, or minimum Hermes version changes.

Non-goals: redesigning plugin content, changing wide panes or mobile sheet behavior, migrating MCP details, and changing plugin installation or mutation logic.

Security and privacy: None. Credentials, storage, and user content handling remain unchanged.

Observability: None added. This route presentation change introduces no backend operation or user action beyond those already covered by plugin action telemetry.
