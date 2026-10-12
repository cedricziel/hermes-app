## Why

The user reported unfamiliar page motion on macOS and confirmed restrained desktop presentation. The shared theme currently relies on Flutter's platform transition defaults, so desktop page motion is not explicitly controlled by the app.

## What Changes

- Give macOS page pushes and pops, including full-screen image viewers, a short fade without horizontal or vertical page movement.
- Show macOS pages immediately when reduced motion is enabled.
- Preserve the installed SDK's iOS interactive Back and Android predictive Back builders.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `navigation`: explicit macOS page motion and reduced-motion behavior.

## Impact

Shared light/dark themes used by the main app, conversation windows, and quick panel. No backend, dependency, native project, or entitlement changes. Modal presentation, non-Material attachment route types, gestures, and authentication recovery remain separate changes.

Security and privacy impact: None. Observability: None; this visual policy adds no meaningful user event or network operation.
