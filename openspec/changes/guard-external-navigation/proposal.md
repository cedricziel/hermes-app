## Why

Deep links currently dismiss pushed routes with `popUntil`, bypassing unsaved-change and busy-operation guards. They can also publish chat requests before dismissal, changing the underlying chat while an editor remains open.

## What Changes

- Hold the latest deep link until guarded routes have actually closed.
- Use existing Back confirmations when unwinding routes; keep the request pending if the user continues editing or an operation blocks dismissal.
- Deliver the request only after reaching the shell, and recheck App Lock and destination availability.

## Capabilities

### New Capabilities

- `navigation`: Guarded deep-link navigation to the signed-in shell.

### Modified Capabilities

None.

## Impact

AppShell, a reusable route-unwinding helper, and deep-link workflow tests. No backend routes, generated API changes, dependencies, or native configuration changes.

## Non-goals

Notifications, sharing, window handoffs, authentication teardown, section history, and presentation changes follow in separate changes. Existing latest-request-wins behavior remains.

## Security and privacy impact

No token or storage changes. A link held while editing must not start chat work or dictation while App Lock covers the app.

## Observability

Retain existing `deeplink.opened` and `deeplink.ignored` breadcrumbs; record opened only after safe delivery. No new spans or log events are needed for local route dismissal. Breadcrumbs retain kind and flags only, without link contents.
