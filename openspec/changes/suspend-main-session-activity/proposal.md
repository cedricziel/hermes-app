## Why

Retaining drafts behind sign-in requires a shared activity boundary that closes immediately when authorization ends. Historical expiry flags cannot distinguish a fresh expiry from a later server departure.

## What Changes

- Add a monotonic expiry transition marker to authentication.
- Add a verified-owner activity coordinator that pauses on fresh expiry, resumes only for the same verified account, and retires on departure or different ownership.
- Expose a stable activity listenable for existing chat, dictation and notification consumers.

## Capabilities

### New Capabilities

- `session-activity`: Verified-owner suspension and retirement of protected client activity.

### Modified Capabilities

None.

## Impact

AuthController and a new owner coordinator with focused lifecycle tests. No backend endpoints or generated client changes. Non-goals: retaining navigator widgets, auxiliary windows, remaining controller integration and desktop history; those ship separately after activity consumers are covered. Security and privacy: authorization closes synchronously; tokens remain in secure storage and no private content enters telemetry. Observability: none added because this internal boundary is verified through lifecycle tests and existing authentication outcomes.
