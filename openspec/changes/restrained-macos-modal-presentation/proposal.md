## Why

The shared modal helper chooses presentation by width, so a narrow Mac window shows mobile bottom sheets. Shared confirmation dialogs also use the SDK's mobile-style dialog motion, and Cupertino alert actions do not provide keyboard activation in the installed SDK. The user confirmed restrained desktop dialogs/popovers on macOS.

## What Changes

- Add a shared macOS dialog entry point with a 150 ms stationary fade, immediate content under reduced motion, captured caller themes, and contained keyboard focus.
- Use it for shared confirmations and for command-server execution reviews and platform-hint prompts at every Mac window width.
- Make common macOS alert actions keyboard focusable and activatable; cancellable dialogs support Escape while busy guards can refuse dismissal.
- Add a catalog use case and behavioral regressions before wiring callers.

Non-goals: migrate other feature modal APIs, change iOS/Android presentation, replace native windows, or implement authentication/navigation draft recovery.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `navigation`: restrained macOS shared modal presentation and keyboard interaction.

## Impact

Shared dialog/sheet helpers, common macOS alert actions, their two sheet callers, and the Widgetbook catalog. No backend route, RPC method, response shape, minimum Hermes version, dependency, or native project/entitlement change.

Security/privacy impact: no token, storage, or telemetry changes; existing busy dismissal guards and confirmation results remain enforced.

Observability: none. This is presentation and local keyboard behavior; existing route and caller telemetry remains sufficient and no new content-bearing signal is needed.
