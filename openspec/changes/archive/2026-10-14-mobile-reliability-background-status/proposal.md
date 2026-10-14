## Why

Mobile background refresh has no guaranteed schedule, but notification settings do not explain the delivery limits or show whether checks recently succeeded. Users need useful state without a false promise of timely alerts.

## What Changes

- Show notification permission and background-refresh availability separately on iOS and Android.
- Explain that periodic checks may run late or never, and that a successful check does not prove a notification reached the user.
- Record and show the last attempted check, last completed check, and fixed latest outcome, scoped to the current account.
- Let foreground resume refresh status without starting an extra background poll or changing scheduling.

Non-goals: shorter polling, new settings switches, guaranteed delivery, diagnostic history, push enrollment, and desktop background scheduling.

Security and privacy impact: store timestamps and fixed outcomes only, scoped by the existing account key. No server address, token, request ID, prompt, or title enters this status record or telemetry. Clear it on sign-out and server change.

Observability: no new telemetry. Existing scheduling failures and `background.task` outcomes remain the diagnostic signals. The local status record exists for the user interface and must not fail background work.

## Capabilities

### New Capabilities

- `background-delivery-status`: mobile delivery limitations, capability state, and last-check outcomes.

### Modified Capabilities

None.

## Impact

Notification settings dialog, background scheduler and refresh completion wiring, account-scoped preferences, tests, and Widgetbook examples. No backend changes. Timely server-triggered alerts require future backend registration, revocation, and notification-provider support, which this app-only proposal does not introduce. Target one PR under 500 lines.
