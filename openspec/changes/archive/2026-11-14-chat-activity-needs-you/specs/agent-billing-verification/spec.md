# Spec Delta

## MODIFIED Requirements

### Requirement: Verification details are private and require a browser action

For billing.step_up.verification, the app SHALL show verification_url and user_code for the owning session in the chat's docked Needs-you card above the composer while the originating request is pending; uncorrelated verification details SHALL be shown there too. It SHALL offer explicit Copy code and Open verification actions. Browser launch SHALL accept HTTPS URLs with no embedded credentials and show the destination host. Invalid URLs SHALL show an unavailable-open state while preserving safe text. The app SHALL never write the code or URL to preferences, telemetry, or operating-system notifications, and SHALL NOT read them in an automatic accessibility announcement.

#### Scenario: A verification event supplies an invalid URL

- **WHEN** the card appears
- **THEN** browser launch is disabled and the code remains available only in-app

#### Scenario: Verification details arrive during a reply

- **WHEN** billing.step_up.verification arrives for the open chat
- **THEN** the details show in the card above the composer and nothing about billing is added above the transcript
