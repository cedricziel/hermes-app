# session-activity Specification

## Purpose
TBD - created by archiving change suspend-main-session-activity. Update Purpose after archive.

## Requirements

### Requirement: Verified-owner activity lifetime

A protected activity owner SHALL close its activity gate synchronously when authorization ends. A fresh expiry belonging to its captured verified account SHALL suspend activity. It SHALL resume only when protected requests are allowed, authentication is ready, the departure generation is unchanged and the same verified account is proven. Explicit departure, different ownership or absent ownership proof SHALL retire the activity owner permanently.

#### Scenario: Same-account recovery
- **WHEN** a verified account expires and subsequently signs in as the same account without departing
- **THEN** activity is false throughout recovery and becomes true only after verified authorization returns

#### Scenario: Historical expiry cannot authorize retention
- **WHEN** an account recovers from expiry and a later non-expiry transition closes authorization
- **THEN** the previous expiry marker does not classify that transition as recoverable expiry

#### Scenario: Departure during token cleanup
- **WHEN** explicit departure begins while token cleanup remains pending
- **THEN** activity closes immediately and that activity owner cannot resume

#### Scenario: Authorized same-server connection check
- **WHEN** a same-owner connection check changes readiness while protected authorization remains allowed
- **THEN** activity pauses until ready and does not retire solely because readiness changed
