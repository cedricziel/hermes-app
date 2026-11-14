# Spec Delta

## MODIFIED Requirements

### Requirement: Scoped session usage contract

The app SHALL request authenticated `/api/ws` RPC `session.usage` with a confirmed runtime `session_id` and the resolved `profile`. A nullable profile SHALL be accepted only when the current owned runtime was confirmed on that exact connection and the runtime-scoped resolver has no ambient-profile fallback. It SHALL consume the `SessionUsageResult` shape and live `session.usage` payload `{usage: Usage}`. The supported contract baseline SHALL be repository-pinned Hermes commit `167e9fdb84248cd0fff80762dc57b6a914b6e930`; earliest released version support is unverified. A method-not-found response SHALL disable usage inspection without disabling chat, and SHALL remove session usage from view rather than show an unsupported row.

#### Scenario: Open usage inspection

- **WHEN** a user opens Session usage in a selected conversation
- **THEN** the app requests that session and profile and shows the returned model, input, output, reasoning, total, and calls when valid
- **AND** missing data is unavailable rather than synthesized as zero

#### Scenario: The server does not offer session usage

- **WHEN** `session.usage` answers method-not-found
- **THEN** no session usage row is drawn and chat remains usable
