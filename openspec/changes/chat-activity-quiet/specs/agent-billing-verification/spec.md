# Spec Delta

## MODIFIED Requirements

### Requirement: Billing verification starts only by explicit request

The app SHALL offer Verify billing access as an optional user-invoked session action while method availability is unknown or established as supported. It SHALL call the existing billing.step_up method with the confirmed current runtime session_id and a known nonempty owning profile only after that explicit action. It SHALL recheck authenticated activity, current physical client, binding, and App Lock immediately before request bytes are sent. It SHALL NOT issue a speculative call to discover availability. While one request is pending, duplicate starts SHALL be disabled. A method-not-found response SHALL mark the action unavailable for that connection without failing chat; an unavailable action SHALL be removed from view rather than shown as an unavailable row. The action SHALL never run automatically in response to credit notices.

#### Scenario: The user starts billing verification

- **WHEN** billing.step_up is supported
- **THEN** one request begins and duplicate starts are disabled

#### Scenario: The server does not offer billing verification

- **WHEN** billing.step_up answers method-not-found
- **THEN** no billing row or action is drawn for that connection and chat remains usable
