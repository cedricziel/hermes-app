## Purpose

Defines billing browser verification in the Hermes app so users can inspect backend-reported activity without changing the agent protocol.

## ADDED Requirements

### Requirement: Billing verification starts only by explicit request

The app SHALL offer Verify billing access as an optional user-invoked session action while method availability is unknown or established as supported. It SHALL call the existing billing.step_up method with the confirmed current runtime session_id and a known nonempty owning profile only after that explicit action. It SHALL recheck authenticated activity, current physical client, binding, and App Lock immediately before request bytes are sent. It SHALL NOT issue a speculative call to discover availability. While one request is pending, duplicate starts SHALL be disabled. A method-not-found response SHALL mark the action unavailable for that connection without failing chat. The action SHALL never run automatically in response to credit notices.

#### Scenario: The user starts billing verification

- **WHEN** billing.step_up is supported
- **THEN** one request begins and duplicate starts are disabled

### Requirement: Verification details are private and require a browser action

For billing.step_up.verification, the app SHALL show verification_url and user_code in an expandable in-app card for the owning session. It SHALL offer explicit Copy code and Open verification actions. Browser launch SHALL accept HTTPS URLs with no embedded credentials and show the destination host. Invalid URLs SHALL show an unavailable-open state while preserving safe text. The app SHALL never write the code or URL to preferences, telemetry, or operating-system notifications.

#### Scenario: A verification event supplies an invalid URL

- **WHEN** the card appears
- **THEN** browser launch is disabled and the code remains available only in-app

### Requirement: Grant state follows the server result

The originating billing.step_up result SHALL be the source of completion for that request. The app SHALL report granted only when ok and granted are true. It SHALL show failure or unavailable state for refusals and connection loss, obey reported retry_after for retry availability, and discard the code when the request finishes or the connection is discarded. Opening or returning from the browser SHALL not mark access granted. Uncorrelated verification events SHALL show verification details but no claimed grant result.

#### Scenario: The browser returns before the RPC completes

- **WHEN** the user returns to the app
- **THEN** the card remains pending until the server reports the result

### Requirement: Existing backend contract and compatibility

The app SHALL use the existing dashboard `/api/ws` JSON-RPC contract for billing.step_up.verification; billing.step_up. The current checked-in OpenRPC baseline SHALL be Hermes Agent commit `71d34bad1045610252eda02ee79549436896e784`, recorded in `openrpc/HERMES_REF`. Retained synthetic fixture shapes were audited against backend source `167e9fdb84248cd0fff80762dc57b6a914b6e930` and match the current billing parameter, result, and verification-payload schema; a minimum semantic release containing every required field is not established. Older backends SHALL keep ordinary chat usable when these optional events or methods are absent. Unsupported actions SHALL be unavailable, and malformed optional payloads SHALL not break the event stream. No backend route, protocol extension, or token-storage change SHALL be required.

`billing.step_up` takes optional `profile` and `session_id`. Its result requires boolean `ok` and optionally includes `granted`, `error`, `message`, and `retry_after`; granted is nullable and false also represents downscoping. The app recognizes grant only from `ok: true` and `granted: true`. The verification event does not carry an expiry or correlation ID.

The event shapes are:

- `billing.step_up.verification`: `BillingStepUpVerificationPayload`, required `verification_url`, `user_code`.

#### Scenario: Optional capability is absent

- **WHEN** an older backend omits this capability or refuses an optional method as unsupported
- **THEN** ordinary chat remains usable and the app reports unavailable functionality without inventing state or submitting speculative requests


### Requirement: Private details retire with their owning scope

The app SHALL discard code and URL on physical connection loss, profile or runtime replacement, session reclaim, protected activity retirement, or thread retarget/removal. It SHALL clear these details immediately when App Lock covers the app, reject new details while covered, and require fresh details after unlocking. App Lock SHALL retain the in-flight request barrier so unlocking cannot start a second billing RPC. A valid originating result MAY update grant status while locked without retaining the code. Replay-only rows from an old connection SHALL NOT restore verification details, while current live parked frames MAY provide fresh details through the owning runtime.

The live billing integration SHALL require a supplied App Lock controller as coverage authority. Without it, the capability SHALL remain unavailable. Auxiliary queue visibility alone SHALL NOT authorize billing verification because an initial visibility value does not prove current coverage.

#### Scenario: Auxiliary engine lacks proven App Lock coverage

- **WHEN** a chat controller has no supplied App Lock coverage authority, including an auxiliary engine without a verified coverage bridge
- **THEN** it creates no billing verification module, exposes no billing details or actions, and sends no billing step-up request

#### Scenario: App Lock covers an in-flight verification

- **WHEN** a dispatched billing step-up remains pending as the app locks and unlocks
- **THEN** the private details are cleared, old browser/copy callbacks are rejected, and a duplicate RPC is blocked until the existing request ends

#### Scenario: A reconnect replays a discarded verification code

- **WHEN** the replay ring contains an old billing verification frame after physical connection loss
- **THEN** the code stays discarded and only current live details can be shown, without altering replay sequence handling or main-turn completion
